import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tiktok_archive_catalog.dart';
import '../../domain/entities/tiktok_classification_report.dart';
import '../../domain/repositories/i_tiktok_archive_repository.dart';
import '../../data/repositories/tiktok_archive_repository_impl.dart';
import '../../data/services/tiktok_collection_reconciliation_service.dart';
import '../../../downloader/presentation/providers/downloader_provider.dart';
import '../../../../core/logger/logger_service.dart';
import '../../../../core/services/local_server_service.dart';
import '../../../../core/download/tiktok_video_url.dart';
import '../../../../core/download/download_file_resolver.dart';
import 'tiktok_video_cache_provider.dart';
import '../../../../showcase/showcase_mode.dart';
import '../../../../showcase/showcase_data.dart';

enum TikTokStatusFilter { all, favoritesOnly, likesOnly }

enum TikTokViewMode { hub, collections, list }

enum TikTokSyncStatus { idle, waiting, complete, partial, failed }

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
      selectedCollection: selectedCollection != null
          ? selectedCollection()
          : this.selectedCollection,
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
  final int batchSkippedCount;
  final TikTokViewMode viewMode;
  final TikTokSyncStatus syncStatus;
  final String? syncMessage;

  const TikTokArchiveState({
    this.isLoading = false,
    this.catalog,
    this.filter = const TikTokArchiveFilter(),
    this.selectedIds = const {},
    this.errorMessage,
    this.isBatchDownloading = false,
    this.batchCompletedCount = 0,
    this.batchTotalCount = 0,
    this.batchSkippedCount = 0,
    this.viewMode = TikTokViewMode.hub,
    this.syncStatus = TikTokSyncStatus.idle,
    this.syncMessage,
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
    int? batchSkippedCount,
    TikTokViewMode? viewMode,
    TikTokSyncStatus? syncStatus,
    String? syncMessage,
    bool clearSyncMessage = false,
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
      batchSkippedCount: batchSkippedCount ?? this.batchSkippedCount,
      viewMode: viewMode ?? this.viewMode,
      syncStatus: syncStatus ?? this.syncStatus,
      syncMessage: clearSyncMessage ? null : syncMessage ?? this.syncMessage,
    );
  }
}

final tikTokArchiveRepositoryProvider = Provider<ITikTokArchiveRepository>((
  ref,
) {
  return TikTokArchiveRepositoryImpl();
});

final tikTokArchiveProvider =
    StateNotifierProvider<TikTokArchiveNotifier, TikTokArchiveState>((ref) {
      final repo = ref.watch(tikTokArchiveRepositoryProvider);
      return TikTokArchiveNotifier(repo, ref);
    });

class TikTokArchiveNotifier extends StateNotifier<TikTokArchiveState> {
  final ITikTokArchiveRepository _repository;
  final Ref _ref;
  Timer? _extensionSyncTimeout;

  /// Set by [stopBatch]; the running batch loop checks it between items.
  bool _batchStopRequested = false;

  /// Stops queuing further items of the running batch. Downloads already
  /// handed to the engine keep going.
  void stopBatch() {
    if (state.isBatchDownloading) _batchStopRequested = true;
  }

  int _extensionSyncRequestId = 0;

  late final Future<void> initialized;

  TikTokArchiveNotifier(this._repository, this._ref)
    : super(const TikTokArchiveState()) {
    initialized = _init();
  }

