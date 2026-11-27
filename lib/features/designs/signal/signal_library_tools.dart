import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/design_system/foundation/typography.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/features/downloader/presentation/models/creator_folder.dart';
import 'package:tapload/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:tapload/features/downloader/presentation/views/widgets/download_row_host.dart';
import 'package:tapload/features/downloader/presentation/views/widgets/download_search_field.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import 'signal_controls.dart';
import 'signal_states.dart';
import 'signal_theme.dart';
import 'signal_widgets.dart';

// ── Search ──────────────────────────────────────────────────────────────────

/// The library search as a Signal pill: Ctrl+F lands here (it registers
/// with [DownloadSearchFocus]), Échap clears then leaves, and it shows how
/// many items match.
class SignalSearchField extends ConsumerStatefulWidget {
  const SignalSearchField({super.key});

  @override
  ConsumerState<SignalSearchField> createState() => _SignalSearchFieldState();
}

class _SignalSearchFieldState extends ConsumerState<SignalSearchField> {
  late final TextEditingController _controller;
  final _focus = FocusNode(debugLabel: 'signal-search');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(downloadSearchQueryProvider),
    )..addListener(_changed);
    DownloadSearchFocus.attach(_focus);
    _focus.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DownloadSearchFocus.detach(_focus);
    _controller.dispose();
    _focus.dispose();
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
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final query = _controller.text;
    final total =
        ref.watch(downloadListProvider.select((s) => s.valueOrNull?.length)) ??
        0;
    final visible =
        ref.watch(filteredDownloadListPhaseProvider).valueOrNull ?? 0;
    final focused = _focus.hasFocus;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            query.isNotEmpty ? _clear() : _focus.unfocus(),
      },
      child: AnimatedContainer(
        duration: signalMotion(context, 200),
        height: 36,
        padding: const EdgeInsets.fromLTRB(14, 0, 4, 0),
        decoration: BoxDecoration(
          color: colors.inputBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: focused
                ? colors.primary
                : colors.textPrimary.withValues(alpha: 0.1),
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.18),
                    spreadRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 16, color: colors.textDisabled),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                onChanged: _set,
                textInputAction: TextInputAction.search,
                cursorColor: colors.primary,
                style: AppTypography.body.copyWith(
                  fontSize: 13,
                  color: colors.textPrimary,
                ),
                decoration: signalBareInput(context, l10n.searchDownloads),
              ),
            ),
            if (total > 0)
              Text(
                query.isNotEmpty
                    ? l10n.searchMatchCount(visible, total)
                    : '$total',
                style: AppTypography.mono.copyWith(
                  fontSize: 11.5,
                  color: query.isNotEmpty && visible == 0
                      ? colors.error
                      : colors.textDisabled,
                ),
              ),
            if (query.isNotEmpty)
              SignalIconButton(
                icon: Icons.close_rounded,
                tooltip: l10n.searchClear,
                size: 28,
                iconSize: 14,
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

// ── More actions ────────────────────────────────────────────────────────────

/// Round ghost button that opens a Signal menu.
class SignalMenuButton<T> extends StatelessWidget {
  const SignalMenuButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.itemBuilder,
    required this.onSelected,
  });

  final IconData icon;
  final String tooltip;
  final PopupMenuItemBuilder<T> itemBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SignalMaterial(
      child: PopupMenuButton<T>(
        tooltip: tooltip,
        position: PopupMenuPosition.under,
        offset: const Offset(0, 8),
        onSelected: onSelected,
        itemBuilder: itemBuilder,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.textPrimary.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(icon, size: 17, color: colors.textSecondary),
        ),
      ),
    );
  }
}

/// One line of a Signal menu: icon, label, an optional count in mono.
PopupMenuItem<T> signalMenuItem<T>(
  BuildContext context, {
  required T value,
  required IconData icon,
  required String label,
  int? count,
  bool enabled = true,
  Color? tone,
}) {
  final colors = AppColors.of(context);
  final fg = !enabled ? colors.textDisabled : (tone ?? colors.textPrimary);
  return PopupMenuItem<T>(
    value: value,
    enabled: enabled,
    height: 40,
    child: Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: tone ?? (enabled ? colors.textSecondary : colors.textDisabled),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTypography.body.copyWith(fontSize: 13.5, color: fg),
          ),
        ),
        if (count != null && count > 0) ...[
          const SizedBox(width: 12),
          Text(
            '$count',
            style: AppTypography.mono.copyWith(
              fontSize: 12,
              color: colors.textDisabled,
            ),
          ),
        ],
      ],
    ),
  );
}

