import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/ui/layout/pane_layout_provider.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/core/ui/widgets/resizable_width_pane.dart';
import 'package:modern_downloader/core/utils/format_utils.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/add_download_dialog.dart';
import 'package:modern_downloader/features/downloader/presentation/views/inspector/collapsed_inspector_rail.dart';
import 'package:modern_downloader/features/downloader/presentation/views/inspector/download_inspector.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_list.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_search_field.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/toolbar/download_more_actions_menu.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/download_item_context_menu.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'terminal_states.dart';
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

  // `c` cancels the first line of `status --live` (running ones first, then
  // paused, as _LiveBlock lists them).
  static void _cancelFirst(WidgetRef ref) {
    final items = ref.read(downloadListProvider).valueOrNull ?? const [];
    final first =
        items.where(isActiveDownload).firstOrNull ??
        items.where((i) => i.status == DownloadStatus.paused).firstOrNull;
    if (first != null) {
      ref.read(downloadListProvider.notifier).cancelDownload(first.id);
    }
  }

  static void _openFolder(WidgetRef ref) {
    final folder = ref.read(settingsProvider).outputFolder;
    if (folder.isNotEmpty && Platform.isWindows) {
      Process.run('explorer', [folder]);
    }
  }

  // `r`: reload a library that failed to load, else retry the failures.
  static void _retry(WidgetRef ref) {
    final notifier = ref.read(downloadListProvider.notifier);
    if (ref.read(downloadListProvider).hasError) {
      notifier.refreshList();
    } else {
      notifier.retryAllFailed();
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
        'r': () => _retry(ref),
        'n': () => _newDownload(context),
        'x': () => _clearFilters(ref),
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
        const SliverToBoxAdapter(child: _FailedBanner()),
        if (mode == DownloadViewMode.list) ...[
          SliverPadding(
            padding: pad,
            sliver: SliverToBoxAdapter(
              // The tour measures a box, so the table's head carries it.
              child: _TableHead(key: OnboardingTargets.creatorList),
            ),
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

/// The only part of the page that rebuilds on progress ticks. A download that
/// just finished stays a few seconds as a typed `✓ done` line.
class _LiveBlock extends ConsumerStatefulWidget {
  const _LiveBlock();

  @override
  ConsumerState<_LiveBlock> createState() => _LiveBlockState();
}

class _LiveBlockState extends ConsumerState<_LiveBlock> {
  static const _hold = Duration(seconds: 4);

  final Map<String, DateTime> _seenActiveAt = {};
  final List<CompletionSummary> _finished = [];
  final Map<String, Timer> _timers = {};

  @override
  void initState() {
    super.initState();
    ref.listenManual(downloadListProvider, _onList, fireImmediately: true);
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }

  void _onList(
    AsyncValue<List<DownloadItem>>? previous,
    AsyncValue<List<DownloadItem>> next,
  ) {
    final after = next.valueOrNull;
    if (after == null) return;
    final now = DateTime.now();
    for (final item in after) {
      if (isActiveDownload(item)) _seenActiveAt.putIfAbsent(item.id, () => now);
    }
    final before = previous?.valueOrNull;
    if (before == null) return;
    final wasActive = {
      for (final item in before)
        if (isActiveDownload(item)) item.id,
    };
    for (final item in after) {
      if (item.status != DownloadStatus.completed ||
          !wasActive.contains(item.id)) {
        continue;
      }
      final started = _seenActiveAt.remove(item.id) ?? now;
      final summary = summarizeCompletion(
        item,
        firstBytesAt: started,
        now: now,
        title: titleOf(item),
      );
      setState(() {
        _finished
          ..removeWhere((s) => s.id == item.id)
          ..insert(0, summary);
        if (_finished.length > 2) {
          _timers.remove(_finished.removeLast().id)?.cancel();
        }
      });
      _timers.remove(item.id)?.cancel();
      _timers[item.id] = Timer(_hold, () {
        _timers.remove(item.id);
        if (mounted) {
          setState(() => _finished.removeWhere((s) => s.id == item.id));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
    final lines = <Widget>[
      for (final s in _finished)
        _DoneLine(key: ValueKey('done ${s.id}'), summary: s),
      for (final item in live.take(4)) _LiveLine(item: item),
    ];
    return TPanel(
      child: lines.isEmpty
          ? Text(
              '# ${l10n.designNothingActive}',
              style: tm(colors.textSecondary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, line) in lines.indexed) ...[
                  if (i > 0) const SizedBox(height: 14),
                  line,
                ],
              ],
            ),
    );
  }
}

/// `✓ done <title>` typed in once, over a bar that fills its last cells.
class _DoneLine extends StatelessWidget {
  const _DoneLine({super.key, required this.summary});

  final CompletionSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final took = durationLabel(l10n, summary.duration);
    final size = FormatUtils.parseBytes(summary.sizeText);
    const right = 200.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // An icon, not a ✓ glyph: the mono font has none.
            Icon(Icons.check, size: 15, color: colors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: TTyped(
                '${l10n.terminalFinished}  ${summary.title}',
                style: tm(colors.primary, weight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 18),
            SizedBox(
              width: right,
              child: Text(
                size <= 0
                    ? took
                    : l10n.terminalFinishedIn(compactBytes(size), took),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tm(colors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Expanded(child: _FillingSeg()),
            const SizedBox(width: 18),
            SizedBox(
              width: right,
              child: Text('100%', style: tm(colors.primary)),
            ),
          ],
        ),
      ],
    );
  }
}

/// The bar's last cells fill in steps (0.85 -> 1) in a third of a second.
class _FillingSeg extends StatefulWidget {
  const _FillingSeg();

  @override
  State<_FillingSeg> createState() => _FillingSegState();
}

class _FillingSegState extends State<_FillingSeg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctl.value = 1;
    } else {
      _ctl.forward();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) =>
          TSeg(value: 0.85 + 0.15 * (_ctl.value * 6).ceil() / 6),
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
                    TextSpan(text: titleOf(item)),
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
            height: 30,
            // Narrow windows leave the `$ tapload ls` prompt some room.
            width: MediaQuery.sizeOf(context).width < 900 ? 170 : 240,
            child: DownloadSearchField(
              onChanged: (v) =>
                  ref.read(downloadSearchQueryProvider.notifier).state = v,
            ),
          ),
          const SizedBox(width: 8),
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
  const _TableHead({super.key});

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

/// The table body: loading lines, a load error, the empty library, no match,
/// or the lines, whose first ones print in once when they first show up.
class _Table extends ConsumerStatefulWidget {
  const _Table();

  @override
  ConsumerState<_Table> createState() => _TableState();
}

class _TableState extends ConsumerState<_Table>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 34 * (TEntrance.lines + 1)),
    );
  }

  bool _printed = false;

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  // Once, the first time there are lines: they stay hidden for this frame
  // and print in from the next one.
  void _printOnce() {
    if (_printed) return;
    _printed = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entrance.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(downloadListProvider);
    final ids = ref.watch(filteredDownloadIdListProvider).ids;
    final query = ref.watch(downloadSearchQueryProvider);
    final status = ref.watch(downloadStatusFilterProvider);
    final source = ref.watch(downloadSourceFilterProvider);
    final sort = ref.watch(downloadSortProvider);
    if (list.hasError && !list.hasValue) {
      return SliverToBoxAdapter(child: _LoadError(error: list.error));
    }
    if (!list.hasValue) {
      return const SliverToBoxAdapter(child: _Loading());
    }
    if (ids.isEmpty) {
      final filtered =
          query.isNotEmpty ||
          status != DownloadStatusFilter.all ||
          source != null;
      return SliverToBoxAdapter(
        child: filtered ? _NoMatch(query: query) : const _EmptyLibrary(),
      );
    }
    _printOnce();
    Widget line(int index) => TPrinted(
      index: index,
      child: _Line(id: ids[index]),
    );
    // Same rule as today's list: drag maps onto the stored order only for
    // the whole library, oldest first.
    final reorder =
        query.isEmpty &&
        status == DownloadStatusFilter.all &&
        source == null &&
        sort == DownloadSort.dateAsc &&
        ids.length <= 50;
    return TEntrance(
      animation: _entrance,
      child: reorder
          ? SliverReorderableList(
              itemCount: ids.length,
              onReorderItem: (a, b) =>
                  ref.read(downloadListProvider.notifier).reorder(a, b),
              itemBuilder: (context, index) => ReorderableDragStartListener(
                key: ValueKey(ids[index]),
                index: index,
                child: line(index),
              ),
            )
          : SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    KeyedSubtree(key: ValueKey(ids[index]), child: line(index)),
                childCount: ids.length,
              ),
            ),
    );
  }
}

