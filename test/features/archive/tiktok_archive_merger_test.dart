import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/features/archive/data/datasources/tiktok_archive_parser.dart';
import 'package:tapload/features/archive/data/datasources/tiktok_archive_storage.dart';
import 'package:tapload/features/archive/data/repositories/tiktok_archive_repository_impl.dart';
import 'package:tapload/features/archive/data/services/tiktok_archive_merger.dart';
import 'package:tapload/features/archive/data/services/tiktok_collection_reconciliation_service.dart';
import 'package:tapload/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:tapload/features/archive/domain/entities/tiktok_classification_report.dart';
import 'package:path/path.dart' as p;

String _url(String id) => 'https://www.tiktokv.com/share/video/$id/';

/// Same shape as the official TikTok export: favorites carry only Link+Date,
/// collections carry only a name, and two collections share a name.
const _export = '''
{"Likes and Favorites": {
  "Favorite Collection": {"FavoriteCollectionList": [
    {"Date": "2026-01-01 10:00:00", "FavoriteCollection": "wowww"},
    {"Date": "2026-02-01 10:00:00", "FavoriteCollection": "wowww"},
    {"Date": "2026-03-01 10:00:00", "FavoriteCollection": "tech"}
  ]},
  "Favorite Videos": {"FavoriteVideoList": [
    {"Date": "2026-05-01 10:00:00", "Link": "https://www.tiktokv.com/share/video/1001/"},
    {"Date": "2026-05-02 10:00:00", "Link": "https://www.tiktokv.com/share/video/1002/"},
    {"Date": "2026-05-03 10:00:00", "Link": "https://www.tiktokv.com/share/video/1003/"}
  ]},
  "Like List": {"ItemFavoriteList": [
    {"date": "2026-05-04 10:00:00", "link": "https://www.tiktokv.com/share/video/1004/"}
  ]}
}}
''';

TikTokArchiveCatalog _legacy({Map<String, List<String>> members = const {}}) {
  final ids = {for (final e in members.entries) e.key: e.value};
  final videoIds = {for (final v in members.values.expand((x) => x)) v};
  return TikTokArchiveCatalog(
    videos: [
      for (final id in videoIds)
        TikTokArchiveItem(
          id: id,
          url: 'https://www.tiktok.com/@someone/video/$id',
          date: DateTime(2026, 4, 1),
          isFavorite: true,
          collectionIds: [
            for (final e in ids.entries)
              if (e.value.contains(id)) e.key,
          ],
        ),
    ],
    collections: [
      for (final e in ids.entries)
        TikTokCollectionItem(
          id: e.key,
          name: _names[e.key]!,
          declaredTotal: 10,
          videoCount: e.value.length,
          syncComplete: true,
        ),
    ],
    sounds: const [],
    totalFavorites: videoIds.length,
    totalLikes: 0,
    totalOverlap: 0,
    yearCounts: const {},
  );
}

const _names = {'c-wow-a': 'wowww', 'c-wow-b': 'wowww', 'c-tech': 'tech'};

