import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/design_system/foundation/colors.dart';
import 'package:modern_downloader/core/design_system/foundation/spacing.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/download/download_file_resolver.dart';
import 'package:modern_downloader/core/download/extraction_placeholders.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/core/download/download_status_guard.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/age_verification_help_dialog.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

/// Touch-first card component tailored specifically for mobile screens.
/// Features high-contrast progress states, 48px+ touch targets, swipe-to-delete,
/// and instant haptic feedback.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    final isActive = item.status == DownloadStatus.downloading ||
        item.status == DownloadStatus.extracting ||
        item.status == DownloadStatus.processing;
    final isFailed = item.status == DownloadStatus.failed;
    final isCompleted = item.status == DownloadStatus.completed;

    final displayTitle = item.status == DownloadStatus.extracting &&
            ExtractionPlaceholders.isGenericTitle(item.title)
        ? l10n.extractingTitle
        : TitleCleanerService.clean(item.title ?? l10n.unknown);

    final playablePath = DownloadFileResolver.resolvePlayablePath(
      item.filePath,
      title: item.title,
      outputFolder: item.request.outputFolder,
    );

    return Dismissible(
      key: ValueKey('dismiss_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.l),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        unawaited(HapticFeedback.mediumImpact());
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.delete),
            content: Text('Supprimer "$displayTitle" ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(backgroundColor: colors.error),
                child: Text(l10n.delete),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) {
        onCancel();
      },
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isFailed
                    ? colors.error.withValues(alpha: 0.35)
                    : isActive
                        ? colors.primary.withValues(alpha: 0.35)
                        : colors.borderSubtle.withValues(alpha: 0.6),
                width: isActive || isFailed ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail
                    _buildThumbnail(context, colors, isCompleted, isFailed, isActive, playablePath, ref),
                    const Gap(12),
                    // Title and metadata
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: colors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const Gap(4),
                          Row(
                            children: [
                              _buildSourceBadge(colors),
                              const Gap(6),
                              Expanded(
                                child: Text(
                                  _buildSubtitleText(l10n),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 11.5,
                                    color: isFailed ? colors.error : colors.textSecondary,
                                    fontWeight: isFailed ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Gap(8),
                    // Action button
                    _buildTrailingAction(context, colors, l10n, isCompleted, isFailed, isActive, playablePath, ref),
                  ],
                ),
                // Progress Bar if active
                if (isActive) ...[
                  const Gap(10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.progress > 0 ? item.progress : null,
                      backgroundColor: colors.borderSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                      minHeight: 5,
                    ),
                  ),
                  const Gap(6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(item.progress * 100).toStringAsFixed(1)}%${item.speed.isNotEmpty ? " • ${item.speed}" : ""}',
                        style: AppTypography.mono.copyWith(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                      if (item.eta.isNotEmpty)
                        Text(
                          'ETA: ${item.eta}',
                          style: AppTypography.mono.copyWith(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
                // Error Hint pill if failed
                if (isFailed && item.error != null) ...[
                  const Gap(8),
                  if (DownloadStatusGuard.isAgeVerificationFailure(
                    error: item.error,
                    url: item.request.url,
                  ))
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        AgeVerificationHelpDialog.show(context, item);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 15,
                              color: Colors.amber,
                            ),
                            Gap(6),
                            Expanded(
                              child: Text(
                                'Vérification d\'âge (+18) — Voir les solutions',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: Colors.amber,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: colors.error,
                          ),
                          const Gap(6),
                          Expanded(
                            child: Text(
                              item.error!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: colors.error,
                          ),
                        ],
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

  Widget _buildThumbnail(
    BuildContext context,
    AppColors colors,
    bool isCompleted,
    bool isFailed,
    bool isActive,
    String? playablePath,
    WidgetRef ref,
  ) {
    return SizedBox(
      width: 76,
      height: 52,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black26),
            if (item.thumbnailUrl != null)
              Image(
                image: _resolveThumbnailImage(item.thumbnailUrl!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _fallbackThumbIcon(colors),
              )
            else
              _fallbackThumbIcon(colors),
            // Overlay badge
            if (isCompleted)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
                ),
              )
            else if (isFailed)
              Container(
                color: colors.error.withValues(alpha: 0.4),
                child: const Center(
                  child: Icon(Icons.error_outline_rounded, color: Colors.white, size: 24),
                ),
              )
            else if (isActive && item.progress <= 0)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackThumbIcon(AppColors colors) {
    return Container(
      color: colors.surfaceHighlight,
      child: Icon(Icons.movie_outlined, color: colors.textSecondary, size: 26),
    );
  }

  ImageProvider _resolveThumbnailImage(String uri) {
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      return NetworkImage(uri);
    }
    return FileImage(File(uri));
  }

  Widget _buildSourceBadge(AppColors colors) {
    final domain = item.source.isNotEmpty ? item.source : 'Web';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        domain,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: colors.primary,
        ),
      ),
    );
  }

  String _buildSubtitleText(AppLocalizations l10n) {
    if (item.status == DownloadStatus.completed) {
      final size = item.totalSize.isNotEmpty ? item.totalSize : item.downloadedSize;
      return size.isNotEmpty ? '$size • ${l10n.statusCompleted}' : l10n.statusCompleted;
    }
    if (item.status == DownloadStatus.failed) {
      return l10n.statusFailed;
    }
    if (item.status == DownloadStatus.paused) {
      return l10n.statusPaused;
    }
    if (item.status == DownloadStatus.extracting) {
      return l10n.statusExtracting;
    }
    final sizeInfo = item.totalSize.isNotEmpty
        ? '${item.downloadedSize} / ${item.totalSize}'
        : item.downloadedSize;
    return sizeInfo.isNotEmpty ? sizeInfo : l10n.statusDownloading;
  }

  Widget _buildTrailingAction(
    BuildContext context,
    AppColors colors,
    AppLocalizations l10n,
    bool isCompleted,
    bool isFailed,
    bool isActive,
    String? playablePath,
    WidgetRef ref,
  ) {
    if (isCompleted) {
      return IconButton(
        tooltip: l10n.openFile,
        icon: Icon(Icons.play_arrow_rounded, color: colors.primary, size: 28),
        onPressed: () {
          HapticFeedback.lightImpact();
          if (playablePath != null && File(playablePath).existsSync()) {
            ref.read(mediaPlayerProvider.notifier).openFile(playablePath);
          } else {
            onTap();
          }
        },
      );
    }
    if (isFailed) {
      return IconButton(
        tooltip: l10n.retry,
        icon: Icon(Icons.refresh_rounded, color: colors.primary, size: 26),
        onPressed: () {
          HapticFeedback.mediumImpact();
          onRetry();
        },
      );
    }
    if (isActive) {
      return IconButton(
        tooltip: l10n.cancel,
        icon: Icon(Icons.close_rounded, color: colors.textSecondary, size: 24),
        onPressed: () {
          HapticFeedback.lightImpact();
          onCancel();
        },
      );
    }
    return IconButton(
      tooltip: l10n.inspector,
      icon: Icon(Icons.chevron_right_rounded, color: colors.textSecondary, size: 24),
      onPressed: onTap,
    );
  }
}
