import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/utils/format_utils.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/domain/utils/download_item_media.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';

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

enum DownloadMediaTypeFilter { all, video, audio }

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

final downloadMediaTypeFilterProvider = StateProvider<DownloadMediaTypeFilter>(
  (ref) => DownloadMediaTypeFilter.all,
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
  final mediaFilter = ref.watch(downloadMediaTypeFilterProvider);
  final sort = ref.watch(downloadSortProvider);

  return allDownloadsState.when(
    data: (allDownloads) {
      final filtered = allDownloads.where((item) {
        // 1. Search Query
        if (query.isNotEmpty) {
          final title = (item.title ?? '').toLowerCase();
          final url = item.request.url.toLowerCase();
          final source = item.source.toLowerCase();
          final filePath = (item.filePath ?? '').toLowerCase();
          if (!title.contains(query) &&
              !url.contains(query) &&
              !source.contains(query) &&
              !filePath.contains(query)) {
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

        if (mediaFilter != DownloadMediaTypeFilter.all) {
          final itemType = DownloadItemMedia.detect(item);
          switch (mediaFilter) {
            case DownloadMediaTypeFilter.video:
              if (itemType != DownloadMediaType.video) {
                return false;
              }
              break;
            case DownloadMediaTypeFilter.audio:
              if (itemType != DownloadMediaType.audio) {
                return false;
              }
              break;
            case DownloadMediaTypeFilter.all:
              break;
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
            return (a.title ?? '').compareTo(b.title ?? '');
          case DownloadSort.nameDesc:
            return (b.title ?? '').compareTo(a.title ?? '');
          case DownloadSort.sizeAsc:
            return _extractComparableSize(
              a,
            ).compareTo(_extractComparableSize(b));
          case DownloadSort.sizeDesc:
            return _extractComparableSize(
              b,
            ).compareTo(_extractComparableSize(a));
        }
      });

      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

int _extractComparableSize(DownloadItem item) {
  final total = FormatUtils.parseBytes(item.totalSize);
  if (total > 0) {
    return total;
  }

  return FormatUtils.parseBytes(item.downloadedSize);
}
