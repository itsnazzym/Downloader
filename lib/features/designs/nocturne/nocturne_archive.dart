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
                  ? NocturneCard(
                      lift: false,
                      padding: EdgeInsets.zero,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: TikTokCollectionsView(catalog: catalog),
                      ),
                    )
                  : _VideoList(state: state, wide: wide),
            ),
          ],
        ),
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
