import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/features/transfer/data/payload_scanner.dart';
import 'package:tapload/features/transfer/data/transfer_zip_bundle.dart';
import 'package:tapload/features/transfer/domain/transfer_models.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('md-flatten-test-');
  });

  tearDown(() async {
    try {
      await temp.delete(recursive: true);
    } catch (_) {}
  });

  test('PayloadScanner flattens multiple folders into one root with no subfolders', () async {
    final folderA = Directory('${temp.path}/folderA')..createSync();
    final folderB = Directory('${temp.path}/folderB')..createSync();

    File('${folderA.path}/video.mp4').writeAsStringSync('a1');
    File('${folderA.path}/intro.mp4').writeAsStringSync('a2');
    File('${folderB.path}/video.mp4').writeAsStringSync('b1'); // Name collision!

    final bundle = await PayloadScanner.scanDirectories(
      [folderA, folderB],
      hash: false,
      flatten: true,
    );

    expect(bundle.files.length, 3);
    // Ensure all fileNames have NO slashes (completely flat!)
    for (final file in bundle.files) {
      expect(file.fileName.contains('/'), isFalse);
      expect(file.fileName.contains('\\'), isFalse);
    }

    final names = bundle.files.map((f) => f.fileName).toList();
    expect(names, contains('video.mp4'));
    expect(names, contains('intro.mp4'));
    // Collision was resolved uniquely with prefix or counter
    expect(names.toSet().length, 3);
  });

  test('PayloadScanner flattens extra files picked directly', () async {
    final file1 = File('${temp.path}/vid1.mp4')..writeAsStringSync('1');
    final file2 = File('${temp.path}/vid2.mp4')..writeAsStringSync('2');

    final bundle = await PayloadScanner.scanFiles([file1, file2], hash: false);
    expect(bundle.files.length, 2);
    expect(bundle.files[0].fileName, 'vid1.mp4');
    expect(bundle.files[1].fileName, 'vid2.mp4');
  });

  test('TransferZipBundle writes flat archive without subdirectories', () async {
    final f1 = File('${temp.path}/f1.mp4')..writeAsStringSync('vid-one');
    final f2 = File('${temp.path}/f2.mp4')..writeAsStringSync('vid-two');

    final files = [
      TransferFile(
        id: '1',
        fileName: 'creator1_clip.mp4',
        size: f1.lengthSync(),
        localPath: f1.path,
      ),
      TransferFile(
        id: '2',
        fileName: 'creator2_clip.mp4',
        size: f2.lengthSync(),
        localPath: f2.path,
      ),
    ];

    final zip = await TransferZipBundle.writeToTemp(files, tempDir: temp, flatten: true);
    addTearDown(() async {
      try {
        await zip.delete();
      } catch (_) {}
    });

    final decoded = ZipDecoder().decodeBytes(await zip.readAsBytes());
    expect(decoded.files.length, 2);
    // Both files are in the zip root
    expect(decoded.findFile('creator1_clip.mp4'), isNotNull);
    expect(decoded.findFile('creator2_clip.mp4'), isNotNull);
    expect(decoded.findFile('creator1_clip.mp4')!.name, 'creator1_clip.mp4');
  });

  test('shouldArchive skips a single file even when zip is enabled', () {
    expect(
      TransferZipBundle.shouldArchive(compressZip: true, fileCount: 1),
      isFalse,
    );
    expect(
      TransferZipBundle.shouldArchive(compressZip: true, fileCount: 2),
      isTrue,
    );
    expect(
      TransferZipBundle.shouldArchive(compressZip: false, fileCount: 4),
      isFalse,
    );
  });

  test('writeToTempIsolated writes a flat STORE archive off the caller isolate', () async {
    final f1 = File('${temp.path}/iso1.mp4')..writeAsStringSync('iso-one');
    final f2 = File('${temp.path}/iso2.mp4')..writeAsStringSync('iso-two');
    final zipPath = '${temp.path}/isolated.zip';
    final zip = await TransferZipBundle.writeToTempIsolated(
      [
        TransferFile(
          id: '1',
          fileName: 'iso1.mp4',
          size: f1.lengthSync(),
          localPath: f1.path,
        ),
        TransferFile(
          id: '2',
          fileName: 'iso2.mp4',
          size: f2.lengthSync(),
          localPath: f2.path,
        ),
      ],
      zipPath: zipPath,
      flatten: true,
    );
    expect(zip.path, zipPath);
    final decoded = ZipDecoder().decodeBytes(await zip.readAsBytes());
    expect(decoded.findFile('iso1.mp4'), isNotNull);
    expect(decoded.findFile('iso2.mp4'), isNotNull);
  });
}
