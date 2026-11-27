import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tapload/core/design_system/components/design_progress_bar.dart';
import 'package:flutter/services.dart';
import 'package:tapload/core/android/android_engine_bridge.dart';
import 'package:tapload/core/design_system/components/status_badge.dart';
import 'package:tapload/core/design_system/foundation/colors.dart';
import 'package:tapload/core/design_system/foundation/spacing.dart';
import 'package:tapload/core/design_system/foundation/typography.dart';
import 'package:tapload/core/download/download_file_resolver.dart';
import 'package:tapload/core/download/extraction_placeholders.dart';
import 'package:tapload/core/platform/platform_info.dart';
import 'package:tapload/core/download/download_error_reason.dart';
import 'package:tapload/core/download/download_status_guard.dart';
import 'package:tapload/l10n/l10n_ext.dart';
import '../../domain/entities/download_item.dart';
import '../../domain/enums/download_status.dart';
import '../views/dialogs/age_verification_help_dialog.dart';
import 'download_item_display.dart';

class DownloadItemCard extends StatefulWidget {
  final DownloadItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const DownloadItemCard({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  State<DownloadItemCard> createState() => _DownloadItemCardState();
}

class _DownloadItemCardState extends State<DownloadItemCard> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isMobile = PlatformInfo.isMobile;
    final isDownloading = widget.item.status == DownloadStatus.downloading;
    final isExtracting = widget.item.status == DownloadStatus.extracting;

    Widget cardBody = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.translationValues(0, _isHovering ? -2 : 0, 0),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.panelOf(context),
        border: Border.all(
          color: widget.isSelected
              ? colors.primary
              : colors.border.withValues(alpha: isMobile ? 0.35 : 0.6),
          width: widget.isSelected ? 1.5 : 1.0,
        ),
        boxShadow: isMobile
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.panelOf(context),
        child: InkWell(
          borderRadius: AppRadius.panelOf(context),
          onTap: () {
            if (isMobile) HapticFeedback.lightImpact();
            widget.onTap();
          },
          onHighlightChanged: (highlighted) {
            if (isMobile && highlighted != _isPressed) {
              setState(() => _isPressed = highlighted);
            }
          },
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 10.0 : AppSpacing.m),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Thumbnail
                _buildThumbnail(context, isMobile),
                SizedBox(width: isMobile ? 12 : AppSpacing.m),

                // Info Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Row + Status Badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              DownloadItemDisplay.title(context, widget.item),
                              maxLines: isMobile ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label.copyWith(
                                color: widget.isSelected
                                    ? colors.primary
                                    : colors.textPrimary,
                                fontSize: isMobile ? 13.5 : 14,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(
                            status: widget.item.status,
                            error: widget.item.error,
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Progress or Meta Information
                      if (isDownloading || isExtracting) ...[
                        DesignProgressBar(
                          value: widget.item.progress > 0
                              ? widget.item.progress
                              : null,
                          live: isDownloading,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${(widget.item.progress * 100).toStringAsFixed(1)}%",
                              style: AppTypography.mono.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _buildMetaString(),
                                style: AppTypography.mono.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            if (widget.item.source.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surfaceHighlight,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: colors.border.withValues(alpha: 0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  widget.item.source,
                                  style: AppTypography.mono.copyWith(
                                    fontSize: 10,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                _buildMetaString(),
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 11.5,
                                  color: colors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (widget.item.status == DownloadStatus.failed &&
                            !DownloadStatusGuard.isAgeVerificationFailure(
                              error: widget.item.error,
                              url: widget.item.request.url,
                            ) &&
                            downloadErrorReason(
                              widget.item.error,
                            ).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          // Why it failed, readable; the full log stays in
                          // the status badge's tooltip.
                          Text(
                            downloadErrorReason(widget.item.error),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11.5,
                              color: colors.error,
                            ),
                          ),
                        ],
                        if (widget.item.status == DownloadStatus.failed &&
                            DownloadStatusGuard.isAgeVerificationFailure(
                              error: widget.item.error,
                              url: widget.item.request.url,
                            )) ...[
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => AgeVerificationHelpDialog.show(
                              context,
                              widget.item,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 12,
                                    color: Colors.amber,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Vérification d\'âge (+18) — Voir solutions',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.amber,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                // Action Buttons (Desktop only - mobile uses swipe and bottom sheet)
                if (!isMobile &&
                    (widget.item.status == DownloadStatus.failed ||
                        widget.item.status == DownloadStatus.canceled ||
                        widget.item.status == DownloadStatus.completed)) ...[
                  const SizedBox(width: 8),
                  if (widget.item.status == DownloadStatus.failed &&
                      DownloadStatusGuard.isAgeVerificationFailure(
                        error: widget.item.error,
                        url: widget.item.request.url,
                      ))
                    IconButton(
                      onPressed: () => AgeVerificationHelpDialog.show(
                        context,
                        widget.item,
                      ),
                      icon: const Icon(
                        Icons.shield_outlined,
                        color: Colors.amber,
                        size: 18,
                      ),
                      tooltip: 'Résoudre la vérification d\'âge (+18)',
                      padding: const EdgeInsets.all(8),
                    ),
                  IconButton(
                    onPressed: widget.onRetry,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: colors.primary,
                      size: 18,
                    ),
                    tooltip: context.l10n.retryDownload,
                    padding: const EdgeInsets.all(8),
                  ),
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.error,
                      size: 18,
                    ),
                    tooltip: context.l10n.remove,
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (isMobile) {
      return RepaintBoundary(
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: Dismissible(
            key: ValueKey('dismiss_${widget.item.id}'),
            direction: DismissDirection.horizontal,
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.endToStart) {
                await HapticFeedback.mediumImpact();
                widget.onCancel();
              } else if (direction == DismissDirection.startToEnd) {
                await HapticFeedback.lightImpact();
                final path = widget.item.filePath;
                if (path != null && File(path).existsSync()) {
                  await AndroidEngineBridge.instance.shareFile(path);
                }
              }
              return false;
            },
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.share_rounded, color: colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Partager',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Supprimer',
                    style: TextStyle(
                      color: colors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.delete_outline_rounded,
                    color: colors.error,
                    size: 20,
                  ),
                ],
              ),
            ),
            child: cardBody,
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        cursor: SystemMouseCursors.click,
        child: cardBody,
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, bool isMobile) {
    final colors = AppColors.of(context);
    final width = isMobile ? 54.0 : 48.0;
    final height = isMobile ? 48.0 : 48.0;

    return Stack(
      children: [
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: widget.item.thumbnailUrl != null
              ? Hero(
                  tag: 'thumbnail_${widget.item.id}',
                  child: _buildThumbnailImage(widget.item.thumbnailUrl!),
                )
              : (ExtractionPlaceholders.showThumbnailSpinner(
                      status: widget.item.status,
                      thumbnailUrl: widget.item.thumbnailUrl,
                    )
                    ? Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.movie_outlined,
                        color: colors.textSecondary,
                        size: 22,
                      )),
        ),
        if (isMobile && widget.item.status == DownloadStatus.completed)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 11,
                color: colors.primary,
              ),
            ),
          ),
      ],
    );
  }

