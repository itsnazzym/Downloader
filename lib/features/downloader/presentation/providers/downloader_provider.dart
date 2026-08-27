import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/download/yt_dlp_cookie_args.dart';
import '../../../../core/services/local_server_service.dart';
import '../../../x_feed/x_media_identity.dart';
import '../../domain/entities/download_item.dart';
import '../../domain/entities/download_request.dart';
import '../../domain/enums/download_status.dart';
import '../../domain/repositories/i_downloader_repository.dart';
import '../../data/sources/yt_dlp_source.dart';
import '../../data/sources/gallery_dl_source.dart';
import '../../data/sources/kick_source.dart';
import '../../data/datasources/persistence_service.dart';
import '../../data/services/library_scanner_service.dart';
import '../../data/repositories/downloader_repository_impl.dart';
import 'package:modern_downloader/services/service_providers.dart';
import '../../../../core/services/download_stats_service.dart';
import '../../../../core/plugins/plugin_manager.dart';
import '../../../../core/logger/logger_service.dart';

// Data Layer Providers
final ytDlpSourceProvider = Provider<YtDlpSource>((ref) {
  return YtDlpSource(
    ref.read(binaryLocatorProvider),
    ref.read(processRunnerProvider),
  );
});

final galleryDlSourceProvider = Provider<GalleryDlSource>((ref) {
  return GalleryDlSource(ref.read(binaryLocatorProvider));
});

// Added persistenceServiceProvider
final persistenceServiceProvider = Provider<PersistenceService>((ref) {
  return PersistenceService();
});

final libraryScannerServiceProvider = Provider<LibraryScannerService>((ref) {
  return LibraryScannerService(ref.read(binaryLocatorProvider));
});

final kickSourceProvider = Provider<KickSource>((ref) {
  return KickSource();
});

