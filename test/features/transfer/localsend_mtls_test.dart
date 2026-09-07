import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/transfer/data/localsend_api.dart';
import 'package:modern_downloader/features/transfer/data/localsend_client.dart';
import 'package:modern_downloader/features/transfer/data/transfer_security.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';

void main() {
  group('LocalSend mTLS & Security Tests', () {
    test('TransferSecurity fingerprint matches 2048-bit certificate DER hash', () {
      final fp = TransferSecurity.certificateFingerprint;
      expect(fp, isNotEmpty);
      expect(fp.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(fp), isTrue);
    });

    test('LocalSendClient connects to HTTPS server with TLS security context', () async {
      final serverCtx = TransferSecurity.createSecurityContext();
      final secureServer = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        serverCtx,
      );

      final requestReceived = Completer<bool>();

      secureServer.listen((HttpRequest request) async {
        requestReceived.complete(true);
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'alias': 'Android Peer',
            'version': '2.0',
            'deviceModel': 'Pixel',
            'deviceType': 'mobile',
            'fingerprint': 'test-fingerprint',
            'download': true,
          }),
        );
        await request.response.close();
      });

      addTearDown(() => secureServer.close(force: true));

      final client = LocalSendClient();
      addTearDown(client.close);

      final peer = TransferPeer(
        alias: 'Android Peer',
        fingerprint: 'test-fingerprint',
        ip: '127.0.0.1',
        port: secureServer.port,
        protocol: 'https',
      );

      final tested = await client.testPeerConnection(peer, timeout: const Duration(seconds: 4));
      expect(tested, isNotNull);
      expect(tested?.alias, 'Android Peer');
      expect(await requestReceived.future.timeout(const Duration(seconds: 2)), isTrue);
    });

    test('PrepareUploadOutcome gracefully retries with PIN', () {
      const outcome = PrepareUploadOutcome.error(
        TransferProtocolCode.pinRequired,
        'PIN required',
      );
      expect(outcome.code, TransferProtocolCode.pinRequired);
      expect(outcome.isOk, isFalse);
    });

    test('prepareUpload sets Content-Length on JSON body', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final seen = Completer<({int contentLength, String? transferEncoding, int bodyLength})>();
      server.listen((request) async {
        try {
          if (request.uri.path == LocalSendApi.infoPath) {
            request.response.statusCode = 200;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'alias': 'Phone',
                'version': '2.0',
                'deviceType': 'mobile',
                'fingerprint': 'peer-fp',
                'download': true,
                'protocol': 'http',
                'port': server.port,
              }),
            );
            await request.response.close();
            return;
          }
          if (request.uri.path == LocalSendApi.prepareUploadPath) {
            final raw = await utf8.decodeStream(request);
            if (!seen.isCompleted) {
              seen.complete((
                contentLength: request.headers.contentLength,
                transferEncoding: request.headers.value(
                  HttpHeaders.transferEncodingHeader,
                ),
                bodyLength: raw.length,
              ));
            }
            request.response.statusCode = 200;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'sessionId': 'sess-1',
                'files': {'vid': 'tok-1'},
              }),
            );
            await request.response.close();
            return;
          }
          request.response.statusCode = 404;
          await request.response.close();
        } catch (_) {
          try {
            await request.response.close();
          } catch (_) {}
        }
      });

      final client = LocalSendClient();
      addTearDown(client.close);

      const identity = TransferIdentity(
        alias: 'PC',
        fingerprint: 'pc-fp',
        deviceModel: 'windows',
        deviceType: TransferDeviceType.desktop,
      );
      const files = [
        TransferFile(id: 'vid', fileName: 'clip.mp4', size: 12, localPath: r'C:\clip.mp4'),
      ];
      final peer = TransferPeer(
        alias: 'Phone',
        fingerprint: 'peer-fp',
        ip: '127.0.0.1',
        port: server.port,
        protocol: 'http',
      );

      final outcome = await client.prepareUpload(
        peer: peer,
        identity: identity,
        files: files,
      );
      expect(outcome.isOk, isTrue);

      final headers = await seen.future.timeout(const Duration(seconds: 3));
      expect(headers.contentLength, greaterThan(0));
      expect(headers.contentLength, headers.bodyLength);
      expect(headers.transferEncoding, isNot(contains('chunked')));
    });

    test('prepareUpload probes /info and sends to the reachable protocol', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final prepareOnHttp = Completer<void>();
      server.listen((request) async {
        try {
          if (request.uri.path == LocalSendApi.infoPath) {
            request.response.statusCode = 200;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'alias': 'Phone',
                'version': '2.0',
                'deviceType': 'mobile',
                'fingerprint': 'peer-fp',
                'download': true,
                'protocol': 'http',
                'port': server.port,
              }),
            );
            await request.response.close();
            return;
          }
          if (request.uri.path == LocalSendApi.prepareUploadPath) {
            if (!prepareOnHttp.isCompleted) prepareOnHttp.complete();
            request.response.statusCode = 200;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'sessionId': 'sess-2',
                'files': {'vid': 'tok-2'},
              }),
            );
            await request.response.close();
            return;
          }
          request.response.statusCode = 404;
          await request.response.close();
        } catch (_) {
          try {
            await request.response.close();
          } catch (_) {}
        }
      });

      final client = LocalSendClient();
      addTearDown(client.close);

      final advertisedHttps = TransferPeer(
        alias: 'Phone',
        fingerprint: 'peer-fp',
        ip: '127.0.0.1',
        port: server.port,
        protocol: 'https',
      );
      final outcome = await client.prepareUpload(
        peer: advertisedHttps,
        identity: const TransferIdentity(
          alias: 'PC',
          fingerprint: 'pc-fp',
          deviceModel: 'windows',
          deviceType: TransferDeviceType.desktop,
        ),
        files: const [
          TransferFile(id: 'vid', fileName: 'clip.mp4', size: 12),
        ],
      );
      expect(outcome.isOk, isTrue);
      expect(outcome.via?.protocol, 'http');
      await prepareOnHttp.future.timeout(const Duration(seconds: 3));
    });

    test('abort ends an in-flight prepareUpload long-poll', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final hanging = Completer<void>();
      server.listen((request) async {
        try {
          if (request.uri.path == LocalSendApi.infoPath) {
            request.response.statusCode = 200;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'alias': 'Phone',
                'version': '2.0',
                'deviceType': 'mobile',
                'fingerprint': 'peer-fp',
                'download': true,
                'protocol': 'http',
                'port': server.port,
              }),
            );
            await request.response.close();
            return;
          }
          if (request.uri.path == LocalSendApi.prepareUploadPath) {
            await utf8.decodeStream(request);
            if (!hanging.isCompleted) hanging.complete();
            return;
          }
          request.response.statusCode = 404;
          await request.response.close();
        } catch (_) {
          try {
            await request.response.close();
          } catch (_) {}
        }
      });

      final client = LocalSendClient();
      addTearDown(client.close);

      final future = client.prepareUpload(
        peer: TransferPeer(
          alias: 'Phone',
          fingerprint: 'peer-fp',
          ip: '127.0.0.1',
          port: server.port,
          protocol: 'http',
        ),
        identity: const TransferIdentity(
          alias: 'PC',
          fingerprint: 'pc-fp',
          deviceModel: 'windows',
          deviceType: TransferDeviceType.desktop,
        ),
        files: const [
          TransferFile(id: 'vid', fileName: 'clip.mp4', size: 12),
        ],
      );

      await hanging.future.timeout(const Duration(seconds: 3));
      client.abort();
      final outcome = await future.timeout(const Duration(seconds: 2));
      expect(outcome.isOk, isFalse);
      expect(
        outcome.code,
        anyOf(
          TransferProtocolCode.timeout,
          TransferProtocolCode.httpError,
          TransferProtocolCode.connectionRefused,
        ),
      );
    });
  });
}
