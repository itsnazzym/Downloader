import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/services/local_server_service.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_video_cache_provider.dart';
import 'package:modern_downloader/features/archive/presentation/views/modes/tiktok_collections_view.dart';
import 'package:modern_downloader/features/archive/presentation/views/widgets/tiktok_filter_pane.dart';
import 'package:modern_downloader/features/archive/presentation/views/widgets/tiktok_video_card.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';

import 'signal_controls.dart';
import 'signal_states.dart';
import 'signal_widgets.dart';

/// Signal's TikTok archive (mockup Signal-Archives.dc.html): an archive
/// card, Vidéos / Collections / Favoris chips, then the collection cards
/// with their purge bar, or the video list. With nothing imported yet, its
/// own empty state; the hub (sync results) and loading stay today's view
/// ([current]).
class SignalArchive extends ConsumerWidget {
  const SignalArchive({super.key, required this.current});

  final Widget current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (today, empty) = ref.watch(
      tikTokArchiveProvider.select(
        (s) => (
          s.isLoading || s.viewMode == TikTokViewMode.hub || !s.hasCatalog,
          !s.isLoading &&
              !s.hasCatalog &&
              s.syncStatus != TikTokSyncStatus.waiting,
        ),
      ),
    );
    if (empty) return const _ArchiveEmpty();
    return today ? current : const _ArchivePage();
  }
}

