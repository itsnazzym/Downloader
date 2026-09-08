import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/binary/service_providers.dart';
import '../../data/services/tiktok_video_cache_service.dart';
import '../../domain/entities/tiktok_archive_catalog.dart';

final tiktokVideoCacheServiceProvider = Provider<TikTokVideoCacheService>((ref) {
  final locator = ref.watch(binaryLocatorProvider);
  final service = TikTokVideoCacheService(binaryLocator: locator);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Shared audio mute state for in-app TikTok browsing
final tiktokMutedProvider = StateProvider<bool>((ref) => false);

/// Set of video IDs that are known to be deleted or unavailable on TikTok
final tiktokUnavailableIdsProvider = StreamProvider<Set<String>>((ref) async* {
  final service = ref.watch(tiktokVideoCacheServiceProvider);
  unawaited(service.getCacheDirectory());
  yield service.unavailableIds;
  await for (final set in service.unavailableIdsStream) {
    yield set;
  }
});

/// Video state provider family for reactive, granular card updates
final tiktokVideoStateProvider = StreamProvider.family<TikTokVideoState, String>((ref, videoId) async* {
  final service = ref.watch(tiktokVideoCacheServiceProvider);
  
  // Emit current cached or in-memory state first
  final current = service.getVideoState(videoId);
  yield current;

  // If already checked on disk, yields updated status
  unawaited(service.getCachedVideoPath(videoId));

  // Listen to state changes from preloader and downloads
  await for (final state in service.stateStream) {
    if (state.videoId == videoId) {
      yield state;
    }
  }
});

/// Controller to trigger preloading and check cache status from views
class TikTokPreloadController {
  final TikTokVideoCacheService _service;

  TikTokPreloadController(this._service);

  void preloadAround(List<TikTokArchiveItem> items, int currentIndex, {int lookAhead = 3}) {
    _service.preloadAround(items, currentIndex, lookAhead: lookAhead);
  }

  Future<String?> requestVideo(String videoId, {bool highPriority = true}) {
    return _service.requestVideo(videoId, highPriority: highPriority);
  }

  Future<String?> getCachedPath(String videoId) {
    return _service.getCachedVideoPath(videoId);
  }

  Future<int> getCacheSizeBytes() => _service.getCacheSizeBytes();

  Future<int> getCachedVideosCount() => _service.getCachedVideosCount();

  Future<void> clearCache() => _service.clearCache();

  void cancelAll() {
    _service.cancelAll();
  }
}

final tiktokPreloadControllerProvider = Provider<TikTokPreloadController>((ref) {
  final service = ref.watch(tiktokVideoCacheServiceProvider);
  return TikTokPreloadController(service);
});
