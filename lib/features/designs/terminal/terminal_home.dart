import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/ui/layout/pane_layout_provider.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/core/ui/widgets/resizable_width_pane.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/features/downloader/presentation/views/inspector/collapsed_inspector_rail.dart';
import 'package:modern_downloader/features/downloader/presentation/views/inspector/download_inspector.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_list.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_search_field.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/toolbar/download_more_actions_menu.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/toolbar/failed_downloads_badge.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/download_item_context_menu.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'terminal_widgets.dart';

/// Terminal's home (mockup Terminal.dc.html): `status --live` with segmented
/// bars, then `ls --recent`, the whole library as a table.
class TerminalHome extends ConsumerWidget {
  const TerminalHome({super.key});

  // Pause what runs; with nothing running, resume what is paused.
  static Future<void> _pauseOrResume(WidgetRef ref) async {
    final notifier = ref.read(downloadListProvider.notifier);
    final items = ref.read(downloadListProvider).valueOrNull ?? const [];
    if (items.any(isActiveDownload)) {
      await notifier.pauseAllActive();
      return;
    }
    for (final i in items) {
      if (i.status == DownloadStatus.paused) {
        unawaited(notifier.resumeDownload(i.id));
      }
    }
  }

  // `c` cancels the first line of `status --live`, as the hint says.
  static void _cancelFirst(WidgetRef ref) {
    final items = ref.read(downloadListProvider).valueOrNull ?? const [];
    for (final i in items) {
      if (isActiveDownload(i) || i.status == DownloadStatus.paused) {
        ref.read(downloadListProvider.notifier).cancelDownload(i.id);
        return;
      }
    }
  }

  static void _openFolder(WidgetRef ref) {
    final folder = ref.read(settingsProvider).outputFolder;
    if (folder.isNotEmpty && Platform.isWindows) {
      Process.run('explorer', [folder]);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The page's width: the window less the chrome's sidebar (221 px).
    final narrow = MediaQuery.sizeOf(context).width - 221 < 900;
    if (narrow) _listenNarrowInspector(context, ref);
    return TerminalPageKeys(
      bindings: {
        'p': () => _pauseOrResume(ref),
        'c': () => _cancelFirst(ref),
        'o': () => _openFolder(ref),
        'r': () => ref.read(downloadListProvider.notifier).retryAllFailed(),
      },
      child: Focus(
        autofocus: true,
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                DownloadSearchFocus.request,
            const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
                DownloadSearchFocus.request,
          },
          child: Row(
            children: [
              const Expanded(child: _HomeScroll()),
              if (!narrow) const _Inspector(),
            ],
          ),
        ),
      ),
    );
  }

  // Narrow windows: the inspector opens as a sheet, like today's library.
  void _listenNarrowInspector(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(selectedDownloadIdProvider, (previous, next) {
      if (next == null || next == previous) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.86,
          child: DownloadInspector(downloadId: next),
        ),
      ).whenComplete(() {
        if (ref.read(selectedDownloadIdProvider) == next) {
          ref.read(selectedDownloadIdProvider.notifier).state = null;
        }
      });
    });
  }
}

/// Today's resizable, collapsible inspector pane.
class _Inspector extends ConsumerWidget {
  const _Inspector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedDownloadIdProvider);
    if (selectedId == null) return const SizedBox.shrink();
    final layout = ref.watch(paneLayoutProvider);
    final pane = ref.read(paneLayoutProvider.notifier);
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: colors.border)),
      ),
      child: ResizableWidthPane(
        width: layout.visibleInspectorWidth,
        minWidth: PaneLayout.inspectorRail,
        maxWidth: PaneLayout.inspectorMax,
        contentMinWidth: PaneLayout.inspectorMin,
        resizeFrom: PaneResizeFrom.leading,
        onWidthChanged: pane.setInspectorWidth,
        onDragActive: (active) =>
            ref.read(paneResizeActiveProvider.notifier).state = active,
        onResizeEnd: () {
          ref.read(paneResizeActiveProvider.notifier).state = false;
          pane.commitInspectorDrag();
          pane.persist();
        },
        onToggleCollapse: () {
          pane.toggleInspectorCollapsed();
          pane.persist();
        },
        child: layout.inspectorCollapsed
            ? CollapsedInspectorRail(
                onExpand: () {
                  pane.expandInspector();
                  pane.persist();
                },
              )
            : ColoredBox(
                color: colors.surface,
                child: DownloadInspector(downloadId: selectedId),
              ),
      ),
    );
  }
}

