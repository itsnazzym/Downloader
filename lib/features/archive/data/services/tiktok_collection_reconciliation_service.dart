import '../../domain/entities/tiktok_archive_catalog.dart';

class TikTokCollectionSyncResult {
  final TikTokArchiveCatalog catalog;
  final int updatedCollections;
  final int incompleteCollections;
  final bool collectionListComplete;

  const TikTokCollectionSyncResult({
    required this.catalog,
    required this.updatedCollections,
    required this.incompleteCollections,
    required this.collectionListComplete,
  });
}

class TikTokCollectionReconciliationService {
  const TikTokCollectionReconciliationService();

  TikTokCollectionSyncResult applySnapshots(
    TikTokArchiveCatalog catalog,
    List<TikTokCollectionSnapshot> snapshots, {
    required bool collectionListComplete,
  }) {
    final videos = List<TikTokArchiveItem>.of(catalog.videos);
    final videoIndexes = <String, int>{
      for (var index = 0; index < videos.length; index++)
        videos[index].id: index,
    };
    final collections = List<TikTokCollectionItem>.of(catalog.collections);
    var suggestions = List<TikTokCollectionSuggestion>.of(catalog.suggestions);
    final observedNames = snapshots
        .map((snapshot) => snapshot.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    final processed = <TikTokCollectionSnapshot>[];
    var incompleteCount = 0;
    final now = DateTime.now();

    for (final snapshot in snapshots) {
      final id = snapshot.id.trim();
      final name = snapshot.name.trim();
      final videoIds = snapshot.videoIds
          .where((id) => id.trim().isNotEmpty)
          .toSet();
      final complete =
          snapshot.complete && id.isNotEmpty && name.isNotEmpty;
      final error =
          snapshot.error ??
          (id.isEmpty || name.isEmpty ? 'invalid_collection' : null);
      final normalized = TikTokCollectionSnapshot(
        id: id,
        name: name,
        coverUrl: snapshot.coverUrl,
        declaredTotal: snapshot.declaredTotal,
        videoIds: videoIds.toList(growable: false),
        videoUrls: snapshot.videoUrls,
        complete: complete,
        error: complete ? null : error ?? 'collection_incomplete',
      );
      if (id.isEmpty || name.isEmpty) {
        incompleteCount++;
        continue;
      }
      processed.add(normalized);

      var collectionIndex = collections.indexWhere((item) => item.id == id);
      if (collectionIndex < 0) {
        final sameName = collections
            .where(
              (item) =>
                  (item.id == null || item.id!.startsWith('legacy:')) &&
                  item.name == name,
            )
            .toList();
        // The export lists some names twice (e.g. 127 entries, 123 names).
        // Id-less entries are empty placeholders, so any of them can take the
        // id; provisional `legacy:` entries may hold memberships, so they must
        // stay unambiguous.
        if (sameName.length == 1 || (sameName.isNotEmpty && sameName.every((item) => item.id == null))) {
          collectionIndex = collections.indexOf(sameName.first);
        }
      }
      final previous = collectionIndex >= 0
          ? collections[collectionIndex]
          : null;
      final previousLegacyId = previous?.id?.startsWith('legacy:') == true
          ? previous!.id
          : null;
      final updatedCollection = TikTokCollectionItem(
        id: id,
        name: name,
        coverUrl: snapshot.coverUrl ?? previous?.coverUrl,
        date: previous?.date,
        videoCount: previous?.videoCount ?? 0,
        declaredTotal: snapshot.declaredTotal,
        heuristicCount: 0,
        syncComplete: complete,
        syncError: complete ? null : normalized.error,
      );
      if (collectionIndex >= 0) {
        collections[collectionIndex] = updatedCollection;
      } else {
        collections.add(updatedCollection);
      }

      if (complete) {
        suggestions.removeWhere(
          (suggestion) =>
              suggestion.collectionId == id ||
              suggestion.collectionName == name,
        );
        // A user-approved suggestion may have been saved before TikTok IDs were
        // available. Promote that provisional membership to the stable ID now.
        final supersededIds =
            collections
                .where(
                  (item) =>
                      item.name == name &&
                      item.id != null &&
                      item.id!.startsWith('legacy:'),
                )
                .map((item) => item.id!)
                .toSet()
              ..add(id);
        if (previousLegacyId != null) supersededIds.add(previousLegacyId);
        for (var i = 0; i < videos.length; i++) {
          final video = videos[i];
          final hadSupersededMembership = video.collectionIds.any(
            supersededIds.contains,
          );
          final ids = video.collectionIds
              .where((value) => !supersededIds.contains(value))
              .toList();
          final legacyMatch =
              video.collectionIds.isEmpty &&
              video.collectionName == name &&
              video.collectionName != 'Vidéos Likées';
          if (hadSupersededMembership || legacyMatch) {
            videos[i] = _withCollectionLabels(
              video.copyWith(
                collectionIds: ids,
                collectionName: ids.isEmpty ? null : video.collectionName,
              ),
              collections,
            );
          }
        }
      } else {
        incompleteCount++;
        // A partial response still proves membership for every returned ID.
        // Preserve older memberships: missing IDs may simply be on pages that
        // TikTok did not return during this run.
        suggestions.removeWhere(
          (suggestion) =>
              videoIds.contains(suggestion.videoId) &&
              (suggestion.collectionId == id ||
                  suggestion.collectionName == name),
        );
      }

      for (final videoId in videoIds) {
        final videoIndex = videoIndexes[videoId];
        if (videoIndex == null) {
          videoIndexes[videoId] = videos.length;
          videos.add(
            TikTokArchiveItem(
              id: videoId,
              url: _safeVideoUrl(normalized.videoUrls[videoId], videoId),
              date: now,
              isFavorite: true,
              collectionIds: [id],
              collectionName: name,
            ),
          );
          continue;
        }
        final video = videos[videoIndex];
        final ids = {...video.collectionIds, id}.toList(growable: false);
        final snapshotUrl = normalized.videoUrls[videoId];
        final preferredUrl = _hasCreatorVideoUrl(video.url)
            ? video.url
            : _safeVideoUrl(snapshotUrl ?? video.url, videoId);
        videos[videoIndex] = _withCollectionLabels(
          video.copyWith(
            url: preferredUrl,
            isFavorite: true,
            collectionIds: ids,
            collectionName: name,
          ),
          collections,
        );
      }
    }

    if (collectionListComplete) {
      final currentIds = processed.map((snapshot) => snapshot.id).toSet();
      final removed = collections.where((collection) {
        if (_isSpecialCollection(collection.name)) return false;
        // An empty placeholder from the export whose name now has a real id
        // is a surplus duplicate (the account has fewer folders of that name).
        if (collection.id == null &&
            collection.videoCount == 0 &&
            collections.any(
              (other) => other.id != null && other.name == collection.name,
            )) {
          return true;
        }
        return collection.id != null
            ? !currentIds.contains(collection.id) &&
                  !observedNames.contains(collection.name)
            : !observedNames.contains(collection.name);
      }).toList();
      final removedIds = removed
          .map((collection) => collection.id)
          .whereType<String>()
          .toSet();
      final removedNames = removed.map((collection) => collection.name).toSet();
      collections.removeWhere(removed.contains);
      for (var i = 0; i < videos.length; i++) {
        final video = videos[i];
        final ids = video.collectionIds
            .where((id) => !removedIds.contains(id))
            .toList();
        if (ids.length != video.collectionIds.length) {
          videos[i] = _withCollectionLabels(
            video.copyWith(collectionIds: ids),
            collections,
          );
        }
      }
      suggestions.removeWhere(
        (suggestion) =>
            (suggestion.collectionId != null &&
                !currentIds.contains(suggestion.collectionId) &&
                !observedNames.contains(suggestion.collectionName)) ||
            (suggestion.collectionId == null &&
                !observedNames.contains(suggestion.collectionName)) ||
            removedNames.contains(suggestion.collectionName),
      );
    }

    final updatedCatalog = _recountCatalog(
      catalog,
      videos: videos,
      collections: collections,
      suggestions: suggestions,
    );
    return TikTokCollectionSyncResult(
      catalog: updatedCatalog,
      updatedCollections: processed.where((item) => item.complete).length,
      incompleteCollections: incompleteCount,
      collectionListComplete: collectionListComplete,
    );
  }

  TikTokArchiveCatalog addMappingSuggestions(
    TikTokArchiveCatalog catalog,
    Map<String, List<String>> mapping, {
    Map<String, int>? declaredTotals,
  }) {
    final videos = List<TikTokArchiveItem>.of(catalog.videos);
    final collections = List<TikTokCollectionItem>.of(catalog.collections);
    final suggestions = List<TikTokCollectionSuggestion>.of(
      catalog.suggestions,
    );
    final now = DateTime.now();
    for (final entry in mapping.entries) {
      final matches = collections
          .where((item) => item.name == entry.key)
          .toList();
      final collectionId = matches.length == 1 ? matches.single.id : null;
      if (matches.isEmpty) {
        collections.add(
          TikTokCollectionItem(
            name: entry.key,
            declaredTotal: declaredTotals?[entry.key],
            syncComplete: false,
            syncError: 'review_required',
          ),
        );
      }
      for (final videoId in entry.value.toSet()) {
        if (videoId.trim().isEmpty) continue;
        if (!videos.any((video) => video.id == videoId)) {
          videos.add(
            TikTokArchiveItem(
              id: videoId,
              url: _shareUrl(videoId),
              date: now,
              isFavorite: true,
            ),
          );
        }
        _addSuggestion(
          suggestions,
          TikTokCollectionSuggestion(
            videoId: videoId,
            collectionId: collectionId,
            collectionName: entry.key,
            reason: 'imported_mapping',
          ),
        );
      }
    }
    return _recountCatalog(
      catalog,
      videos: videos,
      collections: collections,
      suggestions: suggestions,
    );
  }

  TikTokArchiveCatalog applySuggestions(
    TikTokArchiveCatalog catalog,
    Set<String> suggestionKeys,
  ) {
    final selected = catalog.suggestions
        .where((suggestion) => suggestionKeys.contains(suggestion.key))
        .toList();
    if (selected.isEmpty) return catalog;

    final collections = List<TikTokCollectionItem>.of(catalog.collections);
    final videos = List<TikTokArchiveItem>.of(catalog.videos);
    for (final suggestion in selected) {
      var collection = collections
          .where(
            (item) => suggestion.collectionId != null
                ? item.id == suggestion.collectionId
                : item.name == suggestion.collectionName,
          )
          .firstOrNull;
      if (collection == null) {
        collection = TikTokCollectionItem(
          id: suggestion.collectionId,
          name: suggestion.collectionName,
        );
        collections.add(collection);
      }
      final videoIndex = videos.indexWhere(
        (video) => video.id == suggestion.videoId,
      );
      if (videoIndex < 0) continue;
      final video = videos[videoIndex];
      final stableCollection = collection.id == null
          ? TikTokCollectionItem(
              id: 'legacy:${collection.name.toLowerCase()}',
              name: collection.name,
              date: collection.date,
              videoCount: collection.videoCount,
              declaredTotal: collection.declaredTotal,
            )
          : collection;
      if (collection.id == null) {
        collections[collections.indexOf(collection)] = stableCollection;
      }
      final ids = {
        ...video.collectionIds,
        stableCollection.id!,
      }.toList(growable: false);
      videos[videoIndex] = _withCollectionLabels(
        video.copyWith(
          isFavorite: true,
          collectionIds: ids,
          collectionName: stableCollection.name,
        ),
        collections,
      );
    }
    final selectedKeys = selected.map((suggestion) => suggestion.key).toSet();
    return _recountCatalog(
      catalog,
      videos: videos,
      collections: collections,
      suggestions: catalog.suggestions
          .where((suggestion) => !selectedKeys.contains(suggestion.key))
          .toList(),
    );
  }

  TikTokArchiveCatalog resetCollection(
    TikTokArchiveCatalog catalog,
    String collectionKey,
  ) {
    final collection = catalog.collections
        .where((item) => item.id == collectionKey || item.name == collectionKey)
        .firstOrNull;
    final targetId = collection?.id;
    final targetName = collection?.name ?? collectionKey;
    final videos = catalog.videos.map((video) {
      if (targetId != null && video.collectionIds.contains(targetId)) {
        final remaining = video.collectionIds
            .where((id) => id != targetId)
            .toList();
        return _withCollectionLabels(
          video.copyWith(collectionIds: remaining),
          catalog.collections,
        );
      }
      if (video.collectionIds.isEmpty && video.collectionName == targetName) {
        return video.copyWith(clearCollection: true);
      }
      return video;
    }).toList();
    return _recountCatalog(
      catalog,
      videos: videos,
      collections: catalog.collections,
      suggestions: catalog.suggestions
          .where((suggestion) {
            if (targetId != null && suggestion.collectionId == targetId) {
              return false;
            }
            if (suggestion.collectionName == targetName) {
              return false;
            }
            return true;
          })
          .toList(),
    );
  }

  TikTokArchiveCatalog deleteCollection(
    TikTokArchiveCatalog catalog,
    String collectionKey,
  ) {
    final collection = catalog.collections
        .where((item) => item.id == collectionKey || item.name == collectionKey)
        .firstOrNull;
    final targetId = collection?.id;
    final targetName = collection?.name ?? collectionKey;
    final remainingCollections = catalog.collections.where((item) {
      if (targetId != null && item.id == targetId) return false;
      if (item.name == targetName) return false;
      return true;
    }).toList();
    final videos = catalog.videos.map((video) {
      if (targetId != null && video.collectionIds.contains(targetId)) {
        final remaining = video.collectionIds
            .where((id) => id != targetId)
            .toList();
        return _withCollectionLabels(
          video.copyWith(collectionIds: remaining),
          remainingCollections,
        );
      }
      if (video.collectionIds.isEmpty && video.collectionName == targetName) {
        return video.copyWith(clearCollection: true);
      }
      return video;
    }).toList();
    return _recountCatalog(
      catalog,
      videos: videos,
      collections: remainingCollections,
      suggestions: catalog.suggestions
          .where((suggestion) {
            if (targetId != null && suggestion.collectionId == targetId) {
              return false;
            }
            if (suggestion.collectionName == targetName) {
              return false;
            }
            return true;
          })
          .toList(),
    );
  }

  /// Removes [collectionKeys] (ids or names) and every video that only lived
  /// in them. A video also in a kept collection stays and just leaves the
  /// purged folders (a like alone does not keep it: most downloaded videos
  /// are liked too, so the purge would remove almost nothing). Returns the removed video ids so their
  /// downloaded files can be deleted too.
  ({
    TikTokArchiveCatalog catalog,
    Set<String> removedVideoIds,
    int keptSharedCount,
  })
  purgeCollections(TikTokArchiveCatalog catalog, Set<String> collectionKeys) {
    final targets = catalog.collections
        .where(
          (c) =>
              collectionKeys.contains(c.id) || collectionKeys.contains(c.name),
        )
        .toList();
    final targetIds = {for (final c in targets) ?c.id};
    final targetNames = {for (final c in targets) c.name, ...collectionKeys};

    final removed = <String>{};
    var keptShared = 0;
    for (final video in catalog.videos) {
      final ids = video.collectionIds;
      final inTarget = ids.isNotEmpty
          ? ids.any(targetIds.contains)
          : targetNames.contains(video.collectionName);
      if (!inTarget) continue;
      final onlyTargets = ids.isNotEmpty ? ids.every(targetIds.contains) : true;
      if (onlyTargets) {
        removed.add(video.id);
      } else {
        keptShared++;
      }
    }

    var updated = _recountCatalog(
      catalog,
      videos: catalog.videos.where((v) => !removed.contains(v.id)).toList(),
      collections: catalog.collections,
      suggestions: catalog.suggestions
          .where((s) => !removed.contains(s.videoId))
          .toList(),
    );
    for (final collection in targets) {
      updated = deleteCollection(updated, collection.id ?? collection.name);
    }
    return (
      catalog: updated,
      removedVideoIds: removed,
      keptSharedCount: keptShared,
    );
  }

  /// Recomputes counts, totals and the special collections after a merge.
  TikTokArchiveCatalog recount(
    TikTokArchiveCatalog original, {
    required List<TikTokArchiveItem> videos,
    required List<TikTokCollectionItem> collections,
    required List<TikTokCollectionSuggestion> suggestions,
  }) => _recountCatalog(
    original,
    videos: videos,
    collections: collections,
    suggestions: suggestions,
  );

  static void _addSuggestion(
    List<TikTokCollectionSuggestion> suggestions,
    TikTokCollectionSuggestion suggestion,
  ) {
    if (!suggestions.any((item) => item.key == suggestion.key)) {
      suggestions.add(suggestion);
    }
  }

  static bool _isSpecialCollection(String name) =>
      name == 'Favoris non classés' || name == 'Vidéos Likées';

  static String _shareUrl(String videoId) =>
      'https://www.tiktokv.com/share/video/$videoId/';

  static String _safeVideoUrl(String? value, String videoId) {
    if (value != null &&
        RegExp(
          r'^https?://(?:www\.)?tiktok\.com/@[^/]+/video/' +
              RegExp.escape(videoId) +
              r'(?:[/?#]|$)',
        ).hasMatch(value)) {
      return value;
    }
    if (value != null &&
        RegExp(
          r'^https?://(?:www\.)?tiktokv\.com/share/video/' +
              RegExp.escape(videoId) +
              r'(?:[/?#]|$)',
        ).hasMatch(value)) {
      return value;
    }
    return _shareUrl(videoId);
  }

  static bool _hasCreatorVideoUrl(String value) => RegExp(
    r'https?://(?:www\.)?tiktok\.com/@[^/]+/video/\d+',
  ).hasMatch(value);

  static TikTokArchiveItem _withCollectionLabels(
    TikTokArchiveItem video,
    List<TikTokCollectionItem> collections,
  ) {
    if (video.collectionIds.isEmpty) {
      if (video.collectionName == 'Vidéos Likées' ||
          video.collectionName == 'Favoris non classés' ||
          video.collectionName == null) {
        return video;
      }
      return video.copyWith(clearCollection: true);
    }
    final names = video.collectionIds
        .map(
          (id) => collections.where((item) => item.id == id).firstOrNull?.name,
        )
        .whereType<String>()
        .toSet()
        .toList();
    if (names.isEmpty) return video;
    return video.copyWith(collectionName: names.join(' · '));
  }

  static TikTokArchiveCatalog _recountCatalog(
    TikTokArchiveCatalog original, {
    required List<TikTokArchiveItem> videos,
    required List<TikTokCollectionItem> collections,
    required List<TikTokCollectionSuggestion> suggestions,
  }) {
    final countsById = <String, int>{};
    final countsByName = <String, int>{};
    final originalVideos = {
      for (final video in original.videos) video.id: video,
    };
    final addedFavoriteYears = <int, int>{};
    var addedFavorites = 0;
    var addedOverlaps = 0;
    var unclassifiedFavorites = 0;
    var likedVideos = 0;
    for (final video in videos) {
      final previous = originalVideos[video.id];
      if (video.isFavorite && (previous == null || !previous.isFavorite)) {
        addedFavorites++;
      }
      if (previous == null) {
        addedFavoriteYears[video.date.year] =
            (addedFavoriteYears[video.date.year] ?? 0) + 1;
      }
      if (video.isFavorite &&
          video.isLiked &&
          (previous == null || !previous.isFavorite || !previous.isLiked)) {
        addedOverlaps++;
      }
      for (final id in video.collectionIds.toSet()) {
        countsById[id] = (countsById[id] ?? 0) + 1;
      }
      if (video.collectionIds.isEmpty &&
          video.collectionName != null &&
          !_isSpecialCollection(video.collectionName!)) {
        countsByName[video.collectionName!] =
            (countsByName[video.collectionName!] ?? 0) + 1;
      }
      if (video.isFavorite &&
          video.collectionIds.isEmpty &&
          (video.collectionName == null ||
              video.collectionName == 'Vidéos Likées')) {
        unclassifiedFavorites++;
      }
      if (video.isLiked) likedVideos++;
    }

    final updatedCollections = <TikTokCollectionItem>[];
    if (unclassifiedFavorites > 0) {
      updatedCollections.add(
        TikTokCollectionItem(
          name: 'Favoris non classés',
          videoCount: unclassifiedFavorites,
        ),
      );
    }
    for (final collection in collections) {
      if (_isSpecialCollection(collection.name)) continue;
      updatedCollections.add(
        collection.copyWith(
          videoCount: collection.id == null
              ? (countsByName[collection.name] ?? 0)
              : (countsById[collection.id!] ?? 0),
        ),
      );
    }
    if (likedVideos > 0) {
      updatedCollections.add(
        TikTokCollectionItem(name: 'Vidéos Likées', videoCount: likedVideos),
      );
    }
    updatedCollections.sort((a, b) {
      if (a.name == 'Favoris non classés') return -1;
      if (b.name == 'Favoris non classés') return 1;
      if (a.videoCount != b.videoCount) {
        return b.videoCount.compareTo(a.videoCount);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return TikTokArchiveCatalog(
      videos: videos,
      collections: updatedCollections,
      suggestions: suggestions,
      sounds: original.sounds,
      totalFavorites: original.totalFavorites + addedFavorites,
      totalLikes: original.totalLikes,
      totalOverlap: original.totalOverlap + addedOverlaps,
      yearCounts: addedFavoriteYears.isEmpty
          ? original.yearCounts
          : {
              ...original.yearCounts,
              for (final entry in addedFavoriteYears.entries)
                entry.key: (original.yearCounts[entry.key] ?? 0) + entry.value,
            },
    );
  }
}
