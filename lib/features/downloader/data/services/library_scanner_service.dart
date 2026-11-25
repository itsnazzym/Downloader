import 'dart:io';
import 'dart:isolate';
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
import 'package:modern_downloader/core/services/binary/binary_locator.dart';

class _IndexedVideoFile {
  const _IndexedVideoFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final int sizeBytes;

  String get pathKey => path.toLowerCase();

  factory _IndexedVideoFile.fromMap(Map<String, Object?> source) {
    return _IndexedVideoFile(
      path: source['path']! as String,
      name: source['name']! as String,
      sizeBytes: source['sizeBytes']! as int,
    );
  }
}

class LibraryScanResult {
  const LibraryScanResult({required this.fixedItems, required this.newItems});

  final List<DownloadItem> fixedItems;
  final List<DownloadItem> newItems;
}

/// Filesystem traversal and stat calls must never execute on Flutter's UI
/// isolate. The worker returns only primitive values, which are safe to pass
/// back across an isolate boundary.
List<Map<String, Object?>> _indexVideoFiles(String basePath) {
  final directory = Directory(basePath);
  if (!directory.existsSync()) return const [];

  final files = <Map<String, Object?>>[];
  try {
    for (final entity in directory.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !DownloadFileResolver.isVideoPath(entity.path)) {
        continue;
      }
      try {
        files.add(<String, Object?>{
          'path': entity.path,
          'name': entity.uri.pathSegments.last,
          'sizeBytes': entity.lengthSync(),
        });
      } catch (_) {
        // A file can disappear while the library is being indexed.
      }
    }
  } catch (_) {
    return files;
  }
  return files;
}

class LibraryScannerService {
  static const int _maxFuzzyComparisons = 25000;

  /// Cache of all video files found during scanning
  List<_IndexedVideoFile>? _videoFileCache;
  List<String> _videoNormalizedNames = const <String>[];
  Map<String, _IndexedVideoFile> _videoByPath = <String, _IndexedVideoFile>{};
  Map<String, _IndexedVideoFile> _videoById = <String, _IndexedVideoFile>{};
  Map<String, _IndexedVideoFile> _videoByNormalizedName =
      <String, _IndexedVideoFile>{};
  DateTime? _videoCacheBuiltAt;
  bool _allowFuzzyMatching = false;

  LibraryScannerService(BinaryLocator _);

  LibraryScannerService._worker();

  /// Indexes and reconciles the catalogue in one worker isolate. Keeping both
  /// passes together reuses the same filesystem index and avoids CPU or stat
  /// work on Flutter's UI isolate.
  Future<LibraryScanResult> scanLibrary(
    List<DownloadItem> items,
    String basePath,
  ) {
    return Isolate.run(() async {
      final worker = LibraryScannerService._worker();
      final fixedItems = await worker._scanAndFixInWorker(items, basePath);
      final newItems = await worker._scanForNewFilesInWorker(
        fixedItems,
        basePath,
      );
      return LibraryScanResult(fixedItems: fixedItems, newItems: newItems);
    });
  }

  /// Scans current items and fixes paths, thumbnails, and status
  Future<List<DownloadItem>> scanAndFix(
    List<DownloadItem> items,
    String basePath,
  ) async {
    return Isolate.run(() {
      final worker = LibraryScannerService._worker();
      return worker._scanAndFixInWorker(items, basePath);
    });
  }

  Future<List<DownloadItem>> _scanAndFixInWorker(
    List<DownloadItem> items,
    String basePath,
  ) async {
    final fixedItems = <DownloadItem>[];
    LoggerService.i('LibraryScanner: logic start for ${items.length} items');

    // Build cache of all video files in basePath (recursive)
    await _buildVideoCache(basePath);
    final indexedFileCount = _videoFileCache?.length ?? 0;
    _allowFuzzyMatching =
        items.length * indexedFileCount <= _maxFuzzyComparisons;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (i > 0 && i % 30 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
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
          fixedItem =
              _promoteToCompletedIfValid(fixedItem, locatedPath) ?? fixedItem;
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
        final promoted = _promoteToCompletedIfValid(
          fixedItem,
          fixedItem.filePath,
        );
        if (promoted != null) {
          fixedItem = promoted;
        }
      }

      // yt-dlp often never emits "% of 10.00MiB" (Twitter HLS / after_move).
      // Backfill totalSize from the real file so the grid does not show
      // "Unknown Size" for completed downloads already on disk.
      if (fixedItem.totalSize.isEmpty) {
        final diskSize = _formattedSizeForPath(fixedItem.filePath);
        if (diskSize != null) {
          fixedItem = fixedItem.copyWith(
            totalSize: diskSize,
            downloadedSize: diskSize,
          );
        }
      }

      // 2. Thumbnails are lazy. Starting ffmpeg for a library-wide thumbnail
      // sweep causes long startup stalls on large libraries. Existing paths are
      // preserved; missing previews are handled by the row placeholder.

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
    return Isolate.run(() {
      final worker = LibraryScannerService._worker();
      return worker._scanForNewFilesInWorker(knownItems, downloadPath);
    });
  }

