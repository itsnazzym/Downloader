import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/download/yt_dlp_cookie_args.dart';
import '../../../../core/download/x_download_url.dart';
import '../../../../core/download/download_request_factory.dart';
import '../../../../core/download/download_queue_controller.dart';
import '../../../../core/download/download_url_policy.dart';
import '../../../../core/download/tiktok_video_url.dart';
import '../../../../core/download/download_status_guard.dart';
import '../../../archive/presentation/providers/tiktok_video_cache_provider.dart';
import '../../../../core/services/local_server_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../x_feed/x_media_identity.dart';
import '../../domain/entities/download_item.dart';
import '../../domain/entities/download_request.dart';
import '../../domain/enums/download_status.dart';
import '../../domain/repositories/i_downloader_repository.dart';
import '../../data/downloader_data_providers.dart';
import '../../../../core/services/download_stats_service.dart';
import '../../../../core/logger/logger_service.dart';
import '../../../../core/download/async_serializer.dart';
import '../../../../core/download/extension_download_batcher.dart';
import '../../../../core/download/progress_throttle.dart';

export '../../data/downloader_data_providers.dart';

// Presentation Layer - Controller
final activeDownloadsProvider = StreamProvider<DownloadItem>((ref) {
  final repo = ref.watch(downloaderRepositoryProvider);
  return repo.downloadUpdateStream;
});

final duplicateBatchCountProvider = StateProvider<int>((ref) => 0);

/// Volatile download data (progress, speed and ETA) is deliberately kept out
/// of the persisted catalog. Updating an active download must not rebuild or
/// re-sort thousands of completed rows.
final downloadRuntimeItemProvider = StateProvider.family<DownloadItem?, String>(
  (ref, id) => null,
);

/// A download that ended up being a file already on disk. The app shell shows
/// a sheet for it (open it, or download it again), then clears this.
final alreadyDownloadedProvider = StateProvider<DownloadItem?>((ref) => null);