  String _buildMetaString() {
    final parts = <String>[];

    // Source
    parts.add(widget.item.source);

    // Size logic — fall back to on-disk length when yt-dlp never reported it.
    final sizeLabel = DownloadFileResolver.displaySize(
      storedTotalSize: widget.item.totalSize,
      filePath: widget.item.filePath,
      unknownLabel: '',
    );
    if (sizeLabel.isNotEmpty) {
      if (widget.item.downloadedSize.isNotEmpty &&
          widget.item.status == DownloadStatus.downloading) {
        parts.add("${widget.item.downloadedSize} / $sizeLabel");
      } else {
        parts.add(sizeLabel);
      }
    } else if (widget.item.downloadedSize.isNotEmpty) {
      parts.add(widget.item.downloadedSize);
    }

    // Speed
    if (widget.item.speed.isNotEmpty &&
        widget.item.status == DownloadStatus.downloading) {
      parts.add(widget.item.speed);
    }

    // ETA
    if (widget.item.eta.isNotEmpty &&
        widget.item.status == DownloadStatus.downloading) {
      parts.add("ETA ${widget.item.eta}");
    }

    return parts.join(" • ");
  }

  /// Decode thumbnails near their 48 px box, not at the source's 1280x720
  /// (~3.7 MB each): enough for BoxFit.cover of 16:9 art at 2x DPR.
  static const int _thumbDecodeWidth = 192;

  /// Helper method to display thumbnail from local file or network URL
  Widget _buildThumbnailImage(String url) {
    if (url.startsWith('assets/showcase/')) {
      return Image.asset(url, fit: BoxFit.cover, width: 48, height: 48);
    }
    // Showcase thumbnails stay in Flutter's memory image cache; do not use
    // CachedNetworkImage here because it writes image files to disk.
    if (widget.item.id.startsWith('showcase-') &&
        url.startsWith('https://i.ytimg.com/')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: 48,
        height: 48,
        cacheWidth: _thumbDecodeWidth,
        errorBuilder: (context, _, _) => Icon(
          Icons.movie_outlined,
          color: AppColors.of(context).textSecondary,
          size: 24,
        ),
      );
    }
    // Only treat as network URL if it explicitly starts with http:// or https://
    final isNetworkUrl =
        url.startsWith('http://') || url.startsWith('https://');

    if (isNetworkUrl) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: 48,
        height: 48,
        memCacheWidth: _thumbDecodeWidth,
        errorWidget: (context, _, _) => Icon(
          Icons.movie_outlined,
          color: AppColors.of(context).textSecondary,
          size: 24,
        ),
        placeholder: (context, _) => Container(
          color: AppColors.of(context).background,
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        fadeInDuration: const Duration(milliseconds: 200),
      );
    }

    // Everything else is treated as a local file path
    // Decode URL-encoded paths if needed
    String decodedPath = url;
    try {
      decodedPath = Uri.decodeFull(url);
    } catch (_) {}

    return Image.file(
      File(decodedPath),
      fit: BoxFit.cover,
      width: 48,
      height: 48,
      cacheWidth: _thumbDecodeWidth,
      errorBuilder: (context, _, _) => Icon(
        Icons.movie_outlined,
        color: AppColors.of(context).textSecondary,
        size: 24,
      ),
    );
  }
}
