import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import '../../presentation/providers/filtered_downloads_provider.dart';
import '../../presentation/providers/downloader_provider.dart';
import '../../presentation/providers/download_library_counts.dart';
import '../../presentation/providers/creator_folders_provider.dart';

import 'inspector/download_inspector.dart';
import 'widgets/download_list.dart';
import 'widgets/download_search_field.dart';
import 'package:modern_downloader/core/ui/layout/pane_layout_provider.dart';
import 'package:flutter/services.dart';
import 'package:modern_downloader/core/ui/widgets/resizable_width_pane.dart';

class DownloadView extends ConsumerWidget {
  const DownloadView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNarrow = MediaQuery.sizeOf(context).width < 720;
    if (isNarrow) {
      ref.listen<String?>(selectedDownloadIdProvider, (previous, next) {
        if (next == null || next == previous) return;
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) {
            return SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.86,
              child: DownloadInspector(downloadId: next),
            );
          },
        );
      });
    }

    // 3-Column Layout: [Sidebar (handled by Shell)] [Main List] [Inspector]
    return Row(
      children: [
        // Main Content (List)
        Expanded(
          child: Focus(
            autofocus: true,
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                    DownloadSearchFocus.request,
                const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
                    DownloadSearchFocus.request,
                const SingleActivator(LogicalKeyboardKey.escape): () {
                  if (ref.read(openedCreatorFolderKeyProvider) != null) {
                    ref.read(openedCreatorFolderKeyProvider.notifier).state =
                        null;
                    ref.read(selectedDownloadIdProvider.notifier).state = null;
                  }
                },
              },
              child: const Column(
                children: [
                  _DownloadTopBar(),
                  _DownloadTopHairline(),
                  Expanded(child: DownloadList()),
                ],
              ),
            ),
          ),
        ),

        // Inspector Panel (Conditional or Always visible but empty?)
        // Design Doc says "Inspector appears on selection".
        // We will show it if an item is selected.
        if (!isNarrow)
          Consumer(
            builder: (context, ref, child) {
              final selectedId = ref.watch(selectedDownloadIdProvider);
              if (selectedId == null) return const SizedBox.shrink();

              final layout = ref.watch(paneLayoutProvider);
              return ResizableWidthPane(
                width: layout.visibleInspectorWidth,
                minWidth: PaneLayout.inspectorRail,
                maxWidth: PaneLayout.inspectorMax,
                contentMinWidth: PaneLayout.inspectorMin,
                resizeFrom: PaneResizeFrom.leading,
                onWidthChanged: (width) {
                  ref
                      .read(paneLayoutProvider.notifier)
                      .setInspectorWidth(width);
                },
                onDragActive: (active) {
                  ref.read(paneResizeActiveProvider.notifier).state = active;
                },
                onResizeEnd: () {
                  ref.read(paneResizeActiveProvider.notifier).state = false;
                  ref.read(paneLayoutProvider.notifier).commitInspectorDrag();
                  ref.read(paneLayoutProvider.notifier).persist();
                },
                onToggleCollapse: () {
                  ref
                      .read(paneLayoutProvider.notifier)
                      .toggleInspectorCollapsed();
                  ref.read(paneLayoutProvider.notifier).persist();
                },
                child: layout.inspectorCollapsed
                    ? _CollapsedInspectorRail(
                        onExpand: () {
                          ref
                              .read(paneLayoutProvider.notifier)
                              .expandInspector();
                          ref.read(paneLayoutProvider.notifier).persist();
                        },
                      )
                    : ColoredBox(
                        color: AppColors.of(context).surface,
                        child: DownloadInspector(downloadId: selectedId),
                      ),
              );
            },
          ),
      ],
    );
  }
}

class _CollapsedInspectorRail extends StatelessWidget {
  final VoidCallback onExpand;

