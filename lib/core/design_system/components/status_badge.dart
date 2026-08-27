import 'package:flutter/material.dart';
import '../foundation/colors.dart';
import '../foundation/spacing.dart';
import '../foundation/typography.dart';
import '../../../../features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

String downloadStatusLabel(BuildContext context, DownloadStatus status) {
  final l10n = context.l10n;
  switch (status) {
    case DownloadStatus.queued:
      return l10n.statusQueued;
    case DownloadStatus.downloading:
      return l10n.statusDownloading;
    case DownloadStatus.processing:
      return l10n.statusProcessing;
    case DownloadStatus.completed:
      return l10n.statusCompleted;
    case DownloadStatus.failed:
      return l10n.statusFailed;
    case DownloadStatus.canceled:
      return l10n.statusCanceled;
    case DownloadStatus.extracting:
      return l10n.statusExtracting;
    case DownloadStatus.paused:
      return l10n.statusPaused;
    case DownloadStatus.duplicate:
      return l10n.statusDuplicate;
  }
}

class StatusBadge extends StatelessWidget {
  final DownloadStatus status;
  final String? error;

  const StatusBadge({super.key, required this.status, this.error});

  @override
  Widget build(BuildContext context) {
    final Color color = _statusColor(context, status);
    final String label = downloadStatusLabel(context, status);

    return Tooltip(
      message: error ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.smallBorder,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, DownloadStatus status) {
    switch (status) {
      case DownloadStatus.queued:
        return AppColors.of(context).textSecondary;
      case DownloadStatus.downloading:
        return AppColors.of(context).primary;
      case DownloadStatus.processing:
        return AppColors.of(context).info;
      case DownloadStatus.completed:
        return AppColors.of(context).success;
      case DownloadStatus.failed:
        return AppColors.of(context).error;
      case DownloadStatus.canceled:
        return AppColors.of(context).textDisabled;
      case DownloadStatus.extracting:
        return AppColors.of(context).info;
      case DownloadStatus.paused:
        return AppColors.of(context).warning;
      case DownloadStatus.duplicate:
        return AppColors.of(context).warning;
    }
  }
}
