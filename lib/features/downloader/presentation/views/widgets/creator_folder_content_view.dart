import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../../../core/design_system/foundation/spacing.dart';
import '../../models/creator_folder.dart';
import '../../providers/creator_folders_provider.dart';
import '../../providers/filtered_downloads_provider.dart';
import 'creator_folder_grid.dart';
import 'download_row_host.dart';

class CreatorFolderContentView extends ConsumerWidget {
  final CreatorFolder folder;

  const CreatorFolderContentView({super.key, required this.folder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderIds = ref.watch(openedCreatorFolderItemIdsProvider).ids;
    final contentsMode = ref.watch(folderContentsViewModeProvider);
    final useGrid = contentsMode == DownloadViewMode.detailed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CreatorFolderOpenHeader(folder: folder),
        Expanded(
          child: useGrid
              ? GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    mainAxisExtent: 280,
                    crossAxisSpacing: AppSpacing.m,
                    mainAxisSpacing: AppSpacing.m,
                  ),
                  itemCount: folderIds.length,
                  itemBuilder: (context, index) {
                    final id = folderIds[index];
                    return DownloadRowHost(
                      key: ValueKey(id),
                      id: id,
                      useGridCard: true,
                    );
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  itemCount: folderIds.length,
                  separatorBuilder: (ctx, i) => const Gap(AppSpacing.s),
                  itemBuilder: (context, index) {
                    final id = folderIds[index];
                    return DownloadRowHost(key: ValueKey(id), id: id);
                  },
                ),
        ),
      ],
    );
  }
}
