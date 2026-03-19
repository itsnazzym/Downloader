import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import '../../presentation/providers/filtered_downloads_provider.dart';
import '../../presentation/providers/downloader_provider.dart';

import 'inspector/download_inspector.dart';
import 'widgets/download_list.dart';

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
              Divider(height: 1, color: AppColors.border),

              // List
              Expanded(child: DownloadList()),
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

            return Container(
              width: 300,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: AppColors.border)),
                color: AppColors.surface,
              ),
              child: DownloadInspector(downloadId: selectedId),
            );
          },
        ),
      ],
    );
  }
}

class _DownloadTopBar extends ConsumerWidget {
  const _DownloadTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.background,
      child: Row(
        children: [
          Expanded(
            child: _SearchBar(
              onChanged: (value) {
                ref.read(downloadSearchQueryProvider.notifier).state = value;
              },
            ),
          ),
          SizedBox(width: 12),
          // Refresh Library
          IconButton(
            onPressed: () async {
              ref.read(downloadListProvider.notifier).refreshLibrary();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Refreshing library...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: Icon(Icons.refresh, size: 20, color: AppColors.textSecondary),
            tooltip: "Refresh Library",
          ),
          SizedBox(width: 8),
          // Clear History
          IconButton(
            onPressed: () {
              // Confirm dialog
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text("Clear History"),
                  content: Text(
                    "Remove all completed, failed, and canceled downloads? Active downloads will remain.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(downloadListProvider.notifier).clearHistory();
                        Navigator.pop(c);
                      },
                      child: Text(
                        "Clear",
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              );
            },
            icon: Icon(
              Icons.delete_sweep_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
            tooltip: "Clear History",
          ),
          SizedBox(width: 8),

          // View Mode & Sort Menu
          PopupMenuButton<String>(
            icon: Icon(Icons.sort, size: 20, color: AppColors.textSecondary),
            tooltip: "Sort & View",
            itemBuilder: (context) {
              final currentSort = ref.read(downloadSortProvider);
              final currentMode = ref.read(downloadViewModeProvider);

              return [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    "Sort By",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                CheckedPopupMenuItem(
                  checked: currentSort == DownloadSort.dateDesc,
                  value: 'dateDesc',
                  child: Text("Date (Newest)", style: TextStyle(fontSize: 13)),
                  onTap: () => ref.read(downloadSortProvider.notifier).state =
                      DownloadSort.dateDesc,
                ),
                CheckedPopupMenuItem(
                  checked: currentSort == DownloadSort.dateAsc,
                  value: 'dateAsc',
                  child: Text("Date (Oldest)", style: TextStyle(fontSize: 13)),
                  onTap: () => ref.read(downloadSortProvider.notifier).state =
                      DownloadSort.dateAsc,
                ),
                CheckedPopupMenuItem(
                  checked: currentSort == DownloadSort.nameAsc,
                  value: 'nameAsc',
                  child: Text("Name (A-Z)", style: TextStyle(fontSize: 13)),
                  onTap: () => ref.read(downloadSortProvider.notifier).state =
                      DownloadSort.nameAsc,
                ),
                CheckedPopupMenuItem(
                  checked: currentSort == DownloadSort.sizeDesc,
                  value: 'sizeDesc',
                  child: Text("Size (Largest)", style: TextStyle(fontSize: 13)),
                  onTap: () => ref.read(downloadSortProvider.notifier).state =
                      DownloadSort.sizeDesc,
                ),

                PopupMenuDivider(),
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    "View Mode",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                CheckedPopupMenuItem(
                  checked: currentMode == DownloadViewMode.list,
                  value: 'list',
                  child: Text("List", style: TextStyle(fontSize: 13)),
                  onTap: () =>
                      ref.read(downloadViewModeProvider.notifier).state =
                          DownloadViewMode.list,
                ),
                CheckedPopupMenuItem(
                  checked: currentMode == DownloadViewMode.detailed,
                  value: 'detailed',
                  child: Text("Detailed", style: TextStyle(fontSize: 13)),
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

class _SearchBar extends ConsumerWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We need to import the provider
    // Since I cannot easily add top-level imports in this specific Replace call without context of line 1-10
    // I will assume the previous imports are there, and I will add the import in a separate tool call if needed or use the providers directly if visible.

    // Actually, I'll update the user of this search bar to update the provider.
    return Container(
      height: 32,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: AppColors.textSecondary),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: "Search downloads...",
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.zero, // Important for centering in small height
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
