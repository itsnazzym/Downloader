import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/transfer/data/payload_scanner.dart';
import 'package:modern_downloader/features/transfer/data/send_memory_store.dart';
import 'package:modern_downloader/features/transfer/domain/content_hash.dart';
import 'package:modern_downloader/features/transfer/domain/send_memory.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';

void main() {
  late Directory tempDir;
  late File storeFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('send_memory_test_');
    storeFile = File('${tempDir.path}/send_memory.json');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  File createTestFile(String relativePath, List<int> bytes) {
    final file = File('${tempDir.path}/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    return file;
  }

  group('ContentHash & PayloadScanner SHA-256', () {
    test('computes SHA-256 and caches by path/size/mtime', () async {
      final f1 = createTestFile('video1.mp4', [1, 2, 3, 4, 5]);
      final sha1 = await PayloadScanner.sha256File(f1);
      expect(sha1, isNotEmpty);
      expect(sha1.length, 64);

      final store = SendMemoryStore(storeFile);
      await store.load();

      // First resolve: computes and caches in store
      final stat1 = await f1.stat();
      final hashResolved = await ContentHash.resolve(
        file: f1,
        stat: stat1,
        store: store,
      );
      expect(hashResolved, sha1);
      expect(
        store.cachedSha256(
          f1.path,
          size: stat1.size,
          mtimeMs: stat1.modified.millisecondsSinceEpoch,
        ),
        sha1,
      );

      // Mutating content invalidates cache because size/mtime change
      f1.writeAsBytesSync([1, 2, 3, 4, 5, 6, 7, 8]);
      final stat2 = await f1.stat();
      final hashMutated = await ContentHash.resolve(
        file: f1,
        stat: stat2,
        store: store,
      );
      expect(hashMutated, isNot(sha1));
    });
  });

  group('SendMemoryStore', () {
    test('loads empty state, commits records, and persists to disk', () async {
      final store = SendMemoryStore(storeFile);
      await store.load();
      expect(store.isTransferred(null, 'abc123'), isFalse);

      final record = TransferredFileRecord(
        sha256: 'abc123',
        size: 1024,
        firstTransferredAt: DateTime.now(),
        lastFileName: 'video1.mp4',
        lastSource: 'TikTok_ABC',
      );

      await store.commit('phone_pixel_7', [record]);

      expect(
        store.isTransferred('phone_pixel_7', 'abc123'),
        isTrue,
      );
      // Different device -> not transferred yet to that target
      expect(
        store.isTransferred('phone_galaxy_s23', 'abc123'),
        isFalse,
      );

      // Reload store from disk -> verifies persistence
      final reloaded = SendMemoryStore(storeFile);
      await reloaded.load();
      expect(
        reloaded.isTransferred('phone_pixel_7', 'abc123'),
        isTrue,
      );
    });

    test('forgetDevice clears only specified device history', () async {
      final store = SendMemoryStore(storeFile);
      await store.load();

      final r1 = TransferredFileRecord(
        sha256: 'hash1',
        size: 100,
        firstTransferredAt: DateTime.now(),
        lastFileName: 'v1.mp4',
        lastSource: 'FolderA',
      );
      final r2 = TransferredFileRecord(
        sha256: 'hash2',
        size: 200,
        firstTransferredAt: DateTime.now(),
        lastFileName: 'v2.mp4',
        lastSource: 'FolderB',
      );

      await store.commit('deviceA', [r1]);
      await store.commit('deviceB', [r2]);

      expect(store.isTransferred('deviceA', 'hash1'), isTrue);
      expect(store.isTransferred('deviceB', 'hash2'), isTrue);

      await store.forgetDevice('deviceA');

      expect(store.isTransferred('deviceA', 'hash1'), isFalse);
      expect(store.isTransferred('deviceB', 'hash2'), isTrue);
    });
  });

  group('SendMemoryFilter & Real World Scenario', () {
    test('TikTok folder update: 3 transferred old videos + 2 new added videos', () async {
      final store = SendMemoryStore(storeFile);
      await store.load();
      const targetDevice = 'my_phone';

      // 1. Initial State: 3 videos in TikTok_ABC
      final v1 = createTestFile('TikTok_ABC/video1.mp4', [10, 11, 12]);
      final v2 = createTestFile('TikTok_ABC/video2.mp4', [20, 21, 22]);
      final v3 = createTestFile('TikTok_ABC/video3.mp4', [30, 31, 32]);

      final h1 = await PayloadScanner.sha256File(v1);
      final h2 = await PayloadScanner.sha256File(v2);
      final h3 = await PayloadScanner.sha256File(v3);

      final initialFiles = [
        TransferFile(
          id: '1',
          fileName: 'video1.mp4',
          size: v1.lengthSync(),
          sha256: h1,
          creatorKey: 'TikTok_ABC',
          localPath: v1.path,
        ),
        TransferFile(
          id: '2',
          fileName: 'video2.mp4',
          size: v2.lengthSync(),
          sha256: h2,
          creatorKey: 'TikTok_ABC',
          localPath: v2.path,
        ),
        TransferFile(
          id: '3',
          fileName: 'video3.mp4',
          size: v3.lengthSync(),
          sha256: h3,
          creatorKey: 'TikTok_ABC',
          localPath: v3.path,
        ),
      ];

      // Preview before any transfer: 3 found, 0 already, 3 new
      var preview = SendMemoryFilter.preview(
        files: initialFiles,
        fingerprint: targetDevice,
        isTransferred: (sha) => store.isTransferred(targetDevice, sha),
      );
      expect(preview.found, 3);
      expect(preview.already, 0);
      expect(preview.newest, 3);

      // Simulating transfer success: commit files to store
      final records = initialFiles
          .map((f) => TransferredFileRecord.fromFile(f))
          .toList();
      await store.commit(targetDevice, records);

      // 2. Folder updated: video1, video2, video3 remain, video4 and video5 added
      final v4 = createTestFile('TikTok_ABC/video4.mp4', [40, 41, 42]);
      final v5 = createTestFile('TikTok_ABC/video5.mp4', [50, 51, 52]);
      final h4 = await PayloadScanner.sha256File(v4);
      final h5 = await PayloadScanner.sha256File(v5);

      final updatedFiles = [
        ...initialFiles,
        TransferFile(
          id: '4',
          fileName: 'video4.mp4',
          size: v4.lengthSync(),
          sha256: h4,
          creatorKey: 'TikTok_ABC',
          localPath: v4.path,
        ),
        TransferFile(
          id: '5',
          fileName: 'video5.mp4',
          size: v5.lengthSync(),
          sha256: h5,
          creatorKey: 'TikTok_ABC',
          localPath: v5.path,
        ),
      ];

      // Preview on second run: 5 found, 3 already transferred, 2 new
      preview = SendMemoryFilter.preview(
        files: updatedFiles,
        fingerprint: targetDevice,
        isTransferred: (sha) => store.isTransferred(targetDevice, sha),
      );
      expect(preview.found, 5);
      expect(preview.already, 3);
      expect(preview.newest, 2);

      // Per-folder breakdown for TikTok_ABC
      final folderCounts = preview.forKey('TikTok_ABC');
      expect(folderCounts, isNotNull);
      expect(folderCounts!.found, 5);
      expect(folderCounts.already, 3);
      expect(folderCounts.newest, 2);

      // Outgoing filter with onlyNew: true -> returns ONLY video4 and video5!
      final outgoingOnlyNew = SendMemoryFilter.outgoing(
        files: updatedFiles,
        fingerprint: targetDevice,
        isTransferred: (sha) => store.isTransferred(targetDevice, sha),
      );
      expect(outgoingOnlyNew.length, 2);
      expect(outgoingOnlyNew.map((f) => f.fileName).toSet(), {'video4.mp4', 'video5.mp4'});

      // Outgoing filter with onlyNew: false -> returns all 5 videos
      final outgoingAll = SendMemoryFilter.outgoing(
        files: updatedFiles,
        fingerprint: targetDevice,
        isTransferred: (sha) => false, // onlyNew toggle off
      );
      expect(outgoingAll.length, 5);
    });

    test('Deduplication: same video in two different folders is sent only once', () async {
      final store = SendMemoryStore(storeFile);
      await store.load();
      const targetDevice = 'phone_dup';

      final v1 = createTestFile('TikTok_A/clip.mp4', [99, 98, 97]);
      final v2 = createTestFile('TikTok_B/clip_copy.mp4', [99, 98, 97]); // identical content

      final h1 = await PayloadScanner.sha256File(v1);
      final h2 = await PayloadScanner.sha256File(v2);
      expect(h1, h2);

      final files = [
        TransferFile(
          id: '1',
          fileName: 'clip.mp4',
          size: v1.lengthSync(),
          sha256: h1,
          creatorKey: 'TikTok_A',
          localPath: v1.path,
        ),
        TransferFile(
          id: '2',
          fileName: 'clip_copy.mp4',
          size: v2.lengthSync(),
          sha256: h2,
          creatorKey: 'TikTok_B',
          localPath: v2.path,
        ),
      ];

      final outgoing = SendMemoryFilter.outgoing(
        files: files,
        fingerprint: targetDevice,
        isTransferred: (sha) => store.isTransferred(targetDevice, sha),
      );

      // Exactly 1 video is sent (deduplicated by SHA-256)
      expect(outgoing.length, 1);
    });

    test('Renamed or moved video is recognized as already transferred by SHA-256', () async {
      final store = SendMemoryStore(storeFile);
      await store.load();
      const targetDevice = 'phone_move';

      final fileOrig = createTestFile('OrigFolder/vid.mp4', [77, 88, 99]);
      final hashOrig = await PayloadScanner.sha256File(fileOrig);

      await store.commit(targetDevice, [
        TransferredFileRecord(
          sha256: hashOrig,
          size: fileOrig.lengthSync(),
          firstTransferredAt: DateTime.now(),
          lastFileName: 'vid.mp4',
          lastSource: 'OrigFolder',
        ),
      ]);

      // File moved / renamed to NewFolder/vid_renamed.mp4 with identical content
      final fileRenamed = createTestFile('NewFolder/vid_renamed.mp4', [77, 88, 99]);
      final hashRenamed = await PayloadScanner.sha256File(fileRenamed);
      expect(hashRenamed, hashOrig);

      final files = [
        TransferFile(
          id: '1',
          fileName: 'vid_renamed.mp4',
          size: fileRenamed.lengthSync(),
          sha256: hashRenamed,
          creatorKey: 'NewFolder',
          localPath: fileRenamed.path,
        ),
      ];

      final preview = SendMemoryFilter.preview(
        files: files,
        fingerprint: targetDevice,
        isTransferred: (sha) => store.isTransferred(targetDevice, sha),
      );

      expect(preview.found, 1);
      expect(preview.already, 1);
      expect(preview.newest, 0);

      final outgoing = SendMemoryFilter.outgoing(
        files: files,
        fingerprint: targetDevice,
        isTransferred: (sha) => store.isTransferred(targetDevice, sha),
      );
      expect(outgoing.isEmpty, isTrue);
    });

    test('Unhashed files (null sha256 from lazy scanner) are counted and sent as new', () async {
      final store = SendMemoryStore(storeFile);
      await store.load();
      const targetDevice = 'phone_lazy';

      // 1 transferred file with known SHA
      final f1 = createTestFile('TikTok_ABC/old_transferred.mp4', [1, 2, 3]);
      final h1 = await PayloadScanner.sha256File(f1);
      await store.commit(targetDevice, [
        TransferredFileRecord(
          sha256: h1,
          size: f1.lengthSync(),
          firstTransferredAt: DateTime.now(),
          lastFileName: 'old_transferred.mp4',
        ),
      ]);

      // 2 brand new unhashed files (sha256: null, typical of fast directory scans)
      final files = [
        TransferFile(
          id: '1',
          fileName: 'old_transferred.mp4',
          size: f1.lengthSync(),
          sha256: h1,
          creatorKey: 'TikTok_ABC',
          localPath: f1.path,
        ),
        TransferFile(
          id: '2',
          fileName: 'new_video1.mp4',
          size: 1000,
          sha256: null,
          creatorKey: 'TikTok_ABC',
          localPath: 'TikTok_ABC/new_video1.mp4',
        ),
        TransferFile(
          id: '3',
          fileName: 'new_video2.mp4',
          size: 2000,
          sha256: null,
          creatorKey: 'TikTok_XYZ',
          localPath: 'TikTok_XYZ/new_video2.mp4',
        ),
      ];

      final preview = SendMemoryFilter.preview(
        files: files,
        fingerprint: targetDevice,
        isTransferred: (sha) => store.isTransferred(targetDevice, sha),
      );

      expect(preview.found, 3);
      expect(preview.already, 1);
      expect(preview.newest, 2);
      expect(preview.newBytes, 3000);

      final outgoing = SendMemoryFilter.outgoing(
        files: files,
        fingerprint: targetDevice,
        isTransferred: (sha) => store.isTransferred(targetDevice, sha),
      );
      expect(outgoing.length, 2);
      expect(outgoing.map((f) => f.fileName).toSet(), {'new_video1.mp4', 'new_video2.mp4'});
    });
  });
}
