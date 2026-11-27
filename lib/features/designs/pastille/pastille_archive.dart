import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/archive/presentation/views/modes/tiktok_collections_view.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';

import 'pastille_archive_parts.dart';
import 'pastille_kit.dart';
import 'pastille_scope.dart';

/// Pastille's TikTok archive (mockup Pastille-Archives.dc.html): counts,
/// then Vidéos / Collections / Favoris. Collections are pastel tiles with a
/// download dot bar, selectable for purging; opening one (or the detailed
/// view from the `…` menu) shows Pastille's collection view (or, detailed,
/// today's tools in Pastille's Material language). Vidéos and Favoris keep
/// every filter, search, selection and batch download, drawn in Pastille,
/// under the mockup's summary tile. Import / sync is today's hub, framed.
class PastilleArchive extends ConsumerStatefulWidget {
  const PastilleArchive({super.key, required this.current});

  /// Today's archive view: loading, hub (import / sync) and empty states.
  final Widget current;

  @override
  ConsumerState<PastilleArchive> createState() => _PastilleArchiveState();
}

enum _Tab { videos, collections, favorites }

class _PastilleArchiveState extends ConsumerState<PastilleArchive> {
  bool _selecting = false;
  bool _detailed = false;
  bool _purging = false;
  final Set<String> _picked = {};
  final _search = TextEditingController();

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
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  _Tab _tabOf(TikTokArchiveState s) {
    if (s.viewMode == TikTokViewMode.collections) return _Tab.collections;
    return s.filter.statusFilter == TikTokStatusFilter.favoritesOnly
        ? _Tab.favorites
        : _Tab.videos;
  }

  void _pick(_Tab tab) {
    final n = ref.read(tikTokArchiveProvider.notifier);
    switch (tab) {
      case _Tab.collections:
        n.setViewMode(TikTokViewMode.collections);
      case _Tab.videos:
        n.setStatusFilter(TikTokStatusFilter.all);
        n.setViewMode(TikTokViewMode.list);
      case _Tab.favorites:
        n.setStatusFilter(TikTokStatusFilter.favoritesOnly);
        n.setViewMode(TikTokViewMode.list);
    }
    setState(() {
      _selecting = false;
      _picked.clear();
    });
  }

