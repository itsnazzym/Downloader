import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/utils/browser_launch.dart';
import 'package:tapload/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_video_cache_provider.dart';
import 'package:tapload/features/archive/presentation/views/modes/tiktok_feed_view.dart';
import 'package:tapload/l10n/l10n_ext.dart';
import 'package:tapload/showcase/showcase_mode.dart';

import 'studio_states.dart';
import 'studio_widgets.dart';

/// Studio's TikTok archive (mockup Studio-Archives.dc.html): « Archive locale
/// · TikTok », the archive's counts, Synchroniser / Tout télécharger and the
/// Vidéos / Collections / Favoris tabs, then Studio's own views: the filters
/// and the video table, the collection cards and an opened collection. The
/// import hub and the loading screen keep today's view in Studio's
/// components.
class StudioArchive extends ConsumerWidget {
  const StudioArchive({super.key, required this.current});

  final Widget current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (loading, hub, hasCatalog, mode, favorites, opened) = ref.watch(
      tikTokArchiveProvider.select(
        (s) => (
          s.isLoading,
          s.viewMode == TikTokViewMode.hub,
          s.hasCatalog,
          s.viewMode,
          s.filter.statusFilter == TikTokStatusFilter.favoritesOnly,
          s.filter.selectedCollection,
        ),
      ),
    );
    if (loading || hub || !hasCatalog) return StudioThemed(child: current);
    final collections = mode == TikTokViewMode.collections;
    return StudioThemed(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth < 640 ? 16.0 : 40.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(side, 30, side, 14),
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: _Header(
                      mode: mode,
                      favorites: favorites,
                      grid: collections && opened == null,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: !collections
                    ? _VideosPane(side: side)
                    : opened == null
                    ? _CollectionsGrid(side: side)
                    : _CollectionDetail(side: side, collectionKey: opened),
              ),
            ],
          );
        },
      ),
    );
  }
}

final _selectingProvider = StateProvider.autoDispose<bool>((ref) => false);
final _selectedProvider = StateProvider.autoDispose<Set<String>>(
  (ref) => const {},
);
final _postersProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Folders the archive builds itself: views, not collections, so they can't
/// be emptied, purged or deleted.
bool _isVirtual(String name) =>
    name == 'Favoris non classés' || name == 'Vidéos Likées';

