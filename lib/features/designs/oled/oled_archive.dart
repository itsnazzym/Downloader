import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tapload/core/services/local_server_service.dart';
import 'package:tapload/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/archive/presentation/views/modes/tiktok_collections_view.dart';
import 'package:tapload/l10n/l10n_ext.dart';
import 'package:tapload/showcase/showcase_mode.dart';

import 'oled_states.dart';
import 'oled_theme.dart';
import 'oled_widgets.dart';

/// OLED's TikTok archive (mockup OLED-Archives.dc.html): the archive's
/// figures in Doto (favourites lit), sync and import, the Vidéos /
/// Collections / Favoris tabs with the selection and its download, then the
/// filters beside the video cards. The loading screen, the import hub and
/// the Collections tab (open, purge, reset, delete, suggestions) are
/// today's views ([current], [TikTokCollectionsView]) in OLED's theme.
class OledArchive extends ConsumerWidget {
  const OledArchive({super.key, required this.current});

  final Widget current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tikTokArchiveProvider);
    final catalog = state.catalog;
    if (state.isLoading ||
        !state.hasCatalog ||
        catalog == null ||
        state.viewMode == TikTokViewMode.hub) {
      return current;
    }
    final collections = state.viewMode == TikTokViewMode.collections;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final side = wide ? 40.0 : 20.0;
        return Padding(
          padding: EdgeInsets.fromLTRB(side, 30, side, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(state: state, catalog: catalog),
              const SizedBox(height: 26),
              _Tabs(state: state, catalog: catalog),
              const SizedBox(height: 22),
              Expanded(
                child: collections
                    ? TikTokCollectionsView(catalog: catalog)
                    : _Videos(state: state, catalog: catalog, wide: wide),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.state, required this.catalog});

  final TikTokArchiveState state;
  final TikTokArchiveCatalog catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final showcase = ref.watch(showcaseModeProvider);
    final connected =
        showcase || ref.watch(extensionConnectedClientsProvider) > 0;
    final syncing = state.syncStatus == TikTokSyncStatus.waiting;
    final message = state.syncMessage ?? state.errorMessage;
    final failed =
        state.errorMessage != null ||
        state.syncStatus == TikTokSyncStatus.failed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 24,
          runSpacing: 18,
          children: [
            Wrap(
              spacing: 56,
              runSpacing: 18,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                OledFigure(
                  value: '${catalog.totalUniqueVideos}',
                  label: l10n.oledWordVideos(catalog.totalUniqueVideos),
                ),
                OledFigure(
                  value: '${catalog.collections.length}',
                  label: l10n.oledWordCollections(catalog.collections.length),
                ),
                OledFigure(
                  value: '${catalog.totalFavorites}',
                  label: l10n.oledWordFavorites(catalog.totalFavorites),
                  lit: catalog.totalFavorites > 0,
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OledPill(
                  label: syncing ? l10n.oledSyncing : l10n.oledSync,
                  onTap: syncing || !connected
                      ? null
                      : notifier.triggerExtensionSync,
                ),
                OledPill(
                  label: l10n.oledImportExport,
                  onTap: showcase ? null : notifier.pickAndImportFile,
                ),
              ],
            ),
          ],
        ),
        if (message != null && !syncing) ...[
          const SizedBox(height: 12),
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: oledMono(color: failed ? OledInk.err : OledInk.mute),
          ),
        ],
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
    final videos = ref.watch(filteredTikTokVideosProvider);
    final tab = state.viewMode == TikTokViewMode.collections
        ? _Tab.collections
        : state.filter.statusFilter == TikTokStatusFilter.favoritesOnly
        ? _Tab.favorites
        : _Tab.videos;
    void pick(_Tab t) {
      if (t == _Tab.collections) {
        notifier.setViewMode(TikTokViewMode.collections);
        return;
      }
      notifier.setStatusFilter(
        t == _Tab.favorites
            ? TikTokStatusFilter.favoritesOnly
            : TikTokStatusFilter.all,
      );
      notifier.setViewMode(TikTokViewMode.list);
    }

    final selected = state.selectedIds.length;
    final Widget actions;
    if (tab == _Tab.collections) {
      actions = const SizedBox.shrink();
    } else if (state.isBatchDownloading) {
      actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${state.batchCompletedCount} / ${state.batchTotalCount}',
            style: oledMono(color: OledInk.ion),
          ),
          const SizedBox(width: 14),
          OledPill(
            label: l10n.oledStop,
            height: 40,
            padding: 18,
            fontSize: 13,
            onTap: notifier.stopBatch,
          ),
        ],
      );
    } else if (selected == 0) {
      actions = OledPill(
        label: l10n.oledSelectAll,
        height: 40,
        padding: 18,
        fontSize: 13,
        onTap: videos.isEmpty ? null : () => notifier.selectAll(videos),
      );
    } else {
      actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OledTextLink(
            label: l10n.oledSelectedCount(selected),
            size: 12,
            onTap: notifier.clearSelection,
          ),
          const SizedBox(width: 14),
          OledPill(
            label: l10n.oledDownloadSelection,
            kind: OledPillKind.ion,
            height: 40,
            padding: 18,
            fontSize: 13,
            onTap: () async {
              await notifier.downloadSelected();
              if (context.mounted) oledNotice(context, l10n.oledQueued);
            },
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: OledInk.line)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Wrap(
            spacing: 26,
            children: [
              for (final (t, label) in [
                (_Tab.videos, l10n.oledTabVideos),
                (_Tab.collections, l10n.oledTabCollections),
                (_Tab.favorites, l10n.oledTabFavorites),
              ])
                OledTextLink(
                  label: label,
                  selected: tab == t,
                  onTap: () => pick(t),
                ),
            ],
          ),
          actions,
        ],
      ),
    );
  }
}

