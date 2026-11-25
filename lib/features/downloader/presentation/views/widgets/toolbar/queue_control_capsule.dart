import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import '../../../../domain/enums/download_status.dart';
import '../../../providers/download_library_counts.dart';
import '../../../providers/downloader_provider.dart';

class QueueControlCapsule extends ConsumerWidget {
  const QueueControlCapsule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final activeCount = ref.watch(
      downloadLibraryCountsProvider.select((c) => c.active),
    );
    // Disabled when there is nothing to act on, so no "done" toast lies.
    final hasResumable = ref.watch(
      downloadListProvider.select(
        (s) => (s.valueOrNull ?? const []).any(
          (i) =>
              i.status == DownloadStatus.queued ||
              i.status == DownloadStatus.paused ||
              i.status == DownloadStatus.failed,
        ),
      ),
    );

    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pause All Active
          Tooltip(
            message: l10n.pauseActiveTooltip,
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(7),
              ),
              onTap: activeCount == 0
                  ? null
                  : () async {
                      await ref
                          .read(downloadListProvider.notifier)
                          .pauseAllActive();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.activeDownloadsPaused),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pause_rounded,
                      size: 18,
                      color: activeCount > 0
                          ? colors.textPrimary
                          : colors.textSecondary.withValues(alpha: 0.5),
                    ),
                    if (activeCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$activeCount',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 16,
            color: colors.border.withValues(alpha: 0.6),
          ),
          // Resume All Queue
          Tooltip(
            message: l10n.startQueueTooltip,
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(7),
              ),
              onTap: !hasResumable
                  ? null
                  : () async {
                      await ref
                          .read(downloadListProvider.notifier)
                          .resumeAllQueued();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.queueStarted),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 18,
                  color: hasResumable
                      ? colors.primary
                      : colors.textSecondary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
