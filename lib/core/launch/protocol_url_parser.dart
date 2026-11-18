class ProtocolUrlParser {
  static String? extractPluginId(String uriString) {
    try {
      if (uriString.contains('%') ||
          RegExp(r'(^|/)\.\.?(/|$)').hasMatch(uriString)) {
        return null;
      }
      final uri = Uri.parse(uriString);
      if (uri.scheme != 'moderndownloader' ||
          uri.host != 'plugin' ||
          uri.query.isNotEmpty ||
          uri.fragment.isNotEmpty ||
          uri.pathSegments.length != 1) {
        return null;
      }
      final pluginId = uri.pathSegments.single;
      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(pluginId)) return null;
      return pluginId;
    } catch (_) {
      return null;
    }
  }

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
