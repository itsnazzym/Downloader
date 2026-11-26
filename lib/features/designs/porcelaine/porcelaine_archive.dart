import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/plugins/feature_activation.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/archive/presentation/views/modes/tiktok_collections_view.dart';
import 'package:modern_downloader/features/archive/presentation/views/widgets/tiktok_filter_pane.dart';
import 'package:modern_downloader/features/archive/presentation/views/widgets/tiktok_video_card.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';

import 'porcelaine_widgets.dart';

/// Porcelaine's TikTok archive (Porcelaine-Archives.dc.html): the archive
/// card with its figures and actions, the Vidéos / Collections / Favoris
/// tabs, then the video list (filters, search, selection) or the collection
/// cards (« Sélectionner », purge). An opened collection and « Plus
/// d'options… » show today's collections view. Loading, the import hub, an
/// empty archive and windows under 900 px keep today's view.
class PorcelaineArchive extends ConsumerWidget {
  const PorcelaineArchive({super.key, required this.current});

  final Widget current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final title =
        ref
            .watch(featureCatalogProvider)
            .byId['tiktok_archives']
            ?.nameFor(locale) ??
        l10n.archiveMobileTitle;
    final (browsing, mode, opened) = ref.watch(
      tikTokArchiveProvider.select(
        (s) => (
          !s.isLoading && s.hasCatalog && s.viewMode != TikTokViewMode.hub,
          s.viewMode,
          s.filter.selectedCollection != null,
        ),
      ),
    );
    final full = ref.watch(_fullProvider);
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.maxWidth > 1284 ? (box.maxWidth - 1220) / 2 : 32.0;
        // Below 900 the filters and video cards no longer fit side by side:
        // today's view (its own desktop or phone layout) is kept whole.
        final native = browsing && box.maxWidth >= 900;
        final Widget body;
        if (!native) {
          body = _Sheet(child: current);
        } else if (mode != TikTokViewMode.collections) {
          body = const _Sheet(child: _VideoBrowser());
        } else if (opened || full) {
          body = _Sheet(
            child: TikTokCollectionsView(
              catalog: ref.read(tikTokArchiveProvider).catalog!,
            ),
          );
        } else {
          body = const _CollectionsGrid();
        }
        // The grid's cards draw their ring and shadow past their box: its
        // scroll view gets [_bleed] of room on its sides, [_top] above.
        final grid = body is _CollectionsGrid;
        return Padding(
          padding: EdgeInsets.fromLTRB(side - _bleed, 0, side - _bleed, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _bleed),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PPageTitle(title: title),
                    const SizedBox(height: 26),
                    if (native) ...[
                      const _ArchiveCard(),
                      const SizedBox(height: 20),
                      const _Tabs(),
                      SizedBox(height: grid ? 20 - _top : 20),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: grid
                    ? body
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: _bleed),
                        child: body,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

const double _bleed = 24;
const double _top = 12;

/// « Plus d'options… »: today's collections view in place of the cards.
final _fullProvider = StateProvider.autoDispose<bool>((ref) => false);
final _selectingProvider = StateProvider.autoDispose<bool>((ref) => false);
final _selectedProvider = StateProvider.autoDispose<Set<String>>(
  (ref) => const {},
);

/// The frosted sheet that holds a list or today's views.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pCardFill(colors),
        borderRadius: BorderRadius.circular(28),
        boxShadow: pCardShadow(colors),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class _ArchiveCard extends ConsumerWidget {
  const _ArchiveCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final s = ref.watch(
      tikTokArchiveProvider.select(
        (s) => (
          videos: s.catalog?.totalUniqueVideos ?? 0,
          collections: s.catalog?.collections.length ?? 0,
          favorites: s.catalog?.totalFavorites ?? 0,
          pending: s.catalog?.videos.where((v) => !v.isDownloaded).length ?? 0,
          batch: s.isBatchDownloading,
          done: s.batchCompletedCount,
          total: s.batchTotalCount,
          sync: s.syncMessage,
        ),
      ),
    );
    final notifier = ref.read(tikTokArchiveProvider.notifier);

    Future<void> downloadAll() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: colors.surface,
          title: Text(l10n.studioDownloadAll),
          content: Text(l10n.studioDownloadAllConfirm(s.pending)),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
      if (ok != true) return;
      final pending = [
        for (final v in ref.read(tikTokArchiveProvider).catalog!.videos)
          if (!v.isDownloaded) v,
      ];
      await notifier.downloadBatch(pending, limit: pending.length);
    }

    Widget figure(int n, String label) => Padding(
      padding: const EdgeInsetsDirectional.only(start: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$n',
            style: pDisp(30, color: colors.textPrimary).copyWith(height: 1),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: pBody(colors, size: 12.5, color: colors.textSecondary),
          ),
        ],
      ),
    );
    // No account name in the archive: the mockup's « LC @lea.cuisine »
    // becomes the archive's icon and title.
    final identity = Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFD8CFBD),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colors.textPrimary.withValues(alpha: 0.06),
            ),
          ),
          child: Icon(
            Icons.inventory_2_outlined,
            size: 24,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 4,
                children: [
                  Text(
                    l10n.archiveMobileTitle,
                    style: pDisp(26, color: colors.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.inputBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.porcelaineLocalArchive,
                      style: pBody(
                        colors,
                        size: 12,
                        weight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (s.sync != null && s.sync!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        s.sync!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: pBody(
                          colors,
                          size: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final figures = [
      figure(s.videos, l10n.porcelaineArchiveVideos),
      figure(s.collections, l10n.porcelaineArchiveCollections),
      figure(s.favorites, l10n.porcelaineArchiveFavorites),
    ];
    final actions = [
      // Import and sync live in today's archive hub.
      PBtn(
        label: l10n.porcelaineSync,
        icon: Icons.sync_rounded,
        tooltip: l10n.archiveMobileSyncTooltip,
        onTap: () => notifier.setViewMode(TikTokViewMode.hub),
      ),
      if (s.batch)
        PBtn(
          label: '${l10n.archiveMobileStopBatch} · ${s.done}/${s.total}',
          icon: Icons.stop_rounded,
          kind: PBtnKind.dark,
          onTap: notifier.stopBatch,
        )
      else
        PBtn(
          label: l10n.studioDownloadAll,
          icon: Icons.download_rounded,
          kind: PBtnKind.accent,
          onTap: s.pending == 0 ? null : downloadAll,
        ),
    ];
    return PCard(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth >= 1000) {
            return Row(
              children: [
                Expanded(child: identity),
                ...figures,
                const SizedBox(width: 28),
                actions.first,
                const SizedBox(width: 8),
                actions.last,
              ],
            );
          }
          // Narrow: the identity, then the figures and actions wrap.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [...figures, const SizedBox(width: 20), ...actions],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Tabs extends ConsumerWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final (mode, favorites, opened, videos, collections, favs) = ref.watch(
      tikTokArchiveProvider.select(
        (s) => (
          s.viewMode,
          s.filter.statusFilter == TikTokStatusFilter.favoritesOnly,
          s.filter.selectedCollection != null,
          s.catalog?.totalUniqueVideos ?? 0,
          s.catalog?.collections.length ?? 0,
          s.catalog?.totalFavorites ?? 0,
        ),
      ),
    );
    final full = ref.watch(_fullProvider);
    final selecting = ref.watch(_selectingProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final tab = mode == TikTokViewMode.collections ? 1 : (favorites ? 2 : 0);
    void endSelection() {
      ref.read(_selectingProvider.notifier).state = false;
      ref.read(_selectedProvider.notifier).state = const {};
    }

    void pick(int t) {
      endSelection();
      ref.read(_fullProvider.notifier).state = false;
      if (t == 1) {
        notifier.setViewMode(TikTokViewMode.collections);
        return;
      }
      notifier.setStatusFilter(
        t == 2 ? TikTokStatusFilter.favoritesOnly : TikTokStatusFilter.all,
      );
      notifier.setViewMode(TikTokViewMode.list);
    }

    final cards = tab == 1 && !opened && !full;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              colors.surface.withValues(alpha: 0.7),
              colors.background,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: colors.textPrimary.withValues(alpha: 0.07),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, label, n) in [
                (0, l10n.porcelaineArchiveVideosTab, videos),
                (1, l10n.porcelaineArchiveCollectionsTab, collections),
                (2, l10n.porcelaineArchiveFavoritesTab, favs),
              ]) ...[
                if (i > 0) const SizedBox(width: 4),
                PPill(
                  label: label,
                  trailing: '$n',
                  selected: tab == i,
                  transparent: true,
                  onTap: () => pick(i),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: cards && selecting
              ? Text(
                  l10n.porcelaineArchiveKeptHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: pBody(colors, size: 13, color: colors.textSecondary),
                )
              : const SizedBox.shrink(),
        ),
        if (tab == 1 && full)
          PBtn(
            label: l10n.porcelaineSimpleView,
            icon: Icons.arrow_back_rounded,
            onTap: () => ref.read(_fullProvider.notifier).state = false,
          ),
        if (cards) ...[
          if (!selecting) ...[
            PBtn(
              label: l10n.porcelaineMoreOptions,
              kind: PBtnKind.ghost,
              onTap: () => ref.read(_fullProvider.notifier).state = true,
            ),
            const SizedBox(width: 8),
          ],
          PBtn(
            label: selecting ? l10n.porcelaineDone : l10n.archivePurgeSelect,
            icon: Icons.check_box_outlined,
            kind: selecting ? PBtnKind.accent : PBtnKind.line,
            tooltip: selecting ? null : l10n.archivePurgeSelectTooltip,
            onTap: () {
              final next = !selecting;
              endSelection();
              ref.read(_selectingProvider.notifier).state = next;
            },
          ),
        ],
      ],
    );
  }
}

/// Today's video list on the Porcelaine sheet: filters beside it, search,
/// select, download.
class _VideoBrowser extends ConsumerStatefulWidget {
  const _VideoBrowser();

  @override
  ConsumerState<_VideoBrowser> createState() => _VideoBrowserState();
}

class _VideoBrowserState extends ConsumerState<_VideoBrowser> {
  late final _search = TextEditingController(
    text: ref.read(tikTokArchiveProvider).filter.searchQuery,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _notice(String message) {
    if (!mounted) return;
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
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final state = ref.watch(tikTokArchiveProvider);
    final videos = ref.watch(filteredTikTokVideosProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final favorites =
        state.filter.statusFilter == TikTokStatusFilter.favoritesOnly;
    final selected = state.selectedIds.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TikTokFilterPane(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                child: PHead(
                  icon: favorites
                      ? Icons.favorite_rounded
                      : Icons.video_library_outlined,
                  label: favorites
                      ? l10n.porcelaineArchiveFavoritesTab
                      : l10n.porcelaineArchiveVideosTab,
                  tint: favorites ? pPink : colors.primary,
                  trailing: Expanded(
                    child: Text(
                      l10n.archiveMobileVideoCount(videos.length),
                      textAlign: TextAlign.end,
                      style: pMono(colors, size: 12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 42,
                  padding: const EdgeInsetsDirectional.only(start: 14),
                  decoration: BoxDecoration(
                    color: colors.inputBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (v) {
                            notifier.setSearchQuery(v);
                            setState(() {});
                          },
                          style: pBody(colors, size: 13.5),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: l10n.archiveMobileSearchHint,
                            hintStyle: pBody(
                              colors,
                              size: 13.5,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      if (_search.text.isNotEmpty)
                        IconButton(
                          tooltip: l10n.archiveMobileClearSearch,
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () {
                            _search.clear();
                            notifier.setSearchQuery('');
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (selected == 0)
                      PBtn(
                        label: l10n.archiveMobileSelectAll,
                        kind: PBtnKind.ghost,
                        height: 36,
                        onTap: videos.isEmpty
                            ? null
                            : () => notifier.selectAll(videos),
                      )
                    else ...[
                      PBtn(
                        label: l10n.archiveMobileClearSelection,
                        kind: PBtnKind.ghost,
                        height: 36,
                        onTap: notifier.clearSelection,
                      ),
                      const SizedBox(width: 8),
                      PBtn(
                        label: l10n.porcelaineDownloadSelection(selected),
                        icon: Icons.download_rounded,
                        kind: PBtnKind.accent,
                        height: 36,
                        onTap: state.isBatchDownloading
                            ? null
                            : () async {
                                await notifier.downloadSelected();
                                _notice(l10n.pastilleQueued);
                              },
                      ),
                    ],
                  ],
                ),
              ),
              if (state.isBatchDownloading && state.batchTotalCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: PBar(
                          value:
                              state.batchCompletedCount / state.batchTotalCount,
                          height: 6,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        [
                          '${state.batchCompletedCount} / ${state.batchTotalCount}',
                          if (state.batchSkippedCount > 0)
                            l10n.archiveMobileSkippedVideos(
                              state.batchSkippedCount,
                            ),
                        ].join(' · '),
                        style: pMono(colors, size: 12),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: videos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.archiveMobileNoVideos,
                              style: pBody(colors, color: colors.textSecondary),
                            ),
                            const SizedBox(height: 14),
                            PBtn(
                              label: l10n.archiveMobileReset,
                              onTap: notifier.resetFilters,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 6, 24, 20),
                        itemCount: videos.length,
                        itemBuilder: (context, i) {
                          final v = videos[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: TikTokVideoCard(
                              item: v,
                              isSelected: state.selectedIds.contains(v.id),
                              onToggleSelect: () =>
                                  notifier.toggleSelection(v.id),
                              onDownload: () async {
                                if (ref.read(showcaseModeProvider)) {
                                  _notice(l10n.pastilleDemoDownload);
                                  return;
                                }
                                _notice(l10n.archiveMobileVideoAdded);
                                await notifier.downloadBatch([v], limit: 1);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Today's virtual folders: views over the videos, not purgeable.
const _liked = 'Vidéos Likées';
const _unsorted = 'Favoris non classés';

/// Same membership as today's collections view.
bool _inCollection(TikTokArchiveItem v, TikTokCollectionItem c) {
  if (c.name == _liked) return v.isLiked;
  if (c.name == _unsorted) {
    return v.isFavorite &&
        v.collectionIds.isEmpty &&
        (v.collectionName == null ||
            v.collectionName == _unsorted ||
            v.collectionName == _liked);
  }
  return (c.id != null && v.collectionIds.contains(c.id)) ||
      (v.collectionName?.split(' · ').contains(c.name) ?? false);
}

/// Today's collections view only loads covers from TikTok's CDNs.
String? _trustedCover(String? value) {
  final uri = value == null ? null : Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https') return null;
  final host = uri.host.toLowerCase();
  const domains = [
    'tiktokcdn.com',
    'tiktokv.com',
    'byteoversea.com',
    'ibytedtos.com',
    'byteimg.com',
  ];
  return domains.any((d) => host == d || host.endsWith('.$d')) ? value : null;
}

/// The collections as cards (mockup `.cgrid`): mosaic, name, video count,
/// how much is on this PC; in selection mode, checkboxes and the floating
/// « n sélectionnées · Supprimer leurs vidéos » bar.
class _CollectionsGrid extends ConsumerStatefulWidget {
  const _CollectionsGrid();

  @override
  ConsumerState<_CollectionsGrid> createState() => _CollectionsGridState();
}

class _CollectionsGridState extends ConsumerState<_CollectionsGrid> {
  bool _purging = false;
  TikTokArchiveCatalog? _catalog;
  List<
    ({String key, TikTokCollectionItem item, double fraction, bool purgeable})
  >
  _cards = const [];

  /// Same confirmation and purge as today's collections view.
  Future<void> _confirmPurge(Set<String> keys) async {
    if (keys.isEmpty || _purging) return;
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final preview = notifier.purgePreview(keys);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
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
                style: pBody(colors, size: 13, color: colors.textSecondary),
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
          PBtn(
            label: l10n.delete,
            icon: Icons.delete_outline_rounded,
            kind: PBtnKind.danger,
            height: 36,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _purging = true);
    try {
      final result = await notifier.purgeCollections(keys);
      if (!mounted) return;
      ref.read(_selectedProvider.notifier).state = const {};
      ref.read(_selectingProvider.notifier).state = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.archivePurgeDone(result.filesDeleted, result.videosRemoved),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _purging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(tikTokArchiveProvider.select((s) => s.catalog!));
    final selecting = ref.watch(_selectingProvider);
    final selected = ref.watch(_selectedProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    // Downloaded share per collection, once per catalog (not per toggle).
    if (!identical(catalog, _catalog)) {
      _catalog = catalog;
      _cards = [
        for (final c in catalog.collections)
          () {
            var done = 0, total = 0;
            for (final v in catalog.videos) {
              if (!_inCollection(v, c)) continue;
              total++;
              if (v.isDownloaded) done++;
            }
            return (
              key: c.id ?? c.name,
              item: c,
              fraction: total == 0 ? 0.0 : done / total,
              purgeable: c.name != _liked && c.name != _unsorted,
            );
          }(),
      ];
    }
    final cards = _cards;
    // `.abar` is sticky: right under a short grid, pinned to the bottom
    // once the grid scrolls (the loose Flexible gives exactly that).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            // Room below for the cards' shadow; the bar sits 22 under them.
            padding: EdgeInsets.fromLTRB(
              _bleed,
              _top,
              _bleed,
              selecting ? 22 : 48,
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                // `repeat(auto-fill, minmax(250px, 1fr))`, gap 16.
                final perRow = ((box.maxWidth + 16) / (250 + 16)).floor().clamp(
                  1,
                  8,
                );
                final width = ((box.maxWidth - 16 * (perRow - 1)) / perRow)
                    .floorToDouble();
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final card in cards)
                      SizedBox(
                        width: width,
                        child: _CollectionCard(
                          item: card.item,
                          fraction: card.fraction,
                          selecting: selecting && card.purgeable,
                          selected: selected.contains(card.key),
                          onTap: () {
                            if (!selecting) {
                              notifier.selectCollection(card.key);
                              return;
                            }
                            if (!card.purgeable) return;
                            final next = {...selected};
                            if (!next.remove(card.key)) next.add(card.key);
                            ref.read(_selectedProvider.notifier).state = next;
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        if (selecting) ...[
          Center(
            child: _SelectionBar(
              count: selected.length,
              onDelete: selected.isEmpty || _purging
                  ? null
                  : () => _confirmPurge(Set.of(selected)),
            ),
          ),
        ],
      ],
    );
  }
}

/// `.abar`: the dark floating selection bar.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.count, required this.onDelete});

  final int count;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final text = pBody(
      colors,
      size: 13.5,
      weight: FontWeight.w500,
      color: colors.background,
    );
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsetsDirectional.fromSTEB(20, 7, 7, 7),
        decoration: BoxDecoration(
          color: colors.textPrimary,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: 0.35),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.porcelaineSelectedCollections(count), style: text),
            const SizedBox(width: 12),
            Opacity(
              opacity: 0.5,
              child: ExcludeSemantics(child: Text('·', style: text)),
            ),
            const SizedBox(width: 12),
            PBtn(
              label: l10n.archivePurgeAction,
              kind: PBtnKind.danger,
              height: 36,
              fontSize: 13,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// `.wg.coll`: a collection card; the whole card is the checkbox while
/// selecting.
class _CollectionCard extends StatefulWidget {
  const _CollectionCard({
    required this.item,
    required this.fraction,
    required this.selecting,
    required this.selected,
    required this.onTap,
  });

  final TikTokCollectionItem item;
  final double fraction;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final item = widget.item;
    final ring = widget.selecting && widget.selected;
    final up = _hover || ring;
    final muted = pBody(colors, size: 12.5, color: colors.textSecondary);
    final Widget state;
    if (widget.fraction >= 1) {
      state = Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: pGreen,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 13,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.studioAllDownloaded,
            style: pBody(colors, size: 12.5, weight: FontWeight.w500),
          ),
        ],
      );
    } else if (widget.fraction > 0) {
      state = Row(
        children: [
          Expanded(child: PBar(value: widget.fraction, height: 6)),
          const SizedBox(width: 10),
          Text(
            '${(widget.fraction * 100).round()} %',
            style: pMono(colors, size: 12),
          ),
        ],
      );
    } else {
      state = Text(l10n.porcelaineNotDownloadedYet, style: muted);
    }
    final cover = _trustedCover(item.coverUrl);
    Widget thumb(String seed, [String? url]) =>
        PThumb(url: url, seed: seed, height: double.infinity, radius: 10);
    final card = AnimatedContainer(
      duration: pMotion(context, 300),
      curve: pEase,
      transform: Matrix4.translationValues(0, _hover && !ring ? -3 : 0, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pCardFill(colors),
        borderRadius: BorderRadius.circular(24),
        boxShadow: ring
            ? [
                BoxShadow(color: colors.primary, spreadRadius: 2),
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.18),
                  spreadRadius: 7,
                ),
                BoxShadow(
                  color: colors.textPrimary.withValues(alpha: 0.26),
                  blurRadius: 48,
                  spreadRadius: -16,
                  offset: const Offset(0, 24),
                ),
              ]
            : [
                if (_focus) BoxShadow(color: colors.primary, spreadRadius: 2),
                ...pCardShadow(colors, up: up),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 112,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: thumb('${item.name}1', cover)),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: thumb('${item.name}2')),
                      const SizedBox(height: 4),
                      Expanded(child: thumb('${item.name}3')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: pBody(
                          colors,
                          size: 14.5,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.porcelaineVideoCount(item.videoCount),
                      style: pMono(colors, size: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(height: 18, child: state),
              ],
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: !widget.selecting,
      checked: widget.selecting ? widget.selected : null,
      label: item.name,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onFocusChange: (v) => setState(() => _focus = v),
            borderRadius: BorderRadius.circular(24),
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            focusColor: Colors.transparent,
            child: Stack(
              children: [
                card,
                if (widget.selecting)
                  PositionedDirectional(
                    top: 22,
                    end: 22,
                    child: _Check(on: widget.selected, hover: _hover),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.ck`: the 24px checkbox.
class _Check extends StatelessWidget {
  const _Check({required this.on, required this.hover});

  final bool on;
  final bool hover;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedContainer(
      duration: pMotion(context, 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: on ? colors.primary : colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: on
            ? null
            : Border.all(
                color: hover
                    ? colors.primary
                    : colors.textPrimary.withValues(alpha: 0.45),
                width: 1.5,
              ),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: on ? 0.2 : 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: on
          ? Icon(Icons.check_rounded, size: 15, color: colors.onPrimary)
          : null,
    );
  }
}
