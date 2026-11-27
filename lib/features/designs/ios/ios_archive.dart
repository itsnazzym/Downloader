import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:modern_downloader/core/plugins/feature_activation.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_video_cache_provider.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';

import 'ios_glass.dart';
import 'ios_theme.dart';

/// iOS's TikTok archive (mockup iOS-Archives.dc.html): the archive's
/// figures, Collections / Vidéos / Favoris and sync; collections as big
/// tiles with a glass bar and « Tout télécharger », the opened one's videos
/// below with round checkboxes.
///
/// The import hub, the loading catalogue and an empty archive stay today's
/// view ([current]), framed on the glass; « Toutes les options » brings it
/// back for what the mockup does not draw (filters by year, purge, renaming
/// and deleting collections, suggestions).
class IosArchive extends ConsumerStatefulWidget {
  const IosArchive({super.key, required this.current});

  final Widget current;

  @override
  ConsumerState<IosArchive> createState() => _IosArchiveState();
}

class _IosArchiveState extends ConsumerState<IosArchive> {
  bool _detailed = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tikTokArchiveProvider);
    final catalog = state.catalog;
    if (_detailed ||
        state.isLoading ||
        !state.hasCatalog ||
        catalog == null ||
        state.viewMode == TikTokViewMode.hub) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_detailed && catalog != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 0, 12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: IosButton(
                    label: context.l10n.nocturneSimpleView,
                    icon: Icons.grid_view_rounded,
                    onTap: () => setState(() => _detailed = false),
                  ),
                ),
              ),
            Expanded(child: _Framed(child: widget.current)),
          ],
        ),
      );
    }
    final tab = state.viewMode == TikTokViewMode.collections
        ? _Tab.collections
        : state.filter.statusFilter == TikTokStatusFilter.favoritesOnly
        ? _Tab.favorites
        : _Tab.videos;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
          sliver: SliverToBoxAdapter(
            child: _Header(
              state: state,
              catalog: catalog,
              tab: tab,
              onAllOptions: () => setState(() => _detailed = true),
            ),
          ),
        ),
        if (tab == _Tab.collections) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
            sliver: _Collections(state: state, catalog: catalog),
          ),
          if (state.filter.selectedCollection != null)
            ..._videos(
              context,
              state,
              title: _collectionName(catalog, state.filter.selectedCollection!),
            ),
        ] else
          ..._videos(context, state, title: null),
      ],
    );
  }

  static String _collectionName(TikTokArchiveCatalog catalog, String key) =>
      catalog.collections
          .where((c) => c.id == key || (c.id == null && c.name == key))
          .firstOrNull
          ?.name ??
      key;

  List<Widget> _videos(
    BuildContext context,
    TikTokArchiveState state, {
    required String? title,
  }) {
    final videos = ref.watch(filteredTikTokVideosProvider);
    final l10n = context.l10n;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 14),
        sliver: SliverToBoxAdapter(
          child: _VideosBar(state: state, videos: videos, title: title),
        ),
      ),
      if (videos.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
          sliver: SliverToBoxAdapter(
            child: IosGlass(
              radius: 26,
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.nocturneNoMatch,
                      style: iosText(
                        IosTokens.of(context),
                        color: IosTokens.of(context).sub,
                      ),
                    ),
                  ),
                  IosButton(
                    label: l10n.nocturneResetFilters,
                    onTap: ref
                        .read(tikTokArchiveProvider.notifier)
                        .resetFilters,
                  ),
                ],
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 170,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 9 / 16.2,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _VideoTile(
                key: ValueKey(videos[i].id),
                video: videos[i],
                selected: state.selectedIds.contains(videos[i].id),
              ),
              childCount: videos.length,
            ),
          ),
        ),
    ];
  }
}

/// Today's view on the glass: its own panels, the page's corners.
class _Framed extends StatelessWidget {
  const _Framed({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => IosGlass(
    radius: 28,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: IosFramed(child: child),
    ),
  );
}

enum _Tab { collections, videos, favorites }

class _Header extends ConsumerWidget {
  const _Header({
    required this.state,
    required this.catalog,
    required this.tab,
    required this.onAllOptions,
  });