  Future<void> _confirmPurge() async {
    final keys = Set.of(_picked);
    if (keys.isEmpty || _purging) return;
    final l10n = context.l10n;
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final preview = notifier.purgePreview(keys);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pCard,
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
                style: pBody(size: 13, color: pMuted),
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
          PButton(
            label: l10n.delete,
            icon: Icons.delete_forever_rounded,
            kind: PButtonKind.rose,
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
        _picked.clear();
      });
      _notice(l10n.archivePurgeDone(r.filesDeleted, r.videosRemoved));
    } finally {
      if (mounted) setState(() => _purging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    final state = ref.watch(tikTokArchiveProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final catalog = state.catalog;
    if (state.isLoading) return widget.current;

    final header = PastilleHeader(
      eyebrow: l10n.pastilleArchiveEyebrow,
      title: l10n.pastilleArchiveTitle,
      actions: [
        PButton(
          label: l10n.pastilleSync,
          icon: Icons.sync_rounded,
          kind: PButtonKind.cream,
          height: 46,
          padH: 20,
          fontSize: 14,
          onTap: () => notifier.setViewMode(TikTokViewMode.hub),
        ),
        if (catalog != null && state.hasCatalog)
          PButton(
            label: state.isBatchDownloading
                ? l10n.pastilleBatchStop(
                    state.batchCompletedCount,
                    state.batchTotalCount,
                  )
                : l10n.pastilleDownloadAll,
            icon: state.isBatchDownloading
                ? Icons.stop_rounded
                : Icons.download_rounded,
            iconSize: 17,
            kind: PButtonKind.butter,
            height: 46,
            padH: 22,
            fontSize: 14,
            onTap: state.isBatchDownloading
                ? notifier.stopBatch
                : () async {
                    final todo = [
                      for (final v in catalog.videos)
                        if (!v.isDownloaded) v,
                    ];
                    if (ref.read(showcaseModeProvider)) {
                      _notice(l10n.pastilleDemoDownload);
                      return;
                    }
                    await notifier.downloadBatch(todo, limit: todo.length);
                  },
          ),
      ],
    );

    // Import / sync hub and the empty archive: today's view, framed.
    if (state.viewMode == TikTokViewMode.hub || !state.hasCatalog) {
      return _Framed(header: header, child: widget.current);
    }
    final cat = catalog!;
    final tab = _tabOf(state);
    final openCollection =
        tab == _Tab.collections && state.filter.selectedCollection != null;

    final tabsRow = Row(
      children: [
        PSeg(
          page: true,
          items: [
            PSegItem(
              l10n.pastilleArchiveVideos,
              tab == _Tab.videos,
              () => _pick(_Tab.videos),
            ),
            PSegItem(
              l10n.pastilleArchiveCollections,
              tab == _Tab.collections,
              () => _pick(_Tab.collections),
            ),
            PSegItem(
              l10n.pastilleArchiveFavorites,
              tab == _Tab.favorites,
              () => _pick(_Tab.favorites),
            ),
          ],
        ),
        const Spacer(),
        if (tab == _Tab.collections && !_detailed && !openCollection) ...[
          PButton(
            label: _selecting ? l10n.pastilleDone : l10n.archivePurgeSelect,
            icon: Icons.check_circle_outline_rounded,
            iconSize: 15,
            kind: _selecting ? PButtonKind.butter : PButtonKind.cream,
            tooltip: l10n.archivePurgeSelectTooltip,
            onTap: () => setState(() {
              _selecting = !_selecting;
              _picked.clear();
            }),
          ),
          const SizedBox(width: 8),
        ],
        if (tab == _Tab.collections && !openCollection)
          PopupMenuButton<bool>(
            tooltip: l10n.pastilleMoreActions,
            color: pCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            onSelected: (v) => setState(() {
              _detailed = v;
              _selecting = false;
              _picked.clear();
            }),
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: !_detailed,
                checked: _detailed,
                child: Text(
                  l10n.pastilleDetailedView,
                  style: pBody(color: pCream),
                ),
              ),
            ],
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: pInkDeep,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: pCream.withValues(alpha: 0.1),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.more_horiz_rounded,
                size: 18,
                color: pMuted,
              ),
            ),
          ),
      ],
    );

    final children = <Widget>[
      header,
      PGrid(
        rowHeight: 150,
        cells: [
          PCell(_LocalTile(catalog: cat)),
          PCell(
            _CountTile(
              color: tones.rose,
              icon: Icons.smart_display_outlined,
              label: l10n.pastilleArchiveVideos,
              value: cat.videos.length,
              caption: l10n.pastilleInArchive,
              delay: 60,
            ),
          ),
          PCell(
            _CountTile(
              color: tones.lav,
              icon: Icons.grid_view_rounded,
              label: l10n.pastilleArchiveCollections,
              value: cat.collections.length,
              caption: l10n.pastilleByTheme,
              delay: 120,
            ),
          ),
          PCell(
            _CountTile(
              color: tones.butter,
              icon: Icons.favorite_border_rounded,
              label: l10n.pastilleArchiveFavorites,
              value: cat.totalFavorites,
              caption: l10n.pastilleKeptOnTikTok,
              delay: 180,
            ),
          ),
        ],
      ),
      tabsRow,
    ];

    if (tab == _Tab.collections) {
      if (openCollection) {
        children.add(_Embedded(child: PastilleCollectionDetail(catalog: cat)));
      } else if (_detailed) {
        // The detailed tools (posters, suggestions, reset): today's view
        // in Pastille's Material language.
        children.add(
          _Embedded(
            child: PastilleScope(child: TikTokCollectionsView(catalog: cat)),
          ),
        );
      } else {
        if (_selecting) {
          children.add(
            _SelectionBar(
              count: _picked.length,
              busy: _purging,
              onPurge: _confirmPurge,
            ),
          );
        }
        children.add(
          _CollectionGrid(
            catalog: cat,
            selecting: _selecting,
            picked: _picked,
            onTap: (key, special) {
              if (!_selecting) {
                notifier.selectCollection(key);
              } else if (!special) {
                setState(() {
                  if (!_picked.remove(key)) _picked.add(key);
                });
              }
            },
          ),
        );
      }
    } else {
      final favorites = tab == _Tab.favorites;
      children
        ..add(
          _SummaryPane(
            color: favorites ? tones.butter : tones.rose,
            title: favorites
                ? l10n.pastilleArchiveFavorites
                : l10n.pastilleArchiveVideos,
            count: favorites ? cat.totalFavorites : cat.videos.length,
            label: favorites
                ? l10n.pastilleFavoritesLabel
                : l10n.pastilleVideosLabel,
            text: favorites
                ? l10n.pastilleFavoritesText
                : l10n.pastilleVideosText,
            onCollections: () => _pick(_Tab.collections),
          ),
        )
        ..add(
          _Embedded(
            child: _VideoBrowser(search: _search, notice: _notice),
          ),
        );
    }
    return PastillePage(gap: 22, children: children);
  }
}

