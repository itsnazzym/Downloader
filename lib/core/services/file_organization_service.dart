import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:modern_downloader/core/logger/logger_service.dart';

/// Service to organize downloaded files by source and manage thumbnails
class FileOrganizationService {
  /// Extensions considered as video files
  static const videoExtensions = [
    '.mp4',
    '.mkv',
    '.webm',
    '.avi',
    '.mov',
    '.flv',
    '.wmv',
  ];

  static const audioExtensions = [
    '.mp3',
    '.m4a',
    '.wav',
    '.flac',
    '.aac',
    '.ogg',
    '.opus',
    '.wma',
  ];

  /// Extensions considered as image files
  static const imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];

  /// Known source folder names
  static const knownSources = [
    'Twitter',
    'YouTube',
    'Instagram',
    'TikTok',
    'Twitch',
    'Kick',
    'Reddit',
    'Facebook',
    'Pornhub',
    'XVideos',
    'XHamster',
    'XNXX',
    'Vimeo',
    'Dailymotion',
    'SoundCloud',
    'Other',
  ];

  /// Organizes all files in the given base path
  /// - Moves videos to source-specific folders
  /// - Moves all thumbnails to a Thumbnails folder
  /// - Removes temporary files
  Future<OrganizationResult> organizeLibrary(
    String basePath, {
    void Function(String status, int current, int total)? onProgress,
  }) async {
    final result = OrganizationResult();
    final baseDir = Directory(basePath);

    if (!await baseDir.exists()) {
      LoggerService.e('FileOrganization: Base path does not exist: $basePath');
      return result;
    }

    LoggerService.i('FileOrganization: Starting organization of $basePath');

    // Create Thumbnails folder
    final thumbnailsDir = Directory(p.join(basePath, 'Thumbnails'));
    if (!await thumbnailsDir.exists()) {
      await thumbnailsDir.create(recursive: true);
      LoggerService.i('FileOrganization: Created Thumbnails folder');
    }

    // Collect all files first
    final allFiles = <File>[];
    await for (final entity in baseDir.list(recursive: true)) {
      if (entity is File) {
        allFiles.add(entity);
      }
    }

    int processed = 0;
    final total = allFiles.length;

    for (final file in allFiles) {
      processed++;
      final ext = p.extension(file.path).toLowerCase();
      final fileName = p.basename(file.path);

      onProgress?.call('Processing: $fileName', processed, total);

      // Skip files already in Thumbnails folder
      if (file.path.contains('${p.separator}Thumbnails${p.separator}')) {
        continue;
      }

      // Handle thumbnails - move to Thumbnails folder
      if (_isThumbnail(file.path, ext)) {
        await _moveThumbnail(file, thumbnailsDir.path, result);
        continue;
      }

      // Handle temporary/partial files - delete them
      if (_isTemporaryFile(fileName)) {
        await _deleteTemporaryFile(file, result);
        continue;
      }

      // Handle video files - organize by source
      if (videoExtensions.contains(ext)) {
        await _organizeVideoFile(file, basePath, result);
        continue;
      }
    }

    // Clean up empty directories
    await _cleanupEmptyDirectories(basePath, result);

    LoggerService.i(
      'FileOrganization: Complete. Moved ${result.filesMoved}, '
      'deleted ${result.filesDeleted}, thumbnails ${result.thumbnailsMoved}',
    );

    return result;
  }

  /// Checks if a file is a thumbnail (image next to video with same name)
  bool _isThumbnail(String filePath, String ext) {
    if (!imageExtensions.contains(ext)) return false;

    // Check if there's a video file with the same base name
    final baseName = p.basenameWithoutExtension(filePath);
    final parentPath = p.dirname(filePath);

    for (final mediaExt in [...videoExtensions, ...audioExtensions]) {
      final potential = p.join(parentPath, '$baseName$mediaExt');
      if (File(potential).existsSync()) {
        return true; // It's a sidecar thumbnail
      }
    }
    return false;
  }

  /// Checks if a file is temporary/partial download
  bool _isTemporaryFile(String fileName) {
    return fileName.endsWith('.part') ||
        fileName.endsWith('.ytdl') ||
        fileName.endsWith('.aria2') ||
        fileName.endsWith('.temp') ||
        fileName.contains('.f') && fileName.contains('.part') ||
        fileName.startsWith('.');
  }

  /// Moves a thumbnail to the Thumbnails folder
  Future<void> _moveThumbnail(
    File file,
    String thumbnailsDir,
    OrganizationResult result,
  ) async {
    try {
      final fileName = p.basename(file.path);
      final destPath = p.join(thumbnailsDir, fileName);

      // Handle name collision
      final finalPath = await _getUniquePath(destPath);

      await file.rename(finalPath);
      result.thumbnailsMoved++;
      LoggerService.debug('FileOrganization: Thumbnail moved -> $finalPath');
    } catch (e) {
      LoggerService.e(
        'FileOrganization: Failed to move thumbnail ${file.path}',
        e,
      );
      result.errors.add('Failed to move: ${file.path}');
    }
  }

  /// Deletes a temporary file
  Future<void> _deleteTemporaryFile(
    File file,
    OrganizationResult result,
  ) async {
    try {
      await file.delete();
      result.filesDeleted++;
      LoggerService.debug('FileOrganization: Deleted temp file ${file.path}');
    } catch (e) {
      LoggerService.e('FileOrganization: Failed to delete ${file.path}', e);
      result.errors.add('Failed to delete: ${file.path}');
    }
  }

  /// Organizes a video file into source-specific folder
  Future<void> _organizeVideoFile(
    File file,
    String basePath,
    OrganizationResult result,
  ) async {
    try {
      final parentFolder = p.basename(file.parent.path);

      // If already in a known source folder, skip
      if (knownSources.any(
        (s) => s.toLowerCase() == parentFolder.toLowerCase(),
      )) {
        return;
      }

      // Detect source from filename or current folder
      final source = _detectSourceFromFile(file);

      // Create source folder if needed
      final sourceDir = Directory(p.join(basePath, source));
      if (!await sourceDir.exists()) {
        await sourceDir.create(recursive: true);
        result.foldersCreated++;
      }

      // Move file
      final fileName = p.basename(file.path);
      final destPath = p.join(sourceDir.path, fileName);
      final finalPath = await _getUniquePath(destPath);

      await file.rename(finalPath);
      result.filesMoved++;
      LoggerService.debug('FileOrganization: Video moved to $source folder');
    } catch (e) {
      LoggerService.e('FileOrganization: Failed to organize ${file.path}', e);
      result.errors.add('Failed to organize: ${file.path}');
    }
  }

  /// Detects source from filename patterns
  String _detectSourceFromFile(File file) {
    final fileName = p.basename(file.path).toLowerCase();
    final parentName = p.basename(file.parent.path).toLowerCase();

    // Check filename for hints
    if (fileName.contains('twitter') || fileName.contains('x.com')) {
      return 'Twitter';
    }
    if (fileName.contains('youtube') || fileName.contains('youtu.be')) {
      return 'YouTube';
    }
    if (fileName.contains('instagram')) return 'Instagram';
    if (fileName.contains('tiktok')) return 'TikTok';
    if (fileName.contains('twitch')) return 'Twitch';
    if (fileName.contains('reddit') || fileName.contains('redd.it')) {
      return 'Reddit';
    }
    if (fileName.contains('pornhub')) return 'Pornhub';
    if (fileName.contains('xvideos')) return 'XVideos';
    if (fileName.contains('xhamster')) return 'XHamster';

    // Check if parent folder name matches a source
    for (final source in knownSources) {
      if (parentName == source.toLowerCase()) {
        return source;
      }
    }

    return 'Other';
  }

  /// Gets a unique path by appending a number if file exists
  Future<String> _getUniquePath(String path) async {
    if (!await File(path).exists()) return path;

    final dir = p.dirname(path);
    final baseName = p.basenameWithoutExtension(path);
    final ext = p.extension(path);

    int counter = 1;
    String newPath;
    do {
      newPath = p.join(dir, '$baseName ($counter)$ext');
      counter++;
    } while (await File(newPath).exists());

    return newPath;
  }

  /// Cleans up empty directories
  Future<void> _cleanupEmptyDirectories(
    String basePath,
    OrganizationResult result,
  ) async {
    final baseDir = Directory(basePath);

    await for (final entity in baseDir.list(recursive: true)) {
      if (entity is Directory) {
        if (entity.path == p.join(basePath, 'Thumbnails')) continue;

        final isEmpty = await entity.list().isEmpty;
        if (isEmpty) {
          try {
            await entity.delete();
            result.foldersDeleted++;
            LoggerService.debug(
              'FileOrganization: Deleted empty folder ${entity.path}',
            );
          } catch (_) {}
        }
      }
    }
  }
}

/// Result of the organization operation
class OrganizationResult {
  int filesMoved = 0;
  int filesDeleted = 0;
  int thumbnailsMoved = 0;
  int foldersCreated = 0;
  int foldersDeleted = 0;
  List<String> errors = [];

  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() {
    return 'Files moved: $filesMoved, Deleted: $filesDeleted, '
        'Thumbnails: $thumbnailsMoved, Folders created: $foldersCreated, '
        'Folders deleted: $foldersDeleted, Errors: ${errors.length}';
  }
}
