class CookieBrowserArgs {
  static const String defaultBrowser = 'firefox';

  static String resolve(String? browser) {
    if (browser == null) return defaultBrowser;
    final trimmed = browser.trim();
    if (trimmed.isEmpty || trimmed == 'auto' || trimmed == 'none') {
      return defaultBrowser;
    }
    return trimmed;
  }

  static List<String> ytDlpArgs(String? browser) {
    return ['--cookies-from-browser', resolve(browser)];
  }
}
