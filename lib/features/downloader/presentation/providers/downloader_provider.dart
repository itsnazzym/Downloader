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
      state = AsyncValue.data(items);
      _ref.read(downloadStatsProvider.notifier).rebuildFromLibrary(items);
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

      // Terminal / queued / paused: flush immediately
      if (isImmediateFlushStatus(item.status)) {
        _flushUpdates();
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

    state.whenData((currentList) {
      // Create a map of current items for valid lookups and replacement
      final Map<String, DownloadItem> itemMap = {
        for (var item in currentList) item.id: item,
      };

      // Apply all pending updates
      final updates = Map<String, DownloadItem>.from(_pendingUpdates);
      _pendingUpdates.clear();

      bool newQueuedAdded = false;
      updates.forEach((id, item) {
        itemMap[id] = item;

        if (item.status == DownloadStatus.queued && !_resumeIds.contains(id)) {
          _resumeIds.add(id);
          newQueuedAdded = true;
        }

        // Side effects for terminal states (handled once per event effectively)
        // Note: usage of 'item' here refers to the latest update for that ID
        if (item.status == DownloadStatus.duplicate) {
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              deleteDownload(item.id);
            }
          });
        }
      });

      // Convert back to list, maintaining original order if possible, or appending new ones?
      // Re-constructing the list based on itemMap is risky if we lose order.
      // Better: Iterate original list/keys and update. New items appended.

      final List<DownloadItem> newState = [];
      final Set<String> processedIds = {};

      for (var existing in currentList) {
        if (updates.containsKey(existing.id)) {
          newState.add(updates[existing.id]!);
        } else {
          newState.add(existing);
        }
        processedIds.add(existing.id);
      }

      // Add new items that weren't in the list
      updates.forEach((id, item) {
        if (!processedIds.contains(id)) {
          newState.add(item);
        }
      });

      state = AsyncValue.data(newState);

      // Process queue if any slot freed up or new queued items arrived
      final hasTerminal = updates.values.any(
        (i) => isStatsRebuildStatus(i.status),
      );

      if (hasTerminal || newQueuedAdded) {
        _ref.read(downloadStatsProvider.notifier).rebuildFromLibrary(newState);
        _processQueue();
      }
    });
  }

  void refreshList() {
    try {
      final items = _repository.getCurrentDownloads();
      state = AsyncValue.data(items);
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
    String? cookieBrowser,
    bool? audioOnly,
    String? preferredQuality,
  }) async {
    final resolvedUrl = XDownloadUrl.resolveForDownload(url);
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

    final request = DownloadRequestFactory.fromSettings(
      settings: settings,
      url: resolvedUrl,
      cookiesFilePath: resolvedCookiesPath,
      rawCookies: rawCookies,
      userAgent: userAgent,
      videoFormatId: videoFormatId,
      cookieBrowser: cookieBrowser,
      organizeBySite: organizeBySite,
      audioOnly: audioOnly,
      preferredQuality: preferredQuality,
    );

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
    state.whenData((currentList) {
      final newState = currentList.where((item) => item.id != id).toList();
      state = AsyncValue.data(newState);
    });
  }

  /// [newIndex] is the insertion index after the item is removed (onReorderItem).
  Future<void> reorder(int oldIndex, int newIndex) async {
    state.whenData((currentList) async {
      final items = List<DownloadItem>.from(currentList);
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
      state = AsyncValue.data(items);

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
      _queue.add(item.request);
      await _persistQueue();
      await _processQueue();
    });
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

    state.whenData((items) {
      state = AsyncValue.data(<DownloadItem>[...items, duplicateItem]);
    });
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (!mounted) {
        return;
      }
      state.whenData((items) {
        state = AsyncValue.data(
          items.where((item) => item.id != duplicateItem.id).toList(),
        );
      });
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

/// Per-id item so progress ticks rebuild only the row that changed.
final downloadItemByIdProvider = Provider.family<DownloadItem?, String>((
  ref,
  id,
) {
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
