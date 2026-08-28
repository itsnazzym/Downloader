import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/features/downloader/domain/repositories/i_downloader_repository.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/core/download/x_download_url.dart';
import 'package:modern_downloader/core/download/extension_download_batcher.dart';
import 'package:modern_downloader/core/download/progress_throttle.dart';
import '../logger/logger_service.dart';
import 'heartbeat_cookie_locator.dart';
import '../services/notification_service.dart';
import '../security/local_server_auth.dart';
import '../../features/x_feed/gobird_x_feed_service.dart';
import '../../features/x_feed/library_keys_snapshot.dart';
import '../../features/x_feed/x_feed_ws_contract.dart';
import '../../services/binary_locator.dart';

final localServerServiceProvider = Provider<LocalServerService>((ref) {
  return LocalServerService(ref);
});

class LocalServerService {
  final Ref _ref;
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  final GobirdXFeedService _gobirdFeedService;
  late final ExtensionDownloadBatcher _downloadBatcher;
  final ProgressBroadcastFilter _progressFilter = ProgressBroadcastFilter();

  /// HELLO must arrive within this window or the socket is closed.
  static const Duration helloTimeout = Duration(seconds: 2);

  LocalServerService(this._ref, {GobirdXFeedService? gobirdFeedService})
    : _gobirdFeedService =
          gobirdFeedService ?? GobirdXFeedService(locator: BinaryLocator()) {
    _downloadBatcher = ExtensionDownloadBatcher(
      onFlush: _flushExtensionDownloads,
    );
  }

