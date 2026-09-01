import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/ui/blur_container.dart';
import 'package:modern_downloader/theme/ios_theme.dart';
import '../../domain/entities/download_item.dart';
import 'package:modern_downloader/core/design_system/components/status_badge.dart';
import 'package:modern_downloader/core/download/extraction_placeholders.dart';
import 'download_item_display.dart';
import 'progress_bar.dart';

class DownloadCard extends StatelessWidget {
  final DownloadItem item;
  final VoidCallback? onCancel;
  final VoidCallback? onPause;
  final VoidCallback? onRetry;
  final VoidCallback? onTap;
  final bool isSelected;

  const DownloadCard({
    super.key,
    required this.item,
    this.onCancel,
    this.onPause,
    this.onRetry,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final sizeLabel = DownloadItemDisplay.size(context, item);
    return GestureDetector(
      onTap: onTap,
      child: RepaintBoundary(
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: isSelected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(IOSTheme.kRadiusMedium),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                )
              : null,
          child: BlurContainer(
            borderRadius: IOSTheme.kRadiusMedium,
            color: colors.glassFill,
            useBlur: false,
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          ExtractionPlaceholders.showThumbnailSpinner(
                            status: item.status,
                            thumbnailUrl: item.thumbnailUrl,
                          )
                          ? Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: colors.primary,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.play_circle_fill_rounded,
                              color: colors.primary,
                              size: 28,
                            ),
                    ),
                    const Gap(14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DownloadItemDisplay.title(context, item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label.copyWith(
                              color: isSelected
                                  ? colors.primary
                                  : colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Gap(4),
                          Row(
                            children: [
                              StatusBadge(
                                status: item.status,
                                error: item.error,
                              ),
                              const Gap(8),
                              if (item.step.isNotEmpty && sizeLabel.isEmpty)
                                Flexible(
                                  child: Text(
                                    item.step,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                              if (sizeLabel.isNotEmpty)
                                Text(
                                  item.downloadedSize.isNotEmpty
                                      ? '${item.downloadedSize}/$sizeLabel'
                                      : sizeLabel,
                                  style: AppTypography.mono.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              if (DownloadItemDisplay.showSpeed(item)) ...[
                                if (sizeLabel.isNotEmpty) const Gap(6),
                                Text(
                                  item.speed,
                                  style: AppTypography.mono.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                              if (item.eta.isNotEmpty &&
                                  DownloadItemDisplay.isActive(item)) ...[
                                const Gap(4),
                                Text(
                                  'ETA ${item.eta}',
                                  style: AppTypography.mono.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (DownloadItemDisplay.isActive(item)) ...[
                      if (onCancel != null)
                        _buildActionButton(
                          context,
                          icon: Icons.close_rounded,
                          onTap: onCancel!,
                          color: colors.surfaceHighlight,
                        ),
                    ] else if (DownloadItemDisplay.isTerminal(item)) ...[
                      if (onRetry != null)
                        _buildActionButton(
                          context,
                          icon: Icons.restart_alt_rounded,
                          onTap: onRetry!,
                          color: colors.primary,
                        ),
                      const Gap(8),
                      if (onCancel != null)
                        _buildActionButton(
                          context,
                          icon: Icons.delete_outline_rounded,
                          onTap: onCancel!,
                          color: colors.error,
                        ),
                    ],
                  ],
                ),
                const Gap(16),
                ProgressBar(progress: item.progress),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: colors.textPrimary),
      ),
    );
  }
}
