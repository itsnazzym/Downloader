import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/features/archive/data/services/tiktok_video_cache_service.dart';
import 'package:tapload/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:tapload/features/archive/domain/repositories/i_tiktok_archive_repository.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_video_cache_provider.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/entities/download_request.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../visual/visual_fakes.dart';

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

ProviderContainer _createArchiveTestContainer(
  ITikTokArchiveRepository repository,
) {
  final container = ProviderContainer(
    overrides: [
      tikTokArchiveRepositoryProvider.overrideWithValue(repository),
      tiktokVideoCacheServiceProvider.overrideWith((ref) {
        final service = TikTokVideoCacheService(
          cacheDirectory: Directory.systemTemp,
        );
        ref.onDispose(service.dispose);
        return service;
      }),
    ],
  );
  addTearDown(container.dispose);
  return container;
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
      final container = _createArchiveTestContainer(
        MockTikTokArchiveRepository(sampleCatalog),
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

      container
          .read(tikTokArchiveProvider.notifier)
          .selectCollection('Vidéos Likées');
      filtered = container.read(filteredTikTokVideosProvider);
      expect(filtered.map((video) => video.id), containsAll(['1002', '1003']));

      // Filter by Favorites Only
      container.read(tikTokArchiveProvider.notifier).selectCollection(null);
      container
          .read(tikTokArchiveProvider.notifier)
          .setStatusFilter(TikTokStatusFilter.favoritesOnly);
      filtered = container.read(filteredTikTokVideosProvider);
      expect(filtered.length, equals(2));

      // Toggle selection
      container.read(tikTokArchiveProvider.notifier).toggleSelection('1001');
      expect(
        container.read(tikTokArchiveProvider).selectedIds,
        contains('1001'),
      );

      container.read(tikTokArchiveProvider.notifier).clearSelection();
      expect(container.read(tikTokArchiveProvider).selectedIds, isEmpty);
    });

    test(
      'mapping proposals require approval before collection assignment',
      () async {
        final container = _createArchiveTestContainer(
          MockTikTokArchiveRepository(sampleCatalog),
        );

        final notifier = container.read(tikTokArchiveProvider.notifier);
        await notifier.initialized;

        final state = container.read(tikTokArchiveProvider);
        // Cached mapped libraries open directly to their collections.
        expect(state.viewMode, equals(TikTokViewMode.collections));

        notifier.setViewMode(TikTokViewMode.collections);
        expect(
          container.read(tikTokArchiveProvider).viewMode,
          equals(TikTokViewMode.collections),
        );

        await notifier.updateCollectionMapping({
          'Gaming': ['1003'],
        });

        var updatedState = container.read(tikTokArchiveProvider);
        var gamingCol = updatedState.catalog!.collections.firstWhere(
          (c) => c.name == 'Gaming',
        );
        expect(gamingCol.videoCount, 0);
        expect(updatedState.catalog!.suggestions.single.videoId, '1003');
        expect(
          updatedState.catalog!.videos
              .firstWhere((v) => v.id == '1003')
              .collectionName,
          isNull,
        );

        await notifier.applyCollectionSuggestions({
          updatedState.catalog!.suggestions.single.key,
        });
        updatedState = container.read(tikTokArchiveProvider);
        gamingCol = updatedState.catalog!.collections.firstWhere(
          (c) => c.name == 'Gaming',
        );
        expect(gamingCol.videoCount, equals(1));

        final video1003 = updatedState.catalog!.videos.firstWhere(
          (v) => v.id == '1003',
        );
        expect(video1003.collectionName, equals('Gaming'));
      },
    );

    test(
      'legacy mapping creates a reviewable collection without assigning videos',
      () async {
        final repository = MockTikTokArchiveRepository();
        final container = _createArchiveTestContainer(repository);

        final notifier = container.read(tikTokArchiveProvider.notifier);
        await notifier.updateCollectionMapping(
          {
            'Saved clips': ['7400000000000000001', '7400000000000000002'],
          },
          collectionTotals: {'Saved clips': 2},
        );

        final catalog = container.read(tikTokArchiveProvider).catalog!;
        expect(catalog.videos.length, 2);
        expect(catalog.totalFavorites, 2);
        final collection = catalog.collections.firstWhere(
          (item) => item.name == 'Saved clips',
        );
        expect(collection.videoCount, 0);
        expect(collection.declaredTotal, 2);
        expect(catalog.suggestions.length, 2);
        expect(
          catalog.videos.every((video) => video.collectionName == null),
          isTrue,
        );
        expect(
          catalog.videos.first.url,
          'https://www.tiktokv.com/share/video/7400000000000000001/',
        );
        expect((await repository.getCachedCatalog())!.videos.length, 2);

        await notifier.applyCollectionSuggestions(
          catalog.suggestions.map((suggestion) => suggestion.key).toSet(),
        );
        final approved = container.read(tikTokArchiveProvider).catalog!;
        expect(
          approved.collections
              .firstWhere((item) => item.name == 'Saved clips')
              .videoCount,
          2,
        );
        expect(
          approved.videos.every(
            (video) => video.collectionName == 'Saved clips',
          ),
          isTrue,
        );
      },
    );

    test(
      'partial sync saves verified IDs without guessing from nearby dates',
      () async {
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
              date: DateTime(
                2026,
                8,
                11,
              ), // 1 day after verified -> within +/- 2 days anchor
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
              date: DateTime(
                2026,
                8,
                10,
              ), // Same date but not a favorite -> must be ignored
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

        final container = _createArchiveTestContainer(
          MockTikTokArchiveRepository(testCatalog),
        );

        final notifier = container.read(tikTokArchiveProvider.notifier);
        await notifier.initialized;

        await notifier.applyCollectionSync(const [
          TikTokCollectionSnapshot(
            id: 'collection-autotech',
            name: 'AutoTech',
            declaredTotal: 3,
            videoIds: ['v_verified', 'v_not_favorite'],
            complete: false,
            error: 'count_mismatch',
          ),
        ], collectionListComplete: false);

        final state = container.read(tikTokArchiveProvider);
        final col = state.catalog!.collections.firstWhere(
          (c) => c.name == 'AutoTech',
        );

        expect(col.videoCount, equals(2));
        expect(col.declaredTotal, equals(3));
        expect(col.syncComplete, isFalse);
        expect(state.catalog!.suggestions, isEmpty);

        final vVerified = state.catalog!.videos.firstWhere(
          (v) => v.id == 'v_verified',
        );
        final vInWindow = state.catalog!.videos.firstWhere(
          (v) => v.id == 'v_in_window',
        );
        final vFarAway = state.catalog!.videos.firstWhere(
          (v) => v.id == 'v_far_away',
        );
        final vNotFavorite = state.catalog!.videos.firstWhere(
          (v) => v.id == 'v_not_favorite',
        );

        expect(vVerified.collectionId, 'collection-autotech');
        expect(vInWindow.collectionId, isNull);
        expect(vFarAway.collectionName, isNull);
        expect(vNotFavorite.collectionId, 'collection-autotech');
        final newlyFavoritedLike = state.catalog!.videos.firstWhere(
          (video) => video.id == 'v_not_favorite',
        );
        expect(newlyFavoritedLike.isFavorite, isTrue);
        expect(state.catalog!.totalFavorites, 4);
        expect(state.catalog!.totalOverlap, 1);

        await notifier.resetCollectionToUnclassified('collection-autotech');

        final resetState = container.read(tikTokArchiveProvider);
        final resetCol = resetState.catalog!.collections.firstWhere(
          (c) => c.name == 'AutoTech',
        );
        expect(resetCol.videoCount, equals(0));
        expect(resetCol.heuristicCount, equals(0));

        final vVerifiedAfterReset = resetState.catalog!.videos.firstWhere(
          (v) => v.id == 'v_verified',
        );
        final vInWindowAfterReset = resetState.catalog!.videos.firstWhere(
          (v) => v.id == 'v_in_window',
        );
        expect(vVerifiedAfterReset.collectionName, isNull);
        expect(vInWindowAfterReset.collectionName, isNull);
      },
    );

    test(
      'large suggestion batches are reconciled without blocking the UI isolate',
      () async {
        final now = DateTime(2026, 1, 1);
        final videos = List.generate(
          2500,
          (index) => TikTokArchiveItem(
            id: 'large-$index',
            url: 'https://www.tiktok.com/video/$index',
            date: now,
            isFavorite: true,
          ),
        );
        final largeCatalog = TikTokArchiveCatalog(
          videos: videos,
          collections: const [],
          sounds: const [],
          totalFavorites: videos.length,
          totalLikes: 0,
          totalOverlap: 0,
          yearCounts: {2026: videos.length},
        );
        final repository = MockTikTokArchiveRepository(largeCatalog);
        final container = _createArchiveTestContainer(repository);

        final notifier = container.read(tikTokArchiveProvider.notifier);
        await notifier.initialized;
        await notifier.updateCollectionMapping({
          'Large folder': videos.map((video) => video.id).toList(),
        });
        final pending = container.read(tikTokArchiveProvider).catalog!;
        expect(pending.suggestions, hasLength(2500));
        expect(
          pending.videos.every((video) => video.collectionIds.isEmpty),
          isTrue,
        );

        await notifier.applyCollectionSuggestions(
          pending.suggestions.map((suggestion) => suggestion.key).toSet(),
        );
        final approved = container.read(tikTokArchiveProvider).catalog!;
        expect(approved.suggestions, isEmpty);
        expect(approved.collections.single.videoCount, 2500);
        expect(
          approved.videos.every((video) => video.collectionIds.length == 1),
          isTrue,
        );
      },
    );
  });

  test('purging a collection deletes its downloaded files only', () async {
    SharedPreferences.setMockInitialValues({});
    initPrefs(await SharedPreferences.getInstance());
    DownloadItem done(String id, String url) => DownloadItem(
      id: id,
      request: DownloadRequest(url: url),
      title: id,
      status: DownloadStatus.completed,
      progress: 1,
      filePath: 'C:/Videos/$id.mp4',
    );
    final library = FakeDownloaderRepository([
      // As "download all" queues them: the catalog URL, normalised.
      done('dl-tech', 'https://www.tiktokv.com/share/video/1001/'),
      done('dl-music', 'https://www.tiktokv.com/share/video/1002/'),
      done('dl-other', 'https://www.youtube.com/watch?v=x'),
    ]);
    final archive = MockTikTokArchiveRepository(sampleCatalog);
    final container = ProviderContainer(
      overrides: [
        tikTokArchiveRepositoryProvider.overrideWithValue(archive),
        tiktokVideoCacheServiceProvider.overrideWith(
          (ref) =>
              TikTokVideoCacheService(cacheDirectory: Directory.systemTemp),
        ),
        downloaderRepositoryProvider.overrideWithValue(library),
        persistenceServiceProvider.overrideWithValue(FakePersistence()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(downloadListProvider, (_, _) {});
    final notifier = container.read(tikTokArchiveProvider.notifier);
    await notifier.initialized;
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final result = await notifier.purgeCollections({'Tech'});

    expect(result.filesDeleted, 1);
    expect(library.deleteFilesCalls, [true]);
    final catalog = container.read(tikTokArchiveProvider).catalog!;
    final names = catalog.collections.map((c) => c.name);
    expect(names, isNot(contains('Tech')));
    expect(names, contains('Music'));
    expect(catalog.videos.map((v) => v.id), isNot(contains('1001')));
    expect(container.read(downloadListProvider).valueOrNull!.map((e) => e.id), [
      'dl-music',
      'dl-other',
    ]);
  });
}