  Future<void> start() async {
    final settings = _ref.read(settingsProvider);
    final port = settings.serverPort;

    _ref.listen<IDownloaderRepository>(downloaderRepositoryProvider, (
      previous,
      next,
    ) {
      // Monitor the stream manually since the provider returns the Repo instance
    });

    final repo = _ref.read(downloaderRepositoryProvider);
    repo.downloadUpdateStream.listen(_broadcastProgress);

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      LoggerService.i('''
==================================================
🚀 Local Server running on http://127.0.0.1:$port
🔌 WebSocket Mode: ENABLED (Zero-Config)
✅ Ready for Extension Connection
==================================================
''');

      _server!.listen((HttpRequest request) {
        _handleRequest(request);
      });
    } catch (e) {
      LoggerService.e('Failed to start Local Server on port $port', e);
    }
  }

  Future<void> stop() async {
    try {
      _downloadBatcher.flush();
      _downloadBatcher.dispose();
    } catch (e) {
      LoggerService.w('Failed to flush extension download batch: $e');
    }
    for (final client in _clients) {
      client.close();
    }
    _clients.clear();
    await _server?.close();
    _server = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      try {
        final socket = await WebSocketTransformer.upgrade(request);
        _handleWebSocket(socket, request);
      } catch (e) {
        LoggerService.e('WebSocket upgrade failed', e);
      }
      return;
    }

    if (request.uri.path == '/status') {
      request.response.write(
        jsonEncode({'status': 'running', 'mode': 'websocket'}),
      );
    } else {
      request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  }

  bool _isAuthorized(String? token) {
    final expected = _ref.read(settingsProvider).apiToken;
    return LocalServerAuth.isAuthorized(
      expectedToken: expected,
      providedToken: token,
    );
  }

  void _acceptClient(WebSocket socket) {
    if (_clients.contains(socket)) return;
    _clients.add(socket);
    NotificationService().showExtensionConnected();
  }

  void _handleWebSocket(WebSocket socket, HttpRequest request) {
    LoggerService.i(
      '🔌 Extension Connected (WebSocket) from ${request.connectionInfo?.remoteAddress.address}',
    );

    // Token must arrive via HELLO message body — never from the URL query.
    var authorized = false;
    Timer? helloTimer;

    helloTimer = Timer(helloTimeout, () {
      if (!authorized) {
        LoggerService.w('WebSocket closed: HELLO auth timeout');
        try {
          socket.add(
            jsonEncode({'type': 'AUTH_FAILED', 'reason': 'hello_timeout'}),
          );
        } catch (_) {}
        socket.close();
      }
    });

    socket.listen(
      (message) {
        try {
          final data = jsonDecode(message) as Map<String, dynamic>;
          final type = data['type'] as String?;

          if (type == 'HELLO') {
            final messageToken = LocalServerAuth.tokenFromMessage(data);
            authorized = _isAuthorized(messageToken);
            LoggerService.i('👋 Extension Hello received');
            if (authorized) {
              helloTimer?.cancel();
              _acceptClient(socket);
              socket.add(jsonEncode({'type': 'HELLO_OK'}));
              _sendLibraryKeys(socket);
            } else {
              helloTimer?.cancel();
              socket.add(jsonEncode({'type': 'AUTH_FAILED'}));
              socket.close();
            }
            return;
          }

          // Refuse every other message until HELLO succeeds.
          if (!authorized) {
            socket.add(
              jsonEncode({
                'type': 'AUTH_FAILED',
                'reason': 'not_authenticated',
              }),
            );
            return;
          }

          if (type == 'PING') {
            socket.add(jsonEncode({'type': 'PONG'}));
            return;
          }

          if (type == 'DEBUG') {
            // Never echo secrets; message body is extension-controlled text only.
            final debugMsg = data['message'];
            if (debugMsg is String) {
              LoggerService.i('🐛 EXT DEBUG: $debugMsg');
            }
            return;
          }

          if (type == 'DOWNLOAD') {
            final error = _processDownloadPayload(data);
            if (error == null) {
              socket.add(
                jsonEncode({
                  'type': 'ACK',
                  'ok': true,
                  'message': 'Download received',
                }),
              );
            } else {
              socket.add(
                jsonEncode({'type': 'ACK', 'ok': false, 'error': error}),
              );
            }
          } else if (type == 'HEARTBEAT_COOKIES') {
            _handleHeartbeatCookies(data);
          } else if (type == LibraryKeysSnapshot.requestType) {
            _sendLibraryKeys(socket);
          } else if (type == XFeedWsContract.requestType) {
            unawaited(_handleXFeedRequest(socket, data));
          }
        } catch (e) {
          LoggerService.e('Error parsing WS message', e);
        }
      },
      onDone: () {
        helloTimer?.cancel();
        LoggerService.i('🔌 Extension Disconnected');
        _clients.remove(socket);
      },
      onError: (e) {
        helloTimer?.cancel();
        LoggerService.e('WebSocket Error', e);
        _clients.remove(socket);
      },
    );
  }

  void _sendLibraryKeys(WebSocket socket) {
    try {
      if (socket.readyState != WebSocket.open) return;
      final repo = _ref.read(downloaderRepositoryProvider);
      final snapshot = LibraryKeysSnapshot.fromDownloads(
        repo.getCurrentDownloads(),
      );
      final payload = snapshot.toJson();
      if (payload.containsKey('filePath') ||
          payload.containsKey('cookies') ||
          payload.containsKey('request')) {
        LoggerService.w('LIBRARY_KEYS_RESULT rejected: unsanitized fields');
        return;
      }
      socket.add(jsonEncode(payload));
    } catch (e) {
      LoggerService.w('Failed to send LIBRARY_KEYS_RESULT: $e');
    }
  }

  void _broadcastProgress(DownloadItem item) {
    if (_clients.isEmpty) return;
    if (!_progressFilter.shouldSend(
      id: item.id,
      status: item.status,
      progress: item.progress,
    )) {
      return;
    }

    try {
      final payload = jsonEncode({
        'type': 'PROGRESS',
        'data': item.toExtensionProgressJson(),
      });

      for (final client in _clients) {
        if (client.readyState == WebSocket.open) {
          client.add(payload);
        }
      }
    } catch (e) {
      LoggerService.w('Failed to broadcast progress: $e');
    }
  }

  Future<void> _handleXFeedRequest(
    WebSocket socket,
    Map<String, dynamic> data,
  ) async {
    final requestId = XFeedWsContract.requestIdFrom(data);

    void reply(Map<String, dynamic> payload) {
      if (socket.readyState != WebSocket.open) return;
      final body = <String, dynamic>{
        'type': XFeedWsContract.resultType,
        if (requestId != null) 'requestId': requestId,
        ...payload,
      };
      try {
        socket.add(jsonEncode(body));
      } catch (e) {
        LoggerService.w('Failed to send X_FEED_RESULT: $e');
      }
    }

    try {
      // Cookie smuggling is never accepted on this channel.
      if (XFeedWsContract.containsCookieFields(data)) {
        reply({
          'ok': false,
          'source': 'gobird',
          'errorCode': 'cookies_forbidden',
          'error': 'Cookies must not be sent with X_FEED_REQUEST',
          'items': <Object>[],
        });
        return;
      }

      final settings = _ref.read(settingsProvider);
      if (!settings.experimentalXFeedGobirdEnabled) {
        LoggerService.i('X_FEED_REQUEST rejected: gobird disabled in settings');
        reply({
          'ok': false,
          'source': 'gobird',
          'errorCode': 'disabled',
          'error': 'Experimental gobird X feed is disabled',
          'items': <Object>[],
        });
        return;
      }

      final count = XFeedWsContract.normalizeCount(
        data['count'] ?? data['maxItems'],
      );
      LoggerService.i(
        'X_FEED_REQUEST: gobird home count=$count browser=${settings.gobirdBrowser}',
      );
      final result = await _gobirdFeedService.fetchHomeFeed(
        browser: settings.gobirdBrowser,
        count: count,
        probeContentLength: false,
        cookiesFilePath: settings.cookiesFilePath,
      );
      if (!result.ok) {
        LoggerService.w(
          'X_FEED_RESULT failure: ${result.errorCode} — ${result.error}',
        );
      } else {
        LoggerService.i(
          'X_FEED_RESULT ok: ${result.items.length} video items (gobird)',
        );
      }
      reply(result.toJson());
    } catch (e, st) {
      LoggerService.e('X_FEED_REQUEST failed', e, st);
      reply({
        'ok': false,
        'source': 'gobird',
        'errorCode': 'unknown',
        'error': e.toString(),
        'items': <Object>[],
      });
    }
  }

  Future<void> _handleHeartbeatCookies(Map<String, dynamic> data) async {
    try {
      final domain = data['domain'] as String?;
      final cookies = data['cookies'] as String?;
      if (cookies == null || domain == null || domain.isEmpty) return;

      if (!cookies.contains('\t') && cookies.contains('=')) {
        LoggerService.w(
          '❤️ Heartbeat: Received cookies for $domain in Header format (not Netscape). Ignoring to prevent yt-dlp errors.',
        );
        return;
      }

      final safeName = LocalServerAuth.sanitizeDomainForFilename(domain);
      final appDir = Directory.systemTemp;
      final cookieFile = File('${appDir.path}/heartbeat_cookies_$safeName.txt');
      await cookieFile.writeAsString(cookies);
      LoggerService.i(
        '❤️ Heartbeat: Updated cookies for $domain → ${cookieFile.path}',
      );
      // Do not overwrite settings.cookiesFilePath — keep per-domain heartbeat files
      // and resolve the right one at download start via heartbeatCookiePathForUrl.
    } catch (e) {
      LoggerService.e('Failed to handle heartbeat cookies', e);
    }
  }

  /// Resolve the heartbeat cookie file for a URL hostname, if present.
  static Future<String?> heartbeatCookiePathForUrl(String url) {
    return HeartbeatCookieLocator.pathForUrl(url);
  }

  /// Returns an error code, or null when the download was accepted.
  String? _processDownloadPayload(Map<String, dynamic> data) {
    final url = data['url'] as String?;
    final cookies = data['cookies'] as String?;
    final userAgent = data['userAgent'] as String?;

    final isAudioOnly = data['isAudioOnly'] as bool?;
    final isPlaylist = data['isPlaylist'] as bool?;
    final cookieBrowser = data['cookieBrowser'] as String?;
    final preferredQuality = data['preferredQuality'] as String?;

    if (url == null || url.isEmpty) return 'invalid_url';

    // Only accept http(s) download targets from the extension.
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      LoggerService.w('Rejected non-http(s) download URL from extension');
      return 'invalid_url';
    }

    late final String downloadUrl;
    try {
      final referrerRaw = data['referrer'];
      final referrer = referrerRaw is String ? referrerRaw : null;
      final resolved = XDownloadUrl.resolveForDownload(url, referrer);
      if (resolved == null) {
        LoggerService.w(
          'Rejected X CDN download without a tweet permalink: $url',
        );
        return 'need_tweet_url';
      }
      final canonicalUri = Uri.tryParse(resolved);
      if (canonicalUri == null ||
          (canonicalUri.scheme != 'http' && canonicalUri.scheme != 'https') ||
          canonicalUri.host.isEmpty) {
        LoggerService.w('Resolved download URL was not http(s)');
        return 'invalid_url';
      }
      downloadUrl = resolved;
    } catch (e) {
      LoggerService.w('Failed to resolve download URL: $e');
      return 'invalid_url';
    }

    LoggerService.i('📥 Received download request: $downloadUrl');
    if (cookies != null) {
      LoggerService.debug('With Cookies: ${cookies.length} chars');
    }

    if (isPlaylist == true) {
      LoggerService.i('Playlist Mode Detected');
    }

    if (userAgent != null) {
      LoggerService.debug('With UA length: ${userAgent.length}');
    }

    _downloadBatcher.add(
      ExtensionDownloadIngest(
        url: downloadUrl,
        cookies: cookies,
        userAgent: userAgent,
        isAudioOnly: isAudioOnly ?? false,
        isPlaylist: isPlaylist ?? false,
        cookieBrowser: cookieBrowser,
        preferredQuality: preferredQuality,
      ),
    );
    return null;
  }

  void _flushExtensionDownloads(List<ExtensionDownloadIngest> batch) {
    if (batch.isEmpty) return;
    try {
      windowManager.show();
      windowManager.focus();
    } catch (e) {
      LoggerService.w('Failed to show/focus window for extension batch: $e');
    }
    try {
      NotificationService().showLinksQueued(batch.length);
    } catch (e) {
      LoggerService.w('Failed to show batch queued notification: $e');
    }
    unawaited(
      _ref.read(downloadListProvider.notifier).startExtensionDownloads(batch),
    );
  }
}
