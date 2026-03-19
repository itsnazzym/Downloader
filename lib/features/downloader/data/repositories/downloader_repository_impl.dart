import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../domain/entities/download_item.dart';
import '../../domain/entities/download_request.dart';
import '../../domain/enums/download_status.dart';
import '../../domain/repositories/i_downloader_repository.dart';
import '../sources/yt_dlp_source.dart';
import '../sources/gallery_dl_source.dart';
import '../services/library_scanner_service.dart';
import '../../../../core/logger/logger_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/duplicate_detector_service.dart';
import '../../../../core/services/disk_space_service.dart';
import '../../../../core/utils/format_utils.dart';
import '../datasources/persistence_service.dart';
import '../../../../core/services/title_cleaner_service.dart';
import '../../../../core/plugins/plugin_manager.dart';
import '../../../../core/plugins/plugin_interface.dart';
import '../../../../core/utils/media_file_utils.dart';

class DownloaderRepositoryImpl implements IDownloaderRepository {
  final YtDlpSource _source;
  final GalleryDlSource _galleryDlSource;
  final PersistenceService _persistenceService;
  final LibraryScannerService _libraryScanner;
  final PluginManager _pluginManager;
  final String Function() _resolveOutputFolder;

  final _controller = StreamController<DownloadItem>.broadcast();
  final _activeDownloads = <String, DownloadItem>{};
  Timer? _saveTimer;

  DownloaderRepositoryImpl(
    this._source,
    this._galleryDlSource,
    this._persistenceService,
    this._libraryScanner,
    this._pluginManager,
    this._resolveOutputFolder,
  ) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final loaded = await _persistenceService.loadDownloads();
    List<DownloadItem> initialList = [];

    for (final item in loaded) {
      if (_activeDownloads.containsKey(item.id)) continue;
      if (!_shouldKeepPersistedItem(item)) continue;
      var status = item.status;
      if (status == DownloadStatus.downloading ||
          status == DownloadStatus.extracting) {
        status = DownloadStatus.paused;
      }
      initialList.add(item.copyWith(status: status));
    }

    // Get the download path for scanning
    final downloadPath = await _getDownloadPath();
    if (downloadPath == null) {
      // Just load items without scanning if we can't determine path
      for (final item in initialList) {
        _activeDownloads[item.id] = item;
        _controller.add(item); // Emit to stream
      }
      return;
    }

    // Scan and fix existing items (recursive search in subdirectories)
    final fixedItems = await _libraryScanner.scanAndFix(
      initialList,
      downloadPath,
    );
    for (final item in fixedItems) {
      _activeDownloads[item.id] = item;
      _controller.add(item); // Emit to stream
    }

