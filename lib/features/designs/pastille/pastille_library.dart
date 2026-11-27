import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/core/theme/app_palette.dart';
import 'package:tapload/core/theme/theme_presets.dart';
import 'package:tapload/core/ui/layout/pane_layout_provider.dart';
import 'package:tapload/core/ui/shell/shell_strips.dart'
    show libraryFilterSources;
import 'package:tapload/core/ui/widgets/resizable_width_pane.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:tapload/features/downloader/presentation/views/widgets/download_search_field.dart'
    show DownloadSearchFocus;
import 'package:tapload/features/onboarding/presentation/onboarding_targets.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import 'pastille_inspector.dart';
import 'pastille_kit.dart';
import 'pastille_parts.dart';

/// The library's own toolbar, filters and inspector pane, drawn in Pastille
/// instead of today's top bar, badges, capsule and menus: same actions
/// (search, retry failed, pause / start the queue, sort and view, refresh
/// and clean-up), same confirmations and toasts.

// ── Filters ─────────────────────────────────────────────────────────────────

/// Status and source filters as a Pastille capsule of tabs with counts.
class PastilleLibraryFilters extends ConsumerWidget {
  const PastilleLibraryFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final counts = ref.watch(downloadLibraryCountsProvider);
    final status = ref.watch(downloadStatusFilterProvider);
    final source = ref.watch(downloadSourceFilterProvider);
    final adult = ref.watch(
      settingsProvider.select((s) => s.adultSitesEnabled),
    );
    void setStatus(DownloadStatusFilter value) {
      ref.read(downloadStatusFilterProvider.notifier).state = value;
      ref.read(downloadSourceFilterProvider.notifier).state = null;
    }

    void setSource(String value) {
      ref.read(downloadSourceFilterProvider.notifier).state = value;
      ref.read(downloadStatusFilterProvider.notifier).state =
          DownloadStatusFilter.all;
    }

