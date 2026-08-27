import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/logger/logger_service.dart';

class BinaryLocator {
  static const String ytDlpName = 'yt-dlp';
  static const String ffmpegName = 'ffmpeg';
  static const String ffprobeName = 'ffprobe';
  static const String galleryDlName = 'gallery-dl';
  static const String gobirdName = 'gobird';

  // Custom paths can be set from settings
  String? _customGalleryDlPath;

  void setGalleryDlPath(String? path) {
    _customGalleryDlPath = path;
    LoggerService.i('gallery-dl path set to: $path');
  }

  Future<String?> findYtDlp() async {
    return _findBinary(ytDlpName);
  }

  Future<String?> findFfmpeg() async {
    return _findBinary(ffmpegName);
  }

  Future<String?> findFfprobe() async {
    return _findBinary(ffprobeName);
  }

  Future<String?> findAria2c() async {
    return _findBinary('aria2c');
  }

  /// Optional experimental gobird binary (Windows). Missing is not an error.
  Future<String?> findGobird() async {
    return _findBinary(gobirdName, softMissing: true);
  }

  /// Copies a discovered gobird.exe into the persistent app bin folder when needed.
  Future<String?> ensureGobirdStaged() async {
    final existing = await findGobird();
    if (existing != null && existing.isNotEmpty) {
      try {
        final appBin = await resolveAppBinDirectory();
        final dest = p.join(appBin.path, executableFileName(gobirdName));
        if (p.equals(existing, dest)) return existing;
        if (!await File(dest).exists()) {
          await File(existing).copy(dest);
          LoggerService.i('Staged gobird into app bin: $dest');
          return dest;
        }
        return dest;
      } catch (e) {
        LoggerService.w('Could not stage gobird into app bin: $e');
        return existing;
      }
    }
    return null;
  }

  static Directory? _appBinCache;

