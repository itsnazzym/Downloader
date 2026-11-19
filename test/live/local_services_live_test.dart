@Tags(['live'])
library;

import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/transfer/data/localsend_client.dart';
import 'package:modern_downloader/features/transfer/data/transfer_lan_server.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('md_live_lan_'));
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('localsend round trip on loopback keeps a 5 MB file intact', () async {
    final src = File('${temp.path}/source.bin');
    final rnd = Random(42);
    src.writeAsBytesSync(
      List<int>.generate(5 * 1024 * 1024, (_) => rnd.nextInt(256)),
    );
    final expected = sha256.convert(src.readAsBytesSync()).toString();

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
    final peer = TransferPeer(
      alias: 'phone',
      fingerprint: 'other',
      ip: '127.0.0.1',
      port: port,
    );
    final file = TransferFile(
      id: 'f1',
      fileName: 'source.bin',
      size: src.lengthSync(),
      localPath: src.path,
    );

    final outcome = await client.prepareUpload(
      peer: peer,
      identity: identity,
      files: [file],
      pin: '999111',
    );
    expect(outcome.isOk, isTrue, reason: '${outcome.code} ${outcome.message}');

    var sent = 0;
    await client.uploadAll(
      peer: outcome.via ?? peer,
      sessionId: outcome.success!.sessionId,
      tokens: outcome.success!.tokens,
      files: [file],
      onProgress: (delta, _) => sent += delta,
    );

    final received = dest
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('source.bin'))
        .toList();
    expect(received, hasLength(1));
    expect(sent, src.lengthSync());
    expect(sha256.convert(received.single.readAsBytesSync()).toString(), expected);
  });
}
