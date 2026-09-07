import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/presentation/models/creator_folder.dart';
import 'package:modern_downloader/features/transfer/domain/library_manifest.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_creator_query.dart';
import 'package:modern_downloader/features/transfer/domain/qr_payload.dart';
import 'package:modern_downloader/features/transfer/domain/resume_filter.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_media_filter.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_path_guard.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_progress_label.dart';

void main() {
  group('TransferPathGuard', () {
    test('rejects traversal and absolute paths', () {
      expect(TransferPathGuard.relativePathOrNull('../x.mp4'), isNull);
      expect(TransferPathGuard.relativePathOrNull('/etc/passwd'), isNull);
      expect(TransferPathGuard.relativePathOrNull(r'C:\Windows\x'), isNull);
    });

    test('normalizes relative posix paths', () {
      expect(
        TransferPathGuard.relativePathOrNull(r'neo\clip.mp4'),
        'neo/clip.mp4',
      );
      expect(
        TransferPathGuard.relativePathOrNull('./neo/clip.mp4'),
        'neo/clip.mp4',
      );
    });
  });

  group('LibraryManifest', () {
    test('round-trips json', () {
      const original = LibraryManifest(
        entries: [
          LibraryManifestEntry(
            relativePath: 'neo/a.mp4',
            downloadId: '1',
            creatorKey: 'neo',
            creatorHandle: 'neo',
          ),
        ],
      );
      final parsed = LibraryManifest.fromJson(original.toJson());
      expect(parsed, original);
    });
  });

  group('QrPayload', () {
    test('defaults to https like LocalSend', () {
      const peer = TransferPeer(
        alias: 'phone',
        fingerprint: 'fp',
        ip: '192.168.1.20',
        port: 53317,
      );
      expect(peer.origin().scheme, 'https');
      expect(peer.flippedProtocol.origin().scheme, 'http');
    });

    test('builds and parses pin url', () {
      const payload = QrPayload(ip: '192.168.1.8', port: 53317, pin: '042001');
      final parsed = QrPayload.parse(payload.toUri());
      expect(parsed?.ip, '192.168.1.8');
      expect(parsed?.port, 53317);
      expect(parsed?.pin, '042001');
    });
  });

  group('TransferCreatorQuery', () {
    const folders = [
      CreatorFolder(
        key: 'neo',
        handle: 'Neo',
        itemIds: ['a'],
        previewUrls: [null],
      ),
      CreatorFolder(
        key: 'zeta',
        handle: 'Zeta',
        itemIds: ['b'],
        previewUrls: [null],
      ),
    ];

    test('empty query returns nothing (no dump)', () {
      expect(TransferCreatorQuery.matches(folders, ''), isEmpty);
      expect(TransferCreatorQuery.matches(folders, '  @  '), isEmpty);
    });

    test('filters and caps results', () {
      expect(TransferCreatorQuery.matches(folders, '@NE').single.key, 'neo');
      expect(TransferCreatorQuery.matches(folders, 'e', limit: 1).length, 1);
    });
  });

  group('ResumeFilter', () {
    test('skips matching sha256', () {
      const files = [
        TransferFile(id: 'a', fileName: 'neo/a.mp4', size: 10, sha256: 'aaa'),
        TransferFile(id: 'b', fileName: 'neo/b.mp4', size: 11, sha256: 'bbb'),
      ];
      final pending = ResumeFilter.pending(
        files: files,
        destByRelativePath: {
          'neo/a.mp4': const ExistingDestFile(size: 10, sha256: 'aaa'),
        },
      );
      expect(pending.map((f) => f.id), ['b']);
    });
  });

  group('TransferProgressLabel', () {
    test('uses compressing not waitingPeer during zip', () {
      const zip = TransferProgress(
        phase: TransferPhase.compressing,
        bytesDone: 0,
        bytesTotal: 1600000000,
        currentName: 'clip.mp4',
      );
      expect(TransferProgressLabel.key(zip), TransferProgressLabel.compressing);
      expect(
        TransferProgressLabel.key(zip),
        isNot(TransferProgressLabel.waitingPeer),
      );
      expect(TransferProgressLabel.isIndeterminate(zip), isFalse);

      const wait = TransferProgress(
        phase: TransferPhase.waitingPeer,
        bytesDone: 0,
        bytesTotal: 1600000000,
      );
      expect(TransferProgressLabel.key(wait), TransferProgressLabel.waitingPeer);
      expect(TransferProgressLabel.isIndeterminate(wait), isTrue);
    });
  });

  group('TransferMediaFilter', () {
    test('keeps only finished mp4 videos', () {
      expect(TransferMediaFilter.isMp4Video('neo/clips/a.mp4'), isTrue);
      expect(TransferMediaFilter.isMp4Video(r'C:\lib\A.MP4'), isTrue);
      expect(TransferMediaFilter.isMp4Video('neo/thumb.jpg'), isFalse);
      expect(TransferMediaFilter.isMp4Video('neo/clip.mp4.part'), isFalse);
      expect(TransferMediaFilter.isMp4Video('neo/clip.part.mp4'), isFalse);
      expect(TransferMediaFilter.isMp4Video('library-manifest.json'), isFalse);
    });

    test('isTransferableMedia validates video, audio and archives but excludes leftovers', () {
      expect(TransferMediaFilter.isTransferableMedia('video.mp4'), isTrue);
      expect(TransferMediaFilter.isTransferableMedia('movie.mkv'), isTrue);
      expect(TransferMediaFilter.isTransferableMedia('clip.webm'), isTrue);
      expect(TransferMediaFilter.isTransferableMedia('song.mp3'), isTrue);
      expect(TransferMediaFilter.isTransferableMedia('track.flac'), isTrue);
      expect(TransferMediaFilter.isTransferableMedia('archive.zip'), isTrue);

      expect(TransferMediaFilter.isTransferableMedia('video.mp4.part'), isFalse);
      expect(TransferMediaFilter.isTransferableMedia('video.ytdl'), isFalse);
      expect(TransferMediaFilter.isTransferableMedia('video.crdownload'), isFalse);
      expect(TransferMediaFilter.isTransferableMedia('thumb.jpg'), isFalse);
      expect(TransferMediaFilter.isTransferableMedia('manifest.json'), isFalse);
    });
  });
}
