import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/design_system/design_skin.dart';
import 'package:tapload/core/download/download_status_guard.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/models/creator_folder.dart';
import 'package:tapload/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/live_activity.dart';
import 'package:tapload/features/downloader/presentation/views/dialogs/age_verification_help_dialog.dart';
import 'package:tapload/features/downloader/presentation/views/widgets/download_row_host.dart';
import 'package:tapload/features/downloader/presentation/views/widgets/download_search_field.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'terminal_states.dart';
import 'terminal_widgets.dart';

/// Terminal's library pieces: the shared row drawn as a table line or a
/// hairline card, the `/` filter and the `...` actions of the toolbar.

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

/// The state word of a line (`ok`, `run`, `wait`, `err`) and its colour.
(String, Color) terminalStateOf(BuildContext context, DownloadItem item) {
  final colors = AppColors.of(context);
  final l10n = context.l10n;
  if (item.status == DownloadStatus.failed ||
      item.status == DownloadStatus.canceled) {
    return (l10n.terminalStateErr, colors.error);
  }
  if (item.status == DownloadStatus.queued ||
      item.status == DownloadStatus.paused) {
    return (l10n.terminalStateWait, colors.warning);
  }
  if (isActiveDownload(item)) return (l10n.terminalStateRun, colors.primary);
  return (l10n.terminalStateOk, colors.primary);
}

/// `youtube 87M`, or `6,2 Mo/s · 5 s` while it runs.
String _sizeText(DownloadItem item) {
  if (item.status == DownloadStatus.downloading && item.speed.isNotEmpty) {
    return [item.speed, if (item.eta.isNotEmpty) item.eta].join(' · ');
  }
  final size = bytesOf(item);
  return size > 0 ? compactBytes(size) : '';
}

bool _failed(DownloadItem item) =>
    item.status == DownloadStatus.failed ||
    item.status == DownloadStatus.canceled;

bool _restartable(DownloadItem item) =>
    _failed(item) || item.status == DownloadStatus.completed;

/// The shared library row (selection and context menu stay shared around
/// it): a table line in lists, a hairline card in grids.
class TerminalRow extends StatelessWidget {
  const TerminalRow({super.key, required this.row});

  final DesignRow row;

  @override
  Widget build(BuildContext context) =>
      row.grid ? _GridCard(row: row) : _ListLine(row: row);
}

/// Retry, age help and delete: square key buttons, each with its tooltip.
class _RowActions extends StatelessWidget {
  const _RowActions({required this.row});

  final DesignRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = row.item;
    final age =
        item.status == DownloadStatus.failed &&
        DownloadStatusGuard.isAgeVerificationFailure(
          error: item.error,
          url: item.request.url,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (age) ...[
          TButton(
            label: '18+',
            height: 26,
            tooltip: l10n.ageCheckSeeSolutions,
            onTap: () => AgeVerificationHelpDialog.show(context, item),
          ),
          const SizedBox(width: 4),
        ],
        if (_restartable(item)) ...[
          TButton(
            label: l10n.retry,
            height: 26,
            tooltip: l10n.retryDownload,
            onTap: row.onRetry,
          ),
          const SizedBox(width: 4),
        ],
        TButton(
          label: '×',
          square: true,
          height: 26,
          kind: TButtonKind.danger,
          tooltip: l10n.remove,
          onTap: row.onCancel,
        ),
      ],
    );
  }
}

class _ListLine extends StatelessWidget {
  const _ListLine({required this.row});