class _HomeScroll extends ConsumerWidget {
  const _HomeScroll();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(downloadViewModeProvider);
    const pad = EdgeInsets.symmetric(horizontal: 18);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TPrompt('status', l10n.terminalFlagLive),
                const SizedBox(height: 12),
                const _LiveBlock(),
                const SizedBox(height: 12),
                THints([
                  ('p', l10n.pause.toLowerCase()),
                  ('c', l10n.cancel.toLowerCase()),
                  ('o', l10n.openFolder.toLowerCase()),
                ]),
              ],
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
          sliver: SliverToBoxAdapter(child: _ListHeader()),
        ),
        if (mode == DownloadViewMode.list) ...[
          const SliverPadding(
            padding: pad,
            sliver: SliverToBoxAdapter(child: _TableHead()),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 24),
            sliver: _Table(),
          ),
        ] else
          // Folders and cards: today's views, they follow the palette.
          SliverFillRemaining(
            hasScrollBody: true,
            child: DownloadList(key: OnboardingTargets.creatorList),
          ),
      ],
    );
  }
}

// ── status --live ───────────────────────────────────────────────────────────

/// The only part of the page that rebuilds on progress ticks.
class _LiveBlock extends ConsumerWidget {
  const _LiveBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final live = [
      ...liveActiveItems(
        items,
        (id) => ref.watch(downloadRuntimeItemProvider(id)),
      ),
      for (final i in items)
        if (i.status == DownloadStatus.paused) i,
    ];
    return TPanel(
      child: live.isEmpty
          ? Text(
              '# ${l10n.designNothingActive}',
              style: tm(colors.textSecondary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, item) in live.take(4).indexed) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _LiveLine(item: item),
                ],
              ],
            ),
    );
  }
}

