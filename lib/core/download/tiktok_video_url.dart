/// Converts TikTok's export-only `/video/<id>` links into a URL supported by
/// yt-dlp's TikTok extractor. Creator permalinks are kept intact.
class TikTokVideoUrl {
  TikTokVideoUrl._();

  static final RegExp _bareVideoPath = RegExp(r'^/video/(\d{8,})/?$');

  static String forDownload(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return url;
    }
    if (uri.host != 'tiktok.com' &&
        uri.host != 'www.tiktok.com' &&
        uri.host != 'm.tiktok.com') {
      return url;
    }
    final videoId = _bareVideoPath.firstMatch(uri.path)?.group(1);
    if (videoId == null) return url;
    return 'https://www.tiktokv.com/share/video/$videoId/';
  }

  static final RegExp _videoIdRegex = RegExp(r'(\d{15,})');

  /// Extracts the numeric TikTok video ID from a TikTok or TikTokv URL.
  static String? extractVideoId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri != null &&
        (uri.host.contains('tiktok.com') || uri.host.contains('tiktokv.com'))) {
      return _videoIdRegex.firstMatch(uri.path)?.group(1);
    }
    return null;
  }
}
