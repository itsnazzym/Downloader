import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/features/downloader/domain/repositories/i_downloader_repository.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/core/download/extension_download_batcher.dart';
import 'package:tapload/core/download/progress_throttle.dart';
import '../logger/logger_service.dart';
import '../theme/extension_theme.dart';
import 'heartbeat_cookie_locator.dart';
import '../services/notification_service.dart';
import '../security/local_server_auth.dart';
import '../security/local_server_download_intake.dart';
import '../../features/x_feed/gobird_x_feed_service.dart';
import 'extension_queue_contract.dart';
import '../../features/x_feed/library_keys_snapshot.dart';
import '../../features/x_feed/x_feed_ws_contract.dart';
import '../../features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'binary/binary_locator.dart';
import '../../features/archive/presentation/providers/tiktok_archive_provider.dart';

final extensionConnectedClientsProvider = StateProvider<int>((ref) => 0);

final localServerServiceProvider = Provider<LocalServerService>((ref) {
  return LocalServerService(ref);
});

class LocalServerService {
  final Ref _ref;
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  final Map<int, Set<WebSocket>> _pendingTikTokSyncClients = {};
  final Map<int, Timer> _pendingTikTokSyncCleanup = {};
  final GobirdXFeedService _gobirdFeedService;
  late final ExtensionDownloadBatcher _downloadBatcher;
  final ProgressBroadcastFilter _progressFilter = ProgressBroadcastFilter();

  /// HELLO must arrive within this window or the socket is closed.
  static const Duration helloTimeout = Duration(seconds: 2);

  @visibleForTesting
  int? get boundPort => _server?.port;

  LocalServerService(
    this._ref, {
    GobirdXFeedService? gobirdFeedService,
    void Function(List<ExtensionDownloadIngest> batch)? onExtensionFlush,
  }) : _gobirdFeedService =
           gobirdFeedService ?? GobirdXFeedService(locator: BinaryLocator()) {
    _downloadBatcher = ExtensionDownloadBatcher(
      onFlush: onExtensionFlush ?? _flushExtensionDownloads,
    );
  }

  StreamSubscription<DownloadItem>? _repoStreamSub;
  ProviderSubscription<IDownloaderRepository>? _repoProviderSub;
  ProviderSubscription<(String, int, String)>? _themeSub;
  Future<void>? _startFuture;

  Future<void> start() {
    if (_server != null) return Future<void>.value();
    final starting = _startFuture;
    if (starting != null) return starting;

    late final Future<void> run;
    run = _start().whenComplete(() {
      if (identical(_startFuture, run)) {
        _startFuture = null;
      }
    });
    _startFuture = run;
    return run;
  }