/// `# lecture de la bibliothèque…▮` over skeleton lines shaped like _Line.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 12, 6),
          child: TTyped(
            '# ${context.l10n.terminalLoading}',
            style: tm(colors.textSecondary),
            cursor: true,
          ),
        ),
        const TSkeletonLines(
          leading: [_colState],
          trailing: [_colSource, _colRight],
        ),
      ],
    );
  }
}

/// The library could not be read: why, and `r réessayer`.
class _LoadError extends ConsumerWidget {
  const _LoadError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final reason = downloadErrorReason(error?.toString());
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TPanel(
        accentLeft: colors.error,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${l10n.terminalStateErr}  ',
                    style: tm(colors.error, weight: FontWeight.w700),
                  ),
                  TextSpan(text: l10n.terminalLoadError),
                ],
              ),
              style: tm(colors.textPrimary, weight: FontWeight.w700),
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '# $reason',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tm(colors.textSecondary),
              ),
            ],
            const SizedBox(height: 14),
            TButton(
              keyHint: 'r',
              label: l10n.retry,
              kind: TButtonKind.primary,
              onTap: () =>
                  ref.read(downloadListProvider.notifier).refreshList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// First launch: an empty drive, a typed headline, one action.
class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('total 0', style: tm(colors.textDisabled)),
        const SizedBox(height: 8),
        TTyped(
          '## ${l10n.terminalEmptyTitle}',
          style: tm(colors.primary, size: 16, weight: FontWeight.w700),
          cursor: true,
        ),
        const SizedBox(height: 10),
        Text(
          l10n.terminalEmptyBody,
          style: tm(colors.textSecondary).copyWith(height: 1.5),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TButton(
              keyHint: 'n',
              label: l10n.newDownload,
              kind: TButtonKind.primary,
              onTap: () => _newDownload(context),
            ),
            THints([('›', l10n.terminalCommandHint)]),
          ],
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TPanel(
        padding: const EdgeInsets.all(22),
        child: LayoutBuilder(
          builder: (context, c) => c.maxWidth < 560
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TEmptyVisual(),
                    const SizedBox(height: 16),
                    text,
                  ],
                )
              : Row(
                  children: [
                    const TEmptyVisual(),
                    const SizedBox(width: 28),
                    Expanded(child: text),
                  ],
                ),
        ),
      ),
    );
  }
}

