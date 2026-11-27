import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';

/// WebSocket contract for the extension's download queue: a snapshot request
/// and per-download commands (cancel, pause, resume, retry, cancel_all).
class ExtensionQueueContract {
  static const String snapshotRequest = 'QUEUE_SNAPSHOT_REQUEST';
  static const String snapshot = 'QUEUE_SNAPSHOT';
  static const String command = 'DOWNLOAD_COMMAND';
  static const String commandResult = 'DOWNLOAD_COMMAND_RESULT';

  /// Statuses of a download that is queued or running (what cancel_all hits).
  static const Set<DownloadStatus> activeStatuses = {
    DownloadStatus.queued,
    DownloadStatus.extracting,
    DownloadStatus.downloading,
    DownloadStatus.processing,
  };

  /// Single source of truth: the statuses each id command may act on.
  /// A command outside its set would corrupt the item (retry deletes the
  /// downloaded file, pause/cancel rewrite a finished entry).
  static const Map<String, Set<DownloadStatus>> _allowedStatuses = {
    // Same set as DownloadListNotifier.pauseAllActive.
    'pause': {
      DownloadStatus.extracting,
      DownloadStatus.downloading,
      DownloadStatus.processing,
    },
    // failed/canceled go through retry, which re-queues cleanly.
    'resume': {DownloadStatus.paused},
    'cancel': {...activeStatuses, DownloadStatus.paused},
    // Same as retryAllFailed, plus canceled.
    'retry': {DownloadStatus.failed, DownloadStatus.canceled},
  };

  static bool isActive(DownloadStatus status) =>
      activeStatuses.contains(status);

  /// Finished items (completed/duplicate) the snapshot keeps.
  static const int recentFinishedLimit = 50;

  /// What QUEUE_SNAPSHOT sends: the activity, not the library. Every item
  /// that is not finished (live, paused, failed, canceled), plus the
  /// [recentFinishedLimit] most recent finished ones. [all] is in
  /// getCurrentDownloads() order (sortOrder, new items appended), so the most
  /// recent are the last ones; a manual reorder in the app moves them too.
  static List<DownloadItem> snapshotItems(List<DownloadItem> all) {
    bool finished(DownloadItem i) =>
        i.status == DownloadStatus.completed ||
        i.status == DownloadStatus.duplicate;
    var skip = all.where(finished).length - recentFinishedLimit;
    return [
      for (final item in all)
        if (!finished(item) || skip-- <= 0) item,
    ];
  }

  /// True when [command] (cancel, pause, resume, retry) fits [status].
  static bool allows(String command, DownloadStatus status) =>
      _allowedStatuses[command]?.contains(status) ?? false;

  /// Returns an error code, or null when the command shape is valid.
  static String? validateCommand(Map<String, dynamic> data) {
    final name = data['command'];
    if (name == 'cancel_all') return null;
    if (name is! String || !_allowedStatuses.containsKey(name)) {
      return 'unknown_command';
    }
    final id = data['id'];
    if (id is! String || id.isEmpty) return 'missing_id';
    return null;
  }
}
