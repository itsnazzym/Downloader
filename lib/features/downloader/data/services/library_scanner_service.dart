import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:modern_downloader/core/logger/logger_service.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';
import 'package:modern_downloader/core/services/metadata_extractor_service.dart';
import 'package:modern_downloader/core/services/thumbnail_service.dart';
import 'package:modern_downloader/core/utils/media_file_utils.dart';
import 'package:modern_downloader/services/binary_locator.dart';

class LibraryScannerService {
  final BinaryLocator _binaryLocator;
  late final ThumbnailService _thumbnailService;

  /// Cache of all indexable media files found during scanning
  List<File>? _mediaFileCache;
  String? _lastScannedPath;

  LibraryScannerService(this._binaryLocator) {
    _thumbnailService = ThumbnailService(_binaryLocator);
  }

  /// Scans current items and fixes paths, thumbnails, and status
  Future<List<DownloadItem>> scanAndFix(
    List<DownloadItem> items,
    String basePath,
  ) async {
    final fixedItems = <DownloadItem>[];
    LoggerService.i('LibraryScanner: logic start for ${items.length} items');

    // Build cache of all indexable media files in basePath (recursive)
    await _buildMediaCache(basePath);

    for (final item in items) {
      if (item.status == DownloadStatus.downloading ||
          item.status == DownloadStatus.extracting) {
        fixedItems.add(item);
        continue;
      }

      var fixedItem = item;

      // 1. Check Main File
      if (!_pathExists(item.filePath)) {
        final foundPath = _findFileFor(item);
        if (foundPath != null) {
          LoggerService.debug('LibraryScanner: Fixed path for ${item.title}');
          fixedItem = fixedItem.copyWith(filePath: foundPath);

          // File found - mark as completed if it was failed or paused
          if (fixedItem.status == DownloadStatus.failed ||
              fixedItem.status == DownloadStatus.paused) {
            fixedItem = fixedItem.copyWith(status: DownloadStatus.completed);
          }
        } else {
          if (fixedItem.status == DownloadStatus.completed) {
            LoggerService.w('LibraryScanner: File missing for ${item.title}');
            fixedItem = fixedItem.copyWith(
              status: DownloadStatus.failed,
              error: 'File missing from disk',
            );
          }
        }
      } else {
        // File path exists and file is present - ensure status is completed
        if (fixedItem.status == DownloadStatus.paused ||
            fixedItem.status == DownloadStatus.failed) {
          fixedItem = fixedItem.copyWith(status: DownloadStatus.completed);
        }
      }

      if (_pathExists(fixedItem.filePath)) {
        final thumbnail = await _resolveThumbnailForPath(
          fixedItem.filePath!,
          existingThumbnail: fixedItem.thumbnailUrl,
        );
        if (thumbnail != fixedItem.thumbnailUrl) {
          fixedItem = fixedItem.copyWith(thumbnailUrl: thumbnail);
        }
      }

      // 3. Fix source if it's "Other" or "Local" and we have a file path
      if (fixedItem.filePath != null &&
          (fixedItem.source == 'Other' || fixedItem.source == 'Local')) {
        final detectedSource = _detectSource(
          null, // No URL to extract from for existing items
          fixedItem.filePath!,
          basePath,
        );

        // Create synthetic URL for proper source detection
        if (detectedSource != 'local') {
          final newUrl = 'https://$detectedSource.detected/imported';
          fixedItem = fixedItem.copyWith(request: DownloadRequest(url: newUrl));
        }
      }

      fixedItems.add(fixedItem);
    }
    return fixedItems;
  }

