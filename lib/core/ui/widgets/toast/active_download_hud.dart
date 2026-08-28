import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

final activeDownloadHudExpandedProvider = StateProvider<bool>((ref) => false);

bool _isActiveDownload(DownloadItem item) {
  switch (item.status) {
    case DownloadStatus.queued:
    case DownloadStatus.extracting:
    case DownloadStatus.downloading:
    case DownloadStatus.processing:
      return true;
    case DownloadStatus.completed:
    case DownloadStatus.failed:
    case DownloadStatus.canceled:
    case DownloadStatus.paused:
    case DownloadStatus.duplicate:
      return false;
  }
}

class ActiveDownloadHud extends ConsumerWidget {
  const ActiveDownloadHud({super.key});

  static const int maxVisibleCircles = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      downloadListProvider.select((async) {
        return async.maybeWhen(
          data: (items) => items.where(_isActiveDownload).toList(),
          orElse: () => <DownloadItem>[],
        );
      }),
    );
    final duplicatesSkipped = ref.watch(duplicateBatchCountProvider);

    ref.listen(downloadListProvider, (previous, next) {
      final hasActive = next.maybeWhen(
        data: (items) => items.any(_isActiveDownload),
        orElse: () => false,
      );
      if (!hasActive && ref.read(activeDownloadHudExpandedProvider)) {
        ref.read(activeDownloadHudExpandedProvider.notifier).state = false;
      }
    });

    if (active.isEmpty && duplicatesSkipped == 0) {
      return const SizedBox.shrink();
    }

    final expanded = ref.watch(activeDownloadHudExpandedProvider);
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final title = active.isEmpty
        ? l10n.duplicatesSkipped(duplicatesSkipped)
        : active.length == 1
        ? l10n.videoDownloadingSingular
        : l10n.videosDownloadingCount(active.length);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        key: const Key('active-download-hud'),
        color: colors.surface.withValues(alpha: 0.94),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.success.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    ref.read(activeDownloadHudExpandedProvider.notifier).state =
                        !expanded;
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.downloading_rounded,
                          color: colors.success,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Tooltip(
                          message: expanded
                              ? l10n.collapseDownloadingVideos
                              : l10n.expandDownloadingVideos,
                          child: Icon(
                            expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (duplicatesSkipped > 0 && active.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.duplicatesSkipped(duplicatesSkipped),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ],
                if (expanded && active.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 168),
                    child: SingleChildScrollView(
                      child: _ExpandedCircles(items: active, colors: colors),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedCircles extends StatelessWidget {
  const _ExpandedCircles({required this.items, required this.colors});

  final List<DownloadItem> items;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final visible = items.length > ActiveDownloadHud.maxVisibleCircles
        ? items.sublist(0, ActiveDownloadHud.maxVisibleCircles)
        : items;
    final overflow = items.length - visible.length;
    final l10n = context.l10n;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in visible) _DownloadCircle(item: item, colors: colors),
        if (overflow > 0)
          SizedBox(
            width: 52,
            height: 64,
            child: Center(
              child: Text(
                l10n.moreDownloadingVideos(overflow),
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DownloadCircle extends StatelessWidget {
  const _DownloadCircle({required this.item, required this.colors});

  final DownloadItem item;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final indeterminate =
        item.status == DownloadStatus.queued ||
        item.status == DownloadStatus.extracting;
    final progress = item.progress.clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final label = _labelFor(item);

    return Tooltip(
      message: label,
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: indeterminate ? null : progress,
                    strokeWidth: 3.2,
                    color: colors.success,
                    backgroundColor: colors.success.withValues(alpha: 0.18),
                  ),
                  Text(
                    indeterminate ? '…' : '$percent',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

String _labelFor(DownloadItem item) {
  try {
    final title = item.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    final uri = Uri.tryParse(item.request.url);
    if (uri == null) return item.request.url;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) return segments.last;
    if (uri.host.isNotEmpty) return uri.host;
    return item.request.url;
  } catch (_) {
    return item.request.url;
  }
}
