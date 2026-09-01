import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/download_queue_controller.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

DownloadItem item({
  required String id,
  required String url,
  required DownloadStatus status,
  String? filePath,
}) {
  return DownloadItem(
    id: id,
    request: DownloadRequest(url: url),
    status: status,
    filePath: filePath,
  );
}

void main() {
  const tweetA = 'https://x.com/alice/status/2093058718350893415';
  const tweetB = 'https://x.com/bob/status/2091798624661602420';

  group('DownloadQueueController', () {
    test('busyCount only includes extracting/downloading/processing', () {
      final items = [
        item(id: '1', url: tweetA, status: DownloadStatus.downloading),
        item(id: '2', url: tweetB, status: DownloadStatus.queued),
        item(id: '3', url: tweetA, status: DownloadStatus.completed),
      ];
      expect(DownloadQueueController.busyCount(items), 1);
    });

    test('startableCount respects maxConcurrent', () {
      expect(
        DownloadQueueController.startableCount(
          busyCount: 2,
          maxConcurrent: 3,
          pendingCount: 5,
        ),
        1,
      );
      expect(
        DownloadQueueController.startableCount(
          busyCount: 3,
          maxConcurrent: 3,
          pendingCount: 2,
        ),
        0,
      );
    });

    test('detects queued and in-flight duplicates without disk I/O', () {
      final request = const DownloadRequest(url: tweetA);
      expect(
        DownloadQueueController.isDuplicateRequest(
          request: request,
          queued: const [DownloadRequest(url: tweetA)],
          items: const [],
        ),
        isTrue,
      );
      expect(
        DownloadQueueController.isDuplicateRequest(
          request: request,
          queued: const [],
          items: [
            item(id: '1', url: tweetA, status: DownloadStatus.extracting),
          ],
        ),
        isTrue,
      );
    });

    test('treats completed library entries with a filePath as duplicates', () {
      expect(
        DownloadQueueController.isDuplicateRequest(
          request: const DownloadRequest(url: tweetA),
          queued: const [],
          items: [
            item(
              id: '1',
              url: tweetA,
              status: DownloadStatus.completed,
              filePath: r'C:\Videos\clip.mp4',
            ),
          ],
        ),
        isTrue,
      );
    });

    test('allows re-download when completed file is missing', () {
      expect(
        DownloadQueueController.isDuplicateRequest(
          request: const DownloadRequest(url: tweetA),
          queued: const [],
          items: [
            item(
              id: '1',
              url: tweetA,
              status: DownloadStatus.completed,
              filePath: r'C:\Videos\missing.mp4',
            ),
          ],
          fileExists: (_) => false,
        ),
        isFalse,
      );
    });

    test('allows a new tweet id', () {
      expect(
        DownloadQueueController.isDuplicateRequest(
          request: const DownloadRequest(url: tweetB),
          queued: const [DownloadRequest(url: tweetA)],
          items: [item(id: '1', url: tweetA, status: DownloadStatus.completed)],
        ),
        isFalse,
      );
    });
  });
}
