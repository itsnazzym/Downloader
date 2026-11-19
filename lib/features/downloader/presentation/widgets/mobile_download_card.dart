import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/download/download_file_resolver.dart';
import 'package:modern_downloader/core/download/extraction_placeholders.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/core/ui/mobile/oled/oled_kit.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/core/download/download_status_guard.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/age_verification_help_dialog.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

/// Touch-first library row for the Android OLED interface.
/// Hairline-outlined card with swipe-to-delete, haptic feedback, a hairline
/// progress line while active, and a compact status on the trailing edge.
class MobileDownloadCard extends ConsumerWidget {
  final DownloadItem item;
  final VoidCallback onTap;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const MobileDownloadCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onRetry,
    required this.onCancel,
  });

  static const double _radius = 18;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;

    final isActive =
        item.status == DownloadStatus.downloading ||
        item.status == DownloadStatus.extracting ||
        item.status == DownloadStatus.processing;
    final isFailed = item.status == DownloadStatus.failed;
    final isCompleted = item.status == DownloadStatus.completed;
    final isQueued = item.status == DownloadStatus.queued;
    // Rank among the waiting items, in list order. Other rows ignore changes.
    final int? queuePosition = isQueued
        ? ref.watch(
            downloadListProvider.select((state) {
              var rank = 0;
              for (final d in state.valueOrNull ?? const <DownloadItem>[]) {
                if (d.status != DownloadStatus.queued) continue;
                rank++;
                if (d.id == item.id) return rank;
              }
              return null;
            }),
          )
        : null;

    final displayTitle =
        item.status == DownloadStatus.extracting &&
            ExtractionPlaceholders.isGenericTitle(item.title)
        ? l10n.extractingTitle
        : TitleCleanerService.clean(item.title ?? l10n.unknown);

    final playablePath = DownloadFileResolver.resolvePlayablePath(
      item.filePath,
      title: item.title,
      outputFolder: item.request.outputFolder,
    );

    final isAgeFailure =
        isFailed &&
        item.error != null &&
        DownloadStatusGuard.isAgeVerificationFailure(
          error: item.error,
          url: item.request.url,
        );

    return Dismissible(
      key: ValueKey('dismiss_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: t.warn.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: t.warn.withValues(alpha: 0.5)),
        ),
        child: Icon(Icons.delete_outline_rounded, color: t.warn, size: 24),
      ),
      confirmDismiss: (direction) async {
        unawaited(HapticFeedback.mediumImpact());
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.delete),
                content: Text(l10n.downloadCardDeleteConfirm(displayTitle)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: t.warn,
                      foregroundColor: t.onInk,
                    ),
                    child: Text(l10n.delete),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) {
        onCancel();
      },
      child: Material(
        color: t.fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(
            color: isFailed ? t.warn.withValues(alpha: 0.4) : t.line,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Row(
                      children: [
                        _buildThumbnail(
                          context,
                          t,
                          l10n,
                          isCompleted,
                          isFailed,
                          playablePath,
                          ref,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: OledText.ui(
                                  context,
                                  size: 14,
                                  weight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _buildMetaText(l10n),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: OledText.ui(
                                  context,
                                  size: 12,
                                  weight: isFailed
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  color: isFailed ? t.warn : t.ink2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildTrailing(
                          context,
                          t,
                          l10n,
                          isCompleted,
                          isFailed,
                          isActive,
                          isQueued,
                          queuePosition,
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    _HairlineProgress(
                      value: item.progress,
                      trackColor: t.line,
                      barColor: t.ink,
                    ),
                ],
              ),
            ),
            if (isAgeFailure)
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  AgeVerificationHelpDialog.show(context, item);
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: t.warn.withValues(alpha: 0.25)),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: t.warn),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.downloadCardAgeVerification,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OledText.ui(
                              context,
                              size: 12,
                              weight: FontWeight.w600,
                              color: t.warn,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: t.warn,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isRemoteUrl(String uri) =>
      uri.startsWith('http://') || uri.startsWith('https://');

  Widget _buildThumbnail(
    BuildContext context,
    OledTokens t,
    AppLocalizations l10n,
    bool isCompleted,
    bool isFailed,
    String? playablePath,
    WidgetRef ref,
  ) {
    final thumbUrl = item.thumbnailUrl;

    Widget thumb;
    if (thumbUrl != null && thumbUrl.isNotEmpty && !_isRemoteUrl(thumbUrl)) {
      thumb = SizedBox(
        width: 72,
        height: 42,
        child: Stack(
          fit: StackFit.expand,
          children: [
            OledThumb(warn: isFailed),
            Padding(
              padding: const EdgeInsets.all(1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.file(
                  File(thumbUrl),
                  fit: BoxFit.cover,
                  cacheWidth: 216,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      thumb = OledThumb(url: thumbUrl, warn: isFailed);
    }

    if (!isCompleted) return thumb;

    return Semantics(
      button: true,
      label: l10n.openFile,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          if (playablePath != null && File(playablePath).existsSync()) {
            ref.read(mediaPlayerProvider.notifier).openFile(playablePath);
          } else {
            onTap();
          }
        },
        child: SizedBox(
          width: 72,
          height: 42,
          child: Stack(
            fit: StackFit.expand,
            children: [
              thumb,
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.bg.withValues(alpha: 0.6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 18,
                      color: t.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildMetaText(AppLocalizations l10n) {
    final source = item.source.isNotEmpty ? item.source : 'Web';
    final parts = <String>[source];

    if (item.status == DownloadStatus.completed) {
      final size = item.totalSize.isNotEmpty
          ? item.totalSize
          : item.downloadedSize;
      if (size.isNotEmpty) parts.add(size);
    } else if (item.status == DownloadStatus.failed) {
      return l10n.downloadCardFailedMeta(source);
    } else if (item.status == DownloadStatus.paused) {
      parts.add(l10n.statusPaused);
    } else if (item.status == DownloadStatus.queued) {
      parts.add(l10n.statusQueued);
    } else if (item.status == DownloadStatus.extracting) {
      parts.add(l10n.statusExtracting);
    } else if (item.totalSize.isNotEmpty && item.downloadedSize.isNotEmpty) {
      parts.add(l10n.downloadCardSizeOf(item.downloadedSize, item.totalSize));
    } else if (item.downloadedSize.isNotEmpty) {
      parts.add(item.downloadedSize);
    } else {
      parts.add(l10n.statusDownloading);
    }
    return parts.join(', ');
  }

  Widget _buildTrailing(
    BuildContext context,
    OledTokens t,
    AppLocalizations l10n,
    bool isCompleted,
    bool isFailed,
    bool isActive,
    bool isQueued,
    int? queuePosition,
  ) {
    if (isCompleted) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(shape: BoxShape.circle, color: t.ink),
          child: Icon(Icons.check_rounded, size: 16, color: t.onInk),
        ),
      );
    }
    if (isFailed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RowAction(
            icon: Icons.refresh_rounded,
            tooltip: l10n.retry,
            color: t.warn,
            onPressed: () {
              HapticFeedback.mediumImpact();
              onRetry();
            },
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: t.ink3),
          const SizedBox(width: 4),
        ],
      );
    }
    if (isActive) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.progress > 0)
            Text(
              '${(item.progress * 100).round()} %',
              style: OledText.ui(context, size: 13, weight: FontWeight.w600),
            ),
          _RowAction(
            icon: Icons.close_rounded,
            tooltip: l10n.cancel,
            color: t.ink2,
            onPressed: () {
              HapticFeedback.lightImpact();
              onCancel();
            },
          ),
        ],
      );
    }
    if (isQueued) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: queuePosition == null
            ? Icon(Icons.schedule_rounded, size: 20, color: t.ink2)
            : Semantics(
                label: l10n.downloadCardQueuePosition(queuePosition),
                child: Text(
                  '#$queuePosition',
                  style: OledText.ui(
                    context,
                    size: 14,
                    weight: FontWeight.w600,
                    color: t.ink2,
                  ),
                ),
              ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(Icons.chevron_right_rounded, size: 20, color: t.ink3),
    );
  }
}

/// 40x44 tap target with a bare icon, used for retry / cancel on a row.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: 22,
        child: SizedBox(
          width: 40,
          height: 44,
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

/// 2px determinate progress line flush with the bottom edge of the row.
class _HairlineProgress extends StatelessWidget {
  const _HairlineProgress({
    required this.value,
    required this.trackColor,
    required this.barColor,
  });

  final double value;
  final Color trackColor;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, box) {
        return SizedBox(
          height: 2,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: trackColor)),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: box.maxWidth * v,
                child: ColoredBox(color: barColor),
              ),
            ],
          ),
        );
      },
    );
  }
}