class _LiveLine extends StatelessWidget {
  const _LiveLine({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final paused = item.status == DownloadStatus.paused;
    final speed = parseSpeed(item.speed);
    final phase = livePhase(item, speed);
    final s = formatSpeed(l10n, speed);
    final percent = (item.progress * 100).clamp(0, 100).round();
    final detail = paused
        ? l10n.statusPaused.toLowerCase()
        : phase != null
        ? livePhaseLabel(l10n, phase).toLowerCase()
        : [
            '${s.value} ${s.unit}'.trim(),
            if (item.eta.isNotEmpty) 'eta ${etaLabel(l10n, item.eta)}',
          ].join(' ');
    const right = 200.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: paused ? '‖ ' : '▶ ',
                      style: tm(paused ? colors.warning : colors.primary),
                    ),
                    TextSpan(
                      text: TitleCleanerService.clean(
                        item.title ?? item.request.url,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tm(colors.textPrimary),
              ),
            ),
            const SizedBox(width: 18),
            SizedBox(
              width: right,
              child: Text(
                formatLabelOf(item).toLowerCase(),
                style: tm(colors.textDisabled),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TSeg(
                value: item.progress,
                color: paused ? colors.warning : null,
              ),
            ),
            const SizedBox(width: 18),
            SizedBox(
              width: right,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$percent% ', style: tm(colors.primary)),
                    TextSpan(text: detail),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tm(colors.textPrimary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── ls --recent ─────────────────────────────────────────────────────────────

/// `$ tapload ls --recent` and, on the right, search, failed badge, sort and
/// view, more actions (queue controls live there and on `p`).
class _ListHeader extends ConsumerWidget {
  const _ListHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(downloadStatusFilterProvider);
    final source = ref.watch(downloadSourceFilterProvider);
    final query = ref.watch(downloadSearchQueryProvider);
    final flags = [
      switch (status) {
        DownloadStatusFilter.all => l10n.terminalFlagRecent,
        DownloadStatusFilter.active => '--${l10n.terminalActive}',
        DownloadStatusFilter.completed => '--${l10n.terminalDone}',
        DownloadStatusFilter.failed => '--${l10n.terminalFailed}',
      },
      if (source != null) '--source ${source.toLowerCase()}',
      if (query.isNotEmpty) '--grep "$query"',
    ].join(' ');
    return KeyedSubtree(
      key: OnboardingTargets.topBar,
      child: Row(
        children: [
          Expanded(child: TPrompt('ls', flags)),
          const SizedBox(width: 12),
          SizedBox(
            width: 240,
            height: 30,
            child: DownloadSearchField(
              onChanged: (v) =>
                  ref.read(downloadSearchQueryProvider.notifier).state = v,
            ),
          ),
          const SizedBox(width: 8),
          const FailedDownloadsBadge(compact: true),
          const _SortMenu(),
          const SizedBox(width: 4),
          const DownloadMoreActionsMenu(
            showQueueActions: true,
            showRetryFailed: false,
          ),
        ],
      ),
    );
  }
}

/// Today's whole sort and view menu, drawn as a terminal button.
class _SortMenu extends ConsumerWidget {
  const _SortMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final sort = ref.watch(downloadSortProvider);
    final mode = ref.watch(downloadViewModeProvider);
    final sortName = switch (sort) {
      DownloadSort.dateDesc || DownloadSort.dateAsc => l10n.sortFieldDate,
      DownloadSort.nameAsc || DownloadSort.nameDesc => l10n.sortFieldName,
      DownloadSort.sizeDesc || DownloadSort.sizeAsc => l10n.sortFieldSize,
      DownloadSort.countDesc || DownloadSort.countAsc => l10n.sortVideoCount,
    };
    final ascending = switch (sort) {
      DownloadSort.dateAsc ||
      DownloadSort.nameAsc ||
      DownloadSort.sizeAsc ||
      DownloadSort.countAsc => true,
      _ => false,
    };
    void toggle(DownloadSort a, DownloadSort b) =>
        ref.read(downloadSortProvider.notifier).state = sort == a ? b : a;
    void setMode(DownloadViewMode m) {
      final opened = ref.read(openedCreatorFolderKeyProvider);
      if (mode == DownloadViewMode.folders &&
          opened != null &&
          m != DownloadViewMode.folders) {
        ref.read(folderContentsViewModeProvider.notifier).state = m;
        return;
      }
      ref.read(downloadViewModeProvider.notifier).state = m;
      if (m != DownloadViewMode.folders) {
        ref.read(openedCreatorFolderKeyProvider.notifier).state = null;
        if (sort == DownloadSort.countDesc || sort == DownloadSort.countAsc) {
          ref.read(downloadSortProvider.notifier).state = DownloadSort.dateDesc;
        }
      }
    }

    PopupMenuItem<int> item(int v, String label, bool on, VoidCallback tap) =>
        PopupMenuItem<int>(
          value: v,
          height: 36,
          onTap: tap,
          child: Text(
            '${on ? '[x]' : '[ ]'} $label',
            style: tm(on ? colors.primary : colors.textPrimary),
          ),
        );
    final isDate =
        sort == DownloadSort.dateDesc || sort == DownloadSort.dateAsc;
    final isName =
        sort == DownloadSort.nameAsc || sort == DownloadSort.nameDesc;
    final isSize =
        sort == DownloadSort.sizeDesc || sort == DownloadSort.sizeAsc;
    final isCount =
        sort == DownloadSort.countDesc || sort == DownloadSort.countAsc;
    return PopupMenuButton<int>(
      tooltip: l10n.sortAndView,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.zero,
      ),
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          enabled: false,
          height: 30,
          child: Text(
            '## ${l10n.sortBy.toLowerCase()}',
            style: tm(colors.textDisabled),
          ),
        ),
        item(
          0,
          l10n.sortFieldDate,
          isDate,
          () => toggle(DownloadSort.dateDesc, DownloadSort.dateAsc),
        ),
        item(
          1,
          l10n.sortFieldName,
          isName,
          () => toggle(DownloadSort.nameAsc, DownloadSort.nameDesc),
        ),
        item(
          2,
          l10n.sortFieldSize,
          isSize,
          () => toggle(DownloadSort.sizeDesc, DownloadSort.sizeAsc),
        ),
        if (mode == DownloadViewMode.folders)
          item(
            3,
            l10n.sortVideoCount,
            isCount,
            () => toggle(DownloadSort.countDesc, DownloadSort.countAsc),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<int>(
          enabled: false,
          height: 30,
          child: Text(
            '## ${l10n.viewMode.toLowerCase()}',
            style: tm(colors.textDisabled),
          ),
        ),
        item(
          4,
          l10n.viewList,
          mode == DownloadViewMode.list,
          () => setMode(DownloadViewMode.list),
        ),
        item(
          5,
          l10n.viewDetailed,
          mode == DownloadViewMode.detailed,
          () => setMode(DownloadViewMode.detailed),
        ),
        item(
          6,
          l10n.viewFolders,
          mode == DownloadViewMode.folders,
          () => setMode(DownloadViewMode.folders),
        ),
      ],
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
        ),
        child: Text(
          '${sortName.toLowerCase()} ${ascending ? '↑' : '↓'}',
          style: tm(colors.textSecondary),
        ),
      ),
    );
  }
}

