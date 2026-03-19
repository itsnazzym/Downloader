import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/theme/ios_theme.dart';
import 'package:modern_downloader/core/ui/blur_container.dart';
import '../../domain/entities/download_item.dart';
import '../../domain/enums/download_status.dart';
import 'progress_bar.dart';

class DownloadCard extends StatelessWidget {
  final DownloadItem item;
  final VoidCallback? onCancel;
  final VoidCallback? onPause;
  final VoidCallback? onRetry;

  const DownloadCard({
    super.key,
    required this.item,
    this.onCancel,
    this.onPause,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: BlurContainer(
        borderRadius: IOSTheme.kRadiusMedium,
        color: const Color(0x2E2C2C2E), // Custom lighter glass for cards
        child: Column(
          children: [
            Row(
              children: [
                // Thumbnail / Icon Placeholder
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: IOSTheme.systemBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: IOSTheme.systemBlue,
                    size: 28,
                  ),
                ),
                const Gap(14),
                // Titles
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title ?? 'Loading Metadata...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: IOSTheme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(4),
                      Row(
                        children: [
                          _buildBadge(
                            item.status.name.toUpperCase(),
                            IOSTheme.systemGreen,
                          ),
                          const Gap(8),
                          // Show step if no size info available (during extraction/merging)
                          if (item.step.isNotEmpty && item.totalSize.isEmpty)
                            Text(
                              item.step,
                              style: IOSTheme.textTheme.labelSmall?.copyWith(
                                color: IOSTheme.systemBlue,
                              ),
                            ),
                          // Show downloaded/total size if available
                          if (item.totalSize.isNotEmpty)
                            Text(
                              item.downloadedSize.isNotEmpty
                                  ? '${item.downloadedSize}/${item.totalSize}'
                                  : item.totalSize,
                              style: IOSTheme.textTheme.labelSmall,
                            ),
                          if (item.totalSize.isNotEmpty &&
                              item.speed.isNotEmpty)
                            const Gap(6),
                          Text(
                            item.speed.isNotEmpty ? item.speed : '',
                            style: IOSTheme.textTheme.labelSmall,
                          ),
                          if (item.eta.isNotEmpty) ...[
                            const Gap(4),
                            Text('•', style: IOSTheme.textTheme.labelSmall),
                            const Gap(4),
                            Text(
                              'ETA: ${item.eta}',
                              style: IOSTheme.textTheme.labelSmall,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Action - only show for active downloads
                if (_isActive(item)) ...[
                  if (onCancel != null)
                    _buildActionButton(
                      icon: Icons.close_rounded,
                      onTap: onCancel!,
                      color: IOSTheme.systemGray3,
                    ),
                ] else if (item.status == DownloadStatus.failed ||
                    item.status == DownloadStatus.canceled) ...[
                  if (onRetry != null && item.status != DownloadStatus.canceled)
                    _buildActionButton(
                      icon: Icons.refresh_rounded,
                      onTap: onRetry!,
                      color: IOSTheme.systemBlue,
                    ),
                  const Gap(8),
                  if (onCancel != null)
                    _buildActionButton(
                      icon: Icons.delete_outline_rounded,
                      onTap: onCancel!,
                      color: IOSTheme.systemRed,
                    ),
                ],
              ],
            ),
            const Gap(16),
            // Progress Bar (We need to update this widget separately or style it here)
            ProgressBar(progress: item.progress),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: IOSTheme.label),
      ),
    );
  }

  bool _isActive(DownloadItem item) {
    return item.status == DownloadStatus.queued ||
        item.status == DownloadStatus.extracting ||
        item.status == DownloadStatus.downloading;
  }
}
