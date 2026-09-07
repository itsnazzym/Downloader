import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/transfer/data/localsend_api.dart';
import 'package:modern_downloader/features/transfer/data/payload_scanner.dart';
import 'package:modern_downloader/features/transfer/data/transfer_lan_server.dart';
import 'package:modern_downloader/features/transfer/data/transfer_zip_bundle.dart';
import 'package:modern_downloader/features/transfer/domain/library_manifest.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('md-zip-');
  });

  tearDown(() async {
    try {
      await temp.delete(recursive: true);
    } catch (_) {}
  });

  test('zip keeps folder / subfolder / mp4 paths', () async {
    final a = File('${temp.path}${Platform.pathSeparator}a.mp4')
      ..writeAsStringSync('video-a');
    final b = File('${temp.path}${Platform.pathSeparator}b.mp4')
      ..writeAsStringSync('video-b');
    final files = [
      TransferFile(
        id: '1',
        fileName: 'neo/clips/a.mp4',
        size: a.lengthSync(),
        localPath: a.path,
        creatorHandle: 'neo',
      ),
      TransferFile(
        id: '2',
        fileName: 'neo/clips/b.mp4',
        size: b.lengthSync(),
        localPath: b.path,
        creatorHandle: 'neo',
      ),
    ];
    expect(TransferZipBundle.archiveName(files), 'neo');
    final zip = await TransferZipBundle.writeToTemp(files, tempDir: temp);
    addTearDown(() async {
      try {
        await zip.delete();
      } catch (_) {}
    });
    final decoded = ZipDecoder().decodeBytes(await zip.readAsBytes());
    expect(decoded.findFile('neo/clips/a.mp4')?.content, isNotNull);
    expect(
      String.fromCharCodes(
        decoded.findFile('neo/clips/a.mp4')!.content as List<int>,
      ),
      'video-a',
    );
    expect(decoded.findFile('neo/clips/b.mp4'), isNotNull);
    expect(decoded.findFile(LibraryManifest.fileName), isNull);
  });

  test('scanner and zip skip jpg and part leftovers', () async {
    final dir = Directory('${temp.path}${Platform.pathSeparator}neo')
      ..createSync();
    File('${dir.path}${Platform.pathSeparator}keep.mp4').writeAsStringSync('v');
    File(
      '${dir.path}${Platform.pathSeparator}thumb.jpg',
    ).writeAsStringSync('j');
    File(
      '${dir.path}${Platform.pathSeparator}keep.mp4.part',
    ).writeAsStringSync('p');
    final scanned = await PayloadScanner.scanDirectories([dir], hash: false);
    expect(scanned.files.map((f) => f.fileName), ['neo/keep.mp4']);
    final zip = await TransferZipBundle.writeToTemp([
      ...scanned.files,
      TransferFile(
        id: 'jpg',
        fileName: 'neo/thumb.jpg',
        size: 1,
        localPath: '${dir.path}${Platform.pathSeparator}thumb.jpg',
      ),
    ], tempDir: temp);
    final decoded = ZipDecoder().decodeBytes(await zip.readAsBytes());
    expect(decoded.findFile('neo/keep.mp4'), isNotNull);
    expect(decoded.findFile('neo/thumb.jpg'), isNull);
    expect(decoded.findFile('neo/keep.mp4.part'), isNull);
  });

  test('library items sit under creator folder in the zip', () async {
    final output = Directory('${temp.path}${Platform.pathSeparator}out')
      ..createSync();
    final clip = File('${output.path}${Platform.pathSeparator}clip.mp4')
      ..writeAsStringSync('flat');
    final item = DownloadItem(
      id: 'd1',
      request: const DownloadRequest(url: 'https://example.com/v'),
      filePath: clip.path,
    );
    final bundle = await PayloadScanner.fromDownloadItems(
      items: [item],
      outputFolder: output.path,
      creatorKey: 'neo',
      creatorHandle: 'neo',
      hash: false,
    );
    expect(bundle.files.single.fileName, 'neo/clip.mp4');
    expect(TransferZipBundle.archiveName(bundle.files), 'neo');
    final zip = await TransferZipBundle.writeToTemp(
      bundle.files,
      tempDir: temp,
    );
    final decoded = ZipDecoder().decodeBytes(await zip.readAsBytes());
    expect(decoded.findFile('neo/clip.mp4'), isNotNull);
  });

  test('bundle endpoint returns one zip', () async {
    final dest = Directory('${temp.path}/dest')..createSync();
    final clip = File('${temp.path}/clip.mp4')..writeAsStringSync('hello-zip');
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
    );
    server.setShare(
      ShareOffer(
        pin: '654321',
        files: [
          TransferFile(
            id: 'f1',
            fileName: 'neo/clip.mp4',
            size: clip.lengthSync(),
            localPath: clip.path,
          ),
        ],
      ),
    );
    final port = await server.start(
      preferredPort: 0,
      address: InternetAddress.loopbackIPv4,
    );
    addTearDown(server.stop);

    final prep = await HttpClient().postUrl(
      Uri.parse(
        'http://127.0.0.1:$port${LocalSendApi.prepareDownloadPath}?pin=654321',
      ),
    );
    final prepRes = await prep.close();
    expect(prepRes.statusCode, 200);
    await prepRes.drain<void>();

    final get = await HttpClient().getUrl(
      Uri.parse('http://127.0.0.1:$port${LocalSendApi.bundlePath}?pin=654321'),
    );
    final res = await get.close();
    expect(res.statusCode, 200);
    expect(res.headers.contentType?.mimeType, 'application/zip');
    final bytes = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
    final decoded = ZipDecoder().decodeBytes(bytes);
    expect(decoded.findFile('neo/clip.mp4'), isNotNull);
  });
}
