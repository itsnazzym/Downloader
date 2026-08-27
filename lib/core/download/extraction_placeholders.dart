import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

/// Placeholder titles set before yt-dlp metadata arrives.
class ExtractionPlaceholders {
  ExtractionPlaceholders._();

  static const Set<String> genericTitles = {
    'YouTube Video',
    'Twitter Video',
    'Twitch Video',
    'TikTok Video',
    'Kick Video',
    'Instagram Video',
    'Video',
  };

  static bool isGenericTitle(String? title) {
    if (title == null) return true;
    final trimmed = title.trim();
    if (trimmed.isEmpty) return true;
    if (genericTitles.contains(trimmed)) return true;
    return trimmed.startsWith('Video ');
  }

  static bool showThumbnailSpinner({
    required DownloadStatus status,
    required String? thumbnailUrl,
  }) {
    final hasThumb = thumbnailUrl != null && thumbnailUrl.trim().isNotEmpty;
    if (hasThumb) return false;
    return status == DownloadStatus.extracting;
  }

  static bool showExtractingSize({
    required DownloadStatus status,
    required String totalSize,
  }) {
    if (status != DownloadStatus.extracting) return false;
    return totalSize.trim().isEmpty;
  }

  static bool showExtractingSource({
    required DownloadStatus status,
    required String source,
  }) {
    if (status != DownloadStatus.extracting) return false;
    return source.trim().isEmpty;
  }
}