  const _CollapsedInspectorRail({required this.onExpand});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ColoredBox(
      color: AppColors.of(context).surface,
      child: Center(
        child: IconButton(
          tooltip: l10n.expandInspector,
          onPressed: onExpand,
          icon: Icon(
            Icons.chevron_left_rounded,
            color: AppColors.of(context).textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DownloadTopHairline extends StatelessWidget {
  const _DownloadTopHairline();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.of(context).border,
      child: const SizedBox(height: 1, width: double.infinity),
    );
  }
}

class _FailedDownloadsBadge extends ConsumerWidget {
  const _FailedDownloadsBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failedCount = ref.watch(
      downloadLibraryCountsProvider.select((c) => c.failed),
    );
    if (failedCount == 0) return const SizedBox.shrink();

    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: 'Relancer tous les téléchargements en échec',
        child: Material(
          color: colors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              await ref.read(downloadListProvider.notifier).retryAllFailed();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Relance des téléchargements en échec'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.replay_rounded,
                    size: 15,
                    color: colors.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$failedCount ${failedCount > 1 ? "échecs" : "échec"} · Relancer',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueControlCapsule extends ConsumerWidget {
  const _QueueControlCapsule();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final activeCount = ref.watch(
      downloadLibraryCountsProvider.select((c) => c.active),
    );

    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pause All Active
          Tooltip(
            message: 'Mettre en pause tous les téléchargements actifs',
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(7),
              ),
              onTap: () async {
                await ref.read(downloadListProvider.notifier).pauseAllActive();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Tous les téléchargements actifs mis en pause',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pause_rounded,
                      size: 18,
                      color: activeCount > 0
                          ? colors.textPrimary
                          : colors.textSecondary.withValues(alpha: 0.5),
                    ),
                    if (activeCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$activeCount',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 16,
            color: colors.border.withValues(alpha: 0.6),
          ),
          // Resume All Queue
          Tooltip(
            message: 'Lancer tous les téléchargements en attente',
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(7),
              ),
              onTap: () async {
                await ref.read(downloadListProvider.notifier).resumeAllQueued();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('File d\'attente lancée'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 18,
                  color: colors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadMoreActionsMenu extends ConsumerWidget {
  const _DownloadMoreActionsMenu();

  void _showClearHistoryDialog(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.clearHistory),
        content: Text(l10n.clearHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(downloadListProvider.notifier).clearHistory();
              Navigator.pop(c);
            },
            child: Text(
              l10n.clearHistory,
              style: TextStyle(color: AppColors.of(context).error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final completedCount = ref.watch(
      downloadLibraryCountsProvider.select((c) => c.completed),
    );
    final failedCount = ref.watch(
      downloadLibraryCountsProvider.select((c) => c.failed),
    );

    return PopupMenuButton<String>(
      tooltip: 'Plus d\'actions',
      onSelected: (value) async {
        if (value == 'refresh') {
          await ref.read(downloadListProvider.notifier).refreshLibrary();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.refreshLibrary),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (value == 'clear_completed') {
          await ref.read(downloadListProvider.notifier).clearCompleted();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Téléchargements terminés nettoyés'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else if (value == 'clear_failed') {
          await ref.read(downloadListProvider.notifier).clearFailed();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Téléchargements échoués nettoyés'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else if (value == 'clear_history') {
          _showClearHistoryDialog(context, ref);
        }
      },
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            value: 'refresh',
            child: Row(
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.refreshLibrary,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'clear_completed',
            enabled: completedCount > 0,
            child: Row(
              children: [
                Icon(
                  Icons.done_all_rounded,
                  size: 18,
                  color: completedCount > 0
                      ? colors.textSecondary
                      : colors.textDisabled,
                ),
                const SizedBox(width: 10),
                Text(
                  completedCount > 0
                      ? 'Effacer les terminés ($completedCount)'
                      : 'Effacer les terminés',
                  style: TextStyle(
                    fontSize: 13,
                    color: completedCount > 0 ? null : colors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'clear_failed',
            enabled: failedCount > 0,
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: failedCount > 0
                      ? colors.textSecondary
                      : colors.textDisabled,
                ),
                const SizedBox(width: 10),
                Text(
                  failedCount > 0
                      ? 'Effacer les échoués ($failedCount)'
                      : 'Effacer les échoués',
                  style: TextStyle(
                    fontSize: 13,
                    color: failedCount > 0 ? null : colors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'clear_history',
            child: Row(
              children: [
                Icon(
                  Icons.delete_sweep_outlined,
                  size: 18,
                  color: colors.error,
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.clearHistory,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.error,
                  ),
                ),
              ],
            ),
          ),
        ];
      },
      child: Container(
        height: 34,
        width: 34,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.more_horiz_rounded,
          size: 18,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

class _DownloadTopBar extends ConsumerWidget {
  const _DownloadTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      color: colors.isIosChrome
          ? colors.background.withValues(alpha: 0.35)
          : colors.background,
      child: Row(
        children: [
          Expanded(
            child: DownloadSearchField(
              onChanged: (value) {
                ref.read(downloadSearchQueryProvider.notifier).state = value;
              },
            ),
          ),
          const SizedBox(width: 12),
          const _FailedDownloadsBadge(),
          const _QueueControlCapsule(),
          const SizedBox(width: 8),

          // View Mode & Sort Menu
          PopupMenuButton<String>(
            tooltip: l10n.sortAndView,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sort_rounded,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: colors.textSecondary.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
            itemBuilder: (context) {
              final currentSort = ref.read(downloadSortProvider);
              final currentMode = ref.read(downloadViewModeProvider);
              final openedFolder = ref.read(openedCreatorFolderKeyProvider);
              final contentsMode = ref.read(folderContentsViewModeProvider);
              final insideFolder =
                  currentMode == DownloadViewMode.folders &&
                  openedFolder != null;
              final colors = AppColors.of(context);

              final isDate =
                  currentSort == DownloadSort.dateDesc ||
                  currentSort == DownloadSort.dateAsc;
              final isName =
                  currentSort == DownloadSort.nameAsc ||
                  currentSort == DownloadSort.nameDesc;
              final isSize =
                  currentSort == DownloadSort.sizeDesc ||
                  currentSort == DownloadSort.sizeAsc;
              final isCount =
                  currentSort == DownloadSort.countDesc ||
                  currentSort == DownloadSort.countAsc;

              return [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    l10n.sortBy,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'date',
                  onTap: () {
                    ref
                        .read(downloadSortProvider.notifier)
                        .state = currentSort == DownloadSort.dateDesc
                        ? DownloadSort.dateAsc
                        : DownloadSort.dateDesc;
                  },
                  child: Row(
                    children: [
                      Icon(
                        isDate ? Icons.check : null,
                        size: 18,
                        color: isDate ? colors.primary : Colors.transparent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Date',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isDate
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Icon(
                        isDate && currentSort == DownloadSort.dateAsc
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 16,
                        color: isDate
                            ? colors.primary
                            : colors.textSecondary.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'name',
                  onTap: () {
                    ref
                        .read(downloadSortProvider.notifier)
                        .state = currentSort == DownloadSort.nameAsc
                        ? DownloadSort.nameDesc
                        : DownloadSort.nameAsc;
                  },
                  child: Row(
                    children: [
                      Icon(
                        isName ? Icons.check : null,
                        size: 18,
                        color: isName ? colors.primary : Colors.transparent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Nom (A-Z)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isName
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Icon(
                        isName && currentSort == DownloadSort.nameDesc
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 16,
                        color: isName
                            ? colors.primary
                            : colors.textSecondary.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'size',
                  onTap: () {
                    ref
                        .read(downloadSortProvider.notifier)
                        .state = currentSort == DownloadSort.sizeDesc
                        ? DownloadSort.sizeAsc
                        : DownloadSort.sizeDesc;
                  },
                  child: Row(
                    children: [
                      Icon(
                        isSize ? Icons.check : null,
                        size: 18,
                        color: isSize ? colors.primary : Colors.transparent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Taille',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSize
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Icon(
                        isSize && currentSort == DownloadSort.sizeAsc
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 16,
                        color: isSize
                            ? colors.primary
                            : colors.textSecondary.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
                if (currentMode == DownloadViewMode.folders)
                  PopupMenuItem(
                    value: 'count',
                    onTap: () {
                      ref
                          .read(downloadSortProvider.notifier)
                          .state = currentSort == DownloadSort.countDesc
                          ? DownloadSort.countAsc
                          : DownloadSort.countDesc;
                    },
                    child: Row(
                      children: [
                        Icon(
                          isCount ? Icons.check : null,
                          size: 18,
                          color: isCount ? colors.primary : Colors.transparent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.sortVideoCount,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCount
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        Icon(
                          isCount && currentSort == DownloadSort.countAsc
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: isCount
                              ? colors.primary
                              : colors.textSecondary.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),

                const PopupMenuDivider(),
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    l10n.viewMode,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CheckedPopupMenuItem(
                  checked: insideFolder
                      ? contentsMode == DownloadViewMode.list
                      : currentMode == DownloadViewMode.list,
                  value: 'list',
                  child: Text(
                    l10n.viewList,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () {
                    if (insideFolder) {
                      ref.read(folderContentsViewModeProvider.notifier).state =
                          DownloadViewMode.list;
                      return;
                    }
                    ref.read(downloadViewModeProvider.notifier).state =
                        DownloadViewMode.list;
                    ref.read(openedCreatorFolderKeyProvider.notifier).state =
                        null;
                    final sort = ref.read(downloadSortProvider);
                    if (sort == DownloadSort.countDesc ||
                        sort == DownloadSort.countAsc) {
                      ref.read(downloadSortProvider.notifier).state =
                          DownloadSort.dateDesc;
                    }
                  },
                ),
                CheckedPopupMenuItem(
                  checked: insideFolder
                      ? contentsMode == DownloadViewMode.detailed
                      : currentMode == DownloadViewMode.detailed,
                  value: 'detailed',
                  child: Text(
                    l10n.viewDetailed,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () {
                    if (insideFolder) {
                      ref.read(folderContentsViewModeProvider.notifier).state =
                          DownloadViewMode.detailed;
                      return;
                    }
                    ref.read(downloadViewModeProvider.notifier).state =
                        DownloadViewMode.detailed;
                    ref.read(openedCreatorFolderKeyProvider.notifier).state =
                        null;
                    final sort = ref.read(downloadSortProvider);
                    if (sort == DownloadSort.countDesc ||
                        sort == DownloadSort.countAsc) {
                      ref.read(downloadSortProvider.notifier).state =
                          DownloadSort.dateDesc;
                    }
                  },
                ),
                CheckedPopupMenuItem(
                  checked: currentMode == DownloadViewMode.folders,
                  value: 'folders',
                  child: Text(
                    l10n.viewFolders,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () {
                    ref.read(downloadViewModeProvider.notifier).state =
                        DownloadViewMode.folders;
                    if (insideFolder) {
                      ref.read(openedCreatorFolderKeyProvider.notifier).state =
                          null;
                    }
                  },
                ),
              ];
            },
          ),
          const SizedBox(width: 8),
          const _DownloadMoreActionsMenu(),
        ],
      ),
    );
  }
}
