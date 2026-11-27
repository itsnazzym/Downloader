import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/utils/browser_launch.dart';
import 'package:tapload/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/archive/presentation/views/modes/tiktok_feed_view.dart';
import 'package:tapload/l10n/l10n_ext.dart';
import 'package:tapload/showcase/showcase_mode.dart';

import 'nocturne_widgets.dart';

/// The archive's pieces in Nocturne's language: filter pane, video card,
/// an opened collection, the dialogs they ask through.

void nocturneNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
}

/// A Nocturne confirmation: title, body, cancel and a danger action.
Future<bool> nocturneConfirm(
  BuildContext context, {
  required String title,
  required Widget body,
  required String action,
  IconData icon = Icons.delete_outline_rounded,
}) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: body,
      actions: [
        NocturneButton(
          label: l10n.cancel,
          kind: NocturneButtonKind.ghost,
          onTap: () => Navigator.of(ctx).pop(false),
        ),
        NocturneButton(
          label: action,
          icon: icon,
          kind: NocturneButtonKind.danger,
          onTap: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Confirms, then deletes the collections' own videos and their files;
/// videos shared with a kept collection stay. True once done.
Future<bool> nocturnePurge(
  BuildContext context,
  WidgetRef ref,
  Set<String> keys,
) async {
  if (keys.isEmpty) return false;
  final l10n = context.l10n;
  final c = AppColors.of(context);
  final notifier = ref.read(tikTokArchiveProvider.notifier);
  final preview = notifier.purgePreview(keys);
  final ok = await nocturneConfirm(
    context,
    title: l10n.archivePurgeTitle(keys.length),
    action: l10n.delete,
    icon: Icons.delete_forever_rounded,
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.archivePurgeBody(preview.videos, preview.files)),
        if (preview.keptShared > 0) ...[
          const SizedBox(height: 12),
          Text(
            l10n.archivePurgeKept(preview.keptShared),
            style: nocturneText(c, size: 12.5, color: c.textSecondary),
          ),
        ],
      ],
    ),
  );
  if (!ok || !context.mounted) return false;
  final r = await notifier.purgeCollections(keys);
  if (context.mounted) {
    nocturneNotice(
      context,
      l10n.archivePurgeDone(r.filesDeleted, r.videosRemoved),
    );
  }
  return true;
}

Future<void> nocturneDeleteCollection(
  BuildContext context,
  WidgetRef ref,
  String key,
  String name,
  int count,
) async {
  final l10n = context.l10n;
  if (!await nocturneConfirm(
    context,
    title: l10n.archiveCollDelete,
    body: Text(l10n.archiveCollDeleteBody(count, name)),
    action: l10n.archiveCollDeleteConfirm,
    icon: Icons.delete_forever_rounded,
  )) {
    return;
  }
  await ref.read(tikTokArchiveProvider.notifier).deleteCollection(key);
  if (context.mounted)
    nocturneNotice(context, l10n.archiveCollDeleteDone(name));
}

Future<void> nocturneClearArchive(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  if (!await nocturneConfirm(
    context,
    title: l10n.archiveCollClear,
    body: Text(l10n.archiveCollClearBody),
    action: l10n.archiveCollClearConfirm,
    icon: Icons.delete_sweep_outlined,
  )) {
    return;
  }
  await ref.read(tikTokArchiveProvider.notifier).clearCatalog();
  if (context.mounted) nocturneNotice(context, l10n.archiveCollClearDone);
}

// ── Filter pane ─────────────────────────────────────────────────────────────

/// Type, year and collection filters in a Nocturne column.
class NocturneFilterPane extends ConsumerStatefulWidget {
  const NocturneFilterPane({super.key});

  @override
  ConsumerState<NocturneFilterPane> createState() => _NocturneFilterPaneState();
}