/// A search or filters that match nothing: say so, show the query, reset.
class _NoMatch extends ConsumerWidget {
  const _NoMatch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TPanel(
        accentLeft: colors.warning,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TTyped(
              query.isEmpty
                  ? '# ${l10n.terminalNoMatchFilters}'
                  : l10n.terminalNoMatch(query),
              style: tm(colors.textPrimary, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('# ${l10n.noResults}', style: tm(colors.textSecondary)),
            const SizedBox(height: 14),
            TButton(
              keyHint: 'x',
              label: l10n.clearSearchAndFilters,
              onTap: () => _clearFilters(ref),
            ),
          ],
        ),
      ),
    );
  }
}

/// `err  n téléchargements en échec   [r Relancer les échecs (n)]`, from
/// two failures up (one is retried on its own line).
class _FailedBanner extends ConsumerWidget {
  const _FailedBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final failed = ref.watch(
      downloadListProvider.select(
        (s) => (s.valueOrNull ?? const <DownloadItem>[])
            .where((i) => i.status == DownloadStatus.failed)
            .length,
      ),
    );
    if (failed < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: TPanel(
        accentLeft: colors.error,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Text(
              l10n.terminalStateErr,
              style: tm(colors.error, weight: FontWeight.w700),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                l10n.terminalFailedSummary(failed),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tm(colors.textPrimary),
              ),
            ),
            const SizedBox(width: 12),
            TButton(
              keyHint: 'r',
              label: '${l10n.retryFailedAction} ($failed)',
              kind: TButtonKind.danger,
              height: 28,
              onTap: () =>
                  ref.read(downloadListProvider.notifier).retryAllFailed(),
            ),
          ],
        ),
      ),
    );
  }
}

/// One `ok | title | source size | format` line; watches only its own item.
class _Line extends ConsumerWidget {
  const _Line({required this.id});

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
    final error = downloadErrorReason(item.error);
    final title = Text(
      titleOf(item),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tm(colors.textPrimary, weight: FontWeight.w600),
    );
    final retry = TLink(
      label: 'r ${l10n.retry.toLowerCase()}',
      onTap: () => ref.read(downloadListProvider.notifier).retryDownload(item),
    );
    // Narrow pages give the reason its own line under the title.
    final stacked = failed && MediaQuery.sizeOf(context).width < 1121;
    final line = THoverLine(
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
            child: stacked
                ? title
                : Row(
                    children: [
                      Flexible(child: title),
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
                        retry,
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
    );
    if (!stacked) return DownloadItemContextMenu(item: item, child: line);
    return DownloadItemContextMenu(
      item: item,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line,
          Padding(
            padding: const EdgeInsets.fromLTRB(14 + _colState + _gap, 0, 12, 6),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    '└ ${error.isEmpty ? l10n.terminalStateErr : error}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tm(colors.error),
                  ),
                ),
                const SizedBox(width: 8),
                retry,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _newDownload(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const AddDownloadDialog(),
);

void _clearFilters(WidgetRef ref) {
  ref.read(downloadSearchQueryProvider.notifier).state = '';
  ref.read(downloadSourceFilterProvider.notifier).state = null;
  ref.read(downloadStatusFilterProvider.notifier).state =
      DownloadStatusFilter.all;
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
