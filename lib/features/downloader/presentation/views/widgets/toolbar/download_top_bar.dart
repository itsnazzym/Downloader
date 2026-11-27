import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/l10n/l10n_ext.dart';
import '../../../providers/creator_folders_provider.dart';
import '../../../providers/filtered_downloads_provider.dart';
import '../download_search_field.dart';
import 'download_more_actions_menu.dart';
import 'failed_downloads_badge.dart';
import 'queue_control_capsule.dart';

class DownloadTopBar extends ConsumerWidget {
  const DownloadTopBar({super.key, this.showFailedBadge = true});

  /// Off where the page already offers its own "retry failed" control.
  final bool showFailedBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isCompact = availableWidth < 640;
        final isVeryCompact = availableWidth < 460;

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
                    ref.read(downloadSearchQueryProvider.notifier).state =
                        value;
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (!isVeryCompact && showFailedBadge)
                FailedDownloadsBadge(compact: isCompact),
              if (!isCompact) ...[
                const QueueControlCapsule(),
                const SizedBox(width: 8),
              ],

              // View Mode & Sort Menu
              PopupMenuButton<String>(
                tooltip: l10n.sortAndView,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.6),
                    ),
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
                  final openedFolder =
                      ref.read(openedCreatorFolderKeyProvider);
                  final contentsMode =
                      ref.read(folderContentsViewModeProvider);
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
                        ref.read(downloadSortProvider.notifier).state =
                            currentSort == DownloadSort.dateDesc
                                ? DownloadSort.dateAsc
                                : DownloadSort.dateDesc;
                      },
                      child: Row(
                        children: [
                          Icon(
                            isDate ? Icons.check : null,
                            size: 18,
                            color:
                                isDate ? colors.primary : Colors.transparent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.l10n.sortFieldDate,
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
                        ref.read(downloadSortProvider.notifier).state =
                            currentSort == DownloadSort.nameAsc
                                ? DownloadSort.nameDesc
                                : DownloadSort.nameAsc;
                      },
                      child: Row(
                        children: [
                          Icon(
                            isName ? Icons.check : null,
                            size: 18,
                            color:
                                isName ? colors.primary : Colors.transparent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.l10n.sortFieldName,
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
                        ref.read(downloadSortProvider.notifier).state =
                            currentSort == DownloadSort.sizeDesc
                                ? DownloadSort.sizeAsc
                                : DownloadSort.sizeDesc;
                      },
                      child: Row(
                        children: [
                          Icon(
                            isSize ? Icons.check : null,
                            size: 18,
                            color:
                                isSize ? colors.primary : Colors.transparent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.l10n.sortFieldSize,
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
                          ref.read(downloadSortProvider.notifier).state =
                              currentSort == DownloadSort.countDesc
                                  ? DownloadSort.countAsc
                                  : DownloadSort.countDesc;
                        },
                        child: Row(
                          children: [
                            Icon(
                              isCount ? Icons.check : null,
                              size: 18,
                              color: isCount
                                  ? colors.primary
                                  : Colors.transparent,
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
                              isCount &&
                                      currentSort == DownloadSort.countAsc
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 16,
                              color: isCount
                                  ? colors.primary
                                  : colors.textSecondary
                                      .withValues(alpha: 0.5),
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
                          ref
                              .read(folderContentsViewModeProvider.notifier)
                              .state = DownloadViewMode.list;
                          return;
                        }
                        ref.read(downloadViewModeProvider.notifier).state =
                            DownloadViewMode.list;
                        ref
                            .read(openedCreatorFolderKeyProvider.notifier)
                            .state = null;
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
                          ref
                              .read(folderContentsViewModeProvider.notifier)
                              .state = DownloadViewMode.detailed;
                          return;
                        }
                        ref.read(downloadViewModeProvider.notifier).state =
                            DownloadViewMode.detailed;
                        ref
                            .read(openedCreatorFolderKeyProvider.notifier)
                            .state = null;
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
                          ref
                              .read(openedCreatorFolderKeyProvider.notifier)
                              .state = null;
                        }
                      },
                    ),
                  ];
                },
              ),
              const SizedBox(width: 8),
              DownloadMoreActionsMenu(
                showQueueActions: isCompact,
                showRetryFailed: isVeryCompact,
              ),
            ],
          ),
        );
      },
    );
  }
}
