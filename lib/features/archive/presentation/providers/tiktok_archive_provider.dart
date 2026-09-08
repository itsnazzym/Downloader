import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tiktok_archive_catalog.dart';
import '../../domain/repositories/i_tiktok_archive_repository.dart';
import '../../data/repositories/tiktok_archive_repository_impl.dart';
import '../../../downloader/presentation/providers/downloader_provider.dart';
import '../../../../core/logger/logger_service.dart';
import '../../../../core/services/local_server_service.dart';
import 'tiktok_video_cache_provider.dart';

enum TikTokStatusFilter { all, favoritesOnly, likesOnly }

enum TikTokViewMode { hub, collections, list, feed, tinder }

@immutable
class TikTokArchiveFilter {
  final String searchQuery;
  final int? selectedYear;
  final String? selectedCollection;
  final TikTokStatusFilter statusFilter;
  final bool showSounds;

  const TikTokArchiveFilter({
    this.searchQuery = '',
    this.selectedYear,
    this.selectedCollection,
    this.statusFilter = TikTokStatusFilter.all,
    this.showSounds = false,
  });

  TikTokArchiveFilter copyWith({
    String? searchQuery,
    ValueGetter<int?>? selectedYear,
    ValueGetter<String?>? selectedCollection,
    TikTokStatusFilter? statusFilter,
    bool? showSounds,
  }) {
    return TikTokArchiveFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedYear: selectedYear != null ? selectedYear() : this.selectedYear,
      selectedCollection: selectedCollection != null ? selectedCollection() : this.selectedCollection,
      statusFilter: statusFilter ?? this.statusFilter,
      showSounds: showSounds ?? this.showSounds,
    );
  }
}

@immutable
class TikTokArchiveState {
  final bool isLoading;
  final TikTokArchiveCatalog? catalog;
  final TikTokArchiveFilter filter;
  final Set<String> selectedIds;
  final String? errorMessage;
  final bool isBatchDownloading;
  final int batchCompletedCount;
  final int batchTotalCount;
  final TikTokViewMode viewMode;

  const TikTokArchiveState({
    this.isLoading = false,
    this.catalog,
    this.filter = const TikTokArchiveFilter(),
    this.selectedIds = const {},
    this.errorMessage,
    this.isBatchDownloading = false,
    this.batchCompletedCount = 0,
    this.batchTotalCount = 0,
    this.viewMode = TikTokViewMode.hub,
  });

  bool get hasCatalog => catalog != null && catalog!.videos.isNotEmpty;

  TikTokArchiveState copyWith({
    bool? isLoading,
    TikTokArchiveCatalog? catalog,
    TikTokArchiveFilter? filter,
    Set<String>? selectedIds,
    String? errorMessage,
    bool? isBatchDownloading,
    int? batchCompletedCount,
    int? batchTotalCount,
    TikTokViewMode? viewMode,
  }) {
    return TikTokArchiveState(
      isLoading: isLoading ?? this.isLoading,
      catalog: catalog ?? this.catalog,
      filter: filter ?? this.filter,
      selectedIds: selectedIds ?? this.selectedIds,
      errorMessage: errorMessage,
      isBatchDownloading: isBatchDownloading ?? this.isBatchDownloading,
      batchCompletedCount: batchCompletedCount ?? this.batchCompletedCount,
      batchTotalCount: batchTotalCount ?? this.batchTotalCount,
      viewMode: viewMode ?? this.viewMode,
    );
  }
}

final tikTokArchiveRepositoryProvider = Provider<ITikTokArchiveRepository>((ref) {
  return TikTokArchiveRepositoryImpl();
});

final tikTokArchiveProvider = StateNotifierProvider<TikTokArchiveNotifier, TikTokArchiveState>((ref) {
  final repo = ref.watch(tikTokArchiveRepositoryProvider);
  return TikTokArchiveNotifier(repo, ref);
});

class TikTokArchiveNotifier extends StateNotifier<TikTokArchiveState> {
  final ITikTokArchiveRepository _repository;
  final Ref _ref;

  late final Future<void> initialized;

