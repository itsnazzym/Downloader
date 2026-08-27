import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/spacing.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import '../../presentation/providers/filtered_downloads_provider.dart';
import '../../presentation/providers/downloader_provider.dart';

import 'inspector/download_inspector.dart';
import 'widgets/download_list.dart';
import 'package:modern_downloader/core/ui/cupertino_search_bar.dart';
import 'package:modern_downloader/core/ui/layout/pane_layout_provider.dart';
import 'package:modern_downloader/core/ui/widgets/resizable_width_pane.dart';

class DownloadView extends ConsumerWidget {
  const DownloadView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 3-Column Layout: [Sidebar (handled by Shell)] [Main List] [Inspector]
    return Row(
      children: [
        // Main Content (List)
        Expanded(
          child: Column(
            children: [
              // Top Bar (Search / Filter)
              const _DownloadTopBar(),

              // Divider
              Divider(height: 1, color: AppColors.of(context).border),

              // List
              const Expanded(child: DownloadList()),
            ],
          ),
        ),

        // Inspector Panel (Conditional or Always visible but empty?)
        // Design Doc says "Inspector appears on selection".
        // We will show it if an item is selected.
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
                ref.read(paneLayoutProvider.notifier).setInspectorWidth(width);
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
                        ref.read(paneLayoutProvider.notifier).expandInspector();
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

class _DownloadTopBar extends ConsumerWidget {
  const _DownloadTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.of(context).isIosChrome
          ? AppColors.of(context).background.withValues(alpha: 0.35)
          : AppColors.of(context).background,
      child: Row(
        children: [
          Expanded(
            child: _SearchBar(
              onChanged: (value) {
                ref.read(downloadSearchQueryProvider.notifier).state = value;
              },
            ),
          ),
          const SizedBox(width: 12),
          // Refresh Library
          IconButton(
            onPressed: () async {
              ref.read(downloadListProvider.notifier).refreshLibrary();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.refreshLibrary),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: Icon(
              Icons.refresh,
              size: 20,
              color: AppColors.of(context).textSecondary,
            ),
            tooltip: l10n.refreshLibrary,
          ),
          const SizedBox(width: 8),
          // Clear History
          IconButton(
            onPressed: () {
              // Confirm dialog
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
            },
            icon: Icon(
              Icons.delete_sweep_outlined,
              size: 20,
              color: AppColors.of(context).textSecondary,
            ),
            tooltip: l10n.clearHistory,
          ),
          const SizedBox(width: 8),

          // View Mode & Sort Menu
          PopupMenuButton<String>(
            icon: Icon(
              Icons.sort,
              size: 20,
              color: AppColors.of(context).textSecondary,
            ),
            tooltip: l10n.sortAndView,
            itemBuilder: (context) {
              final currentSort = ref.read(downloadSortProvider);
              final currentMode = ref.read(downloadViewModeProvider);

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
                CheckedPopupMenuItem(
                  checked: currentSort == DownloadSort.dateDesc,
                  value: 'dateDesc',
                  child: Text(
                    l10n.sortDateNewest,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () => ref.read(downloadSortProvider.notifier).state =
                      DownloadSort.dateDesc,
                ),
                CheckedPopupMenuItem(
                  checked: currentSort == DownloadSort.dateAsc,
                  value: 'dateAsc',
                  child: Text(
                    l10n.sortDateOldest,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () => ref.read(downloadSortProvider.notifier).state =
                      DownloadSort.dateAsc,
                ),
                CheckedPopupMenuItem(
                  checked: currentSort == DownloadSort.nameAsc,
                  value: 'nameAsc',
                  child: Text(
                    l10n.sortNameAsc,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () => ref.read(downloadSortProvider.notifier).state =
                      DownloadSort.nameAsc,
                ),
                CheckedPopupMenuItem(
                  checked: currentSort == DownloadSort.sizeDesc,
                  value: 'sizeDesc',
                  child: Text(
                    l10n.sortSizeLargest,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () => ref.read(downloadSortProvider.notifier).state =
                      DownloadSort.sizeDesc,
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
                  checked: currentMode == DownloadViewMode.list,
                  value: 'list',
                  child: Text(
                    l10n.viewList,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () =>
                      ref.read(downloadViewModeProvider.notifier).state =
                          DownloadViewMode.list,
                ),
                CheckedPopupMenuItem(
                  checked: currentMode == DownloadViewMode.detailed,
                  value: 'detailed',
                  child: Text(
                    l10n.viewDetailed,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () =>
                      ref.read(downloadViewModeProvider.notifier).state =
                          DownloadViewMode.detailed,
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends ConsumerStatefulWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppColors.of(context).isIosChrome) {
      return CupertinoSearchBar(
        controller: _controller,
        placeholder: context.l10n.searchDownloads,
        onChanged: widget.onChanged,
        onSubmitted: widget.onChanged,
      );
    }

    return Container(
      height: 32,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: AppRadius.controlOf(context),
        border: Border.all(color: AppColors.of(context).border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(
            Icons.search,
            size: 16,
            color: AppColors.of(context).textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.of(context).textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: context.l10n.searchDownloads,
                hintStyle: TextStyle(
                  color: AppColors.of(context).textSecondary,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: widget.onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