void _notice(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// A Studio confirmation: the question, « Annuler » and the action, red
/// when it destroys something.
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required Widget body,
  required String action,
  bool danger = true,
}) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: body,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        StudioButton(
          label: l10n.cancel,
          kind: StudioButtonKind.light,
          height: 32,
          onTap: () => Navigator.of(ctx).pop(false),
        ),
        StudioButton(
          label: action,
          kind: danger ? StudioButtonKind.danger : StudioButtonKind.ink,
          height: 32,
          onTap: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return ok == true;
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.mode,
    required this.favorites,
    required this.grid,
  });

  final TikTokViewMode mode;
  final bool favorites;

  /// The collection cards are showing: offer the purge selection.
  final bool grid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final catalog = ref.watch(tikTokArchiveProvider.select((s) => s.catalog!));
    final batch = ref.watch(
      tikTokArchiveProvider.select((s) => s.isBatchDownloading),
    );
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final selecting = ref.watch(_selectingProvider);
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final pending = [
      for (final v in catalog.videos)
        if (!v.isDownloaded) v,
    ];

    Future<void> downloadAll() async {
      if (await _confirm(
        context,
        title: l10n.studioDownloadAll,
        body: Text(l10n.studioDownloadAllConfirm(pending.length)),
        action: l10n.confirm,
        danger: false,
      )) {
        await notifier.downloadBatch(pending, limit: pending.length);
      }
    }

    void listMode(TikTokStatusFilter filter) {
      notifier.setStatusFilter(filter);
      notifier.setViewMode(TikTokViewMode.list);
    }

    InlineSpan stat(int n, String unit) => TextSpan(
      children: [
        TextSpan(
          text: number.format(n),
          style: studioMono(c, color: c.textPrimary),
        ),
        TextSpan(text: ' $unit'),
      ],
    );

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudioCap(l10n.studioArchiveCap),
        const SizedBox(height: 6),
        Text(l10n.studioArchiveTitle, style: studioTitle(c)),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: studioText(c, color: c.textSecondary),
            children: [
              stat(catalog.videos.length, l10n.studioVideosUnit),
              const TextSpan(text: '    '),
              stat(catalog.collections.length, l10n.studioCollectionsUnit),
              const TextSpan(text: '    '),
              stat(catalog.totalFavorites, l10n.studioFavoritesUnit),
            ],
          ),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Import and sync live in the archive hub.
        StudioButton(
          label: l10n.studioSync,
          icon: Icons.sync_rounded,
          kind: StudioButtonKind.light,
          onTap: () => notifier.setViewMode(TikTokViewMode.hub),
        ),
        const SizedBox(width: 16),
        batch
            ? StudioButton(
                label: l10n.archiveMobileStopBatch,
                kind: StudioButtonKind.light,
                onTap: notifier.stopBatch,
              )
            : StudioButton(
                label: l10n.studioDownloadAll,
                onTap: pending.isEmpty ? null : downloadAll,
              ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          runSpacing: 16,
          spacing: 16,
          children: [title, actions],
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: StudioTabs(
                tabs: [
                  StudioTab(
                    label: l10n.studioVideos,
                    count: number.format(catalog.videos.length),
                    selected: mode == TikTokViewMode.list && !favorites,
                    onTap: () => listMode(TikTokStatusFilter.all),
                  ),
                  StudioTab(
                    label: l10n.studioCollections,
                    count: number.format(catalog.collections.length),
                    selected: mode == TikTokViewMode.collections,
                    onTap: () =>
                        notifier.setViewMode(TikTokViewMode.collections),
                  ),
                  StudioTab(
                    label: l10n.archiveMobileFilterFavorites,
                    count: number.format(catalog.totalFavorites),
                    selected: mode == TikTokViewMode.list && favorites,
                    onTap: () => listMode(TikTokStatusFilter.favoritesOnly),
                  ),
                ],
              ),
            ),
            if (grid) ...[
              const SizedBox(width: 12),
              Tooltip(
                message: l10n.archivePurgeSelectTooltip,
                child: StudioButton(
                  label: selecting ? l10n.studioDone : l10n.archivePurgeSelect,
                  kind: StudioButtonKind.light,
                  on: selecting,
                  height: 32,
                  onTap: () {
                    ref.read(_selectedProvider.notifier).state = const {};
                    ref.read(_selectingProvider.notifier).state = !selecting;
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Videos and favourites ──────────────────────────────────────────────────

/// The filters on the paper beside the video table (in a dialog when the
/// window is narrow), the search, the selection and the batch above it.
class _VideosPane extends ConsumerWidget {
  const _VideosPane({required this.side});

  final double side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final videos = ref.watch(filteredTikTokVideosProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 760;
        final list = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ListToolbar(
              videos: videos,
              onFilters: !narrow
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        child: SizedBox(
                          width: 300,
                          height: 520,
                          child: const StudioThemed(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                              child: _FilterPane(),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: videos.isEmpty
                  ? Align(
                      alignment: Alignment.topCenter,
                      child: StudioSituation(
                        title: l10n.archiveMobileNoVideos,
                        body: '',
                        actions: [
                          StudioButton(
                            label: l10n.archiveMobileReset,
                            icon: Icons.filter_alt_off_outlined,
                            kind: StudioButtonKind.light,
                            onTap: notifier.resetFilters,
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: _VideoTable(videos: videos),
                    ),
            ),
          ],
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(side, 4, side, 0),
          child: narrow
              ? list
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(width: 220, child: _FilterPane()),
                    const SizedBox(width: 28),
                    Expanded(child: list),
                  ],
                ),
        );
      },
    );
  }
}

/// Type, year and collection filters as Studio lists: the chosen line in
/// ink with a dot, the others grey; « Réinitialiser » clears them all.
class _FilterPane extends ConsumerStatefulWidget {
  const _FilterPane();

  @override
  ConsumerState<_FilterPane> createState() => _FilterPaneState();
}

class _FilterPaneState extends ConsumerState<_FilterPane> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final catalog = ref.watch(tikTokArchiveProvider.select((s) => s.catalog));
    final filter = ref.watch(tikTokArchiveProvider.select((s) => s.filter));
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    if (catalog == null) return const SizedBox.shrink();
    final years = catalog.yearCounts.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final collections = [
      for (final coll in catalog.collections)
        if (coll.name.toLowerCase().contains(_search.toLowerCase())) coll,
    ];
    final number = NumberFormat.decimalPattern(l10n.localeName);
    return Material(
      type: MaterialType.transparency,
      child: ListView(
        padding: const EdgeInsets.only(top: 6, bottom: 30),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.archiveMobileFilters,
                  style: studioTitle(c, 17),
                ),
              ),
              _TextLink(
                label: l10n.archiveMobileReset,
                onTap: () {
                  notifier.selectYear(null);
                  notifier.selectCollection(null);
                  notifier.setStatusFilter(TikTokStatusFilter.all);
                  notifier.clearSelection();
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          StudioCap(l10n.archiveMobileType),
          const SizedBox(height: 6),
          for (final (value, label) in [
            (TikTokStatusFilter.all, l10n.archiveMobileFilterAll),
            (
              TikTokStatusFilter.favoritesOnly,
              l10n.archiveMobileFilterFavorites,
            ),
            (TikTokStatusFilter.likesOnly, l10n.archiveMobileFilterLikes),
          ])
            _FilterLine(
              label: label,
              on: filter.statusFilter == value,
              onTap: () => notifier.setStatusFilter(value),
            ),
          const SizedBox(height: 18),
          StudioCap(l10n.archiveMobileYear),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(
                label: l10n.archiveMobileAllYears,
                on: filter.selectedYear == null,
                onTap: () => notifier.selectYear(null),
              ),
              for (final year in years)
                _Chip(
                  label: '$year',
                  count: number.format(catalog.yearCounts[year]),
                  on: filter.selectedYear == year,
                  onTap: () => notifier.selectYear(
                    filter.selectedYear == year ? null : year,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: StudioCap(
                  '${l10n.studioCollections} · ${catalog.collections.length}',
                ),
              ),
              if (filter.selectedCollection != null)
                _TextLink(
                  label: l10n.archiveMobileReset,
                  onTap: () => notifier.selectCollection(null),
                ),
            ],
          ),
          const SizedBox(height: 8),
          StudioSearchBox(
            hint: l10n.archiveCollSearch,
            clearTooltip: l10n.archiveMobileClearSearch,
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 6),
          for (final coll in collections)
            _FilterLine(
              label: coll.name,
              count: number.format(coll.videoCount),
              on: filter.selectedCollection == coll.name,
              onTap: () => notifier.selectCollection(
                filter.selectedCollection == coll.name ? null : coll.name,
              ),
            ),
        ],
      ),
    );
  }
}

