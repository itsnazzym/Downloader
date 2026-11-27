import '../../domain/entities/tiktok_archive_catalog.dart';
import 'tiktok_collection_reconciliation_service.dart';

/// Merges a freshly parsed TikTok export into what the app already knows.
///
/// The official export lists favorites and collection *names* only; it never
/// says which collection holds a favorite. That membership comes from a
/// logged-in sync, so an import must never throw it away.
class TikTokArchiveMerger {
  const TikTokArchiveMerger();

  static const _service = TikTokCollectionReconciliationService();
  static const _special = {'Favoris non classés', 'Vidéos Likées'};

  /// The export is the source of truth for which videos are favorites/likes.
  /// [current] keeps every membership, collection id and sync state it had.
  /// Idempotent: merging the same export twice gives the same catalog.
  TikTokArchiveCatalog mergeExport(
    TikTokArchiveCatalog fresh,
    TikTokArchiveCatalog? current,
  ) {
    if (current == null) return fresh;

    final currentById = {for (final v in current.videos) v.id: v};
    final freshIds = <String>{};
    final videos = <TikTokArchiveItem>[];
    for (final video in fresh.videos) {
      freshIds.add(video.id);
      final old = currentById[video.id];
      if (old == null) {
        videos.add(video);
        continue;
      }
      final member = old.collectionIds.isNotEmpty;
      videos.add(
        video.copyWith(
          isFavorite: video.isFavorite || member,
          collectionIds: member ? old.collectionIds : null,
          collectionName: member ? old.collectionName : null,
          isDownloaded: old.isDownloaded,
          url: _hasCreatorUrl(old.url) && !_hasCreatorUrl(video.url)
              ? old.url
              : video.url,
        ),
      );
    }
    // A video the export no longer lists survives only when a collection
    // proved it (the API sees videos the export may predate).
    for (final old in current.videos) {
      if (!freshIds.contains(old.id) && old.collectionIds.isNotEmpty) {
        videos.add(old);
      }
    }

    // Keep every known collection; add export names that are still missing.
    // Names can repeat, so pair them one for one.
    final pool = <String, List<TikTokCollectionItem>>{};
    for (final c in fresh.collections) {
      if (!_special.contains(c.name)) (pool[c.name] ??= []).add(c);
    }
    final collections = <TikTokCollectionItem>[];
    for (final c in current.collections) {
      if (_special.contains(c.name)) continue;
      collections.add(c);
      final same = pool[c.name];
      if (same != null && same.isNotEmpty) same.removeAt(0);
    }
    for (final rest in pool.values) {
      collections.addAll(rest);
    }

    return _service.recount(
      fresh,
      videos: videos,
      collections: collections,
      suggestions: current.suggestions,
    );
  }

  /// Re-attaches memberships found in catalogs of a previous install (the app
  /// data folder was renamed) to [catalog]. Only videos already in [catalog]
  /// are touched, and collection ids already known are left alone, so running
  /// it again changes nothing. Recovered collections are marked incomplete
  /// because nothing proves their list is the whole folder.
  ({TikTokArchiveCatalog catalog, int collections, int memberships})
  recoverLegacy(
    TikTokArchiveCatalog catalog,
    List<TikTokArchiveCatalog> legacy,
  ) {
    final known = {for (final v in catalog.videos) v.id};
    final knownCollectionIds = {
      for (final c in catalog.collections) ?c.id,
    };
    final collections = <String, TikTokCollectionItem>{};
    final members = <String, Set<String>>{};
    final urls = <String, Map<String, String>>{};
    for (final old in legacy) {
      // Newest first: its name/cover/total win, memberships are unioned.
      for (final c in old.collections) {
        final id = c.id;
        if (id == null ||
            id.startsWith('legacy:') ||
            _special.contains(c.name) ||
            knownCollectionIds.contains(id)) {
          continue;
        }
        collections.putIfAbsent(id, () => c);
      }
      for (final v in old.videos) {
        if (!known.contains(v.id)) continue;
        for (final id in v.collectionIds) {
          if (!collections.containsKey(id)) continue;
          (members[id] ??= {}).add(v.id);
          (urls[id] ??= {})[v.id] = v.url;
        }
      }
    }
    if (collections.isEmpty) return (catalog: catalog, collections: 0, memberships: 0);

    final snapshots = [
      for (final c in collections.values)
        TikTokCollectionSnapshot(
          id: c.id!,
          name: c.name,
          coverUrl: c.coverUrl,
          declaredTotal: c.declaredTotal,
          videoIds: (members[c.id] ?? const <String>{}).toList(),
          videoUrls: urls[c.id] ?? const {},
          complete: false,
        ),
    ];
    final result = _service.applySnapshots(
      catalog,
      snapshots,
      collectionListComplete: false,
    );
    return (
      catalog: result.catalog,
      collections: snapshots.length,
      memberships: members.values.fold(0, (sum, ids) => sum + ids.length),
    );
  }

  static bool _hasCreatorUrl(String url) =>
      RegExp(r'https?://(?:www\.)?tiktok\.com/@[^/]+/video/\d+').hasMatch(url);
}
