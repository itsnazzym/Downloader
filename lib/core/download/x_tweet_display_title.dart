import 'package:modern_downloader/core/services/title_cleaner_service.dart';

/// Builds the same Twitter display title used during a live download.
class XTweetDisplayTitle {
  XTweetDisplayTitle._();

  static String fromMetadata(
    Map<String, dynamic> metadata, {
    required String tweetId,
  }) {
    final fetchedTitle = _asString(metadata['title']);
    final rawId = _asString(metadata['id']);
    final suppliedId = tweetId.trim();
    final videoId = suppliedId.isNotEmpty ? suppliedId : rawId;
    final uploader =
        _asString(metadata['uploader']) ?? _asString(metadata['uploader_id']);

    var finalTitle = fetchedTitle;
    final titleIsUseless =
        fetchedTitle == null ||
        fetchedTitle.isEmpty ||
        fetchedTitle == videoId ||
        fetchedTitle.contains('twitter.com') ||
        TitleCleanerService.isUrlOnlyTitle(fetchedTitle);

    if (titleIsUseless) {
      if (uploader != null && videoId != null && videoId.isNotEmpty) {
        finalTitle = '$uploader - $videoId';
      } else if (videoId != null && videoId.isNotEmpty) {
        finalTitle = 'Tweet $videoId';
      } else {
        finalTitle = fetchedTitle ?? 'Twitter Video';
      }
    }

    var cleaned = TitleCleanerService.clean(finalTitle ?? '');
    if (cleaned.isEmpty) {
      if (videoId != null && videoId.isNotEmpty) {
        cleaned = uploader != null ? '$uploader - $videoId' : 'Tweet $videoId';
      } else {
        cleaned = 'Twitter Video';
      }
    }
    return cleaned;
  }

  static bool hasUsableTweetText(
    Map<String, dynamic> metadata, {
    required String tweetId,
  }) {
    final title = _asString(metadata['title']);
    if (title == null || title == tweetId) return false;
    if (title == 'Twitter Video' || title.startsWith('Video ')) return false;
    if (TitleCleanerService.isUrlOnlyTitle(title)) return false;
    return TitleCleanerService.clean(title).isNotEmpty;
  }

  static String? _asString(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) {
      return value.toString();
    }
    return null;
  }
}