  Future<List<DownloadItem>> _scanForNewFilesInWorker(
    List<DownloadItem> knownItems,
    String downloadPath,
  ) async {
    final newItems = <DownloadItem>[];
    try {
      await _ensureVideoCache(downloadPath);

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

      var nextSortOrder =
          knownItems.fold<int>(
            0,
            (maxOrder, item) =>
                item.sortOrder > maxOrder ? item.sortOrder : maxOrder,
          ) +
          1;

      for (final entity in _videoFileCache ?? const <_IndexedVideoFile>[]) {
        if (knownPaths.contains(entity.pathKey)) continue;
        final fileId = DownloadFileResolver.extractBracketId(entity.path);
        if (fileId != null && knownIds.contains(fileId.toLowerCase())) {
          continue;
        }
        LoggerService.i('LibraryScanner: Found new video ${entity.path}');

        final id = const Uuid().v4();
        final cleanTitle = TitleCleanerService.clean(entity.name);
        final detected = MediaSourceResolver.resolve(filePath: entity.path);
        final requestUrl = detected != null
            ? 'https://${detected.toLowerCase()}.detected/imported'
            : 'https://unknown.invalid/imported';
        final diskSize = FormatUtils.formatBytes(entity.sizeBytes);
        newItems.add(
          DownloadItem(
            id: id,
            request: DownloadRequest(url: requestUrl),
            title: cleanTitle,
            status: DownloadStatus.completed,
            progress: 1.0,
            filePath: entity.path,
            totalSize: diskSize,
            downloadedSize: diskSize,
            sortOrder: nextSortOrder++,
          ),
        );
      }
    } catch (e) {
      LoggerService.e('LibraryScanner: Error scanning for new files', e);
    }
    return newItems;
  }

  /// Builds a cache of all video files in the given path (recursive).
  /// Always rebuilds so files added since the last scan can be recovered.
  Future<void> _buildVideoCache(String basePath) async {
    try {
      final records = _indexVideoFiles(basePath);
      final indexed = records.map(_IndexedVideoFile.fromMap).toList();
      _videoFileCache = indexed;
      _videoByPath = {for (final file in indexed) file.pathKey: file};
      _videoById = <String, _IndexedVideoFile>{};
      _videoByNormalizedName = <String, _IndexedVideoFile>{};
      _videoNormalizedNames = <String>[];
      for (final file in indexed) {
        final id = DownloadFileResolver.extractBracketId(file.name);
        if (id != null && id.isNotEmpty) {
          _videoById.putIfAbsent(id.toLowerCase(), () => file);
        }
        final normalizedName = _normalize(file.name);
        _videoNormalizedNames.add(normalizedName);
        _videoByNormalizedName.putIfAbsent(normalizedName, () => file);
      }
      _videoCacheBuiltAt = DateTime.now();
      LoggerService.i(
        'LibraryScanner: Indexed ${indexed.length} video files from $basePath',
      );
    } catch (e) {
      LoggerService.e('LibraryScanner: Error building cache', e);
    }
  }