  TikTokArchiveNotifier(this._repository, this._ref) : super(const TikTokArchiveState()) {
    initialized = _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    try {
      final cached = await _repository.getCachedCatalog();
      if (cached != null && cached.videos.isNotEmpty) {
        final hasMapped = cached.collections.any((c) => c.videoCount > 0);
        if (hasMapped) {
          state = state.copyWith(isLoading: false, catalog: cached);
          return;
        }
      }

      // Auto-discover typical user export if cached is not yet saved or needs mapping
      const defaultPath = r'C:\Users\entre\Downloads\tiktok_data\user_data_tiktok.json';
      if (File(defaultPath).existsSync()) {
        await importFromPath(defaultPath);
        return;
      }

      state = state.copyWith(isLoading: false);
    } catch (e, st) {
      LoggerService.e('Error initializing TikTokArchiveNotifier: $e', e, st);
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setViewMode(TikTokViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  Future<void> importFromPath(String filePath) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final catalog = await _repository.importFromFile(filePath);
      state = state.copyWith(
        isLoading: false,
        catalog: catalog,
        selectedIds: {},
      );
    } catch (e, st) {
      LoggerService.e('Failed to import TikTok archive from $filePath: $e', e, st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Échec de l\'importation: $e',
      );
    }
  }

  Future<void> pickAndImportFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Sélectionner l\'export JSON TikTok',
      );

      if (result != null && result.files.single.path != null) {
        await importFromPath(result.files.single.path!);
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Sélection annulée ou invalide: $e');
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(filter: state.filter.copyWith(searchQuery: query.trim()));
  }

  void selectYear(int? year) {
    state = state.copyWith(
      filter: state.filter.copyWith(selectedYear: () => year),
    );
  }

  void selectCollection(String? collectionName) {
    state = state.copyWith(
      filter: state.filter.copyWith(selectedCollection: () => collectionName),
    );
  }

  void setStatusFilter(TikTokStatusFilter status) {
    state = state.copyWith(
      filter: state.filter.copyWith(statusFilter: status),
    );
  }

  void setShowSounds(bool showSounds) {
    state = state.copyWith(
      filter: state.filter.copyWith(showSounds: showSounds),
    );
  }

