import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/security/local_server_auth.dart';

/// Lightweight contract checks mirroring LocalServerService auth rules
/// without spinning up the full Riverpod app.
void main() {
  group('WebSocket auth contract', () {
    late HttpServer server;
    late int port;
    const expectedToken = 'test-token-abc';

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      port = server.port;

      server.listen((request) async {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        final socket = await WebSocketTransformer.upgrade(request);
        var authorized = false;
        final helloTimer = Timer(const Duration(seconds: 2), () {
          if (!authorized) {
            socket.add(
              jsonEncode({'type': 'AUTH_FAILED', 'reason': 'hello_timeout'}),
            );
            socket.close();
          }
        });

        socket.listen((message) {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          final type = data['type'] as String?;

          if (type == 'HELLO') {
            final token = LocalServerAuth.tokenFromMessage(data);
            authorized = LocalServerAuth.isAuthorized(
              expectedToken: expectedToken,
              providedToken: token,
            );
            if (authorized) {
              helloTimer.cancel();
              socket.add(jsonEncode({'type': 'HELLO_OK'}));
            } else {
              helloTimer.cancel();
              socket.add(jsonEncode({'type': 'AUTH_FAILED'}));
              socket.close();
            }
            return;
          }

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
          }
        });
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    Future<WebSocket> connect() => WebSocket.connect('ws://127.0.0.1:$port/');

    test('rejects messages before HELLO', () async {
      final ws = await connect();
      final responses = <Map<String, dynamic>>[];
      ws.listen((event) {
        responses.add(jsonDecode(event as String) as Map<String, dynamic>);
      });

      ws.add(jsonEncode({'type': 'PING'}));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(responses, isNotEmpty);
      expect(responses.first['type'], 'AUTH_FAILED');
      expect(responses.first['reason'], 'not_authenticated');
      await ws.close();
    });

    test('HELLO with wrong token fails', () async {
      final ws = await connect();
      final completer = Completer<Map<String, dynamic>>();
      ws.listen((event) {
        if (!completer.isCompleted) {
          completer.complete(
            jsonDecode(event as String) as Map<String, dynamic>,
          );
        }
      });

      ws.add(
        jsonEncode({'type': 'HELLO', 'token': 'wrong', 'version': '2.1.0'}),
      );
      final msg = await completer.future.timeout(const Duration(seconds: 2));
      expect(msg['type'], 'AUTH_FAILED');
      await ws.close();
    });

    test('HELLO with correct token then PING works', () async {
      final ws = await connect();
      final events = <String>[];
      final helloOk = Completer<void>();
      final pong = Completer<void>();

      ws.listen((event) {
        final data = jsonDecode(event as String) as Map<String, dynamic>;
        events.add(data['type'] as String);
        if (data['type'] == 'HELLO_OK') helloOk.complete();
        if (data['type'] == 'PONG') pong.complete();
      });

      ws.add(
        jsonEncode({
          'type': 'HELLO',
          'token': expectedToken,
          'version': '2.1.0',
        }),
      );
      await helloOk.future.timeout(const Duration(seconds: 2));

      ws.add(jsonEncode({'type': 'PING'}));
      await pong.future.timeout(const Duration(seconds: 2));
      expect(events, containsAll(['HELLO_OK', 'PONG']));
      await ws.close();
    });

    test('connection URL must not require query token', () async {
      // Connecting without ?token= must still accept HELLO body auth.
      final ws = await WebSocket.connect('ws://127.0.0.1:$port/');
      final completer = Completer<String>();
      ws.listen((event) {
        final data = jsonDecode(event as String) as Map<String, dynamic>;
        if (!completer.isCompleted) {
          completer.complete(data['type'] as String);
        }
      });
      ws.add(
        jsonEncode({
          'type': 'HELLO',
          'token': expectedToken,
          'version': '2.1.0',
        }),
      );
      expect(
        await completer.future.timeout(const Duration(seconds: 2)),
        'HELLO_OK',
      );
      await ws.close();
    });
  });
}
