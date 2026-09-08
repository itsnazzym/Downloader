import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/domain/repositories/i_tiktok_archive_repository.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';

class MockTikTokArchiveRepository implements ITikTokArchiveRepository {
  TikTokArchiveCatalog? _cached;

  MockTikTokArchiveRepository([this._cached]);

  @override
  Future<TikTokArchiveCatalog?> getCachedCatalog() async => _cached;

  @override
  Future<TikTokArchiveCatalog> importFromFile(String filePath) async {
    return _cached ?? TikTokArchiveCatalog.empty;
  }

  @override
  Future<void> saveCatalog(TikTokArchiveCatalog catalog) async {
    _cached = catalog;
  }

  @override
  Future<void> clearCatalog() async {
    _cached = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleCatalog = TikTokArchiveCatalog(
    videos: [
      TikTokArchiveItem(
        id: '1001',
        url: 'https://www.tiktokv.com/share/video/1001/',
        date: DateTime(2026, 8, 1),
        isFavorite: true,
        isLiked: false,
        collectionName: 'Tech',
      ),
      TikTokArchiveItem(
        id: '1002',
        url: 'https://www.tiktokv.com/share/video/1002/',
        date: DateTime(2025, 5, 10),
        isFavorite: false,
        isLiked: true,
        collectionName: 'Music',
      ),
      TikTokArchiveItem(
        id: '1003',
        url: 'https://www.tiktokv.com/share/video/1003/',
        date: DateTime(2024, 2, 20),
        isFavorite: true,
        isLiked: true,
      ),
    ],
    collections: const [
      TikTokCollectionItem(name: 'Tech', videoCount: 1),
      TikTokCollectionItem(name: 'Music', videoCount: 1),
    ],
    sounds: [
      TikTokSoundItem(
        title: 'Awesome Beat',
        url: 'https://www.tiktokv.com/share/music/beat-99',
        date: DateTime(2026, 1, 1),
      ),
    ],
    totalFavorites: 2,
    totalLikes: 2,
    totalOverlap: 1,
    yearCounts: {2026: 1, 2025: 1, 2024: 1},
  );

  group('TikTokArchiveProvider Tests', () {
    test('loads cached catalog and filters by year and collection', () async {
      final container = ProviderContainer(
        overrides: [
          tikTokArchiveRepositoryProvider.overrideWithValue(
            MockTikTokArchiveRepository(sampleCatalog),
          ),
        ],
      );

      // Initialize notifier and await initialization
      final notifier = container.read(tikTokArchiveProvider.notifier);
      await notifier.initialized;

      final state = container.read(tikTokArchiveProvider);
      expect(state.hasCatalog, isTrue);
      expect(state.catalog!.totalUniqueVideos, equals(3));

      // Filter by Year 2026
      container.read(tikTokArchiveProvider.notifier).selectYear(2026);
      var filtered = container.read(filteredTikTokVideosProvider);
      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('1001'));

      // Filter by Collection 'Music'
      container.read(tikTokArchiveProvider.notifier).selectYear(null);
      container.read(tikTokArchiveProvider.notifier).selectCollection('Music');
      filtered = container.read(filteredTikTokVideosProvider);
      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('1002'));

      // Filter by Favorites Only
      container.read(tikTokArchiveProvider.notifier).selectCollection(null);
      container.read(tikTokArchiveProvider.notifier).setStatusFilter(TikTokStatusFilter.favoritesOnly);
      filtered = container.read(filteredTikTokVideosProvider);
      expect(filtered.length, equals(2));

      // Toggle selection
      container.read(tikTokArchiveProvider.notifier).toggleSelection('1001');
      expect(container.read(tikTokArchiveProvider).selectedIds, contains('1001'));

      container.read(tikTokArchiveProvider.notifier).clearSelection();
      expect(container.read(tikTokArchiveProvider).selectedIds, isEmpty);
    });

    test('defaults to TikTokViewMode.hub and updates collection mapping accurately', () async {
      final container = ProviderContainer(
        overrides: [
          tikTokArchiveRepositoryProvider.overrideWithValue(
            MockTikTokArchiveRepository(sampleCatalog),
          ),
        ],
      );

      final notifier = container.read(tikTokArchiveProvider.notifier);
      await notifier.initialized;

      final state = container.read(tikTokArchiveProvider);
      // Verify default view mode is hub
      expect(state.viewMode, equals(TikTokViewMode.hub));

      // Switch to collections mode
      notifier.setViewMode(TikTokViewMode.collections);
      expect(container.read(tikTokArchiveProvider).viewMode, equals(TikTokViewMode.collections));

      // Update mapping: assign video '1003' to collection 'Gaming'
      await notifier.updateCollectionMapping({
        'Gaming': ['1003'],
      });

      final updatedState = container.read(tikTokArchiveProvider);
      final gamingCol = updatedState.catalog!.collections.firstWhere((c) => c.name == 'Gaming');
      expect(gamingCol.videoCount, equals(1));

      final video1003 = updatedState.catalog!.videos.firstWhere((v) => v.id == '1003');
      expect(video1003.collectionName, equals('Gaming'));
    });

    test('applies strict anchor heuristic only when declaredTotal > verifiedCount', () async {
      final testCatalog = TikTokArchiveCatalog(
        videos: [
          TikTokArchiveItem(
            id: 'v_verified',
            url: 'https://www.tiktokv.com/share/video/v_verified/',
            date: DateTime(2026, 8, 10),
            isFavorite: true,
          ),
          TikTokArchiveItem(
            id: 'v_in_window',
            url: 'https://www.tiktokv.com/share/video/v_in_window/',
            date: DateTime(2026, 8, 11), // 1 day after verified -> within +/- 2 days anchor
            isFavorite: true,
          ),
          TikTokArchiveItem(
            id: 'v_far_away',
            url: 'https://www.tiktokv.com/share/video/v_far_away/',
            date: DateTime(2024, 1, 1), // 2.5 years away -> must be ignored
            isFavorite: true,
          ),
          TikTokArchiveItem(
            id: 'v_not_favorite',
            url: 'https://www.tiktokv.com/share/video/v_not_favorite/',
            date: DateTime(2026, 8, 10), // Same date but not a favorite -> must be ignored
            isFavorite: false,
            isLiked: true,
          ),
        ],
        collections: const [
          TikTokCollectionItem(name: 'AutoTech', videoCount: 0),
        ],
        sounds: const [],
        totalFavorites: 3,
        totalLikes: 1,
        totalOverlap: 0,
        yearCounts: {2026: 3, 2024: 1},
      );

      final container = ProviderContainer(
        overrides: [
          tikTokArchiveRepositoryProvider.overrideWithValue(
            MockTikTokArchiveRepository(testCatalog),
          ),
        ],
      );

      final notifier = container.read(tikTokArchiveProvider.notifier);
      await notifier.initialized;

      // Sync mapping: AutoTech has 1 verified video ('v_verified'), but declaredTotal = 2
      await notifier.updateCollectionMapping(
        {
          'AutoTech': ['v_verified'],
        },
        collectionTotals: {
          'AutoTech': 2,
        },
      );

      final state = container.read(tikTokArchiveProvider);
      final col = state.catalog!.collections.firstWhere((c) => c.name == 'AutoTech');

      // AutoTech should have exactly 2 videos (1 verified + 1 completed via anchor heuristic)
      expect(col.videoCount, equals(2));
      expect(col.declaredTotal, equals(2));
      expect(col.heuristicCount, equals(1));

      // Check which videos were assigned
      final vVerified = state.catalog!.videos.firstWhere((v) => v.id == 'v_verified');
      final vInWindow = state.catalog!.videos.firstWhere((v) => v.id == 'v_in_window');
      final vFarAway = state.catalog!.videos.firstWhere((v) => v.id == 'v_far_away');
      final vNotFavorite = state.catalog!.videos.firstWhere((v) => v.id == 'v_not_favorite');

      expect(vVerified.collectionName, equals('AutoTech'));
      expect(vInWindow.collectionName, equals('AutoTech')); // Captured by anchor window
      expect(vFarAway.collectionName, isNull); // Kept unclassified
      expect(vNotFavorite.collectionName, isNull); // Kept unclassified

      // Test resetCollectionToUnclassified
      await notifier.resetCollectionToUnclassified('AutoTech');

      final resetState = container.read(tikTokArchiveProvider);
      final resetCol = resetState.catalog!.collections.firstWhere((c) => c.name == 'AutoTech');
      expect(resetCol.videoCount, equals(0));
      expect(resetCol.heuristicCount, equals(0));

      final vVerifiedAfterReset = resetState.catalog!.videos.firstWhere((v) => v.id == 'v_verified');
      final vInWindowAfterReset = resetState.catalog!.videos.firstWhere((v) => v.id == 'v_in_window');
      expect(vVerifiedAfterReset.collectionName, isNull);
      expect(vInWindowAfterReset.collectionName, isNull);
    });
  });
}

