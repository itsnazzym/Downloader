import 'cookie_browser_args.dart';

/// Builds yt-dlp cookie-related CLI args with correct precedence.
///
/// Priority:
/// 1. `--cookies <file>` when [cookiesFilePath] is set
/// 2. Netscape [rawCookies] (contains tabs) → caller must write a file first;
///    this builder never puts Netscape into `--add-header Cookie:`
/// 3. Header-style [rawCookies] (`a=b; c=d`) → `--add-header Cookie:...`
/// 4. Else `--cookies-from-browser` (skipped when a cookies file is used)
class YtDlpCookieArgs {
  static bool isNetscapeFormat(String? cookies) {
    if (cookies == null || cookies.isEmpty) return false;
    return cookies.contains('\t');
  }

  static bool isHeaderFormat(String? cookies) {
    if (cookies == null || cookies.isEmpty) return false;
    if (isNetscapeFormat(cookies)) return false;
    return cookies.contains('=');
  }

  /// Prefer a URL/host-specific cookies file over the global settings path.
  ///
  /// Prevents a YouTube heartbeat cookies file from being used for Twitter, etc.
  static String? resolveCookiesFilePath({
    String? urlSpecificPath,
    String? globalPath,
  }) {
    final specific = urlSpecificPath?.trim();
    if (specific != null && specific.isNotEmpty) return specific;
    final global = globalPath?.trim();
    if (global != null && global.isNotEmpty) return global;
    return null;
  }

  /// Returns yt-dlp args. When [rawCookies] is Netscape and [cookiesFilePath]
  /// is null, returns empty cookie args (caller should materialize a file).
  static List<String> build({
    String? cookiesFilePath,
    String? rawCookies,
    String? cookieBrowser,
  }) {
    final filePath = cookiesFilePath?.trim();
    if (filePath != null && filePath.isNotEmpty) {
      return ['--cookies', filePath];
    }

    if (isNetscapeFormat(rawCookies)) {
      // Never inject Netscape body as Cookie header.
      return const [];
    }

    if (isHeaderFormat(rawCookies)) {
      return ['--add-header', 'Cookie:${rawCookies!}'];
    }

    return CookieBrowserArgs.ytDlpArgs(cookieBrowser);
  }

  static bool usesCookiesFile({String? cookiesFilePath, String? rawCookies}) {
    final filePath = cookiesFilePath?.trim();
    if (filePath != null && filePath.isNotEmpty) return true;
    return isNetscapeFormat(rawCookies);
  }
}
