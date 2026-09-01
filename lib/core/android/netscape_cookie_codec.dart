/// Converts Android WebView `Cookie` headers into a Netscape cookies.txt body
/// that yt-dlp accepts via `--cookies`.
class NetscapeCookieCodec {
  NetscapeCookieCodec._();

  static String fromHeader({required String host, required String header}) {
    final buffer = StringBuffer('# Netscape HTTP Cookie File\n');
    final domain = _cookieDomain(host);
    final parts = header.split(';');
    for (final part in parts) {
      final pair = part.trim();
      if (pair.isEmpty) continue;
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      final name = pair.substring(0, eq).trim();
      final value = pair.substring(eq + 1).trim();
      if (name.isEmpty) continue;
      buffer.writeln('$domain\tTRUE\t/\tTRUE\t0\t$name\t$value');
    }
    return buffer.toString();
  }

  static String _cookieDomain(String host) {
    var normalized = host.trim().toLowerCase();
    if (normalized.startsWith('.')) return normalized;
    if (normalized.startsWith('www.')) {
      normalized = normalized.substring(4);
    }
    return '.$normalized';
  }
}