enum _More {
  retryFailed,
  pauseAll,
  resumeAll,
  refresh,
  clearCompleted,
  clearFailed,
  clearHistory,
}

/// The library's « … » menu: the queue (pause, start), retry the failures,
/// refresh, and clearing finished, failed or all history (asked first when
/// files would go).
class SignalMoreActions extends ConsumerWidget {
  const SignalMoreActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final counts = ref.watch(downloadLibraryCountsProvider);
    final notifier = ref.read(downloadListProvider.notifier);
    void tell(String text) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
      );
    }

    Future<bool> ask(String title, String body, String confirm) async =>
        await showDialog<bool>(
          context: context,
          builder: (c) => SignalMaterial(
            child: AlertDialog(
              title: Text(title),
              content: Text(body),
              actions: [
                TextButton(
                  autofocus: true,
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(confirm),
                ),
              ],
            ),
          ),
        ) ==
        true;

    Future<void> run(_More v) async {
      switch (v) {
        case _More.retryFailed:
          final n = counts.failed;
          await notifier.retryAllFailed();
          tell(l10n.retryingFailed(n));
        case _More.pauseAll:
          await notifier.pauseAllActive();
          tell(l10n.activeDownloadsPaused);
        case _More.resumeAll:
          await notifier.resumeAllQueued();
          tell(l10n.queueStarted);
        case _More.refresh:
          await notifier.refreshLibrary();
          tell(l10n.refreshLibrary);
        case _More.clearCompleted:
          if (!await ask(
            l10n.clearCompletedConfirm(counts.completed),
            l10n.filesDeletedFromDisk,
            l10n.delete,
          )) {
            return;
          }
          await notifier.clearCompleted();
          tell(l10n.clearCompletedDone);
        case _More.clearFailed:
          await notifier.clearFailed();
          tell(l10n.clearFailedDone);
        case _More.clearHistory:
          if (!await ask(
            l10n.clearHistory,
            l10n.clearHistoryConfirm,
            l10n.clearHistory,
          )) {
            return;
          }
          await notifier.clearHistory();
      }
    }

    return SignalMenuButton<_More>(
      icon: Icons.more_horiz_rounded,
      tooltip: l10n.moreActions,
      onSelected: run,
      itemBuilder: (context) => [
        signalMenuItem(
          context,
          value: _More.pauseAll,
          icon: Icons.pause_rounded,
          label: l10n.pauseActiveAction,
          enabled: counts.active > 0,
        ),
        signalMenuItem(
          context,
          value: _More.resumeAll,
          icon: Icons.play_arrow_rounded,
          label: l10n.startQueueAction,
          tone: colors.primary,
        ),
        if (counts.failed > 0)
          signalMenuItem(
            context,
            value: _More.retryFailed,
            icon: Icons.replay_rounded,
            label: l10n.retryFailedAction,
            count: counts.failed,
          ),
        const PopupMenuDivider(),
        signalMenuItem(
          context,
          value: _More.refresh,
          icon: Icons.refresh_rounded,
          label: l10n.refreshLibrary,
        ),
        signalMenuItem(
          context,
          value: _More.clearCompleted,
          icon: Icons.done_all_rounded,
          label: l10n.clearCompletedAction,
          count: counts.completed,
          enabled: counts.completed > 0,
        ),
        signalMenuItem(
          context,
          value: _More.clearFailed,
          icon: Icons.error_outline_rounded,
          label: l10n.clearFailedAction,
          count: counts.failed,
          enabled: counts.failed > 0,
        ),
        const PopupMenuDivider(),
        signalMenuItem(
          context,
          value: _More.clearHistory,
          icon: Icons.delete_sweep_outlined,
          label: l10n.clearHistory,
          tone: colors.error,
        ),
      ],
    );
  }
}

// ── Folders ─────────────────────────────────────────────────────────────────

/// The library by creator: folder cards, then the opened folder's items as
/// Signal rows (list or cards). [empty] shows when a search matches nothing.
class SignalFolders extends ConsumerWidget {
  const SignalFolders({super.key, required this.empty});