final downloaderRepositoryProvider = Provider<IDownloaderRepository>((ref) {
  return DownloaderRepositoryImpl(
    ref.read(ytDlpSourceProvider),
    ref.read(galleryDlSourceProvider),
    ref.read(persistenceServiceProvider),
    ref.read(libraryScannerServiceProvider),
    ref.read(pluginManagerProvider.notifier),
    () => ref.read(settingsProvider).outputFolder,
    kickSource: ref.read(kickSourceProvider),
  );
});

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

  DownloadListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    // Simulate loading for better UX (Skeleton demonstration) or valid async load
    await Future.delayed(const Duration(milliseconds: 600));
    try {
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

      // If terminal state or imperative update, flush immediately
      if (item.status == DownloadStatus.completed ||
          item.status == DownloadStatus.failed ||
          item.status == DownloadStatus.canceled ||
          item.status == DownloadStatus.duplicate ||
          item.status == DownloadStatus.paused ||
          item.status == DownloadStatus.queued) {
        _flushUpdates();
      } else {
        // For progress updates (downloading/extracting), throttle
        if (_throttleTimer == null || !_throttleTimer!.isActive) {
          _throttleTimer = Timer(
            const Duration(milliseconds: 50),
            _flushUpdates,
          );
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

      updates.forEach((id, item) {
        itemMap[id] = item;

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
      _ref.read(downloadStatsProvider.notifier).rebuildFromLibrary(newState);

      // Process queue if any slot freed up
      // We check if any of the updates were terminal
      final hasTerminal = updates.values.any(
        (i) =>
            i.status == DownloadStatus.completed ||
            i.status == DownloadStatus.failed ||
            i.status == DownloadStatus.canceled ||
            i.status == DownloadStatus.duplicate,
      );

      if (hasTerminal) {
        _processQueue();
      }
    });
  }

  void refreshList() {
    try {
      final items = _repository.getCurrentDownloads();
      state = AsyncValue.data(items);
      _ref.read(downloadStatsProvider.notifier).rebuildFromLibrary(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
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
    final settings = _ref.read(settingsProvider);
    final heartbeatCookies = await LocalServerService.heartbeatCookiePathForUrl(
      url,
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

    final request = DownloadRequest(
      url: url,
      outputFolder: settings.outputFolder.isNotEmpty
          ? settings.outputFolder
          : null,
      audioOnly: audioOnly ?? settings.audioOnly,
      preferredQuality: preferredQuality ?? settings.preferredQuality,
      outputFormat: settings.outputFormat,
      audioFormat: settings.audioFormat,
      embedThumbnail: settings.embedThumbnail,
      embedSubtitles: settings.embedSubtitles,
      twitterIncludeReplies: settings.twitterIncludeReplies,
      twitchDownloadChat: settings.twitchDownloadChat,
      twitchQuality: settings.twitchQuality,
      cookiesFilePath: resolvedCookiesPath,
      useTorProxy: settings.useTorProxy,
      concurrentFragments: settings.concurrentFragments,
      maxSpeedMode: settings.maxSpeedMode,
      rawCookies: rawCookies,
      videoFormatId: videoFormatId,
      cookieBrowser: cookieBrowser ?? settings.cookieBrowser,
      organizeBySite: organizeBySite ?? settings.organizeBySite,
      userAgent: userAgent,
    );

    if (_isDuplicateRequest(request)) {
      _markDuplicate(request);
      return;
    }

    _queue.add(request);
    await _persistQueue();
    await _processQueue();
  }

  Future<void> startDownloadsBatch(List<String> urls) async {
    final settings = _ref.read(settingsProvider);
    final batchKeys = <String>{};
    var skippedDuplicates = 0;

    for (final url in urls) {
      final heartbeatCookies =
          await LocalServerService.heartbeatCookiePathForUrl(url);
      final resolvedCookiesPath = YtDlpCookieArgs.resolveCookiesFilePath(
        urlSpecificPath: heartbeatCookies,
        globalPath: settings.cookiesFilePath,
      );

      final request = DownloadRequest(
        url: url,
        outputFolder: settings.outputFolder.isNotEmpty
            ? settings.outputFolder
            : null,
        audioOnly: settings.audioOnly,
        preferredQuality: settings.preferredQuality,
        outputFormat: settings.outputFormat,
        audioFormat: settings.audioFormat,
        embedThumbnail: settings.embedThumbnail,
        embedSubtitles: settings.embedSubtitles,
        twitterIncludeReplies: settings.twitterIncludeReplies,
        twitchDownloadChat: settings.twitchDownloadChat,
        twitchQuality: settings.twitchQuality,
        cookiesFilePath: resolvedCookiesPath,
        useTorProxy: settings.useTorProxy,
        concurrentFragments: settings.concurrentFragments,
        maxSpeedMode: settings.maxSpeedMode,
        cookieBrowser: settings.cookieBrowser,
        organizeBySite: settings.organizeBySite,
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
    }

    if (skippedDuplicates > 0) {
      _showDuplicateBatchSummary(skippedDuplicates);
    }
    await _persistQueue();
    await _processQueue();
  }

  Future<void> deleteDownload(String id) async {
    await _repository.deleteDownload(id);
    state.whenData((currentList) {
      final newState = currentList.where((item) => item.id != id).toList();
      state = AsyncValue.data(newState);
    });
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

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
    _queue.add(item.request);
    await _persistQueue();
    await _processQueue();
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
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      while (_queue.isNotEmpty || _resumeIds.isNotEmpty) {
        final currentList = state.valueOrNull ?? [];
        final activeCount = currentList
            .where(
              (i) =>
                  i.status == DownloadStatus.downloading ||
                  i.status == DownloadStatus.extracting ||
                  i.status == DownloadStatus.processing,
            )
            .length;

        final settings = _ref.read(settingsProvider);
        final maxConcurrent = settings.maxConcurrent;

        if (activeCount < maxConcurrent) {
          if (_resumeIds.isNotEmpty) {
            final id = _resumeIds.removeAt(0);
            await _repository.resumeDownload(id);
            refreshList();
          } else {
            final nextRequest = _queue.removeAt(0);
            await _persistQueue();
            await _repository.startDownload(nextRequest);
            refreshList();
          }
        } else {
          break;
        }
      }
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
    final mediaKey = XMediaIdentity.mediaKey(request.url);
    if (mediaKey == null) {
      return false;
    }
    if (batchKeys.contains(mediaKey) ||
        _queue.any(
          (queuedRequest) =>
              XMediaIdentity.mediaKey(queuedRequest.url) == mediaKey,
        )) {
      return true;
    }

    final items = state.valueOrNull ?? const <DownloadItem>[];
    return items.any((item) {
      if (XMediaIdentity.mediaKey(item.request.url) != mediaKey) {
        return false;
      }
      if (_isActiveOrQueued(item.status)) {
        return true;
      }

      final filePath = item.filePath;
      return item.status == DownloadStatus.completed &&
          filePath != null &&
          filePath.isNotEmpty &&
          File(filePath).existsSync();
    });
  }

  bool _isActiveOrQueued(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.queued:
      case DownloadStatus.extracting:
      case DownloadStatus.downloading:
      case DownloadStatus.processing:
        return true;
      case DownloadStatus.completed:
      case DownloadStatus.failed:
      case DownloadStatus.canceled:
      case DownloadStatus.paused:
      case DownloadStatus.duplicate:
        return false;
    }
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
