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
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/core/download/extension_download_batcher.dart';
import 'package:tapload/core/download/progress_throttle.dart';
import '../logger/logger_service.dart';
import '../theme/extension_theme.dart';
import 'heartbeat_cookie_locator.dart';
import '../services/notification_service.dart';
import '../security/extension_origin.dart';
import '../security/local_server_auth.dart';
import '../security/local_server_download_intake.dart';
import '../security/paired_browsers.dart';
import '../security/pairing_coordinator.dart';
import 'extension_pairing_contract.dart';
import '../../features/x_feed/gobird_x_feed_service.dart';
import 'extension_queue_contract.dart';
import '../../features/x_feed/library_keys_snapshot.dart';
import '../../features/x_feed/x_feed_ws_contract.dart';
import '../../features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'binary/binary_locator.dart';
import '../../features/archive/presentation/providers/tiktok_archive_provider.dart';

typedef _Msg = ExtensionPairingContract;

final extensionConnectedClientsProvider = StateProvider<int>((ref) => 0);

final localServerServiceProvider = Provider<LocalServerService>((ref) {
  final service = LocalServerService(ref);
  ref.onDispose(() => unawaited(service.stop()));
  return service;
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

  // Every open socket, authenticated or not, with its handshake state.
  final Map<WebSocket, _Connection> _connections = {};
  // The one socket waiting on each pairing request: only it gets the token.
  final Map<String, _Connection> _adopters = {};
  // Notified once per app session: 'manual' or a paired token's hash.
  final Set<String> _notified = {};
  final Future<void> Function() _showExtensionConnected;
  ProviderSubscription<PairedBrowsersState>? _pairedSub;
  StreamSubscription<PairedBrowser>? _revokedSub;

  /// HELLO must arrive within this window or the socket is closed.
  final Duration helloTimeout;

  /// After `AUTH_FAILED pairing_required`, time left to send `PAIR_REQUEST`.
  final Duration pairRequestWindow;

  /// `PAIR_PENDING` is repeated this often: Chrome kills an extension service
  /// worker after ~30 s without traffic.
  final Duration pendingKeepAlive;

  /// Unauthenticated sockets (pending ones included) held at once; more get
  /// 503 before the upgrade, so a local flood cannot pin sockets and timers.
  final int maxUnauthenticatedSockets;

  static const _maxUnauthenticatedFrame = 4096;
  static const _maxHelloAttempts = 5;
  var _upgrading = 0; // upgrades in flight, counted against the cap

  @visibleForTesting
  int? get boundPort => _server?.port;

  @visibleForTesting
  int get liveConnectionCount => _connections.length;

  LocalServerService(
    this._ref, {
    GobirdXFeedService? gobirdFeedService,
    void Function(List<ExtensionDownloadIngest> batch)? onExtensionFlush,
    this.helloTimeout = const Duration(seconds: 2),
    this.pairRequestWindow = const Duration(seconds: 10),
    this.pendingKeepAlive = const Duration(seconds: 10),
    this.maxUnauthenticatedSockets = 32,
    Future<void> Function()? showExtensionConnected,
  }) : _gobirdFeedService =
           gobirdFeedService ?? GobirdXFeedService(locator: BinaryLocator()),
       _showExtensionConnected =
           showExtensionConnected ??
           NotificationService().showExtensionConnected {
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

    // A revocation cuts that browser's sockets at once. The state listener
    // also covers a revoke whose save failed (state changed, no event).
    _pairedSub?.close();
    _pairedSub = _ref.listen<PairedBrowsersState>(pairedBrowsersProvider, (
      previous,
      next,
    ) {
      final live = {for (final b in next.browsers) b.id};
      _closeRevoked((id) => !live.contains(id));
    });
    unawaited(_revokedSub?.cancel());
    _revokedSub = _ref
        .read(pairedBrowsersProvider.notifier)
        .revoked
        .listen((gone) => _closeRevoked((id) => id == gone.id));

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
    _pairedSub?.close();
    _pairedSub = null;
    await _revokedSub?.cancel();
    _revokedSub = null;

    try {
      _downloadBatcher.flush();
      _downloadBatcher.dispose();
    } catch (e) {
      LoggerService.w('Failed to flush extension download batch: $e');
    }
    // Pending and windowed sockets too, with their timers.
    for (final c in _connections.values) {
      _close(c);
    }
    _connections.clear();
    _adopters.clear();
    _clients.clear();
    for (final timer in _pendingTikTokSyncCleanup.values) {
      timer.cancel();
    }
    _pendingTikTokSyncCleanup.clear();
    _pendingTikTokSyncClients.clear();
    try {
      _ref.read(extensionConnectedClientsProvider.notifier).state = 0;
    } catch (_) {} // stopped by the provider's onDispose: the container is gone
    await _server?.close();
    _server = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      await _route(request);
    } catch (e) {
      // Never let a malformed request escape unanswered (client would hang).
      LoggerService.w('Local server request failed: $e');
      try {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _route(HttpRequest request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      // A web page cannot forge Origin: refuse any present non-extension one.
      // List semantics: value() throws on a duplicated header.
      final origins = request.headers['origin'];
      if (origins != null &&
          (origins.length != 1 ||
              !ExtensionOrigin.isExtensionOrigin(origins.single))) {
        LoggerService.w(
          'WebSocket refused: origin rejected:${origins.length == 1 ? ExtensionOrigin.originScheme(origins.single) : 'multiple'}',
        );
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        return;
      }
      final origin = origins?.single;
      final agents = request.headers['user-agent'];
      final label = ExtensionOrigin.browserLabel(
        agents?.length == 1 ? agents!.single : null,
      );
      // shortcut: one global cap, so a local flood can 503 paired browsers.
      final unauthenticated = _connections.values.where((c) => !c.authorized);
      if (unauthenticated.length + _upgrading >= maxUnauthenticatedSockets) {
        LoggerService.w('WebSocket refused: too many unauthenticated sockets');
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
        return;
      }
      final WebSocket socket;
      _upgrading++;
      try {
        socket = await WebSocketTransformer.upgrade(request);
      } catch (e) {
        LoggerService.e('WebSocket upgrade failed', e);
        // A throw (e.g. duplicated Sec-WebSocket-Extensions) can leave the 101
        // headers staged and nothing sent: answer a clean 400, never hang.
        try {
          request.response.headers
            ..removeAll(HttpHeaders.connectionHeader)
            ..removeAll(HttpHeaders.upgradeHeader)
            ..removeAll('sec-websocket-accept');
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
        } catch (_) {} // the transformer already answered
        return;
      } finally {
        _upgrading--;
      }
      _handleWebSocket(
        socket,
        request,
        extensionOrigin: ExtensionOrigin.isExtensionOrigin(origin)
            ? cleanPairingOrigin(origin!)
            : null,
        label: label,
        originScheme: ExtensionOrigin.originScheme(origin),
      );
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

  void _publishClientCount() =>
      _ref.read(extensionConnectedClientsProvider.notifier).state =
          _clients.length;

  /// Once per app session and per browser (or for the manual token), so a
  /// reconnecting extension does not notify again.
  void _notifyConnected(String key) {
    if (!_notified.add(key)) return;
    unawaited(
      Future.sync(_showExtensionConnected).catchError(
        (Object e) => LoggerService.w('Connected notification failed: $e'),
      ),
    );
  }

  /// Never throws: timer and outcome callbacks send through here.
  void _send(_Connection c, Map<String, dynamic> message) {
    if (c.closed || c.socket.readyState != WebSocket.open) return;
    try {
      c.socket.add(jsonEncode(message));
    } catch (e) {
      LoggerService.w('Failed to send ${message['type']}: $e');
    }
  }

  void _close(_Connection c) {
    c.closed = true;
    c.cancelTimers();
    unawaited(c.socket.close());
  }

  void _closeRevoked(bool Function(String browserId) revoked) {
    var dropped = false;
    for (final c in _connections.values.toList()) {
      final id = c.browserId;
      if (id == null || !revoked(id)) continue;
      c.authorized = false;
      c.browserId = null;
      dropped = _clients.remove(c.socket) || dropped;
      _close(c);
    }
    if (dropped) _publishClientCount();
  }

  void _onSocketGone(_Connection c, Object? error) {
    c.closed = true;
    c.cancelTimers();
    if (error == null) {
      LoggerService.i('Extension Disconnected');
    } else {
      LoggerService.e('WebSocket Error', error);
    }
    // Already dropped by stop(): leave _ref alone, it may be disposed.
    if (_connections.remove(c.socket) == null) return;
    // The only socket that knew the code is gone: withdraw its request so a
    // reconnect gets a new one (new id, new code) to compare again.
    for (final id in [
      for (final e in _adopters.entries)
        if (identical(e.value, c)) e.key,
    ]) {
      _adopters.remove(id);
      _ref.read(pairingCoordinatorProvider.notifier).withdraw(id);
    }
    if (_clients.remove(c.socket)) _publishClientCount();
  }

  void _accept(_Connection c, String notifyKey, String? browserId) {
    c.authorized = true;
    c.browserId = browserId;
    c.deadline?.cancel();
    if (!_clients.contains(c.socket)) {
      _clients.add(c.socket);
      _publishClientCount();
    }
    _notifyConnected(notifyKey);
    _send(c, {'type': _Msg.helloOk});
    _sendTheme(c.socket);
    _sendLibraryKeys(c.socket);
  }

  void _onHello(_Connection c, Map<String, dynamic> data) {
    LoggerService.i('Extension Hello received');
    // A socket waiting for the user's decision cannot switch to a token.
    if (c.pairing) {
      _send(c, _Msg.authFailedMessage(_Msg.notAuthenticated));
      return;
    }
    if (!c.authorized && ++c.helloAttempts > _maxHelloAttempts) {
      LoggerService.w('WebSocket closed: too many HELLO attempts');
      _close(c);
      return;
    }
    final token = LocalServerAuth.tokenFromMessage(data);
    if (_isAuthorized(token)) return _accept(c, 'manual', null);
    final browser = token == null
        ? null
        : _ref.read(pairedBrowsersProvider.notifier).authenticate(token);
    if (browser != null) return _accept(c, browser.tokenHash, browser.id);

    if (c.origin == null || c.authorized) {
      // Not an extension (or a re-HELLO): refuse and close, as always.
      c.authorized = false;
      if (_clients.remove(c.socket)) _publishClientCount();
      _send(c, _Msg.authFailedMessage());
      _close(c);
      return;
    }
    _send(c, _Msg.authFailedMessage(_Msg.pairingRequired));
    if (c.windowOpen) return; // a repeated HELLO never extends the window
    c.windowOpen = true;
    c.deadline?.cancel();
    c.deadline = Timer(pairRequestWindow, () {
      if (!c.pairing && !c.authorized) _close(c);
    });
  }

  /// Only ever SUBMITS: approving or denying is the app UI's job, and no
  /// message can trigger it.
  void _onPairRequest(_Connection c) {
    final origin = c.origin!;
    final store = _ref.read(pairedBrowsersProvider.notifier);
    final coordinator = _ref.read(pairingCoordinatorProvider.notifier);
    // Origin from the real header, label from the User-Agent: nothing the
    // client wrote in its message is used.
    final submitted = coordinator.submit(origin: origin, label: c.label);
    final request = submitted.request;
    final outcome = submitted.outcome;
    if (request == null || outcome == null) {
      LoggerService.i('Pairing request refused: ${submitted.refusal?.name}');
      _send(c, switch (submitted.refusal) {
        PairingRefusal.paused => _Msg.paused(
          submitted.retryAfter ?? Duration.zero,
        ),
        PairingRefusal.rateLimited => _Msg.paused(
          submitted.retryAfter ?? Duration.zero,
          reason: _Msg.rateLimited,
        ),
        PairingRefusal.blocked => _Msg.denied(_Msg.blockedRetryAfter),
        PairingRefusal.busy || PairingRefusal.full || null => _Msg.busy(),
      });
      _close(c);
      return;
    }
    LoggerService.i('Pairing request pending');
    // Only now: a throw above leaves the HELLO deadline armed.
    c.pairing = true;
    c.deadline?.cancel();
    void remind() =>
        _send(c, _Msg.pending(request, coordinator.expiresIn(request)));
    remind();
    c.keepAlive = Timer.periodic(pendingKeepAlive, (_) => remind());
    // The one socket of this request (any other submit is busy until it ends).
    _adopters[request.id] = c;
    unawaited(
      outcome
          .then((result) {
            // shortcut: a socket that closes while the approval is being
            // stored cannot withdraw it: the browser is stored but its token
            // is never delivered (a dead entry the user can revoke).
            if (c.closed || !identical(_adopters[request.id], c)) return;
            _adopters.remove(request.id);
            switch (result) {
              case PairingApproved(:final token):
                _send(c, _Msg.ok(token));
                _notifyConnected(PairedBrowsersStore.hashToken(token));
              case PairingDenied(:final retryAfter):
                // deny(always) blocked the origin: say so, not 10 minutes.
                _send(
                  c,
                  _Msg.denied(
                    store.isBlocked(origin)
                        ? _Msg.blockedRetryAfter
                        : retryAfter,
                  ),
                );
              case PairingExpired():
                _send(c, _Msg.expired());
              case PairingFailed():
                // Not stored: no pause applies, the extension may retry.
                _send(c, _Msg.busy());
            }
            _close(c);
          })
          .catchError((Object e) {
            LoggerService.w('Pairing outcome failed: $e');
            if (identical(_adopters[request.id], c)) {
              _adopters.remove(request.id);
            }
            _close(c);
          }),
    );
  }

  /// [extensionOrigin] is the cleaned Origin of an extension socket, null
  /// without one: such a socket may authenticate with a token, never pair.
  void _handleWebSocket(
    WebSocket socket,
    HttpRequest request, {
    required String? extensionOrigin,
    required String label,
    required String originScheme,
  }) {
    LoggerService.i(
      'Extension Connected (WebSocket) from ${request.connectionInfo?.remoteAddress.address}, origin $originScheme',
    );

    final c = _Connection(socket, extensionOrigin, label);
    _connections[socket] = c;

    // Token must arrive via HELLO message body — never from the URL query.
    c.deadline = Timer(helloTimeout, () {
      if (c.authorized || c.pairing) return;
      LoggerService.w('WebSocket closed: HELLO auth timeout');
      _send(c, _Msg.authFailedMessage(_Msg.helloTimeout));
      _close(c);
    });

    socket.listen(
      (message) {
        if (c.closed) return;
        // Before authentication only small JSON text is read; anything else
        // closes the socket, logged without its payload.
        // shortcut: dart:io has already buffered the whole frame (local DoS).
        if (!c.authorized &&
            (message is! String || message.length > _maxUnauthenticatedFrame)) {
          LoggerService.w('WebSocket closed: unauthenticated frame refused');
          _close(c);
          return;
        }
        try {
          final data = jsonDecode(message) as Map<String, dynamic>;
          final type = data['type'] as String?;

          if (type == _Msg.hello) {
            _onHello(c, data);
            return;
          }

          if (type == _Msg.pairRequest && c.mayRequestPairing) {
            _onPairRequest(c);
            return;
          }

          // Refuse every other message until HELLO succeeds.
          if (!c.authorized) {
            _send(c, _Msg.authFailedMessage(_Msg.notAuthenticated));
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
          if (!c.authorized) {
            LoggerService.w(
              'WebSocket closed: malformed unauthenticated frame',
            );
            _close(c);
            return;
          }
          // The type only: a FormatException quotes its source (a token).
          LoggerService.e('Error parsing WS message: ${e.runtimeType}');
        }
      },
      onDone: () => _onSocketGone(c, null),
      onError: (Object e) => _onSocketGone(c, e),
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
      final items = ExtensionQueueContract.snapshotItems(
        _ref.read(downloaderRepositoryProvider).getCurrentDownloads(),
      ).map((item) => item.toExtensionProgressJson()).toList();
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
      final repo = _ref.read(downloaderRepositoryProvider);
      final list = _ref.read(downloadListProvider.notifier);
      // Fresh lookup each time: an item can finish during an earlier await.
      DownloadItem? current(Object? itemId) {
        for (final item in repo.getCurrentDownloads()) {
          if (item.id == itemId) return item;
        }
        return null;
      }

      if (command == 'cancel_all') {
        final ids = repo
            .getCurrentDownloads()
            .where((i) => ExtensionQueueContract.isActive(i.status))
            .map((i) => i.id)
            .toList();
        for (final itemId in ids) {
          final item = current(itemId);
          if (item == null || !ExtensionQueueContract.isActive(item.status)) {
            continue;
          }
          await list.cancelDownload(itemId);
        }
        return reply();
      }

      // Only ids the desktop really knows are acted on.
      final item = current(id);
      if (item == null) return reply(error: 'unknown_id');
      // A command that does not fit the status could delete or rewrite a
      // finished download (retry deletes the file first).
      if (!ExtensionQueueContract.allows(command as String, item.status)) {
        return reply(error: 'invalid_state');
      }

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

/// Handshake state of one socket. Its timers all live here so that one
/// [cancelTimers] covers every close path.
class _Connection {
  _Connection(this.socket, this.origin, this.label);

  final WebSocket socket;

  /// Cleaned extension Origin header; null: may authenticate, never pair.
  final String? origin;

  /// From the User-Agent header, never from a message.
  final String label;

  var authorized = false;
  String? browserId; // paired browser behind the token, for revocation
  var pairing = false; // PAIR_REQUEST accepted, once per socket
  var windowOpen = false;
  var helloAttempts = 0;
  var closed = false;
  Timer? deadline; // HELLO timeout, then the PAIR_REQUEST window
  Timer? keepAlive; // PAIR_PENDING reminders

  /// Only after `AUTH_FAILED pairing_required` opened the window.
  bool get mayRequestPairing =>
      origin != null && windowOpen && !authorized && !pairing;

  void cancelTimers() {
    deadline?.cancel();
    keepAlive?.cancel();
  }
}
