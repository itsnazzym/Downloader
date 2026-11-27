import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:tapload/core/design_system/foundation/colors.dart';
import 'package:tapload/core/design_system/foundation/typography.dart';
import 'package:tapload/features/downloader/presentation/models/creator_folder.dart';
import 'package:tapload/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:tapload/features/downloader/presentation/views/widgets/creator_folder_tile.dart';
import 'package:tapload/l10n/l10n_ext.dart';

class CreatorFolderGrid extends ConsumerWidget {
  const CreatorFolderGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(creatorFoldersProvider).folders;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 176,
        mainAxisExtent: 214,
        crossAxisSpacing: 22,
        mainAxisSpacing: 26,
      ),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        return CreatorFolderTile(
          key: ValueKey(folder.key),
          folder: folder,
          staggerIndex: index,
          onOpen: () {
            ref.read(openedCreatorFolderKeyProvider.notifier).state =
                folder.key;
            ref.read(selectedDownloadIdProvider.notifier).state = null;
          },
        );
      },
    );
  }
}

class CreatorFolderOpenHeader extends ConsumerWidget {
  const CreatorFolderOpenHeader({super.key, required this.folder});

  final CreatorFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final title = folder.isUnknown
        ? l10n.folderUnknownCreator
        : '@${folder.handle}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 20, 8),
          child: Row(
            children: [
              Tooltip(
                message: l10n.folderBack,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      ref.read(openedCreatorFolderKeyProvider.notifier).state =
                          null;
                      ref.read(selectedDownloadIdProvider.notifier).state =
                          null;
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Ink(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: colors.surfaceHighlight.withValues(alpha: 0.7),
                        border: Border.all(
                          color: AppColors.of(context).textPrimary.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: colors.textPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        height: 1.15,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      l10n.folderVideoCount(folder.count),
                      style: AppTypography.mono.copyWith(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(8),
              _FolderContentsViewToggle(
                mode: ref.watch(folderContentsViewModeProvider),
                onChanged: (mode) {
                  ref.read(folderContentsViewModeProvider.notifier).state =
                      mode;
                },
              ),
            ],
          ),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: AppColors.of(context).textPrimary.withValues(alpha: 0.06),
        ),
      ],
    );
  }
}

class _FolderContentsViewToggle extends StatelessWidget {
  const _FolderContentsViewToggle({
    required this.mode,
    required this.onChanged,
  });

  final DownloadViewMode mode;
  final ValueChanged<DownloadViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final detailed = mode == DownloadViewMode.detailed;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colors.surfaceHighlight.withValues(alpha: 0.7),
        border: Border.all(color: AppColors.of(context).textPrimary.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleGlyph(
              tooltip: l10n.viewList,
              icon: Icons.view_agenda_rounded,
              selected: !detailed,
              onTap: () => onChanged(DownloadViewMode.list),
            ),
            _ToggleGlyph(
              tooltip: l10n.viewDetailed,
              icon: Icons.grid_view_rounded,
              selected: detailed,
              onTap: () => onChanged(DownloadViewMode.detailed),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleGlyph extends StatelessWidget {
  const _ToggleGlyph({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            width: 32,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: selected
                  ? colors.primary.withValues(alpha: 0.22)
                  : Colors.transparent,
            ),
            child: Icon(
              icon,
              size: 16,
              color: selected
                  ? colors.primary
                  : colors.textSecondary.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}
