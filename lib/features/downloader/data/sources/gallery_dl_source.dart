import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../domain/entities/download_request.dart';
import '../../../../../core/logger/logger_service.dart';
import '../../../../../core/utils/media_file_utils.dart';
import '../../../../../services/binary_locator.dart';

/// Source for downloading via gallery-dl CLI
/// Used as fallback when yt-dlp fails for certain sites
class GalleryDlSource {
  final BinaryLocator _binaryLocator;

  GalleryDlSource(this._binaryLocator);

  final _activeProcesses = <String, Process>{};

  /// Sites that gallery-dl handles well as a fallback
  static const supportedDomains = [
    // Social media
    'twitter.com',
    'x.com',
    'instagram.com',
    'tiktok.com',
    // Adult sites
    'pornhub.com',
    'xvideos.com',
    'xnxx.com',
    'xhamster.com',
    'redtube.com',
  ];

  /// Check if this URL should try gallery-dl as fallback
  static bool shouldUseFallback(String url) {
    final lowerUrl = url.toLowerCase();
    return supportedDomains.any((domain) => lowerUrl.contains(domain));
  }

  /// Download using gallery-dl CLI
  /// Returns a stream of progress events
  Stream<GalleryDlProgressEvent> download(
    String id,
    DownloadRequest request,
  ) async* {
    LoggerService.i(
      'GalleryDlSource: Starting fallback download for ${request.url}',
    );

    final galleryDlPath = await _binaryLocator.findGalleryDl();
    if (galleryDlPath == null) {
      throw Exception(
        'gallery-dl not found. Please install it:\n'
        '  pip install gallery-dl\n'
        'Or set the path in Settings.',
      );
    }

    // Build gallery-dl command arguments
    final args = <String>[
      // === SPEED & RELIABILITY FLAGS ===
      '--retries', '5', // Retry on errors (increased from 3)
      '--http-timeout', '30', // 30 second timeout
      '--verbose', // More detailed output for progress tracking
      // JSON output for progress parsing
      '--write-log', '-',
      // Output directory
      if (request.outputFolder != null && request.outputFolder!.isNotEmpty) ...[
        '--directory',
        request.outputFolder!,
      ],
      // Filename template with fallback:
      // {title} for sites that provide it, fallback to {description}, then {tweet_id}/{id}
      '-o', 'filename={title|description|tweet_id|id|filename}.{extension}',
    ];

    if (request.cookiesFilePath != null &&
        request.cookiesFilePath!.isNotEmpty) {
      args.addAll(['--cookies', request.cookiesFilePath!]);
      LoggerService.i('GalleryDlSource: Using supplied cookies file');
    } else if (request.cookieBrowser != null &&
        request.cookieBrowser!.isNotEmpty) {
      args.addAll(['--cookies-from-browser', request.cookieBrowser!]);
      LoggerService.i(
        'GalleryDlSource: Using browser cookies for authentication: ${request.cookieBrowser}',
      );
    }

    // The URL to download (must be last)
    args.add(request.url);

    LoggerService.i(
      'GalleryDlSource: Running $galleryDlPath ${args.join(' ')}',
    );

    try {
      final process = await Process.start(galleryDlPath, args);
      _activeProcesses[id] = process;

      int downloadedCount = 0;
      String currentFile = '';
      String? extractedTitle;
      String? lastSavedPath;
      String? previewImagePath;
      String? galleryDirectory;

      // Listen to stdout for progress
      await for (final data in process.stdout.transform(utf8.decoder)) {
        LoggerService.debug('gallery-dl stdout: $data');

        // Parse gallery-dl output
        for (final line in data.split('\n')) {
          if (line.isEmpty) continue;

          // gallery-dl outputs lines like:
          // "#  https://..." - downloading
          // "C:\path\to\file.mp4" - saved file path
          if (line.startsWith('#')) {
            currentFile = 'Downloading...';
            yield GalleryDlProgressEvent(
              status: currentFile,
              downloadedCount: downloadedCount,
              isComplete: false,
              title: extractedTitle,
              filePath: lastSavedPath,
              thumbnailPath: previewImagePath,
            );
          } else if (_looksLikePath(line)) {
            // This looks like a file path - extract the title from it
            final resolvedPath = _resolveSavedPath(
              line.trim(),
              request.outputFolder,
            );
            if (resolvedPath == null) {
              continue;
            }

            downloadedCount++;
            lastSavedPath = resolvedPath;
            galleryDirectory ??= p.dirname(resolvedPath);
            if (previewImagePath == null &&
                MediaFileUtils.isImageFile(resolvedPath)) {
              previewImagePath = resolvedPath;
            }

            final fileName = _extractFileNameFromPath(resolvedPath);
            if (fileName != null && fileName.isNotEmpty) {
              extractedTitle = fileName;
              LoggerService.debug('Extracted title from file: $extractedTitle');
            }
            yield GalleryDlProgressEvent(
              status: 'Downloaded $downloadedCount files',
              downloadedCount: downloadedCount,
              isComplete: false,
              title: extractedTitle,
              filePath: lastSavedPath,
              thumbnailPath: previewImagePath,
            );
          }
        }
      }

      // Listen to stderr for errors
      process.stderr.transform(utf8.decoder).listen((data) {
        LoggerService.w('gallery-dl stderr: $data');
      });

      // Wait for completion
      final exitCode = await process.exitCode;
      _activeProcesses.remove(id);

      if (exitCode == 0) {
        LoggerService.i('GalleryDlSource: Download completed!');
        final representativePath = previewImagePath ?? lastSavedPath;
        final directoryTarget = _shouldUseDirectoryTarget(
          galleryDirectory: galleryDirectory,
          outputFolder: request.outputFolder,
          downloadedCount: downloadedCount,
        );
        yield GalleryDlProgressEvent(
          status: 'Completed ($downloadedCount files)',
          downloadedCount: downloadedCount,
          isComplete: true,
          title: _deriveCompletedTitle(
            extractedTitle,
            galleryDirectory,
            downloadedCount,
          ),
          filePath: representativePath,
          thumbnailPath: previewImagePath,
          directoryPath: galleryDirectory,
          isGallery: directoryTarget,
        );
      } else {
        throw Exception('gallery-dl exited with code $exitCode');
      }
    } catch (e, stack) {
      LoggerService.e('GalleryDlSource error', e, stack);
      _activeProcesses.remove(id);
      rethrow;
    }
  }

