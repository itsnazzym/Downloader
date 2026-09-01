import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';
import '../../domain/entities/download_item.dart';
import '../../domain/entities/download_request.dart';
import '../../domain/enums/download_status.dart';
import '../../domain/repositories/i_downloader_repository.dart';
import '../sources/yt_dlp_source.dart';
import '../sources/gallery_dl_source.dart';
import '../sources/kick_source.dart';
import '../sources/kick/kick_hls.dart';
import '../services/library_scanner_service.dart';
import '../../../../core/logger/logger_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/duplicate_detector_service.dart';
import '../../../../core/services/disk_space_service.dart';
import '../../../../core/services/media_fingerprint_service.dart';
import '../../../../core/utils/format_utils.dart';
import '../datasources/persistence_service.dart';
import '../../../../core/services/title_cleaner_service.dart';
import '../../../../core/plugins/plugin_manager.dart';
import '../../../../core/plugins/plugin_interface.dart';
import '../../../../core/download/download_crash_recovery.dart';
import '../../../../core/download/download_path_resolver.dart';
import '../../../../core/download/download_status_guard.dart';
import '../../../../core/download/download_file_resolver.dart';
import '../../../../core/download/download_file_cleanup.dart';
import '../../../../core/download/extraction_placeholders.dart';
import '../../../../core/download/x_download_url.dart';
import '../../../../core/download/x_tweet_display_title.dart';
import '../../../../core/services/heartbeat_cookie_locator.dart';
import '../services/x_library_title_repair_service.dart';

class DownloaderRepositoryImpl implements IDownloaderRepository {
  final YtDlpSource _source;
  final GalleryDlSource _galleryDlSource;
  final PersistenceService _persistenceService;
  final LibraryScannerService _libraryScanner;
  final PluginManager _pluginManager;
  final String Function() _outputFolderGetter;
  final KickSource _kickSource;
  final MediaFingerprintService _mediaFingerprintService;

  final _controller = StreamController<DownloadItem>.broadcast();
  final _activeDownloads = <String, DownloadItem>{};
  final _fingerprintedFinalPaths = <String>{};
  final _initialDataCompleter = Completer<void>();
  Timer? _saveTimer;
  bool _xTitleRepairRunning = false;

  @override
  Future<void> get initialized => _initialDataCompleter.future;

  DownloaderRepositoryImpl(
    this._source,
    this._galleryDlSource,
    this._persistenceService,
    this._libraryScanner,
    this._pluginManager,
    this._outputFolderGetter, {
    KickSource? kickSource,
    MediaFingerprintService? mediaFingerprintService,
    Future<void> Function()? waitForLibraryScan,
  }) : _kickSource = kickSource ?? KickSource(),
       _mediaFingerprintService =
           mediaFingerprintService ??
           MediaFingerprintService(_persistenceService) {
    _loadInitialData(waitForLibraryScan: waitForLibraryScan);
  }

  Future<void> _loadInitialData({
    Future<void> Function()? waitForLibraryScan,
  }) async {
    try {
      final loaded = await _persistenceService.loadDownloads();
      final recovered = DownloadCrashRecovery.recoverList(loaded);
      final didRecover = recovered.asMap().entries.any(
        (entry) => entry.value.status != loaded[entry.key].status,
      );
      for (final item in recovered) {
        _activeDownloads[item.id] = item;
      }
      if (didRecover) {
        await _persistenceService.saveDownloads(
          _activeDownloads.values.toList(),
        );
      }
      if (!_initialDataCompleter.isCompleted) {
        _initialDataCompleter.complete();
      }

      if (waitForLibraryScan != null) {
        try {
          await waitForLibraryScan();
        } catch (e) {
          LoggerService.w('Library scan waiting for setup failed: $e');
        }
      }

      final downloadPath = _resolveDownloadPath(
        _activeDownloads.values.toList(),
      );
      if (downloadPath == null) {
        unawaited(_repairBrokenXLibraryTitles());
        return;
      }

      final fixedItems = await _libraryScanner.scanAndFix(
        _activeDownloads.values.toList(),
        downloadPath,
      );
      for (final item in fixedItems) {
        final existing = _activeDownloads[item.id];
        if (existing == null ||
            existing.status != item.status ||
            existing.filePath != item.filePath ||
            existing.thumbnailUrl != item.thumbnailUrl ||
            existing.title != item.title) {
          _activeDownloads[item.id] = item;
          _controller.add(item);
        }
      }

      await _scanLibrary(downloadPath);
      _saveToDisk();
      unawaited(_repairBrokenXLibraryTitles());
    } catch (e) {
      LoggerService.e('Failed to load initial download data', e);
    } finally {
      if (!_initialDataCompleter.isCompleted) {
        _initialDataCompleter.complete();
      }
    }
  }

