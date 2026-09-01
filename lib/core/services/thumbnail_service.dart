import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:modern_downloader/core/services/binary/binary_locator.dart';
import 'package:modern_downloader/core/services/binary/process_runner.dart';
import 'package:modern_downloader/core/logger/logger_service.dart';

/// Service to generate thumbnails from video files using ffmpeg
class ThumbnailService {
  final BinaryLocator _binaryLocator;
  final ProcessRunner _processRunner;

  ThumbnailService(this._binaryLocator, [ProcessRunner? processRunner])
    : _processRunner = processRunner ?? ProcessRunner();

  /// Generates a thumbnail for a video file if one doesn't exist
  /// Returns the path to the generated thumbnail, or null if failed
  /// Thumbnails are stored in a 'Thumbnails' subfolder of the base directory
  Future<String?> generateThumbnail(String videoPath) async {
    if (!File(videoPath).existsSync()) return null;

    final videoDir = p.dirname(videoPath);
    final videoName = p.basenameWithoutExtension(videoPath);

    // First check for existing sidecar thumbnail (legacy)
    final legacyThumbnailPath = p.join(videoDir, '$videoName.jpg');
    if (File(legacyThumbnailPath).existsSync()) {
      return legacyThumbnailPath;
    }

    // Check if thumbnail exists in Thumbnails folder
    // Find base directory (go up until we find a known structure or limit depth)
    final baseDir = _findBaseDirectory(videoDir);
    final thumbnailsDir = p.join(baseDir, 'Thumbnails');
    final thumbnailPath = p.join(thumbnailsDir, '$videoName.jpg');

    if (File(thumbnailPath).existsSync()) {
      return thumbnailPath;
    }

    // Create Thumbnails directory if needed
    final thumbDir = Directory(thumbnailsDir);
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }

    // Generate thumbnail using ffmpeg
    try {
      final ffmpegPath = await _binaryLocator.findFfmpeg();
      if (ffmpegPath == null) {
        LoggerService.w('ThumbnailService: ffmpeg not found');
        return null;
      }

      // Extract frame at 5 seconds (or 1 second for short videos)
      final args = [
        '-i', videoPath,
        '-ss', '00:00:05', // Seek to 5 seconds
        '-vframes', '1', // Extract 1 frame
        '-q:v', '2', // High quality JPEG
        '-y', // Overwrite if exists
        thumbnailPath,
      ];

      final result = await _processRunner.run(ffmpegPath, args);

      if (result.exitCode == 0 && File(thumbnailPath).existsSync()) {
        LoggerService.debug('Generated thumbnail: $thumbnailPath');
        return thumbnailPath;
      } else {
        // Try at 1 second for very short videos
        final retryArgs = [
          '-i',
          videoPath,
          '-ss',
          '00:00:01',
          '-vframes',
          '1',
          '-q:v',
          '2',
          '-y',
          thumbnailPath,
        ];

        final retryResult = await _processRunner.run(ffmpegPath, retryArgs);
        if (retryResult.exitCode == 0 && File(thumbnailPath).existsSync()) {
          LoggerService.debug('Generated thumbnail (1s): $thumbnailPath');
          return thumbnailPath;
        }
      }
    } catch (e) {
      LoggerService.e('ThumbnailService: Failed to generate thumbnail', e);
    }

    return null;
  }

  /// Finds the base directory (VOILA or equivalent output folder)
  String _findBaseDirectory(String currentDir) {
    // Walk up directory tree looking for known base folder names
    // or stop at a reasonable depth
    String dir = currentDir;
    int depth = 0;
    const maxDepth = 5;

    while (depth < maxDepth) {
      final name = p.basename(dir);
      // Check if this looks like a base download folder
      if (name == 'VOILA' || name == 'Downloads' || name == 'Videos') {
        return dir;
      }
      final parent = p.dirname(dir);
      if (parent == dir) break; // Reached root
      dir = parent;
      depth++;
    }

    // Default to the original directory if no base found
    return currentDir;
  }

  /// Generates thumbnails for multiple videos in batch
  /// Returns a map of videoPath -> thumbnailPath
  Future<Map<String, String>> generateThumbnailsBatch(
    List<String> videoPaths, {
    void Function(int current, int total)? onProgress,
  }) async {
    final results = <String, String>{};

    for (var i = 0; i < videoPaths.length; i++) {
      onProgress?.call(i + 1, videoPaths.length);

      final thumbnail = await generateThumbnail(videoPaths[i]);
      if (thumbnail != null) {
        results[videoPaths[i]] = thumbnail;
      }
    }

    return results;
  }
}
