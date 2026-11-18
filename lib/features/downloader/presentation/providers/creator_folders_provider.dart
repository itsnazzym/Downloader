import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/download/creator_folder_key.dart';
import 'package:modern_downloader/features/downloader/presentation/models/creator_folder.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';

final openedCreatorFolderKeyProvider = StateProvider<String?>((ref) => null);

/// List vs detailed layout for videos *inside* an opened creator folder.
final folderContentsViewModeProvider = StateProvider<DownloadViewMode>(
  (ref) => DownloadViewMode.list,
);

final creatorFoldersProvider = Provider<CreatorFolderList>((ref) {
  final order = switch (ref.watch(downloadSortProvider)) {
    DownloadSort.countDesc => CreatorFolderOrder.countDesc,
    DownloadSort.countAsc => CreatorFolderOrder.countAsc,
    _ => CreatorFolderOrder.name,
  };
  return ref.watch(
    filteredDownloadsProvider.select((async) {
      final items = async.valueOrNull;
      if (items == null || items.isEmpty) {
        return const CreatorFolderList([]);
      }
      return CreatorFolderList(
        CreatorFolderGrouper.fromItems(items, order: order),
      );
    }),
  );
});

final openedCreatorFolderProvider = Provider<CreatorFolder?>((ref) {
  final opened = ref.watch(openedCreatorFolderKeyProvider);
  if (opened == null) return null;
  final folders = ref.watch(creatorFoldersProvider).folders;
  for (final folder in folders) {
    if (folder.key == opened) return folder;
  }
  return null;
});

final openedCreatorFolderItemIdsProvider = Provider<DownloadIdList>((ref) {
  final opened = ref.watch(openedCreatorFolderKeyProvider);
  return ref.watch(
    filteredDownloadsProvider.select((async) {
      final items = async.valueOrNull;
      if (opened == null || items == null || items.isEmpty) {
        return const DownloadIdList([]);
      }
      return DownloadIdList([
        for (final item in items)
          if (CreatorFolderKey.of(
                url: item.request.url,
                title: item.title,
                filePath: item.filePath,
              ).key ==
              opened)
            item.id,
      ]);
    }),
  );
});
