import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/theme/app_typography.dart';
import '../../../providers/download_library_counts.dart';
import '../../../providers/filtered_downloads_provider.dart';

class MobileFilterChipsBar extends ConsumerWidget {
  const MobileFilterChipsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final statusFilter = ref.watch(downloadStatusFilterProvider);
    final viewMode = ref.watch(downloadViewModeProvider);
    final counts = ref.watch(downloadLibraryCountsProvider);

    final isFolders = viewMode == DownloadViewMode.folders;

    return Container(
      color: colors.surface.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _buildChip(
              label: 'Tout (${counts.total})',
              isSelected: !isFolders && statusFilter == DownloadStatusFilter.all,
              onTap: () {
                if (isFolders) {
                  ref.read(downloadViewModeProvider.notifier).state =
                      DownloadViewMode.list;
                }
                ref.read(downloadStatusFilterProvider.notifier).state =
                    DownloadStatusFilter.all;
              },
              colors: colors,
            ),
            const SizedBox(width: 8),
            _buildChip(
              label: 'En cours',
              badge: counts.active > 0 ? '${counts.active}' : null,
              badgeColor: colors.primary,
              isSelected:
                  !isFolders && statusFilter == DownloadStatusFilter.active,
              onTap: () {
                if (isFolders) {
                  ref.read(downloadViewModeProvider.notifier).state =
                      DownloadViewMode.list;
                }
                ref.read(downloadStatusFilterProvider.notifier).state =
                    DownloadStatusFilter.active;
              },
              colors: colors,
            ),
            const SizedBox(width: 8),
            _buildChip(
              label: 'Terminés (${counts.completed})',
              isSelected:
                  !isFolders && statusFilter == DownloadStatusFilter.completed,
              onTap: () {
                if (isFolders) {
                  ref.read(downloadViewModeProvider.notifier).state =
                      DownloadViewMode.list;
                }
                ref.read(downloadStatusFilterProvider.notifier).state =
                    DownloadStatusFilter.completed;
              },
              colors: colors,
            ),
            const SizedBox(width: 8),
            _buildChip(
              label: 'Échecs',
              badge: counts.failed > 0 ? '${counts.failed}' : null,
              badgeColor: colors.warning,
              isSelected:
                  !isFolders && statusFilter == DownloadStatusFilter.failed,
              onTap: () {
                if (isFolders) {
                  ref.read(downloadViewModeProvider.notifier).state =
                      DownloadViewMode.list;
                }
                ref.read(downloadStatusFilterProvider.notifier).state =
                    DownloadStatusFilter.failed;
              },
              colors: colors,
            ),
            const SizedBox(width: 8),
            _buildChip(
              label: 'Dossiers',
              icon: Icons.folder_rounded,
              isSelected: isFolders,
              onTap: () {
                if (isFolders) {
                  ref.read(downloadViewModeProvider.notifier).state =
                      DownloadViewMode.list;
                } else {
                  ref.read(downloadViewModeProvider.notifier).state =
                      DownloadViewMode.folders;
                }
              },
              colors: colors,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required AppColors colors,
    String? badge,
    Color? badgeColor,
    IconData? icon,
  }) {
    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        onTap();
      },
      avatar: icon != null
          ? Icon(
              icon,
              size: 16,
              color: isSelected ? colors.primary : colors.textSecondary,
            )
          : null,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? colors.primary : colors.textSecondary,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: (badgeColor ?? colors.primary).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: AppTypography.mono.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: badgeColor ?? colors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
      selectedColor: colors.primary.withValues(alpha: 0.15),
      backgroundColor: colors.surface,
      side: BorderSide(
        color: isSelected
            ? colors.primary.withValues(alpha: 0.5)
            : colors.border.withValues(alpha: 0.4),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}
