import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/features/archive/data/services/tiktok_collection_reconciliation_service.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/domain/repositories/i_tiktok_archive_repository.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';

class _MemoryArchiveRepository implements ITikTokArchiveRepository {
  TikTokArchiveCatalog? catalog;

  _MemoryArchiveRepository([this.catalog]);

  @override
  Future<TikTokArchiveCatalog?> getCachedCatalog() async => catalog;

  @override
  Future<TikTokArchiveCatalog> importFromFile(String filePath) async =>
      catalog ?? TikTokArchiveCatalog.empty;

  @override
  Future<void> saveCatalog(TikTokArchiveCatalog value) async {
    catalog = value;
  }

  @override
  Future<void> clearCatalog() async {
    catalog = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cached TikTok export URLs are repaired when the catalog loads', () {
    final video = TikTokArchiveItem.fromJson({
      'id': '761543876078210326',
      'url': 'https://www.tiktok.com/video/761543876078210326',
      'date': '2026-09-24T00:00:00.000',
    });

    expect(
      video.url,
      'https://www.tiktokv.com/share/video/761543876078210326/',
    );
  });

  test('sync repairs an existing export URL without a new video link', () {
    const videoId = '761543876078210326';
    final oldCatalog = TikTokArchiveCatalog(
      videos: [
        TikTokArchiveItem(
          id: videoId,
          url: 'https://www.tiktok.com/video/$videoId',
          date: DateTime(2026, 9, 24),
          isFavorite: true,
        ),
      ],
      collections: const [],
      sounds: const [],
      totalFavorites: 1,
      totalLikes: 0,
      totalOverlap: 0,
      yearCounts: const {2026: 1},
    );

    final updated = const TikTokCollectionReconciliationService()
        .applySnapshots(oldCatalog, [
          const TikTokCollectionSnapshot(
            id: 'collection-a',
            name: 'Tech',
            declaredTotal: 1,
            videoIds: [videoId],
            complete: true,
          ),
        ], collectionListComplete: true);

    expect(
      updated.catalog.videos.single.url,
      'https://www.tiktokv.com/share/video/$videoId/',
    );
  });

  final catalog = TikTokArchiveCatalog(
    videos: [
      TikTokArchiveItem(
        id: '1001',
        url: 'https://www.tiktok.com/video/1001',
        date: DateTime(2026, 1, 1),
        isFavorite: true,
        collectionId: 'collection-a',
        collectionName: 'Tech',
      ),
      TikTokArchiveItem(
        id: '1002',
        url: 'https://www.tiktok.com/video/1002',
        date: DateTime(2026, 1, 2),
        isFavorite: true,
      ),
      TikTokArchiveItem(
        id: '1003',
        url: 'https://www.tiktok.com/video/1003',
        date: DateTime(2026, 1, 3),
        isLiked: true,
        collectionName: 'Vidéos Likées',
      ),
    ],
    collections: const [
      TikTokCollectionItem(
        id: 'collection-a',
        name: 'Tech',
        videoCount: 1,
        declaredTotal: 1,
        syncComplete: true,
      ),
    ],
    sounds: const [],
    totalFavorites: 2,
    totalLikes: 1,
    totalOverlap: 0,
    yearCounts: {2026: 3},
  );

  test(
    'complete snapshots replace only that collection membership by ID',
    () async {
      final repository = _MemoryArchiveRepository(catalog);
      final container = ProviderContainer(
        overrides: [
          tikTokArchiveRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(tikTokArchiveProvider.notifier);
      await notifier.initialized;
      await notifier.applyCollectionSync([
        const TikTokCollectionSnapshot(
          id: 'collection-a',
          name: 'Tech',
          declaredTotal: 1,
          videoIds: ['1002'],
          complete: true,
        ),
      ], collectionListComplete: true);

      final updated = container.read(tikTokArchiveProvider).catalog!;
      final movedOut = updated.videos.firstWhere((video) => video.id == '1001');
      final movedIn = updated.videos.firstWhere((video) => video.id == '1002');
      final liked = updated.videos.firstWhere((video) => video.id == '1003');
      expect(movedOut.collectionId, isNull);
      expect(movedIn.collectionId, 'collection-a');
      expect(movedIn.collectionName, 'Tech');
      expect(liked.collectionName, 'Vidéos Likées');
      expect(
        updated.collections
            .firstWhere((collection) => collection.id == 'collection-a')
            .videoCount,
        1,
      );
      expect(updated.suggestions, isEmpty);
    },
  );

  test(
    'incomplete snapshots add verified IDs and preserve prior membership',
    () async {
      final repository = _MemoryArchiveRepository(catalog);
      final container = ProviderContainer(
        overrides: [
          tikTokArchiveRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(tikTokArchiveProvider.notifier);
      await notifier.initialized;
      await notifier.applyCollectionSync([
        const TikTokCollectionSnapshot(
          id: 'collection-a',
          name: 'Tech',
          declaredTotal: 2,
          videoIds: ['1002'],
          videoUrls: {'1002': 'https://www.tiktok.com/@creator/video/1002'},
          complete: false,
          error: 'pagination_incomplete',
        ),
      ], collectionListComplete: true);

      var updated = container.read(tikTokArchiveProvider).catalog!;
      expect(
        updated.videos.firstWhere((video) => video.id == '1001').collectionId,
        'collection-a',
      );
      expect(
        updated.videos.firstWhere((video) => video.id == '1002').collectionId,
        'collection-a',
      );
      expect(
        updated.videos.firstWhere((video) => video.id == '1002').url,
        'https://www.tiktok.com/@creator/video/1002',
      );
      expect(updated.suggestions, isEmpty);
      expect(
        updated.collections
            .firstWhere((item) => item.id == 'collection-a')
            .videoCount,
        2,
      );
      expect(
        updated.collections
            .firstWhere((item) => item.id == 'collection-a')
            .syncComplete,
        isFalse,
      );

      await notifier.applyCollectionSync([
        const TikTokCollectionSnapshot(
          id: 'collection-a',
          name: 'Tech',
          declaredTotal: 2,
          videoIds: ['1002'],
          complete: false,
          error: 'pagination_incomplete',
        ),
      ], collectionListComplete: false);
      updated = container.read(tikTokArchiveProvider).catalog!;
      expect(
        updated.videos.firstWhere((video) => video.id == '1002').collectionId,
        'collection-a',
      );
      expect(
        updated.videos.firstWhere((video) => video.id == '1001').collectionId,
        'collection-a',
      );
    },
  );

  test('collection poster cover survives sync and catalog persistence', () {
    const coverUrl = 'https://p16-sign-va.tiktokcdn.com/cover.jpg';
    final result = const TikTokCollectionReconciliationService().applySnapshots(
      catalog,
      [
        TikTokCollectionSnapshot(
          id: 'collection-a',
          name: 'Tech',
          coverUrl: coverUrl,
          declaredTotal: 1,
          videoIds: ['1001'],
          complete: true,
        ),
      ],
      collectionListComplete: false,
    );

    final saved = TikTokArchiveCatalog.fromJson(result.catalog.toJson());
    expect(
      saved.collections
          .firstWhere((collection) => collection.id == 'collection-a')
          .coverUrl,
      coverUrl,
    );
  });

  test(
    'legacy cached assignments migrate into suggestions without data loss',
    () {
      final migrated = TikTokArchiveCatalog.fromJson({
        'videos': [
          {
            'id': '1001',
            'url': 'https://www.tiktok.com/video/1001',
            'date': '2026-01-01T00:00:00.000',
            'isFavorite': true,
            'collectionId': 'legacy-tech-id',
            'collectionName': 'Tech',
          },
          {
            'id': '1002',
            'url': 'https://www.tiktok.com/video/1002',
            'date': '2026-01-02T00:00:00.000',
            'isLiked': true,
            'collectionName': 'Vidéos Likées',
          },
        ],
        'collections': [
          {
            'id': 'legacy-tech-id',
            'name': 'Tech',
            'videoCount': 1,
            'declaredTotal': 1,
          },
        ],
        'sounds': [],
        'totalFavorites': 1,
        'totalLikes': 1,
        'totalOverlap': 0,
        'yearCounts': {'2026': 2},
      });

      expect(
        migrated.videos.firstWhere((video) => video.id == '1001').collectionId,
        isNull,
      );
      expect(
        migrated.videos
            .firstWhere((video) => video.id == '1001')
            .collectionName,
        isNull,
      );
      expect(migrated.suggestions.single.videoId, '1001');
      expect(migrated.suggestions.single.collectionName, 'Tech');
      expect(migrated.suggestions.single.collectionId, 'legacy-tech-id');
      expect(
        migrated.videos
            .firstWhere((video) => video.id == '1002')
            .collectionName,
        'Vidéos Likées',
      );
    },
  );

  test('deleteCollection removes collection and unassigns videos while keeping them in catalog', () {
    const service = TikTokCollectionReconciliationService();
    final catalog = TikTokArchiveCatalog(
      videos: [
        TikTokArchiveItem(
          id: 'v1',
          url: 'https://www.tiktokv.com/share/video/v1/',
          date: DateTime(2026, 1, 1),
          isFavorite: true,
          collectionIds: const ['col-1'],
          collectionName: 'Dossier 1',
        ),
        TikTokArchiveItem(
          id: 'v2',
          url: 'https://www.tiktokv.com/share/video/v2/',
          date: DateTime(2026, 1, 2),
          isFavorite: true,
          collectionIds: const ['col-1', 'col-2'],
          collectionName: 'Dossier 1 · Dossier 2',
        ),
        TikTokArchiveItem(
          id: 'v3',
          url: 'https://www.tiktokv.com/share/video/v3/',
          date: DateTime(2026, 1, 3),
          isFavorite: true,
          collectionIds: const ['col-2'],
          collectionName: 'Dossier 2',
        ),
      ],
      collections: const [
        TikTokCollectionItem(id: 'col-1', name: 'Dossier 1', videoCount: 2),
        TikTokCollectionItem(id: 'col-2', name: 'Dossier 2', videoCount: 2),
      ],
      suggestions: const [
        TikTokCollectionSuggestion(
          videoId: 'v1',
          collectionName: 'Dossier 1',
          collectionId: 'col-1',
          reason: 'test',
        ),
      ],
      sounds: const [],
      totalFavorites: 3,
      totalLikes: 0,
      totalOverlap: 0,
      yearCounts: {2026: 3},
    );

    final updated = service.deleteCollection(catalog, 'col-1');

    // col-1 should be removed
    expect(updated.collections.map((c) => c.name), isNot(contains('Dossier 1')));
    expect(updated.collections.map((c) => c.name), contains('Dossier 2'));

    // Suggestions for col-1 should be removed
    expect(updated.suggestions, isEmpty);

    // v1 is still in catalog, but unassigned (becomes unclassified favorite)
    final v1 = updated.videos.firstWhere((v) => v.id == 'v1');
    expect(v1.collectionIds, isEmpty);
    expect(v1.collectionName, isNull);
    expect(v1.isFavorite, isTrue);

    // v2 now only has col-2
    final v2 = updated.videos.firstWhere((v) => v.id == 'v2');
    expect(v2.collectionIds, ['col-2']);
    expect(v2.collectionName, 'Dossier 2');

    // v3 is unchanged
    final v3 = updated.videos.firstWhere((v) => v.id == 'v3');
    expect(v3.collectionIds, ['col-2']);
    expect(v3.collectionName, 'Dossier 2');
  });
}