  /// Cancel ongoing download
  Future<void> cancel(String id) async {
    final process = _activeProcesses[id];
    if (process != null) {
      LoggerService.i('GalleryDlSource: Canceling download $id');
      process.kill();
      _activeProcesses.remove(id);
    }
  }

  /// Extract filename (without extension) from a file path
  String? _extractFileNameFromPath(String path) {
    try {
      // Get basename from path (handle both / and \)
      final segments = path.split(RegExp(r'[/\\]'));
      final filename = segments.last;
      // Remove extension
      final dotIndex = filename.lastIndexOf('.');
      if (dotIndex > 0) {
        return filename.substring(0, dotIndex);
      }
      return filename;
    } catch (e) {
      return null;
    }
  }

  bool _looksLikePath(String line) {
    final trimmed = line.trim();
    return trimmed.contains('\\') || trimmed.contains('/');
  }

  String? _resolveSavedPath(String path, String? outputFolder) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (p.isAbsolute(trimmed)) {
      return trimmed;
    }

    if (outputFolder != null && outputFolder.isNotEmpty) {
      return p.join(outputFolder, trimmed);
    }

    return trimmed;
  }

  String _deriveCompletedTitle(
    String? extractedTitle,
    String? galleryDirectory,
    int downloadedCount,
  ) {
    if (downloadedCount > 1 && galleryDirectory != null) {
      return '${p.basename(galleryDirectory)} ($downloadedCount items)';
    }

    return extractedTitle ?? 'Gallery Download';
  }

  bool _shouldUseDirectoryTarget({
    required String? galleryDirectory,
    required String? outputFolder,
    required int downloadedCount,
  }) {
    if (downloadedCount <= 1 ||
        galleryDirectory == null ||
        galleryDirectory.isEmpty) {
      return false;
    }

    if (outputFolder == null || outputFolder.isEmpty) {
      return true;
    }

    return p.normalize(galleryDirectory).toLowerCase() !=
        p.normalize(outputFolder).toLowerCase();
  }
}

class GalleryDlProgressEvent {
  final String status;
  final int downloadedCount;
  final bool isComplete;
  final String? title;
  final String? filePath;
  final String? thumbnailPath;
  final String? directoryPath;
  final bool isGallery;

  GalleryDlProgressEvent({
    required this.status,
    required this.downloadedCount,
    required this.isComplete,
    this.title,
    this.filePath,
    this.thumbnailPath,
    this.directoryPath,
    this.isGallery = false,
  });
}
