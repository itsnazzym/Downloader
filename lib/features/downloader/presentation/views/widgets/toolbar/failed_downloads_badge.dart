import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import '../../../providers/download_library_counts.dart';
import '../../../providers/downloader_provider.dart';

class FailedDownloadsBadge extends ConsumerWidget {
  final bool compact;

  const FailedDownloadsBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failedCount = ref.watch(
      downloadLibraryCountsProvider.select((c) => c.failed),
    );
    if (failedCount == 0) return const SizedBox.shrink();

    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: 'Relancer tous les téléchargements en échec ($failedCount)',
        child: Material(
          color: colors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              await ref.read(downloadListProvider.notifier).retryAllFailed();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Relance de $failedCount téléchargement(s) en échec',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Container(
              height: 34,
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.replay_rounded,
                    size: 15,
                    color: colors.warning,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    compact
                        ? '$failedCount'
                        : '$failedCount ${failedCount > 1 ? "échecs" : "échec"} · Relancer',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
