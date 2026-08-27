import 'dart:io';
import '../core/logger/logger_service.dart';
import 'binary_locator.dart';

class BinaryVerifier {
  static final _locator = BinaryLocator();

  /// Checks if yt-dlp is installed and returns version info
  static Future<BinaryStatus> checkYtDlp() async {
    final path = await _locator.findYtDlp() ?? 'yt-dlp';
    return _checkBinary(path, ['--version']);
  }

  /// Checks if ffmpeg is installed and returns version info
  static Future<BinaryStatus> checkFfmpeg() async {
    final path = await _locator.findFfmpeg() ?? 'ffmpeg';
    return _checkBinary(path, ['-version']);
  }

  /// Checks if aria2c is installed and returns version info
  static Future<BinaryStatus> checkAria2c() async {
    final path = await _locator.findAria2c() ?? 'aria2c';
    return _checkBinary(path, ['--version']);
  }

  /// Checks optional experimental gobird binary (not required at startup).
  static Future<BinaryStatus> checkGobird() async {
    final path = await _locator.findGobird();
    if (path == null) {
      return BinaryStatus(
        isInstalled: false,
        version: null,
        error: 'gobird not found',
      );
    }
    return _checkBinary(path, ['--version']);
  }

  static Future<BinaryStatus> _checkBinary(
    String path,
    List<String> args,
  ) async {
    final name = path.split(Platform.pathSeparator).last;
    try {
      final result = await Process.run(path, args, runInShell: true);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        // Extract first line for version
        final version = output.split('\n').first.trim();
        LoggerService.i('$name check passed: $version');
        return BinaryStatus(isInstalled: true, version: version, error: null);
      } else {
        return BinaryStatus(
          isInstalled: false,
          version: null,
          error: result.stderr.toString(),
        );
      }
    } catch (e) {
      LoggerService.e('$name check failed: $e');
      return BinaryStatus(
        isInstalled: false,
        version: null,
        error: e.toString(),
      );
    }
  }
}

class BinaryStatus {
  final bool isInstalled;
  final String? version;
  final String? error;

  BinaryStatus({required this.isInstalled, this.version, this.error});
}
