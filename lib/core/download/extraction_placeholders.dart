import 'package:modern_downloader/core/download/x_download_url.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';
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

  static String titleForUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      final host = uri.host.toLowerCase();
      if (host.isNotEmpty) {
        if (_hostMatches(host, 'youtube.com') ||
            _hostMatches(host, 'youtu.be')) {
          return 'YouTube Video';
        }
        if (XDownloadUrl.isXFamilyHost(host)) {
          return 'Twitter Video';
        }
        if (_hostMatches(host, 'twitch.tv')) {
          return 'Twitch Video';
        }
        if (_hostMatches(host, 'tiktok.com')) {
          return 'TikTok Video';
        }
        if (_hostMatches(host, 'kick.com')) {
          return 'Kick Video';
        }
      }
    } catch (_) {
      // Fall through to URL-derived title.
    }
    return TitleCleanerService.deriveTitleFromUrl(url);
  }

  static bool _hostMatches(String host, String domain) {
    return host == domain || host.endsWith('.$domain');
  }

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