/// Nothing imported yet: import the TikTok export, or sync through the
/// browser extension (today's hub handlers).
class _ArchiveEmpty extends ConsumerWidget {
  const _ArchiveEmpty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final showcase = ref.watch(showcaseModeProvider);
    final connected =
        !showcase && ref.watch(extensionConnectedClientsProvider) > 0;
    final error = ref.watch(
      tikTokArchiveProvider.select((s) => s.errorMessage),
    );
    final n = ref.read(tikTokArchiveProvider.notifier);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: signalPagePadding(constraints.maxWidth),
        child: SignalStateCard(
          eyebrow: l10n.designArchivesTab,
          eyebrowColor: error != null ? colors.error : null,
          title: l10n.signalArchiveEmptyTitle,
          body: error ?? l10n.signalArchiveEmptyBody,
          art: const SignalEmptyArt(),
          actions: [
            SignalButton(
              label: l10n.signalArchiveImport,
              icon: Icons.file_open_outlined,
              onTap: showcase ? null : n.pickAndImportFile,
            ),
            if (connected)
              SignalButton(
                label: l10n.signalArchiveSync,
                icon: Icons.sync_rounded,
                accent: false,
                onTap: n.triggerExtensionSync,
              )
            else
              // Sync needs the extension: say so instead of a dead button.
              Tooltip(
                message: l10n.signalArchiveSyncHint,
                child: Opacity(
                  opacity: 0.45,
                  child: SignalButton(
                    label: l10n.signalArchiveSync,
                    icon: Icons.sync_rounded,
                    accent: false,
                    onTap: null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const _liked = 'Vidéos Likées';
const _unsorted = 'Favoris non classés';

bool _isSpecial(TikTokCollectionItem c) =>
    c.name == _liked || c.name == _unsorted;

/// Videos of [c] still listed (same rule as today's collections view).
List<TikTokArchiveItem> _videosOf(
  TikTokArchiveCatalog catalog,
  TikTokCollectionItem c,
  Set<String> unavailable,
) {
  return catalog.videos.where((v) {
    if (unavailable.contains(v.id)) return false;
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
  }).toList();
}

class _ArchivePage extends ConsumerStatefulWidget {
  const _ArchivePage();

  @override
  ConsumerState<_ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends ConsumerState<_ArchivePage> {
  final _search = TextEditingController();
  String _collQuery = '';
  bool _selecting = false;
  bool _purging = false;
  bool _detailed = false;
  final Set<String> _selected = {};

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

  void _setTab(int tab) {
    final n = ref.read(tikTokArchiveProvider.notifier);
    _search.clear();
    _collQuery = '';
    n.setSearchQuery('');
    if (tab == 1) {
      n.setViewMode(TikTokViewMode.collections);
    } else {
      n.setStatusFilter(
        tab == 2 ? TikTokStatusFilter.favoritesOnly : TikTokStatusFilter.all,
      );
      n.setViewMode(TikTokViewMode.list);
    }
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  Future<void> _downloadAll(List<TikTokArchiveItem> videos) async {
    final l10n = context.l10n;
    final todo = videos.where((v) => !v.isDownloaded).toList();
    if (todo.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.signalArchiveConfirmAll(todo.length)),
        content: Text(l10n.signalArchiveConfirmAllBody),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.archiveMobileDownload),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref
        .read(tikTokArchiveProvider.notifier)
        .downloadBatch(todo, limit: todo.length);
    _notice(l10n.archiveMobileBatchStarted);
  }

  /// Confirms, then deletes the collections, their exclusive videos and
  /// their downloaded files. Shared videos are kept.
  Future<void> _confirmPurge() async {
    final keys = Set.of(_selected);
    if (keys.isEmpty || _purging) return;
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final preview = notifier.purgePreview(keys);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
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
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: Text(l10n.delete),
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

  Future<void> _confirmClear() async {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.archiveCollClear),
        content: Text(l10n.archiveCollClearBody),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.archiveCollClearConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(tikTokArchiveProvider.notifier).clearCatalog();
    _notice(l10n.archiveCollClearDone);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tikTokArchiveProvider);
    final catalog = state.catalog!;
    final unavailable = ref.watch(showcaseModeProvider)
        ? <String>{}
        : ref.watch(tiktokUnavailableIdsProvider).valueOrNull ??
              ref.read(tiktokVideoCacheServiceProvider).unavailableIds;
    final collectionsMode = state.viewMode == TikTokViewMode.collections;
    final tab = collectionsMode
        ? 1
        : (state.filter.statusFilter == TikTokStatusFilter.favoritesOnly
              ? 2
              : 0);
    final opened = state.filter.selectedCollection;
    final collections = [
      for (final c in catalog.collections)
        if (_collQuery.isEmpty ||
            c.name.toLowerCase().contains(_collQuery.toLowerCase()))
          (c, _videosOf(catalog, c, unavailable)),
    ];
    final videos = collectionsMode
        ? const <TikTokArchiveItem>[]
        : ref.watch(filteredTikTokVideosProvider);

    Widget content;
    if (collectionsMode && (opened != null || _detailed)) {
      // An opened collection and the detailed tools (suggestions, poster
      // view, delete one collection) stay today's view.
      content = TikTokCollectionsView(catalog: catalog);
    } else if (collectionsMode) {
      content = _CollectionGrid(
        collections: collections,
        selecting: _selecting,
        selected: _selected,
        onTap: (c) {
          final key = c.id ?? c.name;
          if (!_selecting) {
            ref.read(tikTokArchiveProvider.notifier).selectCollection(key);
          } else if (!_isSpecial(c)) {
            setState(() {
              if (!_selected.remove(key)) _selected.add(key);
            });
          }
        },
        onDownload: (list) => _downloadAll(list),
        bar: _selecting
            ? _PurgeBar(
                count: _selected.length,
                busy: _purging,
                onClear: () => setState(_selected.clear),
                onPurge: _selected.isEmpty ? null : _confirmPurge,
              )
            : null,
      );
    } else {
      content = _VideoList(videos: videos, onNotice: _notice);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = signalPagePadding(constraints.maxWidth);
        return Padding(
          padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ArchiveCard(
                catalog: catalog,
                onSync: () => ref
                    .read(tikTokArchiveProvider.notifier)
                    .setViewMode(TikTokViewMode.hub),
                onDownloadAll: () => _downloadAll(catalog.videos),
              ),
              const SizedBox(height: 24),
              _TabsRow(
                tab: tab,
                count: collectionsMode ? collections.length : videos.length,
                onTab: _setTab,
                search: _search,
                searchHint: collectionsMode
                    ? context.l10n.archiveCollSearch
                    : context.l10n.archiveMobileSearchHint,
                onSearch: (q) {
                  if (collectionsMode) {
                    setState(() => _collQuery = q.trim());
                  } else {
                    ref.read(tikTokArchiveProvider.notifier).setSearchQuery(q);
                  }
                },
                trailing: [
                  if (collectionsMode && opened == null && !_detailed)
                    SignalButton(
                      label: _selecting
                          ? context.l10n.onboardingDone
                          : context.l10n.archivePurgeSelect,
                      icon: Icons.check_box_outlined,
                      accent: false,
                      height: 36,
                      fontSize: 13,
                      onTap: () => setState(() {
                        _selecting = !_selecting;
                        _selected.clear();
                      }),
                    ),
                  if (!collectionsMode) _ListSelection(videos: videos),
                  _MoreMenu(
                    collectionsMode: collectionsMode,
                    detailed: _detailed,
                    onDetailed: () => setState(() {
                      _detailed = !_detailed;
                      _selecting = false;
                      _selected.clear();
                    }),
                    onClear: _confirmClear,
                  ),
                ],
              ),
              const _BatchProgress(),
              const SizedBox(height: 16),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}

// ── Archive card ────────────────────────────────────────────────────────────

class _ArchiveCard extends ConsumerWidget {
  const _ArchiveCard({
    required this.catalog,
    required this.onSync,
    required this.onDownloadAll,
  });

  final TikTokArchiveCatalog catalog;
  final VoidCallback onSync;
  final VoidCallback onDownloadAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final fmt = NumberFormat.decimalPattern(l10n.localeName);
    final batch = ref.watch(
      tikTokArchiveProvider.select((s) => s.isBatchDownloading),
    );
    final sync = ref.watch(tikTokArchiveProvider.select((s) => s.syncStatus));
    final syncMessage = ref.watch(
      tikTokArchiveProvider.select((s) => s.syncMessage),
    );
    final downloaded = catalog.videos.where((v) => v.isDownloaded).length;
    // No account name nor last sync date in an archive: the title is the
    // archive's, the line under it the sync state or what is downloaded.
    final line = switch (sync) {
      TikTokSyncStatus.waiting => l10n.archiveMobileSyncWaiting,
      TikTokSyncStatus.idle => l10n.signalArchiveDownloaded(downloaded),
      _ => syncMessage ?? l10n.signalArchiveDownloaded(downloaded),
    };
    final stats = [
      (l10n.signalArchiveVideosTab, catalog.totalUniqueVideos),
      (l10n.signalArchiveCollectionsTab, catalog.collections.length),
      (l10n.archiveMobileFilterFavorites, catalog.totalFavorites),
    ];
    return SignalCard(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        spacing: 32,
        runSpacing: 20,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 320, maxWidth: 480),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.alphaBlend(
                      colors.warning.withValues(alpha: 0.12),
                      colors.surfaceHighlight,
                    ),
                    border: Border.all(
                      color: colors.textPrimary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 26,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            l10n.archiveMobileTitle,
                            style: AppTypography.display(
                              28,
                              weight: FontWeight.w600,
                            ).copyWith(color: colors.textPrimary, height: 1.15),
                          ),
                          Container(
                            height: 24,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: colors.textPrimary.withValues(
                                  alpha: 0.12,
                                ),
                              ),
                            ),
                            child: Center(
                              widthFactor: 1,
                              child: Text(
                                l10n.signalArchiveLocal,
                                style: AppTypography.body.copyWith(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sync_rounded,
                            size: 14,
                            color: colors.textDisabled,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              line,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body.copyWith(
                                fontSize: 13,
                                color: colors.textDisabled,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, n) in stats) ...[
                if (label != stats.first.$1) const SizedBox(width: 32),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SignalEyebrow(label),
                    const SizedBox(height: 2),
                    Text(
                      fmt.format(n),
                      style: AppTypography.display(
                        30,
                        weight: FontWeight.w600,
                      ).copyWith(color: colors.textPrimary),
                    ),
                  ],
                ),
              ],
              const SizedBox(width: 32),
              SignalButton(
                label: l10n.signalArchiveSync,
                icon: Icons.sync_rounded,
                accent: false,
                onTap: onSync,
              ),
              const SizedBox(width: 10),
              if (batch)
                SignalButton(
                  label: l10n.archiveMobileStopBatch,
                  icon: Icons.stop_rounded,
                  accent: false,
                  onTap: ref.read(tikTokArchiveProvider.notifier).stopBatch,
                )
              else
                SignalButton(
                  label: l10n.signalArchiveDownloadAll,
                  icon: Icons.download_rounded,
                  onTap: downloaded < catalog.videos.length
                      ? onDownloadAll
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BatchProgress extends ConsumerWidget {
  const _BatchProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final (running, done, total, skipped) = ref.watch(
      tikTokArchiveProvider.select(
        (s) => (
          s.isBatchDownloading,
          s.batchCompletedCount,
          s.batchTotalCount,
          s.batchSkippedCount,
        ),
      ),
    );
    if (!running) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Text(
            l10n.archiveMobileBatchRunning,
            style: AppTypography.body.copyWith(
              fontSize: 12.5,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SignalMeter(
              value: total > 0 ? done / total : 0,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            [
              '$done / $total',
              if (skipped > 0) l10n.archiveMobileSkippedVideos(skipped),
            ].join(' · '),
            style: AppTypography.mono.copyWith(
              fontSize: 12.5,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chips row ───────────────────────────────────────────────────────────────

class _TabsRow extends StatelessWidget {
  const _TabsRow({
    required this.tab,
    required this.count,
    required this.onTab,
    required this.search,
    required this.searchHint,
    required this.onSearch,
    required this.trailing,
  });

  final int tab;
  final int count;
  final ValueChanged<int> onTab;
  final TextEditingController search;
  final String searchHint;
  final ValueChanged<String> onSearch;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final labels = [
      l10n.signalArchiveVideosTab,
      l10n.signalArchiveCollectionsTab,
      l10n.archiveMobileFilterFavorites,
    ];
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 12,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              SignalChip(
                label: labels[i],
                selected: tab == i,
                onTap: () => onTab(i),
              ),
            ],
            const SizedBox(width: 16),
            Text(
              '$count',
              style: AppTypography.mono.copyWith(
                fontSize: 13,
                color: colors.textDisabled,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              child: SignalInset(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: colors.textDisabled,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: search,
                        onChanged: onSearch,
                        style: AppTypography.body.copyWith(
                          fontSize: 13,
                          color: colors.textPrimary,
                        ),
                        decoration: signalBareInput(context, searchHint),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (final w in trailing) ...[const SizedBox(width: 10), w],
          ],
        ),
      ],
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.collectionsMode,
    required this.detailed,
    required this.onDetailed,
    required this.onClear,
  });

  final bool collectionsMode;
  final bool detailed;
  final VoidCallback onDetailed;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    TextStyle style([Color? c]) => AppTypography.body.copyWith(
      fontSize: 13.5,
      color: c ?? colors.textPrimary,
    );
    return PopupMenuButton<int>(
      tooltip: l10n.moreActions,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.borderSubtle),
      ),
      onSelected: (v) => v == 0 ? onDetailed() : onClear(),
      itemBuilder: (context) => [
        if (collectionsMode)
          PopupMenuItem(
            value: 0,
            child: Text(
              detailed
                  ? l10n.signalArchiveCardView
                  : l10n.archiveMobileManageCollections,
              style: style(),
            ),
          ),
        PopupMenuItem(
          value: 1,
          child: Text(l10n.archiveCollClear, style: style(colors.error)),
        ),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.textPrimary.withValues(alpha: 0.16)),
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          size: 18,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

// ── Collections ─────────────────────────────────────────────────────────────

class _CollectionGrid extends StatelessWidget {
  const _CollectionGrid({
    required this.collections,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onDownload,
    required this.bar,
  });

  final List<(TikTokCollectionItem, List<TikTokArchiveItem>)> collections;
  final bool selecting;
  final Set<String> selected;
  final ValueChanged<TikTokCollectionItem> onTap;
  final ValueChanged<List<TikTokArchiveItem>> onDownload;
  final Widget? bar;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (collections.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          context.l10n.archiveCollEmpty,
          style: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
      );
    }
    return Stack(
      children: [
        GridView.builder(
          padding: EdgeInsets.only(bottom: bar == null ? 40 : 110),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 320,
            mainAxisExtent: 199,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: collections.length,
          itemBuilder: (context, i) {
            final (c, videos) = collections[i];
            final key = c.id ?? c.name;
            return _CollectionCard(
              collection: c,
              videos: videos,
              index: i,
              selecting: selecting,
              selected: selected.contains(key),
              onTap: () => onTap(c),
              onDownload: () => onDownload(videos),
            );
          },
        ),
        if (bar != null) Positioned(left: 0, right: 0, bottom: 16, child: bar!),
      ],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.collection,
    required this.videos,
    required this.index,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onDownload,
  });

  final TikTokCollectionItem collection;
  final List<TikTokArchiveItem> videos;
  final int index;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  static bool _trusted(String? url) {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    const hosts = [
      'tiktokcdn.com',
      'tiktokv.com',
      'byteoversea.com',
      'ibytedtos.com',
      'byteimg.com',
    ];
    return hosts.any((h) => uri.host == h || uri.host.endsWith('.$h'));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final special = _isSpecial(collection);
    final total = videos.length;
    final done = videos.where((v) => v.isDownloaded).length;
    final tints = [
      colors.warning,
      colors.success,
      colors.textSecondary,
      colors.info,
      colors.error,
    ];
    Color tone(int k) => Color.alphaBlend(
      tints[(index + k) % tints.length].withValues(alpha: 0.07),
      colors.surfaceHighlight,
    );
    Widget tile(int k, {String? url}) => ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: tone(k),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.textPrimary.withValues(alpha: 0.06)),
          image: url != null
              ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
              : null,
        ),
      ),
    );
    final cover = _trusted(collection.coverUrl) ? collection.coverUrl : null;
    Widget status;
    if (total > 0 && done == total) {
      status = Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 12, color: colors.onPrimary),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.signalArchiveAllDone,
            style: AppTypography.body.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
        ],
      );
    } else if (done > 0) {
      status = Row(
        children: [
          Expanded(
            child: SignalMeter(value: done / total, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Text(
            '${(done * 100 / total).round()} %',
            style: AppTypography.mono.copyWith(
              fontSize: 12.5,
              color: colors.textSecondary,
            ),
          ),
        ],
      );
    } else {
      status = Row(
        children: [
          Expanded(
            child: Text(
              l10n.signalArchiveNotDownloaded,
              style: AppTypography.body.copyWith(
                fontSize: 12.5,
                color: colors.textDisabled,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(6, 0),
            child: SignalIconButton(
              icon: Icons.download_rounded,
              tooltip: l10n.archiveCollDownloadAll(total),
              size: 30,
              iconSize: 15,
              onTap: total == 0 ? null : onDownload,
            ),
          ),
        ],
      );
    }
    final card = SignalCard(
      lift: true,
      padding: const EdgeInsets.all(14),
      ring: selected ? colors.textPrimary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: tile(0, url: cover)),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: tile(1)),
                      const SizedBox(height: 4),
                      Expanded(child: tile(2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  collection.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.archiveMobileVideoCount(total),
                style: AppTypography.mono.copyWith(
                  fontSize: 12.5,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(height: 24, child: status),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selecting ? selected : null,
      label: collection.name,
      child: Opacity(
        opacity: selecting && special ? 0.4 : 1,
        child: Stack(
          children: [
            Positioned.fill(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(onTap: onTap, child: card),
              ),
            ),
            if (selecting && !special)
              Positioned(
                top: 22,
                right: 22,
                child: GestureDetector(
                  onTap: onTap,
                  child: AnimatedContainer(
                    duration: signalMotion(context, 180),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.textPrimary
                          : colors.inputBackground.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? colors.textPrimary
                            : colors.textPrimary.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: colors.background,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PurgeBar extends StatelessWidget {
  const _PurgeBar({
    required this.count,
    required this.busy,
    required this.onClear,
    required this.onPurge,
  });

  final int count;
  final bool busy;
  final VoidCallback onClear;
  final VoidCallback? onPurge;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 12, 12),
      decoration: BoxDecoration(
        color: colors.surfaceHighlight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.textPrimary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            blurRadius: 48,
            spreadRadius: -12,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count ${l10n.archiveMobileSelectedLabel(count)}',
                  style: AppTypography.display(
                    18,
                    weight: FontWeight.w600,
                  ).copyWith(color: colors.textPrimary, height: 1.2),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.signalArchiveSharedKept,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    fontSize: 12.5,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          SignalButton(
            label: l10n.deselectAll,
            accent: false,
            height: 40,
            fontSize: 13,
            onTap: count == 0 || busy ? null : onClear,
          ),
          const SizedBox(width: 10),
          _DangerButton(
            label: l10n.archivePurgeAction,
            busy: busy,
            onTap: busy ? null : onPurge,
          ),
        ],
      ),
    );
  }
}

class _DangerButton extends StatefulWidget {
  const _DangerButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  State<_DangerButton> createState() => _DangerButtonState();
}

class _DangerButtonState extends State<_DangerButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final enabled = widget.onTap != null;
    return Opacity(
      opacity: enabled || widget.busy ? 1 : 0.45,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (h) => setState(() => _hover = h),
        borderRadius: BorderRadius.circular(999),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        focusColor: colors.error.withValues(alpha: 0.2),
        child: AnimatedContainer(
          duration: signalMotion(context, 180),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: _hover && enabled
                ? colors.error.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.error.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.busy)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.error,
                  ),
                )
              else
                Icon(
                  Icons.delete_outline_rounded,
                  size: 15,
                  color: colors.error,
                ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: AppTypography.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Videos ──────────────────────────────────────────────────────────────────

class _ListSelection extends ConsumerWidget {
  const _ListSelection({required this.videos});

  final List<TikTokArchiveItem> videos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final n = ref.read(tikTokArchiveProvider.notifier);
    final count = ref.watch(
      tikTokArchiveProvider.select((s) => s.selectedIds.length),
    );
    final batch = ref.watch(
      tikTokArchiveProvider.select((s) => s.isBatchDownloading),
    );
    if (count == 0) {
      return SignalButton(
        label: l10n.archiveMobileSelectAll,
        icon: Icons.check_box_outlined,
        accent: false,
        height: 36,
        fontSize: 13,
        onTap: videos.isEmpty ? null : () => n.selectAll(videos),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SignalButton(
          label: '$count ${l10n.archiveMobileSelectedLabel(count)}',
          icon: Icons.close_rounded,
          accent: false,
          height: 36,
          fontSize: 13,
          onTap: n.clearSelection,
        ),
        const SizedBox(width: 10),
        SignalButton(
          label: l10n.signalArchiveDownloadSelection,
          icon: Icons.download_rounded,
          height: 36,
          fontSize: 13,
          onTap: batch ? null : () => n.downloadSelected(),
        ),
      ],
    );
  }
}

class _VideoList extends ConsumerWidget {
  const _VideoList({required this.videos, required this.onNotice});

  final List<TikTokArchiveItem> videos;
  final ValueChanged<String> onNotice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final n = ref.read(tikTokArchiveProvider.notifier);
    final selected = ref.watch(
      tikTokArchiveProvider.select((s) => s.selectedIds),
    );
    final Widget list;
    if (videos.isEmpty) {
      list = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.archiveMobileNoVideos,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 14),
            SignalButton(
              label: l10n.archiveMobileReset,
              accent: false,
              height: 36,
              fontSize: 13,
              onTap: n.resetFilters,
            ),
          ],
        ),
      );
    } else {
      list = ListView.builder(
        padding: const EdgeInsets.only(bottom: 40),
        itemCount: videos.length,
        itemBuilder: (context, i) {
          final v = videos[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TikTokVideoCard(
              item: v,
              isSelected: selected.contains(v.id),
              onToggleSelect: () => n.toggleSelection(v.id),
              onDownload: () async {
                await n.downloadBatch([v], limit: 1);
                onNotice(l10n.archiveMobileVideoAdded);
              },
            ),
          );
        },
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 760) return list;
        // Today's filter pane (type, year, collections) beside the list.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: const TikTokFilterPane(),
            ),
            const SizedBox(width: 16),
            Expanded(child: list),
          ],
        );
      },
    );
  }
}
