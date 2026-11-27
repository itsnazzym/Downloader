import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';
import '../../domain/entities/download_item.dart';
import '../../domain/entities/download_request.dart';
import '../../domain/enums/download_status.dart';
import '../../domain/repositories/i_downloader_repository.dart';
import '../../domain/exceptions/yt_dlp_exception.dart';
import '../sources/fallback_media_resolver.dart';
import '../sources/yt_dlp_source.dart';
import '../sources/gallery_dl_source.dart';
import '../sources/tiktok_photo_post_source.dart';
import '../sources/kick_source.dart';
import '../sources/kick/kick_hls.dart';
import '../services/library_scanner_service.dart';
import '../../../../core/logger/logger_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/disk_space_service.dart';
import '../../../../core/services/media_fingerprint_service.dart';
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
import '../../../../core/download/metadata_probe_limiter.dart';
import '../../../../core/download/site_backoff.dart';
import '../../../../core/services/heartbeat_cookie_locator.dart';
import '../services/x_library_title_repair_service.dart';

class DownloaderRepositoryImpl implements IDownloaderRepository {
  final YtDlpSource _source;
  final GalleryDlSource _galleryDlSource;
  final PersistenceService _persistenceService;
  final LibraryScannerService _libraryScanner;
  final PluginManager _pluginManager;
  final String Function() _outputFolderGetter;
  final bool Function() _useTorProxyGetter;

  /// Throws to refuse a download before it starts (e.g. Wi-Fi only on mobile
  /// data). Checked once per download, before the disk-space check.
  final Future<void> Function()? _networkPreflight;
  final SiteBackoff _siteBackoff;
  final TikTokPhotoPostSource _photoPosts;
  final Future<void> Function(Duration) _sleep;

  /// Used when yt-dlp cannot read a link (X posts that need a login, players
  /// without an extractor): finds a direct stream instead.
  final FallbackMediaResolver _fallbackResolver;
  final KickSource _kickSource;
  final MediaFingerprintService _mediaFingerprintService;

