import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/ui/widgets/custom_empty_state.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import '../../../../../core/design_system/foundation/colors.dart';
import '../../../../../core/design_system/foundation/spacing.dart';
import '../../../../../core/design_system/foundation/typography.dart';
import '../../providers/creator_folders_provider.dart';
import '../../providers/downloader_provider.dart';
import '../../providers/filtered_downloads_provider.dart';
import 'creator_folder_content_view.dart';
import 'creator_folder_grid.dart';
import 'download_item_skeleton.dart';
import 'download_row_host.dart';

/// Main reactive download list/grid view component.
/// Displays items according to viewMode (folders, detailed grid, or linear reorderable list).
class DownloadList extends ConsumerWidget {
  const DownloadList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final searchQuery = ref.watch(downloadSearchQueryProvider);
    final statusFilter = ref.watch(downloadStatusFilterProvider);
    final listPhase = ref.watch(filteredDownloadListPhaseProvider);
    final idList = ref.watch(filteredDownloadIdListProvider);
    final viewMode = ref.watch(downloadViewModeProvider);
    final isReorderEnabled =
        searchQuery.isEmpty &&
        statusFilter == DownloadStatusFilter.all &&
        idList.ids.length <= 50;

    ref.listen(downloadViewModeProvider, (previous, next) {
      if (next != DownloadViewMode.folders) {
        ref.read(openedCreatorFolderKeyProvider.notifier).state = null;
      }
    });
    ref.listen(creatorFoldersProvider, (previous, next) {
      final opened = ref.read(openedCreatorFolderKeyProvider);
      if (opened == null) return;
      if (!next.folders.any((folder) => folder.key == opened)) {
        ref.read(openedCreatorFolderKeyProvider.notifier).state = null;
      }
    });

    return listPhase.when(
      loading: () => ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.m),
        itemCount: 5,
        separatorBuilder: (ctx, i) => const Gap(AppSpacing.s),
        itemBuilder: (context, index) => const DownloadItemSkeleton(),
      ),

      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.of(context).error,
            ),
            const Gap(AppSpacing.m),
            Text(
              l10n.error,
              style: AppTypography.body.copyWith(
                color: AppColors.of(context).textPrimary,
              ),
            ),
            const Gap(AppSpacing.s),
            Text(
              error.toString(),
              style: AppTypography.caption.copyWith(
                color: AppColors.of(context).error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),

      data: (count) {
        if (count == 0) {
          final isFiltered =
              searchQuery.isNotEmpty ||
              statusFilter != DownloadStatusFilter.all;
          return CustomEmptyState(
            title: isFiltered ? l10n.noResults : l10n.yourListIsEmpty,
            icon: Icons.inbox_outlined,
          );
        }

        final ids = idList.ids;

        if (viewMode == DownloadViewMode.folders) {
          final opened = ref.watch(openedCreatorFolderProvider);
          if (opened == null) {
            return const CreatorFolderGrid();
          }
          return CreatorFolderContentView(folder: opened);
        }

        if (viewMode == DownloadViewMode.detailed) {
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.m),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              mainAxisExtent: 280,
              crossAxisSpacing: AppSpacing.m,
              mainAxisSpacing: AppSpacing.m,
            ),
            itemCount: ids.length,
            itemBuilder: (context, index) {
              final id = ids[index];
              return DownloadRowHost(
                key: ValueKey(id),
                id: id,
                useGridCard: true,
              );
            },
          );
        }

        if (!isReorderEnabled) {
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.m),
            itemCount: ids.length,
            separatorBuilder: (ctx, i) => const Gap(AppSpacing.s),
            itemBuilder: (context, index) {
              final id = ids[index];
              return DownloadRowHost(key: ValueKey(id), id: id);
            },
          );
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.all(AppSpacing.m),
          itemCount: ids.length,
          proxyDecorator: (widget, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (BuildContext context, Widget? child) {
                final double animValue = Curves.easeInOut.transform(
                  animation.value,
                );
                final double elevation = lerpDouble(0, 6, animValue)!;
                return Material(
                  elevation: elevation,
                  color: Colors.transparent,
                  shadowColor: Colors.black.withValues(alpha: 0.5),
                  child: widget,
                );
              },
              child: widget,
            );
          },
          onReorderItem: (oldIndex, newIndex) {
            ref.read(downloadListProvider.notifier).reorder(oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final id = ids[index];

            return Container(
              key: ValueKey(id),
              margin: const EdgeInsets.only(bottom: AppSpacing.s),
              child: DownloadRowHost(id: id),
            );
          },
        );
      },
    );
  }
}
