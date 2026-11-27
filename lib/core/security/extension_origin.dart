/// Which browser Origin values may talk to the local server.
///
/// Browsers set `Origin` themselves and a web page cannot forge it, so a
/// `https://…` origin means a page (not our extension) opened the socket.
class ExtensionOrigin {
  ExtensionOrigin._();

  static final _extensionOrigin = RegExp(
    r'^(chrome-extension|moz-extension)://[A-Za-z0-9-]{8,64}$',
  );

  static bool isExtensionOrigin(String? origin) =>
      origin != null && _extensionOrigin.hasMatch(origin);

  static final _scheme = RegExp(r'^[a-z][a-z0-9+.-]*$');

  /// Scheme only (`chrome-extension`, `https`...), never the extension id.
  /// The value is attacker-chosen, so anything odd is logged as `other`.
  static String originScheme(String? origin) {
    if (origin == null) return 'none';
    final i = origin.indexOf(':');
    final scheme = i > 0 ? origin.substring(0, i) : '';
    return scheme.length <= 20 && _scheme.hasMatch(scheme) ? scheme : 'other';
  }

  /// Stored label of an unrecognised browser: neutral, translated at display.
  static const unknownBrowser = 'Browser';

  /// Display name deduced from the User-Agent; the order matters because
  /// Edge, Opera and Vivaldi all also announce `Chrome/`.
  static String browserLabel(String? userAgent) {
    final ua = userAgent ?? '';
    if (ua.contains('Edg/')) return 'Edge';
    if (ua.contains('OPR/')) return 'Opera';
    if (ua.contains('Vivaldi')) return 'Vivaldi';
    if (ua.contains('Firefox/')) return 'Firefox';
    if (ua.contains('Chrome/')) return 'Chrome';
    return unknownBrowser;
  }
}
