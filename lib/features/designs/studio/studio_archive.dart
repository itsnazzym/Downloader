import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/archive/presentation/views/desktop/tiktok_archive_desktop_view.dart';
import 'package:modern_downloader/features/archive/presentation/views/modes/tiktok_collections_view.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'studio_widgets.dart';

/// Studio's TikTok archive (mockup Studio-Archives.dc.html): « Archive locale
/// · TikTok », the archive's counts, Synchroniser / Tout télécharger and the
/// Vidéos / Collections / Favoris tabs over today's archive views. Loading,
/// the import hub and an empty archive keep today's view.
class StudioArchive extends ConsumerWidget {
  const StudioArchive({super.key, required this.current});

  final Widget current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (loading, hub, hasCatalog, mode, favorites) = ref.watch(
      tikTokArchiveProvider.select(
        (s) => (
          s.isLoading,
          s.viewMode == TikTokViewMode.hub,
          s.hasCatalog,
          s.viewMode,
          s.filter.statusFilter == TikTokStatusFilter.favoritesOnly,
        ),
      ),
    );
    if (loading || hub || !hasCatalog) return current;
    final catalog = ref.watch(tikTokArchiveProvider.select((s) => s.catalog!));
    // An opened collection, or « Toutes les options », shows today's view.
    final opened = ref.watch(
      tikTokArchiveProvider.select((s) => s.filter.selectedCollection != null),
    );
    final full = ref.watch(_fullProvider);
    final native = mode == TikTokViewMode.collections && !opened && !full;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Today's view switches to its phone layout there: keep it whole.
        if (constraints.maxWidth < 800) return current;
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
                    native: native,
                  ),
                ),
              ),
            ),
            if (full && mode == TikTokViewMode.collections)
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(side, 0, side, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: StudioButton(
                    label: context.l10n.studioSimpleView,
                    icon: Icons.arrow_back_rounded,
                    kind: StudioButtonKind.light,
                    height: 32,
                    onTap: () => ref.read(_fullProvider.notifier).state = false,
                  ),
                ),
              ),
            Expanded(
              child: native
                  ? _CollectionsGrid(side: side)
                  : mode == TikTokViewMode.collections
                  ? TikTokCollectionsView(catalog: catalog)
                  : TikTokArchiveDesktopView(catalog: catalog),
            ),
          ],
        );
      },
    );
  }
}

final _fullProvider = StateProvider.autoDispose<bool>((ref) => false);
final _selectingProvider = StateProvider.autoDispose<bool>((ref) => false);
final _selectedProvider = StateProvider.autoDispose<Set<String>>(
  (ref) => const {},
);

class _Header extends ConsumerWidget {
  const _Header({
    required this.mode,
    required this.favorites,
    required this.native,
  });

  final TikTokViewMode mode;
  final bool favorites;
  final bool native;

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
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.studioDownloadAll),
          content: Text(l10n.studioDownloadAllConfirm(pending.length)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
      if (ok == true) {
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
        // Import and sync live in today's archive hub.
        StudioButton(
          label: l10n.studioSync,
          icon: Icons.sync_rounded,
          kind: StudioButtonKind.light,
          onTap: () => notifier.setViewMode(TikTokViewMode.hub),
        ),
        const SizedBox(width: 16),
        batch
            ? StudioButton(
                label: l10n.cancel,
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
            Expanded(child: StudioTabs(
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
              onTap: () => notifier.setViewMode(TikTokViewMode.collections),
            ),
            StudioTab(
              label: l10n.archiveMobileFilterFavorites,
              count: number.format(catalog.totalFavorites),
              selected: mode == TikTokViewMode.list && favorites,
              onTap: () => listMode(TikTokStatusFilter.favoritesOnly),
            ),
          ],
        )),
            if (native) ...[
              const SizedBox(width: 12),
              StudioButton(
                label: l10n.studioAllOptions,
                kind: StudioButtonKind.light,
                height: 32,
                onTap: () {
                  ref.read(_selectingProvider.notifier).state = false;
                  ref.read(_fullProvider.notifier).state = true;
                },
              ),
              const SizedBox(width: 8),
              StudioButton(
                label: selecting ? l10n.studioDone : l10n.archivePurgeSelect,
                kind: StudioButtonKind.light,
                on: selecting,
                height: 32,
                onTap: () {
                  ref.read(_selectedProvider.notifier).state = const {};
                  ref.read(_selectingProvider.notifier).state = !selecting;
                },
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The collections as cards (mockup): name, video count, how much is on this
/// PC; in selection mode, checkboxes and the « Supprimer leurs vidéos » bar.
class _CollectionsGrid extends ConsumerStatefulWidget {
  const _CollectionsGrid({required this.side});

  final double side;

  @override
  ConsumerState<_CollectionsGrid> createState() => _CollectionsGridState();
}

class _CollectionsGridState extends ConsumerState<_CollectionsGrid> {
  bool _purging = false;

  /// Same confirmation and purge as today's collections view.
  Future<void> _confirmPurge(Set<String> keys) async {
    if (keys.isEmpty || _purging) return;
    final l10n = context.l10n;
    final c = AppColors.of(context);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final preview = notifier.purgePreview(keys);
    final confirmed = await showDialog<bool>(
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
                style: studioText(c, color: c.textSecondary),
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
          StudioButton(
            label: l10n.delete,
            kind: StudioButtonKind.danger,
            height: 32,
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
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final catalog = ref.watch(tikTokArchiveProvider.select((s) => s.catalog!));
    final selecting = ref.watch(_selectingProvider);
    final selected = ref.watch(_selectedProvider);
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
    final cards = [
      for (final coll in catalog.collections)
        (
          key: coll.id ?? coll.name,
          name: coll.name,
          count: coll.videoCount,
          done: done[coll.id ?? coll.name] ?? 0,
          total: total[coll.id ?? coll.name] ?? 0,
        ),
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(widget.side, 8, widget.side, 40),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                            name: card.name,
                            count: card.count,
                            fraction: card.total == 0
                                ? 0
                                : card.done / card.total,
                            selecting: selecting,
                            selected: selected.contains(card.key),
                            onTap: () {
                              if (!selecting) {
                                notifier.selectCollection(card.key);
                                return;
                              }
                              final next = {...selected};
                              if (!next.remove(card.key)) next.add(card.key);
                              ref.read(_selectedProvider.notifier).state =
                                  next;
                            },
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
    required this.name,
    required this.count,
    required this.fraction,
    required this.selecting,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final int count;
  final double fraction;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final on = widget.selecting && widget.selected;
    final pct = (widget.fraction * 100).round();
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
    return Semantics(
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
          padding: const EdgeInsets.all(16),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: StudioUnderline(
                        text: widget.name,
                        hover: _hover,
                        style: studioTitle(
                          c,
                          17,
                        ).copyWith(letterSpacing: -0.34, height: 1.25),
                      ),
                    ),
                  ),
                  if (widget.selecting) ...[
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.all(3),
                      child: StudioCheckbox(value: widget.selected),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${widget.count}',
                      style: studioMono(c, size: 20, color: c.textPrimary),
                    ),
                    TextSpan(text: '  ${l10n.studioVideosUnit}'),
                  ],
                ),
                style: studioText(c, color: c.textSecondary),
              ),
              const SizedBox(height: 14),
              Container(
                constraints: const BoxConstraints(minHeight: 34),
                padding: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.borderSubtle)),
                ),
                child: state,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