  Future<void> _repairBrokenXLibraryTitles() async {
    if (_xTitleRepairRunning) return;
    _xTitleRepairRunning = true;
    try {
      final service = XLibraryTitleRepairService(
        fetchMetadata:
            (permalink, {String? cookiesFilePath, String? rawCookies}) async {
              try {
                final heartbeat = await HeartbeatCookieLocator.pathForUrl(
                  permalink,
                );
                final cookiePath = (heartbeat != null && heartbeat.isNotEmpty)
                    ? heartbeat
                    : cookiesFilePath;
                return await _source.fetchMetadata(
                  permalink,
                  cookies: rawCookies,
                  cookiesFilePath: cookiePath,
                );
              } catch (e) {
                LoggerService.w('X library title repair metadata failed: $e');
                return null;
              }
            },
      );

      await service.repairItems(
        _activeDownloads.values.toList(),
        shouldAbort: () => _controller.isClosed,
        onItemRepaired: (repaired) {
          if (_controller.isClosed) return;
          final current = _activeDownloads[repaired.id];
          if (current == null) return;
          if (current.status == DownloadStatus.extracting ||
              current.status == DownloadStatus.downloading ||
              current.status == DownloadStatus.processing) {
            return;
          }
          _update(
            current.copyWith(
              title: repaired.title,
              filePath: repaired.filePath,
              request: repaired.request,
              thumbnailUrl: repaired.thumbnailUrl,
            ),
          );
        },
      );
    } catch (e) {
      LoggerService.w('X library title repair failed: $e');
    } finally {
      _xTitleRepairRunning = false;
    }
  }

  String? _resolveDownloadPath([List<DownloadItem>? items]) {
    final sourceItems = items ?? _activeDownloads.values.toList();
    return DownloadPathResolver.resolve(
      settingsOutputFolder: _outputFolderGetter(),
      itemFolders: sourceItems
          .map((item) => item.request.outputFolder ?? '')
          .toList(),
      userProfile: Platform.isWindows
          ? Platform.environment['USERPROFILE']
          : null,
    );
  }

  Future<String?> _getDownloadPath() async {
    return _resolveDownloadPath();
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
    final keptIds = fixedItems.map((item) => item.id).toSet();
    _activeDownloads.removeWhere((id, _) => !keptIds.contains(id));

    // 4. Scan for new files
    await _scanLibrary(downloadPath);
    _saveToDisk();
    unawaited(_repairBrokenXLibraryTitles());

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
    if (request.url.contains('kick.com') && !request.maxSpeedMode) {
      effectiveRequest = request.copyWith(concurrentFragments: 64);
    }

    String initialTitle = _extractInitialTitle(effectiveRequest.url);
    if (ExtractionPlaceholders.isGenericTitle(initialTitle)) {
      initialTitle = '';
    }
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
      status: DownloadStatus.extracting,
    );
    _update(item);