const _colState = 70.0;
const _colSource = 120.0;
const _colRight = 110.0;
const _gap = 14.0;

class _TableHead extends StatelessWidget {
  const _TableHead();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = tm(AppColors.of(context).textDisabled);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 7, 12, 7),
      child: Row(
        children: [
          SizedBox(
            width: _colState,
            child: Text(l10n.terminalColState, style: style),
          ),
          const SizedBox(width: _gap),
          Expanded(child: Text(l10n.terminalColTitle, style: style)),
          const SizedBox(width: _gap),
          SizedBox(
            width: _colSource,
            child: Text(l10n.terminalColSource, style: style),
          ),
          const SizedBox(width: _gap),
          SizedBox(
            width: _colRight,
            child: Text(
              l10n.terminalColFormat,
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class _Table extends ConsumerWidget {
  const _Table();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final ids = ref.watch(filteredDownloadIdListProvider).ids;
    final query = ref.watch(downloadSearchQueryProvider);
    final status = ref.watch(downloadStatusFilterProvider);
    final source = ref.watch(downloadSourceFilterProvider);
    final sort = ref.watch(downloadSortProvider);
    if (ids.isEmpty) {
      final filtered =
          query.isNotEmpty ||
          status != DownloadStatusFilter.all ||
          source != null;
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 0),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  '# ${filtered ? l10n.noResults : l10n.designLibraryEmpty}',
                  style: tm(colors.textSecondary),
                ),
              ),
              if (filtered) ...[
                const SizedBox(width: 12),
                TLink(
                  label: l10n.clearSearchAndFilters.toLowerCase(),
                  onTap: () {
                    ref.read(downloadSearchQueryProvider.notifier).state = '';
                    ref.read(downloadSourceFilterProvider.notifier).state =
                        null;
                    ref.read(downloadStatusFilterProvider.notifier).state =
                        DownloadStatusFilter.all;
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }
    // Same rule as today's list: drag maps onto the stored order only for
    // the whole library, oldest first.
    final reorder =
        query.isEmpty &&
        status == DownloadStatusFilter.all &&
        source == null &&
        sort == DownloadSort.dateAsc &&
        ids.length <= 50;
    if (reorder) {
      return SliverReorderableList(
        key: OnboardingTargets.creatorList,
        itemCount: ids.length,
        onReorderItem: (a, b) =>
            ref.read(downloadListProvider.notifier).reorder(a, b),
        itemBuilder: (context, index) => ReorderableDragStartListener(
          key: ValueKey(ids[index]),
          index: index,
          child: _Line(id: ids[index]),
        ),
      );
    }
    return SliverList(
      key: OnboardingTargets.creatorList,
      delegate: SliverChildBuilderDelegate(
        (context, index) => _Line(key: ValueKey(ids[index]), id: ids[index]),
        childCount: ids.length,
      ),
    );
  }
}

/// One `ok | title | source size | format` line; watches only its own item.
class _Line extends ConsumerWidget {
  const _Line({super.key, required this.id});

  final String id;

  void _play(WidgetRef ref, DownloadItem item) {
    final path = item.filePath;
    if (path != null && File(path).existsSync()) {
      ref.read(mediaPlayerProvider.notifier).openFile(path);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(downloadItemByIdProvider(id));
    if (item == null) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final selected = ref.watch(
      selectedDownloadIdProvider.select((s) => s == id),
    );
    final failed =
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.canceled;
    final waiting =
        item.status == DownloadStatus.queued ||
        item.status == DownloadStatus.paused;
    final busy = isActiveDownload(item);
    final (state, stateColor) = failed
        ? (l10n.terminalStateErr, colors.error)
        : waiting
        ? (l10n.terminalStateWait, colors.warning)
        : busy
        ? (l10n.terminalStateRun, colors.primary)
        : (l10n.terminalStateOk, colors.primary);
    final size = bytesOf(item);
    final sourceText = [
      item.source.toLowerCase(),
      if (size > 0 && !failed) compactBytes(size),
    ].where((s) => s.isNotEmpty).join(' ');
    final right = busy
        ? '${(item.progress * 100).round()}%'
        : (failed || waiting)
        ? '—'
        : formatLabelOf(item).toLowerCase();
    final error = (item.error ?? '').split('\n').first.trim();
    return DownloadItemContextMenu(
      item: item,
      child: THoverLine(
        selected: selected,
        onTap: () => ref.read(selectedDownloadIdProvider.notifier).state =
            selected ? null : item.id,
        onDoubleTap: () => _play(ref, item),
        child: Row(
          children: [
            SizedBox(
              width: _colState,
              child: Text(state, style: tm(stateColor)),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      TitleCleanerService.clean(item.title ?? item.request.url),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tm(colors.textPrimary, weight: FontWeight.w600),
                    ),
                  ),
                  if (failed) ...[
                    if (error.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          error,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tm(colors.error),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    TLink(
                      label: 'r ${l10n.retry.toLowerCase()}',
                      onTap: () => ref
                          .read(downloadListProvider.notifier)
                          .retryDownload(item),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: _gap),
            SizedBox(
              width: _colSource,
              child: Text(
                sourceText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tm(colors.textSecondary),
              ),
            ),
            const SizedBox(width: _gap),
            SizedBox(
              width: _colRight,
              child: Text(
                right,
                textAlign: TextAlign.right,
                style: tm(colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `ls -h` sizes: 2.1G, 38M, 812K.
String compactBytes(int bytes) {
  const k = 1024.0;
  String f(double v, String u) =>
      '${v >= 10 ? v.round() : v.toStringAsFixed(1)}$u';
  if (bytes >= k * k * k) return f(bytes / (k * k * k), 'G');
  if (bytes >= k * k) return f(bytes / (k * k), 'M');
  if (bytes >= k) return f(bytes / k, 'K');
  return '${bytes}B';
}
