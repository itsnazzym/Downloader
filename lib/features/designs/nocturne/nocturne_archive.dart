import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/plugins/feature_activation.dart';
import 'package:modern_downloader/core/services/local_server_service.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/archive/presentation/views/modes/tiktok_collections_view.dart';
import 'package:modern_downloader/features/archive/presentation/views/widgets/tiktok_filter_pane.dart';
import 'package:modern_downloader/features/archive/presentation/views/widgets/tiktok_video_card.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';

import 'nocturne_widgets.dart';

/// Nocturne's TikTok archive (mockup Nocturne-Archives.dc.html): the
/// archive's header and figures, sync and download-all, then Vidéos /
/// Collections / Favoris. The import hub, the loading state, the filter pane,
/// the video cards and the collections view (open, select and purge, reset,
/// delete, suggestions) are today's widgets, unchanged.
class NocturneArchive extends ConsumerWidget {
  const NocturneArchive({super.key, required this.current});

  /// Today's archive view: loading, import hub and empty states.
  final Widget current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tikTokArchiveProvider);
    final catalog = state.catalog;
    if (!state.isLoading && !state.hasCatalog) return _NoArchive(state: state);
    if (state.isLoading ||
        state.viewMode == TikTokViewMode.hub ||
        !state.hasCatalog ||
        catalog == null) {
      return current;
    }
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.fromLTRB(wide ? 40 : 20, 34, wide ? 40 : 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(state: state, catalog: catalog, wide: wide),
            const SizedBox(height: 24),
            _Tabs(state: state, catalog: catalog),
            const SizedBox(height: 18),
            Expanded(
              child: state.viewMode == TikTokViewMode.collections
                  ? _Collections(state: state, catalog: catalog)
                  : _VideoList(state: state, wide: wide),
            ),
          ],
        ),
      ),
    );
  }
}

/// No archive imported yet: the orbit, what the page is for, and today's
/// hub actions (import a JSON export, sync through the extension).
class _NoArchive extends ConsumerWidget {
  const _NoArchive({required this.state});

