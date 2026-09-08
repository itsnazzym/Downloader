import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/transfer/data/localsend_api.dart';
import 'package:modern_downloader/features/transfer/data/localsend_client.dart';
import 'package:modern_downloader/features/transfer/data/transfer_lan_server.dart';
import 'package:modern_downloader/features/transfer/data/trusted_devices_store.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('md-transfer-');
  });

  tearDown(() async {
    try {
      await temp.delete(recursive: true);
    } catch (_) {}
  });

  test('trusted store persists fingerprints atomically', () async {
    final file = File('${temp.path}/trusted.json');
    final store = TrustedDevicesStore(file);
    await store.load();
    await store.add('fp-1');
    final reloaded = TrustedDevicesStore(file);
    await reloaded.load();
    expect(reloaded.contains('fp-1'), isTrue);
  });

  test('prepare-download requires pin then serves file bytes', () async {
    final dest = Directory('${temp.path}/dest')..createSync();
    final payload = File('${temp.path}/clip.mp4')
      ..writeAsStringSync('hello-lan');
    const identity = TransferIdentity(
      alias: 'PC',
      fingerprint: 'self',
      deviceModel: 'test',
      deviceType: TransferDeviceType.desktop,
    );
    final server = TransferLanServer(
      identity: identity,
      destRoot: dest.path,
      isTrusted: (_) => false,
      onIncoming: (_) async => false,
      onPeer: (_) {},
      forbiddenPort: 6969,
    );
    server.setShare(
      ShareOffer(
        pin: '123456',
        files: [
          TransferFile(
            id: 'f1',
            fileName: 'clip.mp4',
            size: payload.lengthSync(),
            localPath: payload.path,
          ),
        ],
      ),
    );
    final port = await server.start(
      preferredPort: 0,
      address: InternetAddress.loopbackIPv4,
      secure: false,
    );
    addTearDown(server.stop);

    final denied = await HttpClient().postUrl(
      Uri.parse('http://127.0.0.1:$port${LocalSendApi.prepareDownloadPath}'),
    );
    final deniedRes = await denied.close();
    expect(deniedRes.statusCode, 401);
    await deniedRes.drain<void>();

    final ok = await HttpClient().postUrl(
      Uri.parse(
        'http://127.0.0.1:$port${LocalSendApi.prepareDownloadPath}?pin=123456',
      ),
    );
    final okRes = await ok.close();
    expect(okRes.statusCode, 200);
    await okRes.drain<void>();
  });

  test('prepare-upload 409 when busy, 401 without pin', () async {
    final dest = Directory('${temp.path}/in')..createSync();
    const identity = TransferIdentity(
      alias: 'PC',
      fingerprint: 'self',
      deviceModel: 'test',
      deviceType: TransferDeviceType.desktop,
    );
    final server = TransferLanServer(
      identity: identity,
      destRoot: dest.path,
      isTrusted: (_) => false,
      onIncoming: (_) async => true,
      onPeer: (_) {},
    );
    server.pin = '999111';
    final port = await server.start(
      preferredPort: 0,
      address: InternetAddress.loopbackIPv4,
    );
    addTearDown(server.stop);

    final client = LocalSendClient();
    addTearDown(client.close);
    const peer = TransferPeer(
      alias: 'phone',
      fingerprint: 'other',
      ip: '127.0.0.1',
      port: 1,
    );
    final unauth = await client.prepareUpload(
      peer: TransferPeer(
        alias: 'phone',
        fingerprint: 'other',
        ip: '127.0.0.1',
        port: port,
      ),
      identity: identity,
      files: const [TransferFile(id: 'a', fileName: 'a.mp4', size: 1)],
    );
    expect(unauth.code, TransferProtocolCode.pinRequired);

    final source = File('${temp.path}/a.mp4')..writeAsStringSync('x');
    final auth = await client.prepareUpload(
      peer: TransferPeer(
        alias: 'phone',
        fingerprint: 'other',
        ip: '127.0.0.1',
        port: port,
      ),
      identity: identity,
      files: [
        TransferFile(
          id: 'a',
          fileName: 'a.mp4',
          size: source.lengthSync(),
          localPath: source.path,
          sha256: null,
        ),
      ],
      pin: '999111',
    );
    expect(auth.isOk, isTrue);

    final busy = await client.prepareUpload(
      peer: TransferPeer(
        alias: 'phone',
        fingerprint: 'other',
        ip: '127.0.0.1',
        port: port,
      ),
      identity: identity,
      files: const [TransferFile(id: 'b', fileName: 'b.mp4', size: 1)],
      pin: '999111',
    );
    expect(busy.code, TransferProtocolCode.busy);
    expect(peer.alias, 'phone');
  });
}