/// Vidéos and Favoris: the filters (type, collections, year) and the cards.
class _Videos extends ConsumerWidget {
  const _Videos({
    required this.state,
    required this.catalog,
    required this.wide,
  });

  final TikTokArchiveState state;
  final TikTokArchiveCatalog catalog;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final videos = ref.watch(filteredTikTokVideosProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final showcase = ref.watch(showcaseModeProvider);
    final Widget grid = videos.isEmpty
        ? SingleChildScrollView(
            child: OledState(
              glyph: false,
              title: l10n.noResults,
              action: OledPill(
                label: l10n.archiveMobileReset,
                onTap: notifier.resetFilters,
              ),
            ),
          )
        : GridView.builder(
            padding: const EdgeInsets.only(bottom: 32),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisExtent: 210,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: videos.length,
            itemBuilder: (context, i) {
              final video = videos[i];
              return _VideoCard(
                item: video,
                selected: state.selectedIds.contains(video.id),
                onToggle: () => notifier.toggleSelection(video.id),
                onDownload: showcase
                    ? null
                    : () => notifier.downloadBatch([video], limit: 1),
              );
            },
          );
    if (!wide) return grid;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 220,
          child: _Filters(state: state, catalog: catalog),
        ),
        const SizedBox(width: 40),
        Expanded(child: grid),
      ],
    );
  }
}

/// « ● Tous ○ Favoris ○ J'aime », the collections and their counts, years.
class _Filters extends ConsumerWidget {
  const _Filters({required this.state, required this.catalog});