  @override
  void dispose() {
    _extensionSyncTimeout?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    if (_ref.read(showcaseModeProvider)) {
      state = state.copyWith(
        catalog: createShowcaseArchive(),
        viewMode: TikTokViewMode.list,
      );
      return;
    }
    state = state.copyWith(isLoading: true);
    try {
      final cacheService = _ref.read(tiktokVideoCacheServiceProvider);
      await cacheService.getCacheDirectory();

      final cached = await _repository.getCachedCatalog();
      if (cached != null && cached.videos.isNotEmpty) {
        var processed = _purgeUnavailable(cached);
        processed = _repairSyncedCollections(processed);
        if (processed != cached) {
          unawaited(_repository.saveCatalog(processed));
        }
        state = state.copyWith(catalog: processed);
        final hasMapped = processed.collections.any((c) => c.videoCount > 0);
        if (hasMapped) {
          state = state.copyWith(
            isLoading: false,
            catalog: processed,
            viewMode: TikTokViewMode.collections,
          );
          return;
        }
      }

      // Auto-discover typical user export if cached is not yet saved or needs mapping
      const defaultPath =
          r'C:\Users\entre\Downloads\tiktok_data\user_data_tiktok.json';
      if (File(defaultPath).existsSync()) {
        await importFromPath(defaultPath, announce: false);
        return;
      }

      state = state.copyWith(isLoading: false);
    } catch (e, st) {
      LoggerService.e('Error initializing TikTokArchiveNotifier: $e', e, st);
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  TikTokArchiveCatalog _purgeUnavailable(TikTokArchiveCatalog catalog) {
    final unavailableIds =
        _ref.read(tiktokUnavailableIdsProvider).valueOrNull ??
        _ref.read(tiktokVideoCacheServiceProvider).unavailableIds;
    if (unavailableIds.isEmpty) return catalog;

    final remainingVideos = catalog.videos
        .where((v) => !unavailableIds.contains(v.id))
        .toList(growable: false);

    if (remainingVideos.length == catalog.videos.length) {
      return catalog;
    }

    final updatedCollections = catalog.collections
        .map((col) {
          final count = remainingVideos.where((v) {
            if (col.id != null && col.id!.isNotEmpty) {
              return v.collectionIds.contains(col.id);
            }
            return v.collectionName == col.name;
          }).length;
          return col.copyWith(videoCount: count);
        })
        .toList(growable: false);

    return catalog.copyWith(
      videos: remainingVideos,
      collections: updatedCollections,
      totalFavorites: remainingVideos.where((v) => v.isFavorite).length,
      totalLikes: remainingVideos.where((v) => v.isLiked).length,
    );
  }

  TikTokArchiveCatalog _repairSyncedCollections(TikTokArchiveCatalog catalog) {
    var changed = false;
    final updatedCollections = catalog.collections
        .map((col) {
          if (col.syncError == 'count_mismatch' ||
              (col.syncComplete == false &&
                  col.syncError == null &&
                  col.videoCount > 0)) {
            changed = true;
            return TikTokCollectionItem(
              id: col.id,
              name: col.name,
              coverUrl: col.coverUrl,
              date: col.date,
              videoCount: col.videoCount,
              declaredTotal: col.declaredTotal,
              heuristicCount: col.heuristicCount,
              syncComplete: true,
              syncError: null,
            );
          }
          return col;
        })
        .toList(growable: false);
    if (!changed) return catalog;
    return catalog.copyWith(collections: updatedCollections);
  }

  Future<void> purgeUnavailableVideos() async {
    if (_ref.read(showcaseModeProvider)) return;
    final current = state.catalog;
    if (current == null) return;
    final cleaned = _purgeUnavailable(current);
    if (cleaned.videos.length != current.videos.length) {
      state = state.copyWith(catalog: cleaned);
      await _repository.saveCatalog(cleaned);
      LoggerService.i(
        'Purged ${current.videos.length - cleaned.videos.length} unavailable videos from TikTok catalog.',
      );
    }
  }

  void setViewMode(TikTokViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  /// [announce] false keeps the import silent (startup discovery): no summary
  /// and no extension sync until the user asks for one.
  Future<void> importFromPath(String filePath, {bool announce = true}) async {
    if (_ref.read(showcaseModeProvider)) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final rawCatalog = await _repository.importFromFile(filePath);
      final catalog = _purgeUnavailable(rawCatalog);
      if (catalog.videos.length != rawCatalog.videos.length) {
        unawaited(_repository.saveCatalog(catalog));
      }
      state = state.copyWith(
        isLoading: false,
        catalog: catalog,
        selectedIds: {},
        viewMode: TikTokViewMode.collections,
      );
      if (announce) _reportImport(catalog);
    } catch (e, st) {
      LoggerService.e(
        'Failed to import TikTok archive from $filePath: $e',
        e,
        st,
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Échec de l\'importation: $e',
      );
    }
  }

  /// "N favoris classés dans X/Y collections · M non classés", or null before
  /// any catalog exists.
  String? get classificationSummary {
    final catalog = state.catalog;
    return catalog == null
        ? null
        : TikTokClassificationReport.fromCatalog(catalog).summary();
  }

  /// Says what the import classified and why the rest is not. The export has
  /// no collection membership, so when favorites remain unfiled the extension
  /// sync starts by itself; without an extension the message says what to do.
  void _reportImport(TikTokArchiveCatalog catalog) {
    final report = TikTokClassificationReport.fromCatalog(catalog);
    final summary =
        'Import terminé : ${report.videos} vidéos, ${report.summary()}.';
    if (!report.needsSync) {
      state = state.copyWith(
        syncStatus: TikTokSyncStatus.complete,
        syncMessage: summary,
      );
      return;
    }
    const why =
        ' Le JSON TikTok ne dit pas dans quelle collection se trouve un favori : '
        'seule ta session TikTok connectée le sait.';
    try {
      triggerExtensionSync(
        offlineNotice:
            '$summary$why Ouvre TikTok dans ton navigateur avec l’extension, puis appuie sur Synchroniser.',
      );
    } catch (e) {
      LoggerService.w('Automatic TikTok sync after import not started: $e');
      state = state.copyWith(
        syncStatus: TikTokSyncStatus.partial,
        syncMessage: '$summary$why',
      );
    }
  }

  Future<void> pickAndImportFile() async {
    if (_ref.read(showcaseModeProvider)) return;
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
    state = state.copyWith(
      filter: state.filter.copyWith(searchQuery: query.trim()),
    );
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
    state = state.copyWith(filter: state.filter.copyWith(statusFilter: status));
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

  /// Saves every verified browser membership, even from partial snapshots.
  Future<int> applyCollectionSync(
    List<TikTokCollectionSnapshot> snapshots, {
    required bool collectionListComplete,
  }) async {
    await initialized;
    final catalog =
        state.catalog ??
        await _repository.getCachedCatalog() ??
        TikTokArchiveCatalog.empty;
    final result = await compute(_reconcileCollectionSyncInBackground, {
      'catalog': catalog.toJson(),
      'snapshots': snapshots.map((snapshot) => snapshot.toJson()).toList(),
      'collectionListComplete': collectionListComplete,
    });
    final updatedCatalog = TikTokArchiveCatalog.fromJson(
      Map<String, dynamic>.from(result['catalog'] as Map),
    );
    state = state.copyWith(catalog: updatedCatalog);
    await _repository.saveCatalog(updatedCatalog);
    return result['incompleteCollections'] as int? ?? 0;
  }

  /// Imports an old name-to-ID mapping as suggestions because it has no completeness proof.
  Future<void> updateCollectionMapping(
    Map<String, List<String>> mapping, {
    Map<String, int>? collectionTotals,
  }) async {
    await initialized;
    final catalog =
        state.catalog ??
        await _repository.getCachedCatalog() ??
        TikTokArchiveCatalog.empty;
    final result = await compute(_mutateCollectionCatalogInBackground, {
      'operation': 'add_mapping_suggestions',
      'catalog': catalog.toJson(),
      'mapping': mapping,
      'collectionTotals': collectionTotals,
    });
    final updatedCatalog = TikTokArchiveCatalog.fromJson(
      Map<String, dynamic>.from(result['catalog'] as Map),
    );
    state = state.copyWith(catalog: updatedCatalog);
    await _repository.saveCatalog(updatedCatalog);
  }

  /// Applies only the suggestions selected by the user in the grouped review.
  Future<void> applyCollectionSuggestions(Set<String> suggestionKeys) async {
    await initialized;
    final catalog =
        state.catalog ??
        await _repository.getCachedCatalog() ??
        TikTokArchiveCatalog.empty;
    final result = await compute(_mutateCollectionCatalogInBackground, {
      'operation': 'apply_suggestions',
      'catalog': catalog.toJson(),
      'suggestionKeys': suggestionKeys.toList(growable: false),
    });
    final updatedCatalog = TikTokArchiveCatalog.fromJson(
      Map<String, dynamic>.from(result['catalog'] as Map),
    );
    state = state.copyWith(catalog: updatedCatalog);
    await _repository.saveCatalog(updatedCatalog);
  }

  /// Resets a collection's confirmed memberships to unclassified favorites.
  Future<void> resetCollectionToUnclassified(String collectionKey) async {
    await initialized;
    final catalog = state.catalog;
    if (catalog == null) return;
    final result = await compute(_mutateCollectionCatalogInBackground, {
      'operation': 'reset_collection',
      'catalog': catalog.toJson(),
      'collectionKey': collectionKey,
    });
    final updatedCatalog = TikTokArchiveCatalog.fromJson(
      Map<String, dynamic>.from(result['catalog'] as Map),
    );
    state = state.copyWith(catalog: updatedCatalog);
    await _repository.saveCatalog(updatedCatalog);
    LoggerService.i(
      'Reset collection "$collectionKey" to unclassified favorites',
    );
  }

  /// Permanently deletes a collection from the catalog.
  /// Videos are preserved but no longer assigned to this collection.
  Future<void> deleteCollection(String collectionKey) async {
    await initialized;
    final catalog = state.catalog;
    if (catalog == null) return;
    final result = await compute(_mutateCollectionCatalogInBackground, {
      'operation': 'delete_collection',
      'catalog': catalog.toJson(),
      'collectionKey': collectionKey,
    });
    final updatedCatalog = TikTokArchiveCatalog.fromJson(
      Map<String, dynamic>.from(result['catalog'] as Map),
    );
    final isSelected = state.filter.selectedCollection == collectionKey;
    state = state.copyWith(
      catalog: updatedCatalog,
      filter: isSelected
          ? state.filter.copyWith(selectedCollection: () => null)
          : state.filter,
    );
    await _repository.saveCatalog(updatedCatalog);
    LoggerService.i('Deleted collection "$collectionKey" permanently');
  }

  /// What [purgeCollections] would remove, for the confirmation dialog.
  ({int videos, int keptShared, int files}) purgePreview(
    Set<String> collectionKeys,
  ) {
    final catalog = state.catalog;
    if (catalog == null) return (videos: 0, keptShared: 0, files: 0);
    final result = const TikTokCollectionReconciliationService()
        .purgeCollections(catalog, collectionKeys);
    return (
      videos: result.removedVideoIds.length,
      keptShared: result.keptSharedCount,
      files: _libraryRowsFor(catalog, result.removedVideoIds).length,
    );
  }

  /// Deletes the collections, the videos that only they contained, and those
  /// videos' downloaded files (permanently). Videos shared with a kept
  /// collection stay, so "download all" never brings the purged ones back.
  Future<({int videosRemoved, int filesDeleted, int keptShared})>
  purgeCollections(Set<String> collectionKeys) async {
    await initialized;
    final catalog = state.catalog;
    if (catalog == null || collectionKeys.isEmpty) {
      return (videosRemoved: 0, filesDeleted: 0, keptShared: 0);
    }
    final result = await compute(_purgeCollectionsInBackground, {
      'catalog': catalog.toJson(),
      'keys': collectionKeys.toList(),
    });
    final updatedCatalog = TikTokArchiveCatalog.fromJson(
      Map<String, dynamic>.from(result['catalog'] as Map),
    );
    final removedIds = (result['removed'] as List).cast<String>().toSet();
    final rows = _ref.read(showcaseModeProvider)
        ? const <String>[]
        : _libraryRowsFor(catalog, removedIds);
    if (rows.isNotEmpty) {
      await _ref.read(downloadListProvider.notifier).deleteDownloads(rows);
    }
    final selected = state.filter.selectedCollection;
    state = state.copyWith(
      catalog: updatedCatalog,
      filter: selected != null && collectionKeys.contains(selected)
          ? state.filter.copyWith(selectedCollection: () => null)
          : state.filter,
    );
    await _repository.saveCatalog(updatedCatalog);
    LoggerService.i(
      'Purged ${collectionKeys.length} collections: '
      '${removedIds.length} videos, ${rows.length} files',
    );
    return (
      videosRemoved: removedIds.length,
      filesDeleted: rows.length,
      keptShared: result['kept'] as int,
    );
  }

  /// Library rows downloaded from one of [videoIds]: by the exact URL the
  /// batch download used, by the video id in the URL, or by the `[id]` yt-dlp
  /// puts in the file name (re-imported files).
  List<String> _libraryRowsFor(
    TikTokArchiveCatalog catalog,
    Set<String> videoIds,
  ) {
    if (videoIds.isEmpty) return const [];
    final urls = {
      for (final video in catalog.videos)
        if (videoIds.contains(video.id)) TikTokVideoUrl.forDownload(video.url),
    };
    final items = _ref.read(downloadListProvider).valueOrNull ?? const [];
    return [
      for (final item in items)
        if (urls.contains(TikTokVideoUrl.forDownload(item.request.url)) ||
            videoIds.contains(
              TikTokVideoUrl.extractVideoId(item.request.url) ??
                  DownloadFileResolver.extractBracketId(item.filePath),
            ))
          item.id,
    ];
  }

  /// Trigger collection synchronization from a connected browser extension.
  /// Pending state ends only when the extension returns data or the request times out.
  ///
  /// With [offlineNotice], no connected extension is not an error: the notice
  /// is shown as a partial result instead of a failure.
  void triggerExtensionSync({String? offlineNotice}) {
    if (_ref.read(showcaseModeProvider)) return;
    final requestId = ++_extensionSyncRequestId;
    _extensionSyncTimeout?.cancel();
    state = state.copyWith(
      syncStatus: TikTokSyncStatus.waiting,
      clearSyncMessage: true,
    );

    final sentCount = _ref
        .read(localServerServiceProvider)
        .requestTikTokCollectionsSync(requestId: requestId);
    if (sentCount == 0) {
      if (offlineNotice != null) {
        setExtensionSyncResult(ok: true, partial: true, message: offlineNotice);
        return;
      }
      setExtensionSyncResult(
        ok: false,
        message: 'Aucune extension Modern Downloader n’est connectée.',
      );
      return;
    }

    _extensionSyncTimeout = Timer(const Duration(minutes: 15), () {
      if (requestId == _extensionSyncRequestId &&
          state.syncStatus == TikTokSyncStatus.waiting) {
        setExtensionSyncResult(
          ok: false,
          message:
              'La synchronisation prend trop de temps. Les données déjà enregistrées sont conservées.',
        );
      }
    });
  }

  void setExtensionSyncResult({
    required bool ok,
    required String message,
    bool partial = false,
  }) {
    _extensionSyncTimeout?.cancel();
    _extensionSyncTimeout = null;
    _extensionSyncRequestId++;
    state = state.copyWith(
      syncStatus: !ok
          ? TikTokSyncStatus.failed
          : partial
          ? TikTokSyncStatus.partial
          : TikTokSyncStatus.complete,
      syncMessage: message,
    );
  }

  /// Import a custom JSON mapping file mapping { "Collection Name": ["videoId1", "videoId2"] }
  Future<void> importCollectionsMappingFromFile() async {
    if (_ref.read(showcaseModeProvider)) return;
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
            mapping[entry.key.toString()] = (entry.value as List)
                .map((e) => e.toString())
                .toList();
          }
        }
        await updateCollectionMapping(mapping);
      } else {
        state = state.copyWith(
          errorMessage:
              'Format JSON invalide (un objet JSON "Nom": ["id1", "id2"] est requis)',
        );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur import mapping JSON: $e');
    }
  }