  final DesignRow row;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final item = row.item;
    final (state, stateColor) = terminalStateOf(context, item);
    final busy = isActiveDownload(item);
    final reason = _failed(item) ? downloadErrorReason(item.error) : '';
    return THoverLine(
      selected: row.isSelected,
      onTap: row.onTap,
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 36,
            child: TThumb(url: item.thumbnailUrl, filePath: item.filePath),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 44, child: Text(state, style: tm(stateColor))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleOf(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tm(colors.textPrimary, weight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                if (busy)
                  TSeg(value: item.progress, height: 6)
                else
                  Text(
                    reason.isNotEmpty
                        ? '└ $reason'
                        : [
                            item.source.toLowerCase(),
                            _sizeText(item),
                          ].where((s) => s.isNotEmpty).join(' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tm(
                      reason.isNotEmpty ? colors.error : colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              busy
                  ? '${(item.progress * 100).round()}% ${_sizeText(item)}'
                  : formatLabelOf(item).toLowerCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: tm(colors.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          _RowActions(row: row),
        ],
      ),
    );
  }
}

class _GridCard extends StatefulWidget {
  const _GridCard({required this.row});

  final DesignRow row;

  @override
  State<_GridCard> createState() => _GridCardState();
}

class _GridCardState extends State<_GridCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final row = widget.row;
    final item = row.item;
    final (state, stateColor) = terminalStateOf(context, item);
    final busy = isActiveDownload(item);
    final reason = _failed(item) ? downloadErrorReason(item.error) : '';
    final lit = _hover || row.isSelected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: row.onTap,
        child: AnimatedContainer(
          duration: tMotion(context),
          decoration: BoxDecoration(
            color: row.isSelected
                ? colors.primary.withValues(alpha: 0.08)
                : colors.surface,
            border: Border.all(color: lit ? colors.primary : colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TThumb(
                  url: item.thumbnailUrl,
                  filePath: item.filePath,
                  cacheWidth: 480,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '$state  ', style: tm(stateColor)),
                          TextSpan(text: titleOf(item)),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tm(colors.textPrimary, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    if (busy) ...[
                      TSeg(value: item.progress, height: 6),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            reason.isNotEmpty
                                ? reason
                                : [
                                    item.source.toLowerCase(),
                                    if (busy)
                                      '${(item.progress * 100).round()}%',
                                    _sizeText(item),
                                  ].where((s) => s.isNotEmpty).join(' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tm(
                              reason.isNotEmpty
                                  ? colors.error
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _RowActions(row: row),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `# cartes` / `# dossiers`: the head of the non-table views (it carries
/// the tour's library target).
class TerminalModeHead extends ConsumerWidget {
  const TerminalModeHead({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(downloadViewModeProvider);
    final label = mode == DownloadViewMode.folders
        ? l10n.viewFolders
        : l10n.viewDetailed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 7, 12, 7),
      child: Text(
        '# ${label.toLowerCase()}',
        style: tm(AppColors.of(context).textDisabled),
      ),
    );
  }
}

/// The library as hairline cards (today's detailed grid).
class TerminalCardGrid extends StatelessWidget {
  const TerminalCardGrid({super.key, required this.ids});

  final List<String> ids;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.only(top: 6),
    sliver: SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: 250,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: ids.length,
      itemBuilder: (context, i) =>
          DownloadRowHost(key: ValueKey(ids[i]), id: ids[i], useGridCard: true),
    ),
  );
}

/// Creator folders as `dir` lines; an opened one lists its downloads under
/// `← cd ..`, as lines ([line]) or cards, like today's folder view.
class TerminalFolders extends ConsumerWidget {
  const TerminalFolders({super.key, required this.line});

  final Widget Function(String id) line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A folder emptied by a filter or a delete closes, as in today's view.
    ref.listen(creatorFoldersProvider, (_, next) {
      final opened = ref.read(openedCreatorFolderKeyProvider);
      if (opened != null && !next.folders.any((f) => f.key == opened)) {
        ref.read(openedCreatorFolderKeyProvider.notifier).state = null;
      }
    });
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final opened = ref.watch(openedCreatorFolderProvider);
    String name(CreatorFolder f) =>
        f.isUnknown ? l10n.folderUnknownCreator : '@${f.handle}';
    void select(String? key) {
      ref.read(openedCreatorFolderKeyProvider.notifier).state = key;
      ref.read(selectedDownloadIdProvider.notifier).state = null;
    }

    if (opened == null) {
      final folders = ref.watch(creatorFoldersProvider).folders;
      return SliverList.builder(
        itemCount: folders.length,
        itemBuilder: (context, i) {
          final f = folders[i];
          return TPrinted(
            index: i,
            child: THoverLine(
              key: ValueKey(f.key),
              onTap: () => select(f.key),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text('dir', style: tm(colors.primary)),
                  ),
                  Expanded(
                    child: Text(
                      '${name(f)}/',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tm(colors.textPrimary, weight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    l10n.folderVideoCount(f.count),
                    style: tm(colors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
    final ids = ref.watch(openedCreatorFolderItemIdsProvider).ids;
    final grid =
        ref.watch(folderContentsViewModeProvider) == DownloadViewMode.detailed;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 12, 8),
            child: Row(
              children: [
                TLink(label: '← cd ..', onTap: () => select(null)),
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    name(opened),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tm(colors.textPrimary, weight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '# ${l10n.folderVideoCount(opened.count)}',
                  style: tm(colors.textDisabled),
                ),
              ],
            ),
          ),
        ),
        if (grid)
          TerminalCardGrid(ids: ids)
        else
          SliverList.builder(
            itemCount: ids.length,
            itemBuilder: (context, i) =>
                KeyedSubtree(key: ValueKey(ids[i]), child: line(ids[i])),
          ),
      ],
    );
  }
}

/// The `/` filter: same wiring as today's search field (Ctrl+F target,
/// Esc clears then leaves, provider and field stay in sync, match count).
class TSearchField extends ConsumerStatefulWidget {
  const TSearchField({super.key});

  @override
  ConsumerState<TSearchField> createState() => _TSearchFieldState();
}

class _TSearchFieldState extends ConsumerState<TSearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(downloadSearchQueryProvider),
    );
    _focus = FocusNode(debugLabel: 'terminal-search');
    DownloadSearchFocus.attach(_focus);
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    DownloadSearchFocus.detach(_focus);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = _focus.hasFocus);
  }

  void _set(String v) {
    ref.read(downloadSearchQueryProvider.notifier).state = v;
    setState(() {});
  }

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
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final hasQuery = _controller.text.isNotEmpty;
    final total =
        ref.watch(downloadListProvider.select((s) => s.valueOrNull?.length)) ??
        0;
    final visible =
        ref.watch(filteredDownloadListPhaseProvider).valueOrNull ?? 0;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            hasQuery ? _clear() : _focus.unfocus(),
      },
      child: AnimatedContainer(
        duration: tMotion(context),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          color: colors.inputBackground,
          border: Border.all(color: _focused ? colors.primary : colors.border),
        ),
        child: Row(
          children: [
            Text('/', style: tm(colors.primary)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                onChanged: _set,
                textInputAction: TextInputAction.search,
                cursorColor: colors.primary,
                style: tm(colors.textPrimary),
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: l10n.searchDownloads,
                  hintStyle: tm(colors.textDisabled),
                ),
              ),
            ),
            if (total > 0) ...[
              const SizedBox(width: 6),
              Text(
                hasQuery ? l10n.searchMatchCount(visible, total) : '$total',
                style: tm(
                  hasQuery && visible == 0
                      ? colors.warning
                      : colors.textDisabled,
                  size: 11,
                ),
              ),
            ],
            if (hasQuery)
              Semantics(
                button: true,
                label: l10n.searchClear,
                child: Tooltip(
                  message: l10n.searchClear,
                  child: InkWell(
                    onTap: _clear,
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(
                        child: Text('×', style: tm(colors.textSecondary)),
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}

/// `...`: queue and library housekeeping, as today's more-actions menu with
/// the queue actions (failures are retried from the banner and `r`).
class TMoreMenu extends ConsumerWidget {
  const TMoreMenu({super.key});

  Future<bool> _ask(
    BuildContext context,
    String title,
    String body,
    String action,
  ) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => TDialog(
        title: title,
        body: Text(body),
        actions: [
          TButton(
            keyHint: 'Esc',
            label: l10n.cancel,
            onTap: () => Navigator.pop(c, false),
          ),
          TButton(
            label: action,
            kind: TButtonKind.danger,
            onTap: () => Navigator.pop(c, true),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final counts = ref.watch(downloadLibraryCountsProvider);
    final notifier = ref.read(downloadListProvider.notifier);
    void say(String m, [int s = 2]) =>
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(m),
            duration: Duration(seconds: s),
          ),
        );

    PopupMenuItem<String> item(
      String value,
      String label, {
      bool enabled = true,
      bool danger = false,
    }) => PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      height: 34,
      child: Text(
        label,
        style: tm(
          !enabled
              ? colors.textDisabled
              : danger
              ? colors.error
              : colors.textPrimary,
        ),
      ),
    );

    return PopupMenuButton<String>(
      tooltip: l10n.moreActions,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.zero,
      ),
      onSelected: (value) async {
        switch (value) {
          case 'pause_all':
            await notifier.pauseAllActive();
            if (context.mounted) say(l10n.activeDownloadsPaused);
          case 'resume_all':
            await notifier.resumeAllQueued();
            if (context.mounted) say(l10n.queueStarted);
          case 'refresh':
            await notifier.refreshLibrary();
            if (context.mounted) say(l10n.refreshLibrary);
          case 'clear_completed':
            if (!await _ask(
              context,
              l10n.clearCompletedConfirm(counts.completed),
              l10n.filesDeletedFromDisk,
              l10n.delete,
            )) {
              return;
            }
            await notifier.clearCompleted();
            if (context.mounted) say(l10n.clearCompletedDone, 3);
          case 'clear_failed':
            await notifier.clearFailed();
            if (context.mounted) say(l10n.clearFailedDone);
          case 'clear_history':
            if (await _ask(
              context,
              l10n.clearHistory,
              l10n.clearHistoryConfirm,
              l10n.clearHistory,
            )) {
              await notifier.clearHistory();
            }
        }
      },
      itemBuilder: (context) => [
        item('pause_all', l10n.pauseActiveAction, enabled: counts.active > 0),
        item('resume_all', l10n.startQueueAction),
        const PopupMenuDivider(),
        item('refresh', l10n.refreshLibrary),
        item(
          'clear_completed',
          counts.completed > 0
              ? '${l10n.clearCompletedAction} (${counts.completed})'
              : l10n.clearCompletedAction,
          enabled: counts.completed > 0,
        ),
        item(
          'clear_failed',
          counts.failed > 0
              ? '${l10n.clearFailedAction} (${counts.failed})'
              : l10n.clearFailedAction,
          enabled: counts.failed > 0,
        ),
        const PopupMenuDivider(),
        item('clear_history', l10n.clearHistory, danger: true),
      ],
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
        ),
        child: Text('...', style: tm(colors.textSecondary)),
      ),
    );
  }
}