    await _scanLibrary(downloadPath);
  }

  Future<String?> _getDownloadPath() async {
    final configuredPath = _resolveOutputFolder().trim();
    if (configuredPath.isNotEmpty) {
      return configuredPath;
    }

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile == null) return null;
      return '$userProfile\\Downloads';
    }
    return null;
  }

  Future<void> _scanLibrary(String downloadPath) async {
    try {
      final newItems = await _libraryScanner.scanForNewFiles(
        _activeDownloads.values.toList(),
        downloadPath,
      );

      for (final item in newItems) {
        _activeDownloads[item.id] = item;
        _controller.add(item);
      }

      if (newItems.isNotEmpty) {
        _saveToDisk();
      }
    } catch (e) {
      LoggerService.e('Library scan failed', e);
    }
  }

  @override
  Future<void> refreshLibrary() async {
    LoggerService.i('Refreshing library...');
    final downloadPath = await _getDownloadPath();
    if (downloadPath == null) return;

    // 1. Remove duplicate files from filesystem
    final duplicateDetector = DuplicateDetectorService();
    final dupResult = await duplicateDetector.findAndRemoveDuplicates(
      downloadPath,
    );

    if (dupResult.duplicatesRemoved > 0) {
      LoggerService.i(
        'Removed ${dupResult.duplicatesRemoved} duplicate files, '
        'recovered ${_formatBytes(dupResult.bytesRecovered)}',
      );
    }

    // 2. Remove entries from app state that reference deleted duplicates
    final removedPaths = dupResult.duplicateDetails
        .map((d) => d.removed)
        .toSet();
    final itemsToRemove = <String>[];

    for (final entry in _activeDownloads.entries) {
      final item = entry.value;
      if (item.filePath != null && removedPaths.contains(item.filePath)) {
        itemsToRemove.add(entry.key);
      }
    }

    for (final id in itemsToRemove) {
      _activeDownloads.remove(id);
      LoggerService.debug('Removed duplicate entry from app: $id');
    }

    // 3. Re-scan and fix existing items
    final currentItems = _activeDownloads.values.toList();
    final fixedItems = await _libraryScanner.scanAndFix(
      currentItems,
      downloadPath,
    );

    for (final item in fixedItems) {
      _activeDownloads[item.id] = item;
      _controller.add(item);
    }

    // 4. Scan for new files
    await _scanLibrary(downloadPath);
    _saveToDisk();

    LoggerService.i(
      'Library refresh complete. Duplicates removed: ${dupResult.duplicatesRemoved}',
    );
  }

  String _formatBytes(int bytes) {
    return FormatUtils.formatBytes(bytes);
  }

  @override
  List<DownloadItem> getCurrentDownloads() {
    final list = _activeDownloads.values.toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  @override
  Stream<DownloadItem> get downloadUpdateStream => _controller.stream;

  @override
  Future<String> startDownload(DownloadRequest request) async {
    final id = const Uuid().v4();
    LoggerService.i('Starting download: ${request.url}');

    DownloadRequest effectiveRequest = request;
    if (request.url.contains('kick.com')) {
      effectiveRequest = request.copyWith(concurrentFragments: 64);
    }

    String initialTitle = _extractInitialTitle(effectiveRequest.url);
    int nextOrder = 0;
    if (_activeDownloads.isNotEmpty) {
      final maxOrder = _activeDownloads.values
          .map((e) => e.sortOrder)
          .reduce((a, b) => a > b ? a : b);
      nextOrder = maxOrder + 1;
    }

    final item = DownloadItem(
      id: id,
      request: effectiveRequest,
      title: initialTitle,
      sortOrder: nextOrder,
    );
    _update(item);

    _startDownloadProcess(id, effectiveRequest);
    return id;
  }

  Future<void> _startDownloadProcess(String id, DownloadRequest request) async {
    int retryCount = 0;
    const maxRetries = 3;

    Future<void> run() async {
      DownloadRequest currentRequest = request;
      Map<String, dynamic>? sourceMetadata;
      File? tempCookiesFile;
      bool preDownloadPluginsDispatched = false;
      try {
        // 1. Prepare Cookies
        if (request.rawCookies != null && request.rawCookies!.isNotEmpty) {
          // Check if it's a Header string (Extension) or Netscape file content
          // Headers usually have "name=value;" and NO tabs. Netscape has tabs.
          final isHeader =
              !request.rawCookies!.contains('\t') &&
              request.rawCookies!.contains('=');

          if (!isHeader) {
            try {
              final tempDir = Directory.systemTemp;
              tempCookiesFile = File('${tempDir.path}/md_cookies_$id.txt');
              await tempCookiesFile.writeAsString(request.rawCookies!);
              currentRequest = request.copyWith(
                cookiesFilePath: tempCookiesFile.path,
              );
            } catch (e) {
              LoggerService.w('Failed to create temp cookies file: $e');
            }
          }
        }

        while (retryCount < maxRetries) {
          if (_activeDownloads[id]?.status == DownloadStatus.canceled ||
              _activeDownloads[id]?.status == DownloadStatus.paused) {
            return;
          }

          try {
            // 2. Pre-flight Check: Disk Space
            if (retryCount == 0) {
              await DiskSpaceService.checkDiskSpace();
            }

            // 3. Status Update
            if (retryCount > 0) {
              _update(
                _activeDownloads[id]!.copyWith(
                  status: DownloadStatus.extracting,
                  speed: 'Retry ${retryCount + 1}/$maxRetries...',
                ),
              );
              await Future.delayed(Duration(seconds: 5)); // Backoff
            } else {
              _update(
                _activeDownloads[id]!.copyWith(
                  status: DownloadStatus.extracting,
                ),
              );
            }

            // 4. Metadata Extraction (Retried if fails)
            String finalTitle = _activeDownloads[id]?.title ?? 'Video';
            String? finalThumbnail = _activeDownloads[id]?.thumbnailUrl;

            try {
              final metadata = await _source.fetchMetadata(
                currentRequest.url,
                cookies: _isCookieHeader(currentRequest.rawCookies)
                    ? currentRequest.rawCookies
                    : null,
                cookiesFilePath: !_isCookieHeader(currentRequest.rawCookies)
                    ? currentRequest.cookiesFilePath
                    : null,
              );
              sourceMetadata = metadata;
              final String? fetchedTitle = metadata['title'];
              finalThumbnail = metadata['thumbnail'];
              final String? videoId = metadata['id'];

              // Platform-specific title logic...
              if (currentRequest.url.contains('twitter.com') ||
                  currentRequest.url.contains('x.com')) {
                final String? uploader =
                    metadata['uploader'] ?? metadata['uploader_id'];
                if (fetchedTitle == null ||
                    fetchedTitle.isEmpty ||
                    fetchedTitle == videoId ||
                    fetchedTitle.contains('twitter.com')) {
                  if (uploader != null && videoId != null) {
                    finalTitle = '$uploader - $videoId';
                  } else if (videoId != null) {
                    finalTitle = 'Tweet $videoId';
                  }
                } else {
                  finalTitle = fetchedTitle;
                }
              } else if (fetchedTitle != null &&
                  fetchedTitle.isNotEmpty &&
                  fetchedTitle != 'null' &&
                  fetchedTitle != videoId) {
                finalTitle = fetchedTitle;
              }

              finalTitle = TitleCleanerService.clean(finalTitle);
              _update(
                _activeDownloads[id]!.copyWith(
                  title: finalTitle,
                  thumbnailUrl: finalThumbnail,
                ),
              );

              // Build filename with unique ID to prevent false duplicates
              // e.g. "My Video [abc123].mp4" instead of "My Video.mp4"
              if (videoId != null && videoId.isNotEmpty) {
                final cleanId = videoId.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
                currentRequest = currentRequest.copyWith(
                  customFilename: '$finalTitle [$cleanId].%(ext)s',
                );
              } else {
                // No ID available — derive a short hash from the URL as unique suffix
                final urlHash = currentRequest.url.hashCode.toRadixString(36);
                currentRequest = currentRequest.copyWith(
                  customFilename: '$finalTitle [$urlHash].%(ext)s',
                );
              }
            } catch (e) {
              LoggerService.w(
                'Metadata extraction failed (retry possible): $e',
              );
              // If metadata fails, we still try to download with derived title as fallback or retry
              if (retryCount < maxRetries - 1) {
                retryCount++;
                continue; // Retry whole loop
              }
              finalTitle = TitleCleanerService.deriveTitleFromUrl(
                currentRequest.url,
              );
              // Ensure unique filename even without metadata
              final urlHash = currentRequest.url.hashCode.toRadixString(36);
              currentRequest = currentRequest.copyWith(
                customFilename: '$finalTitle [$urlHash].%(ext)s',
              );
            }

            if (!preDownloadPluginsDispatched) {
              final preDownloadResult = await _pluginManager.onBeforeDownload(
                await _buildPluginEvent(
                  id,
                  request: currentRequest,
                  sourceMetadata: sourceMetadata,
                ),
              );

              if (preDownloadResult?.shouldCancel == true) {
                _update(
                  _activeDownloads[id]!.copyWith(
                    status: preDownloadResult!.isDuplicate
                        ? DownloadStatus.duplicate
                        : DownloadStatus.canceled,
                    progress: preDownloadResult.isDuplicate ? 1.0 : 0.0,
                    speed:
                        preDownloadResult.message ??
                        (preDownloadResult.isDuplicate
                            ? 'Duplicate blocked'
                            : 'Canceled by plugin'),
                    step: 'Blocked by plugin',
                    filePath:
                        preDownloadResult.existingFilePath ??
                        _activeDownloads[id]!.filePath,
                  ),
                );
                return;
              }

              await _pluginManager.onDownloadStart(
                await _buildPluginEvent(
                  id,
                  request: currentRequest,
                  sourceMetadata: sourceMetadata,
                ),
              );
              preDownloadPluginsDispatched = true;
            }

            // 5. Download Execution
            _update(
              _activeDownloads[id]!.copyWith(
                status: DownloadStatus.downloading,
              ),
            );

            await for (final progress in _source.download(id, currentRequest)) {
              if (progress.isDuplicate) {
                _update(
                  _activeDownloads[id]!.copyWith(
                    status: DownloadStatus.duplicate,
                    progress: 1.0,
                    speed: 'Doublon',
                    title: progress.title ?? _activeDownloads[id]!.title,
                    filePath:
                        progress.filePath ?? _activeDownloads[id]!.filePath,
                  ),
                );
                return;
              }

              _update(
                _activeDownloads[id]!.copyWith(
                  progress: progress.progress >= 0
                      ? progress.progress
                      : _activeDownloads[id]!.progress,
                  eta: progress.eta,
                  speed: progress.speed,
                  totalSize: progress.totalSize,
                  downloadedSize: progress.downloadedSize,
                  step: progress.step,
                  title: _shouldUpdateTitle(
                    _activeDownloads[id]!.title,
                    progress.title,
                  ),
                  filePath: progress.filePath ?? _activeDownloads[id]!.filePath,
                ),
              );
            }

            // 6. Success
            _update(
              _activeDownloads[id]!.copyWith(
                status: DownloadStatus.completed,
                progress: 1.0,
              ),
            );
            NotificationService().showDownloadComplete(
              _activeDownloads[id]!.title ?? 'Download Complete',
            );

            await _runCompletionPlugins(
              id,
              currentRequest,
              sourceMetadata: sourceMetadata,
            );

            // Note: stats recording is handled by the provider layer
            return;
          } catch (e) {
            // Rethrow if it's a fatal non-retryable error (like Disk Space)
            if (e.toString().contains('Low Disk Space')) rethrow;

            retryCount++;
            LoggerService.e('Download try $retryCount failed: $e');
            if (retryCount >= maxRetries) rethrow;
          }
        }
      } catch (e, st) {
        LoggerService.e('Download $id FATAL ERROR', e, st);
        if (GalleryDlSource.shouldUseFallback(request.url)) {
          try {
            await _tryGalleryDlFallback(id, currentRequest);
            await _runCompletionPlugins(
              id,
              currentRequest,
              sourceMetadata: sourceMetadata,
            );
            return;
          } catch (ge) {
            LoggerService.w('Gallery DL fallback failed: $ge');
          }
        }
        _update(
          _activeDownloads[id]!.copyWith(
            status: DownloadStatus.failed,
            error: e.toString(),
          ),
        );
        NotificationService().showDownloadFailed(
          _activeDownloads[id]?.title ?? 'Download Failed',
          e.toString(),
        );
        await _runFailurePlugins(
          id,
          currentRequest,
          e,
          sourceMetadata: sourceMetadata,
        );
      } finally {
        if (tempCookiesFile?.existsSync() ?? false) {
          tempCookiesFile?.deleteSync();
        }
      }
    }

    run();
  }

  Future<void> _tryGalleryDlFallback(String id, DownloadRequest request) async {
    _update(_activeDownloads[id]!.copyWith(status: DownloadStatus.downloading));
    await for (final progress in _galleryDlSource.download(id, request)) {
      final videoPath = _resolveFallbackVideoPath(progress.filePath);

      if (progress.isComplete) {
        if (videoPath == null) {
          await _cleanupUnsupportedFallback(progress);
          throw Exception(
            'This project only supports video downloads. Photo-only downloads are blocked.',
          );
        }

        _update(
          _activeDownloads[id]!.copyWith(
            status: DownloadStatus.completed,
            progress: 1.0,
            title: progress.title ?? _activeDownloads[id]?.title ?? 'Unknown',
            speed: progress.status,
            filePath: videoPath,
            thumbnailUrl:
                progress.thumbnailPath ??
                _activeDownloads[id]?.thumbnailUrl ??
                _activeDownloads[id]?.thumbnailUrl,
          ),
        );
      } else {
        _update(
          _activeDownloads[id]!.copyWith(
            speed: progress.status,
            title:
                progress.title ??
                _activeDownloads[id]?.title ??
                'Processing...',
            filePath: videoPath ?? _activeDownloads[id]?.filePath,
            thumbnailUrl:
                progress.thumbnailPath ?? _activeDownloads[id]?.thumbnailUrl,
          ),
        );
      }
    }
  }

  @override
  Future<void> pauseDownload(String id) async {
    await _source.cancel(id);
    await _galleryDlSource.cancel(id);
    if (_activeDownloads.containsKey(id)) {
      _update(
        _activeDownloads[id]!.copyWith(
          status: DownloadStatus.paused,
          speed: 'Paused',
        ),
      );
    }
  }

  @override
  Future<void> cancelDownload(String id) async {
    await _source.cancel(id);
    await _galleryDlSource.cancel(id);
    if (_activeDownloads.containsKey(id)) {
      _update(
        _activeDownloads[id]!.copyWith(
          status: DownloadStatus.canceled,
          speed: 'Canceled',
        ),
      );
    }
  }

  @override
  Future<void> deleteDownload(String id) async {
    // 1. Cancel active process if running
    await _source.cancel(id);
    await _galleryDlSource.cancel(id);

    // 2. Locate the item to find its file path
    final item = _activeDownloads[id];
    if (item != null && item.filePath != null) {
      try {
        final itemPath = item.filePath!;
        final directory = Directory(itemPath);
        if (await directory.exists()) {
          final libraryRoot = await _getDownloadPath();
          final normalizedDirectory = p.normalize(directory.path).toLowerCase();
          final normalizedRoot = libraryRoot == null
              ? null
              : p.normalize(libraryRoot).toLowerCase();

          if (normalizedRoot != null && normalizedDirectory == normalizedRoot) {
            LoggerService.w(
              'Refusing to delete library root for item ${item.id}: $itemPath',
            );
          } else {
            await directory.delete(recursive: true);
            LoggerService.i('Deleted gallery directory: $itemPath');
          }
        } else {
          final file = File(itemPath);

          // Delete main file
          if (await file.exists()) {
            await file.delete();
            LoggerService.i('Deleted file: ${item.filePath}');
          }

          // Delete sidecar thumbnails (.jpg, .webp, .png next to video)
          final dotIndex = item.filePath!.lastIndexOf('.');
          if (dotIndex != -1) {
            final basePath = item.filePath!.substring(0, dotIndex);
            for (final ext in ['.jpg', '.webp', '.png']) {
              try {
                final thumbFile = File('$basePath$ext');
                if (await thumbFile.exists()) {
                  await thumbFile.delete();
                  LoggerService.i('Deleted thumbnail: $basePath$ext');
                }
              } catch (_) {}
            }
          }

          // 3. Cleanup temporary files (.part, .ytdl, etc.)
          final parentDirectory = file.parent;
          if (await parentDirectory.exists()) {
            final filename = file.uri.pathSegments.last.replaceAll(
              RegExp(r'\.\w+$'),
              '',
            );
            await for (final entity in parentDirectory.list()) {
              if (entity is File) {
                final name = entity.uri.pathSegments.last;
                if (name.contains(filename) &&
                    (name.endsWith('.part') ||
                        name.endsWith('.ytdl') ||
                        name.endsWith('.aria2') ||
                        name.contains('.f') ||
                        name.endsWith('.temp'))) {
                  try {
                    await entity.delete();
                    LoggerService.debug('Cleaned up temp file: $name');
                  } catch (_) {}
                }
              }
            }
          }
        }
      } catch (e) {
        LoggerService.w('Failed to delete files for $id: $e');
      }
    }

    // 4. Remove from state and persistence
    _activeDownloads.remove(id);
    if (item != null) {
      _controller.add(item.copyWith(status: DownloadStatus.canceled));
      _saveToDisk();
    }

    LoggerService.i('Download removed: ${item?.title ?? id}');
  }

  @override
  Future<void> reorderDownloads(int oldIndex, int newIndex) async {
    final list = _activeDownloads.values.toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (oldIndex < newIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    for (int i = 0; i < list.length; i++) {
      final updated = list[i].copyWith(sortOrder: i);
      _activeDownloads[updated.id] = updated;
      _controller.add(updated);
    }
    _saveToDisk();
  }

  @override
  Future<void> resumeDownload(String id) async {
    if (_activeDownloads.containsKey(id)) {
      _startDownloadProcess(id, _activeDownloads[id]!.request);
    }
  }

  void _update(DownloadItem item) {
    _activeDownloads[item.id] = item;
    _controller.add(item);
    _saveToDisk();
  }

  void _saveToDisk() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _persistenceService.saveDownloads(_activeDownloads.values.toList());
    });
  }

  @override
  Future<Map<String, dynamic>> fetchMetadata(
    String url, {
    String? cookies,
  }) async {
    return _source.fetchMetadata(url, cookies: cookies);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPlaylist(String url) async {
    return _source.fetchPlaylist(url);
  }

  Future<void> _runCompletionPlugins(
    String id,
    DownloadRequest request, {
    Map<String, dynamic>? sourceMetadata,
  }) async {
    try {
      final pluginResult = await _pluginManager.onDownloadComplete(
        await _buildPluginEvent(
          id,
          request: request,
          sourceMetadata: sourceMetadata,
        ),
      );

      if (pluginResult != null) {
        _update(
          _activeDownloads[id]!.copyWith(
            filePath:
                pluginResult.newFilePath ?? _activeDownloads[id]!.filePath,
            title: pluginResult.newTitle ?? _activeDownloads[id]!.title,
            thumbnailUrl:
                pluginResult.newThumbnailPath ??
                _activeDownloads[id]!.thumbnailUrl,
          ),
        );
      }
    } catch (pluginError, st) {
      LoggerService.e('Plugin processing failed', pluginError, st);
    }
  }

  Future<void> _runFailurePlugins(
    String id,
    DownloadRequest request,
    Object error, {
    Map<String, dynamic>? sourceMetadata,
  }) async {
    try {
      await _pluginManager.onDownloadFailed(
        await _buildPluginEvent(
          id,
          request: request,
          sourceMetadata: sourceMetadata,
          error: error.toString(),
        ),
      );
    } catch (pluginError, st) {
      LoggerService.e('Plugin failure hook failed', pluginError, st);
    }
  }

  Future<PluginDownloadEvent> _buildPluginEvent(
    String id, {
    DownloadRequest? request,
    Map<String, dynamic>? sourceMetadata,
    String? error,
  }) async {
    final item = _activeDownloads[id];
    final outputDirectory = await _resolvePluginOutputDirectory(
      request ?? item?.request,
    );

    return PluginDownloadEvent(
      downloadId: id,
      url: request?.url ?? item?.request.url ?? '',
      request: request ?? item?.request,
      filePath: item?.filePath,
      title: item?.title,
      source: item?.source ?? _extractSourceFromUrl(request?.url ?? ''),
      progress: item?.progress ?? 0.0,
      error: error ?? item?.error,
      outputDirectory: outputDirectory,
      sourceMetadata: sourceMetadata,
      existingDownloads: _activeDownloads.values
          .map(
            (download) => PluginDownloadSnapshot(
              downloadId: download.id,
              url: download.request.url,
              status: download.status.name,
              filePath: download.filePath,
              title: download.title,
            ),
          )
          .toList(),
    );
  }

  Future<String?> _resolvePluginOutputDirectory(
    DownloadRequest? request,
  ) async {
    final configured = request?.outputFolder?.trim();
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }

    return _getDownloadPath();
  }

  String _extractInitialTitle(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return 'YouTube Video';
    }
    if (url.contains('twitter.com') || url.contains('x.com')) {
      return 'Twitter Video';
    }
    if (url.contains('twitch.tv')) {
      return 'Twitch Video';
    }
    if (url.contains('tiktok.com')) {
      return 'TikTok Video';
    }
    if (url.contains('kick.com')) {
      return 'Kick Video';
    }
    // For unknown sources, derive a clean title from the URL
    return TitleCleanerService.deriveTitleFromUrl(url);
  }

  String _extractSourceFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      if (host.contains('youtube') || host.contains('youtu.be')) {
        return 'YouTube';
      }
      if (host.contains('twitter') ||
          host == 'x.com' ||
          host.endsWith('.x.com')) {
        return 'Twitter';
      }
      if (host.contains('twitch')) {
        return 'Twitch';
      }
      if (host.contains('kick')) {
        return 'Kick';
      }
      if (host.contains('tiktok')) {
        return 'TikTok';
      }
      if (host.contains('instagram')) {
        return 'Instagram';
      }
      if (host.contains('facebook') ||
          host.contains('fb.com') ||
          host.contains('fb.watch')) {
        return 'Facebook';
      }
    } catch (_) {}

    return 'Other';
  }

  String _shouldUpdateTitle(String? current, String? proposed) {
    if (proposed == null || proposed.isEmpty) return current ?? 'Video';
    if (current == null ||
        current.isEmpty ||
        current == 'Video' ||
        current.startsWith('Video ')) {
      return proposed;
    }
    // If the proposed title contains technical suffixes and current doesn't, keep current
    if (proposed.contains('.fhls') || proposed.contains('.f\\d+')) {
      if (!current.contains('.fhls') && !current.contains('.f\\d+')) {
        return current;
      }
    }
    return proposed;
  }

  @override
  Future<void> clearHistory() async {
    // Remove all non-active downloads
    final keysToRemove = <String>[];
    _activeDownloads.forEach((key, value) {
      if (value.status == DownloadStatus.completed ||
          value.status == DownloadStatus.failed ||
          value.status == DownloadStatus.canceled) {
        keysToRemove.add(key);
      }
    });

    for (final key in keysToRemove) {
      _activeDownloads.remove(key);
    }

    // Refresh the stream with the new list (or just next save relies on UI poll? UI needs push)
    // We should probably emit the full list update or let the provider poll/refresh
    // Re-emitting current items one by one might be noisy, but provider listens to stream.
    // Provider implementation is "add/update if id matches, add if not". It doesn't handle removals via stream well except logic.
    // Ideally we should have a "Sync" event or just rely on provider refreshing list manually.
    // For now, let's just save. The provider calls getCurrentDownloads() normally.
    _saveToDisk();
  }

  @override
  Future<void> exportHistory(String path) async {
    final history = _activeDownloads.values.map((e) => e.toJson()).toList();
    final jsonStr = jsonEncode(history);
    final file = File(path);
    await file.writeAsString(jsonStr);
  }

  @override
  Future<void> importHistory(String path) async {
    final file = File(path);
    if (!await file.exists()) return;

    final jsonStr = await file.readAsString();
    final List<dynamic> list = jsonDecode(jsonStr);

    bool changed = false;
    for (final map in list) {
      try {
        final item = DownloadItem.fromJson(map);
        if (!_shouldKeepPersistedItem(item)) {
          continue;
        }
        if (!_activeDownloads.containsKey(item.id)) {
          _activeDownloads[item.id] = item;
          _controller.add(item);
          changed = true;
        }
      } catch (e) {
        LoggerService.w("Failed to import history item: $e");
      }
    }

    if (changed) {
      _saveToDisk();
    }
  }

  bool _isCookieHeader(String? rawCookies) {
    if (rawCookies == null || rawCookies.isEmpty) {
      return false;
    }

    return !rawCookies.contains('\t') && rawCookies.contains('=');
  }

  bool _shouldKeepPersistedItem(DownloadItem item) {
    final filePath = item.filePath;
    if (filePath == null || filePath.isEmpty) {
      return true;
    }

    return MediaFileUtils.isVideoFile(filePath) ||
        MediaFileUtils.isAudioFile(filePath);
  }

  String? _resolveFallbackVideoPath(String? filePath) {
    if (filePath == null || filePath.isEmpty) {
      return null;
    }

    if (MediaFileUtils.isVideoFile(filePath)) {
      return filePath;
    }

    return null;
  }

  Future<void> _cleanupUnsupportedFallback(
    GalleryDlProgressEvent progress,
  ) async {
    final directoryPath = progress.directoryPath;
    if (directoryPath != null && directoryPath.isNotEmpty) {
      final directory = Directory(directoryPath);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }

    final filePath = progress.filePath;
    if (filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
