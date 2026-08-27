class ProtocolUrlParser {
  static String? extractMediaUrl(String uriString) {
    try {
      final uri = Uri.parse(uriString);
      final url = uri.queryParameters['url'];
      if (url != null && url.isNotEmpty) {
        return url;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
