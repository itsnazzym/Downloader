import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/features/transfer/data/localsend_api.dart';
import 'package:tapload/features/transfer/data/localsend_client.dart';
import 'package:tapload/features/transfer/data/transfer_discovery.dart';
import 'package:tapload/features/transfer/data/transfer_security.dart';
import 'package:tapload/features/transfer/data/trusted_devices_store.dart';
import 'package:tapload/features/transfer/domain/transfer_models.dart';

void main() {
  group('TransferDiscovery & Mutual Peer Recognition Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('transfer_discovery_test');
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('TransferIdentityStore generates and persists deviceId and fingerprint', () async {
      final file = File('${tempDir.path}/identity.json');
      final store = TransferIdentityStore(file);

      final id1 = await store.loadOrCreateIdentity(
        fixedFingerprint: TransferSecurity.certificateFingerprint,
      );
      expect(id1.fingerprint, TransferSecurity.certificateFingerprint);
      expect(id1.deviceId, isNotEmpty);

      // Second load preserves same deviceId and fingerprint
      final store2 = TransferIdentityStore(file);
      final id2 = await store2.loadOrCreateIdentity(
        fixedFingerprint: TransferSecurity.certificateFingerprint,
      );
      expect(id2.fingerprint, id1.fingerprint);
      expect(id2.deviceId, id1.deviceId);
    });

    test('Two TapLoad peers with same certificate fingerprint discover each other via HTTP probe', () async {
      final serverCtx = TransferSecurity.createSecurityContext();
      final secureServer = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        serverCtx,
      );

      const phoneDeviceId = 'phone-device-uuid-1234';
      const pcDeviceId = 'pc-device-uuid-5678';
      const sharedFingerprint = 'shared-cert-fingerprint-abc';

      // Mock Phone HTTPS server
      secureServer.listen((HttpRequest request) async {
        if (request.uri.path == LocalSendApi.infoPath) {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'alias': 'Pixel Phone',
              'version': '2.0',
              'deviceModel': 'Pixel 8',
              'deviceType': 'mobile',
              'fingerprint': sharedFingerprint,
              'deviceId': phoneDeviceId,
              'download': true,
              'port': secureServer.port,
              'protocol': 'https',
            }),
          );
          await request.response.close();
        } else if (request.uri.path == LocalSendApi.registerPath) {
          request.response.statusCode = 200;
          request.response.write(jsonEncode({'status': 'ok'}));
          await request.response.close();
        }
      });
      addTearDown(() => secureServer.close(force: true));

      final client = LocalSendClient();
      addTearDown(client.close);

      final discoveredPeers = <TransferPeer>[];
      const pcIdentity = TransferIdentity(
        alias: 'Windows PC',
        fingerprint: sharedFingerprint,
        deviceId: pcDeviceId,
        deviceModel: 'Windows',
        deviceType: TransferDeviceType.desktop,
      );

      final discovery = TransferDiscovery(
        identity: pcIdentity,
        client: client,
        onPeer: (peer) => discoveredPeers.add(peer),
      );

      // Probe the mock Phone
      final peer = await discovery.probeIp(
        '127.0.0.1',
        port: secureServer.port,
      );

      expect(peer, isNotNull);
      expect(peer?.alias, 'Pixel Phone');
      expect(peer?.deviceId, phoneDeviceId);
      expect(peer?.fingerprint, sharedFingerprint);
      expect(discoveredPeers.length, 1);
      expect(discoveredPeers.first.alias, 'Pixel Phone');
    });

    test('Probe rejects when target is the exact same device instance (loopback)', () async {
      final serverCtx = TransferSecurity.createSecurityContext();
      final secureServer = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        serverCtx,
      );

      const myDeviceId = 'my-device-uuid-9999';
      const sharedFingerprint = 'shared-cert-fingerprint-abc';

      secureServer.listen((HttpRequest request) async {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'alias': 'Myself',
            'version': '2.0',
            'deviceModel': 'Windows',
            'deviceType': 'desktop',
            'fingerprint': sharedFingerprint,
            'deviceId': myDeviceId,
            'download': true,
          }),
        );
        await request.response.close();
      });
      addTearDown(() => secureServer.close(force: true));

      final client = LocalSendClient();
      addTearDown(client.close);

      final discoveredPeers = <TransferPeer>[];
      const myIdentity = TransferIdentity(
        alias: 'Myself',
        fingerprint: sharedFingerprint,
        deviceId: myDeviceId,
        deviceModel: 'Windows',
        deviceType: TransferDeviceType.desktop,
      );

      final discovery = TransferDiscovery(
        identity: myIdentity,
        client: client,
        onPeer: (peer) => discoveredPeers.add(peer),
      );

      final peer = await discovery.probeIp(
        '127.0.0.1',
        port: secureServer.port,
      );

      // Should be rejected because deviceId matches my own deviceId
      expect(peer, isNull);
      expect(discoveredPeers.isEmpty, isTrue);
    });
  });
}