  final TikTokArchiveState state;
  final TikTokArchiveCatalog catalog;
  final _Tab tab;
  final VoidCallback onAllOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final locale = Localizations.localeOf(context).languageCode;
    final name =
        ref
            .watch(featureCatalogProvider)
            .byId['tiktok_archives']
            ?.nameFor(locale) ??
        l10n.designArchivesTab;
    final syncing = state.syncStatus == TikTokSyncStatus.waiting;
    final figures = [
      l10n.archiveMobileVideoCount(catalog.totalUniqueVideos),
      l10n.archiveHubCollections(catalog.collections.length),
      '${catalog.totalFavorites} ${l10n.nocturneWordFavorites(catalog.totalFavorites)}',
      if (state.syncMessage != null && !syncing) state.syncMessage!,
      if (syncing) l10n.nocturneSyncing,
    ].join(' · ');
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              IosTitle(name),
              const SizedBox(height: 2),
              Text(
                figures,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: iosText(
                  t,
                  color: state.syncStatus == TikTokSyncStatus.failed
                      ? t.red
                      : t.sub,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IosSegmented<_Tab>(
              value: tab,
              height: 34,
              fontSize: 13.5,
              onChanged: (v) {
                if (v == _Tab.collections) {
                  // No hidden filter on « Dans … »: it has no search.
                  notifier.setStatusFilter(TikTokStatusFilter.all);
                  notifier.setSearchQuery('');
                  notifier.selectYear(null);
                  notifier.setViewMode(TikTokViewMode.collections);
                  return;
                }
                notifier.selectCollection(null);
                notifier.setStatusFilter(
                  v == _Tab.favorites
                      ? TikTokStatusFilter.favoritesOnly
                      : TikTokStatusFilter.all,
                );
                notifier.setViewMode(TikTokViewMode.list);
              },
              segments: [
                (_Tab.collections, l10n.nocturneTabCollections),
                (_Tab.videos, l10n.nocturneTabVideos),
                (_Tab.favorites, l10n.nocturneTabFavorites),
              ],
            ),
            const SizedBox(width: 10),
            IosRoundButton(
              icon: Icons.sync_rounded,
              tooltip: syncing ? l10n.nocturneSyncing : l10n.nocturneSync,
              onTap: syncing ? null : notifier.triggerExtensionSync,
            ),
            const SizedBox(width: 10),
            IosRoundButton(
              icon: Icons.tune_rounded,
              tooltip: l10n.nocturneAllOptions,
              onTap: onAllOptions,
            ),
          ],
        ),
      ],
    );
  }
}

/// Is [v] in [col]? The liked and unsorted folders are views over flags.
bool _inCollection(TikTokCollectionItem col, TikTokArchiveItem v) {
  const liked = 'Vidéos Likées';
  const unsorted = 'Favoris non classés';
  if (col.name == liked) return v.isLiked;
  if (col.name == unsorted) {
    return v.isFavorite &&
        v.collectionIds.isEmpty &&
        (v.collectionName == null ||
            v.collectionName == unsorted ||
            v.collectionName == liked);
  }
  return (col.id != null && v.collectionIds.contains(col.id)) ||
      (v.collectionName?.split(' · ').contains(col.name) ?? false);
}

class _Collections extends ConsumerWidget {
  const _Collections({required this.state, required this.catalog});

