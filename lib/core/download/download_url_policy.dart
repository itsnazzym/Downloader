import 'package:modern_downloader/core/download/x_download_url.dart';

/// Host allowlist for extension / manual download URLs.
class DownloadUrlPolicy {
  DownloadUrlPolicy._();

  static const Set<String> _allowedDomains = {
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
    'pornhub.com',
    'xvideos.com',
    'xnxx.com',
    'xhamster.com',
  };

  /// Returns true when [url] may be handed to yt-dlp / gallery-dl.
  static bool isAllowed(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;

    if (XDownloadUrl.statusPermalink(trimmed) != null) return true;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (uri.host.isEmpty) return false;

    if (XDownloadUrl.isCdnHost(uri.host)) return false;

    final host = uri.host.toLowerCase();
    for (final domain in _allowedDomains) {
      if (_hostMatches(host, domain)) return true;
    }
    return false;
  }

  static bool _hostMatches(String host, String domain) {
    return host == domain || host.endsWith('.$domain');
  }
}