  void toggleSelection(String id) {
    final updated = Set<String>.from(state.selectedIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = state.copyWith(selectedIds: updated);
  }

  void selectAll(List<TikTokArchiveItem> items) {
    final updated = Set<String>.from(state.selectedIds);
    for (final item in items) {
      updated.add(item.id);
    }
    state = state.copyWith(selectedIds: updated);
  }

  void clearSelection() {
    state = state.copyWith(selectedIds: const {});
  }

  void resetFilters() {
    state = state.copyWith(
      filter: const TikTokArchiveFilter(),
      selectedIds: const {},
    );
  }

  /// Updates collection mapping with scraped or assigned video IDs, optionally applying
  /// strict chronological anchor heuristic if declared total exceeds scraped count.
  Future<void> updateCollectionMapping(
    Map<String, List<String>> mapping, {
    Map<String, int>? collectionTotals,
  }) async {
    final catalog = state.catalog;
    if (catalog == null) return;

    final catalogVideosMap = {for (final v in catalog.videos) v.id: v};
    final videoIdToCollection = <String, String>{};
    final verifiedIdsByCollection = <String, Set<String>>{};

    for (final entry in mapping.entries) {
      final colName = entry.key;
      final verifiedSet = <String>{};
      for (final id in entry.value) {
        videoIdToCollection[id] = colName;
        verifiedSet.add(id);
      }
      verifiedIdsByCollection[colName] = verifiedSet;
    }

    // Strict chronological anchor heuristic: ONLY applies when declaredTotal > verifiedCount
    final heuristicCountByCollection = <String, int>{};
    if (collectionTotals != null && collectionTotals.isNotEmpty) {
      for (final entry in mapping.entries) {
        final colName = entry.key;
        final declaredTotal = collectionTotals[colName];
        final verifiedIds = verifiedIdsByCollection[colName] ?? const <String>{};
        final verifiedCount = verifiedIds.length;

        if (declaredTotal != null && declaredTotal > verifiedCount) {
          final quota = declaredTotal - verifiedCount;

          // 1. Collect dates of verified videos belonging to this collection
          final verifiedDates = <DateTime>[];
          for (final id in verifiedIds) {
            final v = catalogVideosMap[id];
            if (v != null) {
              verifiedDates.add(v.date);
            }
          }

          DateTime? tMin;
          DateTime? tMax;

          if (verifiedDates.isNotEmpty) {
            verifiedDates.sort();
            tMin = verifiedDates.first;
            tMax = verifiedDates.last;
          }

          final existingCol = catalog.collections
              .where((c) => c.name == colName)
              .firstOrNull;
          if (existingCol?.date != null) {
            if (tMin == null || existingCol!.date!.isBefore(tMin)) {
              tMin = existingCol!.date!;
            }
            if (tMax == null || existingCol.date!.isAfter(tMax)) {
              tMax = existingCol.date!;
            }
          }

          if (tMin != null && tMax != null) {
            // Strict anchor window with tight +/- 2 days margin
            final windowStart = tMin.subtract(const Duration(days: 2));
            final windowEnd = tMax.add(const Duration(days: 2));
            final centerMillis =
                (tMin.millisecondsSinceEpoch + tMax.millisecondsSinceEpoch) ~/ 2;

            // Search only unclassified favorites strictly within the anchor window
            final candidates = catalog.videos.where((v) {
              if (!v.isFavorite) return false;
              if (videoIdToCollection.containsKey(v.id)) return false;
              return (v.date.isAfter(windowStart) || v.date.isAtSameMomentAs(windowStart)) &&
                  (v.date.isBefore(windowEnd) || v.date.isAtSameMomentAs(windowEnd));
            }).toList();

            // Sort candidates by proximity to collection anchor center
            candidates.sort((a, b) {
              final distA = (a.date.millisecondsSinceEpoch - centerMillis).abs();
              final distB = (b.date.millisecondsSinceEpoch - centerMillis).abs();
              return distA.compareTo(distB);
            });

            // Strictly cap at missing quota
            final selected = candidates.take(quota).toList();
            for (final c in selected) {
              videoIdToCollection[c.id] = colName;
            }
            heuristicCountByCollection[colName] = selected.length;
            LoggerService.i(
              'Strict Anchor Heuristic for "$colName": verified=$verifiedCount, declared=$declaredTotal, completed=${selected.length} (window: $windowStart -> $windowEnd)',
            );
          }
        }
      }
    }

    final updatedVideos = catalog.videos.map((v) {
      if (videoIdToCollection.containsKey(v.id)) {
        return v.copyWith(collectionName: videoIdToCollection[v.id]);
      }
      return v;
    }).toList();

    // Update collection counts
    final collectionCounts = <String, int>{};
    int unclassifiedCount = 0;
    for (final v in updatedVideos) {
      if (v.collectionName != null) {
        collectionCounts[v.collectionName!] = (collectionCounts[v.collectionName!] ?? 0) + 1;
      } else if (v.isFavorite) {
        unclassifiedCount++;
      }
    }

    final updatedCollections = <TikTokCollectionItem>[];
    if (unclassifiedCount > 0) {
      updatedCollections.add(TikTokCollectionItem(
        name: 'Favoris non classés',
        videoCount: unclassifiedCount,
      ));
    }

    final existingNames = <String>{};
    for (final c in catalog.collections) {
      if (c.name == 'Favoris non classés' || c.name == 'Vidéos Likées') continue;
      existingNames.add(c.name);
      updatedCollections.add(c.copyWith(
        videoCount: collectionCounts[c.name] ?? 0,
        declaredTotal: collectionTotals?[c.name] ?? c.declaredTotal,
        heuristicCount: heuristicCountByCollection[c.name] ?? c.heuristicCount,
      ));
    }

    for (final colName in mapping.keys) {
      if (!existingNames.contains(colName)) {
        existingNames.add(colName);
        updatedCollections.add(TikTokCollectionItem(
          name: colName,
          videoCount: collectionCounts[colName] ?? 0,
          declaredTotal: collectionTotals?[colName],
          heuristicCount: heuristicCountByCollection[colName],
        ));
      }
    }

    if ((collectionCounts['Vidéos Likées'] ?? 0) > 0) {
      updatedCollections.add(TikTokCollectionItem(
        name: 'Vidéos Likées',
        videoCount: collectionCounts['Vidéos Likées']!,
      ));
    }

    updatedCollections.sort((a, b) {
      if (a.name == 'Favoris non classés') return -1;
      if (b.name == 'Favoris non classés') return 1;
      if (a.videoCount != b.videoCount) {
        return b.videoCount.compareTo(a.videoCount);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    final updatedCatalog = TikTokArchiveCatalog(
      videos: updatedVideos,
      collections: updatedCollections,
      sounds: catalog.sounds,
      totalFavorites: catalog.totalFavorites,
      totalLikes: catalog.totalLikes,
      totalOverlap: catalog.totalOverlap,
      yearCounts: catalog.yearCounts,
    );

    state = state.copyWith(catalog: updatedCatalog);
    await _repository.saveCatalog(updatedCatalog);
  }

  /// Resets all videos in a specific collection back to unclassified favorites.
  Future<void> resetCollectionToUnclassified(String collectionName) async {
    final catalog = state.catalog;
    if (catalog == null) return;

    final updatedVideos = catalog.videos.map((v) {
      if (v.collectionName == collectionName) {
        return v.copyWith(clearCollection: true);
      }
      return v;
    }).toList();

    final collectionCounts = <String, int>{};
    int unclassifiedCount = 0;
    for (final v in updatedVideos) {
      if (v.collectionName != null) {
        collectionCounts[v.collectionName!] = (collectionCounts[v.collectionName!] ?? 0) + 1;
      } else if (v.isFavorite) {
        unclassifiedCount++;
      }
    }

    final updatedCollections = <TikTokCollectionItem>[];
    if (unclassifiedCount > 0) {
      updatedCollections.add(TikTokCollectionItem(
        name: 'Favoris non classés',
        videoCount: unclassifiedCount,
      ));
    }

    for (final c in catalog.collections) {
      if (c.name == 'Favoris non classés' || c.name == 'Vidéos Likées') continue;
      final isTarget = c.name == collectionName;
      updatedCollections.add(c.copyWith(
        videoCount: collectionCounts[c.name] ?? 0,
        heuristicCount: isTarget ? 0 : c.heuristicCount,
      ));
    }

    if ((collectionCounts['Vidéos Likées'] ?? 0) > 0) {
      updatedCollections.add(TikTokCollectionItem(
        name: 'Vidéos Likées',
        videoCount: collectionCounts['Vidéos Likées']!,
      ));
    }

    updatedCollections.sort((a, b) {
      if (a.name == 'Favoris non classés') return -1;
      if (b.name == 'Favoris non classés') return 1;
      if (a.videoCount != b.videoCount) {
        return b.videoCount.compareTo(a.videoCount);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    final updatedCatalog = TikTokArchiveCatalog(
      videos: updatedVideos,
      collections: updatedCollections,
      sounds: catalog.sounds,
      totalFavorites: catalog.totalFavorites,
      totalLikes: catalog.totalLikes,
      totalOverlap: catalog.totalOverlap,
      yearCounts: catalog.yearCounts,
    );

    state = state.copyWith(catalog: updatedCatalog);
    await _repository.saveCatalog(updatedCatalog);
    LoggerService.i('Reset collection "$collectionName" back to unclassified favorites');
  }

  /// Trigger collection synchronization from connected browser extension
  void triggerExtensionSync() {
    _ref.read(localServerServiceProvider).requestTikTokCollectionsSync();
  }

  /// Import a custom JSON mapping file mapping { "Collection Name": ["videoId1", "videoId2"] }
  Future<void> importCollectionsMappingFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        final mapping = <String, List<String>>{};
        for (final entry in decoded.entries) {
          if (entry.value is List) {
            mapping[entry.key.toString()] =
                (entry.value as List).map((e) => e.toString()).toList();
          }
        }
        await updateCollectionMapping(mapping);
      } else {
        state = state.copyWith(
          errorMessage: 'Format JSON invalide (un objet JSON "Nom": ["id1", "id2"] est requis)',
        );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur import mapping JSON: $e');
    }
  }

  /// Clears the video cache directory
  Future<void> clearVideoCache() async {
    await _ref.read(tiktokPreloadControllerProvider).clearCache();
  }

  /// Download selected items via Downloader repository with rate-limiting delay
  Future<void> downloadSelected({bool audioOnly = false}) async {
    final catalog = state.catalog;
    if (catalog == null || state.selectedIds.isEmpty) return;

    final targetItems = catalog.videos.where((v) => state.selectedIds.contains(v.id)).toList();
    await _enqueueBatch(targetItems, audioOnly: audioOnly);
  }

  /// Download first N items from currently visible filtered list
  Future<void> downloadBatch(List<TikTokArchiveItem> items, {int limit = 50, bool audioOnly = false}) async {
    final toDownload = items.take(limit).toList();
    await _enqueueBatch(toDownload, audioOnly: audioOnly);
  }

  /// Download all 308 sounds in audio-only MP3 format
  Future<void> downloadSounds(List<TikTokSoundItem> sounds, {int limit = 50}) async {
    final toDownload = sounds.take(limit).toList();
    if (toDownload.isEmpty) return;

    state = state.copyWith(
      isBatchDownloading: true,
      batchTotalCount: toDownload.length,
      batchCompletedCount: 0,
    );

    try {
      final downloader = _ref.read(downloadListProvider.notifier);
      for (int i = 0; i < toDownload.length; i++) {
        final sound = toDownload[i];
        await downloader.startDownload(
          sound.url,
          audioOnly: true,
          organizeBySite: true,
        );
        state = state.copyWith(batchCompletedCount: i + 1);
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } finally {
      state = state.copyWith(isBatchDownloading: false);
    }
  }

  Future<void> _enqueueBatch(List<TikTokArchiveItem> items, {bool audioOnly = false}) async {
    if (items.isEmpty) return;

    state = state.copyWith(
      isBatchDownloading: true,
      batchTotalCount: items.length,
      batchCompletedCount: 0,
    );

    try {
      final downloader = _ref.read(downloadListProvider.notifier);
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        await downloader.startDownload(
          item.url,
          audioOnly: audioOnly,
          organizeBySite: true,
        );
        state = state.copyWith(batchCompletedCount: i + 1);
        // Discrete throttle between downloads to respect network & engine stability
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } finally {
      state = state.copyWith(isBatchDownloading: false);
    }
  }

  Future<void> clearCatalog() async {
    await _repository.clearCatalog();
    state = const TikTokArchiveState();
  }
}

/// Selector provider returning filtered videos based on active filter.
final filteredTikTokVideosProvider = Provider<List<TikTokArchiveItem>>((ref) {
  final state = ref.watch(tikTokArchiveProvider);
  final catalog = state.catalog;
  if (catalog == null) return const [];

  final unavailableIds = ref.watch(tiktokUnavailableIdsProvider).valueOrNull ??
      ref.watch(tiktokVideoCacheServiceProvider).unavailableIds;

  final filter = state.filter;
  return catalog.videos.where((v) {
    // 0. Exclude unavailable or deleted TikTok videos
    if (unavailableIds.contains(v.id)) {
      return false;
    }

    // 1. Filter by Year
    if (filter.selectedYear != null && v.date.year != filter.selectedYear) {
      return false;
    }

    // 2. Filter by Collection
    if (filter.selectedCollection != null) {
      if (filter.selectedCollection == 'Favoris non classés') {
        if (v.collectionName != null && v.collectionName != 'Favoris non classés') {
          return false;
        }
      } else if (v.collectionName != filter.selectedCollection) {
        return false;
      }
    }

    // 3. Filter by Status (Favorites vs Likes)
    if (filter.statusFilter == TikTokStatusFilter.favoritesOnly && !v.isFavorite) {
      return false;
    }
    if (filter.statusFilter == TikTokStatusFilter.likesOnly && !v.isLiked) {
      return false;
    }

    // 4. Filter by Search Query
    if (filter.searchQuery.isNotEmpty) {
      final query = filter.searchQuery.toLowerCase();
      final matchesId = v.id.contains(query);
      final matchesCollection = v.collectionName?.toLowerCase().contains(query) ?? false;
      if (!matchesId && !matchesCollection) {
        return false;
      }
    }

    return true;
  }).toList();
});