  /// Persistent `bin` folder next to app data (survives debug rebuilds).
  static Future<Directory> resolveAppBinDirectory() async {
    if (_appBinCache != null) return _appBinCache!;
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory(p.join(support.path, 'bin'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _appBinCache = dir;
      return dir;
    } catch (e) {
      LoggerService.w('Falling back to local bin directory: $e');
      final fallback = Directory(p.join(Directory.current.path, 'bin'));
      if (!await fallback.exists()) {
        await fallback.create(recursive: true);
      }
      _appBinCache = fallback;
      return fallback;
    }
  }

  static String executableFileName(String binaryName) {
    if (Platform.isWindows && !binaryName.toLowerCase().endsWith('.exe')) {
      return '$binaryName.exe';
    }
    return binaryName;
  }

  /// Find gallery-dl executable
  /// Checks custom path first, then PATH, then common pip locations
  Future<String?> findGalleryDl() async {
    // 1. Try custom path if set
    if (_customGalleryDlPath != null && _customGalleryDlPath!.isNotEmpty) {
      final file = File(_customGalleryDlPath!);
      if (await file.exists()) {
        LoggerService.i(
          'Found gallery-dl at custom path: $_customGalleryDlPath',
        );
        return _customGalleryDlPath;
      }
    }

    // 2. Try via PATH (pip install --user adds to Scripts)
    try {
      final result = await Process.run(galleryDlName, [
        '--version',
      ], runInShell: true);
      if (result.exitCode == 0) {
        LoggerService.i('Found gallery-dl in PATH');
        return galleryDlName;
      }
    } catch (e) {
      LoggerService.w('gallery-dl not in PATH: $e');
    }

    // 3. Try common pip install locations on Windows
    final userProfile = Platform.environment['USERPROFILE'];
    final programData = Platform.environment['ProgramData']; // C:\ProgramData

    // Explicit check for Chocolatey (common on Windows)
    if (programData != null) {
      final chocoPath = '$programData\\chocolatey\\bin\\gallery-dl.exe';
      if (await File(chocoPath).exists()) {
        LoggerService.i('Found gallery-dl in Chocolatey: $chocoPath');
        return chocoPath;
      }
    }

    if (userProfile != null) {
      final commonPaths = [
        '$userProfile\\AppData\\Local\\Programs\\Python\\Python314\\Scripts\\gallery-dl.exe', // Python 3.14 (User)
        '$userProfile\\AppData\\Local\\Programs\\Python\\Python311\\Scripts\\gallery-dl.exe',
        '$userProfile\\AppData\\Local\\Programs\\Python\\Python310\\Scripts\\gallery-dl.exe',
        '$userProfile\\AppData\\Local\\Programs\\Python\\Python39\\Scripts\\gallery-dl.exe',
        '$userProfile\\AppData\\Roaming\\Python\\Python314\\Scripts\\gallery-dl.exe', // Python 3.14 (Roaming)
        '$userProfile\\AppData\\Roaming\\Python\\Python311\\Scripts\\gallery-dl.exe',
        '$userProfile\\AppData\\Roaming\\Python\\Python310\\Scripts\\gallery-dl.exe',
      ];

      for (final path in commonPaths) {
        final file = File(path);
        if (await file.exists()) {
          LoggerService.i('Found gallery-dl at: $path');
          return path;
        }
      }
    }

    LoggerService.w('gallery-dl not found');
    return null;
  }

  Future<String?> _findBinary(
    String binaryName, {
    bool softMissing = false,
  }) async {
    final versionArg =
        binaryName.contains('ffmpeg') || binaryName.contains('ffprobe')
        ? '-version'
        : '--version';

    final binaryWithExt = executableFileName(binaryName);

    try {
      final appBin = await resolveAppBinDirectory();
      final appPath = p.join(appBin.path, binaryWithExt);
      if (await File(appPath).exists() &&
          await _verifyBinary(appPath, versionArg)) {
        LoggerService.i('Using app binary: $appPath');
        return appPath;
      }
    } catch (e) {
      LoggerService.w('App bin lookup failed for $binaryName: $e');
    }

    final potentialPaths = [
      p.join(Directory.current.path, 'bin', binaryWithExt),
      p.join(
        File(Platform.resolvedExecutable).parent.path,
        'bin',
        binaryWithExt,
      ),
      p.join(
        File(Platform.resolvedExecutable).parent.path,
        'data',
        'flutter_assets',
        'bin',
        binaryWithExt,
      ),
    ];

    for (final path in potentialPaths) {
      if (await File(path).exists() && await _verifyBinary(path, versionArg)) {
        LoggerService.i('Using local binary: $path');
        return path;
      }
    }

    // 1. Try via shell/PATH (Fallback only if NOT in bin)
    if (Platform.isWindows) {
      // Check Chocolatey specifically first (more reliable than generic PATH sometimes)
      final programData = Platform.environment['ProgramData'];
      if (programData != null) {
        final chocoPath = '$programData\\chocolatey\\bin\\$binaryWithExt';
        if (await File(chocoPath).exists()) {
          return chocoPath;
        }
      }

      if (await _verifyBinary(binaryName, versionArg)) {
        LoggerService.i('Found valid $binaryName in PATH');
        return binaryName;
      }
    }

    // 2. Fallback: Try 'where' command to get full path from PATH
    try {
      final result = await Process.run('where', [binaryName], runInShell: true);
      if (result.exitCode == 0) {
        final paths = result.stdout.toString().split('\r\n');
        for (var path in paths) {
          path = path.trim();
          if (path.isNotEmpty && await _verifyBinary(path, versionArg)) {
            LoggerService.i('Found valid $binaryName via where: $path');
            return path;
          }
        }
      }
    } catch (e) {
      LoggerService.w('Could not locate $binaryName via where: $e');
    }

    if (softMissing) {
      LoggerService.w('$binaryName not found (optional)');
    } else {
      LoggerService.e('$binaryName not found or all locations are invalid');
    }
    return null;
  }

  Future<bool> _verifyBinary(String path, String versionArg) async {
    try {
      final result = await Process.run(path, [versionArg], runInShell: true);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}
