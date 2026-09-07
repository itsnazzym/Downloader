import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:modern_downloader/core/logger/logger_service.dart';

/// Service to detect and remove duplicate files
class DuplicateDetectorService {
  /// Extensions to check for duplicates
  static const mediaExtensions = [
    // Video
    '.mp4', '.mkv', '.webm', '.avi', '.mov', '.flv', '.wmv', '.m4v',
    // Audio
    '.mp3', '.m4a', '.wav', '.flac', '.aac', '.ogg', '.opus', '.wma',
    // Image
    '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.tiff',
  ];

  /// Finds and removes duplicate files in the given directory
  /// Uses file size + partial hash for faster comparison
  Future<DuplicateResult> findAndRemoveDuplicates(
    String basePath, {
    void Function(String status, int current, int total)? onProgress,
    bool dryRun = true,
  }) async {
    final result = DuplicateResult();
    final baseDir = Directory(basePath);

    if (!await baseDir.exists()) {
      LoggerService.e('DuplicateDetector: Base path does not exist: $basePath');
      return result;
    }

    LoggerService.i('DuplicateDetector: Scanning for duplicates in $basePath');

    // Group files by size first (same size is prerequisite for duplicate)
    final filesBySize = <int, List<File>>{};
    final allFiles = <File>[];

    await for (final entity in baseDir.list(recursive: true)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (mediaExtensions.contains(ext)) {
          allFiles.add(entity);
        }
      }
    }

    int processed = 0;
    final total = allFiles.length;

    // Group by file size
    for (final file in allFiles) {
      processed++;
      onProgress?.call('Analyzing: ${p.basename(file.path)}', processed, total);

      try {
        final size = await file.length();
        filesBySize.putIfAbsent(size, () => []).add(file);
      } catch (e) {
        LoggerService.debug(
          'DuplicateDetector: Cannot read file size: ${file.path}',
        );
      }
    }

    // Find duplicates in groups with same size
    final sizeGroups = filesBySize.entries
        .where((e) => e.value.length > 1)
        .toList();
    processed = 0;
    final totalGroups = sizeGroups.length;

    for (final group in sizeGroups) {
      processed++;
      onProgress?.call(
        'Checking duplicates (group $processed/$totalGroups)',
        processed,
        totalGroups,
      );

      final files = group.value;
      final hashToFiles = <String, List<File>>{};

      // Compute partial hash for files with same size
      for (final file in files) {
        final hash = await _computePartialHash(file);
        if (hash != null) {
          hashToFiles.putIfAbsent(hash, () => []).add(file);
        }
      }

      // Remove duplicates (keep the first one, delete others)
      for (final entry in hashToFiles.entries) {
        if (entry.value.length > 1) {
          // Sort by path length (shorter = likely more organized) then by name
          entry.value.sort((a, b) {
            final lenDiff = a.path.length.compareTo(b.path.length);
            return lenDiff != 0 ? lenDiff : a.path.compareTo(b.path);
          });

          // Keep the first file, remove the rest
          final toKeep = entry.value.first;
          final toRemove = entry.value.skip(1);

          for (final duplicate in toRemove) {
            result.duplicatesFound++;
            result.duplicateDetails.add(
              DuplicateInfo(
                kept: toKeep.path,
                removed: duplicate.path,
                size: group.key,
              ),
            );

            if (!dryRun) {
              try {
                await duplicate.delete();
                result.duplicatesRemoved++;
                result.bytesRecovered += group.key;
                LoggerService.i(
                  'DuplicateDetector: Removed duplicate: ${duplicate.path}',
                );
              } catch (e) {
                LoggerService.e(
                  'DuplicateDetector: Failed to delete ${duplicate.path}',
                  e,
                );
                result.errors.add('Failed to delete: ${duplicate.path}');
              }
            }
          }
        }
      }
    }

    LoggerService.i(
      'DuplicateDetector: Complete. Found ${result.duplicatesFound}, '
      'removed ${result.duplicatesRemoved}, recovered ${_formatBytes(result.bytesRecovered)}',
    );

    return result;
  }

  /// Computes a partial hash of a file (first 64KB + last 64KB)
  /// This is faster than hashing the entire file while still being accurate
  Future<String?> _computePartialHash(File file) async {
    try {
      final raf = await file.open(mode: FileMode.read);
      final fileSize = await file.length();

      const chunkSize = 64 * 1024; // 64KB
      final buffer = <int>[];

      // Read first chunk
      final firstChunk = await raf.read(chunkSize);
      buffer.addAll(firstChunk);

      // Read last chunk (if file is larger than 2 chunks)
      if (fileSize > chunkSize * 2) {
        await raf.setPosition(fileSize - chunkSize);
        final lastChunk = await raf.read(chunkSize);
        buffer.addAll(lastChunk);
      }

      await raf.close();

      // Compute MD5 hash
      final digest = md5.convert(buffer);
      return '$fileSize-${digest.toString()}';
    } catch (e) {
      LoggerService.debug('DuplicateDetector: Cannot hash file: ${file.path}');
      return null;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}

/// Result of duplicate detection
class DuplicateResult {
  int duplicatesFound = 0;
  int duplicatesRemoved = 0;
  int bytesRecovered = 0;
  List<DuplicateInfo> duplicateDetails = [];
  List<String> errors = [];

  bool get hasErrors => errors.isNotEmpty;
}

/// Details about a duplicate file pair
class DuplicateInfo {
  final String kept;
  final String removed;
  final int size;

  DuplicateInfo({
    required this.kept,
    required this.removed,
    required this.size,
  });
}
