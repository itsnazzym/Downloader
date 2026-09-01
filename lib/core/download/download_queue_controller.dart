import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/x_feed/x_media_identity.dart';

import 'fragment_budget.dart';

/// Pure queue / duplicate helpers used by [DownloadListNotifier].
class DownloadQueueController {
  DownloadQueueController._();

  static bool isBusy(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.extracting:
      case DownloadStatus.downloading:
      case DownloadStatus.processing:
        return true;
      case DownloadStatus.queued:
      case DownloadStatus.completed:
      case DownloadStatus.failed:
      case DownloadStatus.canceled:
      case DownloadStatus.paused:
      case DownloadStatus.duplicate:
        return false;
    }
  }

  static bool isActiveOrQueued(DownloadStatus status) {
    return status == DownloadStatus.queued || isBusy(status);
  }

  static int busyCount(Iterable<DownloadItem> items) {
    var count = 0;
    for (final item in items) {
      if (isBusy(item.status)) count++;
    }
    return count;
  }

  /// How many pending jobs can start given [maxConcurrent] and current busy jobs.
  static int startableCount({
    required int busyCount,
    required int maxConcurrent,
    required int pendingCount,
  }) {
    return computeStartableCount(
      activeCount: busyCount,
      maxConcurrent: maxConcurrent,
      pendingCount: pendingCount,
    );
  }

  /// True when [request] is already queued, in-flight, or completed in the library.
  ///
  /// Completed items with a persisted [DownloadItem.filePath] are treated as
  /// duplicates without a disk `existsSync`. Missing files are repaired by
  /// the library scanner, not on the enqueue hot path.
  static bool isDuplicateRequest({
    required DownloadRequest request,
    required Iterable<DownloadRequest> queued,
    required Iterable<DownloadItem> items,
    Set<String> batchKeys = const <String>{},
  }) {
    final mediaKey = XMediaIdentity.mediaKey(request.url);
    if (mediaKey == null) return false;
    if (batchKeys.contains(mediaKey)) return true;
    for (final queuedRequest in queued) {
      if (XMediaIdentity.mediaKey(queuedRequest.url) == mediaKey) {
        return true;
      }
    }
    for (final item in items) {
      if (XMediaIdentity.mediaKey(item.request.url) != mediaKey) {
        continue;
      }
      if (isActiveOrQueued(item.status)) return true;
      final filePath = item.filePath;
      if (item.status == DownloadStatus.completed &&
          filePath != null &&
          filePath.isNotEmpty) {
        return true;
      }
    }
    return false;
  }
}