// Notifier to hold the list state
class DownloadListNotifier
    extends StateNotifier<AsyncValue<List<DownloadItem>>> {
  final IDownloaderRepository _repository;
  final Ref _ref;

  final List<DownloadRequest> _queue = [];
  final List<String> _resumeIds = [];
  bool _isProcessingQueue = false;
  bool _processQueueAgain = false;
  final AsyncSerializer _queueOps = AsyncSerializer();
  final Map<String, DownloadItem> _catalogById = <String, DownloadItem>{};
  final List<String> _catalogIds = <String>[];
  final Set<String> _runtimeIds = <String>{};

  DownloadListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    // Yield so constructor init does not mutate other providers synchronously.
    await Future<void>.delayed(Duration.zero);
    try {
      await _repository.initialized;
      final items = _repository.getCurrentDownloads();
      final failedToPurge = items.where((item) {
        if (item.status == DownloadStatus.failed) {
          final err = (item.error ?? '').toLowerCase();
          return DownloadStatusGuard.isPermanentDownloadError(err);
        }
        return false;
      }).toList();

      for (final bad in failedToPurge) {
        unawaited(_repository.deleteDownload(bad.id));
        final videoId = TikTokVideoUrl.extractVideoId(bad.request.url);
        if (videoId != null) {
          try {
            unawaited(
              _ref
                  .read(tiktokVideoCacheServiceProvider)
                  .recordUnavailable(videoId, bad.error ?? 'Unavailable video'),
            );
          } catch (_) {}
        }
      }

      final validItems = items
          .where((item) => !failedToPurge.contains(item))
          .toList();
      _replaceCatalog(validItems);
      _ref.read(downloadStatsProvider.notifier).rebuildFromLibrary(validItems);
      _listenToUpdates();

      for (final item in items) {
        if (item.status == DownloadStatus.queued) {
          _resumeIds.add(item.id);
        }
      }

      final persistedQueue = await _ref
          .read(persistenceServiceProvider)
          .loadQueue();
      if (persistedQueue.isNotEmpty) {
        _queue.addAll(persistedQueue);
      }
      if (_resumeIds.isNotEmpty || _queue.isNotEmpty) {
        await _processQueue();
      }

      // Listen to Max Concurrent changes to auto-start pending downloads
      _ref.listen<AppSettings>(settingsProvider, (previous, next) {
        if (previous?.maxConcurrent != next.maxConcurrent) {
          _processQueue();
        }
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  final Map<String, DownloadItem> _pendingUpdates = {};
  Timer? _throttleTimer;
  Timer? _duplicateSummaryTimer;
  bool _flushMicrotaskScheduled = false;

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _duplicateSummaryTimer?.cancel();
    super.dispose();
  }

  void _listenToUpdates() {
    _repository.downloadUpdateStream.listen((item) {
      if (!mounted) return;

      // Queue the update
      _pendingUpdates[item.id] = item;

      // Terminal / queued / paused: flush at next microtask turn (coalescing rapid bursts)
      if (isImmediateFlushStatus(item.status)) {
        if (!_flushMicrotaskScheduled) {
          _flushMicrotaskScheduled = true;
          scheduleMicrotask(() {
            _flushMicrotaskScheduled = false;
            _flushUpdates();
          });
        }
      } else {
        // For progress updates (downloading/extracting), throttle
        if (_throttleTimer == null || !_throttleTimer!.isActive) {
          _throttleTimer = Timer(kProgressThrottleInterval, _flushUpdates);
        }
      }
    });
  }

  void _flushUpdates() {
    if (!mounted) return;
    if (_pendingUpdates.isEmpty) return;

    final updates = Map<String, DownloadItem>.from(_pendingUpdates);
    _pendingUpdates.clear();
    var catalogChanged = false;
    var newQueuedAdded = false;

    for (final entry in updates.entries) {
      final id = entry.key;
      final item = entry.value;
      final previous = _catalogById[id];

      // Deleting a row makes the repository emit one last `canceled` copy of
      // it. Once the row has left the catalog that echo must not bring it
      // back (it showed up as a ghost row after "Retry").
      if (previous == null && item.status == DownloadStatus.canceled) {
        continue;
      }

      if (_requiresCatalogUpdate(previous, item)) {
        if (previous == null) {
          _catalogIds.add(id);
        }
        _catalogById[id] = item;
        _clearRuntimeItem(id);
        catalogChanged = true;
      } else {
        _setRuntimeItem(id, item);
      }

      if (item.alreadyDownloaded &&
          item.status == DownloadStatus.completed &&
          previous?.alreadyDownloaded != true) {
        _ref.read(alreadyDownloadedProvider.notifier).state = item;
      }

      if (item.status == DownloadStatus.queued && !_resumeIds.contains(id)) {
        _resumeIds.add(id);
        newQueuedAdded = true;
      }

      if (item.status == DownloadStatus.duplicate) {
        Future<void>.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            deleteDownload(item.id);
          }
        });
      }

      if (item.status == DownloadStatus.failed) {
        final err = (item.error ?? '').toLowerCase();
        final isPermanentUnavail = DownloadStatusGuard.isPermanentDownloadError(
          err,
        );
        if (isPermanentUnavail &&
            (item.request.url.contains('tiktok.com') ||
                item.request.url.contains('tiktokv.com'))) {
          final videoId = TikTokVideoUrl.extractVideoId(item.request.url);
          if (videoId != null) {
            try {
              unawaited(
                _ref
                    .read(tiktokVideoCacheServiceProvider)
                    .recordUnavailable(
                      videoId,
                      item.error ?? 'Unavailable video',
                    ),
              );
            } catch (_) {}
          }
          // Remove from download list after 1s so it quickly disappears from the failed downloads tab
          Future<void>.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              deleteDownload(item.id);
            }
          });
        }
      }
    }

    if (catalogChanged) {
      state = AsyncValue.data(_catalogItems());
    }

    final hasTerminal = updates.values.any(
      (item) => isStatsRebuildStatus(item.status),
    );
    if (hasTerminal || newQueuedAdded) {
      _ref
          .read(downloadStatsProvider.notifier)
          .rebuildFromLibrary(_catalogItems());
      _processQueue();
    }
  }

  void refreshList() {
    try {
      final items = _repository.getCurrentDownloads();
      _replaceCatalog(items);
      _ref.read(downloadStatsProvider.notifier).rebuildFromLibrary(items);
      bool newQueued = false;
      for (final item in items) {
        if (item.status == DownloadStatus.queued &&
            !_resumeIds.contains(item.id)) {
          _resumeIds.add(item.id);
          newQueued = true;
        }
      }
      if (newQueued || _queue.isNotEmpty) {
        _processQueue();
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _replaceCatalog(List<DownloadItem> items) {
    for (final id in _runtimeIds.toList(growable: false)) {
      _clearRuntimeItem(id);
    }
    _catalogById
      ..clear()
      ..addEntries(items.map((item) => MapEntry(item.id, item)));
    _catalogIds
      ..clear()
      ..addAll(items.map((item) => item.id));
    state = AsyncValue.data(_catalogItems());
  }

  List<DownloadItem> _catalogItems() {
    return [
      for (final id in _catalogIds)
        if (_catalogById[id] case final item?) item,
    ];
  }

  bool _requiresCatalogUpdate(DownloadItem? previous, DownloadItem next) {
    if (previous == null) return true;
    return previous.status != next.status ||
        previous.title != next.title ||
        previous.filePath != next.filePath ||
        previous.thumbnailUrl != next.thumbnailUrl ||
        previous.totalSize != next.totalSize ||
        previous.sortOrder != next.sortOrder ||
        previous.error != next.error ||
        previous.request.url != next.request.url ||
        previous.request.outputFolder != next.request.outputFolder;
  }

  void _removeCatalogItem(String id) {
    if (!_catalogById.containsKey(id)) return;
    _catalogById.remove(id);
    _catalogIds.remove(id);
    _clearRuntimeItem(id);
    state = AsyncValue.data(_catalogItems());
  }

  void _setRuntimeItem(String id, DownloadItem item) {
    _runtimeIds.add(id);
    _ref.read(downloadRuntimeItemProvider(id).notifier).state = item;
  }

  void _clearRuntimeItem(String id) {
    _runtimeIds.remove(id);
    _ref.read(downloadRuntimeItemProvider(id).notifier).state = null;
  }

  Future<void> resumeAllQueued() async {
    final items = state.valueOrNull ?? _repository.getCurrentDownloads();
    for (final item in items) {
      if ((item.status == DownloadStatus.queued ||
              item.status == DownloadStatus.paused ||
              item.status == DownloadStatus.failed) &&
          !_resumeIds.contains(item.id)) {
        _resumeIds.add(item.id);
      }
    }
    await _processQueue();
  }

  Future<void> refreshLibrary() async {
    await _repository.refreshLibrary();
    refreshList();
  }

  Future<void> startDownload(
    String url, {
    String? rawCookies,
    String? videoFormatId,
    String? userAgent,
    String? cookiesFilePath,
    bool? organizeBySite,
    bool? organizeByCreator,
    String? cookieBrowser,
    bool? audioOnly,
    String? preferredQuality,
    String? forceStreamUrl,
    String? customFilename,
    String? forceThumbnailUrl,
  }) async {
    final resolved = XDownloadUrl.resolveForDownload(url);
    final resolvedUrl = resolved == null
        ? null
        : TikTokVideoUrl.forDownload(resolved);
    if (resolvedUrl == null) {
      LoggerService.w(
        'Rejected X CDN download without a tweet permalink: $url',
      );
      await NotificationService().showError(
        'Need tweet link',
        'Paste the tweet link (x.com/.../status/...), not the video file.',
      );
      return;
    }

    final settings = _ref.read(settingsProvider);
    if (!DownloadUrlPolicy.isAllowed(
      resolvedUrl,
      includeAdult: settings.adultSitesEnabled,
    )) {
      LoggerService.w('Rejected unsupported download URL: $resolvedUrl');
      await _notifyUnsupportedUrl();
      return;
    }
    final heartbeatCookies = await LocalServerService.heartbeatCookiePathForUrl(
      resolvedUrl,
    );
    final explicitOrGlobal =
        (cookiesFilePath != null && cookiesFilePath.trim().isNotEmpty)
        ? cookiesFilePath
        : settings.cookiesFilePath;
    // Host-specific heartbeat cookies win over the global settings file so a
    // YouTube cookie dump is not used for Twitter/X (and vice versa).
    final resolvedCookiesPath = YtDlpCookieArgs.resolveCookiesFilePath(
      urlSpecificPath: heartbeatCookies,
      globalPath: explicitOrGlobal,
    );

    var request = DownloadRequestFactory.fromSettings(
      settings: settings,
      url: resolvedUrl,
      cookiesFilePath: resolvedCookiesPath,
      rawCookies: rawCookies,
      userAgent: userAgent,
      videoFormatId: videoFormatId,
      cookieBrowser: cookieBrowser,
      organizeBySite: organizeBySite,
      organizeByCreator: organizeByCreator,
      audioOnly: audioOnly,
      preferredQuality: preferredQuality,
    );
    // A stream picked in the in-app browser: [url] stays the page (referer,
    // site folder) and the stream is fetched directly.
    if (forceStreamUrl != null && forceStreamUrl.isNotEmpty) {
      request = request.copyWith(
        forceStreamUrl: forceStreamUrl,
        forceThumbnailUrl: forceThumbnailUrl,
        customFilename: customFilename,
      );
    }

    await _queueOps.run(() async {
      if (_isDuplicateRequest(request)) {
        _markDuplicate(request);
        return;
      }

      _queue.add(request);
      await _persistQueue();
      await _processQueue();
    });
  }

  /// Queues a TikTok video through the normal downloader and waits for its
  /// finished file in the configured output folder. This keeps archive playback
  /// subject to the same settings, duplicate checks, and library indexing as a
  /// regular download.
  Future<String?> downloadTikTokToOutput(
    String videoId,
    String url, {
    required void Function(double progress) onProgress,
    Duration timeout = const Duration(minutes: 20),
  }) async {
    List<DownloadItem> matchingItems() {
      try {
        return _repository
            .getCurrentDownloads()
            .where((item) => _tiktokVideoIdFromUrl(item.request.url) == videoId)
            .toList(growable: false);
      } catch (_) {
        return const <DownloadItem>[];
      }
    }

    bool hasOutput(DownloadItem item) {
      final path = item.filePath;
      if (item.status != DownloadStatus.completed ||
          path == null ||
          path.isEmpty) {
        return false;
      }
      try {
        return File(path).existsSync();
      } catch (_) {
        return false;
      }
    }

    DownloadItem? completedOutput(Iterable<DownloadItem> items) {
      for (final item in items) {
        if (hasOutput(item)) return item;
      }
      return null;
    }

    final before = matchingItems();
    final previousIds = before.map((item) => item.id).toSet();
    final existingOutput = completedOutput(before);
    if (existingOutput != null) return existingOutput.filePath;

    bool isPending(DownloadStatus status) =>
        status == DownloadStatus.queued ||
        status == DownloadStatus.extracting ||
        status == DownloadStatus.downloading ||
        status == DownloadStatus.processing ||
        status == DownloadStatus.paused;

    var targetIds = before
        .where((item) => isPending(item.status))
        .map((item) => item.id)
        .toSet();
    var waitingForNewRequest = false;
    if (targetIds.isEmpty) {
      await startDownload(url, organizeBySite: true);
      final after = matchingItems();
      targetIds = after
          .where(
            (item) =>
                !previousIds.contains(item.id) &&
                item.status != DownloadStatus.duplicate,
          )
          .map((item) => item.id)
          .toSet();
      if (targetIds.isEmpty) {
        final output = completedOutput(after);
        if (output != null) return output.filePath;
        targetIds = after
            .where((item) => isPending(item.status))
            .map((item) => item.id)
            .toSet();
        waitingForNewRequest = targetIds.isEmpty;
      }
    }

    final deadline = DateTime.now().add(timeout);
    final queuedWaitStartedAt = DateTime.now();
    var lastProgress = -1.0;
    while (DateTime.now().isBefore(deadline)) {
      var current = matchingItems()
          .where(
            (item) => targetIds.isNotEmpty
                ? targetIds.contains(item.id) &&
                      item.status != DownloadStatus.duplicate
                : !previousIds.contains(item.id) &&
                      item.status != DownloadStatus.duplicate,
          )
          .toList(growable: false);
      if (waitingForNewRequest && current.isEmpty) {
        final requestStillQueued = _queue.any(
          (request) => _tiktokVideoIdFromUrl(request.url) == videoId,
        );
        if (!requestStillQueued &&
            DateTime.now().difference(queuedWaitStartedAt) >
                const Duration(seconds: 30)) {
          throw StateError(
            'Le téléchargement n’a pas pu être ajouté à la file.',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 650));
        continue;
      }
      if (waitingForNewRequest && current.isNotEmpty) {
        targetIds = current.map((item) => item.id).toSet();
        waitingForNewRequest = false;
      }
      final completed = completedOutput(current);
      if (completed != null) return completed.filePath;

      final latest = current.isEmpty ? null : current.last;
      if (latest != null) {
        if (latest.progress != lastProgress) {
          lastProgress = latest.progress;
          onProgress(latest.progress.clamp(0.05, 0.99).toDouble());
        }
        if (latest.status == DownloadStatus.failed ||
            latest.status == DownloadStatus.canceled) {
          throw StateError(
            latest.error?.trim().isNotEmpty == true
                ? latest.error!.trim()
                : 'Le téléchargement TikTok a échoué.',
          );
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 650));
    }
    throw TimeoutException('Le téléchargement TikTok prend trop de temps.');
  }

  Future<void> startDownloadsBatch(List<String> urls) {
    return startExtensionDownloads([
      for (final url in urls) ExtensionDownloadIngest(url: url),
    ]);
  }

  Future<void> startExtensionDownloads(
    List<ExtensionDownloadIngest> items,
  ) async {
    if (items.isEmpty) return;
    await _queueOps.run(() async {
      final settings = _ref.read(settingsProvider);
      final batchKeys = <String>{};
      final cookiePathByHost = <String, String?>{};
      var skippedDuplicates = 0;
      var rejectedUnsupported = 0;
      var queued = 0;

      for (final item in items) {
        final resolvedUrl = XDownloadUrl.resolveForDownload(item.url);
        if (resolvedUrl == null) {
          LoggerService.w(
            'Rejected X CDN download without a tweet permalink: ${item.url}',
          );
          continue;
        }
        if (!DownloadUrlPolicy.isAllowed(
          resolvedUrl,
          includeAdult: settings.adultSitesEnabled,
        )) {
          rejectedUnsupported++;
          LoggerService.w('Rejected unsupported download URL: $resolvedUrl');
          continue;
        }
        String? heartbeatCookies;
        try {
          final host = Uri.parse(resolvedUrl).host;
          if (cookiePathByHost.containsKey(host)) {
            heartbeatCookies = cookiePathByHost[host];
          } else {
            heartbeatCookies =
                await LocalServerService.heartbeatCookiePathForUrl(resolvedUrl);
            cookiePathByHost[host] = heartbeatCookies;
          }
        } catch (e) {
          LoggerService.w('Heartbeat cookie lookup failed: $e');
          heartbeatCookies = await LocalServerService.heartbeatCookiePathForUrl(
            resolvedUrl,
          );
        }
        final resolvedCookiesPath = YtDlpCookieArgs.resolveCookiesFilePath(
          urlSpecificPath: heartbeatCookies,
          globalPath: settings.cookiesFilePath,
        );

        final request = DownloadRequestFactory.fromSettings(
          settings: settings,
          url: resolvedUrl,
          cookiesFilePath: resolvedCookiesPath,
          rawCookies: item.cookies,
          userAgent: item.userAgent,
          cookieBrowser: item.cookieBrowser,
          audioOnly: item.isAudioOnly ? true : null,
          preferredQuality: item.preferredQuality,
        );
        final mediaKey = XMediaIdentity.mediaKey(request.url);
        if (_isDuplicateRequest(request, batchKeys: batchKeys)) {
          skippedDuplicates++;
          _markDuplicate(request);
          continue;
        }
        if (mediaKey != null) {
          batchKeys.add(mediaKey);
        }
        _queue.add(request);
        queued++;
      }

      if (skippedDuplicates > 0) {
        _showDuplicateBatchSummary(skippedDuplicates);
      }
      if (queued == 0) {
        if (rejectedUnsupported > 0 && skippedDuplicates == 0) {
          await _notifyUnsupportedUrl();
        }
        return;
      }
      await _persistQueue();
      await _processQueue();
    });
  }

  Future<void> deleteDownload(String id) async {
    await _repository.deleteDownload(id);
    _removeCatalogItem(id);
  }

  /// [newIndex] is the insertion index after the item is removed (onReorderItem).
  Future<void> reorder(int oldIndex, int newIndex) async {
    state.whenData((currentList) async {
      final items = List<DownloadItem>.from(currentList);
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
      _replaceCatalog(items);

      await _repository.reorderDownloads(oldIndex, newIndex);
    });
  }

  Future<void> cancelDownload(String id) async {
    await _repository.cancelDownload(id);
  }

  Future<void> pauseDownload(String id) async {
    await _repository.pauseDownload(id);
  }

  Future<void> resumeDownload(String id) async {
    await _repository.resumeDownload(id);
  }

  Future<void> retryDownload(DownloadItem item) async {
    await deleteDownload(item.id);
    await _queueOps.run(() async {
      _queue.add(
        item.request.copyWith(
          url: TikTokVideoUrl.forDownload(item.request.url),
        ),
      );
      await _persistQueue();
      await _processQueue();
    });
  }

  Future<void> pauseAllActive() async {
    final items = state.valueOrNull ?? _repository.getCurrentDownloads();
    for (final item in items) {
      if (item.status == DownloadStatus.downloading ||
          item.status == DownloadStatus.extracting ||
          item.status == DownloadStatus.processing) {
        await _repository.pauseDownload(item.id);
      }
    }
  }

  Future<void> retryAllFailed() async {
    final items = state.valueOrNull ?? _repository.getCurrentDownloads();
    final failed = items
        .where((item) => item.status == DownloadStatus.failed)
        .toList();
    for (final item in failed) {
      await retryDownload(item);
    }
  }

  Future<void> clearCompleted() async {
    final items = state.valueOrNull ?? _repository.getCurrentDownloads();
    final completed = items
        .where((item) => item.status == DownloadStatus.completed)
        .toList();
    for (final item in completed) {
      await deleteDownload(item.id);
    }
  }

  Future<void> clearFailed() async {
    final items = state.valueOrNull ?? _repository.getCurrentDownloads();
    final failed = items
        .where(
          (item) =>
              item.status == DownloadStatus.failed ||
              item.status == DownloadStatus.canceled,
        )
        .toList();
    for (final item in failed) {
      await deleteDownload(item.id);
    }
  }

  Future<void> clearHistory() async {
    await _repository.clearHistory();
    refreshList();
  }

  Future<void> exportHistory(String path) async {
    await _repository.exportHistory(path);
  }

  Future<void> importHistory(String path) async {
    await _repository.importHistory(path);
    refreshList();
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue) {
      _processQueueAgain = true;
      return;
    }
    _isProcessingQueue = true;

    try {
      do {
        _processQueueAgain = false;
        final currentList =
            state.valueOrNull ?? _repository.getCurrentDownloads();
        int activeCount = DownloadQueueController.busyCount(currentList);

        final settings = _ref.read(settingsProvider);
        final maxConcurrent = settings.maxConcurrent;

        while (_queue.isNotEmpty || _resumeIds.isNotEmpty) {
          final pendingCount = _resumeIds.length + _queue.length;
          if (DownloadQueueController.startableCount(
                busyCount: activeCount,
                maxConcurrent: maxConcurrent,
                pendingCount: pendingCount,
              ) <
              1) {
            break;
          }

          activeCount++;

          if (_resumeIds.isNotEmpty) {
            final id = _resumeIds.removeAt(0);
            await _repository.resumeDownload(id);
          } else {
            final nextRequest = _queue.removeAt(0);
            await _persistQueue();
            await _repository.startDownload(nextRequest);
          }
        }
      } while (_processQueueAgain);
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<void> _persistQueue() async {
    try {
      await _ref
          .read(persistenceServiceProvider)
          .saveQueue(List<DownloadRequest>.from(_queue));
    } catch (e) {
      LoggerService.e('Failed to persist download queue', e);
    }
  }

  bool _isDuplicateRequest(
    DownloadRequest request, {
    Set<String> batchKeys = const <String>{},
  }) {
    return DownloadQueueController.isDuplicateRequest(
      request: request,
      queued: _queue,
      items: state.valueOrNull ?? const <DownloadItem>[],
      batchKeys: batchKeys,
      fileExists: (path) {
        try {
          return File(path).existsSync();
        } catch (_) {
          return false;
        }
      },
    );
  }

  Future<void> _notifyUnsupportedUrl() async {
    await NotificationService().showError(
      'Unsupported URL',
      'This link is not supported (Discord invite, unknown host, etc.).',
    );
  }

  void _markDuplicate(DownloadRequest request) {
    final duplicateItem = DownloadItem(
      id: const Uuid().v4(),
      request: request,
      status: DownloadStatus.duplicate,
    );

    _catalogById[duplicateItem.id] = duplicateItem;
    _catalogIds.add(duplicateItem.id);
    state = AsyncValue.data(_catalogItems());
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (!mounted) {
        return;
      }
      _removeCatalogItem(duplicateItem.id);
    });
  }

  void _showDuplicateBatchSummary(int count) {
    _duplicateSummaryTimer?.cancel();
    _ref.read(duplicateBatchCountProvider.notifier).state = count;
    _duplicateSummaryTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _ref.read(duplicateBatchCountProvider.notifier).state = 0;
      }
    });
  }
}

final downloadListProvider =
    StateNotifierProvider<DownloadListNotifier, AsyncValue<List<DownloadItem>>>(
      (ref) {
        return DownloadListNotifier(
          ref.read(downloaderRepositoryProvider),
          ref,
        );
      },
    );

String? _tiktokVideoIdFromUrl(String url) {
  final match = RegExp(
    r'/(?:video|share/video)/(\d{8,})(?:\D|$)',
  ).firstMatch(url);
  if (match != null) return match.group(1);
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  for (final key in const ['video_id', 'aweme_id', 'item_id']) {
    final value = uri.queryParameters[key];
    if (value != null && RegExp(r'^\d{8,}$').hasMatch(value)) return value;
  }
  return null;
}

/// Per-id item so progress ticks rebuild only the row that changed.
final downloadItemByIdProvider = Provider.family<DownloadItem?, String>((
  ref,
  id,
) {
  final runtimeItem = ref.watch(downloadRuntimeItemProvider(id));
  if (runtimeItem != null) return runtimeItem;
  return ref.watch(
    downloadListProvider.select((async) {
      final items = async.valueOrNull;
      if (items == null) return null;
      for (final item in items) {
        if (item.id == id) return item;
      }
      return null;
    }),
  );
});
