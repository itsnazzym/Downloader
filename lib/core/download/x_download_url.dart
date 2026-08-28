/// Canonicalizes X/Twitter media URLs to a tweet permalink when one is known.
class XDownloadUrl {
  XDownloadUrl._();

  static final RegExp _statusPath = RegExp(
    r'^/(?:[^/]+/status|i/(?:web/)?status)/(\d+)',
  );

  static final RegExp _statusTweetId = RegExp(
    r'/(?:[^/]+/status|i/(?:web/)?status)/(\d{15,20})(?:\D|$)',
  );

  /// Numeric IDs in Twitter CDN paths identify the *media asset*, which can be
  /// shared across authors (quotes, retweets). They are not tweet snowflakes.
  static final RegExp _mediaAssetId = RegExp(
    r'/(?:ext_tw_video(?:_thumb)?|amplify_video(?:_thumb)?|tweet_video(?:_thumb)?)/(\d{15,20})(?:/|\.|$)',
    caseSensitive: false,
  );
  static bool isXFamilyHost(String host) {
    final normalized = _normalizeHost(host);
    return _hostMatches(normalized, 'x.com') ||
        _hostMatches(normalized, 'twitter.com') ||
        _hostMatches(normalized, 'twimg.com') ||
        _hostMatches(normalized, 'pscp.tv');
  }

  static bool isCdnHost(String host) {
    final normalized = _normalizeHost(host);
    return _hostMatches(normalized, 'twimg.com') ||
        _hostMatches(normalized, 'pscp.tv');
  }

  static bool isXFamilyUrl(String url) {
    final uri = _tryParseHttp(url);
    if (uri == null) return false;
    return isXFamilyHost(uri.host);
  }

  /// Returns a query-stripped permalink when [url] is an X/Twitter status URL.
  static String? statusPermalink(String url) {
    try {
      final uri = _tryParseHttp(url);
      if (uri == null) return null;
      final host = uri.host.toLowerCase();
      if (!_hostMatches(host, 'x.com') && !_hostMatches(host, 'twitter.com')) {
        return null;
      }
      if (_statusPath.firstMatch(uri.path) == null) return null;
      return Uri(
        scheme: uri.scheme,
        userInfo: uri.userInfo,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: uri.path,
      ).toString();
    } catch (_) {
      return null;
    }
  }

  static bool isCdnUrl(String url) {
    final uri = _tryParseHttp(url);
    if (uri == null) return false;
    return isCdnHost(uri.host);
  }

  /// Prefer a tweet permalink over a CDN media URL.
  ///
  /// An existing `/status/{id}` URL is kept even if [pageUrl] is `/home`.
  /// `x.com/home` never replaces a media URL. CDN hosts (`twimg.com`,
  /// `pscp.tv`) are rewritten only when [pageUrl] itself is a status permalink.
  static String canonicalize(String mediaUrl, [String? pageUrl]) {
    return resolveForDownload(mediaUrl, pageUrl) ?? mediaUrl;
  }

  /// URL that yt-dlp may fetch, or null when an X CDN file has no tweet id.
  ///
  /// Status permalinks are returned stripped of query/hash. CDN hosts are
  /// rewritten only from a status [pageUrl]. Non-X URLs pass through unchanged.
  static String? resolveForDownload(String mediaUrl, [String? pageUrl]) {
    try {
      final permalink = statusPermalink(mediaUrl);
      if (permalink != null) return permalink;

      final mediaUri = _tryParseHttp(mediaUrl);
      if (mediaUri == null) return mediaUrl;

      if (isCdnHost(mediaUri.host)) {
        if (pageUrl == null || pageUrl.trim().isEmpty) return null;
        return statusPermalink(pageUrl);
      }
      return mediaUrl;
    } catch (_) {
      return mediaUrl;
    }
  }

  static String _normalizeHost(String host) {
    var normalized = host.trim().toLowerCase();
    if (normalized.startsWith('.')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  static bool _hostMatches(String host, String domain) {
    return host == domain || host.endsWith('.$domain');
  }

  /// Extracts a tweet snowflake from a status URL.
  ///
  /// Numeric IDs in `video.twimg.com/amplify_video/...` and
  /// `ext_tw_video/...` are media IDs, not necessarily tweet IDs. They cannot
  /// safely be used to build a status permalink.
  static String? tweetIdFrom(String? text) {
    if (text == null) return null;
    final value = text.trim();
    if (value.isEmpty) return null;

    final status = _statusTweetId.firstMatch(value);
    if (status != null) return status.group(1);
    return null;
  }

  /// Extracts a stable X media asset id from a CDN or thumbnail URL.
  ///
  /// The same video posted by another author keeps this id on
  /// `ext_tw_video` / `ext_tw_video_thumb` / `amplify_video` paths.
  static String? mediaAssetIdFrom(String? text) {
    if (text == null) return null;
    final value = text.trim();
    if (value.isEmpty) return null;
    return _mediaAssetId.firstMatch(value)?.group(1);
  }

  /// Permalink that yt-dlp can resolve without knowing the handle.
  static String permalinkForTweetId(String tweetId) {
    return 'https://x.com/i/status/${tweetId.trim()}';
  }

  static Uri? _tryParseHttp(String value) {
    try {
      final uri = Uri.parse(value.trim());
      if (uri.host.isEmpty) return null;
      if (uri.scheme != 'http' && uri.scheme != 'https') return null;
      return uri;
    } catch (_) {
      return null;
    }
  }
}
