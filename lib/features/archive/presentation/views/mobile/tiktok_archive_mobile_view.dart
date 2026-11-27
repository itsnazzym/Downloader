import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tapload/core/ui/mobile/back_navigation.dart';
import 'package:tapload/core/ui/mobile/oled/oled_kit.dart';
import 'package:tapload/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/archive/presentation/views/modes/tiktok_feed_view.dart';
import 'package:tapload/l10n/l10n_ext.dart';
import 'package:tapload/showcase/showcase_mode.dart';
import 'archive_collection_label.dart';
import 'tiktok_collections_mobile_view.dart';
import '../archive_hub_view.dart';

/// Android OLED layout of the TikTok archive: a 3-column grid of tiles with
/// collection chips, live progress cards and a floating selection bar.
class TikTokArchiveMobileView extends ConsumerStatefulWidget {
  final TikTokArchiveCatalog catalog;

  const TikTokArchiveMobileView({super.key, required this.catalog});

  @override
  ConsumerState<TikTokArchiveMobileView> createState() =>
      _TikTokArchiveMobileViewState();
}

class _TikTokArchiveMobileViewState
    extends ConsumerState<TikTokArchiveMobileView> {
  late final TextEditingController _videoSearchController;

  /// When true, the collection management screen (rename, reset, delete,
  /// suggestions) is shown instead of the video grid.
  bool _manageCollections = false;
  VoidCallback? _unregisterBack;

  @override
  void initState() {
    super.initState();
    // Back leaves the collection manager before leaving the archive.
    _unregisterBack = ref.read(backInterceptorsProvider).register(() {
      if (!_manageCollections) return false;
      setState(() => _manageCollections = false);
      return true;
    });
    _videoSearchController = TextEditingController(
      text: ref.read(tikTokArchiveProvider).filter.searchQuery,
    );
  }

  @override
  void dispose() {
    _unregisterBack?.call();
    _videoSearchController.dispose();
    super.dispose();
  }

  void _showNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openFeed(List<TikTokArchiveItem> videos) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: TikTokFeedView(
          videos: videos,
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final t = OledTokens.of(context);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final catalog = ref.read(tikTokArchiveProvider).catalog ?? widget.catalog;
    final years = catalog.yearCounts.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.bg,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: t.line),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final filter = ref.watch(
              tikTokArchiveProvider.select((s) => s.filter),
            );
            final t = OledTokens.of(context);
            final l10n = context.l10n;

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.archiveMobileFilters,
                            style: OledText.title(context, size: 22),
                          ),
                        ),
                        OledButton(
                          label: l10n.archiveMobileReset,
                          filled: false,
                          expand: false,
                          height: 44,
                          onPressed: () {
                            notifier.resetFilters();
                            _videoSearchController.clear();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.archiveMobileType,
                      style: OledText.ui(context, size: 13, color: t.ink2),
                    ),
                    const SizedBox(height: 8),
                    OledSegmented<TikTokStatusFilter>(
                      options: {
                        TikTokStatusFilter.all: l10n.archiveMobileFilterAll,
                        TikTokStatusFilter.favoritesOnly:
                            l10n.archiveMobileFilterFavorites,
                        TikTokStatusFilter.likesOnly:
                            l10n.archiveMobileFilterLikes,
                      },
                      value: filter.statusFilter,
                      onChanged: notifier.setStatusFilter,
                    ),
                    if (years.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        l10n.archiveMobileYear,
                        style: OledText.ui(context, size: 13, color: t.ink2),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OledChip(
                            label: l10n.archiveMobileAllYears,
                            selected: filter.selectedYear == null,
                            onTap: () => notifier.selectYear(null),
                          ),
                          for (final y in years)
                            OledChip(
                              label: '$y',
                              count: catalog.yearCounts[y],
                              selected: filter.selectedYear == y,
                              onTap: () => notifier.selectYear(y),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    OledButton(
                      label: l10n.archiveMobileApplyFilters,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tikTokArchiveProvider);
    final filteredVideos = ref.watch(filteredTikTokVideosProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final isShowcase = ref.watch(showcaseModeProvider);
    final catalog = state.catalog ?? widget.catalog;
    final l10n = context.l10n;

    if (state.viewMode == TikTokViewMode.hub) {
      return const ArchiveHubView();
    }

    if (_manageCollections) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, notifier),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: OledChip(
                label: l10n.archiveMobileBackToVideos,
                selected: false,
                onTap: () => setState(() => _manageCollections = false),
              ),
            ),
            Expanded(
              child: TikTokCollectionsMobileView(
                catalog: widget.catalog,
                onShowVideos: () => setState(() => _manageCollections = false),
              ),
            ),
          ],
        ),
      );
    }

    final hasSelection = state.selectedIds.isNotEmpty;
    final batchLabel = state.isBatchDownloading
        ? '${state.batchCompletedCount}/${state.batchTotalCount}'
        : l10n.archiveMobileDownload;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildGrid(
              context,
              state: state,
              videos: filteredVideos,
              notifier: notifier,
              catalog: catalog,
              isShowcase: isShowcase,
            ),
          ),
          if (hasSelection)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: _SelectionBar(
                count: state.selectedIds.length,
                actionLabel: batchLabel,
                onClear: notifier.clearSelection,
                onAction: state.isBatchDownloading
                    ? null
                    : () async {
                        _showNotice(l10n.archiveMobileBatchStarted);
                        await notifier.downloadSelected();
                      },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TikTokArchiveNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.archiveMobileTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OledText.title(context, size: 28),
            ),
          ),
          OledIconButton(
            icon: Icons.sync_rounded,
            tooltip: context.l10n.archiveMobileSyncTooltip,
            onPressed: () => notifier.setViewMode(TikTokViewMode.hub),
          ),
          const SizedBox(width: 8),
          OledIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: context.l10n.archiveMobileBackToLibrary,
            onPressed: () => context.go('/'),
          ),
        ],
      ),
    );
  }

  /// Progress cards, only for activity the provider really reports: the batch
  /// download counters and the pending browser sync.
  List<Widget> _buildActivityCards(
    BuildContext context,
    TikTokArchiveState state,
    TikTokArchiveNotifier notifier,
  ) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final cards = <Widget>[];

    if (state.isBatchDownloading) {
      final done = state.batchCompletedCount;
      final total = state.batchTotalCount;
      final figure = OledText.dot(context, size: 40);
      cards.add(
        OledCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const OledLiveDot(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.archiveMobileBatchRunning,
                      style: OledText.ui(context, size: 13, color: t.ink2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  text: '$done',
                  style: figure,
                  children: [
                    TextSpan(
                      text: '/$total',
                      style: figure.copyWith(color: t.ink3),
                    ),
                  ],
                ),
              ),
              if (state.batchSkippedCount > 0) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.archiveMobileSkippedVideos(state.batchSkippedCount),
                  style: OledText.ui(context, size: 13, color: t.ink2),
                ),
              ],
              const SizedBox(height: 12),
              _SegmentedProgress(value: total > 0 ? done / total : 0),
              const SizedBox(height: 12),
              OledButton(
                label: l10n.archiveMobileStopBatch,
                filled: false,
                height: 44,
                onPressed: notifier.stopBatch,
              ),
            ],
          ),
        ),
      );
    }

    if (state.syncStatus == TikTokSyncStatus.waiting) {
      cards.add(
        OledCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const OledLiveDot(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.archiveMobileSyncingCollections,
                      style: OledText.ui(
                        context,
                        size: 15,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.archiveMobileSyncWaiting,
                style: OledText.ui(context, size: 13, color: t.ink2),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  color: t.ink,
                  backgroundColor: t.fillStrong,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return cards;
  }

  Widget _buildChips(
    BuildContext context,
    TikTokArchiveState state,
    TikTokArchiveNotifier notifier,
    TikTokArchiveCatalog catalog,
  ) {
    final filter = state.filter;
    final l10n = context.l10n;
    final chips = <Widget>[
      OledChip(
        label: l10n.archiveMobileChipAll,
        selected:
            filter.selectedCollection == null &&
            filter.statusFilter == TikTokStatusFilter.all,
        onTap: () {
          notifier.selectCollection(null);
          notifier.setStatusFilter(TikTokStatusFilter.all);
        },
      ),
      OledChip(
        label: l10n.archiveMobileFilterFavorites,
        count: catalog.totalFavorites > 0 ? catalog.totalFavorites : null,
        selected: filter.statusFilter == TikTokStatusFilter.favoritesOnly,
        onTap: () => notifier.setStatusFilter(
          filter.statusFilter == TikTokStatusFilter.favoritesOnly
              ? TikTokStatusFilter.all
              : TikTokStatusFilter.favoritesOnly,
        ),
      ),
      OledChip(
        label: l10n.archiveMobileFilterLikes,
        count: catalog.totalLikes > 0 ? catalog.totalLikes : null,
        selected: filter.statusFilter == TikTokStatusFilter.likesOnly,
        onTap: () => notifier.setStatusFilter(
          filter.statusFilter == TikTokStatusFilter.likesOnly
              ? TikTokStatusFilter.all
              : TikTokStatusFilter.likesOnly,
        ),
      ),
      for (final coll in catalog.collections)
        if (coll.videoCount > 0)
          OledChip(
            label: archiveCollectionLabel(context.l10n, coll.name),
            count: coll.videoCount,
            selected: filter.selectedCollection == (coll.id ?? coll.name),
            onTap: () => notifier.selectCollection(
              filter.selectedCollection == (coll.id ?? coll.name)
                  ? null
                  : (coll.id ?? coll.name),
            ),
          ),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => chips[index],
      ),
    );
  }

  Widget _buildSearchField(
    BuildContext context,
    TikTokArchiveState state,
    TikTokArchiveNotifier notifier,
  ) {
    final t = OledTokens.of(context);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide(color: color),
    );

    return TextField(
      controller: _videoSearchController,
      onChanged: notifier.setSearchQuery,
      style: OledText.ui(context, size: 14),
      cursorColor: t.ink,
      decoration: InputDecoration(
        hintText: context.l10n.archiveMobileSearchHint,
        hintStyle: OledText.ui(context, size: 14, color: t.ink3),
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: t.ink2),
        suffixIcon: state.filter.searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: context.l10n.archiveMobileClearSearch,
                icon: Icon(Icons.close_rounded, size: 18, color: t.ink2),
                onPressed: () {
                  _videoSearchController.clear();
                  notifier.setSearchQuery('');
                },
              ),
        isDense: true,
        filled: true,
        fillColor: t.fill,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: border(t.line),
        enabledBorder: border(t.line),
        focusedBorder: border(t.lineStrong),
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context, {
    required TikTokArchiveState state,
    required List<TikTokArchiveItem> videos,
    required TikTokArchiveNotifier notifier,
    required TikTokArchiveCatalog catalog,
    required bool isShowcase,
  }) {
    final t = OledTokens.of(context);
    final hasSelection = state.selectedIds.isNotEmpty;
    final l10n = context.l10n;
    final countLabel = l10n.archiveMobileVideoCount(videos.length);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, notifier),
              for (final card in _buildActivityCards(context, state, notifier))
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: card,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _buildSearchField(context, state, notifier),
              ),
              const SizedBox(height: 12),
              _buildChips(context, state, notifier, catalog),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        countLabel,
                        style: OledText.ui(context, size: 13, color: t.ink2),
                      ),
                    ),
                    if (hasSelection)
                      OledIconButton(
                        icon: Icons.close_rounded,
                        tooltip: l10n.archiveMobileClearSelection,
                        outlined: false,
                        onPressed: notifier.clearSelection,
                      )
                    else
                      OledIconButton(
                        icon: Icons.select_all_rounded,
                        tooltip: l10n.archiveMobileSelectAll,
                        outlined: false,
                        onPressed: videos.isEmpty
                            ? null
                            : () => notifier.selectAll(videos),
                      ),
                    OledIconButton(
                      icon: Icons.tune_rounded,
                      tooltip: l10n.archiveMobileFilters,
                      outlined: false,
                      onPressed: () => _showFilterSheet(context),
                    ),
                    OledIconButton(
                      icon: Icons.folder_open_rounded,
                      tooltip: l10n.archiveMobileManageCollections,
                      outlined: false,
                      onPressed: () =>
                          setState(() => _manageCollections = true),
                    ),
                    if (!isShowcase)
                      OledIconButton(
                        icon: Icons.play_arrow_rounded,
                        tooltip: l10n.archiveMobilePlayFullscreen,
                        outlined: false,
                        onPressed: videos.isEmpty
                            ? null
                            : () => _openFeed(videos),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (videos.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  l10n.archiveMobileNoVideos,
                  style: OledText.ui(context, size: 14, color: t.ink2),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent: 168,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final video = videos[index];
                return _ArchiveTile(
                  item: video,
                  selected: state.selectedIds.contains(video.id),
                  onTap: () => notifier.toggleSelection(video.id),
                  onLongPress: () async {
                    await HapticFeedback.mediumImpact();
                    await notifier.downloadBatch([video], limit: 1);
                    _showNotice(l10n.archiveMobileVideoAdded);
                  },
                );
              }, childCount: videos.length),
            ),
          ),
        SliverToBoxAdapter(child: SizedBox(height: hasSelection ? 96 : 24)),
      ],
    );
  }
}

