import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:modern_downloader/core/logger/logger_service.dart';

/// Resolves unpackaged MV3 folders and opens the browser install pages.
///
/// End users may not have a dev `extension/` tree. [ensureChromeExtension] and
/// [ensureFirefoxExtension] materialize a copy under app support, downloading
/// from GitHub Releases when needed.
class BrowserExtensionInstaller {
  BrowserExtensionInstaller._();

  static const firefoxXpiUrl =
      'https://github.com/Mizaruta/Downloader/releases/latest/download/modern_downloader_firefox.xpi';

  static const chromeZipUrl =
      'https://github.com/Mizaruta/Downloader/releases/latest/download/modern_downloader_chrome.zip';

  static Directory? resolveChromeDir() {
    return _firstExistingDir(_candidateRoots(), 'chrome');
  }

  static Directory? resolveFirefoxDir() {
    return _firstExistingDir(_candidateRoots(), 'firefox');
  }

  /// Materializes Chrome's unpacked extension under Application Support.
  static Future<Directory?> ensureChromeExtension({
    bool forceRefresh = false,
  }) async {
    final dest = await _cachedBrowserDir('chrome');
    if (!forceRefresh && _hasValidManifest(dest)) return dest;

    try {
      if (dest.existsSync()) {
        dest.deleteSync(recursive: true);
      }

      final source = resolveChromeDir();
      if (source != null) {
        await _copyDir(source, dest);
        if (_hasValidManifest(dest)) {
          LoggerService.i('Chrome extension copied to ${dest.path}');
          return dest;
        }
        LoggerService.w('Chrome extension source has no manifest.json');
      }
    } catch (e, st) {
      LoggerService.e('Failed to cache Chrome extension', e, st);
    }

    return _downloadAndExtract(chromeZipUrl, dest, browser: 'chrome');
  }

  /// Dev folder, bundled copy, or XPI extracted to cache.
  static Future<Directory?> ensureFirefoxExtension({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final existing = resolveFirefoxDir();
      if (existing != null) return existing;

      final cached = await _cachedBrowserDir('firefox');
      if (_hasValidManifest(cached)) return cached;
    } else {
      final cached = await _cachedBrowserDir('firefox');
      if (cached.existsSync()) cached.deleteSync(recursive: true);
    }

    final dest = await _cachedBrowserDir('firefox');
    return _downloadAndExtract(firefoxXpiUrl, dest, browser: 'firefox');
  }

  /// Headless download of the Chrome ZIP into the user's Downloads folder.
  static Future<File?> saveChromeZipToDownloads() async {
    return _downloadUrlToDownloads(
      chromeZipUrl,
      'modern_downloader_chrome.zip',
    );
  }

  /// Downloads the XPI to a temp file (headless). Returns null on failure.
  static Future<File?> downloadFirefoxXpiToTemp() async {
    try {
      final temp = await getTemporaryDirectory();
      final xpi = File(p.join(temp.path, 'modern_downloader_firefox.xpi'));
      final ok = await _downloadUrlToFile(firefoxXpiUrl, xpi);
      return ok ? xpi : null;
    } catch (e) {
      LoggerService.w('Firefox XPI temp download failed: $e');
      return null;
    }
  }

  /// Opens Firefox with a local `.xpi` file path.
  static Future<bool> launchFirefoxWithXpi(File xpi) async {
    if (!xpi.existsSync()) return false;
    if (Platform.isWindows) {
      return _openWindowsBrowser(executables: _windowsFirefox(), url: xpi.path);
    }
    if (Platform.isMacOS) {
      return _run('open', ['-a', 'Firefox', xpi.path]);
    }
    return _run('firefox', [xpi.path]);
  }

  /// Downloads the XPI locally, then asks Firefox to install it (no browser tab).
  static Future<bool> installFirefoxAddOn() async {
    try {
      final xpi = await downloadFirefoxXpiToTemp();
      if (xpi == null) return false;
      return await launchFirefoxWithXpi(xpi);
    } catch (e) {
      LoggerService.w('Firefox headless install failed: $e');
      return false;
    }
  }