  final _controller = StreamController<DownloadItem>.broadcast();
  final _activeDownloads = <String, DownloadItem>{};
  final _fingerprintedFinalPaths = <String>{};
  final _initialDataCompleter = Completer<void>();
  Timer? _saveTimer;
  Timer? _backgroundLibrarySyncTimer;
  bool _saveInFlight = false;
  bool _saveRequested = false;
  Future<void>? _librarySyncFuture;
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
    bool Function()? useTorProxyGetter,
    MediaFingerprintService? mediaFingerprintService,
    Future<void> Function()? waitForLibraryScan,
    Future<void> Function()? networkPreflight,
    FallbackMediaResolver? fallbackResolver,
    SiteBackoff? siteBackoff,
    Future<void> Function(Duration)? sleep,
    TikTokPhotoPostSource? photoPostSource,
  }) : _networkPreflight = networkPreflight,
       _siteBackoff = siteBackoff ?? SiteBackoff(),
       _photoPosts = photoPostSource ?? TikTokPhotoPostSource(),
       _sleep = sleep ?? Future<void>.delayed,
       _fallbackResolver = fallbackResolver ?? FallbackMediaResolver(),
       _kickSource = kickSource ?? KickSource(),
       _useTorProxyGetter = useTorProxyGetter ?? (() => false),
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

      // The persisted history is available before this point. Do not compete
      // with first render and startup services for disk I/O.
      _backgroundLibrarySyncTimer?.cancel();
      _backgroundLibrarySyncTimer = Timer(const Duration(seconds: 10), () {
        unawaited(() async {
          try {
            await _synchronizeLibrary(downloadPath);
          } catch (e) {
            LoggerService.e('Background library scan failed', e);
          }
        }());
      });
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
                  useTorProxy: _useTorProxyGetter(),
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
      fallbackFolder: Platform.isAndroid
          ? '/storage/emulated/0/Download/ModernDownloader'
          : null,
    );
  }

  Future<String?> _getDownloadPath() async {
    return _resolveDownloadPath();
  }

  Future<void> _synchronizeLibrary(String downloadPath) {
    final inFlight = _librarySyncFuture;
    if (inFlight != null) return inFlight;

    late final Future<void> run;
    run = _runLibrarySynchronization(downloadPath).whenComplete(() {
      if (identical(_librarySyncFuture, run)) {
        _librarySyncFuture = null;
      }
    });
    _librarySyncFuture = run;
    return run;
  }

  Future<void> _runLibrarySynchronization(String downloadPath) async {
    final snapshot = Map<String, DownloadItem>.of(_activeDownloads);
    final scanResult = await _libraryScanner.scanLibrary(
      snapshot.values.toList(),
      downloadPath,
    );
    // The scan can take seconds: only touch entries still exactly as scanned,
    // so a download that progressed, finished, started or was deleted
    // meanwhile keeps its live state.
    bool unchangedSinceSnapshot(String id) {
      final live = _activeDownloads[id];
      return live != null && identical(live, snapshot[id]);
    }

    final fixedItems = scanResult.fixedItems;
    var hasChanges = false;
    for (final item in fixedItems) {
      if (!unchangedSinceSnapshot(item.id)) continue;
      final existing = _activeDownloads[item.id]!;
      if (existing.status != item.status ||
          existing.filePath != item.filePath ||
          existing.thumbnailUrl != item.thumbnailUrl ||
          existing.title != item.title ||
          existing.totalSize != item.totalSize) {
        _activeDownloads[item.id] = item;
        _controller.add(item);
        hasChanges = true;
      }
    }
    final keptIds = fixedItems.map((item) => item.id).toSet();
    final beforeCount = _activeDownloads.length;
    _activeDownloads.removeWhere(
      (id, _) => !keptIds.contains(id) && unchangedSinceSnapshot(id),
    );
    if (_activeDownloads.length != beforeCount) {
      hasChanges = true;
    }

    for (final item in scanResult.newItems) {
      _activeDownloads[item.id] = item;
      _controller.add(item);
    }

    if (hasChanges || scanResult.newItems.isNotEmpty) {
      _saveToDisk();
    }
    unawaited(_repairBrokenXLibraryTitles());
  }

  @override
  Future<void> refreshLibrary() async {
    LoggerService.i('Refreshing library...');
    final downloadPath = await _getDownloadPath();
    if (downloadPath == null) return;

    await _synchronizeLibrary(downloadPath);
    _saveToDisk();

    LoggerService.i('Library refresh complete.');
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
    // Each run owns a token: Pause then Resume starts a new run while the old
    // one may still be inside a probe or retry sleep; the old one must stop
    // instead of spawning a second yt-dlp on the same file.
    final token = (_runTokens[id] ?? 0) + 1;
    _runTokens[id] = token;
    int retryCount = 0;
    // Four tries spaced 5 s, 20 s, 80 s (see [SiteBackoff]): long enough to
    // outlast a site's short block instead of failing inside it.
    const maxRetries = 4;

    Future<void> run() async {
      File? tempCookiesFile;
      try {
        final prepared = await _prepareCookieFile(id, request);
        DownloadRequest currentRequest = prepared.request;
        tempCookiesFile = prepared.tempFile;

        while (retryCount < maxRetries) {
          if (_shouldAbort(id, token)) {
            return;
          }

          try {
            // 2. Pre-flight Check: Disk Space
            // Every attempt, not only the first: an automatic retry must not
            // start on mobile data after the Wi-Fi was lost.
            await _networkPreflight?.call();
            if (retryCount == 0) {
              await DiskSpaceService.checkDiskSpace(
                currentRequest.outputFolder ?? _outputFolderGetter(),
              );
            }

            // 3. Status Update. A retry, or any job of a site that just
            // refused, waits first: the site pause can outlast the delay.
            final retryWait = retryCount > 0
                ? _siteBackoff.retryDelay(retryCount)
                : Duration.zero;
            final siteWait = _siteBackoff.waitFor(currentRequest.url);
            final wait = siteWait > retryWait ? siteWait : retryWait;
            if (wait > Duration.zero) {
              _update(
                _activeDownloads[id]!.copyWith(
                  status: DownloadStatus.extracting,
                  speed: retryCount > 0
                      ? 'Retry ${retryCount + 1}/$maxRetries...'
                      : 'Waiting for the site...',
                ),
              );
              await _sleep(wait);
              if (!(_isCurrentRun(id, token) &&
                  DownloadStatusGuard.shouldRetryAfterError(
                    _activeDownloads[id]?.status,
                  ))) {
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
                !currentRequest.useTorProxy &&
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
              } else if (_isPreResolved(currentRequest)) {
                // Picked in the in-app browser: the stream, its name and the
                // session are already known, so nothing to look up.
                final stem = _stemOf(currentRequest.customFilename!);
                finalTitle = stem.isEmpty
                    ? TitleCleanerService.deriveTitleFromUrl(currentRequest.url)
                    : stem;
                finalThumbnail =
                    currentRequest.forceThumbnailUrl ?? finalThumbnail;
                _update(
                  _activeDownloads[id]!.copyWith(
                    title: finalTitle,
                    thumbnailUrl: finalThumbnail,
                  ),
                );
              } else {
                final metadata = await _source.fetchMetadata(
                  currentRequest.url,
                  cookies: currentRequest.rawCookies,
                  cookiesFilePath: currentRequest.cookiesFilePath,
                  cookieBrowser: currentRequest.cookieBrowser,
                  useTorProxy: currentRequest.useTorProxy,
                  isCancelled: () => _shouldAbort(id, token),
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
            } on MetadataProbeCancelledException {
              return;
            } catch (e) {
              if (_shouldAbort(id, token)) return;
              final resolved =
                  (currentRequest.useTorProxy ||
                      e is MetadataProbeLimitException)
                  ? null
                  : await _fallbackResolver.resolve(
                      currentRequest.url,
                      isCancelled: () => _shouldAbort(id, token),
                    );
              if (_shouldAbort(id, token)) return;
              if (resolved != null) {
                LoggerService.i(
                  'yt-dlp could not read the link ($e); '
                  'using a direct stream found via ${resolved.source}',
                );
                final stream = resolved.pick(currentRequest.preferredQuality);
                finalTitle = TitleCleanerService.clean(resolved.title ?? '');
                if (finalTitle.isEmpty) {
                  finalTitle = TitleCleanerService.deriveTitleFromUrl(
                    currentRequest.url,
                  );
                }
                finalThumbnail = resolved.thumbnail ?? finalThumbnail;
                _update(
                  _activeDownloads[id]!.copyWith(
                    title: finalTitle,
                    thumbnailUrl: finalThumbnail,
                    clearError: true,
                  ),
                );
                final mediaId =
                    (resolved.id ??
                            currentRequest.url.hashCode.toRadixString(36))
                        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
                currentRequest = currentRequest.copyWith(
                  forceStreamUrl: stream.url,
                  forceThumbnailUrl: resolved.thumbnail,
                  customFilename:
                      '${TitleCleanerService.filenameStem(finalTitle)} '
                      '[$mediaId].%(ext)s',
                );
              } else {
                final skipProbe = e is MetadataProbeLimitException;
                if (!skipProbe) {
                  LoggerService.w(
                    'Metadata extraction failed (retry possible): $e',
                  );
                  if (DownloadStatusGuard.isNonRetryableError(e)) {
                    rethrow;
                  }
                  if (DownloadStatusGuard.isSiteRefusal(e)) {
                    _siteBackoff.recordRefusal(currentRequest.url);
                  }
                  if (retryCount < maxRetries - 1) {
                    retryCount++;
                    continue;
                  }
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
            }

            if (_shouldAbort(id, token)) return;

            // 5. Download Execution
            _update(
              _activeDownloads[id]!.copyWith(
                status: DownloadStatus.downloading,
              ),
            );

            var alreadyDownloaded = false;
            await for (final progress in _source.download(id, currentRequest)) {
              if (!(_isCurrentRun(id, token) &&
                  DownloadStatusGuard.shouldRetryAfterError(
                    _activeDownloads[id]?.status,
                  ))) {
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

              if (progress.alreadyDownloaded) alreadyDownloaded = true;
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
            _siteBackoff.recordSuccess(currentRequest.url);
            _update(
              _withCompletedFileSize(
                _activeDownloads[id]!.copyWith(
                  status: DownloadStatus.completed,
                  progress: 1.0,
                  speed: 'Terminé',
                  clearError: true,
                  alreadyDownloaded: alreadyDownloaded,
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
            if (e is MetadataProbeCancelledException) rethrow;
            if (e.toString().contains('Low Disk Space')) rethrow;
            if (e is WifiOnlyBlockedException) rethrow;
            if (DownloadStatusGuard.isNonRetryableError(e)) {
              rethrow;
            }
            if (!(_isCurrentRun(id, token) &&
                DownloadStatusGuard.shouldRetryAfterError(
                  _activeDownloads[id]?.status,
                ))) {
              return;
            }

            if (DownloadStatusGuard.isSiteRefusal(e)) {
              _siteBackoff.recordRefusal(currentRequest.url);
            }
            retryCount++;
            LoggerService.e('Download try $retryCount failed: $e');
            if (retryCount >= maxRetries) rethrow;
          }
        }
      } catch (e, st) {
        if (e is MetadataProbeCancelledException || _shouldAbort(id, token)) {
          return;
        }
        LoggerService.e('Download $id FATAL ERROR', e, st);
        if (!(_isCurrentRun(id, token) &&
            DownloadStatusGuard.shouldRetryAfterError(
              _activeDownloads[id]?.status,
            ))) {
          return;
        }
        if (e is WifiOnlyBlockedException) {
          // Refused on purpose: no fallback downloader, and no notification
          // per item (a queued batch would raise one for each row).
          _markDownloadFailed(id, e, notify: false);
          return;
        }
        if (e is TikTokPhotoPostException && !request.audioOnly) {
          try {
            await _downloadTikTokPhotoPost(id, request);
            return;
          } catch (pe) {
            LoggerService.w('TikTok photo post failed: $pe');
          }
        }
        if (!DownloadStatusGuard.isNonRetryableError(e) &&
            GalleryDlSource.shouldUseFallback(request.url)) {
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
      return _privateCookieCopy(id, request);
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

  /// yt-dlp writes its cookie jar back to `--cookies` on exit, so parallel
  /// jobs sharing the extension's file overwrote each other's copy: each job
  /// reads its own. A file gone since the job was queued (Retry) is looked
  /// up again for the URL.
  Future<({DownloadRequest request, File? tempFile})> _privateCookieCopy(
    String id,
    DownloadRequest request,
  ) async {
    final stored = request.cookiesFilePath;
    if (stored == null || stored.isEmpty) {
      return (request: request, tempFile: null);
    }
    try {
      final source = await File(stored).exists()
          ? stored
          : await HeartbeatCookieLocator.pathForUrl(request.url);
      if (source == null) {
        return (
          request: request.copyWith(clearCookiesFilePath: true),
          tempFile: null,
        );
      }
      final copy = await File(
        source,
      ).copy('${Directory.systemTemp.path}/md_cookies_$id.txt');
      return (
        request: request.copyWith(cookiesFilePath: copy.path),
        tempFile: copy,
      );
    } catch (e) {
      LoggerService.w('Failed to copy cookies file: $e');
      return (request: request, tempFile: null);
    }
  }

  final _runTokens = <String, int>{};

  bool _isCurrentRun(String id, int token) => _runTokens[id] == token;

  bool _shouldAbort(String id, int token) {
    if (!_isCurrentRun(id, token)) return true;
    // After shutdown killed the processes, a run must not retry (it would
    // start a new, orphaned yt-dlp while the app exits).
    if (_shuttingDown) return true;
    final status = _activeDownloads[id]?.status;
    return status == DownloadStatus.canceled || status == DownloadStatus.paused;
  }

  String _uniqueFilename(String title, String? videoId, String url) {
    final unique = (videoId != null && videoId.isNotEmpty)
        ? videoId.replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        : url.hashCode.toRadixString(36);
    final stem = TitleCleanerService.filenameStem(title);
    return '$stem [$unique].%(ext)s';
  }

  static bool _isPreResolved(DownloadRequest request) {
    final stream = request.forceStreamUrl;
    final name = request.customFilename;
    return stream != null &&
        stream.isNotEmpty &&
        name != null &&
        name.isNotEmpty &&
        !KickPageRef.isKickHost(request.url);
  }

  /// "My video [abc].%(ext)s" -> "My video".
  static String _stemOf(String customFilename) {
    final cut = customFilename.indexOf(' [');
    final stem = cut > 0 ? customFilename.substring(0, cut) : customFilename;
    return stem.replaceAll('.%(ext)s', '').trim();
  }

  void _markDownloadFailed(String id, Object error, {bool notify = true}) {
    final item = _activeDownloads[id];
    if (item == null) return;
    final message = DownloadStatusGuard.userFacingDownloadErrorMessage(error);
    _update(item.copyWith(status: DownloadStatus.failed, error: message));
    if (!notify) return;
    unawaited(
      NotificationService().showDownloadFailed(
        item.title ?? 'Download Failed',
        message,
      ),
    );
  }

  /// yt-dlp has no format for a photo slideshow: it becomes one MP4.
  Future<void> _downloadTikTokPhotoPost(
    String id,
    DownloadRequest request,
  ) async {
    _update(
      _activeDownloads[id]!.copyWith(
        status: DownloadStatus.downloading,
        speed: 'Slideshow...',
      ),
    );
    final folder = await _source.outputFolderFor(request);
    final result = await _photoPosts.download(request, folder);
    _siteBackoff.recordSuccess(request.url);
    _update(
      _withCompletedFileSize(
        _activeDownloads[id]!.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
          speed: 'Terminé',
          clearError: true,
          title: result.title,
          filePath: result.filePath,
        ),
      ),
    );
    await _deduplicateFinalFile(id);
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
  Future<void> deleteDownload(String id, {bool deleteFiles = true}) async {
    await _source.cancel(id);

    final item = _activeDownloads[id];
    if (deleteFiles && item != null && item.filePath != null) {
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
    // newIndex comes from onReorderItem, already the post-removal index.
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

  DateTime _lastDiskSave = DateTime.fromMillisecondsSinceEpoch(0);

  void _update(DownloadItem item, {bool persist = false}) {
    final previous = _activeDownloads[item.id];
    _activeDownloads[item.id] = item;
    _controller.add(item);

    final statusChanged = previous == null || previous.status != item.status;
    final titleChanged = previous?.title != item.title;
    final pathChanged = previous?.filePath != item.filePath;
    final periodicSaveDue =
        DateTime.now().difference(_lastDiskSave).inSeconds >= 30;

    if (persist ||
        statusChanged ||
        titleChanged ||
        pathChanged ||
        periodicSaveDue) {
      _saveToDisk();
    }
  }

  bool _shuttingDown = false;
  Future<void>? _shutdown;
  Future<void>? _saveInFlightFuture;

  /// App exit: kills every running download's process tree (yt-dlp keeps
  /// ffmpeg/aria2c children) and writes the library as it was, so crash
  /// recovery re-queues those downloads on the next launch. Repeated calls
  /// (close then tray Exit) share the same work.
  Future<void> shutdown() => _shutdown ??= _runShutdown();

  Future<void> _runShutdown() async {
    _shuttingDown = true;
    _backgroundLibrarySyncTimer?.cancel();
    _saveTimer?.cancel();
    // Before the library is loaded the map is empty: saving it would wipe
    // the library on disk.
    await _initialDataCompleter.future;
    // One writer at a time on the library file.
    await _saveInFlightFuture;
    final snapshot = _activeDownloads.values.toList(growable: false);
    await Future.wait([
      for (final item in snapshot)
        if (DownloadCrashRecovery.isInterrupted(item.status)) ...[
          _source.cancel(item.id),
          _galleryDlSource.cancel(item.id),
        ],
    ]);
    await _persistenceService.saveDownloads(snapshot);
  }

  void _saveToDisk() {
    // After shutdown the kills make runs report failures; keep the snapshot.
    if (_shuttingDown) return;
    _saveRequested = true;
    // Coalesce, but never re-arm: progress lines arrive faster than 750 ms and
    // re-arming postponed every save until all downloads went quiet.
    if (_saveTimer?.isActive ?? false) return;
    _saveTimer = Timer(const Duration(milliseconds: 750), _flushSave);
  }

  void _flushSave() {
    if (_shuttingDown || _saveInFlight || !_saveRequested) return;
    _saveRequested = false;
    _saveInFlight = true;
    final snapshot = _activeDownloads.values.toList(growable: false);
    _saveInFlightFuture = _persistSnapshot(snapshot);
  }

  Future<void> _persistSnapshot(List<DownloadItem> snapshot) async {
    try {
      await _persistenceService.saveDownloads(snapshot);
      _lastDiskSave = DateTime.now();
    } catch (e) {
      LoggerService.e('Failed to persist download snapshot', e);
    } finally {
      _saveInFlight = false;
      if (_saveRequested && !_shuttingDown) {
        _saveTimer?.cancel();
        _saveTimer = Timer(const Duration(milliseconds: 750), _flushSave);
      }
    }
  }

  @override
  Future<Map<String, dynamic>> fetchMetadata(
    String url, {
    String? cookies,
    bool? useTorProxy,
  }) async {
    final routeThroughTor = useTorProxy ?? _useTorProxyGetter();
    if (KickPageRef.isKickHost(url) && !routeThroughTor) {
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
    return _source.fetchMetadata(
      url,
      cookies: cookies,
      useTorProxy: routeThroughTor,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPlaylist(
    String url, {
    bool? useTorProxy,
  }) async {
    return _source.fetchPlaylist(
      url,
      useTorProxy: useTorProxy ?? _useTorProxyGetter(),
    );
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
