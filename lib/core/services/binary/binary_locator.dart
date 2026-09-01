import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../logger/logger_service.dart';
import 'process_runner.dart';

class BinaryLocator {
  BinaryLocator({
    ProcessRunner? processRunner,
    Future<bool> Function(String path)? fileExists,
    Future<Directory> Function()? resolveAppBin,
  }) : _processRunner = processRunner ?? ProcessRunner(),
       _fileExists = fileExists,
       _resolveAppBin = resolveAppBin;

  static const String ytDlpName = 'yt-dlp';
  static const String ffmpegName = 'ffmpeg';
  static const String ffprobeName = 'ffprobe';
  static const String galleryDlName = 'gallery-dl';
  static const String gobirdName = 'gobird';
  static const Duration processTimeout = Duration(seconds: 5);

  final ProcessRunner _processRunner;
  final Future<bool> Function(String path)? _fileExists;
  final Future<Directory> Function()? _resolveAppBin;

  static final Map<String, String> _resolvedPathCache = {};

  /// Drops cached lookup results. Intended for tests.
  static void clearResolvedPathCache() {
    _resolvedPathCache.clear();
  }

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
  /// PATH probes are skipped unless [allowPathProbe] is true (feature enabled).
  Future<String?> findGobird({bool allowPathProbe = false}) async {
    return _findBinary(
      gobirdName,
      softMissing: true,
      allowPathProbe: allowPathProbe,
    );
  }

  /// Copies a discovered gobird.exe into the persistent app bin folder when needed.
  Future<String?> ensureGobirdStaged() async {
    final existing = await findGobird(allowPathProbe: true);
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
    bool allowPathProbe = true,
  }) async {
    final cacheKey = executableFileName(binaryName).toLowerCase();
    final cached = _resolvedPathCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final binaryWithExt = executableFileName(binaryName);

    if (Platform.isAndroid) {
      return _remember(cacheKey, binaryName);
    }

    try {
      final resolveAppBin = _resolveAppBin;
      final appBin = resolveAppBin != null
          ? await resolveAppBin()
          : await resolveAppBinDirectory();
      final appPath = p.join(appBin.path, binaryWithExt);
      if (await _exists(appPath)) {
        LoggerService.i('Using app binary: $appPath');
        return _remember(cacheKey, appPath);
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
      try {
        if (await _exists(path)) {
          LoggerService.i('Using local binary: $path');
          return _remember(cacheKey, path);
        }
      } catch (e) {
        LoggerService.w('Local binary lookup failed for $path: $e');
      }
    }

    if (!allowPathProbe) {
      if (softMissing) {
        LoggerService.w('$binaryName not found (optional)');
      } else {
        LoggerService.e('$binaryName not found or all locations are invalid');
      }
      return null;
    }

    final versionArg =
        binaryName.contains('ffmpeg') || binaryName.contains('ffprobe')
        ? '-version'
        : '--version';

    // PATH fallback only when no local copy exists.
    if (Platform.isWindows) {
      try {
        final programData = Platform.environment['ProgramData'];
        if (programData != null) {
          final chocoPath = '$programData\\chocolatey\\bin\\$binaryWithExt';
          if (await _exists(chocoPath)) {
            return _remember(cacheKey, chocoPath);
          }
        }
      } catch (e) {
        LoggerService.w('Chocolatey lookup failed for $binaryName: $e');
      }

      if (await _verifyBinary(binaryName, versionArg)) {
        LoggerService.i('Found valid $binaryName in PATH');
        return _remember(cacheKey, binaryName);
      }
    }

    try {
      final result = await _run('where', [binaryName]);
      if (result.exitCode == 0) {
        final paths = result.stdout.toString().split('\r\n');
        for (var path in paths) {
          path = path.trim();
          if (path.isNotEmpty && await _verifyBinary(path, versionArg)) {
            LoggerService.i('Found valid $binaryName via where: $path');
            return _remember(cacheKey, path);
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

  String _remember(String cacheKey, String path) {
    _resolvedPathCache[cacheKey] = path;
    return path;
  }

  Future<bool> _exists(String path) async {
    try {
      final fileExists = _fileExists;
      if (fileExists != null) {
        return await fileExists(path);
      }
      return await File(path).exists();
    } catch (e) {
      LoggerService.w('File exists check failed for $path: $e');
      return false;
    }
  }

  Future<ProcessResult> _run(String executable, List<String> arguments) {
    return _processRunner.run(executable, arguments).timeout(processTimeout);
  }

  Future<bool> _verifyBinary(String path, String versionArg) async {
    try {
      final result = await _run(path, [versionArg]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}