  final TikTokArchiveState state;
  final TikTokArchiveCatalog catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final filter = state.filter;
    final years = catalog.yearCounts.keys.toList()..sort((a, b) => b - a);
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(text.toUpperCase(), style: oledEyebrow()),
    );
    // ● / ○ drawn, not typed: the UI fonts have no such glyphs.
    Widget radio(String label, bool on, VoidCallback onTap) => Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? OledInk.ink : null,
            border: on ? null : Border.all(color: OledInk.mute),
          ),
        ),
        const SizedBox(width: 8),
        OledTextLink(
          label: label,
          size: 13,
          selected: on,
          selectedWeight: FontWeight.w400,
          onTap: onTap,
        ),
      ],
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            l10n.archiveMobileType.toUpperCase(),
            style: oledEyebrow(),
          ),
        ),
        for (final (f, label) in [
          (TikTokStatusFilter.all, l10n.archiveMobileFilterAll),
          (TikTokStatusFilter.favoritesOnly, l10n.archiveMobileFilterFavorites),
          (TikTokStatusFilter.likesOnly, l10n.archiveMobileFilterLikes),
        ])
          radio(
            label,
            filter.statusFilter == f,
            () => notifier.setStatusFilter(f),
          ),
        heading(l10n.oledTabCollections),
        for (final col in catalog.collections)
          _CollectionLink(
            name: col.name,
            count: col.videoCount,
            selected: filter.selectedCollection == col.name,
            onTap: () => notifier.selectCollection(
              filter.selectedCollection == col.name ? null : col.name,
            ),
          ),
        heading(l10n.archiveMobileYear),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            OledTextLink(
              label: l10n.archiveMobileAllYears,
              size: 13,
              selectedWeight: FontWeight.w400,
              selected: filter.selectedYear == null,
              onTap: () => notifier.selectYear(null),
            ),
            for (final y in years)
              OledTextLink(
                label: '$y',
                size: 13,
                selectedWeight: FontWeight.w400,
                selected: filter.selectedYear == y,
                onTap: () =>
                    notifier.selectYear(filter.selectedYear == y ? null : y),
              ),
          ],
        ),
      ],
    );
  }
}

class _CollectionLink extends StatelessWidget {
  const _CollectionLink({
    required this.name,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OledTextLink(
            label: name,
            size: 13,
            selected: selected,
            selectedWeight: FontWeight.w500,
            onTap: onTap,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: oledMono(
            size: 13,
            color: selected ? OledInk.ion : OledInk.mute,
          ),
        ),
      ],
    );
  }
}

const _tones = [
  Color(0xFF0D0D0D),
  Color(0xFF111111),
  Color(0xFF0A0A0A),
  Color(0xFF141414),
];

/// One archived video (`.o-vid`): a dark still with its check, the date
/// title, the collection and its marks (★ favourite in ion, ♥ liked).
class _VideoCard extends StatefulWidget {
  const _VideoCard({
    required this.item,
    required this.selected,
    required this.onToggle,
    required this.onDownload,
  });

  final TikTokArchiveItem item;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback? onDownload;

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = widget.item;
    final on = widget.selected;
    final show = _hover || _focus;
    return Semantics(
      checked: on,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onToggle,
          onHover: (v) => setState(() => _hover = v),
          onFocusChange: (v) => setState(() => _focus = v),
          borderRadius: BorderRadius.circular(14),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: OledInk.ion.withValues(alpha: 0.05),
          child: OledHoverBox(
            selected: on || _focus,
            hoverColor: const Color(0xFF2E2E2E),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _tones[item.id.hashCode % _tones.length],
                          OledInk.bg,
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 8,
                          left: 8,
                          child: OledCheck(checked: on),
                        ),
                        if (widget.onDownload != null)
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: IgnorePointer(
                              ignoring: !show,
                              child: AnimatedOpacity(
                                opacity: show ? 1 : 0,
                                duration: oledMotion(context, 150),
                                child: IconButton(
                                  tooltip: l10n.designDownload,
                                  icon: const Icon(
                                    Icons.download_rounded,
                                    size: 18,
                                  ),
                                  color: OledInk.ion,
                                  onPressed: widget.onDownload,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.archiveVideoTitle(
                    DateFormat.yMd(l10n.localeName).format(item.date),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: oledText(size: 13, weight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.collectionName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: oledMono(size: 11),
                      ),
                    ),
                    if (item.isFavorite)
                      Tooltip(
                        message: l10n.archiveMobileFilterFavorites,
                        child: const Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: OledInk.ion,
                        ),
                      ),
                    if (item.isLiked) ...[
                      const SizedBox(width: 4),
                      Tooltip(
                        message: l10n.archiveMobileFilterLikes,
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 12,
                          color: OledInk.mute,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