Map<String, dynamic> _json(TikTokArchiveCatalog c) => c.toJson();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const merger = TikTokArchiveMerger();

  late TikTokArchiveCatalog fresh;
  setUp(() async {
    fresh = await TikTokArchiveParser.parseFromString(_export);
  });

  test('the export alone files no favorite: it has no membership data', () {
    final report = TikTokClassificationReport.fromCatalog(fresh);
    expect(report.favorites, 3);
    expect(report.classified, 0);
    expect(report.unclassified, 3);
    expect(report.collections, 3);
    expect(report.linkedCollections, 0);
    expect(report.needsSync, isTrue);
  });

  group('mergeExport', () {
    final synced = TikTokCollectionReconciliationService().applySnapshots(
      TikTokArchiveCatalog.empty,
      [
        const TikTokCollectionSnapshot(
          id: 'c-tech',
          name: 'tech',
          videoIds: ['1001', '9999'],
          complete: true,
        ),
      ],
      collectionListComplete: false,
    ).catalog;

    test('importing again keeps what a sync already filed', () {
      final merged = merger.mergeExport(fresh, synced);

      final video = merged.videos.firstWhere((v) => v.id == '1001');
      expect(video.collectionIds, ['c-tech']);
      expect(video.url, _url('1001'));
      final tech = merged.collections.firstWhere((c) => c.id == 'c-tech');
      expect(tech.videoCount, 2); // 1001 + 9999 (proved by the API)
      expect(tech.syncComplete, isTrue);
      expect(
        merged.videos.map((v) => v.id),
        containsAll(['1001', '1002', '1003', '1004', '9999']),
      );
      // "tech" from the export pairs with the synced one: no empty twin.
      expect(merged.collections.where((c) => c.name == 'tech'), hasLength(1));
      // The two same-name export entries both survive.
      expect(merged.collections.where((c) => c.name == 'wowww'), hasLength(2));
    });

    test('is idempotent', () {
      final once = merger.mergeExport(fresh, synced);
      final twice = merger.mergeExport(fresh, once);
      expect(_json(twice), _json(once));
    });

    test('drops a favorite the export no longer lists unless a collection proved it', () {
      final current = merger.mergeExport(fresh, synced);
      final smaller = TikTokArchiveCatalog(
        videos: fresh.videos.where((v) => v.id != '1002').toList(),
        collections: fresh.collections,
        sounds: fresh.sounds,
        totalFavorites: 2,
        totalLikes: fresh.totalLikes,
        totalOverlap: 0,
        yearCounts: fresh.yearCounts,
      );
      final merged = merger.mergeExport(smaller, current);
      final ids = merged.videos.map((v) => v.id);
      expect(ids, isNot(contains('1002')));
      expect(ids, contains('9999'));
    });

    test('with nothing saved yet the parsed export is returned as is', () {
      expect(identical(merger.mergeExport(fresh, null), fresh), isTrue);
    });
  });

  group('recoverLegacy', () {
    final legacy = _legacy(
      members: {
        'c-tech': ['1001', '7777'],
        'c-wow-a': ['1002'],
        'c-wow-b': ['1003'],
      },
    );

    test('re-files known videos, fills id-less export collections, invents nothing', () {
      final result = merger.recoverLegacy(fresh, [legacy]);
      final catalog = result.catalog;

      expect(catalog.videos.map((v) => v.id), isNot(contains('7777')));
      expect(catalog.videos.length, fresh.videos.length);
      expect(
        catalog.videos.firstWhere((v) => v.id == '1001').collectionIds,
        ['c-tech'],
      );
      expect(result.memberships, 3);
      expect(result.collections, 3);
      // Both same-name export entries took one id each: no empty leftovers.
      final wow = catalog.collections.where((c) => c.name == 'wowww').toList();
      expect(wow.map((c) => c.id), unorderedEquals(['c-wow-a', 'c-wow-b']));
      expect(wow.every((c) => c.videoCount == 1), isTrue);
      // Nothing proves the legacy lists are whole.
      expect(catalog.collections.every((c) => c.syncComplete != true), isTrue);
      final report = TikTokClassificationReport.fromCatalog(catalog);
      expect(report.classified, 3);
      expect(report.unclassified, 0);
    });

    test('is idempotent and never downgrades a collection a sync completed', () {
      final once = merger.recoverLegacy(fresh, [legacy]).catalog;
      final completed = TikTokCollectionReconciliationService().applySnapshots(
        once,
        [
          const TikTokCollectionSnapshot(
            id: 'c-tech',
            name: 'tech',
            videoIds: ['1001'],
            complete: true,
          ),
        ],
        collectionListComplete: false,
      ).catalog;
      final again = merger.recoverLegacy(completed, [legacy]).catalog;
      expect(_json(again), _json(completed));
      expect(
        again.collections.firstWhere((c) => c.id == 'c-tech').syncComplete,
        isTrue,
      );
    });

    test('a full account list removes the surplus empty export duplicate', () {
      final withOneWow = TikTokCollectionReconciliationService().applySnapshots(
        fresh,
        [
          const TikTokCollectionSnapshot(
            id: 'c-wow-a',
            name: 'wowww',
            videoIds: ['1002'],
            complete: true,
          ),
          const TikTokCollectionSnapshot(
            id: 'c-tech',
            name: 'tech',
            videoIds: ['1001'],
            complete: true,
          ),
        ],
        collectionListComplete: true,
      ).catalog;
      expect(
        withOneWow.collections.where((c) => c.name == 'wowww'),
        hasLength(1),
      );
    });
  });

  group('repository', () {
    late Directory root;
    late File exportFile;
    late TikTokArchiveRepositoryImpl repository;
    late Directory legacyDir;
    late Directory currentDir;

    setUp(() {
      root = Directory.systemTemp.createTempSync('tiktok_import_test');
      addTearDown(() => root.deleteSync(recursive: true));
      currentDir = Directory(p.join(root.path, 'TapLoad'))..createSync();
      legacyDir = Directory(p.join(root.path, 'modern_downloader', 'tiktok_archive'))
        ..createSync(recursive: true);
      File(p.join(legacyDir.path, 'tiktok_archive_catalog.json'))
          .writeAsStringSync(jsonEncode(_legacy(members: {
        'c-tech': ['1001'],
        'c-wow-a': ['1002'],
      }).toJson()));
      exportFile = File(p.join(root.path, 'user_data_tiktok.json'))
        ..writeAsStringSync(_export);
      repository = TikTokArchiveRepositoryImpl(
        storage: TikTokArchiveStorage(supportDirectory: currentDir),
      );
    });

    test('first import recovers memberships from the old install', () async {
      final catalog = await repository.importFromFile(exportFile.path);
      expect(
        TikTokClassificationReport.fromCatalog(catalog).classified,
        2,
      );
      final saved = await repository.getCachedCatalog();
      expect(_json(saved!), _json(catalog));
    });

    test('importing twice gives the same catalog and keeps a backup', () async {
      final first = await repository.importFromFile(exportFile.path);
      final second = await repository.importFromFile(exportFile.path);
      expect(_json(second), _json(first));
      final archive = Directory(p.join(currentDir.path, 'tiktok_archive'));
      expect(
        archive.listSync().map((f) => p.basename(f.path)),
        anyElement(startsWith('tiktok_archive_catalog.json.bak-')),
      );
      // The old install's file is never touched.
      expect(
        File(p.join(legacyDir.path, 'tiktok_archive_catalog.json')).existsSync(),
        isTrue,
      );
    });

    test('a catalog with no membership is healed from the old install on load', () async {
      final flat = merger.mergeExport(fresh, null);
      await TikTokArchiveStorage(supportDirectory: currentDir).saveCatalog(flat);

      final healed = await repository.getCachedCatalog();
      expect(healed!.videos.where((v) => v.collectionIds.isNotEmpty), hasLength(2));
    });
  });
}
