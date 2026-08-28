import 'dart:async';
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

  test('TTL: second getSize skips scanner while age < 10 min; rescans at 10 min', () async {
    await writeBytes('a.bin', 4);
    var now = DateTime(2026, 8, 28, 12, 0);
    var scans = 0;
    final service = FolderSizeService(
      clock: () => now,
      scanner: (path) async {
        scans += 1;
        return scanFolderSize(path);
      },
    );

    await service.getSize(tempRoot.path);
    expect(scans, 1);

    await service.getSize(tempRoot.path);
    expect(scans, 1);

    now = now.add(const Duration(minutes: 10));
    await service.getSize(tempRoot.path);
    expect(scans, 2);
  });

  test('path A cache is never returned for path B', () async {
    await writeBytes('a.bin', 4);
    final other = await Directory.systemTemp.createTemp('folder_size_b_');
    addTearDown(() async {
      if (await other.exists()) {
        await other.delete(recursive: true);
      }
    });
    final service = FolderSizeService(scanner: scanFolderSize);

    final snapA = okSnapshot(await service.getSize(tempRoot.path));
    expect(service.peek(other.path), isNull);

    final snapB = okSnapshot(await service.getSize(other.path));
    expect(snapA.path, isNot(snapB.path));
    expect(service.peek(tempRoot.path)!.totalBytes, snapA.totalBytes);
    expect(service.peek(other.path)!.totalBytes, snapB.totalBytes);
  });

  test('root PathAccessException is FolderSizeError and keeps prior cache', () async {
    await writeBytes('a.bin', 7);
    var scans = 0;
    var fail = false;
    final service = FolderSizeService(
      scanner: (path) async {
        scans += 1;
        if (fail) {
          throw PathAccessException('list', const OSError('Access denied', 5), path);
        }
        return scanFolderSize(path);
      },
    );

    final first = okSnapshot(await service.getSize(tempRoot.path));
    expect(first.totalBytes, 7);
    expect(scans, 1);

    fail = true;
    final second = await service.getSize(tempRoot.path, force: true);
    expect(second, isA<FolderSizeError>());
    expect((second as FolderSizeError).path, tempRoot.path);
    expect(service.peek(tempRoot.path)!.totalBytes, 7);
    expect(scans, 2);
  });

  test('joins an in-flight scan for the same cache key', () async {
    await writeBytes('a.bin', 3);
    var starts = 0;
    final gate = Completer<void>();
    final service = FolderSizeService(
      scanner: (path) async {
        starts += 1;
        await gate.future;
        return scanFolderSize(path);
      },
    );

    final first = service.getSize(tempRoot.path);
    final second = service.getSize(tempRoot.path);
    await Future<void>.delayed(Duration.zero);
    expect(starts, 1);
    gate.complete();

    expect(okSnapshot(await first).totalBytes, 3);
    expect(okSnapshot(await second).totalBytes, 3);
    expect(starts, 1);
  });
}
