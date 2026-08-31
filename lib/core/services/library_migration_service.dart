import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:modern_downloader/core/logger/logger_service.dart';
import 'package:modern_downloader/features/downloader/data/datasources/persistence_service.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/core/download/media_source_resolver.dart';

class MigrationProgress {
  final String status;
  final int current;
  final int total;
  final double percentage;
  final String? currentFile;

  const MigrationProgress({
    required this.status,
    required this.current,
    required this.total,
    required this.percentage,
    this.currentFile,
  });
}

class MigrationResult {
  final int videosMoved;
  final int thumbnailsMoved;
  final int databaseItemsUpdated;
  final int errorsCount;
  final List<String> errors;
  final double freedBytes;

  double get freedGigabytes => freedBytes / (1024 * 1024 * 1024);

  const MigrationResult({
    required this.videosMoved,
    required this.thumbnailsMoved,
    required this.databaseItemsUpdated,
    required this.errorsCount,
    required this.errors,
    required this.freedBytes,
  });
}

class LibraryMigrationService {
  final PersistenceService _persistenceService;

  LibraryMigrationService([PersistenceService? persistenceService])
    : _persistenceService = persistenceService ?? PersistenceService();

  Future<MigrationResult> migrateLibrary({
    required String newOutputFolder,
    required bool deleteSourceFiles,
    void Function(MigrationProgress progress)? onProgress,
  }) async {
    final errors = <String>[];
    var videosMoved = 0;
    var thumbnailsMoved = 0;
    var databaseItemsUpdated = 0;
    var freedBytes = 0.0;

    LoggerService.i('LibraryMigration: Starting migration to $newOutputFolder');

    final targetDir = Directory(newOutputFolder);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final targetThumbDir = Directory(p.join(newOutputFolder, 'Thumbnails'));
    if (!await targetThumbDir.exists()) {
      await targetThumbDir.create(recursive: true);
    }

    final downloads = await _persistenceService.loadDownloads();
    final total = downloads.length;
    final updatedDownloads = <DownloadItem>[];
    final filesToDeleteOnSource = <File>[];

    for (var i = 0; i < total; i++) {
      final item = downloads[i];
      var updatedItem = item;

      final filename = item.filePath != null ? p.basename(item.filePath!) : '';
      onProgress?.call(
        MigrationProgress(
          status: 'Traitement en cours...',
          current: i + 1,
          total: total,
          percentage: total > 0 ? (i + 1) / total : 1.0,
          currentFile: item.title ?? filename,
        ),
      );

      // 1. Update request outputFolder
      updatedItem = updatedItem.copyWith(
        request: updatedItem.request.copyWith(outputFolder: newOutputFolder),
      );

      // 2. Migrate video file if exists
      if (item.filePath != null && item.filePath!.trim().isNotEmpty) {
        final srcFile = File(item.filePath!);
        if (await srcFile.exists()) {
          try {
            // Determine destination subfolder (e.g. Twitter, YouTube)
            final sourceName = item.source.isNotEmpty
                ? item.source
                : (MediaSourceResolver.fromFilePath(item.filePath) ?? '');

            final subfolder = sourceName.isNotEmpty
                ? Directory(p.join(newOutputFolder, sourceName))
                : targetDir;

            if (!await subfolder.exists()) {
              await subfolder.create(recursive: true);
            }

            final fileName = p.basename(srcFile.path);
            final dstFile = File(p.join(subfolder.path, fileName));

            // Only copy if destination is different
            if (p.canonicalize(srcFile.path) != p.canonicalize(dstFile.path)) {
              await _copyFileSafely(srcFile, dstFile);
              videosMoved++;
              freedBytes += await srcFile.length();
              if (deleteSourceFiles) {
                filesToDeleteOnSource.add(srcFile);
              }
            }

            updatedItem = updatedItem.copyWith(filePath: dstFile.path);
            databaseItemsUpdated++;
          } catch (e) {
            LoggerService.e(
              'LibraryMigration: Failed to move video ${srcFile.path}',
              e,
            );
            errors.add('Erreur vidéo (${srcFile.path}): $e');
          }
        }
      }

      // 3. Migrate local thumbnail if exists
      if (item.thumbnailUrl != null &&
          !item.thumbnailUrl!.startsWith('http') &&
          item.thumbnailUrl!.trim().isNotEmpty) {
        final srcThumb = File(item.thumbnailUrl!);
        if (await srcThumb.exists()) {
          try {
            final thumbName = p.basename(srcThumb.path);
            final dstThumb = File(p.join(targetThumbDir.path, thumbName));

            if (p.canonicalize(srcThumb.path) !=
                p.canonicalize(dstThumb.path)) {
              await _copyFileSafely(srcThumb, dstThumb);
              thumbnailsMoved++;
              freedBytes += await srcThumb.length();
              if (deleteSourceFiles) {
                filesToDeleteOnSource.add(srcThumb);
              }
            }

            updatedItem = updatedItem.copyWith(thumbnailUrl: dstThumb.path);
            databaseItemsUpdated++;
          } catch (e) {
            LoggerService.e(
              'LibraryMigration: Failed to move thumbnail ${srcThumb.path}',
              e,
            );
            errors.add('Erreur miniature (${srcThumb.path}): $e');
          }
        }
      }

      // 4. If status was failed due to disk space, unblock to queued
      final err = item.error ?? '';
      if (item.status == DownloadStatus.failed &&
          (err.contains('Disk Space') ||
              err.contains('Low Disk') ||
              err.contains('espace'))) {
        updatedItem = updatedItem.copyWith(
          status: DownloadStatus.queued,
          clearError: true,
          speed: '',
          step: '',
          progress: 0.0,
        );
        databaseItemsUpdated++;
      }

      updatedDownloads.add(updatedItem);
    }

    // Save updated database
    await _persistenceService.saveDownloads(updatedDownloads);

    // Delete source files if requested
    if (deleteSourceFiles) {
      onProgress?.call(
        MigrationProgress(
          status: 'Nettoyage des fichiers sources...',
          current: total,
          total: total,
          percentage: 1.0,
          currentFile: 'Nettoyage en cours',
        ),
      );

      for (final f in filesToDeleteOnSource) {
        try {
          if (await f.exists()) {
            await f.delete();
          }
        } catch (e) {
          LoggerService.w(
            'LibraryMigration: Could not delete source file ${f.path}: $e',
          );
        }
      }
    }

    LoggerService.i(
      'LibraryMigration complete. Videos: $videosMoved, Thumbs: $thumbnailsMoved, '
      'DB items: $databaseItemsUpdated, Freed: ${(freedBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB',
    );

    return MigrationResult(
      videosMoved: videosMoved,
      thumbnailsMoved: thumbnailsMoved,
      databaseItemsUpdated: databaseItemsUpdated,
      errorsCount: errors.length,
      errors: errors,
      freedBytes: freedBytes,
    );
  }

  Future<void> _copyFileSafely(File source, File destination) async {
    final tempDst = File('${destination.path}.tmp_mig');
    if (await tempDst.exists()) {
      await tempDst.delete();
    }

    final reader = source.openRead();
    final sink = tempDst.openWrite();
    await reader.pipe(sink);

    if (await destination.exists()) {
      await destination.delete();
    }
    await tempDst.rename(destination.path);
  }
}
