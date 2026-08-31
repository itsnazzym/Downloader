import 'dart:io';

import 'package:modern_downloader/core/download/temp_file_cleanup.dart';
import 'package:modern_downloader/core/logger/logger_service.dart';

/// Deletes a finished media file plus sidecar thumbs and yt-dlp temp fragments.
class DownloadFileCleanup {
  DownloadFileCleanup._();

  static const List<String> sidecarExtensions = ['.jpg', '.webp', '.png'];

  static Future<void> deleteMediaAndSidecars(String filePath) async {
    try {
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        LoggerService.i('Deleted file: $filePath');
      }

      final dotIndex = filePath.lastIndexOf('.');
      if (dotIndex != -1) {
        final basePath = filePath.substring(0, dotIndex);
        for (final ext in sidecarExtensions) {
          try {
            final thumbFile = File('$basePath$ext');
            if (await thumbFile.exists()) {
              await thumbFile.delete();
              LoggerService.i('Deleted thumbnail: $basePath$ext');
            }
          } catch (e) {
            LoggerService.w('Failed to delete thumbnail $basePath$ext: $e');
          }
        }
      }

      final directory = file.parent;
      if (await directory.exists()) {
        final filename = file.uri.pathSegments.last.replaceAll(
          RegExp(r'\.\w+$'),
          '',
        );
        await for (final entity in directory.list()) {
          if (entity is! File) continue;
          final name = entity.uri.pathSegments.last;
          if (name.contains(filename) &&
              TempFileCleanup.isFragmentOrTemp(name)) {
            try {
              await entity.delete();
              LoggerService.debug('Cleaned up temp file: $name');
            } catch (e) {
              LoggerService.w('Failed to delete temp file $name: $e');
            }
          }
        }
      }
    } catch (e) {
      LoggerService.w('Failed to delete files for $filePath: $e');
    }
  }
}
