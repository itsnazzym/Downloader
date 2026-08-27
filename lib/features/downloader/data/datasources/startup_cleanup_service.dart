import 'dart:io';
import '../../../../core/logger/logger_service.dart';

class StartupCleanupService {
  static Future<void> cleanup(String outputFolder) async {
    if (outputFolder.isEmpty) return;

    final dir = Directory(outputFolder);
    if (!dir.existsSync()) return;

    LoggerService.i('Starting startup cleanup in: $outputFolder');
    int deletedCount = 0;

    try {
      // Recursive list to handle site subfolders
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          if (shouldDelete(entity.path)) {
            try {
              await entity.delete();
              deletedCount++;
              LoggerService.debug('Cleaned up: ${entity.path}');
            } catch (e) {
              LoggerService.w('Failed to delete temp file: ${entity.path}: $e');
            }
          }
        }
      }
      if (deletedCount > 0) {
        LoggerService.i(
          'Startup cleanup finished. Removed $deletedCount temporary files.',
        );
      } else {
        LoggerService.i('Startup cleanup finished. No temporary files found.');
      }
    } catch (e) {
      LoggerService.e('Error during startup cleanup: $e');
    }
  }

  /// Resume artifacts (.part/.ytdl/.aria2) must be kept so yt-dlp can continue.
  static bool shouldDelete(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.part') ||
        lower.endsWith('.ytdl') ||
        lower.endsWith('.aria2')) {
      return false;
    }
    return lower.endsWith('.temp');
  }
}
