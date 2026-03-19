import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/config/app_config.dart';
import 'package:modern_downloader/core/providers/launch_provider.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/services/notification_service.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:window_manager/window_manager.dart';

import '../logger/logger_service.dart';

final localServerServiceProvider = Provider<LocalServerService>((ref) {
  return LocalServerService(ref);
});

class LocalServerService {
  static const String _protocolVersion = '1';

  final Ref _ref;
  HttpServer? _server;
  final Set<WebSocket> _clients = <WebSocket>{};
  final Set<WebSocket> _authenticatedClients = <WebSocket>{};
  StreamSubscription<DownloadItem>? _downloadSubscription;

  LocalServerService(this._ref);

  Future<void> start() async {
    if (_server != null) {
      return;
    }

    final settings = _ref.read(settingsProvider);
    final port = settings.serverPort;
    final repo = _ref.read(downloaderRepositoryProvider);

    _downloadSubscription ??= repo.downloadUpdateStream.listen(
      _broadcastProgress,
    );

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      LoggerService.i(
        'Local server running on http://localhost:$port (protocol $_protocolVersion)',
      );
      _server!.listen(_handleRequest);
    } catch (e) {
      LoggerService.e('Failed to start local server on port $port', e);
    }
  }

  Future<void> stop() async {
    for (final client in _clients.toList()) {
      await client.close();
    }
    _clients.clear();
    _authenticatedClients.clear();
    await _downloadSubscription?.cancel();
    _downloadSubscription = null;
    await _server?.close();
    _server = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final origin = request.headers.value('origin');

    if (_isAllowedCorsOrigin(origin)) {
      request.response.headers.set('Access-Control-Allow-Origin', origin!);
      request.response.headers.set('Vary', 'Origin');
    } else {
      request.response.headers.set('Access-Control-Allow-Origin', '*');
    }
    request.response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type',
    );

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    if (WebSocketTransformer.isUpgradeRequest(request)) {
      try {
        if (!_isExtensionOrigin(origin)) {
          request.response.statusCode = HttpStatus.forbidden;
          request.response.write(
            jsonEncode({
              'error': 'forbidden',
              'message': 'Extension origin required.',
            }),
          );
          await request.response.close();
          return;
        }

        final socket = await WebSocketTransformer.upgrade(request);
        _handleWebSocket(socket, request);
      } catch (e) {
        LoggerService.e('WebSocket upgrade failed', e);
      }
      return;
    }

    if (request.uri.path == '/status') {
      request.response.write(
        jsonEncode({
          'status': 'running',
          'mode': 'websocket',
          'protocolVersion': _protocolVersion,
          'appVersion': AppConfig.version,
          'authRequired': true,
        }),
      );
    } else if (request.uri.path == '/extension-config') {
      if (!_isExtensionConfigOrigin(origin)) {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.write(
          jsonEncode({
            'error': 'forbidden',
            'message': 'Extension origin required.',
          }),
        );
      } else {
        final settings = _ref.read(settingsProvider);
        request.response.write(
          jsonEncode({
            'protocolVersion': _protocolVersion,
            'appVersion': AppConfig.version,
            'apiToken': settings.apiToken,
            'port': settings.serverPort,
          }),
        );
      }
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write(
        jsonEncode({'error': 'not_found', 'message': 'Unknown endpoint.'}),
      );
    }

    await request.response.close();
  }

  void _handleWebSocket(WebSocket socket, HttpRequest request) {
    LoggerService.i(
      'Extension connected from ${request.connectionInfo?.remoteAddress.address}',
    );
    _clients.add(socket);

    socket.listen(
      (message) {
        try {
          final data = jsonDecode(message) as Map<String, dynamic>;
          final type = data['type'] as String?;

          if (type == 'PING') {
            socket.add(
              jsonEncode({
                'type': 'PONG',
                'protocolVersion': _protocolVersion,
                'appVersion': AppConfig.version,
              }),
            );
            return;
          }

          if (type == 'HELLO') {
            final validation = _validateHelloPayload(data);
            if (!validation.isValid) {
              _sendError(socket, validation.code, validation.message);
              return;
            }

            _authenticatedClients.add(socket);
            socket.add(
              jsonEncode({
                'type': 'HELLO_ACK',
                'protocolVersion': _protocolVersion,
                'appVersion': AppConfig.version,
              }),
            );
            NotificationService().showExtensionConnected();
            LoggerService.i('Extension authenticated successfully');
            return;
          }

          if (!_authenticatedClients.contains(socket)) {
            _sendError(
              socket,
              'AUTH_REQUIRED',
              'Authenticate with HELLO before sending commands.',
            );
            return;
          }

          if (type == 'DEBUG') {
            if (data['message'] is String) {
              LoggerService.i('EXT DEBUG: ${data['message']}');
            }
            return;
          }

          if (type == 'DOWNLOAD') {
            final validation = _validateDownloadPayload(data);
            if (!validation.isValid) {
              _sendError(socket, validation.code, validation.message);
              return;
            }

            _processDownloadPayload(data);
            socket.add(
              jsonEncode({'type': 'ACK', 'message': 'Download received'}),
            );
            return;
          }

          if (type == 'HEARTBEAT_COOKIES') {
            final validation = _validateHeartbeatPayload(data);
            if (!validation.isValid) {
              _sendError(socket, validation.code, validation.message);
              return;
            }

            _handleHeartbeatCookies(data);
            return;
          }

          _sendError(socket, 'UNKNOWN_TYPE', 'Unsupported message type.');
        } catch (e) {
          LoggerService.e('Error parsing WS message', e);
          _sendError(
            socket,
            'INVALID_JSON',
            'Unable to parse message payload.',
          );
        }
      },
      onDone: () {
        LoggerService.i('Extension disconnected');
        _clients.remove(socket);
        _authenticatedClients.remove(socket);
      },
      onError: (e) {
        LoggerService.e('WebSocket error', e);
        _clients.remove(socket);
        _authenticatedClients.remove(socket);
      },
    );
  }

  void _broadcastProgress(DownloadItem item) {
    if (_authenticatedClients.isEmpty) {
      return;
    }

    final payload = jsonEncode({'type': 'PROGRESS', 'data': item.toJson()});
    for (final client in _authenticatedClients.toList()) {
      if (client.readyState == WebSocket.open) {
        client.add(payload);
      } else {
        _authenticatedClients.remove(client);
        _clients.remove(client);
      }
    }
  }

  Future<void> _handleHeartbeatCookies(Map<String, dynamic> data) async {
    try {
      final domain = data['domain'] as String?;
      final cookies = data['cookies'] as String?;
      if (cookies == null || domain == null) {
        return;
      }

      if (!cookies.contains('\t') && cookies.contains('=')) {
        LoggerService.w(
          'Heartbeat cookies for $domain are not in Netscape format. Ignoring.',
        );
        return;
      }

      final appDir = Directory.systemTemp;
      final cookieFile = File('${appDir.path}/heartbeat_cookies.txt');
      await cookieFile.writeAsString(cookies);
      LoggerService.i('Heartbeat cookies updated for $domain');
      _ref.read(settingsProvider.notifier).setCookiesFilePath(cookieFile.path);
    } catch (e) {
      LoggerService.e('Failed to handle heartbeat cookies', e);
    }
  }

  void _processDownloadPayload(Map<String, dynamic> data) {
    final url = data['url'] as String?;
    final cookies = data['cookies'] as String?;
    final userAgent = data['userAgent'] as String?;
    final isAudioOnly = data['isAudioOnly'] as bool?;
    final isPlaylist = data['isPlaylist'] as bool?;
    final cookieBrowser = data['cookieBrowser'] as String?;

    if (url == null) {
      return;
    }

    LoggerService.i('Received extension download request: $url');
    if (cookies != null) {
      LoggerService.debug('With cookies: ${cookies.length} chars');
    }
    if (userAgent != null) {
      LoggerService.debug('With user agent: $userAgent');
    }
    if (isPlaylist == true) {
      LoggerService.i('Playlist mode detected');
    }

    _ref.read(launchDataProvider.notifier).state = LaunchData.autoStart(
      url,
      cookies: cookies?.trim().isNotEmpty == true ? cookies : null,
      userAgent: userAgent?.trim().isNotEmpty == true ? userAgent : null,
      isAudioOnly: isAudioOnly ?? false,
      isPlaylist: isPlaylist ?? false,
      cookieBrowser: cookieBrowser?.trim().isNotEmpty == true
          ? cookieBrowser
          : null,
    );

    windowManager.show();
    windowManager.focus();
    NotificationService().showClipboardDetected(url);
  }

  bool _isAllowedCorsOrigin(String? origin) {
    return origin == null ||
        origin.startsWith('chrome-extension://') ||
        origin.startsWith('moz-extension://');
  }

  bool _isExtensionOrigin(String? origin) {
    return origin != null &&
        (origin.startsWith('chrome-extension://') ||
            origin.startsWith('moz-extension://'));
  }

  bool _isExtensionConfigOrigin(String? origin) {
    return origin == null || _isExtensionOrigin(origin);
  }

  void _sendError(WebSocket socket, String code, String message) {
    if (socket.readyState == WebSocket.open) {
      socket.add(
        jsonEncode({'type': 'ERROR', 'code': code, 'message': message}),
      );
    }
  }

  _ValidationResult _validateHelloPayload(Map<String, dynamic> data) {
    final protocolVersion = data['protocolVersion'];
    final token = data['token'];
    final settings = _ref.read(settingsProvider);

    if (protocolVersion is! String || protocolVersion.isEmpty) {
      return const _ValidationResult.invalid(
        'INVALID_HELLO',
        'Missing protocol version.',
      );
    }

    if (protocolVersion != _protocolVersion) {
      return _ValidationResult.invalid(
        'PROTOCOL_MISMATCH',
        'Protocol mismatch. Expected $_protocolVersion, got $protocolVersion.',
      );
    }

    if (token is! String || token.trim().isEmpty) {
      return const _ValidationResult.invalid(
        'AUTH_INVALID',
        'Missing API token.',
      );
    }

    if (token != settings.apiToken) {
      return const _ValidationResult.invalid(
        'AUTH_INVALID',
        'Invalid API token.',
      );
    }

    return const _ValidationResult.valid();
  }

  _ValidationResult _validateDownloadPayload(Map<String, dynamic> data) {
    final url = data['url'];
    if (url is! String || url.trim().isEmpty) {
      return const _ValidationResult.invalid(
        'INVALID_DOWNLOAD',
        'Missing download URL.',
      );
    }

    final parsed = Uri.tryParse(url);
    if (parsed == null ||
        !(parsed.scheme == 'http' || parsed.scheme == 'https')) {
      return const _ValidationResult.invalid(
        'INVALID_DOWNLOAD',
        'Download URL must be a valid HTTP or HTTPS URL.',
      );
    }

    if (data['isAudioOnly'] == true) {
      return const _ValidationResult.invalid(
        'VIDEO_ONLY',
        'Audio-only downloads are disabled in the extension.',
      );
    }

    final cookies = data['cookies'];
    if (cookies != null && cookies is! String) {
      return const _ValidationResult.invalid(
        'INVALID_DOWNLOAD',
        'Cookies payload must be a string.',
      );
    }

    final cookieBrowser = data['cookieBrowser'];
    if (cookieBrowser != null && cookieBrowser is! String) {
      return const _ValidationResult.invalid(
        'INVALID_DOWNLOAD',
        'cookieBrowser must be a string.',
      );
    }

    return const _ValidationResult.valid();
  }

  _ValidationResult _validateHeartbeatPayload(Map<String, dynamic> data) {
    if (data['domain'] is! String ||
        (data['domain'] as String).trim().isEmpty) {
      return const _ValidationResult.invalid(
        'INVALID_HEARTBEAT',
        'Missing heartbeat domain.',
      );
    }

    if (data['cookies'] is! String ||
        (data['cookies'] as String).trim().isEmpty) {
      return const _ValidationResult.invalid(
        'INVALID_HEARTBEAT',
        'Missing heartbeat cookies.',
      );
    }

    return const _ValidationResult.valid();
  }
}

class _ValidationResult {
  final bool isValid;
  final String code;
  final String message;

  const _ValidationResult.valid() : isValid = true, code = '', message = '';

  const _ValidationResult.invalid(this.code, this.message) : isValid = false;
}
