/// Rewrites desktop yt-dlp flags so they work with youtubedl-android.
class AndroidYtDlpArgs {
  const AndroidYtDlpArgs._();

  static List<String> sanitize(List<String> args) {
    final sanitized = <String>[];
    var skipNext = false;
    for (var i = 0; i < args.length; i++) {
      if (skipNext) {
        skipNext = false;
        continue;
      }
      final current = args[i];
      final next = i + 1 < args.length ? args[i + 1] : null;

      if (current == '--cookies-from-browser') {
        skipNext = next != null && !next.startsWith('-');
        continue;
      }

      if (current == '--downloader' && next == 'aria2c') {
        sanitized.add(current);
        sanitized.add('libaria2c.so');
        skipNext = true;
        continue;
      }

      if (current == 'aria2c' &&
          sanitized.isNotEmpty &&
          sanitized.last == '--downloader') {
        sanitized.add('libaria2c.so');
        continue;
      }

      sanitized.add(current);
    }
    return sanitized;
  }
}