  final Widget empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Same housekeeping as the shared list: leaving folders, or a folder
    // emptied by a filter, closes the opened folder.
    ref.listen(downloadViewModeProvider, (_, next) {
      if (next != DownloadViewMode.folders) {
        ref.read(openedCreatorFolderKeyProvider.notifier).state = null;
      }
    });
    ref.listen(creatorFoldersProvider, (_, next) {
      final opened = ref.read(openedCreatorFolderKeyProvider);
      if (opened != null && !next.folders.any((f) => f.key == opened)) {
        ref.read(openedCreatorFolderKeyProvider.notifier).state = null;
      }
    });
    final phase = ref.watch(filteredDownloadListPhaseProvider);
    final count = phase.valueOrNull;
    if (count == null) {
      return const SignalShimmer(
        child: Column(
          children: [
            SignalBone(height: 74, radius: 14),
            SizedBox(height: 8),
            SignalBone(height: 74, radius: 14),
          ],
        ),
      );
    }
    if (count == 0) {
      return Align(alignment: Alignment.topCenter, child: empty);
    }
    final opened = ref.watch(openedCreatorFolderProvider);
    if (opened == null) return const _FolderGrid();
    return _FolderContents(folder: opened);
  }
}

String _folderName(BuildContext context, CreatorFolder f) =>
    f.isUnknown ? context.l10n.folderUnknownCreator : '@${f.handle}';

class _FolderGrid extends ConsumerWidget {
  const _FolderGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(creatorFoldersProvider).folders;
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 48),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisExtent: 236,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: folders.length,
      itemBuilder: (context, i) => _FolderCard(
        key: ValueKey(folders[i].key),
        folder: folders[i],
        onOpen: () {
          ref.read(openedCreatorFolderKeyProvider.notifier).state =
              folders[i].key;
          ref.read(selectedDownloadIdProvider.notifier).state = null;
        },
      ),
    );
  }
}

class _FolderCard extends StatefulWidget {
  const _FolderCard({super.key, required this.folder, required this.onOpen});

  final CreatorFolder folder;
  final VoidCallback onOpen;

  @override
  State<_FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<_FolderCard> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final f = widget.folder;
    final urls = f.previewUrls.take(4).toList();
    return Semantics(
      button: true,
      label: _folderName(context, f),
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onOpen();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onOpen,
          child: SignalCard(
            lift: true,
            ring: _focus ? colors.primary : null,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w = (c.maxWidth - 4) / 2;
                      final h = (c.maxHeight - 4) / 2;
                      return Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (var i = 0; i < 4; i++)
                            SignalThumb(
                              url: i < urls.length ? urls[i] : null,
                              width: w,
                              height: h,
                              radius: 8,
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _folderName(context, f),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.folderVideoCount(f.count),
                  style: AppTypography.mono.copyWith(
                    fontSize: 12,
                    color: colors.textDisabled,
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

class _FolderContents extends ConsumerWidget {
  const _FolderContents({required this.folder});

  final CreatorFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final ids = ref.watch(openedCreatorFolderItemIdsProvider).ids;
    final mode = ref.watch(folderContentsViewModeProvider);
    final grid = mode == DownloadViewMode.detailed;
    void setMode(DownloadViewMode m) =>
        ref.read(folderContentsViewModeProvider.notifier).state = m;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SignalIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: l10n.folderBack,
              onTap: () {
                ref.read(openedCreatorFolderKeyProvider.notifier).state = null;
                ref.read(selectedDownloadIdProvider.notifier).state = null;
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _folderName(context, folder),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.display(
                      22,
                      weight: FontWeight.w600,
                    ).copyWith(color: colors.textPrimary),
                  ),
                  Text(
                    l10n.folderVideoCount(folder.count),
                    style: AppTypography.mono.copyWith(
                      fontSize: 12,
                      color: colors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
            SignalChip(
              label: l10n.viewList,
              selected: !grid,
              onTap: () => setMode(DownloadViewMode.list),
            ),
            const SizedBox(width: 8),
            SignalChip(
              label: l10n.viewDetailed,
              selected: grid,
              onTap: () => setMode(DownloadViewMode.detailed),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: grid
              ? GridView.builder(
                  padding: const EdgeInsets.only(bottom: 48),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    mainAxisExtent: 280,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: ids.length,
                  itemBuilder: (context, i) => DownloadRowHost(
                    key: ValueKey(ids[i]),
                    id: ids[i],
                    useGridCard: true,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 48),
                  itemCount: ids.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: DownloadRowHost(key: ValueKey(ids[i]), id: ids[i]),
                  ),
                ),
        ),
      ],
    );
  }
}