/// Today's view under the Pastille header (hub, empty archive).
class _Framed extends StatelessWidget {
  const _Framed({required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: pBackground,
      child: LayoutBuilder(
        builder: (context, c) {
          final side = c.maxWidth > 1264 ? (c.maxWidth - 1200) / 2 : 32.0;
          return Padding(
            padding: EdgeInsets.fromLTRB(side, 30, side, 92),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 22),
                Expanded(
                  child: _Rounded(child: PastilleScope(child: child)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Rounded extends StatelessWidget {
  const _Rounded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pBackground,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: pCream.withValues(alpha: 0.08), spreadRadius: 1),
        ],
      ),
      child: child,
    );
  }
}

/// A fixed-height window on a view that scrolls by itself.
class _Embedded extends StatelessWidget {
  const _Embedded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final h = math.max(520.0, MediaQuery.sizeOf(context).height - 220);
    return SizedBox(
      height: h,
      child: _Rounded(child: child),
    );
  }
}

class _LocalTile extends StatelessWidget {
  const _LocalTile({required this.catalog});

  final TikTokArchiveCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final years = catalog.yearCounts.keys.toList()..sort();
    // No account name in a TikTok export: the years it covers stand in.
    final span = years.isEmpty
        ? '—'
        : (years.first == years.last
              ? '${years.first}'
              : '${years.first} – ${years.last}');
    return PTile(
      color: pInkDeep,
      semanticLabel: l10n.pastilleLocalArchive,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(
              icon: Icons.music_note_rounded,
              iconColor: PTones.of(context).rose,
              text: l10n.pastilleLocalArchive,
            ),
            const Spacer(),
            Text(
              span,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pNum(26, color: pCream).copyWith(height: 1.1),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.pastilleLikes(catalog.totalLikes),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pSub(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.delay,
  });

  final Color color;
  final IconData icon;
  final String label;
  final int value;
  final String caption;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return PTile(
      color: color,
      delay: delay,
      semanticLabel: label,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(icon: icon, text: label),
            const Spacer(),
            Text('$value', maxLines: 1, style: pNum(52, color: pInk)),
            const SizedBox(height: 6),
            Text(caption, style: pSub(context)),
          ],
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.busy,
    required this.onPurge,
  });