  final TikTokArchiveState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final showcase = ref.watch(showcaseModeProvider);
    final connected =
        !showcase && ref.watch(extensionConnectedClientsProvider) > 0;
    final syncing = state.syncStatus == TikTokSyncStatus.waiting;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.nocturneArchiveEmptyTitle,
          style: nocturneText(
            c,
            size: 24,
            weight: FontWeight.w700,
          ).copyWith(letterSpacing: -0.5, height: 1.2),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            l10n.nocturneArchiveEmptyBody,
            style: nocturneText(c, size: 14, color: c.textSecondary),
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            NocturneButton(
              label: l10n.nocturneArchiveImportJson,
              icon: Icons.file_open_outlined,
              kind: NocturneButtonKind.primary,
              height: 42,
              radius: 14,
              onTap: showcase ? null : notifier.pickAndImportFile,
            ),
            NocturneButton(
              label: syncing ? l10n.nocturneSyncing : l10n.nocturneSync,
              icon: Icons.sync_rounded,
              height: 42,
              radius: 14,
              onTap: connected && !syncing ? notifier.triggerExtensionSync : null,
            ),
          ],
        ),
        if (!connected) ...[
          const SizedBox(height: 12),
          Text(
            l10n.nocturneArchiveSyncHint,
            style: nocturneText(c, size: 12.5, color: c.textDisabled),
          ),
        ],
      ],
    );
    return SingleChildScrollView(
      padding: nocturnePagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NocturneHeader(
            eyebrow: l10n.nocturneArchiveEyebrow,
            title: l10n.archiveMobileTitle,
          ),
          const SizedBox(height: 24),
          NocturneCard(
            lift: false,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
            child: LayoutBuilder(
              builder: (context, box) => box.maxWidth >= 560
                  ? Row(
                      children: [
                        const NocturneOrbit(
                          size: 176,
                          icon: Icons.inventory_2_outlined,
                          arc: 0,
                        ),
                        const SizedBox(width: 36),
                        Expanded(child: text),
                      ],
                    )
                  : text,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.state,
    required this.catalog,
    required this.wide,
  });

  final TikTokArchiveState state;
  final TikTokArchiveCatalog catalog;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final locale = Localizations.localeOf(context).languageCode;
    final name =
        ref
            .watch(featureCatalogProvider)
            .byId['tiktok_archives']
            ?.nameFor(locale) ??
        l10n.designArchivesTab;
    final missing = [
      for (final v in catalog.videos)
        if (!v.isDownloaded) v,
    ];
    final syncing = state.syncStatus == TikTokSyncStatus.waiting;
    Widget figure(int n, String word) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$n',
            style: nocturneMono(c, size: 13.5, color: c.textPrimary),
          ),
          TextSpan(text: ' $word'),
        ],
      ),
      style: nocturneText(c, color: c.textSecondary),
    );
    final identity = Row(
      children: [
        NocturneMonogram(
          text: 'Tik Tok',
          size: 60,
          radius: 18,
          fontSize: 18,
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.nocturneArchiveEyebrow,
                style: nocturneText(c, size: 13, color: c.textDisabled),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nocturneDisplay(c),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 18,
                runSpacing: 6,
                children: [
                  figure(
                    catalog.totalUniqueVideos,
                    l10n.nocturneWordVideos(catalog.totalUniqueVideos),
                  ),
                  figure(
                    catalog.collections.length,
                    l10n.nocturneWordCollections(catalog.collections.length),
                  ),
                  figure(
                    catalog.totalFavorites,
                    l10n.nocturneWordFavorites(catalog.totalFavorites),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    final actions = Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            NocturneButton(
              label: syncing ? l10n.nocturneSyncing : l10n.nocturneSync,
              icon: Icons.sync_rounded,
              onTap: syncing ? null : notifier.triggerExtensionSync,
            ),
            if (state.isBatchDownloading)
              NocturneButton(
                label: l10n.nocturneStopBatch(
                  state.batchCompletedCount,
                  state.batchTotalCount,
                ),
                icon: Icons.stop_rounded,
                kind: NocturneButtonKind.primary,
                onTap: notifier.stopBatch,
              )
            else
              NocturneButton(
                label: l10n.nocturneDownloadAll,
                icon: Icons.download_rounded,
                kind: NocturneButtonKind.primary,
                onTap: missing.isEmpty
                    ? null
                    : () => notifier.downloadBatch(
                        missing,
                        limit: missing.length,
                      ),
              ),
          ],
        ),
        if (state.syncMessage != null) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              state.syncMessage!,
              textAlign: wide ? TextAlign.end : TextAlign.start,
              style: nocturneText(
                c,
                size: 12,
                color: state.syncStatus == TikTokSyncStatus.failed
                    ? c.error
                    : c.textDisabled,
              ),
            ),
          ),
        ],
      ],
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [identity, const SizedBox(height: 16), actions],
      );
    }
    return Row(
      children: [
        Expanded(child: identity),
        const SizedBox(width: 18),
        actions,
      ],
    );
  }
}

enum _Tab { videos, collections, favorites }

class _Tabs extends ConsumerWidget {
  const _Tabs({required this.state, required this.catalog});

