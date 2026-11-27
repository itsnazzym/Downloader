import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import '../../../providers/download_library_counts.dart';
import '../../../providers/downloader_provider.dart';

class DownloadMoreActionsMenu extends ConsumerWidget {
  final bool showQueueActions;
  final bool showRetryFailed;

  /// What the menu opens from; today's ringed "…" square when null.
  final Widget? child;

  const DownloadMoreActionsMenu({
    super.key,
    this.showQueueActions = false,
    this.showRetryFailed = false,
    this.child,
  });

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
    final activeCount = ref.watch(
      downloadLibraryCountsProvider.select((c) => c.active),
    );
    final completedCount = ref.watch(
      downloadLibraryCountsProvider.select((c) => c.completed),
    );
    final failedCount = ref.watch(
      downloadLibraryCountsProvider.select((c) => c.failed),
    );

    return PopupMenuButton<String>(
      tooltip: l10n.moreActions,
      onSelected: (value) async {
        if (value == 'retry_failed') {
          await ref.read(downloadListProvider.notifier).retryAllFailed();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.retryingFailed(failedCount)),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (value == 'pause_all') {
          await ref.read(downloadListProvider.notifier).pauseAllActive();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.activeDownloadsPaused),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (value == 'resume_all') {
          await ref.read(downloadListProvider.notifier).resumeAllQueued();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.queueStarted),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (value == 'refresh') {
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
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(l10n.clearCompletedConfirm(completedCount)),
              content: Text(l10n.filesDeletedFromDisk),
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
                  child: Text(l10n.delete),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          await ref.read(downloadListProvider.notifier).clearCompleted();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.clearCompletedDone),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else if (value == 'clear_failed') {
          await ref.read(downloadListProvider.notifier).clearFailed();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.clearFailedDone),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (value == 'clear_history') {
          _showClearHistoryDialog(context, ref);
        }
      },
      itemBuilder: (context) {
        return [
          if (showRetryFailed && failedCount > 0) ...[
            PopupMenuItem(
              value: 'retry_failed',
              child: Row(
                children: [
                  Icon(
                    Icons.replay_rounded,
                    size: 18,
                    color: colors.warning,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${l10n.retryFailedAction} ($failedCount)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.warning,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
          ],
          if (showQueueActions) ...[
            PopupMenuItem(
              value: 'pause_all',
              enabled: activeCount > 0,
              child: Row(
                children: [
                  Icon(
                    Icons.pause_rounded,
                    size: 18,
                    color: activeCount > 0
                        ? colors.textSecondary
                        : colors.textDisabled,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.pauseActiveAction,
                    style: TextStyle(
                      fontSize: 13,
                      color: activeCount > 0 ? null : colors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'resume_all',
              child: Row(
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 18,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.startQueueAction,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
          ],
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
                      ? '${l10n.clearCompletedAction} ($completedCount)'
                      : l10n.clearCompletedAction,
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
                      ? '${l10n.clearFailedAction} ($failedCount)'
                      : l10n.clearFailedAction,
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
      child: child ?? Container(
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
