import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/services/local_server_service.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/utils/browser_launch.dart';
import 'package:tapload/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/archive/presentation/views/modes/tiktok_feed_view.dart';
import 'package:tapload/l10n/l10n_ext.dart';
import 'package:tapload/showcase/showcase_mode.dart';

import 'porcelaine_widgets.dart';

/// The archive's pieces Porcelaine used to borrow from today's views, drawn
/// in its language: the video card, the filter pane, an opened collection,
/// the suggestions review and the import hub.

// ── Video card ─────────────────────────────────────────────────────────────

/// A TikTok video as a Porcelaine row: the checkbox, the still (bundled
/// art for the demo), the date and id, its tags, then copy / open / download
/// (shown on hover or keyboard focus).
class PArchiveVideoCard extends StatefulWidget {
  const PArchiveVideoCard({
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
  State<PArchiveVideoCard> createState() => _PArchiveVideoCardState();
}

class _PArchiveVideoCardState extends State<PArchiveVideoCard> {
  bool _hover = false;
  bool _focus = false;

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
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final item = widget.item;
    final demo = item.id.startsWith('demo-')
        ? int.tryParse(item.id.substring(5))
        : null;
    final demoIndex = demo == null ? null : (demo - 1) % 4;
    final shown = _hover || _focus;
    Widget tag(String label, IconData icon, Color tint) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Color.alphaBlend(tint.withValues(alpha: 0.1), colors.surface),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: tint),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pBody(
                colors,
                size: 11.5,
                weight: FontWeight.w600,
                color: tint,
              ).copyWith(height: 1.3),
            ),
          ),
        ],
      ),
    );
    final still = demoIndex != null
        ? PThumb(
            url: 'assets/showcase/${_demoArt[demoIndex]}',
            seed: item.id,
            width: 56,
            height: 56,
          )
        : Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.inputBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              size: 22,
              color: colors.textSecondary,
            ),
          );
    return Focus(
      skipTraversal: true,
      onFocusChange: (v) => setState(() => _focus = v),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: pMotion(context, 220),
          curve: pEase,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Color.alphaBlend(
                    colors.primary.withValues(alpha: 0.05),
                    colors.surface,
                  )
                : colors.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              if (widget.isSelected)
                BoxShadow(color: colors.primary, spreadRadius: 1.5),
              ...pCardShadow(colors, up: _hover),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onToggleSelect,
              borderRadius: BorderRadius.circular(18),
              hoverColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 12, 10),
                child: Row(
                  children: [
                    Semantics(
                      checked: widget.isSelected,
                      child: PCheckBox(on: widget.isSelected, hover: _hover),
                    ),
                    const SizedBox(width: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: still,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  demoIndex == null
                                      ? l10n.archiveVideoTitle(_date(item.date))
                                      : l10n.porcelaineDemoExcerpt(
                                          _demoFilms[demoIndex],
                                          (demo! - 1) ~/ 4 + 1,
                                        ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: pBody(colors, weight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: SelectableText(
                                  item.id,
                                  maxLines: 1,
                                  style: pMono(
                                    colors,
                                    size: 11.5,
                                    color: colors.textDisabled,
                                  ),
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
                                tag(
                                  l10n.porcelaineArchiveFavorite,
                                  Icons.bookmark_rounded,
                                  pPink,
                                ),
                              if (item.isLiked)
                                tag(
                                  l10n.porcelaineArchiveLike,
                                  Icons.favorite_rounded,
                                  colors.error,
                                ),
                              if (item.collectionName != null)
                                tag(
                                  item.collectionName!,
                                  Icons.folder_rounded,
                                  colors.primary,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedOpacity(
                      opacity: shown ? 1 : 0,
                      duration: pMotion(context, 140),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PIconBtn(
                            icon: Icons.copy_rounded,
                            tooltip: l10n.porcelaineCopyLink,
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: item.url));
                              pNotice(context, l10n.porcelaineLinkCopied);
                            },
                          ),
                          const SizedBox(width: 4),
                          PIconBtn(
                            icon: Icons.open_in_new_rounded,
                            tooltip: l10n.porcelaineOpenInBrowser,
                            onTap: () async {
                              // Demo links point nowhere on purpose.
                              if (Uri.tryParse(
                                    item.url,
                                  )?.host.endsWith('.invalid') ==
                                  true) {
                                return;
                              }
                              await openInBrowser(item.url);
                            },
                          ),
                          const SizedBox(width: 8),
                          PBtn(
                            label: l10n.archiveMobileDownload,
                            icon: Icons.download_rounded,
                            kind: PBtnKind.accent,
                            height: 34,
                            fontSize: 12.5,
                            padding: 13,
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

// ── Filter pane ────────────────────────────────────────────────────────────

/// Type, year and collection filters beside the video list.
class PArchiveFilterPane extends ConsumerStatefulWidget {
  const PArchiveFilterPane({super.key});

  @override
  ConsumerState<PArchiveFilterPane> createState() => _PArchiveFilterPaneState();
}

class _PArchiveFilterPaneState extends ConsumerState<PArchiveFilterPane> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final state = ref.watch(tikTokArchiveProvider);
    final catalog = state.catalog;
    if (catalog == null) return const SizedBox.shrink();
    final filter = state.filter;
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final years = catalog.yearCounts.keys.toList()..sort((a, b) => b - a);
    final q = _search.text.toLowerCase();
    final collections = [
      for (final c in catalog.collections)
        if (c.name.toLowerCase().contains(q)) c,
    ];
    Widget label(String text, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: pBody(
                colors,
                size: 12.5,
                weight: FontWeight.w600,
                color: colors.textDisabled,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
    Widget clear(VoidCallback onTap) => PBtn(
      label: l10n.porcelaineClear,
      kind: PBtnKind.ghost,
      height: 30,
      fontSize: 12.5,
      padding: 10,
      onTap: onTap,
    );
    return Container(
      width: 264,
      decoration: BoxDecoration(
        border: BorderDirectional(
          end: BorderSide(color: colors.textPrimary.withValues(alpha: 0.06)),
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 0),
            sliver: SliverList.list(
              children: [
                PHead(
                  icon: Icons.tune_rounded,
                  label: l10n.archiveMobileFilters,
                  tint: pSlate,
                  bottom: 0,
                  trailing: Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: clear(() {
                        notifier.selectYear(null);
                        notifier.selectCollection(null);
                        notifier.setStatusFilter(TikTokStatusFilter.all);
                        notifier.clearSelection();
                      }),
                    ),
                  ),
                ),
                label(l10n.archiveMobileType),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FittedBox(
                    child: PSegmented<TikTokStatusFilter>(
                      options: [
                        (TikTokStatusFilter.all, l10n.archiveMobileFilterAll),
                        (
                          TikTokStatusFilter.favoritesOnly,
                          l10n.archiveMobileFilterFavorites,
                        ),
                        (
                          TikTokStatusFilter.likesOnly,
                          l10n.archiveMobileFilterLikes,
                        ),
                      ],
                      value: filter.statusFilter,
                      onChanged: notifier.setStatusFilter,
                    ),
                  ),
                ),
                label(l10n.archiveMobileYear),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    PPill(
                      label: l10n.archiveMobileAllYears,
                      selected: filter.selectedYear == null,
                      onTap: () => notifier.selectYear(null),
                    ),
                    for (final y in years)
                      PPill(
                        label: '$y',
                        trailing: '${catalog.yearCounts[y]}',
                        selected: filter.selectedYear == y,
                        onTap: () => notifier.selectYear(
                          filter.selectedYear == y ? null : y,
                        ),
                      ),
                  ],
                ),
                label(
                  '${l10n.porcelaineArchiveCollectionsTab} · ${catalog.collections.length}',
                  trailing: filter.selectedCollection == null
                      ? null
                      : clear(() => notifier.selectCollection(null)),
                ),
                PSearchField(
                  controller: _search,
                  hint: l10n.archiveCollSearch,
                  onChanged: (_) => setState(() {}),
                  height: 38,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 10, 16),
            sliver: SliverList.builder(
              itemCount: collections.length,
              itemBuilder: (context, i) {
                final c = collections[i];
                final on = filter.selectedCollection == c.name;
                return _PaneRow(
                  label: c.name,
                  count: c.videoCount,
                  selected: on,
                  onTap: () => notifier.selectCollection(on ? null : c.name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PaneRow extends StatefulWidget {
  const _PaneRow({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PaneRow> createState() => _PaneRowState();
}

class _PaneRowState extends State<_PaneRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final on = widget.selected;
    final fg = on ? colors.primary : colors.textPrimary;
    return Semantics(
      selected: on,
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          color: on
              ? colors.primary.withValues(alpha: 0.08)
              : colors.textPrimary.withValues(alpha: _hover ? 0.04 : 0),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    on ? Icons.folder_rounded : Icons.folder_outlined,
                    size: 17,
                    color: on ? colors.primary : colors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: pBody(
                        colors,
                        size: 13,
                        weight: on ? FontWeight.w600 : FontWeight.w400,
                        color: fg,
                      ),
                    ),
                  ),
                  Text('${widget.count}', style: pMono(colors, size: 11.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── An opened collection ───────────────────────────────────────────────────

const pLikedFolder = 'Vidéos Likées';
const pUnsortedFolder = 'Favoris non classés';

/// One collection's videos: back, its name and count, the « … » menu
/// (remove its videos, delete them for good, delete the collection), play
/// them in the vertical feed, download them all.
class PCollectionDetail extends ConsumerWidget {
  const PCollectionDetail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final state = ref.watch(tikTokArchiveProvider);
    final videos = ref.watch(filteredTikTokVideosProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final key = state.filter.selectedCollection!;
    final name =
        state.catalog?.collections
            .where((c) => c.id == key || (c.id == null && c.name == key))
            .firstOrNull
            ?.name ??
        key;
    final special = name == pLikedFolder || name == pUnsortedFolder;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    Future<void> menu(BuildContext button) async {
      final action = await pShowMenu<String>(button, [
        // An empty collection can still be deleted; there is nothing to
        // remove from it or purge.
        if (videos.isNotEmpty) ...[
          pMenuItem(
            button,
            value: 'reset',
            label: l10n.archiveCollReset,
            icon: Icons.remove_circle_outline_rounded,
          ),
          pMenuItem(
            button,
            value: 'purge',
            label: l10n.archivePurgeMenu,
            icon: Icons.delete_forever_rounded,
            danger: true,
          ),
        ],
        pMenuItem(
          button,
          value: 'delete',
          label: l10n.archiveCollDelete,
          icon: Icons.delete_outline_rounded,
          danger: true,
        ),
      ]);
      if (action == null || !context.mounted) return;
      switch (action) {
        case 'reset':
          if (await pConfirm(
            context,
            title: l10n.archiveCollResetTitle,
            body: l10n.archiveCollResetBody(videos.length, name),
            action: l10n.archiveCollResetConfirm,
          )) {
            await notifier.resetCollectionToUnclassified(key);
            if (context.mounted)
              pNotice(context, l10n.archiveCollResetDone(name));
          }
        case 'purge':
          await pConfirmPurge(context, ref, {key});
        case 'delete':
          if (await pConfirm(
            context,
            title: l10n.archiveCollDelete,
            body: l10n.archiveCollDeleteBody(videos.length, name),
            action: l10n.archiveCollDeleteConfirm,
            icon: Icons.delete_forever_rounded,
          )) {
            await notifier.deleteCollection(key);
            if (context.mounted) {
              pNotice(context, l10n.archiveCollDeleteDone(name));
            }
          }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: [
              PBtn(
                label: l10n.porcelaineAllCollections,
                icon: rtl
                    ? Icons.arrow_forward_rounded
                    : Icons.arrow_back_rounded,
                height: 36,
                onTap: () => notifier.selectCollection(null),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: pDisp(24, color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.archiveMobileVideoCount(videos.length),
                style: pMono(colors),
              ),
              const Spacer(),
              if (!special)
                Builder(
                  builder: (button) => PIconBtn(
                    icon: Icons.more_horiz_rounded,
                    tooltip: l10n.moreActions,
                    size: 36,
                    onTap: () => menu(button),
                  ),
                ),
              if (videos.isNotEmpty && !ref.read(showcaseModeProvider)) ...[
                const SizedBox(width: 6),
                PIconBtn(
                  icon: Icons.play_arrow_rounded,
                  tooltip: l10n.archiveMobilePlayFullscreen,
                  size: 36,
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (dialog) => Dialog.fullscreen(
                      child: TikTokFeedView(
                        videos: videos,
                        onClose: () => Navigator.of(dialog).pop(),
                      ),
                    ),
                  ),
                ),
              ],
              if (videos.isNotEmpty) ...[
                const SizedBox(width: 8),
                PBtn(
                  label: l10n.archiveCollDownloadAll(videos.length),
                  icon: Icons.download_rounded,
                  kind: PBtnKind.accent,
                  height: 36,
                  onTap: state.isBatchDownloading
                      ? null
                      : () async {
                          pNotice(
                            context,
                            l10n.porcelaineDownloadingFolder(videos.length),
                          );
                          await notifier.downloadBatch(
                            videos,
                            limit: videos.length,
                          );
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
                    l10n.porcelaineCollectionEmpty,
                    style: pBody(colors, color: colors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                  itemCount: videos.length,
                  itemBuilder: (context, i) {
                    final v = videos[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: PArchiveVideoCard(
                        item: v,
                        isSelected: state.selectedIds.contains(v.id),
                        onToggleSelect: () => notifier.toggleSelection(v.id),
                        onDownload: () async {
                          pNotice(context, l10n.archiveMobileVideoAdded);
                          await notifier.downloadBatch([v], limit: 1);
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

/// Same confirmation and purge as today's collections view: what goes,
/// what is kept because another collection holds it. True when purged.
Future<bool> pConfirmPurge(
  BuildContext context,
  WidgetRef ref,
  Set<String> keys,
) async {
  if (keys.isEmpty) return false;
  final l10n = context.l10n;
  final colors = AppColors.of(context);
  final notifier = ref.read(tikTokArchiveProvider.notifier);
  final preview = notifier.purgePreview(keys);
  final ok = await pConfirm(
    context,
    title: l10n.archivePurgeTitle(keys.length),
    body: l10n.archivePurgeBody(preview.videos, preview.files),
    content: preview.keptShared > 0
        ? Text(
            l10n.archivePurgeKept(preview.keptShared),
            style: pBody(colors, size: 13, color: colors.textSecondary),
          )
        : null,
    action: l10n.delete,
    icon: Icons.delete_forever_rounded,
  );
  if (!ok) return false;
  final result = await notifier.purgeCollections(keys);
  if (context.mounted) {
    pNotice(
      context,
      l10n.archivePurgeDone(result.filesDeleted, result.videosRemoved),
    );
  }
  return true;
}

// ── Sorting suggestions ────────────────────────────────────────────────────

/// « n propositions de classement à vérifier » above the collection cards.
class PSuggestionsBanner extends ConsumerStatefulWidget {
  const PSuggestionsBanner({super.key});

  @override
  ConsumerState<PSuggestionsBanner> createState() => _PSuggestionsBannerState();
}

class _PSuggestionsBannerState extends ConsumerState<PSuggestionsBanner> {
  bool _applying = false;

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
      if (mounted)
        pNotice(context, l10n.porcelaineSuggestionsDone(picked.length));
    } catch (error) {
      if (mounted) {
        pNotice(context, l10n.porcelaineSuggestionsFailed('$error'));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final suggestions = ref.watch(
      tikTokArchiveProvider.select((s) => s.catalog?.suggestions ?? const []),
    );
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PCard(
        lift: false,
        radius: 22,
        padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  colors.primary.withValues(alpha: 0.12),
                  Colors.white,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.fact_check_outlined,
                size: 16,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.porcelaineSuggestionsBanner(suggestions.length),
                style: pBody(colors, weight: FontWeight.w600),
              ),
            ),
            PBtn(
              label: _applying
                  ? l10n.porcelaineSuggestionsApplying
                  : l10n.porcelaineSuggestionsReview(suggestions.length),
              icon: Icons.fact_check_outlined,
              height: 36,
              onTap: _applying ? null : () => _review(suggestions),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionsDialog extends StatefulWidget {
  const _SuggestionsDialog({required this.suggestions});

  final List<TikTokCollectionSuggestion> suggestions;

  @override
  State<_SuggestionsDialog> createState() => _SuggestionsDialogState();
}

class _SuggestionsDialogState extends State<_SuggestionsDialog> {
  late final Map<String, List<TikTokCollectionSuggestion>> _groups;
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
    _groups = {
      for (final n in names)
        n: grouped[n]!..sort((a, b) => a.videoId.compareTo(b.videoId)),
    };
    _picked = {for (final s in widget.suggestions) s.key};
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    String reason(String r) => switch (r) {
      'partial_snapshot' => l10n.porcelaineSuggestionPartial,
      'date_proximity' => l10n.porcelaineSuggestionDate,
      'imported_mapping' => l10n.porcelaineSuggestionMapping,
      _ => l10n.porcelaineSuggestionOther,
    };
    final height = (MediaQuery.sizeOf(context).height * 0.65).clamp(
      280.0,
      620.0,
    );
    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SizedBox(
        width: 650,
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.porcelaineSuggestionsTitle,
                      style: pDisp(22, color: colors.textPrimary),
                    ),
                  ),
                  PIconBtn(
                    icon: Icons.close_rounded,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.porcelaineSuggestionsHint,
                style: pBody(colors, size: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final e in _groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                        child: Text(
                          '${e.key} · ${e.value.length}',
                          style: pBody(colors, weight: FontWeight.w700),
                        ),
                      ),
                      for (final s in e.value)
                        Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() {
                              if (!_picked.remove(s.key)) _picked.add(s.key);
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Semantics(
                                    checked: _picked.contains(s.key),
                                    child: PCheckBox(
                                      on: _picked.contains(s.key),
                                      hover: false,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.porcelaineSuggestionVideo(
                                            s.videoId,
                                          ),
                                          style: pBody(colors, size: 13.5),
                                        ),
                                        Text(
                                          reason(s.reason),
                                          style: pBody(
                                            colors,
                                            size: 12,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.porcelaineSuggestionsSelected(_picked.length),
                      style: pMono(colors),
                    ),
                  ),
                  PBtn(
                    label: l10n.porcelaineSuggestionsApply,
                    icon: Icons.check_rounded,
                    kind: PBtnKind.accent,
                    onTap: _picked.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(Set.of(_picked)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Import hub ─────────────────────────────────────────────────────────────

/// Import and browser sync for the archive (today's hub), as Porcelaine
/// widgets: the archive at a glance, the import card, the sync card.
class PArchiveHub extends ConsumerWidget {
  const PArchiveHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final state = ref.watch(tikTokArchiveProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final showcase = ref.watch(showcaseModeProvider);
    final connected =
        !showcase && ref.watch(extensionConnectedClientsProvider) > 0;
    final syncing = state.syncStatus == TikTokSyncStatus.waiting;
    final catalog = state.catalog;

    Widget notice(String message, Color tint) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(tint.withValues(alpha: 0.1), colors.surface),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: pBody(colors, size: 13, color: tint)),
    );

    Widget card({
      required IconData icon,
      required Color tint,
      required String title,
      required String body,
      required List<Widget> children,
    }) => PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PHead(icon: icon, label: title, tint: tint, bottom: 10),
          Text(body, style: pBody(colors, color: colors.textSecondary)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.archiveDeskIntro,
                textAlign: TextAlign.center,
                style: pBody(colors, color: colors.textSecondary),
              ),
              const SizedBox(height: 22),
              if (state.hasCatalog && catalog != null) ...[
                PCard(
                  padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${l10n.archiveMobileVideoCount(catalog.videos.length)} · '
                          '${l10n.archiveHubCollections(catalog.collections.length)}',
                          style: pBody(colors, weight: FontWeight.w600),
                        ),
                      ),
                      PBtn(
                        label: l10n.archiveHubOpen,
                        kind: PBtnKind.dark,
                        height: 36,
                        onTap: () =>
                            notifier.setViewMode(TikTokViewMode.collections),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (state.errorMessage != null) ...[
                notice(state.errorMessage!, colors.error),
                const SizedBox(height: 16),
              ],
              card(
                icon: Icons.folder_open_outlined,
                tint: colors.primary,
                title: l10n.archiveDeskImportTitle,
                body: l10n.archiveDeskImportBody,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: PBtn(
                      label: l10n.archiveDeskPickJson,
                      icon: Icons.file_open_outlined,
                      kind: PBtnKind.accent,
                      height: 42,
                      onTap: showcase ? null : notifier.pickAndImportFile,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              card(
                icon: Icons.sync_rounded,
                tint: pGreen,
                title: l10n.archiveDeskSyncTitle,
                body: connected
                    ? l10n.archiveDeskSyncConnected
                    : l10n.archiveDeskSyncDisconnected,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: PBtn(
                      label: syncing
                          ? l10n.archiveDeskSyncing
                          : l10n.archiveDeskSyncAction,
                      icon: Icons.sync_rounded,
                      height: 42,
                      onTap: !showcase && connected && !syncing
                          ? notifier.triggerExtensionSync
                          : null,
                    ),
                  ),
                  if (syncing) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        color: colors.primary,
                        backgroundColor: pTrack(colors),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.archiveMobileSyncWaiting,
                      style: pBody(
                        colors,
                        size: 12.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ] else if (state.syncMessage != null) ...[
                    const SizedBox(height: 14),
                    notice(state.syncMessage!, switch (state.syncStatus) {
                      TikTokSyncStatus.failed => colors.error,
                      TikTokSyncStatus.partial => colors.warning,
                      _ => pGreen,
                    }),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.archiveDeskSyncManual,
                textAlign: TextAlign.center,
                style: pBody(colors, size: 12.5, color: colors.textDisabled),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
