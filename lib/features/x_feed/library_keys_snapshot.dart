import 'dart:io';

import 'package:modern_downloader/core/download/x_download_url.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

/// Sanitized tweet / media ids for the extension Downloaded overlay.
///
/// Never includes file paths, cookies, titles, or author names.
class LibraryKeysSnapshot {
  static const String requestType = 'LIBRARY_KEYS';
  static const String resultType = 'LIBRARY_KEYS_RESULT';
  static const int maxIds = 4000;

  final List<String> tweetIds;
  final List<String> mediaIds;

  const LibraryKeysSnapshot({required this.tweetIds, required this.mediaIds});

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': resultType,
      'ok': true,
      'tweetIds': List<String>.from(tweetIds),
      'mediaIds': List<String>.from(mediaIds),
    };
  }

  static LibraryKeysSnapshot fromDownloads(
    List<DownloadItem> items, {
    bool Function(String path)? fileExists,
  }) {
    final exists = fileExists ?? _defaultFileExists;
    final tweets = <String>{};
    final media = <String>{};

    for (final item in items) {
      if (!_includeItem(item, exists)) continue;
      for (final source in _idSources(item)) {
        final tweetId = XDownloadUrl.tweetIdFrom(source);
        if (tweetId != null) tweets.add(tweetId);
        final mediaId = XDownloadUrl.mediaAssetIdFrom(source);
        if (mediaId != null) media.add(mediaId);
      }
    }

    final tweetList = tweets.toList()..sort();
    final mediaList = media.toList()..sort();
    return LibraryKeysSnapshot(
      tweetIds: _cap(tweetList),
      mediaIds: _cap(mediaList),
    );
  }

  static bool _includeItem(
    DownloadItem item,
    bool Function(String path) fileExists,
  ) {
    if (item.status == DownloadStatus.duplicate) return true;
    if (item.status != DownloadStatus.completed) return false;
    final path = item.filePath;
    if (path == null || path.isEmpty) return false;
    try {
      return fileExists(path);
    } catch (_) {
      return false;
    }
  }

  static Iterable<String?> _idSources(DownloadItem item) {
    return <String?>[
      item.request.url,
      item.request.forceStreamUrl,
      item.request.forceThumbnailUrl,
      item.thumbnailUrl,
    ];
  }

  static bool _defaultFileExists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  static List<String> _cap(List<String> ids) {
    if (ids.length <= maxIds) return ids;
    return ids.sublist(ids.length - maxIds);
  }
}