/// One 9:16-ish tile of the grid.
class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final TikTokArchiveItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static const _demoArt = [
    'sintel.jpg',
    'tears-of-steel.jpg',
    'elephants-dream.jpg',
    'big-buck-bunny.png',
  ];

  /// The demo catalogue uses bundled stills instead of thumbnails.
  String? _demoAsset() {
    if (!item.id.startsWith('demo-')) return null;
    final n = int.tryParse(item.id.substring(5));
    if (n == null) return null;
    return 'assets/showcase/${_demoArt[(n - 1) % _demoArt.length]}';
  }

  String _shortDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = (d.year % 100).toString().padLeft(2, '0');
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final demo = _demoAsset();
    final date = _shortDate(item.date);

    return Semantics(
      button: true,
      selected: selected,
      label: context.l10n.archiveMobileTileLabel(date),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        onLongPress: onLongPress,
        child: LayoutBuilder(
          builder: (context, box) {
            return Stack(
              fit: StackFit.expand,
              children: [
                if (demo != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.line),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11.5),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            demo,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                ColoredBox(color: t.fill),
                          ),
                          Positioned(
                            right: 3,
                            bottom: 3,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: t.bg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                child: Text(
                                  date,
                                  style: OledText.ui(
                                    context,
                                    size: 11,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  OledThumb(
                    width: box.maxWidth,
                    height: box.maxHeight,
                    radius: 12,
                    badge: date,
                  ),
                if (selected)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: t.ink, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                if (selected)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.ink,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: t.onInk,
                      ),
                    ),
                  ),
                if (item.isFavorite || item.isLiked)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.bg.withValues(alpha: 0.7),
                      ),
                      child: Icon(
                        item.isFavorite
                            ? Icons.bookmark_rounded
                            : Icons.favorite_rounded,
                        size: 13,
                        color: t.ink,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Progress bar made of discrete segments, filled left to right.
class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({required this.value});

  /// 0.0 to 1.0
  final double value;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    const segments = 24;
    final clamped = value.clamp(0.0, 1.0);
    final filled = (clamped * segments).floor();
    return Semantics(
      label: context.l10n.archiveMobileProgress,
      value: '${(clamped * 100).round()} %',
      child: SizedBox(
        height: 4,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < segments; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == segments - 1 ? 0 : 2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: i < filled ? t.ink : t.fillStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ink-filled pill floating above the bottom bar while tiles are selected.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.actionLabel,
    required this.onClear,
    required this.onAction,
  });

  final int count;
  final String actionLabel;
  final VoidCallback onClear;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final enabled = onAction != null;
    return Material(
      color: t.ink,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
          child: Row(
            children: [
              Text(
                '$count',
                style: OledText.dot(context, size: 26, color: t.onInk),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.archiveMobileSelectedLabel(count),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OledText.ui(
                    context,
                    size: 14,
                    weight: FontWeight.w700,
                    color: t.onInk,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n.archiveMobileClearSelection,
                onPressed: onClear,
                icon: Icon(Icons.close_rounded, color: t.onInk),
              ),
              const SizedBox(width: 4),
              Material(
                color: t.onInk,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: enabled
                      ? () {
                          HapticFeedback.lightImpact();
                          onAction!();
                        }
                      : null,
                  child: SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Center(
                        child: Text(
                          actionLabel,
                          style: OledText.ui(
                            context,
                            size: 14,
                            weight: FontWeight.w700,
                            color: enabled ? t.ink : t.ink2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