  Future<void> _start() async {
    final settings = _ref.read(settingsProvider);
    final port = settings.serverPort;

    unawaited(_repoStreamSub?.cancel());
    _repoProviderSub?.close();

    _repoProviderSub = _ref.listen<IDownloaderRepository>(
      downloaderRepositoryProvider,
      (previous, next) {
        if (identical(previous, next)) return;
        unawaited(_repoStreamSub?.cancel());
        _repoStreamSub = next.downloadUpdateStream.listen(_broadcastProgress);
      },
    );

    final repo = _ref.read(downloaderRepositoryProvider);
    _repoStreamSub = repo.downloadUpdateStream.listen(_broadcastProgress);

    // The extension wears the desktop design: push it again when it changes.
    _themeSub?.close();
    _themeSub = _ref.listen<(String, int, String)>(
      settingsProvider.select(
        (s) => (s.themePreset, s.customAccentColor, s.themeMode),
      ),
      (previous, next) => _broadcastTheme(),
    );

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      LoggerService.i('''
==================================================
Local Server running on http://127.0.0.1:$port
WebSocket Mode: ENABLED (Zero-Config)
Ready for Extension Connection
==================================================
''');

      _server!.listen((HttpRequest request) {
        unawaited(_handleRequest(request));
      });
    } catch (e) {
      LoggerService.e('Failed to start Local Server on port $port', e);
    }
  }

  Future<void> stop() async {
    await _repoStreamSub?.cancel();
    _repoStreamSub = null;
    _repoProviderSub?.close();
    _repoProviderSub = null;
    _themeSub?.close();
    _themeSub = null;

    try {
      _downloadBatcher.flush();
      _downloadBatcher.dispose();
    } catch (e) {
      LoggerService.w('Failed to flush extension download batch: $e');
    }
    for (final client in _clients) {
      unawaited(client.close());
    }
    _clients.clear();
    for (final timer in _pendingTikTokSyncCleanup.values) {
      timer.cancel();
    }
    _pendingTikTokSyncCleanup.clear();
    _pendingTikTokSyncClients.clear();
    _ref.read(extensionConnectedClientsProvider.notifier).state = 0;
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
    _ref.read(extensionConnectedClientsProvider.notifier).state =
        _clients.length;
    unawaited(NotificationService().showExtensionConnected());
  }

  void _handleWebSocket(WebSocket socket, HttpRequest request) {
    LoggerService.i(
      'Extension Connected (WebSocket) from ${request.connectionInfo?.remoteAddress.address}',
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
        } catch (e) {
          LoggerService.w('Failed to send HELLO timeout AUTH_FAILED: $e');
        }
        unawaited(socket.close());
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
            LoggerService.i('Extension Hello received');
            if (authorized) {
              helloTimer?.cancel();
              _acceptClient(socket);
              socket.add(jsonEncode({'type': 'HELLO_OK'}));
              _sendTheme(socket);
              _sendLibraryKeys(socket);
            } else {
              helloTimer?.cancel();
              socket.add(jsonEncode({'type': 'AUTH_FAILED'}));
              unawaited(socket.close());
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
            unawaited(_handleHeartbeatCookies(data));
          } else if (type == LibraryKeysSnapshot.requestType) {
            _sendLibraryKeys(socket);
          } else if (type == XFeedWsContract.requestType) {
            unawaited(_handleXFeedRequest(socket, data));
          } else if (type == 'TIKTOK_COLLECTIONS_SYNC') {
            unawaited(_handleTikTokCollectionsSync(socket, data));
          } else if (type == ExtensionQueueContract.snapshotRequest) {
            _sendQueueSnapshot(socket);
          } else if (type == ExtensionQueueContract.command) {
            unawaited(_handleDownloadCommand(socket, data));
          }
        } catch (e) {
          LoggerService.e('Error parsing WS message', e);
        }
      },
      onDone: () {
        helloTimer?.cancel();
        LoggerService.i('Extension Disconnected');
        _clients.remove(socket);
        _ref.read(extensionConnectedClientsProvider.notifier).state =
            _clients.length;
      },
      onError: (e) {
        helloTimer?.cancel();
        LoggerService.e('WebSocket Error', e);
        _clients.remove(socket);
        _ref.read(extensionConnectedClientsProvider.notifier).state =
            _clients.length;
      },
    );
  }

  Map<String, dynamic>? _themeMessage() {
    try {
      return ExtensionTheme.fromSettings(
        _ref.read(settingsProvider),
        platformBrightness:
            WidgetsBinding.instance.platformDispatcher.platformBrightness,
      );
    } catch (e) {
      LoggerService.w('Could not build the extension theme: $e');
      return null;
    }
  }

  void _sendTheme(WebSocket socket) {
    final message = _themeMessage();
    if (message == null || socket.readyState != WebSocket.open) return;
    socket.add(jsonEncode(message));
  }

  void _broadcastTheme() {
    final message = _themeMessage();
    if (message == null) return;
    final payload = jsonEncode(message);
    for (final client in _clients) {
      if (client.readyState == WebSocket.open) client.add(payload);
    }
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

  void _sendQueueSnapshot(WebSocket socket) {
    try {
      if (socket.readyState != WebSocket.open) return;
      final items = _ref
          .read(downloaderRepositoryProvider)
          .getCurrentDownloads()
          .map((item) => item.toExtensionProgressJson())
          .toList();
      if (items.any(
        (i) =>
            i.containsKey('filePath') ||
            i.containsKey('cookies') ||
            i.containsKey('request'),
      )) {
        LoggerService.w('QUEUE_SNAPSHOT rejected: unsanitized fields');
        return;
      }
      socket.add(
        jsonEncode({'type': ExtensionQueueContract.snapshot, 'items': items}),
      );
    } catch (e) {
      LoggerService.w('Failed to send QUEUE_SNAPSHOT: $e');
    }
  }

  Future<void> _handleDownloadCommand(
    WebSocket socket,
    Map<String, dynamic> data,
  ) async {
    final command = data['command'];
    final id = data['id'];

    void reply({String? error}) {
      if (socket.readyState != WebSocket.open) return;
      try {
        socket.add(
          jsonEncode({
            'type': ExtensionQueueContract.commandResult,
            'ok': error == null,
            'command': command is String ? command : '',
            if (id is String) 'id': id,
            if (error != null) 'error': error,
          }),
        );
      } catch (e) {
        LoggerService.w('Failed to send DOWNLOAD_COMMAND_RESULT: $e');
      }
    }

    final invalid = ExtensionQueueContract.validateCommand(data);
    if (invalid != null) return reply(error: invalid);

    try {
      final items = _ref
          .read(downloaderRepositoryProvider)
          .getCurrentDownloads();
      final list = _ref.read(downloadListProvider.notifier);

      if (command == 'cancel_all') {
        for (final item in items.where(_isActive)) {
          await list.cancelDownload(item.id);
        }
        return reply();
      }

      // Only ids the desktop really knows are acted on.
      final matches = items.where((item) => item.id == id);
      if (matches.isEmpty) return reply(error: 'unknown_id');
      final item = matches.first;

      switch (command) {
        case 'cancel':
          await list.cancelDownload(item.id);
        case 'pause':
          await list.pauseDownload(item.id);
        case 'resume':
          await list.resumeDownload(item.id);
        case 'retry':
          await list.retryDownload(item);
      }
      reply();
    } catch (e) {
      LoggerService.w('DOWNLOAD_COMMAND $command failed: $e');
      reply(error: 'command_failed');
    }
  }

  static bool _isActive(DownloadItem item) =>
      item.status == DownloadStatus.queued ||
      item.status == DownloadStatus.extracting ||
      item.status == DownloadStatus.downloading ||
      item.status == DownloadStatus.processing;

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
          'Heartbeat: Received cookies for $domain in Header format (not Netscape). Ignoring to prevent yt-dlp errors.',
        );
        return;
      }

      final safeName = LocalServerAuth.sanitizeDomainForFilename(domain);
      final appDir = Directory.systemTemp;
      final cookieFile = File('${appDir.path}/heartbeat_cookies_$safeName.txt');
      await cookieFile.writeAsString(cookies);
      LoggerService.i(
        'Heartbeat: Updated cookies for $domain -> ${cookieFile.path}',
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
    final result = LocalServerDownloadIntake.parse(data);
    if (!result.isOk) return result.errorCode;
    _downloadBatcher.add(result.ingest!);
    return null;
  }

  void _flushExtensionDownloads(List<ExtensionDownloadIngest> batch) {
    if (batch.isEmpty) return;
    try {
      unawaited(windowManager.show());
      unawaited(windowManager.focus());
    } catch (e) {
      LoggerService.w('Failed to show/focus window for extension batch: $e');
    }
    try {
      unawaited(NotificationService().showLinksQueued(batch.length));
    } catch (e) {
      LoggerService.w('Failed to show batch queued notification: $e');
    }
    unawaited(
      _ref.read(downloadListProvider.notifier).startExtensionDownloads(batch),
    );
  }

  Future<void> _handleTikTokCollectionsSync(
    WebSocket socket,
    Map<String, dynamic> data,
  ) async {
    final notifier = _ref.read(tikTokArchiveProvider.notifier);
    final rawRequestId = data['requestId'];
    final requestId = rawRequestId is num ? rawRequestId.toInt() : null;
    try {
      final rawCollections = data['collections'];
      if (rawCollections is List) {
        final snapshots = <TikTokCollectionSnapshot>[];
        for (final value in rawCollections) {
          if (value is Map) {
            snapshots.add(
              TikTokCollectionSnapshot.fromJson(
                Map<String, dynamic>.from(value),
              ),
            );
          }
        }
        final listComplete = data['collectionListComplete'] == true;
        if (snapshots.isEmpty && !listComplete) {
          final errorCode = (data['error'] ?? 'empty_response').toString();
          final shouldReportFailure = _recordTikTokSyncFailure(
            requestId,
            socket,
          );
          if (shouldReportFailure) {
            notifier.setExtensionSyncResult(
              ok: false,
              message: _tikTokSyncErrorMessage(errorCode),
            );
          }
          if (socket.readyState == WebSocket.open) {
            socket.add(
              jsonEncode({
                'type': 'TIKTOK_COLLECTIONS_SYNC_ACK',
                'ok': false,
                'error': errorCode,
                'requestId': requestId,
              }),
            );
          }
          return;
        }

        if (!_completeTikTokSyncRequest(requestId)) return;

        final incompleteCount = await notifier.applyCollectionSync(
          snapshots,
          collectionListComplete: listComplete,
        );
        final completeCount = snapshots.length - incompleteCount;
        final verifiedVideoCount = snapshots
            .expand((snapshot) => snapshot.videoIds)
            .toSet()
            .length;
        final partial = incompleteCount > 0 || !listComplete;
        final summary = notifier.classificationSummary;
        final overview = summary == null ? '' : ' $summary.';
        final message = partial
            ? '$verifiedVideoCount vidéos retrouvées dans ${snapshots.length} collections. '
                  '$incompleteCount collections incomplètes ; leurs vidéos retrouvées sont enregistrées.$overview'
            : '${snapshots.length} collections et $verifiedVideoCount vidéos synchronisées.$overview';
        notifier.setExtensionSyncResult(
          ok: true,
          partial: partial,
          message: message,
        );
        if (socket.readyState == WebSocket.open) {
          socket.add(
            jsonEncode({
              'type': 'TIKTOK_COLLECTIONS_SYNC_ACK',
              'ok': true,
              'partial': partial,
              'collectionCount': completeCount,
              'incompleteCount': incompleteCount,
              'verifiedVideoCount': verifiedVideoCount,
              'collectionListComplete': listComplete,
              'requestId': requestId,
            }),
          );
        }
        LoggerService.i(
          'Reconciled $completeCount complete TikTok collections; incomplete=$incompleteCount',
        );
        return;
      }

      // Older extensions send a name-to-IDs map without completion markers.
      // Keep those IDs in the review queue; never treat them as a full snapshot.
      if (rawCollections is Map && rawCollections.isNotEmpty) {
        if (!_completeTikTokSyncRequest(requestId)) return;
        final mapping = <String, List<String>>{};
        for (final entry in rawCollections.entries) {
          if (entry.value is List) {
            mapping[entry.key.toString()] = (entry.value as List)
                .map((value) => value.toString())
                .toList();
          }
        }
        final rawTotals = data['collectionTotals'];
        final totals = <String, int>{};
        if (rawTotals is Map) {
          for (final entry in rawTotals.entries) {
            final value = entry.value;
            if (value is num) {
              totals[entry.key.toString()] = value.toInt();
            } else if (value is String) {
              final parsed = int.tryParse(value);
              if (parsed != null) totals[entry.key.toString()] = parsed;
            }
          }
        }
        await notifier.updateCollectionMapping(
          mapping,
          collectionTotals: totals,
        );
        const message =
            'Ancien format reçu : les propositions sont à vérifier. Mets à jour l’extension.';
        notifier.setExtensionSyncResult(
          ok: true,
          partial: true,
          message: message,
        );
        if (socket.readyState == WebSocket.open) {
          socket.add(
            jsonEncode({
              'type': 'TIKTOK_COLLECTIONS_SYNC_ACK',
              'ok': true,
              'partial': true,
              'legacyFormat': true,
              'collectionCount': mapping.length,
              'requestId': requestId,
            }),
          );
        }
        return;
      }

      final errorCode = (data['error'] ?? 'empty_response').toString();
      final shouldReportFailure = _recordTikTokSyncFailure(requestId, socket);
      if (shouldReportFailure) {
        notifier.setExtensionSyncResult(
          ok: false,
          message: _tikTokSyncErrorMessage(errorCode),
        );
      }
      if (socket.readyState == WebSocket.open) {
        socket.add(
          jsonEncode({
            'type': 'TIKTOK_COLLECTIONS_SYNC_ACK',
            'ok': false,
            'error': errorCode,
            'requestId': requestId,
          }),
        );
      }
    } catch (e, st) {
      LoggerService.e('Failed to process TikTok collections sync', e, st);
      notifier.setExtensionSyncResult(
        ok: false,
        message: 'Échec de la synchronisation : $e',
      );
      if (socket.readyState == WebSocket.open) {
        socket.add(
          jsonEncode({
            'type': 'TIKTOK_COLLECTIONS_SYNC_ACK',
            'ok': false,
            'error': e.toString(),
          }),
        );
      }
    }
  }

  bool _recordTikTokSyncFailure(int? requestId, WebSocket socket) {
    if (requestId == null) return true;
    final pending = _pendingTikTokSyncClients[requestId];
    if (pending == null) return false;
    pending.remove(socket);
    if (pending.isNotEmpty) return false;
    _clearTikTokSyncRequest(requestId);
    return true;
  }

  bool _completeTikTokSyncRequest(int? requestId) {
    if (requestId == null) return true;
    if (!_pendingTikTokSyncClients.containsKey(requestId)) return false;
    _clearTikTokSyncRequest(requestId);
    return true;
  }

  void _clearTikTokSyncRequest(int requestId) {
    _pendingTikTokSyncClients.remove(requestId);
    _pendingTikTokSyncCleanup.remove(requestId)?.cancel();
  }

  String _tikTokSyncErrorMessage(String errorCode) {
    return switch (errorCode) {
      'no_tiktok_tab' =>
        'Aucun onglet TikTok détecté. Ouvre tes Favoris > Collections dans le navigateur puis réessaie.',
      'no_collections' =>
        'Aucune collection visible. Ouvre tes Favoris > Collections dans TikTok puis réessaie.',
      'collection_items_unavailable' =>
        'TikTok a refusé l’accès aux vidéos des collections. Recharge la page TikTok puis réessaie.',
      _ => 'Synchronisation TikTok impossible ($errorCode).',
    };
  }

  /// Sends a request to all connected browser extensions to extract TikTok collections.
  int requestTikTokCollectionsSync({required int requestId}) {
    final payload = jsonEncode({
      'type': 'REQUEST_TIKTOK_COLLECTIONS_SYNC',
      'requestId': requestId,
    });
    var sentCount = 0;
    final recipients = <WebSocket>{};
    for (final client in _clients) {
      if (client.readyState == WebSocket.open) {
        try {
          client.add(payload);
          sentCount++;
          recipients.add(client);
        } catch (e) {
          LoggerService.w('Failed to send REQUEST_TIKTOK_COLLECTIONS_SYNC: $e');
        }
      }
    }
    if (recipients.isNotEmpty) {
      _pendingTikTokSyncClients[requestId] = recipients;
      _pendingTikTokSyncCleanup.remove(requestId)?.cancel();
      _pendingTikTokSyncCleanup[requestId] = Timer(
        const Duration(minutes: 16),
        () {
          _pendingTikTokSyncClients.remove(requestId);
          _pendingTikTokSyncCleanup.remove(requestId);
        },
      );
    }
    return sentCount;
  }
}