  final int count;
  final bool busy;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 8, 8, 8),
        decoration: BoxDecoration(
          color: pInkDeep,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: pCream.withValues(alpha: 0.1), spreadRadius: 1),
          ],
        ),
        child: Row(
          children: [
            Text(
              l10n.archivePurgeSelectedCount(count),
              style: pBody(weight: FontWeight.w700, color: pCream),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.info_outline_rounded, size: 14, color: pMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.pastilleSharedKept,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: pBody(size: 12.5, color: pMuted),
              ),
            ),
            const SizedBox(width: 16),
            PButton(
              label: l10n.archivePurgeAction,
              icon: Icons.delete_outline_rounded,
              iconSize: 15,
              kind: PButtonKind.rose,
              onTap: count == 0 || busy ? null : onPurge,
            ),
          ],
        ),
      ),
    );
  }
}

/// Collection names that are views over the archive, not real collections.
const _virtual = {'Favoris non classés', 'Vidéos Likées'};

class _CollectionGrid extends StatelessWidget {
  const _CollectionGrid({
    required this.catalog,
    required this.selecting,
    required this.picked,
    required this.onTap,
  });

  final TikTokArchiveCatalog catalog;
  final bool selecting;
  final Set<String> picked;
  final void Function(String key, bool special) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    final palette = [
      tones.sage,
      tones.sky,
      tones.butter,
      tones.lav,
      tones.rose,
      tones.cream,
    ];
    if (catalog.collections.isEmpty) {
      return Text(l10n.pastilleNoCollections, style: pBody(color: pMuted));
    }
    return PGrid(
      rowHeight: 178,
      cells: [
        for (var i = 0; i < catalog.collections.length; i++)
          PCell(
            Builder(
              builder: (context) {
                final c = catalog.collections[i];
                final key = c.id ?? c.name;
                final inside = catalog.videos.where(
                  (v) =>
                      (c.id != null && v.collectionIds.contains(c.id)) ||
                      v.collectionName == c.name,
                );
                final total = math.max(c.videoCount, inside.length);
                final done = inside.where((v) => v.isDownloaded).length;
                final pct = total == 0 ? 0 : (done * 100 / total).round();
                final status = pct >= 100
                    ? l10n.pastilleAllDownloaded
                    : (pct > 0
                          ? l10n.pastillePercentDownloaded(pct)
                          : l10n.pastilleToDownload);
                final special = _virtual.contains(c.name);
                final on = picked.contains(key);
                return PTile(
                  color: palette[i % palette.length],
                  delay: math.min(i, 12) * 50,
                  picked: selecting && on,
                  semanticLabel: c.name,
                  onTap: () => onTap(key, special),
                  child: Builder(
                    builder: (context) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 30,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: pBody(
                                    weight: FontWeight.w700,
                                    color: pInk,
                                  ),
                                ),
                              ),
                              if (selecting && !special)
                                Semantics(
                                  checked: on,
                                  child: PCheck(on: on),
                                ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('$total', style: pNum(44, color: pInk)),
                            const SizedBox(width: 8),
                            Text(l10n.pastilleVideosWord, style: pSub(context)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        PDots(
                          count: 30,
                          columns: 15,
                          gap: 5,
                          on: (pct * 30 / 100).round(),
                          semanticLabel: status,
                        ),
                        const SizedBox(height: 8),
                        Text(status, style: pSub(context)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SummaryPane extends StatelessWidget {
  const _SummaryPane({
    required this.color,
    required this.title,
    required this.count,
    required this.label,
    required this.text,
    required this.onCollections,
  });

  final Color color;
  final String title;
  final int count;
  final String label;
  final String text;
  final VoidCallback onCollections;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: 172 * 2 + 14,
      child: PTile(
        color: color,
        semanticLabel: title,
        child: Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PLabel(
                icon: Icons.smart_display_outlined,
                text: title,
                trailing: Text(l10n.pastilleOneDotTen),
              ),
              const SizedBox(height: 16),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 28,
                runSpacing: 14,
                children: [
                  Text('$count', style: pNum(112, color: pInk)),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: pBody(
                              size: 16,
                              weight: FontWeight.w700,
                              color: pInk,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(text, style: pSub(context, size: 13.5)),
                          const SizedBox(height: 14),
                          PButton(
                            label: l10n.pastilleSeeCollections,
                            onTap: onCollections,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              PDots(
                count: (count / 10).ceil().clamp(0, 124),
                columns: 31,
                gap: 5,
                on: (count / 10).ceil().clamp(0, 124),
                maxWidth: 760,
                semanticLabel: '$count $label',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Today's video list: filters beside it, search, select, download.
class _VideoBrowser extends ConsumerWidget {
  const _VideoBrowser({required this.search, required this.notice});

  final TextEditingController search;
  final void Function(String) notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    final state = ref.watch(tikTokArchiveProvider);
    final videos = ref.watch(filteredTikTokVideosProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PastilleArchiveFilters(),
        Container(width: 1.5, color: pCream.withValues(alpha: 0.07)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1C1A),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: pCream.withValues(alpha: 0.1),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: pFaint),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: search,
                          onChanged: notifier.setSearchQuery,
                          style: pBody(color: pCream),
                          cursorColor: tones.butter,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            contentPadding: EdgeInsets.zero,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: l10n.pastilleArchiveSearch,
                            hintStyle: pBody(color: pFaint),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.pastilleVideoCount(videos.length),
                        style: pBody(
                          size: 13,
                          weight: FontWeight.w600,
                          color: pMuted,
                        ),
                      ),
                    ),
                    if (state.selectedIds.isEmpty)
                      PButton(
                        label: l10n.pastilleSelectAll,
                        kind: PButtonKind.cream,
                        height: 36,
                        onTap: videos.isEmpty
                            ? null
                            : () => notifier.selectAll(videos),
                      )
                    else ...[
                      PButton(
                        label: l10n.pastilleClearSelection(
                          state.selectedIds.length,
                        ),
                        kind: PButtonKind.cream,
                        height: 36,
                        onTap: notifier.clearSelection,
                      ),
                      const SizedBox(width: 8),
                      PButton(
                        label: state.isBatchDownloading
                            ? l10n.pastilleBatchProgress(
                                state.batchCompletedCount,
                                state.batchTotalCount,
                              )
                            : l10n.pastilleDownloadSelection,
                        icon: Icons.download_rounded,
                        kind: PButtonKind.butter,
                        height: 36,
                        onTap: state.isBatchDownloading
                            ? null
                            : () async {
                                await notifier.downloadSelected();
                                notice(l10n.pastilleQueued);
                              },
                      ),
                    ],
                  ],
                ),
              ),
              if (state.isBatchDownloading && state.batchTotalCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 20, 8),
                  child: PDots(
                    count: 50,
                    columns: 50,
                    gap: 3,
                    on: (state.batchCompletedCount * 50 / state.batchTotalCount)
                        .floor(),
                    live: true,
                    semanticLabel: l10n.pastilleBatchProgress(
                      state.batchCompletedCount,
                      state.batchTotalCount,
                    ),
                  ),
                ),
              Expanded(
                child: videos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.pastilleNoVideoMatch,
                              style: pBody(color: pMuted),
                            ),
                            const SizedBox(height: 14),
                            PButton(
                              label: l10n.pastilleResetFilters,
                              kind: PButtonKind.cream,
                              onTap: notifier.resetFilters,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                        itemCount: videos.length,
                        itemBuilder: (context, i) {
                          final v = videos[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: PastilleVideoRow(
                              item: v,
                              isSelected: state.selectedIds.contains(v.id),
                              onToggleSelect: () =>
                                  notifier.toggleSelection(v.id),
                              onDownload: () async {
                                if (ref.read(showcaseModeProvider)) {
                                  notice(l10n.pastilleDemoDownload);
                                  return;
                                }
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
