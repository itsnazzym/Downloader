import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';

/// Sidebar counts derived from status / source only (ignores progress ticks).
@immutable
class DownloadLibraryCounts {
  const DownloadLibraryCounts({
    required this.total,
    required this.active,
    required this.completed,
    required this.failed,
    required this.sourceCounts,
  });

  static const empty = DownloadLibraryCounts(
    total: 0,
    active: 0,
    completed: 0,
    failed: 0,
    sourceCounts: <String, int>{},
  );

  final int total;

  final int active;
  final int completed;
  final int failed;
  final Map<String, int> sourceCounts;

  @override
  bool operator ==(Object other) {
    return other is DownloadLibraryCounts &&
        active == other.active &&
        completed == other.completed &&
        failed == other.failed &&
        total == other.total &&
        mapEquals(sourceCounts, other.sourceCounts);
  }

  @override
  int get hashCode =>
      Object.hash(total, active, completed, failed, sourceCounts);
}

final downloadLibraryCountsProvider = Provider<DownloadLibraryCounts>((ref) {
  return ref.watch(
    downloadListProvider.select((async) {
      final items = async.valueOrNull;
      if (items == null || items.isEmpty) {
        return DownloadLibraryCounts.empty;
      }

      var total = 0;
      var active = 0;
      var completed = 0;
      var failed = 0;
      final sourceCounts = <String, int>{};

      for (final item in items) {
        total++;
        switch (item.status) {
          case DownloadStatus.downloading:
          case DownloadStatus.queued:
          case DownloadStatus.extracting:
          case DownloadStatus.processing:
            active++;
            break;
          case DownloadStatus.completed:
            completed++;
            break;
          case DownloadStatus.failed:
          case DownloadStatus.canceled:
            failed++;
            break;
          case DownloadStatus.paused:
          case DownloadStatus.duplicate:
            break;
        }
        final source = item.source;
        if (source.isNotEmpty) {
          sourceCounts[source] = (sourceCounts[source] ?? 0) + 1;
        }
      }

      return DownloadLibraryCounts(
        total: total,
        active: active,
        completed: completed,
        failed: failed,
        sourceCounts: sourceCounts,
      );
    }),
  );
});
