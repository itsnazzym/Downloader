import 'package:flutter/foundation.dart';
import 'package:modern_downloader/core/download/creator_folder_key.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';

/// A creator vault: username + the downloads that belong to it.
@immutable
class CreatorFolder {
  const CreatorFolder({
    required this.key,
    required this.handle,
    required this.itemIds,
    required this.previewUrls,
  });

  final String key;
  final String? handle;
  final List<String> itemIds;
  final List<String?> previewUrls;

  int get count => itemIds.length;

  bool get isUnknown => handle == null || handle!.isEmpty;

  int get overflowCount => count > 4 ? count - 4 : 0;

  @override
  bool operator ==(Object other) {
    return other is CreatorFolder &&
        other.key == key &&
        other.handle == handle &&
        listEquals(other.itemIds, itemIds) &&
        listEquals(other.previewUrls, previewUrls);
  }

  @override
  int get hashCode => Object.hash(
    key,
    handle,
    Object.hashAll(itemIds),
    Object.hashAll(previewUrls),
  );
}

@immutable
class CreatorFolderList {
  const CreatorFolderList(this.folders);

  final List<CreatorFolder> folders;

  @override
  bool operator ==(Object other) {
    return other is CreatorFolderList && listEquals(other.folders, folders);
  }

  @override
  int get hashCode => Object.hashAll(folders);
}

enum CreatorFolderOrder { name, countDesc, countAsc }

class CreatorFolderGrouper {
  const CreatorFolderGrouper._();

  static List<CreatorFolder> fromItems(
    List<DownloadItem> items, {
    CreatorFolderOrder order = CreatorFolderOrder.name,
  }) {
    final keys = <String>[];
    final handles = <String, String?>{};
    final ids = <String, List<String>>{};
    final thumbs = <String, List<String?>>{};

    for (final item in items) {
      final identity = CreatorFolderKey.of(
        url: item.request.url,
        title: item.title,
        filePath: item.filePath,
      );
      if (!ids.containsKey(identity.key)) {
        keys.add(identity.key);
        handles[identity.key] = identity.handle;
        ids[identity.key] = <String>[];
        thumbs[identity.key] = <String?>[];
      }
      ids[identity.key]!.add(item.id);
      final preview = thumbs[identity.key]!;
      if (preview.length < 4) {
        final url = item.thumbnailUrl;
        preview.add(url != null && url.trim().isNotEmpty ? url : null);
      }
    }

    final folders = [
      for (final key in keys)
        CreatorFolder(
          key: key,
          handle: handles[key],
          itemIds: List<String>.unmodifiable(ids[key]!),
          previewUrls: List<String?>.unmodifiable(thumbs[key]!),
        ),
    ];

    folders.sort((a, b) {
      if (order == CreatorFolderOrder.countDesc ||
          order == CreatorFolderOrder.countAsc) {
        final byCount = order == CreatorFolderOrder.countDesc
            ? b.count.compareTo(a.count)
            : a.count.compareTo(b.count);
        if (byCount != 0) return byCount;
      } else {
        if (a.isUnknown && !b.isUnknown) return 1;
        if (!a.isUnknown && b.isUnknown) return -1;
      }
      final left = (a.handle ?? '').toLowerCase();
      final right = (b.handle ?? '').toLowerCase();
      return left.compareTo(right);
    });

    return folders;
  }
}