  Future<void> _ensureVideoCache(String basePath) async {
    final cacheAge = _videoCacheBuiltAt == null
        ? null
        : DateTime.now().difference(_videoCacheBuiltAt!);
    if (_videoFileCache != null &&
        cacheAge != null &&
        cacheAge < const Duration(minutes: 1)) {
      return;
    }
    await _buildVideoCache(basePath);
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

    if (item.filePath != null && item.filePath!.trim().isNotEmpty) {
      final existing = _videoByPath[item.filePath!.toLowerCase()];
      if (existing != null) return existing.path;
      // The index only covers the library root; a file yt-dlp saved
      // elsewhere (Downloads, a per-download folder) still exists. Runs in
      // the scan isolate, so the sync check is off the UI thread.
      if (File(item.filePath!).existsSync()) return item.filePath;
    }

    if (videoId != null && videoId.isNotEmpty) {
      final byId = _videoById[videoId.toLowerCase()];
      if (byId != null) return byId.path;
    }

    if (item.filePath != null && item.filePath!.trim().isNotEmpty) {
      final byOldName =
          _videoByNormalizedName[_normalize(_basename(item.filePath!))];
      if (byOldName != null) return byOldName.path;
    }

    if (item.title != null && item.title!.trim().isNotEmpty) {
      final byTitle = _videoByNormalizedName[_normalize(item.title!)];
      if (byTitle != null) return byTitle.path;
    }

    return _findFileFor(item);
  }

  /// Finds a file matching the item's title using normalized comparison
  String? _findFileFor(
    DownloadItem item, {
    Set<String> excludePaths = const {},
  }) {
    if (_videoFileCache == null) return null;

    bool isCandidate(_IndexedVideoFile file) {
      if (DownloadFileResolver.isFragmentPath(file.path)) return false;
      return !excludePaths.contains(file.path.toLowerCase());
    }

    // 1. Prefer bracket video id from previous path or title (most reliable)
    final idFromPath = DownloadFileResolver.extractBracketId(item.filePath);
    final idFromTitle = DownloadFileResolver.extractBracketId(item.title);
    final videoId = idFromPath ?? idFromTitle;
    if (videoId != null && videoId.isNotEmpty) {
      final byId = _videoById[videoId.toLowerCase()];
      if (byId != null && isCandidate(byId)) return byId.path;
    }

    if (item.title == null) return null;

    final normalizedTitle = _normalize(item.title!);
    if (normalizedTitle.isEmpty) return null;

    // Try exact filename match from previous path
    if (item.filePath != null) {
      final oldFilename = _basename(item.filePath!);
      final normalizedOldFilename = _normalize(oldFilename);

      final byName = _videoByNormalizedName[normalizedOldFilename];
      if (byName != null && isCandidate(byName)) return byName.path;
    }

    final exactTitle = _videoByNormalizedName[normalizedTitle];
    if (exactTitle != null && isCandidate(exactTitle)) return exactTitle.path;

    // Fuzzy matching is a legacy recovery path. Bound the total candidate
    // comparisons across the whole reconciliation pass, not only the number
    // of files: thousands of failed rows and a modest folder can still make
    // an items × files scan expensive.
    if (!_allowFuzzyMatching) return null;

    // Best title match — never take the first weak overlap (e.g. "Hijab").
    String? bestPath;
    var bestScore = 0.0;
    for (var i = 0; i < _videoFileCache!.length; i++) {
      final file = _videoFileCache![i];
      if (!isCandidate(file)) continue;
      final score = _fileMatchScore(normalizedTitle, _videoNormalizedNames[i]);
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
          final diskSize = _formattedSizeForPath(found);
          result[i] = loser.copyWith(
            filePath: found,
            clearThumbnailUrl: true,
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

  String? _formattedSizeForPath(String? path) {
    if (path == null || path.isEmpty) return null;
    final bytes = _videoByPath[path.toLowerCase()]?.sizeBytes;
    if (bytes == null || bytes <= 0) return null;
    return FormatUtils.formatBytes(bytes);
  }

  bool _hasStaleRetryState(DownloadItem item) {
    if (item.error != null && item.error!.isNotEmpty) return true;
    if (item.speed.toLowerCase().contains('retry')) return true;
    if (item.progress < 0.99) return true;
    return false;
  }

  /// Promote failed/paused → completed only when the file is a non-fragment
  /// with length &gt; 0. Clears stale error / Retry speed / 0% progress.
  DownloadItem? _promoteToCompletedIfValid(
    DownloadItem item,
    String? resolvedPath,
  ) {
    final path = resolvedPath ?? item.filePath;
    if (path == null || path.isEmpty) return null;
    if (DownloadFileResolver.isFragmentPath(path)) return null;

    final bytes = _videoByPath[path.toLowerCase()]?.sizeBytes;
    if (bytes == null || bytes <= 0) return null;
    final size = FormatUtils.formatBytes(bytes);
    return item.copyWith(
      status: DownloadStatus.completed,
      progress: 1.0,
      speed: 'Terminé',
      totalSize: size,
      downloadedSize: size,
      clearError: true,
    );
  }
}