  static Future<void> copyPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
  }

  static Future<bool> openChromeExtensionsPage() async {
    if (Platform.isWindows) {
      return _openWindowsBrowser(
        executables: _windowsChromeLike(),
        url: 'chrome://extensions',
      );
    }
    if (Platform.isMacOS) {
      return _run('open', ['-a', 'Google Chrome', 'chrome://extensions']);
    }
    return _run('xdg-open', ['chrome://extensions']);
  }

  static Future<bool> openFirefoxDebuggingPage() async {
    const page = 'about:debugging#/runtime/this-firefox';
    if (Platform.isWindows) {
      return _openWindowsBrowser(executables: _windowsFirefox(), url: page);
    }
    if (Platform.isMacOS) {
      return _run('open', ['-a', 'Firefox', page]);
    }
    return _run('firefox', [page]);
  }

  static Future<Directory> _cachedBrowserDir(String browser) async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'extensions', browser));
    dir.createSync(recursive: true);
    return dir;
  }

  static bool _hasValidManifest(Directory dir) {
    return File(p.join(dir.path, 'manifest.json')).existsSync();
  }

  static Future<Directory?> _downloadAndExtract(
    String url,
    Directory dest, {
    required String browser,
  }) async {
    try {
      LoggerService.i('Downloading $browser extension from $url');
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        LoggerService.w('Extension download HTTP ${response.statusCode}');
        return null;
      }

      if (dest.existsSync()) {
        dest.deleteSync(recursive: true);
      }
      dest.createSync(recursive: true);

      final archive = ZipDecoder().decodeBytes(response.bodyBytes);
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final name = entry.name.replaceAll('\\', '/');
        if (name.contains('..')) continue;
        final out = File(p.join(dest.path, name));
        out.parent.createSync(recursive: true);
        await out.writeAsBytes(entry.content as List<int>);
      }

      if (!_hasValidManifest(dest)) {
        LoggerService.w('Downloaded $browser archive has no manifest.json');
        return null;
      }

      LoggerService.i('$browser extension ready at ${dest.path}');
      return dest;
    } catch (e, st) {
      LoggerService.e('Failed to materialize $browser extension', e, st);
      return null;
    }
  }

  static Future<bool> _downloadUrlToFile(String url, File dest) async {
    try {
      LoggerService.i('Headless download → ${dest.path}');
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        LoggerService.w('Download HTTP ${response.statusCode} for $url');
        return false;
      }
      dest.parent.createSync(recursive: true);
      await dest.writeAsBytes(response.bodyBytes);
      return true;
    } catch (e, st) {
      LoggerService.e('Headless download failed', e, st);
      return false;
    }
  }

  static Future<void> _copyDir(Directory source, Directory destination) async {
    destination.createSync(recursive: true);
    await for (final entity in source.list(recursive: true)) {
      final relative = p.relative(entity.path, from: source.path);
      final targetPath = p.join(destination.path, relative);
      if (entity is Directory) {
        Directory(targetPath).createSync(recursive: true);
      } else if (entity is File) {
        final target = File(targetPath);
        target.parent.createSync(recursive: true);
        await entity.copy(target.path);
      }
    }
  }

  static Future<File?> _downloadUrlToDownloads(
    String url,
    String filename,
  ) async {
    final downloads = await getDownloadsDirectory();
    if (downloads == null) {
      LoggerService.w('Downloads directory unavailable');
      return null;
    }
    final dest = File(p.join(downloads.path, filename));
    final ok = await _downloadUrlToFile(url, dest);
    return ok ? dest : null;
  }

  static List<String> _candidateRoots() {
    final roots = <String>{};
    roots.add(Directory.current.path);
    try {
      var exeDir = File(Platform.resolvedExecutable).parent;
      for (var i = 0; i < 6; i++) {
        roots.add(exeDir.path);
        final parent = exeDir.parent;
        if (parent.path == exeDir.path) break;
        exeDir = parent;
      }
    } catch (e) {
      LoggerService.w('Could not resolve executable dir: $e');
    }
    return roots.toList();
  }

  static Directory? _firstExistingDir(List<String> roots, String browser) {
    for (final root in roots) {
      final dir = Directory(p.join(root, 'extension', browser));
      if (dir.existsSync()) return dir;
    }
    return null;
  }

  static List<String> _windowsChromeLike() {
    final local = Platform.environment['LOCALAPPDATA'] ?? '';
    final pf = Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
    final pf86 =
        Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)';
    return [
      p.join(local, r'Google\Chrome\Application\chrome.exe'),
      p.join(pf, r'Google\Chrome\Application\chrome.exe'),
      p.join(pf86, r'Google\Chrome\Application\chrome.exe'),
      p.join(local, r'Microsoft\Edge\Application\msedge.exe'),
      p.join(pf, r'Microsoft\Edge\Application\msedge.exe'),
      p.join(local, r'BraveSoftware\Brave-Browser\Application\brave.exe'),
    ];
  }

  static List<String> _windowsFirefox() {
    final pf = Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
    final pf86 =
        Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)';
    return [
      p.join(pf, r'Mozilla Firefox\firefox.exe'),
      p.join(pf86, r'Mozilla Firefox\firefox.exe'),
    ];
  }

  static Future<bool> _openWindowsBrowser({
    required List<String> executables,
    required String url,
  }) async {
    for (final exe in executables) {
      if (!File(exe).existsSync()) continue;
      try {
        await Process.start(exe, [url]);
        return true;
      } catch (e) {
        LoggerService.w('Failed to launch $exe: $e');
      }
    }
    try {
      await Process.start('cmd', ['/c', 'start', '', url], runInShell: false);
      return true;
    } catch (e) {
      LoggerService.w('Failed to open $url: $e');
      return false;
    }
  }

  static Future<bool> _run(String executable, List<String> args) async {
    try {
      await Process.start(executable, args);
      return true;
    } catch (e) {
      LoggerService.w('Failed to run $executable: $e');
      return false;
    }
  }
}
