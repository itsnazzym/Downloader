import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/providers/launch_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/utils/format_utils.dart';
import '../../domain/entities/download_item.dart';
import '../../domain/entities/download_request.dart';
import '../../domain/enums/download_status.dart';
import '../../domain/repositories/i_downloader_repository.dart';
import '../../data/sources/yt_dlp_source.dart';
import '../../data/sources/gallery_dl_source.dart';
import '../../data/datasources/persistence_service.dart';
import '../../data/services/library_scanner_service.dart';
import '../../data/repositories/downloader_repository_impl.dart';
import 'package:modern_downloader/services/service_providers.dart';
import '../../../../core/services/download_stats_service.dart';
import '../../../../core/plugins/plugin_manager.dart';

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

final downloaderRepositoryProvider = Provider<IDownloaderRepository>((ref) {
  return DownloaderRepositoryImpl(
    ref.read(ytDlpSourceProvider),
    ref.read(galleryDlSourceProvider),
    ref.read(persistenceServiceProvider),
    ref.read(libraryScannerServiceProvider),
    ref.read(pluginManagerProvider.notifier),
    () => ref.read(settingsProvider).outputFolder,
  );
});

// Presentation Layer - Controller
final activeDownloadsProvider = StreamProvider<DownloadItem>((ref) {
  final repo = ref.watch(downloaderRepositoryProvider);
  return repo.downloadUpdateStream;
});

// Notifier to hold the list state
class DownloadListNotifier
    extends StateNotifier<AsyncValue<List<DownloadItem>>> {
  final IDownloaderRepository _repository;
  final Ref _ref;

  final List<DownloadRequest> _queue = [];
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
      _listenToUpdates();

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

  @override
  void dispose() {
    _throttleTimer?.cancel();
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
        final previous = itemMap[id];
        itemMap[id] = item;

        // Side effects for terminal states (handled once per event effectively)
        // Note: usage of 'item' here refers to the latest update for that ID
        if (item.status == DownloadStatus.completed ||
            item.status == DownloadStatus.failed ||
            item.status == DownloadStatus.canceled ||
            item.status == DownloadStatus.duplicate) {
          // Stats
          if (item.status == DownloadStatus.completed &&
              previous?.status != DownloadStatus.completed) {
            _ref
                .read(downloadStatsProvider.notifier)
                .recordDownload(
                  source: item.source,
                  bytesDownloaded: _extractRecordedBytes(item),
                );
          }

          // Auto-delete duplicates
          if (item.status == DownloadStatus.duplicate) {
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) {
                deleteDownload(item.id);
              }
            });
          }
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
    bool? audioOnlyOverride,
  }) async {
    _queue.add(
      _buildRequest(
        url,
        rawCookies: rawCookies,
        videoFormatId: videoFormatId,
        userAgent: userAgent,
        cookiesFilePath: cookiesFilePath,
        organizeBySite: organizeBySite,
        cookieBrowser: cookieBrowser,
        audioOnlyOverride: audioOnlyOverride,
      ),
    );
    await _processQueue();
  }

  Future<void> startDownloadsBatch(List<String> urls) async {
    for (final url in urls) {
      _queue.add(_buildRequest(url));
    }

    await _processQueue();
  }

  Future<void> startFromLaunchData(LaunchData data) async {
    if (data.isPlaylist) {
      try {
        final items = await _repository.fetchPlaylist(data.url);
        if (items.length > 1) {
          for (final item in items) {
            _queue.add(
              _buildRequest(
                _resolvePlaylistEntryUrl(item, data.url),
                rawCookies: data.cookies,
                userAgent: data.userAgent,
                cookieBrowser: data.cookieBrowser,
                audioOnlyOverride: data.isAudioOnly,
              ),
            );
          }
          await _processQueue();
          return;
        }
      } catch (_) {
        // Fall back to a single download below.
      }
    }

    await startDownload(
      data.url,
      rawCookies: data.cookies,
      userAgent: data.userAgent,
      cookieBrowser: data.cookieBrowser,
      audioOnlyOverride: data.isAudioOnly,
    );
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

  Future<void> retryDownload(DownloadItem item) async {
    await deleteDownload(item.id);
    _queue.add(item.request);
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
      while (_queue.isNotEmpty) {
        final currentList = state.valueOrNull ?? [];
        final activeCount = currentList
            .where(
              (i) =>
                  i.status == DownloadStatus.downloading ||
                  i.status == DownloadStatus.extracting,
            )
            .length;

        final settings = _ref.read(settingsProvider);
        final maxConcurrent = settings.maxConcurrent;

        if (activeCount < maxConcurrent) {
          final nextRequest = _queue.removeAt(0);
          await _repository.startDownload(nextRequest);
          // After starting, we continue the loop to check if we can start more
        } else {
          // Max concurrent reached, stop for now
          break;
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  DownloadRequest _buildRequest(
    String url, {
    String? rawCookies,
    String? videoFormatId,
    String? userAgent,
    String? cookiesFilePath,
    bool? organizeBySite,
    String? cookieBrowser,
    bool? audioOnlyOverride,
  }) {
    final settings = _ref.read(settingsProvider);
    final normalizedCookieBrowser = cookieBrowser != null
        ? (cookieBrowser.isEmpty ? null : cookieBrowser)
        : settings.cookieBrowser;

    return DownloadRequest(
      url: url,
      outputFolder: settings.outputFolder.isNotEmpty
          ? settings.outputFolder
          : null,
      audioOnly: audioOnlyOverride ?? settings.audioOnly,
      preferredQuality: settings.preferredQuality,
      outputFormat: settings.outputFormat,
      audioFormat: settings.audioFormat,
      embedThumbnail: settings.embedThumbnail,
      embedSubtitles: settings.embedSubtitles,
      twitterIncludeReplies: settings.twitterIncludeReplies,
      twitchDownloadChat: settings.twitchDownloadChat,
      twitchQuality: settings.twitchQuality,
      cookiesFilePath:
          cookiesFilePath ??
          (settings.cookiesFilePath.isNotEmpty
              ? settings.cookiesFilePath
              : null),
      useTorProxy: settings.useTorProxy,
      concurrentFragments: settings.concurrentFragments,
      rawCookies: rawCookies,
      videoFormatId: videoFormatId,
      cookieBrowser: normalizedCookieBrowser,
      organizeBySite: organizeBySite ?? settings.organizeBySite,
      userAgent: userAgent,
    );
  }

  String _resolvePlaylistEntryUrl(
    Map<String, dynamic> item,
    String originalUrl,
  ) {
    final itemUrl = item['url'] as String?;
    if (itemUrl != null && itemUrl.startsWith('http')) {
      return itemUrl;
    }

    if (item['id'] != null &&
        (itemUrl == null || !itemUrl.startsWith('http'))) {
      if (item['ie_key'] == 'Youtube' || originalUrl.contains('youtu')) {
        return 'https://www.youtube.com/watch?v=${item['id']}';
      }
    }

    return itemUrl ?? originalUrl;
  }

  int _extractRecordedBytes(DownloadItem item) {
    final candidates = [item.totalSize, item.downloadedSize];
    for (final candidate in candidates) {
      final parsed = FormatUtils.parseBytes(candidate);
      if (parsed > 0) {
        return parsed;
      }
    }
    return 0;
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
