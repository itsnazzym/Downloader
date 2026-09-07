import 'package:modern_downloader/core/download/x_download_url.dart';

/// URL gate for extension / manual downloads.
///
/// Any public http(s) page is allowed (yt-dlp generic extractor). Known
/// [adultDomains] stay behind [includeAdult]. Keep list names in sync with
/// `ALLOWED_DOWNLOAD_DOMAINS` / `ADULT_DOMAINS` in `extension/shared/url_policy.js`.
class DownloadUrlPolicy {
  DownloadUrlPolicy._();

  static const Set<String> allowedDomains = {
    'youtube.com',
    'youtu.be',
    'instagram.com',
    'twitter.com',
    'x.com',
    'tiktok.com',
    'twitch.tv',
    'facebook.com',
    'fb.watch',
    'kick.com',
    'reddit.com',
    'redd.it',
    'vimeo.com',
    'dailymotion.com',
    'soundcloud.com',
    'bilibili.com',
    'rumble.com',
    'threads.net',
    'bsky.app',
  };

  static const Set<String> adultDomains = {
    'pornhub.com',
    'xvideos.com',
    'xnxx.com',
    'xhamster.com',
  };

  /// Returns true when [url] may be handed to yt-dlp / gallery-dl.
  static bool isAllowed(String url, {bool includeAdult = true}) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;

    if (XDownloadUrl.statusPermalink(trimmed) != null) return true;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (uri.host.isEmpty) return false;

    if (XDownloadUrl.isCdnHost(uri.host)) return false;

    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1' || host.endsWith('.local')) {
      return false;
    }
    if (!includeAdult) {
      for (final domain in adultDomains) {
        if (_hostMatches(host, domain)) return false;
      }
    }
    return true;
  }

  static bool _hostMatches(String host, String domain) {
    return host == domain || host.endsWith('.$domain');
  }
}