  /// Scans the download directory recursively for new files not in the list
  Future<List<DownloadItem>> scanForNewFiles(
    List<DownloadItem> knownItems,
    String downloadPath,
  ) async {
    final newItems = <DownloadItem>[];
    try {
      final dir = Directory(downloadPath);
      if (!dir.existsSync()) return [];

      // Get all known paths (normalized) to avoid duplicates
      final knownPaths = knownItems
          .where((i) => i.filePath != null && File(i.filePath!).existsSync())
          .map((i) => i.filePath!.toLowerCase())
          .toSet();
      // Scan recursively
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final normalizedPath = entity.path.toLowerCase();
          if (knownPaths.contains(normalizedPath) ||
              !_shouldIndexFile(entity.path)) {
            continue;
          }

          LoggerService.i('LibraryScanner: Found new media ${entity.path}');
          final item = await _buildItemFromFile(entity, downloadPath);
          if (item != null) {
            newItems.add(item);
          }
        }
      }
    } catch (e) {
      LoggerService.e('LibraryScanner: Error scanning for new files', e);
    }
    return newItems;
  }

  /// Detects the source of a video from metadata URL or folder structure
  String _detectSource(String? sourceUrl, String filePath, String basePath) {
    // 1. Try to extract from source URL (most accurate)
    if (sourceUrl != null && sourceUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(sourceUrl);
        final host = uri.host.toLowerCase();
        if (host.contains('youtube') || host.contains('youtu.be')) {
          return 'youtube';
        }
        if (host.contains('twitter') || host == 'x.com') return 'twitter';
        if (host.contains('instagram')) return 'instagram';
        if (host.contains('tiktok')) return 'tiktok';
        if (host.contains('twitch')) return 'twitch';
        if (host.contains('kick')) return 'kick';
        if (host.contains('reddit') || host.contains('redd.it')) {
          return 'reddit';
        }
        if (host.contains('pornhub')) return 'pornhub';
        if (host.contains('xvideos')) return 'xvideos';
        if (host.contains('xhamster')) return 'xhamster';
        if (host.contains('xnxx')) return 'xnxx';
      } catch (_) {}
    }

    // 3. Try to extract from parent folder name
    final relativePath = filePath
        .replaceFirst(basePath, '')
        .replaceAll('\\', '/');
    final parts = relativePath.split('/').where((p) => p.isNotEmpty).toList();

    if (parts.length > 1) {
      // First part of relative path is the subfolder (e.g., "Twitter", "YouTube")
      final folder = parts.first.toLowerCase();
      if (_isKnownSource(folder)) {
        return folder;
      }
    }

    return 'local';
  }

  /// Checks if a folder name matches a known source
  bool _isKnownSource(String folder) {
    const knownSources = [
      'twitter',
      'youtube',
      'instagram',
      'tiktok',
      'twitch',
      'kick',
      'reddit',
      'facebook',
      'xnxx',
      'xhamster',
      'pornhub',
      'xvideos',
      'vimeo',
      'dailymotion',
      'soundcloud',
    ];
    return knownSources.contains(folder);
  }

  /// Builds a cache of all indexable media files in the given path (recursive)
  Future<void> _buildMediaCache(String basePath) async {
    if (_lastScannedPath == basePath && _mediaFileCache != null) {
      return; // Use existing cache
    }

    _mediaFileCache = [];
    _lastScannedPath = basePath;

    try {
      final dir = Directory(basePath);
      if (!dir.existsSync()) return;

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && _shouldIndexFile(entity.path)) {
          _mediaFileCache!.add(entity);
        }
      }
      LoggerService.i(
        'LibraryScanner: Cached ${_mediaFileCache!.length} media files from $basePath',
      );
    } catch (e) {
      LoggerService.e('LibraryScanner: Error building cache', e);
    }
  }

  /// Finds a file matching the item's title using normalized comparison
  String? _findFileFor(DownloadItem item) {
    if (item.title == null || _mediaFileCache == null) return null;

    final normalizedTitle = _normalize(item.title!);
    if (normalizedTitle.isEmpty) return null;
    final candidates = _candidateFilesFor(item);

    // Try exact filename match from previous path
    if (item.filePath != null) {
      final oldFilename = item.filePath!.split(RegExp(r'[/\\]')).last;
      final normalizedOldFilename = _normalize(oldFilename);

      for (final file in candidates) {
        final filename = file.uri.pathSegments.last;
        final normalizedFilename = _normalize(filename);

        if (normalizedFilename == normalizedOldFilename) {
          return file.path;
        }
      }
    }

    // Try title-based matching
    for (final file in candidates) {
      final filename = file.uri.pathSegments.last;
      final normalizedFilename = _normalize(filename);

      // Check if title is substantially contained in filename or vice versa
      if (_fuzzyMatch(normalizedTitle, normalizedFilename)) {
        return file.path;
      }
    }

    return null;
  }

  /// Normalizes a string for comparison (removes special chars, lowercase)
  String _normalize(String input) {
    // Remove file extensions
    var s = input.replaceAll(
      RegExp(
        r'\.(mp4|mkv|webm|mov|avi|flv|m4v|3gp|wmv|mp3|aac|opus|m4a|ogg|flac|wav|wma)$',
        caseSensitive: false,
      ),
      '',
    );
    // Remove URLs
    s = s.replaceAll(RegExp(r'https?[^\s]*'), '');
    // Remove special chars, keep only alphanumeric and spaces
    s = s.replaceAll(RegExp(r'[^\w\s]'), ' ');
    // Collapse whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    return s;
  }

  /// Fuzzy matching - checks if significant words overlap
  bool _fuzzyMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;

    // Split into words
    final wordsA = a.split(' ').where((w) => w.length > 2).toSet();
    final wordsB = b.split(' ').where((w) => w.length > 2).toSet();

    if (wordsA.isEmpty || wordsB.isEmpty) return false;

    // Count matching words
    final matches = wordsA.intersection(wordsB).length;
    final minWords = wordsA.length < wordsB.length
        ? wordsA.length
        : wordsB.length;

    // Require at least 50% word overlap
    return matches >= (minWords * 0.5).ceil() && matches >= 1;
  }

  String? _findSidecarThumbnail(String videoPath) {
    try {
      final dotIndex = videoPath.lastIndexOf('.');
      if (dotIndex == -1) return null;
      final basePath = videoPath.substring(0, dotIndex);

      final exts = ['.jpg', '.webp', '.png'];
      for (final ext in exts) {
        final path = '$basePath$ext';
        if (File(path).existsSync()) return path;
      }
    } catch (_) {}
    return null;
  }

  Future<DownloadItem?> _buildItemFromFile(File file, String basePath) async {
    final id = const Uuid().v4();
    final metadata = _shouldExtractMetadata(file.path)
        ? await MetadataExtractorService(_binaryLocator).extract(file.path)
        : null;
    final filename = file.uri.pathSegments.last;
    final cleanTitle = TitleCleanerService.clean(metadata?.title ?? filename);
    final source = _detectSource(metadata?.sourceUrl, file.path, basePath);
    final thumbnail = await _resolveThumbnailFor(file.path);

    return DownloadItem(
      id: id,
      request: DownloadRequest(
        url: metadata?.sourceUrl ?? 'https://$source.detected/imported',
      ),
      title: cleanTitle,
      status: DownloadStatus.completed,
      progress: 1.0,
      filePath: file.path,
      sortOrder: 9999,
      thumbnailUrl: thumbnail,
    );
  }

  bool _shouldExtractMetadata(String path) {
    return MediaFileUtils.isVideoFile(path) || MediaFileUtils.isAudioFile(path);
  }

  Future<String?> _resolveThumbnailFor(
    String mediaPath, {
    String? existingThumbnail,
  }) async {
    if (existingThumbnail != null && existingThumbnail.isNotEmpty) {
      if (MediaFileUtils.isNetworkUrl(existingThumbnail) ||
          File(existingThumbnail).existsSync()) {
        return existingThumbnail;
      }
    }

    final sidecar = _findSidecarThumbnail(mediaPath);
    if (sidecar != null) {
      return sidecar;
    }

    if (MediaFileUtils.isVideoFile(mediaPath)) {
      return _thumbnailService.generateThumbnail(mediaPath);
    }

    return null;
  }

  Future<String?> _resolveThumbnailForPath(
    String path, {
    String? existingThumbnail,
  }) async {
    return _resolveThumbnailFor(path, existingThumbnail: existingThumbnail);
  }

  bool _shouldIndexFile(String path) {
    if (!MediaFileUtils.isVideoFile(path) &&
        !MediaFileUtils.isAudioFile(path)) {
      return false;
    }

    final normalized = path.toLowerCase().replaceAll('/', '\\');
    if (normalized.contains('\\thumbnails\\')) {
      return false;
    }

    return true;
  }

  Iterable<File> _candidateFilesFor(DownloadItem item) {
    final allFiles = _mediaFileCache ?? const <File>[];
    final currentPath = item.filePath;
    if (currentPath == null || currentPath.isEmpty) {
      return allFiles;
    }

    if (MediaFileUtils.isVideoFile(currentPath)) {
      return allFiles.where((file) => MediaFileUtils.isVideoFile(file.path));
    }

    if (MediaFileUtils.isAudioFile(currentPath)) {
      return allFiles.where((file) => MediaFileUtils.isAudioFile(file.path));
    }

    return allFiles;
  }

  bool _pathExists(String? path) {
    if (path == null || path.isEmpty) {
      return false;
    }

    return File(path).existsSync();
  }
}