/// A filter choice: a 5px ink dot and ink text when chosen, an optional mono
/// count at the end, the row tinted on hover.
class _FilterLine extends StatefulWidget {
  const _FilterLine({
    required this.label,
    required this.on,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;
  final String? count;

  @override
  State<_FilterLine> createState() => _FilterLineState();
}

class _FilterLineState extends State<_FilterLine> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      selected: widget.on,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hover = v),
        borderRadius: BorderRadius.circular(6),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: studioMotion(context, 140),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: widget.on
                ? c.surface
                : (_hover ? c.surface.withValues(alpha: 0.6) : null),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.on ? c.border : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: studioMotion(context, 140),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: widget.on ? c.textPrimary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: studioText(
                    c,
                    color: widget.on || _hover
                        ? c.textPrimary
                        : c.textSecondary,
                  ).copyWith(fontWeight: widget.on ? FontWeight.w500 : null),
                ),
              ),
              if (widget.count != null)
                Text(
                  widget.count!,
                  style: studioMono(c, size: 11, color: c.textDisabled),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.chip`: a ringed 8px pill, ink when on.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.on,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;
  final String? count;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      selected: on,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: c.textPrimary.withValues(alpha: 0.05),
        child: AnimatedContainer(
          duration: studioMotion(context, 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: on ? c.primary : c.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? c.primary : c.border),
          ),
          child: Text.rich(
            TextSpan(
              text: label,
              children: [
                if (count != null)
                  TextSpan(
                    text: '  $count',
                    style: studioMono(
                      c,
                      size: 11,
                      color: on ? c.background : c.textDisabled,
                    ),
                  ),
              ],
            ),
            style: studioText(
              c,
              size: 12,
              color: on ? c.background : c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// An underlined text action.
class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = c.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          label,
          style: studioText(c, size: 12, color: color).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: color,
          ),
        ),
      ),
    );
  }
}

/// Search, the count, the selection (select all / clear / download it) and
/// the batch's progress line.
class _ListToolbar extends ConsumerWidget {
  const _ListToolbar({required this.videos, required this.onFilters});

  final List<TikTokArchiveItem> videos;
  final VoidCallback? onFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final (selected, batch, done, total, skipped, query) = ref.watch(
      tikTokArchiveProvider.select(
        (s) => (
          s.selectedIds.length,
          s.isBatchDownloading,
          s.batchCompletedCount,
          s.batchTotalCount,
          s.batchSkippedCount,
          s.filter.searchQuery,
        ),
      ),
    );
    final skippedLabel = skipped > 0
        ? ' · ${l10n.archiveMobileSkippedVideos(skipped)}'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onFilters != null) ...[
                  StudioIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: l10n.archiveMobileFilters,
                    onTap: onFilters,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: SizedBox(
                    width: 300,
                    child: StudioSearchBox(
                      hint: l10n.archiveMobileSearchHint,
                      clearTooltip: l10n.archiveMobileClearSearch,
                      initial: query,
                      onChanged: notifier.setSearchQuery,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  l10n.archiveMobileVideoCount(videos.length),
                  style: studioMono(c, size: 12),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected == 0)
                  StudioButton(
                    label: l10n.archiveMobileSelectAll,
                    icon: Icons.select_all_rounded,
                    kind: StudioButtonKind.light,
                    height: 32,
                    onTap: videos.isEmpty
                        ? null
                        : () => notifier.selectAll(videos),
                  )
                else ...[
                  Text(
                    l10n.archivePurgeSelectedCount(selected),
                    style: studioMono(c, size: 12, color: c.textPrimary),
                  ),
                  const SizedBox(width: 6),
                  _TextLink(
                    label: l10n.archiveMobileClearSelection,
                    onTap: notifier.clearSelection,
                  ),
                  const SizedBox(width: 10),
                  StudioButton(
                    label: batch
                        ? l10n.studioArchiveBatchRunning(done, total) +
                              skippedLabel
                        : l10n.downloadSelected(selected),
                    icon: Icons.download_rounded,
                    height: 32,
                    onTap: batch
                        ? null
                        : () async {
                            await notifier.downloadSelected();
                            if (context.mounted) {
                              _notice(context, l10n.archiveMobileBatchStarted);
                            }
                          },
                  ),
                ],
              ],
            ),
          ],
        ),
        if (batch) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: StudioLine(value: total > 0 ? done / total : 0)),
              const SizedBox(width: 12),
              Text(
                '$done / $total$skippedLabel',
                style: studioMono(c, size: 12),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The videos as one white table: a checkbox, the still or a play glyph, the
/// date as title with its favourite / like / collection marks, the id in
/// mono; copy, open and download appear on hover.
class _VideoTable extends ConsumerWidget {
  const _VideoTable({required this.videos});

  final List<TikTokArchiveItem> videos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final selected = ref.watch(
      tikTokArchiveProvider.select((s) => s.selectedIds),
    );
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    Future<void> download(TikTokArchiveItem video) async {
      if (ref.read(showcaseModeProvider)) {
        _notice(context, l10n.studioArchiveDemo);
        return;
      }
      _notice(context, l10n.archiveMobileVideoAdded);
      await notifier.downloadBatch([video], limit: 1);
    }

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: (41 + videos.length * 57.0).clamp(0, constraints.maxHeight),
          clipBehavior: Clip.antiAlias,
          decoration: studioPanelDecoration(c),
          child: Column(
            children: [
              Container(
                height: 41,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  children: [
                    const SizedBox(width: 16 + 14 + 40 + 14),
                    Expanded(child: StudioCap(l10n.title)),
                    if (constraints.maxWidth >= 640)
                      SizedBox(width: 190, child: StudioCap(l10n.inspectorId)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: videos.length,
                  itemExtent: 57,
                  itemBuilder: (context, i) {
                    final video = videos[i];
                    return _VideoRow(
                      key: ValueKey(video.id),
                      item: video,
                      showId: constraints.maxWidth >= 640,
                      selected: selected.contains(video.id),
                      onToggle: () => notifier.toggleSelection(video.id),
                      onDownload: () => download(video),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoRow extends StatefulWidget {
  const _VideoRow({
    super.key,
    required this.item,
    required this.showId,
    required this.selected,
    required this.onToggle,
    required this.onDownload,
  });

  final TikTokArchiveItem item;
  final bool showId;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onDownload;

  @override
  State<_VideoRow> createState() => _VideoRowState();
}

class _VideoRowState extends State<_VideoRow> {
  bool _hover = false;

  static const _demoFilms = [
    'Sintel',
    'Tears of Steel',
    'Elephants Dream',
    'Big Buck Bunny',
  ];
  static const _demoArt = [
    'sintel.jpg',
    'tears-of-steel.jpg',
    'elephants-dream.jpg',
    'big-buck-bunny.png',
  ];

  String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final item = widget.item;
    // The showcase uses bundled, licensed stills, never a request to a
    // user's archive source.
    final demo = item.id.startsWith('demo-')
        ? int.tryParse(item.id.substring(5))
        : null;
    final demoIndex = demo == null ? null : (demo - 1) % 4;
    final title = demoIndex == null
        ? l10n.archiveVideoTitle(_date(item.date))
        : '${_demoFilms[demoIndex]} · ${(demo! - 1) ~/ 4 + 1}';
    final marks = [
      if (item.isFavorite) l10n.studioArchiveFavorite,
      if (item.isLiked) l10n.studioArchiveLike,
    ];
    final glyph = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.borderSubtle),
      ),
      child: Icon(Icons.play_arrow_rounded, size: 18, color: c.textSecondary),
    );
    return Material(
      color: widget.selected
          ? Color.lerp(c.surface, c.surfaceHighlight, 0.6)
          : (_hover ? studioHover(c) : c.surface),
      child: InkWell(
        onTap: widget.onToggle,
        onHover: (v) => setState(() => _hover = v),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.borderSubtle)),
          ),
          child: Row(
            children: [
              Semantics(
                checked: widget.selected,
                child: StudioCheckbox(value: widget.selected),
              ),
              const SizedBox(width: 14),
              if (demoIndex != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/showcase/${_demoArt[demoIndex]}',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    semanticLabel: _demoFilms[demoIndex],
                    errorBuilder: (_, _, _) => glyph,
                  ),
                )
              else
                glyph,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StudioUnderline(
                      text: title,
                      hover: _hover,
                      style: studioText(
                        c,
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (item.isFavorite)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: 6,
                                ),
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: c.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          TextSpan(
                            text: [
                              ...marks,
                              ?item.collectionName,
                            ].join('  ·  '),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: studioText(c, size: 12, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              if (widget.showId) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 190,
                  child: SelectableText(
                    item.id,
                    maxLines: 1,
                    style: studioMono(c, size: 11, color: c.textDisabled),
                  ),
                ),
              ],
              // Kept mounted when hidden, for the keyboard and touch.
              AnimatedOpacity(
                duration: studioMotion(context, 140),
                opacity: _hover ? 1 : 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StudioIconButton(
                      icon: Icons.copy_rounded,
                      tooltip: l10n.studioArchiveCopyLink,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: item.url));
                        _notice(context, l10n.studioArchiveLinkCopied);
                      },
                    ),
                    const SizedBox(width: 6),
                    StudioIconButton(
                      icon: Icons.open_in_new_rounded,
                      tooltip: l10n.studioArchiveOpenBrowser,
                      onTap: () {
                        if (Uri.tryParse(item.url)?.host.endsWith('.invalid') ==
                            true) {
                          return;
                        }
                        openInBrowser(item.url);
                      },
                    ),
                    const SizedBox(width: 6),
                    StudioButton(
                      label: l10n.archiveMobileDownload,
                      icon: Icons.download_rounded,
                      height: 32,
                      onTap: widget.onDownload,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Collections ────────────────────────────────────────────────────────────

/// How many videos of [collection] are still on TikTok, as today's view
/// counts them (the two virtual folders by flag).
int _visibleCount(
  TikTokArchiveCatalog catalog,
  TikTokCollectionItem collection,
  Set<String> unavailable,
) {
  return catalog.videos.where((video) {
    if (unavailable.contains(video.id)) return false;
    if (collection.name == 'Vidéos Likées') return video.isLiked;
    if (collection.name == 'Favoris non classés') {
      return video.isFavorite &&
          video.collectionIds.isEmpty &&
          (video.collectionName == null ||
              video.collectionName == 'Favoris non classés' ||
              video.collectionName == 'Vidéos Likées');
    }
    return (collection.id != null &&
            video.collectionIds.contains(collection.id)) ||
        (video.collectionName?.split(' · ').contains(collection.name) ?? false);
  }).length;
}

Set<String> _unavailable(WidgetRef ref) => ref.watch(showcaseModeProvider)
    ? <String>{}
    : ref.watch(tiktokUnavailableIdsProvider).valueOrNull ??
          ref.read(tiktokVideoCacheServiceProvider).unavailableIds;

/// The collections as cards (mockup): name, video count, how much is on this
/// PC; a search, folders or covers, the suggestions to review and the reset
/// of the whole archive above; in selection mode, checkboxes and the
/// « Supprimer leurs vidéos » bar.
class _CollectionsGrid extends ConsumerStatefulWidget {
  const _CollectionsGrid({required this.side});

  final double side;

  @override
  ConsumerState<_CollectionsGrid> createState() => _CollectionsGridState();
}

class _CollectionsGridState extends ConsumerState<_CollectionsGrid> {
  bool _purging = false;
  bool _applying = false;
  String _search = '';

  /// Same confirmation and purge as today's collections view.
  Future<void> _confirmPurge(Set<String> keys) async {
    if (keys.isEmpty || _purging) return;
    final l10n = context.l10n;
    final c = AppColors.of(context);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final preview = notifier.purgePreview(keys);
    final confirmed = await _confirm(
      context,
      title: l10n.archivePurgeTitle(keys.length),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.archivePurgeBody(preview.videos, preview.files)),
          if (preview.keptShared > 0) ...[
            const SizedBox(height: 12),
            Text(
              l10n.archivePurgeKept(preview.keptShared),
              style: studioText(c, color: c.textSecondary),
            ),
          ],
        ],
      ),
      action: l10n.delete,
    );
    if (!confirmed || !mounted) return;
    setState(() => _purging = true);
    try {
      final result = await notifier.purgeCollections(keys);
      if (!mounted) return;
      ref.read(_selectedProvider.notifier).state = const {};
      ref.read(_selectingProvider.notifier).state = false;
      _notice(
        context,
        l10n.archivePurgeDone(result.filesDeleted, result.videosRemoved),
      );
    } finally {
      if (mounted) setState(() => _purging = false);
    }
  }

  Future<void> _confirmDelete(String key, String name, int count) async {
    final l10n = context.l10n;
    if (!await _confirm(
      context,
      title: l10n.archiveCollDelete,
      body: Text(l10n.archiveCollDeleteBody(count, name)),
      action: l10n.archiveCollDeleteConfirm,
    )) {
      return;
    }
    await ref.read(tikTokArchiveProvider.notifier).deleteCollection(key);
    if (mounted) _notice(context, l10n.archiveCollDeleteDone(name));
  }

  Future<void> _confirmClear() async {
    final l10n = context.l10n;
    if (!await _confirm(
      context,
      title: l10n.archiveCollClear,
      body: Text(l10n.archiveCollClearBody),
      action: l10n.archiveCollClearConfirm,
    )) {
      return;
    }
    await ref.read(tikTokArchiveProvider.notifier).clearCatalog();
    if (mounted) _notice(context, l10n.archiveCollClearDone);
  }

  Future<void> _review(List<TikTokCollectionSuggestion> suggestions) async {
    final l10n = context.l10n;
    final picked = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _SuggestionsDialog(suggestions: suggestions),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() => _applying = true);
    try {
      await ref
          .read(tikTokArchiveProvider.notifier)
          .applyCollectionSuggestions(picked);
      if (mounted) _notice(context, l10n.studioArchiveApplied(picked.length));
    } catch (error) {
      if (mounted) _notice(context, l10n.studioArchiveApplyFailed('$error'));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final catalog = ref.watch(tikTokArchiveProvider.select((s) => s.catalog!));
    final selecting = ref.watch(_selectingProvider);
    final selected = ref.watch(_selectedProvider);
    final posters = ref.watch(_postersProvider);
    final unavailable = _unavailable(ref);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    // Downloaded / total per collection key, in one pass over the videos.
    final done = <String, int>{};
    final total = <String, int>{};
    for (final v in catalog.videos) {
      final keys = {...v.collectionIds, ?v.collectionName};
      for (final k in keys) {
        total[k] = (total[k] ?? 0) + 1;
        if (v.isDownloaded) done[k] = (done[k] ?? 0) + 1;
      }
    }
    final query = _search.toLowerCase();
    final cards = [
      for (final coll in catalog.collections)
        if (coll.name.toLowerCase().contains(query))
          (
            key: coll.id ?? coll.name,
            coll: coll,
            count: _visibleCount(catalog, coll, unavailable),
            done: done[coll.id ?? coll.name] ?? 0,
            total: total[coll.id ?? coll.name] ?? 0,
          ),
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(widget.side, 4, widget.side, 40),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(
                    child: SizedBox(
                      width: 280,
                      child: StudioSearchBox(
                        hint: l10n.archiveCollSearch,
                        clearTooltip: l10n.archiveMobileClearSearch,
                        onChanged: (v) => setState(() => _search = v.trim()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '${cards.length} ${l10n.studioCollectionsUnit}',
                    style: studioMono(c, size: 12),
                  ),
                  const Spacer(),
                  StudioIconButton(
                    icon: posters
                        ? Icons.view_agenda_outlined
                        : Icons.grid_view_rounded,
                    tooltip: posters
                        ? l10n.studioArchiveShowFolders
                        : l10n.studioArchiveShowPosters,
                    onTap: () =>
                        ref.read(_postersProvider.notifier).state = !posters,
                  ),
                  const SizedBox(width: 8),
                  StudioIconButton(
                    icon: Icons.delete_sweep_outlined,
                    tooltip: l10n.archiveCollClear,
                    onTap: _confirmClear,
                  ),
                ],
              ),
              if (catalog.suggestions.isNotEmpty) ...[
                const SizedBox(height: 14),
                StudioPanel(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 10, 10),
                  child: Row(
                    children: [
                      const StudioRecDot(live: false),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.studioArchiveSuggestions(
                            catalog.suggestions.length,
                          ),
                          style: studioText(
                            c,
                          ).copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      StudioButton(
                        label: _applying
                            ? l10n.studioArchiveApplying
                            : l10n.studioArchiveReview(
                                catalog.suggestions.length,
                              ),
                        icon: Icons.fact_check_outlined,
                        kind: StudioButtonKind.light,
                        height: 32,
                        onTap: _applying
                            ? null
                            : () => _review(catalog.suggestions),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (cards.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    l10n.archiveCollEmpty,
                    style: studioText(c, color: c.textSecondary),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final perRow = ((constraints.maxWidth + 14) / (200 + 14))
                        .floor()
                        .clamp(1, 8);
                    final width =
                        (constraints.maxWidth - 14 * (perRow - 1)) / perRow;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (final card in cards)
                          SizedBox(
                            width: width,
                            child: _CollectionCard(
                              collection: card.coll,
                              count: card.count,
                              poster: posters,
                              fraction: card.total == 0
                                  ? 0
                                  : card.done / card.total,
                              virtual: _isVirtual(card.coll.name),
                              selecting: selecting,
                              selected: selected.contains(card.key),
                              onTap: () {
                                if (!selecting) {
                                  notifier.selectCollection(card.key);
                                  return;
                                }
                                if (_isVirtual(card.coll.name)) return;
                                final next = {...selected};
                                if (!next.remove(card.key)) next.add(card.key);
                                ref.read(_selectedProvider.notifier).state =
                                    next;
                              },
                              onDelete: selecting || _isVirtual(card.coll.name)
                                  ? null
                                  : () => _confirmDelete(
                                      card.key,
                                      card.coll.name,
                                      card.count,
                                    ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              if (selecting) ...[
                const SizedBox(height: 14),
                if (selected.isNotEmpty)
                  StudioPanel(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      10,
                      10,
                      10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.archivePurgeSelectedCount(selected.length),
                            style: studioMono(
                              c,
                              color: c.textPrimary,
                            ).copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        StudioButton(
                          label: l10n.cancel,
                          kind: StudioButtonKind.light,
                          height: 32,
                          onTap: () =>
                              ref.read(_selectedProvider.notifier).state =
                                  const {},
                        ),
                        const SizedBox(width: 12),
                        StudioButton(
                          label: l10n.archivePurgeAction,
                          kind: StudioButtonKind.danger,
                          height: 32,
                          onTap: _purging
                              ? null
                              : () => _confirmPurge(selected),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                StudioNote(l10n.studioPurgeNote),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionCard extends StatefulWidget {
  const _CollectionCard({
    required this.collection,
    required this.count,
    required this.poster,
    required this.fraction,
    required this.virtual,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  final TikTokCollectionItem collection;
  final int count;
  final bool poster;
  final double fraction;
  final bool virtual;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  bool _hover = false;

  /// Only covers from TikTok's own image hosts are loaded.
  static bool _trusted(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https') return false;
    const domains = [
      'tiktokcdn.com',
      'tiktokv.com',
      'byteoversea.com',
      'ibytedtos.com',
      'byteimg.com',
    ];
    final host = uri.host.toLowerCase();
    return domains.any((d) => host == d || host.endsWith('.$d'));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final coll = widget.collection;
    final on = widget.selecting && widget.selected;
    final pct = (widget.fraction * 100).round();
    final incomplete =
        coll.syncComplete == false && coll.syncError != 'count_mismatch';
    final declared = coll.declaredTotal;
    final Widget state;
    if (widget.fraction >= 1) {
      state = Row(
        children: [
          Icon(Icons.check_rounded, size: 13, color: c.textPrimary),
          const SizedBox(width: 6),
          Text(l10n.studioAllDownloaded, style: studioText(c, size: 12)),
        ],
      );
    } else if (widget.fraction > 0) {
      state = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$pct %', style: studioMono(c, size: 12)),
                TextSpan(text: '  ${l10n.studioPartDownloaded}'),
              ],
            ),
            style: studioText(c, size: 12, color: c.textSecondary),
          ),
          const SizedBox(height: 8),
          StudioLine(value: widget.fraction),
        ],
      );
    } else {
      state = Text(
        l10n.studioToDownload,
        style: studioText(c, size: 12, color: c.textDisabled),
      );
    }
    final cover = _trusted(coll.coverUrl) ? coll.coverUrl : null;
    final fallback = ColoredBox(
      color: Color.lerp(c.background, c.border, 0.5)!,
      child: Center(
        child: Icon(Icons.folder_open_rounded, size: 28, color: c.textDisabled),
      ),
    );
    return Opacity(
      opacity: widget.selecting && widget.virtual ? 0.4 : 1,
      child: Semantics(
        button: true,
        selected: on,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (v) => setState(() => _hover = v),
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: studioMotion(context, 180),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: on
                    ? c.textPrimary
                    : (_hover ? const Color(0xFFD6D3CD) : c.border),
                width: on ? 1.5 : 1,
              ),
              boxShadow: on || _hover
                  ? [
                      BoxShadow(
                        color: c.primary.withValues(alpha: 0.07),
                        blurRadius: 22,
                        spreadRadius: -8,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.poster)
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: cover == null
                        ? fallback
                        : Image.network(
                            cover,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            filterQuality: FilterQuality.low,
                            errorBuilder: (_, _, _) => fallback,
                          ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: StudioUnderline(
                                text: coll.name,
                                hover: _hover,
                                style: studioTitle(
                                  c,
                                  17,
                                ).copyWith(letterSpacing: -0.34, height: 1.25),
                              ),
                            ),
                          ),
                          if (incomplete) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message: coll.syncError == null
                                  ? l10n.studioArchiveSyncIncomplete
                                  : l10n.studioArchiveSyncIncompleteWhy(
                                      coll.syncError!,
                                    ),
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Icon(
                                  Icons.error_outline_rounded,
                                  size: 15,
                                  color: c.error,
                                ),
                              ),
                            ),
                          ],
                          if (widget.selecting && !widget.virtual) ...[
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.all(3),
                              child: StudioCheckbox(value: widget.selected),
                            ),
                          ],
                          if (widget.onDelete != null)
                            AnimatedOpacity(
                              duration: studioMotion(context, 140),
                              opacity: _hover ? 1 : 0,
                              child: Tooltip(
                                message: l10n.archiveCollDelete,
                                child: InkWell(
                                  onTap: _hover ? widget.onDelete : null,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 16,
                                      color: c.error,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Tooltip(
                        message: declared != null && declared > widget.count
                            ? l10n.studioArchiveDeclared(widget.count, declared)
                            : '',
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text:
                                    incomplete &&
                                        declared != null &&
                                        declared > widget.count
                                    ? '${widget.count}/$declared'
                                    : '${widget.count}',
                                style: studioMono(
                                  c,
                                  size: 20,
                                  color: c.textPrimary,
                                ),
                              ),
                              TextSpan(text: '  ${l10n.studioVideosUnit}'),
                              if (coll.date != null)
                                TextSpan(
                                  text:
                                      '   ${coll.date!.year}-'
                                      '${coll.date!.month.toString().padLeft(2, '0')}',
                                  style: studioMono(
                                    c,
                                    size: 11,
                                    color: c.textDisabled,
                                  ),
                                ),
                            ],
                          ),
                          style: studioText(c, color: c.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        constraints: const BoxConstraints(minHeight: 34),
                        padding: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: c.borderSubtle),
                          ),
                        ),
                        child: state,
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

/// « Vérifier les propositions »: the suggestions grouped by collection,
/// each with its reason and a checkbox; nothing changes before « Appliquer ».
class _SuggestionsDialog extends StatefulWidget {
  const _SuggestionsDialog({required this.suggestions});

  final List<TikTokCollectionSuggestion> suggestions;

  @override
  State<_SuggestionsDialog> createState() => _SuggestionsDialogState();
}

class _SuggestionsDialogState extends State<_SuggestionsDialog> {
  late final List<Object> _rows; // a group's (name, count) or a suggestion
  late final Set<String> _picked;

  @override
  void initState() {
    super.initState();
    final grouped = <String, List<TikTokCollectionSuggestion>>{};
    for (final s in widget.suggestions) {
      grouped.putIfAbsent(s.collectionName, () => []).add(s);
    }
    final names = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _rows = [
      for (final name in names) ...[
        (name, grouped[name]!.length),
        ...(grouped[name]!..sort((a, b) => a.videoId.compareTo(b.videoId))),
      ],
    ];
    _picked = {for (final s in widget.suggestions) s.key};
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    String reason(String r) => switch (r) {
      'partial_snapshot' => l10n.studioArchiveReasonPartial,
      'date_proximity' => l10n.studioArchiveReasonDate,
      'imported_mapping' => l10n.studioArchiveReasonMapping,
      _ => l10n.studioArchiveReasonOther,
    };
    final height = (MediaQuery.sizeOf(context).height * 0.65).clamp(
      280.0,
      620.0,
    );
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l10n.studioArchiveReviewTitle)),
          StudioIconButton(
            icon: Icons.close_rounded,
            tooltip: l10n.close,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.studioArchiveReviewHint,
              style: studioText(c, color: c.textSecondary),
            ),
            const SizedBox(height: 10),
            const StudioRule(),
            Expanded(
              child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (context, i) {
                  final row = _rows[i];
                  if (row is (String, int)) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                      child: StudioCap('${row.$1} · ${row.$2}'),
                    );
                  }
                  final s = row as TikTokCollectionSuggestion;
                  final on = _picked.contains(s.key);
                  return InkWell(
                    onTap: () => setState(
                      () => on ? _picked.remove(s.key) : _picked.add(s.key),
                    ),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Semantics(
                            checked: on,
                            child: StudioCheckbox(value: on),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.studioArchiveSuggestionVideo(s.videoId),
                                  style: studioMono(
                                    c,
                                    size: 12,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  reason(s.reason),
                                  style: studioText(
                                    c,
                                    size: 12,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        Text(
          l10n.archivePurgeSelectedCount(_picked.length),
          style: studioMono(c, size: 12),
        ),
        const SizedBox(width: 8),
        StudioButton(
          label: l10n.studioArchiveApply,
          icon: Icons.check_rounded,
          height: 32,
          onTap: _picked.isEmpty
              ? null
              : () => Navigator.of(context).pop(Set<String>.of(_picked)),
        ),
      ],
    );
  }
}

/// An opened collection: back, its name as a headline and its count, the
/// remove / purge / delete menu, the vertical player and « Tout
/// télécharger », then its videos in the table.
class _CollectionDetail extends ConsumerWidget {
  const _CollectionDetail({required this.side, required this.collectionKey});

  final double side;
  final String collectionKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final catalog = ref.watch(tikTokArchiveProvider.select((s) => s.catalog!));
    final batch = ref.watch(
      tikTokArchiveProvider.select((s) => s.isBatchDownloading),
    );
    final videos = ref.watch(filteredTikTokVideosProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final name =
        catalog.collections
            .where(
              (coll) =>
                  coll.id == collectionKey ||
                  (coll.id == null && coll.name == collectionKey),
            )
            .firstOrNull
            ?.name ??
        collectionKey;
    final canReset = videos.isNotEmpty && !_isVirtual(name);

    Future<void> onMenu(String value) async {
      switch (value) {
        case 'reset':
          if (await _confirm(
            context,
            title: l10n.archiveCollResetTitle,
            body: Text(l10n.archiveCollResetBody(videos.length, name)),
            action: l10n.archiveCollResetConfirm,
          )) {
            await notifier.resetCollectionToUnclassified(collectionKey);
            if (context.mounted) {
              _notice(context, l10n.archiveCollResetDone(name));
            }
          }
        case 'delete':
          if (await _confirm(
            context,
            title: l10n.archiveCollDelete,
            body: Text(l10n.archiveCollDeleteBody(videos.length, name)),
            action: l10n.archiveCollDeleteConfirm,
          )) {
            await notifier.deleteCollection(collectionKey);
            if (context.mounted) {
              _notice(context, l10n.archiveCollDeleteDone(name));
            }
          }
        case 'purge':
          final preview = notifier.purgePreview({collectionKey});
          if (await _confirm(
            context,
            title: l10n.archivePurgeTitle(1),
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.archivePurgeBody(preview.videos, preview.files)),
                if (preview.keptShared > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.archivePurgeKept(preview.keptShared),
                    style: studioText(c, color: c.textSecondary),
                  ),
                ],
              ],
            ),
            action: l10n.delete,
          )) {
            final result = await notifier.purgeCollections({collectionKey});
            if (context.mounted) {
              _notice(
                context,
                l10n.archivePurgeDone(
                  result.filesDeleted,
                  result.videosRemoved,
                ),
              );
            }
          }
      }
    }

    PopupMenuItem<String> item(
      String value,
      String label, {
      bool red = false,
    }) => PopupMenuItem(
      value: value,
      height: 36,
      child: Text(
        label,
        style: studioText(c, color: red ? c.error : c.textPrimary),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(side, 4, side, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StudioButton(
                    label: l10n.studioArchiveAllCollections,
                    icon: Icons.arrow_back_rounded,
                    kind: StudioButtonKind.light,
                    height: 32,
                    onTap: () => notifier.selectCollection(null),
                  ),
                  const SizedBox(width: 18),
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: studioTitle(c, 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.archiveMobileVideoCount(videos.length),
                    style: studioMono(c, size: 12),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canReset) ...[
                    PopupMenuButton<String>(
                      tooltip: l10n.moreActions,
                      onSelected: onMenu,
                      itemBuilder: (_) => [
                        item('reset', l10n.archiveCollReset),
                        item('purge', l10n.archivePurgeMenu, red: true),
                        item('delete', l10n.archiveCollDelete, red: true),
                      ],
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.border),
                        ),
                        child: Icon(
                          Icons.more_horiz_rounded,
                          size: 16,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (videos.isNotEmpty && !ref.read(showcaseModeProvider)) ...[
                    StudioIconButton(
                      icon: Icons.play_arrow_rounded,
                      tooltip: l10n.archiveMobilePlayFullscreen,
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (dialogContext) => Dialog.fullscreen(
                          child: TikTokFeedView(
                            videos: videos,
                            onClose: () => Navigator.of(dialogContext).pop(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (videos.isNotEmpty)
                    StudioButton(
                      label: l10n.archiveCollDownloadAll(videos.length),
                      icon: Icons.download_rounded,
                      height: 36,
                      onTap: batch
                          ? null
                          : () async {
                              _notice(
                                context,
                                l10n.studioArchiveFolderQueued(videos.length),
                              );
                              await notifier.downloadBatch(
                                videos,
                                limit: videos.length,
                              );
                            },
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: videos.isEmpty
                ? Align(
                    alignment: AlignmentDirectional.topStart,
                    child: Text(
                      l10n.studioArchiveEmptyCollection,
                      style: studioText(c, color: c.textSecondary),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: _VideoTable(videos: videos),
                  ),
          ),
        ],
      ),
    );
  }
}