  /// Clears the video cache directory
  Future<void> clearVideoCache() async {
    if (_ref.read(showcaseModeProvider)) return;
    await _ref.read(tiktokPreloadControllerProvider).clearCache();
  }

  /// Download selected items via Downloader repository with rate-limiting delay
  Future<void> downloadSelected({bool audioOnly = false}) async {
    if (_ref.read(showcaseModeProvider)) return;
    final catalog = state.catalog;
    if (catalog == null || state.selectedIds.isEmpty) return;

    final targetItems = catalog.videos
        .where((v) => state.selectedIds.contains(v.id))
        .toList();
    await _enqueueBatch(targetItems, audioOnly: audioOnly);
  }

  /// Download first N items from currently visible filtered list
  Future<void> downloadBatch(
    List<TikTokArchiveItem> items, {
    int limit = 50,
    bool audioOnly = false,
  }) async {
    final toDownload = items.take(limit).toList();
    if (_ref.read(showcaseModeProvider)) return;
    await _enqueueBatch(toDownload, audioOnly: audioOnly);
  }

  /// Download all 308 sounds in audio-only MP3 format
  Future<void> downloadSounds(
    List<TikTokSoundItem> sounds, {
    int limit = 50,
  }) async {
    final toDownload = sounds.take(limit).toList();
    if (_ref.read(showcaseModeProvider)) return;
    if (toDownload.isEmpty) return;

    state = state.copyWith(
      isBatchDownloading: true,
      batchTotalCount: toDownload.length,
      batchCompletedCount: 0,
    );
    _batchStopRequested = false;

    try {
      final downloader = _ref.read(downloadListProvider.notifier);
      for (int i = 0; i < toDownload.length; i++) {
        if (_batchStopRequested) break;
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
      _batchStopRequested = false;
      state = state.copyWith(isBatchDownloading: false);
    }
  }

  Future<void> _enqueueBatch(
    List<TikTokArchiveItem> items, {
    bool audioOnly = false,
  }) async {
    final cacheService = _ref.read(tiktokVideoCacheServiceProvider);
    await cacheService.getCacheDirectory();

    // 1. Immediately drop all videos confirmed dead or private
    final toProcess = items
        .where((item) => !cacheService.isUnavailable(item.id))
        .toList(growable: false);
    if (toProcess.isEmpty) return;

    state = state.copyWith(
      isBatchDownloading: true,
      batchTotalCount: toProcess.length,
      batchCompletedCount: 0,
      batchSkippedCount: 0,
    );
    _batchStopRequested = false;

    int skippedCount = 0;

    try {
      final downloader = _ref.read(downloadListProvider.notifier);
      for (int i = 0; i < toProcess.length; i++) {
        if (_batchStopRequested) break;
        final item = toProcess[i];
        if (cacheService.isUnavailable(item.id)) {
          skippedCount++;
          state = state.copyWith(
            batchCompletedCount: i + 1,
            batchSkippedCount: skippedCount,
          );
          continue;
        }

        // Fast probe: check if video is deleted or private before handing to yt-dlp
        final isAvailable = await cacheService.checkAvailability(
          item.id,
          url: item.url,
        );
        if (!isAvailable) {
          skippedCount++;
          state = state.copyWith(
            batchCompletedCount: i + 1,
            batchSkippedCount: skippedCount,
          );
          continue;
        }

        await downloader.startDownload(
          TikTokVideoUrl.forDownload(item.url),
          audioOnly: audioOnly,
          organizeBySite: true,
        );
        state = state.copyWith(batchCompletedCount: i + 1);
        // Discrete throttle between downloads to respect network & engine stability
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } finally {
      _batchStopRequested = false;
      state = state.copyWith(isBatchDownloading: false);
      if (skippedCount > 0) {
        final catalog = state.catalog;
        if (catalog != null) {
          final purged = _purgeUnavailable(catalog);
          if (purged != catalog) {
            state = state.copyWith(catalog: purged);
            unawaited(_repository.saveCatalog(purged));
          }
        }
      }
    }
  }

  Future<void> clearCatalog() async {
    await _repository.clearCatalog();
    state = const TikTokArchiveState();
  }
}

Map<String, dynamic> _reconcileCollectionSyncInBackground(
  Map<String, dynamic> arguments,
) {
  final catalog = TikTokArchiveCatalog.fromJson(
    Map<String, dynamic>.from(arguments['catalog'] as Map),
  );
  final snapshots = (arguments['snapshots'] as List<dynamic>)
      .map(
        (item) => TikTokCollectionSnapshot.fromJson(
          Map<String, dynamic>.from(item as Map),
        ),
      )
      .toList();
  final result = const TikTokCollectionReconciliationService().applySnapshots(
    catalog,
    snapshots,
    collectionListComplete:
        arguments['collectionListComplete'] as bool? ?? false,
  );
  return {
    'catalog': result.catalog.toJson(),
    'updatedCollections': result.updatedCollections,
    'incompleteCollections': result.incompleteCollections,
  };
}

Map<String, dynamic> _purgeCollectionsInBackground(
  Map<String, dynamic> arguments,
) {
  final catalog = TikTokArchiveCatalog.fromJson(
    Map<String, dynamic>.from(arguments['catalog'] as Map),
  );
  final result = const TikTokCollectionReconciliationService().purgeCollections(
    catalog,
    (arguments['keys'] as List).cast<String>().toSet(),
  );
  return {
    'catalog': result.catalog.toJson(),
    'removed': result.removedVideoIds.toList(),
    'kept': result.keptSharedCount,
  };
}

Map<String, dynamic> _mutateCollectionCatalogInBackground(
  Map<String, dynamic> arguments,
) {
  final catalog = TikTokArchiveCatalog.fromJson(
    Map<String, dynamic>.from(arguments['catalog'] as Map),
  );
  const service = TikTokCollectionReconciliationService();
  final operation = arguments['operation'];
  late final TikTokArchiveCatalog updatedCatalog;

  if (operation == 'add_mapping_suggestions') {
    final rawMapping = arguments['mapping'] as Map;
    final mapping = <String, List<String>>{};
    for (final entry in rawMapping.entries) {
      if (entry.value is List) {
        mapping[entry.key.toString()] = (entry.value as List)
            .map((value) => value.toString())
            .toList(growable: false);
      }
    }
    final rawTotals = arguments['collectionTotals'];
    final totals = <String, int>{};
    if (rawTotals is Map) {
      for (final entry in rawTotals.entries) {
        final value = entry.value;
        if (value is num) {
          totals[entry.key.toString()] = value.toInt();
        }
      }
    }
    updatedCatalog = service.addMappingSuggestions(
      catalog,
      mapping,
      declaredTotals: totals,
    );
  } else if (operation == 'apply_suggestions') {
    final keys = (arguments['suggestionKeys'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toSet();
    updatedCatalog = service.applySuggestions(catalog, keys);
  } else if (operation == 'reset_collection') {
    updatedCatalog = service.resetCollection(
      catalog,
      arguments['collectionKey'] as String? ?? '',
    );
  } else if (operation == 'delete_collection') {
    updatedCatalog = service.deleteCollection(
      catalog,
      arguments['collectionKey'] as String? ?? '',
    );
  } else {
    throw ArgumentError.value(
      operation,
      'operation',
      'Unknown collection mutation',
    );
  }

  return {'catalog': updatedCatalog.toJson()};
}

/// Selector provider returning filtered videos based on active filter.
final filteredTikTokVideosProvider = Provider<List<TikTokArchiveItem>>((ref) {
  final state = ref.watch(tikTokArchiveProvider);
  final catalog = state.catalog;
  if (catalog == null) return const [];

  final unavailableIds =
      ref.watch(tiktokUnavailableIdsProvider).valueOrNull ??
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
      if (filter.selectedCollection == 'Vidéos Likées') {
        if (!v.isLiked) return false;
      } else if (filter.selectedCollection == 'Favoris non classés') {
        if (!v.isFavorite ||
            v.collectionIds.isNotEmpty ||
            (v.collectionName != null &&
                v.collectionName != 'Vidéos Likées' &&
                v.collectionName != 'Favoris non classés')) {
          return false;
        }
      } else {
        final selectedCollection = catalog.collections
            .where(
              (collection) =>
                  collection.id == filter.selectedCollection ||
                  (collection.id == null &&
                      collection.name == filter.selectedCollection),
            )
            .firstOrNull;
        final matchesById =
            selectedCollection?.id != null &&
            v.collectionIds.contains(selectedCollection!.id);
        final matchesByName =
            v.collectionName
                ?.split(' · ')
                .contains(
                  selectedCollection?.name ?? filter.selectedCollection,
                ) ??
            false;
        if (!matchesById && !matchesByName) return false;
      }
    }

    // 3. Filter by Status (Favorites vs Likes)
    if (filter.statusFilter == TikTokStatusFilter.favoritesOnly &&
        !v.isFavorite) {
      return false;
    }
    if (filter.statusFilter == TikTokStatusFilter.likesOnly && !v.isLiked) {
      return false;
    }

    // 4. Filter by Search Query
    if (filter.searchQuery.isNotEmpty) {
      final query = filter.searchQuery.toLowerCase();
      final matchesId = v.id.contains(query);
      final matchesCollection =
          v.collectionName?.toLowerCase().contains(query) ?? false;
      if (!matchesId && !matchesCollection) {
        return false;
      }
    }

    return true;
  }).toList();
});
