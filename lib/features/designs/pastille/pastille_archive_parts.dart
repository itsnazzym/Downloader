import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/utils/browser_launch.dart';
import 'package:tapload/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/archive/presentation/views/modes/tiktok_feed_view.dart';
import 'package:tapload/l10n/l10n_ext.dart';
import 'package:tapload/showcase/showcase_mode.dart';

import 'pastille_kit.dart';
import 'pastille_parts.dart';

/// The archive's inner pieces drawn in Pastille instead of today's filter
/// pane, video card and collection view: same filters, selection, links,
/// downloads, feed player and collection clean-up.

// ── Filter pane ─────────────────────────────────────────────────────────────

class PastilleArchiveFilters extends ConsumerStatefulWidget {
  const PastilleArchiveFilters({super.key});

  @override
  ConsumerState<PastilleArchiveFilters> createState() =>
      _PastilleArchiveFiltersState();
}

class _PastilleArchiveFiltersState
    extends ConsumerState<PastilleArchiveFilters> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: pBody(size: 12.5, weight: FontWeight.w600, color: pFaint),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    final state = ref.watch(tikTokArchiveProvider);
    final catalog = state.catalog;
    final filter = state.filter;
    final n = ref.read(tikTokArchiveProvider.notifier);
    if (catalog == null) return const SizedBox.shrink();
    final years = catalog.yearCounts.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final q = _search.text.toLowerCase();
    final collections = [
      for (final c in catalog.collections)
        if (c.name.toLowerCase().contains(q)) c,
    ];
    return SizedBox(
      width: 272,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 14, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.pastilleArcFilters,
                    style: pNum(
                      20,
                      weight: FontWeight.w700,
                      color: pCream,
                    ).copyWith(letterSpacing: -0.5),
                  ),
                ),
                PButton(
                  label: l10n.pastilleArcClear,
                  kind: PButtonKind.ghost,
                  height: 32,
                  padH: 12,
                  fontSize: 12.5,
                  onTap: () {
                    n.selectYear(null);
                    n.selectCollection(null);
                    n.setStatusFilter(TikTokStatusFilter.all);
                    n.clearSelection();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _label(l10n.pastilleArcType),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (f, label) in [
                  (TikTokStatusFilter.all, l10n.pastilleArcAll),
                  (
                    TikTokStatusFilter.favoritesOnly,
                    l10n.pastilleArchiveFavorites,
                  ),
                  (TikTokStatusFilter.likesOnly, l10n.pastilleArcLikes),
                ])
                  _Chip(
                    label: label,
                    on: filter.statusFilter == f,
                    onTap: () => n.setStatusFilter(f),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _label(l10n.pastilleArcYear),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Chip(
                  label: l10n.pastilleArcAll,
                  on: filter.selectedYear == null,
                  onTap: () => n.selectYear(null),
                ),
                for (final y in years)
                  _Chip(
                    label: '$y  ${catalog.yearCounts[y]}',
                    on: filter.selectedYear == y,
                    onTap: () =>
                        n.selectYear(filter.selectedYear == y ? null : y),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _label(
                    l10n.pastilleArcCollections(catalog.collections.length),
                  ),
                ),
                if (filter.selectedCollection != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PButton(
                      label: l10n.pastilleArcClear,
                      kind: PButtonKind.ghost,
                      height: 28,
                      padH: 10,
                      fontSize: 12,
                      onTap: () => n.selectCollection(null),
                    ),
                  ),
              ],
            ),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
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
                  const Icon(Icons.search_rounded, size: 16, color: pFaint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      style: pBody(size: 13, color: pCream),
                      cursorColor: tones.butter,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: l10n.pastilleArcCollectionSearch,
                        hintStyle: pBody(size: 13, color: pFaint),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  for (final c in collections)
                    _CollectionChoice(
                      name: c.name,
                      count: c.videoCount,
                      selected: filter.selectedCollection == c.name,
                      onTap: () => n.selectCollection(
                        filter.selectedCollection == c.name ? null : c.name,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A filter pill: cream when on, a faint cream wash otherwise.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: on,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: pMotion(context, 180),
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: on ? pCream : pCream.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(999),
            ),
            // A Row, not `alignment`: the pill hugs its label in the Wrap.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: pBody(
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: on ? pInk : pCream,
                    height: 1.2,
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

class _CollectionChoice extends StatefulWidget {
  const _CollectionChoice({
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
  State<_CollectionChoice> createState() => _CollectionChoiceState();
}

class _CollectionChoiceState extends State<_CollectionChoice> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.selected;
    final fg = on ? pInk : pCream;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Semantics(
        selected: on,
        button: true,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(999),
              hoverColor: Colors.transparent,
              child: AnimatedContainer(
                duration: pMotion(context, 180),
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: on
                      ? PTones.of(context).lav
                      : (_hover
                            ? pCream.withValues(alpha: 0.06)
                            : Colors.transparent),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: on ? pInk : PTones.of(context).lav,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: pBody(
                          size: 13.5,
                          weight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                    ),
                    Text(
                      '${widget.count}',
                      style: pMono(size: 12, color: on ? pInk : pFaint),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Video row ───────────────────────────────────────────────────────────────

const _demoFilms = [
  'Sintel',
  'Tears of Steel',
  'Elephants Dream',
  'Big Buck Bunny',
];
const _demoArt = [
  'sintel.jpg',
  'tears-of-steel.jpg',
  'elephants-dream.jpg',
  'big-buck-bunny.png',
];

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// One archived video: round check, still, date title, id, tag pills; copy,
/// open and download on hover (and on keyboard focus).
class PastilleVideoRow extends StatefulWidget {
  const PastilleVideoRow({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onDownload,
  });

  final TikTokArchiveItem item;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onDownload;

  @override
  State<PastilleVideoRow> createState() => _PastilleVideoRowState();
}

class _PastilleVideoRowState extends State<PastilleVideoRow> {
  bool _hover = false;
  bool _focus = false;

  Future<void> _open(String url) async {
    if (Uri.tryParse(url)?.host.endsWith('.invalid') == true) return;
    await openInBrowser(url);
  }

  Widget _tag(String label, IconData icon, Color color) => Container(
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: pInk),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: pBody(size: 11.5, weight: FontWeight.w700, color: pInk),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    final item = widget.item;
    final number = item.id.startsWith('demo-')
        ? int.tryParse(item.id.substring(5))
        : null;
    final demo = number == null ? null : (number - 1) % 4;
    final on = widget.isSelected;
    final showActions = _hover || _focus;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        onFocusChange: (f) => setState(() => _focus = f),
        skipTraversal: true,
        child: AnimatedContainer(
          duration: pMotion(context, 200),
          decoration: BoxDecoration(
            color: on || _hover ? const Color(0xFF2A2723) : pCard,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: on ? tones.butter : pCream.withValues(alpha: 0.07),
                spreadRadius: on ? 2 : 1,
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              hoverColor: Colors.transparent,
              onTap: widget.onToggleSelect,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                child: Row(
                  children: [
                    Semantics(
                      checked: on,
                      child: PCheck(on: on, size: 24),
                    ),
                    const SizedBox(width: 12),
                    if (demo != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/showcase/${_demoArt[demo]}',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          semanticLabel: _demoFilms[demo],
                          errorBuilder: (_, _, _) => Container(
                            width: 48,
                            height: 48,
                            color: tones.lav,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: tones.rose,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 22,
                          color: pInk,
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  demo == null
                                      ? l10n.archiveVideoTitle(_date(item.date))
                                      : l10n.pastilleArcDemoClip(
                                          _demoFilms[demo],
                                          (number! - 1) ~/ 4 + 1,
                                        ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: pBody(
                                    size: 14,
                                    weight: FontWeight.w700,
                                    color: pCream,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: SelectableText(
                                  item.id,
                                  maxLines: 1,
                                  style: pMono(size: 11, color: pFaint),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (item.isFavorite)
                                _tag(
                                  l10n.pastilleArcFavoriteTag,
                                  Icons.bookmark_rounded,
                                  tones.butter,
                                ),
                              if (item.isLiked)
                                _tag(
                                  l10n.pastilleArcLikeTag,
                                  Icons.favorite_rounded,
                                  tones.rose,
                                ),
                              if (item.collectionName != null)
                                _tag(
                                  item.collectionName!,
                                  Icons.folder_rounded,
                                  tones.lav,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: showActions ? 1 : 0,
                      duration: pMotion(context, 140),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PButton(
                            icon: Icons.copy_rounded,
                            tooltip: l10n.pastilleArcCopyLink,
                            kind: PButtonKind.ghost,
                            height: 34,
                            iconSize: 15,
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: item.url));
                              pNotice(context, l10n.pastilleArcLinkCopied);
                            },
                          ),
                          const SizedBox(width: 6),
                          PButton(
                            icon: Icons.open_in_new_rounded,
                            tooltip: l10n.pastilleArcOpenBrowser,
                            kind: PButtonKind.ghost,
                            height: 34,
                            iconSize: 15,
                            onTap: () => _open(item.url),
                          ),
                          const SizedBox(width: 6),
                          PButton(
                            label: l10n.designDownload,
                            icon: Icons.download_rounded,
                            kind: PButtonKind.butter,
                            height: 34,
                            padH: 12,
                            fontSize: 12.5,
                            iconSize: 15,
                            onTap: widget.onDownload,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Open collection ─────────────────────────────────────────────────────────

/// Collection names that are views over the archive, not real collections.
const _virtual = {'Favoris non classés', 'Vidéos Likées'};

/// One collection opened: back pill, its name and count, clean-up menu,
/// the vertical feed player, download all, then its videos.
class PastilleCollectionDetail extends ConsumerWidget {
  const PastilleCollectionDetail({super.key, required this.catalog});

  final TikTokArchiveCatalog catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    final state = ref.watch(tikTokArchiveProvider);
    final videos = ref.watch(filteredTikTokVideosProvider);
    final n = ref.read(tikTokArchiveProvider.notifier);
    final key = state.filter.selectedCollection!;
    final name =
        (state.catalog ?? catalog).collections
            .where((c) => c.id == key || (c.id == null && c.name == key))
            .firstOrNull
            ?.name ??
        key;
    final canReset = videos.isNotEmpty && !_virtual.contains(name);
    final demo = ref.read(showcaseModeProvider);

    Future<void> reset() async {
      if (!await pConfirm(
        context,
        title: l10n.pastilleArcResetTitle,
        body: l10n.pastilleArcResetBody(videos.length, name),
        action: l10n.pastilleArcResetAction,
        icon: Icons.layers_clear_rounded,
      )) {
        return;
      }
      await n.resetCollectionToUnclassified(key);
      if (context.mounted) pNotice(context, l10n.pastilleArcResetDone(name));
    }

    Future<void> delete() async {
      if (!await pConfirm(
        context,
        title: l10n.pastilleArcDeleteTitle,
        body: l10n.pastilleArcDeleteBody(name, videos.length),
        action: l10n.pastilleArcDeleteMenu,
        icon: Icons.delete_forever_rounded,
      )) {
        return;
      }
      await n.deleteCollection(key);
      if (context.mounted) pNotice(context, l10n.pastilleArcDeleteDone(name));
    }

    Future<void> purge() async {
      final preview = n.purgePreview({key});
      if (!await pConfirm(
        context,
        title: l10n.archivePurgeTitle(1),
        body: [
          l10n.archivePurgeBody(preview.videos, preview.files),
          if (preview.keptShared > 0) l10n.archivePurgeKept(preview.keptShared),
        ].join('\n\n'),
        action: l10n.delete,
        icon: Icons.delete_forever_rounded,
      )) {
        return;
      }
      final r = await n.purgeCollections({key});
      if (context.mounted) {
        pNotice(
          context,
          l10n.archivePurgeDone(r.filesDeleted, r.videosRemoved),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Row(
            children: [
              PButton(
                label: l10n.pastilleArcAllCollections,
                icon: Icons.arrow_back_rounded,
                kind: PButtonKind.ghost,
                height: 38,
                padH: 14,
                iconSize: 15,
                onTap: () => n.selectCollection(null),
              ),
              const SizedBox(width: 14),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: tones.lav,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: pNum(
                    24,
                    weight: FontWeight.w700,
                    color: pCream,
                  ).copyWith(letterSpacing: -0.7, height: 1.1),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.pastilleVideoCount(videos.length),
                style: pMono(size: 12, color: pFaint),
              ),
              const Spacer(),
              if (canReset)
                PMenu<String>(
                  tooltip: l10n.pastilleMoreActions,
                  onSelected: (v) => switch (v) {
                    'reset' => reset(),
                    'purge' => purge(),
                    _ => delete(),
                  },
                  items: (context) => [
                    pMenuItem(
                      value: 'reset',
                      label: l10n.pastilleArcRemoveFromCollection,
                      icon: Icons.layers_clear_rounded,
                    ),
                    pMenuItem(
                      value: 'purge',
                      label: l10n.archivePurgeMenu,
                      icon: Icons.delete_forever_rounded,
                      danger: true,
                    ),
                    pMenuItem(
                      value: 'delete',
                      label: l10n.pastilleArcDeleteMenu,
                      icon: Icons.delete_outline_rounded,
                      danger: true,
                    ),
                  ],
                  child: const PRoundIcon(
                    icon: Icons.more_horiz_rounded,
                    size: 38,
                  ),
                ),
              if (videos.isNotEmpty && !demo) ...[
                const SizedBox(width: 8),
                PButton(
                  icon: Icons.play_arrow_rounded,
                  tooltip: l10n.pastilleArcPlayFeed,
                  kind: PButtonKind.cream,
                  height: 38,
                  iconSize: 20,
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
              ],
              if (videos.isNotEmpty) ...[
                const SizedBox(width: 8),
                PButton(
                  label: l10n.pastilleArcDownloadAll(videos.length),
                  icon: Icons.download_rounded,
                  kind: PButtonKind.butter,
                  height: 38,
                  padH: 16,
                  iconSize: 15,
                  onTap: state.isBatchDownloading
                      ? null
                      : () async {
                          pNotice(
                            context,
                            l10n.pastilleArcDownloadingFolder(videos.length),
                          );
                          await n.downloadBatch(videos, limit: videos.length);
                        },
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: videos.isEmpty
              ? Center(
                  child: Text(
                    l10n.pastilleArcEmptyCollection,
                    style: pBody(color: pMuted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                  itemCount: videos.length,
                  itemBuilder: (context, i) {
                    final v = videos[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: PastilleVideoRow(
                        item: v,
                        isSelected: state.selectedIds.contains(v.id),
                        onToggleSelect: () => n.toggleSelection(v.id),
                        onDownload: () async {
                          pNotice(
                            context,
                            l10n.pastilleArcDownloadStarted(v.id),
                          );
                          await n.downloadBatch([v], limit: 1);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
