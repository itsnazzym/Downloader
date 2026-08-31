import 'dart:io';
import '../logger/logger_service.dart';
import 'binary/binary_locator.dart';

/// Service to auto-update yt-dlp at app startup.
class YtDlpUpdaterService {
  final BinaryLocator _locator;

  YtDlpUpdaterService(this._locator);

  /// Checks for yt-dlp updates and applies them.
  /// Returns a message describing the result.
  /// Runs non-blocking — failures are logged but don't crash the app.
  Future<String> checkForUpdate() async {
    try {
      final ytDlpPath = await _locator.findYtDlp();
      if (ytDlpPath == null) {
        LoggerService.w('yt-dlp not found — skipping auto-update');
        return 'yt-dlp not found';
      }

      LoggerService.i('Checking for yt-dlp updates...');

      final result =
          await Process.run(ytDlpPath, ['--update'], runInShell: true).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              LoggerService.w('yt-dlp update check timed out');
              return ProcessResult(0, 1, '', 'Timeout');
            },
          );

      final output = result.stdout.toString().trim();

      if (output.contains('Updating to')) {
        // Extract version from output like "Updating to version 2024.01.01"
        final match = RegExp(
          r'Updating to (?:version )?(.+)',
        ).firstMatch(output);
        final version = match?.group(1) ?? 'latest';
        LoggerService.i('yt-dlp updated to $version');
        return 'Updated to $version';
      } else if (output.contains('is up to date') ||
          output.contains('up-to-date')) {
        LoggerService.i('yt-dlp is already up to date');
        return 'Already up to date';
      } else {
        LoggerService.i('yt-dlp update result: $output');
        return output.isNotEmpty ? output : 'Check completed';
      }
    } catch (e) {
      LoggerService.w('yt-dlp auto-update failed: $e');
      return 'Update check failed';
    }
  }
}