  final TikTokArchiveState state;
  final TikTokArchiveCatalog catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    // Videos the cache knows are gone don't count, as in today's view.
    final unavailable = ref.watch(showcaseModeProvider)
        ? const <String>{}
        : ref.watch(tiktokUnavailableIdsProvider).valueOrNull ??
              ref.read(tiktokVideoCacheServiceProvider).unavailableIds;
    final open = state.filter.selectedCollection;
    if (catalog.collections.isEmpty) {
      return SliverToBoxAdapter(
        child: Text(l10n.archiveCollEmpty, style: iosText(t, color: t.sub)),
      );
    }
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 520,
        mainAxisExtent: 210,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
      ),
      delegate: SliverChildBuilderDelegate((context, i) {
        final col = catalog.collections[i];
        final key = col.id ?? col.name;
        final videos = [
          for (final v in catalog.videos)
            if (!unavailable.contains(v.id) && _inCollection(col, v)) v,
        ];
        final missing = [
          for (final v in videos)
            if (!v.isDownloaded) v,
        ];
        return _CollectionTile(
          key: ValueKey(key),
          collection: col,
          count: videos.length,
          downloaded: videos.length - missing.length,
          open: open == key,
          onTap: () => notifier.selectCollection(open == key ? null : key),
          onDownload: missing.isEmpty || state.isBatchDownloading
              ? null
              : () => notifier.downloadBatch(missing, limit: missing.length),
        );
      }, childCount: catalog.collections.length),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    super.key,
    required this.collection,
    required this.count,
    required this.downloaded,
    required this.open,
    required this.onTap,
    required this.onDownload,
  });

  final TikTokCollectionItem collection;
  final int count;
  final int downloaded;
  final bool open;
  final VoidCallback onTap;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return IosTap(
      onTap: onTap,
      radius: 30,
      selected: open,
      semanticLabel: collection.name,
      builder: (context, hover) => AnimatedContainer(
        duration: iosMotion(context, 350),
        curve: iosEase,
        transform: Matrix4.translationValues(0, hover && !reduce ? -5 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 60,
              offset: Offset(0, 24),
            ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: open ? t.blueFill : Colors.white.withValues(alpha: 0.12),
            width: open ? 2.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Covers live on TikTok's servers: the tile keeps a soft tint.
            IosArt(seed: collection.name.hashCode),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: CustomPaint(
                // A darker frost: legible over any tint without a blur.
                painter: IosGlassPainter(
                  top: const Color(0x4D0A0C14),
                  bottom: const Color(0x800A0C14),
                  edge: const Color(0x38FFFFFF),
                  highlight: const Color(0x66FFFFFF),
                  radius: 20,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
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
                              style: iosText(
                                t,
                                size: 20,
                                weight: FontWeight.w800,
                                spacing: -0.4,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              l10n.iosCollectionFigures(count, downloaded),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: iosText(
                                t,
                                size: 13,
                                color: const Color(0xFFD5DAE5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IosButton(
                        label: l10n.nocturneDownloadAll,
                        kind: IosButtonKind.white,
                        height: 36,
                        fontSize: 13.5,
                        onTap: onDownload,
                      ),
                    ],
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

/// « Dans Cuisine · 2 sélectionnées », select all, download the selection.
class _VideosBar extends ConsumerWidget {
  const _VideosBar({
    required this.state,
    required this.videos,
    required this.title,
  });

  final TikTokArchiveState state;
  final List<TikTokArchiveItem> videos;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final chosen = state.selectedIds.length;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IosHeading(
              title == null
                  ? l10n.archiveMobileVideoCount(videos.length)
                  : l10n.iosInCollection(title!),
            ),
            if (chosen > 0) ...[
              const SizedBox(width: 12),
              Text(
                l10n.iosSelectedCount(chosen),
                style: iosText(t, size: 13.5, color: t.sub),
              ),
            ],
          ],
        ),
        // Wraps in narrow windows instead of overflowing.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (title == null)
              const SizedBox(width: 240, child: _ArchiveSearch()),
            if (chosen == 0)
              IosButton(
                label: l10n.nocturneSelectAll,
                height: 36,
                onTap: videos.isEmpty ? null : () => notifier.selectAll(videos),
              )
            else ...[
              IosButton(
                label: l10n.iosClearSelection,
                height: 36,
                onTap: notifier.clearSelection,
              ),
              IosButton(
                label: state.isBatchDownloading
                    ? '${state.batchCompletedCount} / ${state.batchTotalCount}'
                    : l10n.nocturneDownloadSelection,
                icon: Icons.download_rounded,
                kind: IosButtonKind.primary,
                height: 36,
                onTap: state.isBatchDownloading
                    ? null
                    : () async {
                        await notifier.downloadSelected();
                        if (!context.mounted) return;
                        ScaffoldMessenger.maybeOf(context)
                          ?..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(l10n.nocturneQueued),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                      },
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ArchiveSearch extends ConsumerStatefulWidget {
  const _ArchiveSearch();

  @override
  ConsumerState<_ArchiveSearch> createState() => _ArchiveSearchState();
}

class _ArchiveSearchState extends ConsumerState<_ArchiveSearch> {
  late final _controller = TextEditingController(
    text: ref.read(tikTokArchiveProvider).filter.searchQuery,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    return SizedBox(
      height: 36,
      child: IosGlass(
        radius: 18,
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 16, color: t.sub),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: ref
                    .read(tikTokArchiveProvider.notifier)
                    .setSearchQuery,
                style: iosText(t, weight: FontWeight.w500),
                cursorColor: t.blueFill,
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: context.l10n.search,
                  hintStyle: iosText(t, weight: FontWeight.w500, color: t.sub),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One archived video: a 9:13 tinted tile (TikTok gives no picture), a mark
/// when it is already downloaded, a round checkbox and its date.
class _VideoTile extends ConsumerWidget {
  const _VideoTile({super.key, required this.video, required this.selected});

  final TikTokArchiveItem video;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.MMMd(locale).format(video.date);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return IosTap(
      onTap: () =>
          ref.read(tikTokArchiveProvider.notifier).toggleSelection(video.id),
      radius: 18,
      selected: selected,
      semanticLabel: l10n.iosSelectVideo(date),
      builder: (context, hover) => AnimatedContainer(
        duration: iosMotion(context, 350),
        curve: iosEase,
        transform: Matrix4.translationValues(0, hover && !reduce ? -5 : 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x59000000),
                      blurRadius: 28,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IosArt(
                      seed: video.id.hashCode,
                      icon: Icons.play_arrow_rounded,
                    ),
                    if (video.isFavorite || video.isDownloaded)
                      PositionedDirectional(
                        top: 8,
                        end: 8,
                        child: Row(
                          children: [
                            if (video.isFavorite)
                              const Icon(
                                Icons.bookmark_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            if (video.isDownloaded)
                              Tooltip(
                                message: l10n.statusCompleted,
                                child: const Icon(
                                  Icons.download_done_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                AnimatedContainer(
                  duration: iosMotion(context, 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? t.blueFill : Colors.transparent,
                    border: Border.all(
                      color: selected ? t.blue : t.sub,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: iosText(t, size: 12.5, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