    String n(String label, int? count) =>
        count == null || count == 0 ? label : '$label  $count';
    return KeyedSubtree(
      key: OnboardingTargets.library,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: PSeg(
          page: true,
          height: 34,
          padH: 14,
          fontSize: 13,
          items: [
            PSegItem(
              n(l10n.allDownloads, counts.total),
              status == DownloadStatusFilter.all && source == null,
              () => setStatus(DownloadStatusFilter.all),
            ),
            PSegItem(
              n(l10n.sidebarActive, counts.active),
              status == DownloadStatusFilter.active,
              () => setStatus(DownloadStatusFilter.active),
            ),
            PSegItem(
              n(l10n.sidebarCompleted, counts.completed),
              status == DownloadStatusFilter.completed,
              () => setStatus(DownloadStatusFilter.completed),
            ),
            PSegItem(
              n(l10n.sidebarFailed, counts.failed),
              status == DownloadStatusFilter.failed,
              () => setStatus(DownloadStatusFilter.failed),
            ),
            for (final s in libraryFilterSources(counts.sourceCounts, adult))
              PSegItem(
                n(s, counts.sourceCounts[s]),
                source == s,
                () => setSource(s),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Toolbar ─────────────────────────────────────────────────────────────────

/// Search pill, retry-failed pill, queue capsule, sort/view and `…` menus.
/// Narrow widths fold the queue, then the retry, into the `…` menu.
class PastilleLibraryToolbar extends ConsumerWidget {
  const PastilleLibraryToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final failed = ref.watch(
      downloadLibraryCountsProvider.select((c) => c.failed),
    );
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 640;
        final veryCompact = c.maxWidth < 460;
        return SizedBox(
          height: 46,
          child: Row(
            children: [
              const Expanded(child: _SearchPill()),
              if (!veryCompact && failed > 0) ...[
                const SizedBox(width: 10),
                Tooltip(
                  message: l10n.retryAllFailedTooltip(failed),
                  child: PButton(
                    label: compact
                        ? '$failed'
                        : l10n.pastilleRetryFailed(failed),
                    icon: Icons.refresh_rounded,
                    iconSize: 16,
                    kind: PButtonKind.rose,
                    height: 44,
                    padH: 16,
                    onTap: () => _retryFailed(context, ref, failed),
                  ),
                ),
              ],
              if (!compact) ...[
                const SizedBox(width: 10),
                const _QueueCapsule(),
              ],
              const SizedBox(width: 10),
              const _SortMenu(),
              const SizedBox(width: 10),
              _MoreMenu(showQueue: compact, showRetry: veryCompact),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _retryFailed(BuildContext context, WidgetRef ref, int n) async {
  await ref.read(downloadListProvider.notifier).retryAllFailed();
  if (context.mounted) pNotice(context, context.l10n.retryingFailed(n));
}

Future<void> _pauseAll(BuildContext context, WidgetRef ref) async {
  await ref.read(downloadListProvider.notifier).pauseAllActive();
  if (context.mounted) pNotice(context, context.l10n.activeDownloadsPaused);
}

Future<void> _startQueue(BuildContext context, WidgetRef ref) async {
  await ref.read(downloadListProvider.notifier).resumeAllQueued();
  if (context.mounted) pNotice(context, context.l10n.queueStarted);
}

bool _resumable(AsyncValue<List<DownloadItem>> s) =>
    (s.valueOrNull ?? const <DownloadItem>[]).any(
      (i) =>
          i.status == DownloadStatus.queued ||
          i.status == DownloadStatus.paused ||
          i.status == DownloadStatus.failed,
    );

/// The library filter as a Pastille pill: Ctrl/Cmd+F lands here, Esc clears
/// then leaves, the count reads "matches / total" while searching.
class _SearchPill extends ConsumerStatefulWidget {
  const _SearchPill();

  @override
  ConsumerState<_SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends ConsumerState<_SearchPill> {
  late final TextEditingController _controller;
  final _focus = FocusNode(debugLabel: 'pastille-search');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(downloadSearchQueryProvider),
    );
    DownloadSearchFocus.attach(_focus);
    _focus.addListener(_redraw);
    _controller.addListener(_redraw);
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DownloadSearchFocus.detach(_focus);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _set(String v) =>
      ref.read(downloadSearchQueryProvider.notifier).state = v;

  void _clear() {
    _controller.clear();
    _set('');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(downloadSearchQueryProvider, (_, next) {
      if (_controller.text == next) return;
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    });
    final l10n = context.l10n;
    final tones = PTones.of(context);
    final hasQuery = _controller.text.isNotEmpty;
    final total =
        ref.watch(downloadListProvider.select((s) => s.valueOrNull?.length)) ??
        0;
    final visible =
        ref.watch(filteredDownloadListPhaseProvider).valueOrNull ?? 0;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            hasQuery ? _clear() : _focus.unfocus(),
      },
      child: AnimatedContainer(
        duration: pMotion(context, 200),
        height: 46,
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 6, 0),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1C1A),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: _focus.hasFocus
                  ? tones.butter
                  : pCream.withValues(alpha: 0.1),
              spreadRadius: _focus.hasFocus ? 2 : 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 18,
              color: _focus.hasFocus ? tones.butter : pFaint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                onChanged: _set,
                textInputAction: TextInputAction.search,
                style: pBody(color: pCream),
                cursorColor: tones.butter,
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: l10n.searchDownloads,
                  hintStyle: pBody(color: pFaint),
                ),
              ),
            ),
            if (total > 0) ...[
              const SizedBox(width: 8),
              IgnorePointer(
                child: Text(
                  hasQuery ? l10n.searchMatchCount(visible, total) : '$total',
                  style: pMono(
                    size: 12,
                    color: hasQuery && visible == 0 ? tones.rose : pFaint,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            if (hasQuery)
              PButton(
                icon: Icons.close_rounded,
                tooltip: l10n.searchClear,
                kind: PButtonKind.ghost,
                height: 34,
                iconSize: 15,
                onTap: _clear,
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}

/// Pause what runs / start the queue: two halves of one dark capsule.
class _QueueCapsule extends ConsumerWidget {
  const _QueueCapsule();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    final active = ref.watch(
      downloadLibraryCountsProvider.select((c) => c.active),
    );
    // Disabled when there is nothing to act on, so no "done" toast lies.
    final resumable = ref.watch(downloadListProvider.select(_resumable));
    Widget half({
      required String tip,
      required VoidCallback? onTap,
      required Widget child,
      required bool start,
    }) => Tooltip(
      message: tip,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: tip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.horizontal(
            left: start ? const Radius.circular(999) : Radius.zero,
            right: start ? Radius.zero : const Radius.circular(999),
          ),
          hoverColor: pCream.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Opacity(opacity: onTap == null ? 0.4 : 1, child: child),
          ),
        ),
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: pInkDeep,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(color: pCream.withValues(alpha: 0.1), spreadRadius: 1),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            half(
              tip: l10n.pauseActiveTooltip,
              start: true,
              onTap: active == 0 ? null : () => _pauseAll(context, ref),
              child: Row(
                children: [
                  const Icon(Icons.pause_rounded, size: 18, color: pCream),
                  if (active > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      height: 20,
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tones.lav,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$active',
                        style: pMono(
                          size: 11,
                          weight: FontWeight.w500,
                          color: pInk,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 1.5,
              height: 18,
              color: pCream.withValues(alpha: 0.12),
            ),
            half(
              tip: l10n.startQueueTooltip,
              start: false,
              onTap: !resumable ? null : () => _startQueue(context, ref),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 20,
                color: tones.butter,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sort and view mode.
class _SortMenu extends ConsumerWidget {
  const _SortMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PMenu<String>(
      tooltip: l10n.sortAndView,
      items: (context) {
        final sort = ref.read(downloadSortProvider);
        final mode = ref.read(downloadViewModeProvider);
        final opened = ref.read(openedCreatorFolderKeyProvider);
        final contents = ref.read(folderContentsViewModeProvider);
        final inFolder = mode == DownloadViewMode.folders && opened != null;
        void setSort(DownloadSort a, DownloadSort b) =>
            ref.read(downloadSortProvider.notifier).state = sort == a ? b : a;
        PopupMenuEntry<String> sortItem(
          String value,
          String label,
          DownloadSort first,
          DownloadSort second,
          DownloadSort up,
        ) {
          final on = sort == first || sort == second;
          return pMenuItem(
            value: value,
            label: label,
            checked: on,
            trailing: on && sort == up
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            onTap: () => setSort(first, second),
          );
        }

        void setMode(DownloadViewMode m) {
          if (inFolder && m != DownloadViewMode.folders) {
            ref.read(folderContentsViewModeProvider.notifier).state = m;
            return;
          }
          ref.read(downloadViewModeProvider.notifier).state = m;
          if (m != DownloadViewMode.folders || inFolder) {
            ref.read(openedCreatorFolderKeyProvider.notifier).state = null;
          }
          if (m != DownloadViewMode.folders &&
              (sort == DownloadSort.countDesc ||
                  sort == DownloadSort.countAsc)) {
            ref.read(downloadSortProvider.notifier).state =
                DownloadSort.dateDesc;
          }
        }

        bool shown(DownloadViewMode m) =>
            inFolder && m != DownloadViewMode.folders
            ? contents == m
            : mode == m;
        return [
          pMenuHeader(l10n.sortBy),
          sortItem(
            'date',
            l10n.sortFieldDate,
            DownloadSort.dateDesc,
            DownloadSort.dateAsc,
            DownloadSort.dateAsc,
          ),
          sortItem(
            'name',
            l10n.sortFieldName,
            DownloadSort.nameAsc,
            DownloadSort.nameDesc,
            DownloadSort.nameDesc,
          ),
          sortItem(
            'size',
            l10n.sortFieldSize,
            DownloadSort.sizeDesc,
            DownloadSort.sizeAsc,
            DownloadSort.sizeAsc,
          ),
          if (mode == DownloadViewMode.folders)
            sortItem(
              'count',
              l10n.sortVideoCount,
              DownloadSort.countDesc,
              DownloadSort.countAsc,
              DownloadSort.countAsc,
            ),
          pMenuDivider(),
          pMenuHeader(l10n.viewMode),
          for (final (m, label, icon) in [
            (DownloadViewMode.list, l10n.viewList, Icons.view_agenda_outlined),
            (
              DownloadViewMode.detailed,
              l10n.viewDetailed,
              Icons.grid_view_rounded,
            ),
            (
              DownloadViewMode.folders,
              l10n.viewFolders,
              Icons.folder_copy_outlined,
            ),
          ])
            pMenuItem(
              value: m.name,
              label: label,
              checked: shown(m),
              trailing: icon,
              onTap: () => setMode(m),
            ),
        ];
      },
      child: const PRoundIcon(
        icon: Icons.sort_rounded,
        on: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: pMuted),
      ),
    );
  }
}

/// Refresh and clean-up, plus the queue and retry when the bar is narrow.
class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.showQueue, required this.showRetry});

  final bool showQueue;
  final bool showRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final counts = ref.watch(downloadLibraryCountsProvider);
    final notifier = ref.read(downloadListProvider.notifier);
    Future<void> run(String value) async {
      switch (value) {
        case 'retry_failed':
          await _retryFailed(context, ref, counts.failed);
        case 'pause_all':
          await _pauseAll(context, ref);
        case 'resume_all':
          await _startQueue(context, ref);
        case 'refresh':
          await notifier.refreshLibrary();
          if (context.mounted) pNotice(context, l10n.refreshLibrary);
        case 'clear_completed':
          if (!await pConfirm(
            context,
            title: l10n.clearCompletedConfirm(counts.completed),
            body: l10n.filesDeletedFromDisk,
            action: l10n.delete,
          )) {
            return;
          }
          await notifier.clearCompleted();
          if (context.mounted) pNotice(context, l10n.clearCompletedDone);
        case 'clear_failed':
          await notifier.clearFailed();
          if (context.mounted) pNotice(context, l10n.clearFailedDone);
        case 'clear_history':
          if (await pConfirm(
            context,
            title: l10n.clearHistory,
            body: l10n.clearHistoryConfirm,
            action: l10n.clearHistory,
            icon: Icons.delete_sweep_outlined,
          )) {
            await notifier.clearHistory();
          }
      }
    }

    String n(String label, int count) => count > 0 ? '$label ($count)' : label;
    return PMenu<String>(
      tooltip: l10n.moreActions,
      onSelected: run,
      items: (context) => [
        if (showRetry && counts.failed > 0) ...[
          pMenuItem(
            value: 'retry_failed',
            label: n(l10n.retryFailedAction, counts.failed),
            icon: Icons.refresh_rounded,
            tint: PTones.of(context).rose,
          ),
          pMenuDivider(),
        ],
        if (showQueue) ...[
          pMenuItem(
            value: 'pause_all',
            label: l10n.pauseActiveAction,
            icon: Icons.pause_rounded,
            enabled: counts.active > 0,
          ),
          pMenuItem(
            value: 'resume_all',
            label: l10n.startQueueAction,
            icon: Icons.play_arrow_rounded,
            tint: PTones.of(context).butter,
          ),
          pMenuDivider(),
        ],
        pMenuItem(
          value: 'refresh',
          label: l10n.refreshLibrary,
          icon: Icons.refresh_rounded,
        ),
        pMenuItem(
          value: 'clear_completed',
          label: n(l10n.clearCompletedAction, counts.completed),
          icon: Icons.done_all_rounded,
          enabled: counts.completed > 0,
        ),
        pMenuItem(
          value: 'clear_failed',
          label: n(l10n.clearFailedAction, counts.failed),
          icon: Icons.error_outline_rounded,
          enabled: counts.failed > 0,
        ),
        pMenuDivider(),
        pMenuItem(
          value: 'clear_history',
          label: l10n.clearHistory,
          icon: Icons.delete_sweep_outlined,
          danger: true,
        ),
      ],
      child: const PRoundIcon(icon: Icons.more_horiz_rounded),
    );
  }
}

// ── Inspector pane ──────────────────────────────────────────────────────────

/// The selected download beside the list: a resizable dark panel that
/// folds to a slim rail; on a narrow window it opens as a sheet instead.
class PastilleInspectorPane extends ConsumerWidget {
  const PastilleInspectorPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(selectedDownloadIdProvider);
    if (id == null) return const SizedBox.shrink();
    final layout = ref.watch(paneLayoutProvider);
    final pane = ref.read(paneLayoutProvider.notifier);
    void collapse() {
      pane.toggleInspectorCollapsed();
      pane.persist();
    }

    final theme = Theme.of(context);
    final p = AppPalette.of(context).preset;
    // The shared resize handle draws a hairline and corner brackets in the
    // palette's border colour: Pastille hides them until hovered (butter).
    final quiet = theme.copyWith(
      extensions: [
        AppPalette(
          ThemePreset(
            id: p.id,
            name: p.name,
            primary: PTones.of(context).butter,
            accent: p.accent,
            background: p.background,
            surface: p.surface,
            surfaceHighlight: p.surfaceHighlight,
            textPrimary: p.textPrimary,
            textSecondary: p.textSecondary,
            textDisabled: p.textDisabled,
            border: Colors.transparent,
            borderSubtle: p.borderSubtle,
            success: p.success,
            error: p.error,
            warning: p.warning,
            info: p.info,
            inputBackground: p.inputBackground,
            chrome: p.chrome,
            useMeshBackground: p.useMeshBackground,
            useFloatingDock: p.useFloatingDock,
          ),
        ),
      ],
    );
    return Theme(
      data: quiet,
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
        onToggleCollapse: collapse,
        child: Theme(
          data: theme,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 10),
            child: layout.inspectorCollapsed
                ? PPanel(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: PButton(
                          icon: Icons.chevron_left_rounded,
                          tooltip: context.l10n.expandInspector,
                          kind: PButtonKind.ghost,
                          height: 30,
                          iconSize: 18,
                          onTap: () {
                            pane.expandInspector();
                            pane.persist();
                          },
                        ),
                      ),
                    ),
                  )
                : PPanel(
                    child: PastilleInspector(
                      downloadId: id,
                      onCollapse: collapse,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Below 620 px the inspector opens as a bottom sheet on selection.
void pListenNarrowInspector(BuildContext context, WidgetRef ref) {
  ref.listen<String?>(selectedDownloadIdProvider, (previous, next) {
    if (next == null || next == previous) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.86,
        child: PastilleInspector(downloadId: next),
      ),
    ).whenComplete(() {
      if (ref.read(selectedDownloadIdProvider) == next) {
        ref.read(selectedDownloadIdProvider.notifier).state = null;
      }
    });
  });
}
