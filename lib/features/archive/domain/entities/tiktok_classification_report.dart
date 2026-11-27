import 'package:flutter/foundation.dart';
import 'tiktok_archive_catalog.dart';

/// How much of the favorites is filed in a real TikTok collection, and why
/// the rest is not. Derived from a catalog, so it is cheap and always honest.
@immutable
class TikTokClassificationReport {
  final int videos;
  final int favorites;
  final int classified;

  /// Real collections (not "Favoris non classés" / "Vidéos Likées").
  final int collections;

  /// Collections that carry a TikTok id, i.e. were seen by a sync or recovered.
  final int linkedCollections;

  /// Linked collections whose membership list is known to be incomplete.
  final int partialCollections;

  const TikTokClassificationReport({
    required this.videos,
    required this.favorites,
    required this.classified,
    required this.collections,
    required this.linkedCollections,
    required this.partialCollections,
  });

  int get unclassified => favorites - classified;

  /// Only a logged-in TikTok session can tell which collection holds a favorite.
  bool get needsSync => unclassified > 0 || linkedCollections < collections;

  factory TikTokClassificationReport.fromCatalog(TikTokArchiveCatalog catalog) {
    var favorites = 0;
    var classified = 0;
    for (final video in catalog.videos) {
      if (!video.isFavorite) continue;
      favorites++;
      if (video.collectionIds.isNotEmpty) classified++;
    }
    var collections = 0;
    var linked = 0;
    var partial = 0;
    for (final collection in catalog.collections) {
      if (collection.name == 'Favoris non classés' ||
          collection.name == 'Vidéos Likées') {
        continue;
      }
      collections++;
      final id = collection.id;
      if (id == null || id.startsWith('legacy:')) continue;
      linked++;
      final declared = collection.declaredTotal;
      if (collection.syncComplete == false ||
          (declared != null && collection.videoCount < declared)) {
        partial++;
      }
    }
    return TikTokClassificationReport(
      videos: catalog.videos.length,
      favorites: favorites,
      classified: classified,
      collections: collections,
      linkedCollections: linked,
      partialCollections: partial,
    );
  }

  /// One French sentence for the status line every design already renders.
  String summary() {
    final parts = <String>[
      '$classified favoris classés dans $linkedCollections/$collections collections',
      '$unclassified non classés',
      if (partialCollections > 0)
        '$partialCollections collections à compléter (synchro partielle)',
    ];
    return parts.join(' · ');
  }
}