    unawaited(_startDownloadProcess(id, effectiveRequest));
    return id;
  }

  Future<void> _startDownloadProcess(String id, DownloadRequest request) async {
    int retryCount = 0;
    const maxRetries = 3;

    Future<void> run() async {
      File? tempCookiesFile;
      try {
        final prepared = await _prepareCookieFile(id, request);
        DownloadRequest currentRequest = prepared.request;
        tempCookiesFile = prepared.tempFile;

        while (retryCount < maxRetries) {
          if (_activeDownloads[id]?.status == DownloadStatus.canceled ||
              _activeDownloads[id]?.status == DownloadStatus.paused) {
            return;
          }

          try {
            // 2. Pre-flight Check: Disk Space
            if (retryCount == 0) {
              await DiskSpaceService.checkDiskSpace(
                currentRequest.outputFolder ?? _outputFolderGetter(),
              );
            }

            // 3. Status Update
            if (retryCount > 0) {
              _update(
                _activeDownloads[id]!.copyWith(
                  status: DownloadStatus.extracting,
                  speed: 'Retry ${retryCount + 1}/$maxRetries...',
                ),
              );
              await Future.delayed(const Duration(seconds: 5));
              if (!DownloadStatusGuard.shouldRetryAfterError(
                _activeDownloads[id]?.status,
              )) {
                return;
              }
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
            KickResolvedStream? kickStream;

            if (KickPageRef.isKickHost(currentRequest.url) &&
                (currentRequest.forceStreamUrl == null ||
                    currentRequest.forceStreamUrl!.isEmpty)) {
              try {
                kickStream = await _kickSource.resolve(
                  currentRequest.url,
                  cookies: currentRequest.rawCookies,
                );
              } catch (e) {
                LoggerService.w('Kick HLS resolve failed: $e');
              }
              if (kickStream != null) {
                LoggerService.i(
                  'Kick HLS resolved: ${kickStream.masterPlaylistUrl}',
                );
                currentRequest = currentRequest.copyWith(
                  forceStreamUrl: kickStream.playlistFor(
                    formatId: currentRequest.videoFormatId,
                  ),
                  forceThumbnailUrl: kickStream.thumbnailUrl,
                );
                if (kickStream.title != null && kickStream.title!.isNotEmpty) {
                  finalTitle = TitleCleanerService.clean(kickStream.title!);
                }
                finalThumbnail = kickStream.thumbnailUrl ?? finalThumbnail;
              }
            }

            try {
              if (kickStream != null) {
                final videoId = kickStream.videoId;
                _update(
                  _activeDownloads[id]!.copyWith(
                    title: finalTitle,
                    thumbnailUrl: finalThumbnail,
                  ),
                );
                if (videoId != null && videoId.isNotEmpty) {
                  final cleanId = videoId.replaceAll(
                    RegExp(r'[<>:"/\\|?*]'),
                    '',
                  );
                  final stem = TitleCleanerService.filenameStem(finalTitle);
                  currentRequest = currentRequest.copyWith(
                    customFilename: '$stem [$cleanId].%(ext)s',
                  );
                } else {
                  final urlHash = currentRequest.url.hashCode.toRadixString(36);
                  final stem = TitleCleanerService.filenameStem(finalTitle);
                  currentRequest = currentRequest.copyWith(
                    customFilename: '$stem [$urlHash].%(ext)s',
                  );
                }
              } else {
                final metadata = await _source.fetchMetadata(
                  currentRequest.url,
                  cookies: currentRequest.rawCookies,
                  cookiesFilePath: currentRequest.cookiesFilePath,
                  cookieBrowser: currentRequest.cookieBrowser,
                  useTorProxy: currentRequest.useTorProxy,
                );
                final String? fetchedTitle = metadata['title'];
                finalThumbnail = metadata['thumbnail'];
                final String? videoId = metadata['id'];

                // Platform-specific title logic...
                if (XDownloadUrl.isXFamilyUrl(currentRequest.url) ||
                    currentRequest.url.contains('twitter.com') ||
                    currentRequest.url.contains('x.com')) {
                  finalTitle = XTweetDisplayTitle.fromMetadata(
                    metadata,
                    tweetId: (videoId != null && videoId.isNotEmpty)
                        ? videoId
                        : (XDownloadUrl.tweetIdFrom(currentRequest.url) ?? ''),
                  );
                } else if (fetchedTitle != null &&
                    fetchedTitle.isNotEmpty &&
                    fetchedTitle != 'null' &&
                    fetchedTitle != videoId) {
                  finalTitle = fetchedTitle;
                }

                // URL-only titles on any platform → derive from URL / id
                if (TitleCleanerService.isUrlOnlyTitle(finalTitle)) {
                  if (videoId != null && videoId.isNotEmpty) {
                    finalTitle = 'Video $videoId';
                  } else {
                    finalTitle = TitleCleanerService.deriveTitleFromUrl(
                      currentRequest.url,
                    );
                  }
                }

                finalTitle = TitleCleanerService.clean(finalTitle);
                // Guard: clean() can empty a URL-only title
                if (finalTitle.isEmpty) {
                  finalTitle = videoId != null && videoId.isNotEmpty
                      ? 'Video $videoId'
                      : TitleCleanerService.deriveTitleFromUrl(
                          currentRequest.url,
                        );
                }
                _update(
                  _activeDownloads[id]!.copyWith(
                    title: finalTitle,
                    thumbnailUrl: finalThumbnail,
                  ),
                );

                // Build filename with unique ID to prevent false duplicates
                // e.g. "My Video [abc123].mp4" instead of "My Video.mp4"
                if (videoId != null && videoId.isNotEmpty) {
                  final cleanId = videoId.replaceAll(
                    RegExp(r'[<>:"/\\|?*]'),
                    '',
                  );
                  final stem = TitleCleanerService.filenameStem(finalTitle);
                  currentRequest = currentRequest.copyWith(
                    customFilename: '$stem [$cleanId].%(ext)s',
                  );
                } else {
                  // No ID available — derive a short hash from the URL as unique suffix
                  final urlHash = currentRequest.url.hashCode.toRadixString(36);
                  final stem = TitleCleanerService.filenameStem(finalTitle);
                  currentRequest = currentRequest.copyWith(
                    customFilename: '$stem [$urlHash].%(ext)s',
                  );
                }
              }
            } catch (e) {
              LoggerService.w(
                'Metadata extraction failed (retry possible): $e',
              );
              if (DownloadStatusGuard.isNonRetryableError(e)) {
                throw Exception(
                  DownloadStatusGuard.userFacingDownloadErrorMessage(e),
                );
              }
              if (retryCount < maxRetries - 1) {
                retryCount++;
                continue;
              }
              if (ExtractionPlaceholders.isGenericTitle(finalTitle) ||
                  finalTitle.isEmpty) {
                finalTitle = TitleCleanerService.deriveTitleFromUrl(
                  currentRequest.url,
                );
              }
              currentRequest = currentRequest.copyWith(
                customFilename: _uniqueFilename(
                  finalTitle,
                  XDownloadUrl.tweetIdFrom(currentRequest.url),
                  currentRequest.url,
                ),
              );
            }

            // 5. Download Execution
            _update(
              _activeDownloads[id]!.copyWith(
                status: DownloadStatus.downloading,
              ),
            );

            await for (final progress in _source.download(id, currentRequest)) {
              if (!DownloadStatusGuard.shouldRetryAfterError(
                _activeDownloads[id]?.status,
              )) {
                return;
              }
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

              final step = progress.step;
              final isProcessing =
                  step.toLowerCase().contains('merg') ||
                  step.toLowerCase().contains('ffmpeg') ||
                  step.toLowerCase().contains('recode');
              _update(
                _activeDownloads[id]!.copyWith(
                  progress: progress.progress >= 0
                      ? progress.progress
                      : _activeDownloads[id]!.progress,
                  eta: progress.eta,
                  speed: progress.speed,
                  totalSize: progress.totalSize.isNotEmpty
                      ? progress.totalSize
                      : _activeDownloads[id]!.totalSize,
                  downloadedSize: progress.downloadedSize.isNotEmpty
                      ? progress.downloadedSize
                      : _activeDownloads[id]!.downloadedSize,
                  step: progress.step,
                  status: isProcessing
                      ? DownloadStatus.processing
                      : DownloadStatus.downloading,
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
              _withCompletedFileSize(
                _activeDownloads[id]!.copyWith(
                  status: DownloadStatus.completed,
                  progress: 1.0,
                  speed: 'Terminé',
                  clearError: true,
                ),
              ),
            );
            // 7. Plugin Processing
            try {
              final pluginResult = await _pluginManager.onDownloadComplete(
                PluginDownloadEvent(
                  downloadId: id,
                  url: currentRequest.url,
                  filePath: _activeDownloads[id]!.filePath,
                  title: _activeDownloads[id]!.title,
                  source: _activeDownloads[id]!.source,
                  progress: 1.0,
                ),
              );

              if (pluginResult != null) {
                _update(
                  _withCompletedFileSize(
                    _activeDownloads[id]!.copyWith(
                      filePath:
                          pluginResult.newFilePath ??
                          _activeDownloads[id]!.filePath,
                      title:
                          pluginResult.newTitle ?? _activeDownloads[id]!.title,
                    ),
                  ),
                );
              }
            } catch (pluginError) {
              LoggerService.e('Plugin processing failed', pluginError);
            }

            final isDuplicate = await _deduplicateFinalFile(id);
            if (!isDuplicate &&
                _activeDownloads[id]?.status == DownloadStatus.completed) {
              unawaited(
                NotificationService().showDownloadComplete(
                  _activeDownloads[id]!.title ?? 'Download Complete',
                ),
              );
            }

            // Note: stats recording is handled by the provider layer
            return;
          } catch (e) {
            if (e.toString().contains('Low Disk Space')) rethrow;
            if (DownloadStatusGuard.isNonRetryableError(e)) {
              throw Exception(
                DownloadStatusGuard.userFacingDownloadErrorMessage(e),
              );
            }
            if (!DownloadStatusGuard.shouldRetryAfterError(
              _activeDownloads[id]?.status,
            )) {
              return;
            }

            retryCount++;
            LoggerService.e('Download try $retryCount failed: $e');
            if (retryCount >= maxRetries) rethrow;
          }
        }
      } catch (e, st) {
        LoggerService.e('Download $id FATAL ERROR', e, st);
        if (!DownloadStatusGuard.shouldRetryAfterError(
          _activeDownloads[id]?.status,
        )) {
          return;
        }
        if (GalleryDlSource.shouldUseFallback(request.url)) {
          try {
            await _tryGalleryDlFallback(id, request);
            return;
          } catch (ge) {
            LoggerService.w('Gallery DL fallback failed: $ge');
          }
        }
        _markDownloadFailed(id, e);
      } finally {
        if (tempCookiesFile?.existsSync() ?? false) {
          tempCookiesFile?.deleteSync();
        }
      }
    }

    unawaited(run());
  }

  Future<({DownloadRequest request, File? tempFile})> _prepareCookieFile(
    String id,
    DownloadRequest request,
  ) async {
    if (request.rawCookies == null || request.rawCookies!.isEmpty) {
      return (request: request, tempFile: null);
    }
    final isHeader =
        !request.rawCookies!.contains('\t') &&
        request.rawCookies!.contains('=');
    if (isHeader) {
      return (request: request, tempFile: null);
    }
    try {
      final tempFile = File('${Directory.systemTemp.path}/md_cookies_$id.txt');
      await tempFile.writeAsString(request.rawCookies!);
      return (
        request: request.copyWith(
          cookiesFilePath: tempFile.path,
          clearRawCookies: true,
        ),
        tempFile: tempFile,
      );
    } catch (e) {
      LoggerService.w('Failed to create temp cookies file: $e');
      return (request: request, tempFile: null);
    }
  }

  String _uniqueFilename(String title, String? videoId, String url) {
    final unique = (videoId != null && videoId.isNotEmpty)
        ? videoId.replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        : url.hashCode.toRadixString(36);
    final stem = TitleCleanerService.filenameStem(title);
    return '$stem [$unique].%(ext)s';
  }

  void _markDownloadFailed(String id, Object error) {
    final item = _activeDownloads[id];
    if (item == null) return;
    final message = DownloadStatusGuard.userFacingDownloadErrorMessage(error);
    _update(item.copyWith(status: DownloadStatus.failed, error: message));
    unawaited(
      NotificationService().showDownloadFailed(
        item.title ?? 'Download Failed',
        message,
      ),
    );
  }

  Future<void> _tryGalleryDlFallback(String id, DownloadRequest request) async {
    _update(_activeDownloads[id]!.copyWith(status: DownloadStatus.downloading));
    await for (final progress in _galleryDlSource.download(id, request)) {
      if (progress.isComplete) {
        _update(
          _withCompletedFileSize(
            _activeDownloads[id]!.copyWith(
              status: DownloadStatus.completed,
              progress: 1.0,
              speed: 'Terminé',
              clearError: true,
              title: progress.title ?? _activeDownloads[id]?.title ?? 'Unknown',
              filePath: progress.filePath ?? _activeDownloads[id]?.filePath,
            ),
          ),
        );
        await _deduplicateFinalFile(id);
      } else {
        _update(
          _activeDownloads[id]!.copyWith(
            speed: progress.status,
            title:
                progress.title ??
                _activeDownloads[id]?.title ??
                'Processing...',
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
    await _source.cancel(id);

    final item = _activeDownloads[id];
    if (item != null && item.filePath != null) {
      await DownloadFileCleanup.deleteMediaAndSidecars(item.filePath!);
    }

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
    final current = _activeDownloads[id];
    if (current == null) return;
    if (current.status == DownloadStatus.downloading ||
        current.status == DownloadStatus.extracting ||
        current.status == DownloadStatus.processing) {
      return;
    }
    _update(current.copyWith(status: DownloadStatus.extracting, error: null));
    unawaited(_startDownloadProcess(id, current.request));
  }

  void _update(DownloadItem item) {
    _activeDownloads[item.id] = item;
    _controller.add(item);
    _saveToDisk();
  }

  void _saveToDisk() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(
        _persistenceService.saveDownloads(_activeDownloads.values.toList()),
      );
    });
  }

  @override
  Future<Map<String, dynamic>> fetchMetadata(
    String url, {
    String? cookies,
  }) async {
    if (KickPageRef.isKickHost(url)) {
      try {
        final resolved = await _kickSource.resolve(url, cookies: cookies);
        if (resolved != null) {
          return resolved.toYtDlpMetadata();
        }
      } catch (e) {
        LoggerService.w(
          'Kick metadata resolve failed, falling back to yt-dlp: $e',
        );
      }
    }
    return _source.fetchMetadata(url, cookies: cookies);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPlaylist(String url) async {
    return _source.fetchPlaylist(url);
  }

  String _extractInitialTitle(String url) {
    return ExtractionPlaceholders.titleForUrl(url);
  }

  String _shouldUpdateTitle(String? current, String? proposed) {
    if (proposed == null || proposed.isEmpty) return current ?? 'Video';
    if (ExtractionPlaceholders.isGenericTitle(current)) {
      return proposed;
    }
    // If the proposed title contains technical suffixes and current doesn't, keep current
    if (proposed.contains('.fhls') || proposed.contains('.f\\d+')) {
      if (!current!.contains('.fhls') && !current.contains('.f\\d+')) {
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

  /// Prefer the real on-disk length once a download is finished.
  DownloadItem _withCompletedFileSize(DownloadItem item) {
    final size = DownloadFileResolver.formattedFileSize(item.filePath);
    if (size == null) return item;
    return item.copyWith(totalSize: size, downloadedSize: size);
  }

  /// Removes only a newly-created file after its exact SHA-256 match is
  /// confirmed against a still-valid indexed original.
  Future<bool> _deduplicateFinalFile(String id) async {
    final item = _activeDownloads[id];
    final filePath = item?.filePath;
    if (item == null || filePath == null || filePath.isEmpty) {
      return false;
    }

    final file = File(filePath);
    try {
      if (!await file.exists()) {
        LoggerService.w(
          'Skipping fingerprint: final file is unavailable: $filePath',
        );
        return false;
      }
      final normalizedPath = file.absolute.path;
      if (!_fingerprintedFinalPaths.add(normalizedPath)) {
        return false;
      }

      final duplicate = await _mediaFingerprintService.findDuplicateOrRegister(
        filePath,
      );
      if (duplicate == null) {
        return false;
      }

      // Hashing confirmed the duplicate. Do not update the status unless the
      // verified newly-created file was actually deleted.
      if (!await file.exists()) {
        return false;
      }
      await file.delete();
      _update(
        item.copyWith(
          status: DownloadStatus.duplicate,
          progress: 1.0,
          speed: 'Doublon',
          clearError: true,
        ),
      );
      LoggerService.i(
        'Removed exact duplicate $filePath; kept ${duplicate.originalPath}',
      );
      return true;
    } catch (error, stackTrace) {
      LoggerService.e(
        'Post-download fingerprint failed; keeping file $filePath',
        error,
        stackTrace,
      );
      return false;
    }
  }
}
