import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/services/folder_size_service.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('folder_size_');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  FolderSizeService serviceWithProdScanner({DateTime Function()? clock}) {
    return FolderSizeService(
      scanner: scanFolderSize,
      clock: clock,
    );
  }

  Future<File> writeBytes(String relativePath, int length) async {
    final file = File('${tempRoot.path}${Platform.pathSeparator}$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List<int>.filled(length, 1), flush: true);
    return file;
  }

  FolderSizeSnapshot okSnapshot(FolderSizeResult result) {
    expect(result, isA<FolderSizeOk>());
    return (result as FolderSizeOk).snapshot;
  }

  test('sums nested files into totalBytes and fileCount', () async {
    await writeBytes('root.bin', 10);
    await writeBytes('sub${Platform.pathSeparator}nested.bin', 25);
    final service = serviceWithProdScanner();

    final snapshot = okSnapshot(await service.getSize(tempRoot.path));

    expect(snapshot.totalBytes, 35);
    expect(snapshot.fileCount, 2);
    expect(snapshot.videoBytes + snapshot.audioBytes + snapshot.otherBytes, 35);
  });

  test('missing folder is FolderSizeOk with zeros', () async {
    final missing = '${tempRoot.path}${Platform.pathSeparator}does-not-exist';
    final clock = DateTime(2026, 8, 28, 14, 5);
    final service = serviceWithProdScanner(clock: () => clock);

    final snapshot = okSnapshot(await service.getSize(missing));

    expect(snapshot.totalBytes, 0);
    expect(snapshot.fileCount, 0);
    expect(snapshot.topSubfolders, isEmpty);
    expect(snapshot.videoBytes, 0);
    expect(snapshot.audioBytes, 0);
    expect(snapshot.otherBytes, 0);
    expect(snapshot.scannedAt, clock);
  });

  test('includes partials and thumbnails in otherBytes', () async {
    await writeBytes('clip.mp4.part', 40);
    await writeBytes('thumb.jpg', 15);
    final service = serviceWithProdScanner();

    final snapshot = okSnapshot(await service.getSize(tempRoot.path));

    expect(snapshot.totalBytes, 55);
    expect(snapshot.fileCount, 2);
    expect(snapshot.otherBytes, 55);
    expect(snapshot.videoBytes, 0);
    expect(snapshot.audioBytes, 0);
  });

  test('classifies video, audio, and other by final extension', () async {
    await writeBytes('a.mp4', 8);
    await writeBytes('b.mp3', 5);
    await writeBytes('c.part', 3);
    final service = serviceWithProdScanner();

    final snapshot = okSnapshot(await service.getSize(tempRoot.path));

    expect(snapshot.videoBytes, 8);
    expect(snapshot.audioBytes, 5);
    expect(snapshot.otherBytes, 3);
    expect(snapshot.totalBytes, 16);
  });

  test('keeps the 3 heaviest direct subfolders; ties sort by name ascending', () async {
    await writeBytes('alpha${Platform.pathSeparator}f.bin', 30);
    await writeBytes('beta${Platform.pathSeparator}f.bin', 50);
    await writeBytes('gamma${Platform.pathSeparator}f.bin', 50);
    await writeBytes('delta${Platform.pathSeparator}f.bin', 10);
    final service = serviceWithProdScanner();

    final snapshot = okSnapshot(await service.getSize(tempRoot.path));

    expect(snapshot.topSubfolders.map((e) => e.name).toList(), ['beta', 'gamma', 'alpha']);
    expect(snapshot.topSubfolders.map((e) => e.bytes).toList(), [50, 50, 30]);
  });
}
