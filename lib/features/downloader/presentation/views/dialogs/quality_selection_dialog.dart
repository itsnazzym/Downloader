import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/design_system/components/app_button.dart';
import 'package:modern_downloader/core/design_system/foundation/colors.dart';
import 'package:modern_downloader/core/design_system/foundation/spacing.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

class QualitySelectionDialog extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final String title;

  const QualitySelectionDialog({
    super.key,
    required this.metadata,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formats = (metadata['formats'] as List? ?? [])
        .map((f) => Map<String, dynamic>.from(f as Map))
        .where((f) => f['vcodec'] != 'none') // Filter for video formats
        .toList();

    // Sort by resolution (height) descending
    formats.sort((a, b) {
      final ha = a['height'] as int? ?? 0;
      final hb = b['height'] as int? ?? 0;
      return hb.compareTo(ha);
    });

    return Dialog(
      backgroundColor: AppColors.of(context).surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.of(context).border),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.high_quality, color: AppColors.of(context).primary),
                const Gap(AppSpacing.m),
                Expanded(
                  child: Text(
                    l10n.selectQuality,
                    style: AppTypography.h3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Gap(4),
            Text(
              title,
              style: AppTypography.caption.copyWith(
                color: AppColors.of(context).textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(AppSpacing.l),
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.of(context).surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.of(context).border.withValues(alpha: 0.5),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: formats.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: AppColors.of(context).border),
                  itemBuilder: (context, index) {
                    final f = formats[index];
                    final formatId = f['format_id'] as String;
                    final ext = f['ext'] as String? ?? 'unknown';
                    final resolution =
                        f['resolution'] as String? ??
                        "${f['width'] ?? '?'}x${f['height'] ?? '?'}";
                    final size =
                        f['filesize'] as int? ?? f['filesize_approx'] as int?;
                    final sizeStr = size != null
                        ? _formatSize(size)
                        : l10n.unknownSize;
                    final isBest = index == 0;

                    return ListTile(
                      dense: true,
                      onTap: () => Navigator.of(context).pop(formatId),
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isBest
                              ? AppColors.of(
                                  context,
                                ).primary.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isBest
                                ? AppColors.of(
                                    context,
                                  ).primary.withValues(alpha: 0.3)
                                : AppColors.of(context).border,
                          ),
                        ),
                        child: Text(
                          ext.toUpperCase(),
                          style: AppTypography.mono.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isBest
                                ? AppColors.of(context).primary
                                : AppColors.of(context).textSecondary,
                          ),
                        ),
                      ),
                      title: Text(
                        resolution,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        sizeStr,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.of(context).textSecondary,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: AppColors.of(context).textDisabled,
                      ),
                    );
                  },
                ),
              ),
            ),
            const Gap(AppSpacing.l),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton.ghost(
                  label: l10n.cancel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Gap(AppSpacing.s),
                AppButton.primary(
                  label: l10n.bestQuality,
                  onPressed: () => Navigator.of(context).pop('best'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return "${size.toStringAsFixed(1)} ${suffixes[i]}";
  }
}