class _NocturneFilterPaneState extends ConsumerState<NocturneFilterPane> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final state = ref.watch(tikTokArchiveProvider);
    final catalog = state.catalog;
    if (catalog == null) return const SizedBox.shrink();
    final filter = state.filter;
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final years = catalog.yearCounts.keys.toList()..sort((a, b) => b - a);
    final query = _search.text.toLowerCase();
    final collections = [
      for (final col in catalog.collections)
        if (col.name.toLowerCase().contains(query)) col,
    ];
    Widget heading(String text, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: nocturneText(
                c,
                size: 12,
                weight: FontWeight.w700,
                color: c.textDisabled,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
    Widget chip(String label, bool on, VoidCallback onTap) =>
        _Chip(label: label, selected: on, onTap: onTap);
    return SizedBox(
      width: 272,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 10, 0),
            child: Row(
              children: [
                Expanded(child: NocturneTitle(l10n.archiveMobileFilters)),
                NocturneButton(
                  label: l10n.archiveMobileReset,
                  kind: NocturneButtonKind.ghost,
                  height: 30,
                  padding: 10,
                  fontSize: 12.5,
                  onTap: () {
                    notifier.selectYear(null);
                    notifier.selectCollection(null);
                    notifier.setStatusFilter(TikTokStatusFilter.all);
                    notifier.clearSelection();
                  },
                ),
              ],
            ),
          ),
          heading(l10n.archiveMobileType),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (f, label) in [
                  (TikTokStatusFilter.all, l10n.archiveMobileFilterAll),
                  (
                    TikTokStatusFilter.favoritesOnly,
                    l10n.archiveMobileFilterFavorites,
                  ),
                  (TikTokStatusFilter.likesOnly, l10n.archiveMobileFilterLikes),
                ])
                  chip(
                    label,
                    filter.statusFilter == f,
                    () => notifier.setStatusFilter(f),
                  ),
              ],
            ),
          ),
          heading(l10n.archiveMobileYear),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                chip(
                  l10n.archiveMobileAllYears,
                  filter.selectedYear == null,
                  () => notifier.selectYear(null),
                ),
                for (final y in years)
                  chip(
                    '$y · ${catalog.yearCounts[y]}',
                    filter.selectedYear == y,
                    () => notifier.selectYear(
                      filter.selectedYear == y ? null : y,
                    ),
                  ),
              ],
            ),
          ),
          heading(
            '${l10n.nocturneTabCollections} · ${catalog.collections.length}',
            trailing: filter.selectedCollection == null
                ? null
                : NocturneButton(
                    label: l10n.nocturneClear,
                    kind: NocturneButtonKind.ghost,
                    height: 26,
                    padding: 8,
                    fontSize: 12,
                    onTap: () => notifier.selectCollection(null),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: NocturneSearchBox(
              controller: _search,
              hint: l10n.archiveCollSearch,
              onChanged: (_) => setState(() {}),
              height: 36,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              itemCount: collections.length,
              itemBuilder: (context, i) {
                final col = collections[i];
                final on = filter.selectedCollection == col.name;
                return _PaneRow(
                  label: col.name,
                  count: col.videoCount,
                  selected: on,
                  onTap: () => notifier.selectCollection(on ? null : col.name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatefulWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final on = widget.selected;
    return Semantics(
      button: true,
      selected: on,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hover = v),
        borderRadius: BorderRadius.circular(10),
        hoverColor: Colors.transparent,
        child: AnimatedContainer(
          duration: nocturneMotion(context, 160),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: on
                ? c.surfaceHighlight
                : (_hover
                      ? c.primary.withValues(alpha: 0.06)
                      : c.inputBackground),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: on
                  ? c.primary.withValues(alpha: 0.5)
                  : c.primary.withValues(alpha: 0.08),
            ),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              widget.label,
              style: nocturneText(
                c,
                size: 12.5,
                weight: FontWeight.w600,
                color: on ? c.textPrimary : c.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaneRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: selected ? c.surfaceHighlight : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        hoverColor: c.primary.withValues(alpha: 0.06),
        child: SizedBox(
          height: 38,
          child: Row(
            children: [
              const SizedBox(width: 10),
              NocturneMonogram(text: label, size: 24, radius: 8, fontSize: 9.5),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: nocturneText(
                    c,
                    size: 13,
                    weight: FontWeight.w600,
                    color: selected ? c.textPrimary : c.textSecondary,
                  ),
                ),
              ),
              Text(
                '$count',
                style: nocturneMono(
                  c,
                  size: 11.5,
                  color: selected ? c.primary : c.textDisabled,
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dark search well with a clear button.
class NocturneSearchBox extends StatelessWidget {
  const NocturneSearchBox({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.height = 40,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: height,
      padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
      decoration: BoxDecoration(
        color: c.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 17, color: c.textDisabled),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: nocturneText(c, size: 13),
              cursorColor: c.primary,
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: hint,
                hintStyle: nocturneText(c, size: 13, color: c.textDisabled),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            NocturneIconButton(
              icon: Icons.close_rounded,
              tooltip: context.l10n.nocturneClear,
              ghost: true,
              size: height - 8,
              onTap: () {
                controller.clear();
                onChanged('');
              },
            ),
        ],
      ),
    );
  }
}

// ── Video card ──────────────────────────────────────────────────────────────

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

/// One archived video: check, still, date title and id, its marks, then
/// copy, open and download on hover or focus.
class NocturneVideoCard extends StatefulWidget {
  const NocturneVideoCard({
    super.key,
    required this.item,
    required this.selected,
    required this.onToggle,
    required this.onDownload,
  });

  final TikTokArchiveItem item;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onDownload;

  @override
  State<NocturneVideoCard> createState() => _NocturneVideoCardState();
}

class _NocturneVideoCardState extends State<NocturneVideoCard> {
  bool _hover = false;
  bool _focus = false;

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final item = widget.item;
    final on = widget.selected;
    final number = item.id.startsWith('demo-')
        ? int.tryParse(item.id.substring(5))
        : null;
    final demo = number == null ? null : (number - 1) % 4;
    final show = _hover || _focus;
    final radius = BorderRadius.circular(16);
    return AnimatedContainer(
      duration: nocturneMotion(context, 180),
      curve: nocturneEase,
      decoration: BoxDecoration(
        color: on || _hover ? c.surface : c.surface.withValues(alpha: 0.55),
        borderRadius: radius,
        border: Border.all(
          color: on
              ? c.primary.withValues(alpha: 0.6)
              : c.primary.withValues(alpha: _hover ? 0.14 : 0.06),
          width: on ? 1.5 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onToggle,
          onHover: (v) => setState(() => _hover = v),
          onFocusChange: (v) => setState(() => _focus = v),
          borderRadius: radius,
          hoverColor: Colors.transparent,
          focusColor: c.primary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Semantics(
                  checked: on,
                  child: NocturneCheck(checked: on),
                ),
                const SizedBox(width: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox.square(
                    dimension: 44,
                    child: demo != null
                        ? Image.asset(
                            'assets/showcase/${_demoArt[demo]}',
                            fit: BoxFit.cover,
                            semanticLabel: _demoFilms[demo],
                            errorBuilder: (_, _, _) => _still(c),
                          )
                        : _still(c),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              demo == null
                                  ? l10n.archiveVideoTitle(_date(item.date))
                                  : l10n.nocturneDemoClip(
                                      _demoFilms[demo],
                                      (number! - 1) ~/ 4 + 1,
                                    ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: nocturneText(c, weight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SelectableText(
                            item.id,
                            maxLines: 1,
                            style: nocturneMono(
                              c,
                              size: 11,
                              color: c.textDisabled,
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
                            _Mark(
                              icon: Icons.bookmark_rounded,
                              label: l10n.nocturneBadgeFavorite,
                            ),
                          if (item.isLiked)
                            _Mark(
                              icon: Icons.favorite_rounded,
                              label: l10n.nocturneBadgeLike,
                            ),
                          if (item.collectionName != null)
                            _Mark(
                              icon: Icons.folder_rounded,
                              label: item.collectionName!,
                              accent: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: show ? 1 : 0,
                  duration: nocturneMotion(context, 150),
                  child: IgnorePointer(
                    ignoring: !show,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NocturneIconButton(
                          icon: Icons.copy_rounded,
                          tooltip: l10n.copyUrl,
                          ghost: true,
                          size: 32,
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: item.url));
                            nocturneNotice(context, l10n.nocturneLinkCopied);
                          },
                        ),
                        NocturneIconButton(
                          icon: Icons.open_in_new_rounded,
                          tooltip: l10n.nocturneOpenInBrowser,
                          ghost: true,
                          size: 32,
                          onTap: () {
                            // Demo links point at a reserved domain.
                            if (Uri.tryParse(
                                  item.url,
                                )?.host.endsWith('.invalid') ==
                                true) {
                              return;
                            }
                            openInBrowser(item.url);
                          },
                        ),
                        const SizedBox(width: 4),
                        NocturneButton(
                          label: l10n.designDownload,
                          icon: Icons.download_rounded,
                          kind: NocturneButtonKind.primary,
                          height: 32,
                          radius: 10,
                          padding: 12,
                          fontSize: 12.5,
                          onTap: widget.onDownload,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _still(AppColors c) => DecoratedBox(
    decoration: BoxDecoration(gradient: nocturneTint(widget.item.id.hashCode)),
    child: Icon(
      Icons.play_arrow_rounded,
      size: 20,
      color: c.textPrimary.withValues(alpha: 0.7),
    ),
  );
}

class _Mark extends StatelessWidget {
  const _Mark({required this.icon, required this.label, this.accent = false});

  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = accent ? c.primary : c.textSecondary;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: accent ? c.primary.withValues(alpha: 0.1) : c.surfaceHighlight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: nocturneText(
                c,
                size: 11,
                weight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── An opened collection ────────────────────────────────────────────────────

const nocturneLikedFolder = 'Vidéos Likées';
const nocturneUnsortedFolder = 'Favoris non classés';

/// The videos of one collection: back, its name and count, play them all
/// vertically, download them all, and reset, purge or delete it.
class NocturneCollectionDetail extends ConsumerWidget {
  const NocturneCollectionDetail({
    super.key,
    required this.collectionKey,
    required this.name,
  });

  final String collectionKey;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final state = ref.watch(tikTokArchiveProvider);
    final videos = ref.watch(filteredTikTokVideosProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final showcase = ref.watch(showcaseModeProvider);
    final real = name != nocturneLikedFolder && name != nocturneUnsortedFolder;
    final canEdit = videos.isNotEmpty && real;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final title = Row(
              children: [
                NocturneButton(
                  label: l10n.nocturneAllCollections,
                  icon: Directionality.of(context) == TextDirection.rtl
                      ? Icons.arrow_forward_rounded
                      : Icons.arrow_back_rounded,
                  kind: NocturneButtonKind.ghost,
                  onTap: () => notifier.selectCollection(null),
                ),
                const SizedBox(width: 10),
                NocturneMonogram(text: name, size: 34),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: nocturneText(c, size: 17, weight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.nocturneCountVideos(videos.length),
                  style: nocturneMono(c, color: c.textDisabled),
                ),
              ],
            );
            final actions = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canEdit)
                  PopupMenuButton<String>(
                    tooltip: l10n.moreActions,
                    onSelected: (v) async {
                      switch (v) {
                        case 'reset':
                          if (await nocturneConfirm(
                            context,
                            title: l10n.archiveCollResetTitle,
                            body: Text(
                              l10n.archiveCollResetBody(videos.length, name),
                            ),
                            action: l10n.archiveCollResetConfirm,
                            icon: Icons.layers_clear_outlined,
                          )) {
                            await notifier.resetCollectionToUnclassified(
                              collectionKey,
                            );
                            if (context.mounted) {
                              nocturneNotice(
                                context,
                                l10n.archiveCollResetDone(name),
                              );
                            }
                          }
                        case 'purge':
                          if (context.mounted) {
                            await nocturnePurge(context, ref, {collectionKey});
                          }
                        case 'delete':
                          if (context.mounted) {
                            await nocturneDeleteCollection(
                              context,
                              ref,
                              collectionKey,
                              name,
                              videos.length,
                            );
                          }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'reset',
                        child: Text(
                          l10n.archiveCollReset,
                          style: nocturneText(c, size: 13),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'purge',
                        child: Text(
                          l10n.archivePurgeMenu,
                          style: nocturneText(c, size: 13, color: c.error),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          l10n.archiveCollDelete,
                          style: nocturneText(c, size: 13, color: c.error),
                        ),
                      ),
                    ],
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c.surfaceHighlight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        size: 18,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                if (videos.isNotEmpty && !showcase) ...[
                  const SizedBox(width: 8),
                  NocturneIconButton(
                    icon: Icons.play_arrow_rounded,
                    tooltip: l10n.archiveMobilePlayFullscreen,
                    size: 38,
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
                  NocturneButton(
                    label: l10n.archiveCollDownloadAll(videos.length),
                    icon: Icons.download_rounded,
                    kind: NocturneButtonKind.primary,
                    onTap: state.isBatchDownloading
                        ? null
                        : () async {
                            nocturneNotice(
                              context,
                              l10n.nocturneFolderDownloading(videos.length),
                            );
                            await notifier.downloadBatch(
                              videos,
                              limit: videos.length,
                            );
                          },
                  ),
                ],
              ],
            );
            // Narrow windows: the actions go under the title.
            if (box.maxWidth < 820) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 10), actions],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 12),
                actions,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Expanded(
          child: videos.isEmpty
              ? Center(
                  child: Text(
                    l10n.archiveMobileNoVideos,
                    style: nocturneText(c, color: c.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: videos.length,
                  itemBuilder: (context, i) {
                    final v = videos[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: NocturneVideoCard(
                        item: v,
                        selected: state.selectedIds.contains(v.id),
                        onToggle: () => notifier.toggleSelection(v.id),
                        onDownload: () async {
                          nocturneNotice(
                            context,
                            l10n.nocturneDownloadStarted(v.id),
                          );
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

// ── Classification suggestions ──────────────────────────────────────────────

/// "N suggestions to review", and the review that applies the checked ones.
class NocturneSuggestionsBanner extends ConsumerStatefulWidget {
  const NocturneSuggestionsBanner({super.key, required this.suggestions});

  final List<TikTokCollectionSuggestion> suggestions;

  @override
  ConsumerState<NocturneSuggestionsBanner> createState() =>
      _NocturneSuggestionsBannerState();
}

class _NocturneSuggestionsBannerState
    extends ConsumerState<NocturneSuggestionsBanner> {
  bool _applying = false;

  Future<void> _review() async {
    final l10n = context.l10n;
    final picked = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _SuggestionsDialog(suggestions: widget.suggestions),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() => _applying = true);
    try {
      await ref
          .read(tikTokArchiveProvider.notifier)
          .applyCollectionSuggestions(picked);
      if (mounted) {
        nocturneNotice(context, l10n.nocturneSuggestionsApplied(picked.length));
      }
    } catch (error) {
      if (mounted) {
        nocturneNotice(context, l10n.nocturneSuggestionsFailed('$error'));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final n = widget.suggestions.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.fact_check_outlined, size: 18, color: c.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.nocturneSuggestionsCount(n),
              style: nocturneText(c, weight: FontWeight.w600),
            ),
          ),
          NocturneButton(
            label: _applying
                ? l10n.nocturneSuggestionsApplying
                : l10n.nocturneSuggestionsReview(n),
            onTap: _applying ? null : _review,
          ),
        ],
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
    _picked = widget.suggestions.map((s) => s.key).toSet();
  }

  String _reason(BuildContext context, String reason) {
    final l10n = context.l10n;
    return switch (reason) {
      'partial_snapshot' => l10n.nocturneReasonPartial,
      'date_proximity' => l10n.nocturneReasonDate,
      'imported_mapping' => l10n.nocturneReasonImported,
      _ => l10n.nocturneReasonOther,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final height = (MediaQuery.sizeOf(context).height * 0.65)
        .clamp(280.0, 620.0)
        .toDouble();
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l10n.nocturneSuggestionsTitle)),
          NocturneIconButton(
            icon: Icons.close_rounded,
            tooltip: l10n.nocturneClose,
            ghost: true,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.nocturneSuggestionsHint,
              style: nocturneText(c, size: 12.5, color: c.textSecondary),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  for (final MapEntry(key: name, value: items)
                      in _groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                      child: Text(
                        '$name · ${items.length}',
                        style: nocturneText(c, weight: FontWeight.w700),
                      ),
                    ),
                    for (final s in items)
                      InkWell(
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
                                child: NocturneCheck(
                                  checked: _picked.contains(s.key),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.nocturneSuggestionVideo(s.videoId),
                                      style: nocturneText(c, size: 13),
                                    ),
                                    Text(
                                      _reason(context, s.reason),
                                      style: nocturneText(
                                        c,
                                        size: 12,
                                        color: c.textDisabled,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            l10n.nocturneSuggestionsSelected(_picked.length),
            style: nocturneText(c, size: 12.5, color: c.textSecondary),
          ),
        ),
        NocturneButton(
          label: l10n.nocturneSuggestionsApply,
          icon: Icons.check_rounded,
          kind: NocturneButtonKind.primary,
          onTap: _picked.isEmpty
              ? null
              : () => Navigator.of(context).pop(Set<String>.of(_picked)),
        ),
      ],
    );
  }
}