  final TikTokArchiveState state;
  final TikTokArchiveCatalog catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final tab = state.viewMode == TikTokViewMode.collections
        ? _Tab.collections
        : state.filter.statusFilter == TikTokStatusFilter.favoritesOnly
        ? _Tab.favorites
        : _Tab.videos;
    return Row(
      children: [
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: NocturneSegmented<_Tab>(
              value: tab,
              onChanged: (t) {
                switch (t) {
                  case _Tab.collections:
                    notifier.setViewMode(TikTokViewMode.collections);
                  case _Tab.videos:
                  case _Tab.favorites:
                    notifier.setStatusFilter(
                      t == _Tab.favorites
                          ? TikTokStatusFilter.favoritesOnly
                          : TikTokStatusFilter.all,
                    );
                    notifier.setViewMode(TikTokViewMode.list);
                }
              },
              segments: [
                NocturneSegment(
                  _Tab.videos,
                  l10n.nocturneTabVideos,
                  count: '${catalog.totalUniqueVideos}',
                ),
                NocturneSegment(
                  _Tab.collections,
                  l10n.nocturneTabCollections,
                  count: '${catalog.collections.length}',
                ),
                NocturneSegment(
                  _Tab.favorites,
                  l10n.nocturneTabFavorites,
                  count: '${catalog.totalFavorites}',
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        // Today's « Importer / synchroniser » hub.
        NocturneButton(
          label: l10n.nocturneImport,
          icon: Icons.file_upload_outlined,
          kind: NocturneButtonKind.ghost,
          onTap: () => notifier.setViewMode(TikTokViewMode.hub),
        ),
      ],
    );
  }
}

/// Vidéos and Favoris: today's filter pane, then search, selection and the
/// video cards.
class _VideoList extends ConsumerStatefulWidget {
  const _VideoList({required this.state, required this.wide});

  final TikTokArchiveState state;
  final bool wide;

  @override
  ConsumerState<_VideoList> createState() => _VideoListState();
}

class _VideoListState extends ConsumerState<_VideoList> {
  late final _search = TextEditingController(
    text: widget.state.filter.searchQuery,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final state = widget.state;
    final videos = ref.watch(filteredTikTokVideosProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.primary.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: c.textDisabled),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (v) {
                    notifier.setSearchQuery(v);
                    setState(() {});
                  },
                  style: nocturneText(c),
                  cursorColor: c.primary,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: l10n.nocturneArchiveSearch,
                    hintStyle: nocturneText(c, color: c.textDisabled),
                  ),
                ),
              ),
              if (_search.text.isNotEmpty)
                NocturneIconButton(
                  icon: Icons.close_rounded,
                  tooltip: l10n.nocturneClear,
                  ghost: true,
                  size: 32,
                  onTap: () {
                    _search.clear();
                    notifier.setSearchQuery('');
                    setState(() {});
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              l10n.nocturneCountVideos(videos.length),
              style: nocturneText(c, size: 12.5, color: c.textSecondary),
            ),
            const Spacer(),
            if (!widget.wide) ...[
              // Narrow windows: the filter pane opens in a sheet.
              NocturneButton(
                label: l10n.nocturneFilters,
                icon: Icons.tune_rounded,
                kind: NocturneButtonKind.ghost,
                height: 34,
                padding: 12,
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: c.surface,
                  builder: (_) => SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.8,
                    child: const TikTokFilterPane(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (state.selectedIds.isEmpty)
              NocturneButton(
                label: l10n.nocturneSelectAll,
                icon: Icons.select_all_rounded,
                kind: NocturneButtonKind.ghost,
                height: 34,
                padding: 12,
                onTap: videos.isEmpty ? null : () => notifier.selectAll(videos),
              )
            else ...[
              NocturneButton(
                label: l10n.nocturneSelectedClear(state.selectedIds.length),
                kind: NocturneButtonKind.ghost,
                height: 34,
                padding: 12,
                onTap: notifier.clearSelection,
              ),
              const SizedBox(width: 8),
              NocturneButton(
                label: l10n.nocturneDownloadSelection,
                icon: Icons.download_rounded,
                kind: NocturneButtonKind.primary,
                height: 34,
                padding: 14,
                onTap: state.isBatchDownloading
                    ? null
                    : () async {
                        await notifier.downloadSelected();
                        if (mounted) _notice(l10n.nocturneQueued);
                      },
              ),
            ],
          ],
        ),
        if (state.isBatchDownloading) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: NocturneBar(
                  value: state.batchTotalCount > 0
                      ? state.batchCompletedCount / state.batchTotalCount
                      : 0,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                state.batchSkippedCount > 0
                    ? l10n.nocturneBatchSkipped(
                        state.batchCompletedCount,
                        state.batchTotalCount,
                        state.batchSkippedCount,
                      )
                    : '${state.batchCompletedCount} / ${state.batchTotalCount}',
                style: nocturneMono(c),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: videos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.nocturneNoMatch,
                        style: nocturneText(c, color: c.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      NocturneButton(
                        label: l10n.nocturneResetFilters,
                        onTap: notifier.resetFilters,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: videos.length,
                  itemBuilder: (context, i) {
                    final video = videos[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: TikTokVideoCard(
                        item: video,
                        isSelected: state.selectedIds.contains(video.id),
                        onToggleSelect: () =>
                            notifier.toggleSelection(video.id),
                        onDownload: () async {
                          if (ref.read(showcaseModeProvider)) return;
                          await notifier.downloadBatch([video], limit: 1);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
    if (!widget.wide) return list;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: NocturneCard(
            lift: false,
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: const TikTokFilterPane(),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(child: list),
      ],
    );
  }
}

/// Collections as in the mockup: tinted cards, how much is downloaded,
/// select-and-purge with its bar. Opening a collection, and « Vue
/// classique » (search, posters, suggestions, reset, delete), show today's
/// collections view.
class _Collections extends ConsumerStatefulWidget {
  const _Collections({required this.state, required this.catalog});

  final TikTokArchiveState state;
  final TikTokArchiveCatalog catalog;

  @override
  ConsumerState<_Collections> createState() => _CollectionsState();
}

class _CollectionsState extends ConsumerState<_Collections> {
  bool _selecting = false;
  bool _classic = false;
  bool _purging = false;
  final Set<String> _selected = {};

  // Same virtual folders as today's view: views, not collections.
  static const _liked = 'Vidéos Likées';
  static const _unsorted = 'Favoris non classés';

  static bool _contains(TikTokCollectionItem col, TikTokArchiveItem v) {
    if (col.name == _liked) return v.isLiked;
    if (col.name == _unsorted) {
      return v.isFavorite &&
          v.collectionIds.isEmpty &&
          (v.collectionName == null ||
              v.collectionName == _unsorted ||
              v.collectionName == _liked);
    }
    return (col.id != null && v.collectionIds.contains(col.id)) ||
        (v.collectionName?.split(' · ').contains(col.name) ?? false);
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Confirms, then deletes the collections' own videos and their files
  /// (permanently); videos shared with a kept collection stay.
  Future<void> _purge() async {
    if (_selected.isEmpty || _purging) return;
    final l10n = context.l10n;
    final c = AppColors.of(context);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final keys = Set<String>.of(_selected);
    final preview = notifier.purgePreview(keys);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(l10n.archivePurgeTitle(keys.length)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.archivePurgeBody(preview.videos, preview.files)),
            if (preview.keptShared > 0) ...[
              const SizedBox(height: 12),
              Text(
                l10n.archivePurgeKept(preview.keptShared),
                style: nocturneText(c, size: 12.5, color: c.textSecondary),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          NocturneButton(
            label: l10n.delete,
            icon: Icons.delete_forever_rounded,
            kind: NocturneButtonKind.danger,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _purging = true);
    try {
      final r = await notifier.purgeCollections(keys);
      if (!mounted) return;
      setState(() {
        _selecting = false;
        _selected.clear();
      });
      _notice(l10n.archivePurgeDone(r.filesDeleted, r.videosRemoved));
    } finally {
      if (mounted) setState(() => _purging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final catalog = widget.catalog;
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    if (_classic || widget.state.filter.selectedCollection != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_classic) ...[
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: NocturneButton(
                label: l10n.nocturneCardsView,
                icon: Icons.grid_view_rounded,
                kind: NocturneButtonKind.ghost,
                onTap: () => setState(() => _classic = false),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: NocturneCard(
              lift: false,
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: TikTokCollectionsView(catalog: catalog),
              ),
            ),
          ),
        ],
      );
    }
    final cards = <Widget>[];
    for (final col in catalog.collections) {
      final videos = [
        for (final v in catalog.videos)
          if (_contains(col, v)) v,
      ];
      final missing = [
        for (final v in videos)
          if (!v.isDownloaded) v,
      ];
      final key = col.id ?? col.name;
      final special = col.name == _liked || col.name == _unsorted;
      cards.add(
        _CollectionCard(
          collection: col,
          count: videos.length,
          downloaded: videos.length - missing.length,
          selecting: _selecting && !special,
          selected: _selected.contains(key),
          onTap: () {
            if (!_selecting) {
              notifier.selectCollection(key);
            } else if (!special) {
              setState(() {
                if (!_selected.remove(key)) _selected.add(key);
              });
            }
          },
          onDownload: missing.isEmpty || widget.state.isBatchDownloading
              ? null
              : () => notifier.downloadBatch(missing, limit: missing.length),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            NocturneButton(
              label: l10n.nocturneClassicView,
              icon: Icons.view_list_rounded,
              kind: NocturneButtonKind.ghost,
              onTap: () => setState(() => _classic = true),
            ),
            const SizedBox(width: 8),
            NocturneButton(
              label: _selecting ? l10n.nocturneDone : l10n.archivePurgeSelect,
              icon: Icons.check_box_outlined,
              kind: _selecting
                  ? NocturneButtonKind.plain
                  : NocturneButtonKind.ghost,
              tooltip: l10n.archivePurgeSelectTooltip,
              onTap: () => setState(() {
                _selecting = !_selecting;
                _selected.clear();
              }),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NocturneAutoGrid(minWidth: 220, children: cards),
                if (_selecting) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: c.surfaceHighlight,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: c.primary.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.archivePurgeSelectedCount(
                                  _selected.length,
                                ),
                                style: nocturneText(
                                  c,
                                  size: 14,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                l10n.nocturnePurgeHint,
                                style: nocturneText(
                                  c,
                                  size: 12.5,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        NocturneButton(
                          label: l10n.archivePurgeAction,
                          icon: Icons.delete_outline_rounded,
                          kind: NocturneButtonKind.danger,
                          onTap: _selected.isEmpty || _purging ? null : _purge,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.collection,
    required this.count,
    required this.downloaded,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onDownload,
  });

  final TikTokCollectionItem collection;
  final int count;
  final int downloaded;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final share = count == 0 ? 0.0 : downloaded / count;
    return Semantics(
      button: true,
      selected: selected,
      label: collection.name,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: NocturneCard(
            padding: const EdgeInsets.all(12),
            strongHighlight: selecting && selected,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 88,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: nocturneTint(collection.name.hashCode),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            Expanded(
                              child: FractionallySizedBox(
                                heightFactor: const [0.62, 0.82, 0.48][i],
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(
                                      alpha: 0.06,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (selecting)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.background.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: NocturneCheck(checked: selected),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              collection.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: nocturneText(
                                c,
                                size: 14.5,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              l10n.nocturneCountVideos(count),
                              style: nocturneMono(c, color: c.textDisabled),
                            ),
                            if (downloaded > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                downloaded == count
                                    ? l10n.nocturneAllDownloaded
                                    : l10n.nocturnePartDownloaded(
                                        (share * 100).round(),
                                      ),
                                style: nocturneText(
                                  c,
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: c.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (downloaded > 0)
                        NocturneRing(
                          value: share,
                          size: 36,
                          stroke: 4,
                          radius: 14,
                        )
                      else if (!selecting)
                        NocturneButton(
                          label: l10n.designDownload,
                          kind: NocturneButtonKind.ghost,
                          height: 30,
                          padding: 10,
                          fontSize: 12.5,
                          onTap: onDownload,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
