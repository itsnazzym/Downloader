/// Extracts http(s) media URLs from Android share-sheet / intent text.
class ShareUrlExtractor {
  ShareUrlExtractor._();

  static final RegExp _urlPattern = RegExp(
    r'https?://[^\s<>"{}|\\^`\[\]]+',
    caseSensitive: false,
  );

  /// Returns the first usable http(s) URL, preferring tweet permalinks.
  static String? extract(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;

    if (!text.contains(RegExp(r'\s'))) {
      final direct = _tryParseHttp(text);
      if (direct != null) return _stripTrailingPunctuation(direct.toString());
    }

    final matches = _urlPattern.allMatches(text).toList();
    if (matches.isEmpty) return null;

    String? first;
    for (final match in matches) {
      final candidate = _stripTrailingPunctuation(match.group(0) ?? '');
      final uri = _tryParseHttp(candidate);
      if (uri == null) continue;
      first ??= uri.toString();
      final host = uri.host.toLowerCase();
      if (host == 'x.com' ||
          host.endsWith('.x.com') ||
          host == 'twitter.com' ||
          host.endsWith('.twitter.com')) {
        return uri.toString();
      }
    }
    return first;
  }

  static String _stripTrailingPunctuation(String value) {
    return value.replaceAll(RegExp(r'[),.;!?]+$'), '');
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
