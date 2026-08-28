import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:modern_downloader/core/logger/logger_service.dart';
import 'package:modern_downloader/core/download/download_file_resolver.dart';
import 'package:modern_downloader/core/download/media_source_resolver.dart';
import 'package:modern_downloader/core/download/x_download_url.dart';
import 'package:modern_downloader/features/x_feed/x_media_identity.dart';
import 'package:modern_downloader/core/utils/format_utils.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';
import 'package:modern_downloader/core/services/metadata_extractor_service.dart';
import 'package:modern_downloader/core/services/thumbnail_service.dart';
import 'package:modern_downloader/services/binary_locator.dart';

class LibraryScannerService {
  final BinaryLocator _binaryLocator;
  late final ThumbnailService _thumbnailService;

  /// Cache of all video files found during scanning
  List<File>? _videoFileCache;

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

    // Build cache of all video files in basePath (recursive)
    await _buildVideoCache(basePath);
    var generatedThumbs = 0;

    for (final item in items) {
      if (item.status == DownloadStatus.downloading ||
          item.status == DownloadStatus.extracting) {
        fixedItems.add(item);
        continue;
      }

      var fixedItem = item;

      // 1. Check Main File
      final locatedPath = _locateExistingFile(item, basePath);
      if (locatedPath != null) {
        if (locatedPath != item.filePath) {
          LoggerService.debug('LibraryScanner: Fixed path for ${item.title}');
          fixedItem = fixedItem.copyWith(filePath: locatedPath);
        }

        // File found - mark as completed if it was failed or paused
        if (fixedItem.status == DownloadStatus.failed ||
            fixedItem.status == DownloadStatus.paused) {
          fixedItem = _promoteToCompletedIfValid(fixedItem) ?? fixedItem;
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

      // Clear COMPLETED + Retry 3/3 ghost state when the file is valid.
      if (fixedItem.status == DownloadStatus.completed &&
          _hasStaleRetryState(fixedItem)) {
        final promoted = _promoteToCompletedIfValid(fixedItem);
        if (promoted != null) {
          fixedItem = promoted;
        }
      }

      // yt-dlp often never emits "% of 10.00MiB" (Twitter HLS / after_move).
      // Backfill totalSize from the real file so the grid does not show
      // "Unknown Size" for completed downloads already on disk.
      if (fixedItem.totalSize.isEmpty) {
        final diskSize = DownloadFileResolver.formattedFileSize(
          fixedItem.filePath,
        );
        if (diskSize != null) {
          fixedItem = fixedItem.copyWith(
            totalSize: diskSize,
            downloadedSize: diskSize,
          );
        }
      }

      // 2. Check/Fix Thumbnail - validate existing and generate if missing
      if (fixedItem.filePath != null &&
          DownloadFileResolver.existsOnDisk(fixedItem.filePath!)) {
        // First, validate existing thumbnailUrl - clear if file doesn't exist
        if (fixedItem.thumbnailUrl != null &&
            !fixedItem.thumbnailUrl!.startsWith('http')) {
          // It's a local path - check if file exists
          String decodedPath = fixedItem.thumbnailUrl!;
          try {
            decodedPath = Uri.decodeFull(fixedItem.thumbnailUrl!);
          } catch (_) {}

          if (!File(decodedPath).existsSync()) {
            // Thumbnail file is missing - clear it so we can regenerate
            fixedItem = fixedItem.copyWith(clearThumbnailUrl: true);
          }
        }

        // Now try to find or generate thumbnail if needed
        if (fixedItem.thumbnailUrl == null ||
            !fixedItem.thumbnailUrl!.startsWith('http')) {
          // First try existing sidecar
          var thumb = _findSidecarThumbnail(fixedItem.filePath!);

          // If no sidecar, generate one (bounded to prevent freezing startup)
          if (thumb == null && generatedThumbs < 5) {
            thumb = await _thumbnailService.generateThumbnail(
              fixedItem.filePath!,
            );
            if (thumb != null) {
              generatedThumbs++;
            }
          }

          if (thumb != null) {
            fixedItem = fixedItem.copyWith(thumbnailUrl: thumb);
          }
        }
      }

      // 3. Infer origin from folder / URL — never invent "Local".
      if (fixedItem.filePath != null) {
        final detected = MediaSourceResolver.resolve(
          url: fixedItem.request.url,
          filePath: fixedItem.filePath,
        );
        if (detected != null &&
            MediaSourceResolver.fromUrlString(fixedItem.request.url) == null) {
          final slug = detected.toLowerCase();
          fixedItem = fixedItem.copyWith(
            request: DownloadRequest(url: 'https://$slug.detected/imported'),
          );
        }
      }

      fixedItems.add(fixedItem);
    }

    // Two items can end up on the same file (loose title match, then
    // scanForNewFiles imports the real file). Rebind losers, drop ghosts.
    var result = _rebindSharedFiles(fixedItems);
    return _rebindSharedFiles(result);
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

      final extractor = MetadataExtractorService(_binaryLocator);

      // Get all known paths (normalized) to avoid duplicates
      final knownPaths = knownItems
          .where((i) => i.filePath != null)
          .map((i) => i.filePath!.toLowerCase())
          .toSet();
      final knownIds = <String>{};
      for (final item in knownItems) {
        final fromPath = DownloadFileResolver.extractBracketId(item.filePath);
        final fromTitle = DownloadFileResolver.extractBracketId(item.title);
        if (fromPath != null && fromPath.isNotEmpty) {
          knownIds.add(fromPath.toLowerCase());
        }
        if (fromTitle != null && fromTitle.isNotEmpty) {
          knownIds.add(fromTitle.toLowerCase());
        }
      }

      // Scan recursively
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          if (knownPaths.contains(entity.path.toLowerCase())) continue;
          final fileId = DownloadFileResolver.extractBracketId(entity.path);
          if (fileId != null && knownIds.contains(fileId.toLowerCase())) {
            continue;
          }
          if (_isVideo(entity.path)) {
            LoggerService.i('LibraryScanner: Found new video ${entity.path}');

            final id = const Uuid().v4();
            final metadata = await extractor.extract(entity.path);
            final filename = entity.uri.pathSegments.last;
            final cleanTitle = TitleCleanerService.clean(
              metadata?.title ?? filename,
            );

            final detected = MediaSourceResolver.resolve(
              url: metadata?.sourceUrl,
              filePath: entity.path,
            );
            final requestUrl =
                metadata?.sourceUrl ??
                (detected != null
                    ? 'https://${detected.toLowerCase()}.detected/imported'
                    : 'https://unknown.invalid/imported');
            final diskSize = DownloadFileResolver.formattedFileSize(
              entity.path,
            );
            final newItem = DownloadItem(
              id: id,
              request: DownloadRequest(url: requestUrl),
              title: cleanTitle,
              status: DownloadStatus.completed,
              progress: 1.0,
              filePath: entity.path,
              totalSize: diskSize ?? '',
              downloadedSize: diskSize ?? '',
              sortOrder: 9999,
              thumbnailUrl: _findSidecarThumbnail(entity.path),
            );
            newItems.add(newItem);
          }
        }
      }
    } catch (e) {
      LoggerService.e('LibraryScanner: Error scanning for new files', e);
    }
    return newItems;
  }

  /// Builds a cache of all video files in the given path (recursive).
  /// Always rebuilds so files added since the last scan can be recovered.
  Future<void> _buildVideoCache(String basePath) async {
    _videoFileCache = [];

    try {
      final dir = Directory(basePath);
      if (!dir.existsSync()) return;

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && _isVideo(entity.path)) {
          _videoFileCache!.add(entity);
        }
      }
      LoggerService.i(
        'LibraryScanner: Cached ${_videoFileCache!.length} video files from $basePath',
      );
    } catch (e) {
      LoggerService.e('LibraryScanner: Error building cache', e);
    }
  }

  String _basename(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? path : parts.last;
  }

  /// Resolve the on-disk file for [item], or null if it cannot be found.
  String? _locateExistingFile(DownloadItem item, String basePath) {
    final videoId =
        DownloadFileResolver.extractBracketId(item.filePath) ??
        DownloadFileResolver.extractBracketId(item.title);

    if (item.filePath != null &&
        item.filePath!.trim().isNotEmpty &&
        DownloadFileResolver.existsOnDisk(item.filePath!)) {
      return item.filePath;
    }

    final resolved = DownloadFileResolver.resolve(
      candidatePath: item.filePath,
      outputFolder: basePath,
      videoId: videoId,
    );
    if (resolved != null) return resolved;

    return _findFileFor(item);
  }

  /// Finds a file matching the item's title using normalized comparison
  String? _findFileFor(
    DownloadItem item, {
    Set<String> excludePaths = const {},
  }) {
    if (_videoFileCache == null) return null;

    bool isCandidate(File file) {
      if (DownloadFileResolver.isFragmentPath(file.path)) return false;
      return !excludePaths.contains(file.path.toLowerCase());
    }

    // 1. Prefer bracket video id from previous path or title (most reliable)
    final idFromPath = DownloadFileResolver.extractBracketId(item.filePath);
    final idFromTitle = DownloadFileResolver.extractBracketId(item.title);
    final videoId = idFromPath ?? idFromTitle;
    if (videoId != null && videoId.isNotEmpty) {
      final needle = videoId.toLowerCase();
      for (final file in _videoFileCache!) {
        if (!isCandidate(file)) continue;
        final filename = _basename(file.path);
        final lower = filename.toLowerCase();
        if (lower.contains('[$needle]')) {
          return file.path;
        }
      }
    }

    if (item.title == null) return null;

    final normalizedTitle = _normalize(item.title!);
    if (normalizedTitle.isEmpty) return null;

    // Try exact filename match from previous path
    if (item.filePath != null) {
      final oldFilename = _basename(item.filePath!);
      final normalizedOldFilename = _normalize(oldFilename);

      for (final file in _videoFileCache!) {
        if (!isCandidate(file)) continue;
        final filename = _basename(file.path);
        final normalizedFilename = _normalize(filename);

        if (normalizedFilename == normalizedOldFilename) {
          return file.path;
        }
      }
    }

    // Best title match — never take the first weak overlap (e.g. "Hijab").
    String? bestPath;
    var bestScore = 0.0;
    for (final file in _videoFileCache!) {
      if (!isCandidate(file)) continue;
      final filename = _basename(file.path);
      final score = _fileMatchScore(normalizedTitle, _normalize(filename));
      if (score > bestScore) {
        bestScore = score;
        bestPath = file.path;
      }
    }
    if (bestPath != null && bestScore >= 0.4) {
      return bestPath;
    }

    return null;
  }

  /// When several library rows point at the same file, keep the best owner
  /// and reattach or drop the others.
  List<DownloadItem> _rebindSharedFiles(List<DownloadItem> items) {
    final byPath = <String, List<int>>{};
    for (var i = 0; i < items.length; i++) {
      final path = items[i].filePath;
      if (path == null || path.isEmpty) continue;
      byPath.putIfAbsent(path.toLowerCase(), () => []).add(i);
    }

    final result = List<DownloadItem>.from(items);
    final dropIds = <String>{};

    for (final indexes in byPath.values) {
      if (indexes.length < 2) continue;
      final path = result[indexes.first].filePath!;
      var bestIndex = indexes.first;
      for (final i in indexes.skip(1)) {
        if (_preferItemForPath(path, result[i], result[bestIndex]) ==
            result[i]) {
          bestIndex = i;
        }
      }

      final exclude = {path.toLowerCase()};
      for (final i in indexes) {
        if (i == bestIndex) continue;
        final loser = result[i];
        final found = _findFileFor(
          loser.copyWith(clearFilePath: true),
          excludePaths: exclude,
        );
        if (found != null) {
          final diskSize = DownloadFileResolver.formattedFileSize(found);
          result[i] = loser.copyWith(
            filePath: found,
            clearThumbnailUrl: true,
            thumbnailUrl: _findSidecarThumbnail(found),
            totalSize: diskSize ?? loser.totalSize,
            downloadedSize: diskSize ?? loser.downloadedSize,
          );
          exclude.add(found.toLowerCase());
        } else if (_isImported(loser) ||
            _isSameMedia(loser, result[bestIndex])) {
          LoggerService.debug(
            'LibraryScanner: Dropped duplicate row for ${loser.title}',
          );
          dropIds.add(loser.id);
        } else {
          // The file exists; this row just has no unique copy. Keep the
          // shared path rather than lying that the file is missing.
          LoggerService.w(
            'LibraryScanner: Shared file kept for ${loser.title}',
          );
        }
      }
    }

    if (dropIds.isEmpty) return result;
    return result.where((item) => !dropIds.contains(item.id)).toList();
  }

  DownloadItem _preferItemForPath(String path, DownloadItem a, DownloadItem b) {
    final importedA = _isImported(a);
    final importedB = _isImported(b);
    if (importedA != importedB) {
      return importedA ? b : a;
    }
    final filename = path.split(RegExp(r'[/\\]')).last;
    final fileNorm = _normalize(filename);
    final scoreA = _fileMatchScore(_normalize(a.title ?? ''), fileNorm);
    final scoreB = _fileMatchScore(_normalize(b.title ?? ''), fileNorm);
    if ((scoreA - scoreB).abs() > 0.05) {
      return scoreA > scoreB ? a : b;
    }
    final titleA = a.title ?? '';
    final titleB = b.title ?? '';
    return titleA.length >= titleB.length ? a : b;
  }

  bool _isImported(DownloadItem item) {
    final url = item.request.url.toLowerCase();
    return url.contains('.detected/') || url.contains('/imported');
  }

  /// True when [a] and [b] are library rows for the same media (same tweet).
  bool _isSameMedia(DownloadItem a, DownloadItem b) {
    final urlA = a.request.url.trim();
    final urlB = b.request.url.trim();
    if (urlA.isNotEmpty && urlA.toLowerCase() == urlB.toLowerCase()) {
      return true;
    }
    if (XMediaIdentity.sameMedia(urlA, urlB)) return true;
    final idA =
        XDownloadUrl.tweetIdFrom(urlA) ??
        XDownloadUrl.tweetIdFrom(a.request.forceStreamUrl);
    final idB =
        XDownloadUrl.tweetIdFrom(urlB) ??
        XDownloadUrl.tweetIdFrom(b.request.forceStreamUrl);
    return idA != null && idA == idB;
  }

  /// Normalizes a string for comparison (keeps unicode letters, lowercase)
  String _normalize(String input) {
    // Remove file extensions
    var s = input.replaceAll(
      RegExp(r'\.(mp4|mkv|webm|mov|avi)$', caseSensitive: false),
      '',
    );
    // Remove URLs (raw and collapsed httpst.co forms)
    s = s.replaceAll(RegExp(r'https?[^\s]*', caseSensitive: false), '');
    s = s.replaceAll(
      RegExp(r'https?t\.co[A-Za-z0-9]+', caseSensitive: false),
      '',
    );
    // Keep unicode letters/numbers and spaces; drop other punctuation
    s = s.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    // Collapse whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    return s;
  }

  /// Jaccard + stem score. A single shared word (e.g. "hijab") must not win.
  double _fileMatchScore(String titleNorm, String filenameNorm) {
    if (titleNorm.isEmpty || filenameNorm.isEmpty) return 0;

    final fileStem = filenameNorm
        .replaceAll(RegExp(r'\b\d{8,}\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (fileStem == titleNorm) return 1.0;
    if (fileStem.startsWith(titleNorm) || titleNorm.startsWith(fileStem)) {
      final shorter = fileStem.length < titleNorm.length
          ? fileStem.length
          : titleNorm.length;
      final longer = fileStem.length > titleNorm.length
          ? fileStem.length
          : titleNorm.length;
      if (shorter >= 3 && longer > 0 && shorter / longer >= 0.5) {
        return 0.9;
      }
    }

    final wordsA = _significantWords(titleNorm);
    final wordsB = _significantWords(fileStem);
    if (wordsA.isEmpty || wordsB.isEmpty) return 0;
    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;
    if (union == 0) return 0;
    return intersection / union;
  }

  Set<String> _significantWords(String normalized) {
    return normalized
        .split(' ')
        .where((w) => w.isNotEmpty && (w.length > 2 || _isCjkHeavy(w)))
        .toSet();
  }

  /// True when most characters are CJK (Japanese/Chinese/Korean).
  bool _isCjkHeavy(String word) {
    if (word.isEmpty) return false;
    final cjk = RegExp(
      r'[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]',
    );
    var count = 0;
    for (final rune in word.runes) {
      if (cjk.hasMatch(String.fromCharCode(rune))) count++;
    }
    return count >= (word.runes.length / 2).ceil();
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

  bool _isVideo(String path) {
    return DownloadFileResolver.isVideoPath(path);
  }

  bool _hasStaleRetryState(DownloadItem item) {
    if (item.error != null && item.error!.isNotEmpty) return true;
    if (item.speed.toLowerCase().contains('retry')) return true;
    if (item.progress < 0.99) return true;
    return false;
  }

  /// Promote failed/paused → completed only when the file is a non-fragment
  /// with length &gt; 0. Clears stale error / Retry speed / 0% progress.
  DownloadItem? _promoteToCompletedIfValid(DownloadItem item) {
    final path = item.filePath;
    if (path == null || path.isEmpty) return null;
    if (DownloadFileResolver.isFragmentPath(path)) return null;

    try {
      final file = File(path);
      if (!DownloadFileResolver.existsOnDisk(path)) return null;
      final bytes = file.lengthSync();
      if (bytes <= 0) return null;
      final size = FormatUtils.formatBytes(bytes);
      return item.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        speed: 'Terminé',
        totalSize: size,
        downloadedSize: size,
        clearError: true,
      );
    } catch (_) {
      return null;
    }
  }
}
