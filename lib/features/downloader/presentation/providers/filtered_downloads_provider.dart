import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/utils/format_utils.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';

/// Compares formatted size strings (`"10 MB"` vs `"2 GB"`) by parsed bytes.
int compareDownloadSize(DownloadItem a, DownloadItem b) {
  return FormatUtils.parseBytes(
    a.totalSize,
  ).compareTo(FormatUtils.parseBytes(b.totalSize));
}

// --- Filter State Definitions ---

enum DownloadStatusFilter {
  all,
  active, // Downloading, Extracting, Queued, Processing
  completed,
  failed, // Failed, Canceled
}

enum DownloadSort { dateDesc, dateAsc, nameAsc, nameDesc, sizeDesc, sizeAsc }

enum DownloadViewMode {
  list,
  detailed, // Grid-like cards
}

// Changed to String for dynamic source support
final downloadSourceFilterProvider = StateProvider<String?>(
  (ref) => null,
); // null = all

// --- Providers ---

final downloadSearchQueryProvider = StateProvider<String>((ref) => '');

final downloadStatusFilterProvider = StateProvider<DownloadStatusFilter>(
  (ref) => DownloadStatusFilter.all,
);

final downloadSortProvider = StateProvider<DownloadSort>(
  (ref) => DownloadSort.dateDesc,
);

final downloadViewModeProvider = StateProvider<DownloadViewMode>(
  (ref) => DownloadViewMode.list,
);

final selectedDownloadIdProvider = StateProvider<String?>((ref) => null);

// --- Logic ---

final filteredDownloadsProvider = Provider<AsyncValue<List<DownloadItem>>>((
  ref,
) {
  final allDownloadsState = ref.watch(downloadListProvider);
  final query = ref.watch(downloadSearchQueryProvider).toLowerCase();
  final statusFilter = ref.watch(downloadStatusFilterProvider);
  final sourceFilter = ref.watch(downloadSourceFilterProvider);
  final sort = ref.watch(downloadSortProvider);

  return allDownloadsState.when(
    data: (allDownloads) {
      final filtered = allDownloads.where((item) {
        // 1. Search Query
        if (query.isNotEmpty) {
          final title = (item.title ?? '').toLowerCase();
          final url = item.request.url.toLowerCase();
          if (!title.contains(query) && !url.contains(query)) {
            return false;
          }
        }

        // 2. Status Filter
        if (statusFilter != DownloadStatusFilter.all) {
          switch (statusFilter) {
            case DownloadStatusFilter.active:
              if (![
                DownloadStatus.downloading,
                DownloadStatus.extracting,
                DownloadStatus.queued,
                DownloadStatus.processing,
              ].contains(item.status)) {
                return false;
              }
              break;
            case DownloadStatusFilter.completed:
              if (item.status != DownloadStatus.completed) {
                return false;
              }
              break;
            case DownloadStatusFilter.failed:
              if (![
                DownloadStatus.failed,
                DownloadStatus.canceled,
              ].contains(item.status)) {
                return false;
              }
              break;
            case DownloadStatusFilter.all:
              break;
          }
        }

        // 3. Source Filter
        if (sourceFilter != null) {
          if (item.source != sourceFilter) {
            return false;
          }
        }

        return true;
      }).toList();

      // 4. Sorting
      filtered.sort((a, b) {
        switch (sort) {
          case DownloadSort.dateDesc:
            // Assuming sortOrder ~ creation time due to implementation
            return b.sortOrder.compareTo(a.sortOrder);
          case DownloadSort.dateAsc:
            return a.sortOrder.compareTo(b.sortOrder);
          case DownloadSort.nameAsc:
            return (a.title ?? '').toLowerCase().compareTo(
              (b.title ?? '').toLowerCase(),
            );
          case DownloadSort.nameDesc:
            return (b.title ?? '').toLowerCase().compareTo(
              (a.title ?? '').toLowerCase(),
            );
          case DownloadSort.sizeAsc:
            return compareDownloadSize(a, b);
          case DownloadSort.sizeDesc:
            return compareDownloadSize(b, a);
        }
      });

      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Identity of the visible list. Progress ticks do not change IDs, so widgets
/// watching this skip rebuilds while per-id providers update the active row.
@immutable
class DownloadIdList {
  const DownloadIdList(this.ids);

  final List<String> ids;

  @override
  bool operator ==(Object other) {
    return other is DownloadIdList && listEquals(other.ids, ids);
  }

  @override
  int get hashCode => Object.hashAll(ids);
}

final filteredDownloadIdListProvider = Provider<DownloadIdList>((ref) {
  return ref.watch(
    filteredDownloadsProvider.select((async) {
      final items = async.valueOrNull;
      if (items == null || items.isEmpty) {
        return const DownloadIdList([]);
      }
      return DownloadIdList([for (final item in items) item.id]);
    }),
  );
});

/// Loading / error / length only — ignores per-item progress mutations.
final filteredDownloadListPhaseProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(
    filteredDownloadsProvider.select((async) {
      return async.when(
        data: (items) => AsyncValue.data(items.length),
        loading: () => const AsyncValue<int>.loading(),
        error: (e, st) => AsyncValue<int>.error(e, st),
      );
    }),
  );
});
