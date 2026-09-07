import 'dart:io';

class CookieBrowserArgs {
  static const String defaultBrowser = 'firefox';

  /// Probes the system filesystem to find an installed browser with a profile.
  static String? probeInstalledBrowser() {
    try {
      if (Platform.isWindows) {
        final localAppData = Platform.environment['LOCALAPPDATA'];
        final appData = Platform.environment['APPDATA'];

        if (localAppData != null) {
          if (Directory('$localAppData\\Google\\Chrome\\User Data').existsSync()) {
            return 'chrome';
          }
          if (Directory('$localAppData\\Microsoft\\Edge\\User Data').existsSync()) {
            return 'edge';
          }
          if (Directory('$localAppData\\BraveSoftware\\Brave-Browser\\User Data')
              .existsSync()) {
            return 'brave';
          }
          if (Directory('$localAppData\\Vivaldi\\User Data').existsSync()) {
            return 'vivaldi';
          }
        }
        if (appData != null) {
          if (Directory('$appData\\Mozilla\\Firefox\\Profiles').existsSync()) {
            return 'firefox';
          }
          if (Directory('$appData\\Opera Software\\Opera Stable').existsSync()) {
            return 'opera';
          }
        }
      } else if (Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          if (Directory('$home/Library/Application Support/Google/Chrome')
              .existsSync()) {
            return 'chrome';
          }
          if (Directory(
            '$home/Library/Application Support/BraveSoftware/Brave-Browser',
          ).existsSync()) {
            return 'brave';
          }
          if (Directory('$home/Library/Application Support/Microsoft Edge')
              .existsSync()) {
            return 'edge';
          }
          if (Directory('$home/Library/Application Support/Firefox/Profiles')
              .existsSync()) {
            return 'firefox';
          }
        }
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          if (Directory('$home/.config/google-chrome').existsSync()) {
            return 'chrome';
          }
          if (Directory('$home/.mozilla/firefox').existsSync()) {
            return 'firefox';
          }
          if (Directory('$home/.config/BraveSoftware/Brave-Browser')
              .existsSync()) {
            return 'brave';
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static String resolve(String? browser, {bool autoDetect = false}) {
    if (browser == null) {
      return autoDetect
          ? (probeInstalledBrowser() ?? defaultBrowser)
          : defaultBrowser;
    }
    final trimmed = browser.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed == 'auto') {
      return autoDetect
          ? (probeInstalledBrowser() ?? defaultBrowser)
          : defaultBrowser;
    }
    if (trimmed == 'none') {
      return 'none';
    }
    return trimmed;
  }

  static List<String> ytDlpArgs(String? browser) {
    final resolved = resolve(browser, autoDetect: true);
    if (resolved == 'none') {
      return const [];
    }
    return ['--cookies-from-browser', resolved];
  }
}
