import '../../features/downloader/domain/entities/download_item.dart';
import '../../features/downloader/domain/enums/download_status.dart';

/// Restores downloads that were still running when the process died.
///
/// In-flight items are mapped to [DownloadStatus.queued] so the notifier can
/// call [resumeDownload] on the existing id. User-paused items stay paused.
class DownloadCrashRecovery {
  const DownloadCrashRecovery._();

  static bool isInterrupted(DownloadStatus status) {
    return status == DownloadStatus.downloading ||
        status == DownloadStatus.extracting ||
        status == DownloadStatus.processing;
  }

  static DownloadStatus recoverStatus(DownloadStatus status) {
    if (isInterrupted(status)) {
      return DownloadStatus.queued;
    }
    return status;
  }

  static DownloadItem recoverItem(DownloadItem item) {
    final next = recoverStatus(item.status);
    if (next == item.status) {
      return item;
    }
    return item.copyWith(status: next, speed: '', eta: '');
  }

  static List<DownloadItem> recoverList(List<DownloadItem> items) {
    return items.map(recoverItem).toList(growable: false);
  }
}
