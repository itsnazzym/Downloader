import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/status_badge.dart';
import '../../../../core/design_system/foundation/colors.dart';
import '../../../../core/design_system/foundation/typography.dart';
import '../../../../core/download/extraction_placeholders.dart';
import '../../domain/entities/download_item.dart';
import '../../domain/enums/download_status.dart';
import 'download_item_display.dart';
import 'progress_bar.dart';

class DownloadItemGridCard extends StatefulWidget {
  final DownloadItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const DownloadItemGridCard({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  State<DownloadItemGridCard> createState() => _DownloadItemGridCardState();
}

class _DownloadItemGridCardState extends State<DownloadItemGridCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final bool isDownloading = widget.item.status == DownloadStatus.downloading;

    // Performance: Isolate repaints for progress bars
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          scale: _isHovering ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AppCard(
            onTap: widget.onTap,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Preview Area
                Expanded(
                  flex: 3,
                  child: Container(
                    color: AppColors.of(context).background,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (widget.item.thumbnailUrl != null)
                          Hero(
                            tag: 'thumbnail_${widget.item.id}',
                            child: _buildThumbnailImage(
                              widget.item.thumbnailUrl!,
                            ),
                          )
                        else if (ExtractionPlaceholders.showThumbnailSpinner(
                          status: widget.item.status,
                          thumbnailUrl: widget.item.thumbnailUrl,
                        ))
                          Center(
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.of(context).primary,
                              ),
                            ),
                          )
                        else
                          Center(
                            child: Icon(
                              Icons.movie_outlined,
                              color: AppColors.of(context).textSecondary,
                              size: 48,
                            ),
                          ),

                        // Status Overlay
                        Positioned(
                          top: 8,
                          right: 8,
                          child: StatusBadge(
                            status: widget.item.status,
                            error: widget.item.error,
                          ),
                        ),

                        // Progress Overlay
                        if (isDownloading)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: ProgressBar(
                              progress: widget.item.progress,
                              height: 3,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Info Area
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DownloadItemDisplay.title(context, widget.item),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            color: widget.isSelected
                                ? AppColors.of(context).primary
                                : AppColors.of(context).textPrimary,
                          ),
                        ),
                        const Spacer(),
                        // Meta info
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DownloadItemDisplay.source(
                                      context,
                                      widget.item,
                                    ),
                                    style: AppTypography.mono.copyWith(
                                      fontSize: 10,
                                    ),
                                  ),
                                  const Gap(2),
                                  Text(
                                    isDownloading &&
                                            widget.item.speed.isNotEmpty
                                        ? widget.item.speed
                                        : DownloadItemDisplay.size(
                                            context,
                                            widget.item,
                                          ),
                                    style: AppTypography.mono.copyWith(
                                      fontSize: 11,
                                      color: AppColors.of(
                                        context,
                                      ).textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (DownloadItemDisplay.isTerminal(widget.item))
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: widget.onRetry,
                                    icon: Icon(
                                      Icons.refresh,
                                      size: 16,
                                      color: AppColors.of(context).primary,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: widget.onCancel,
                                    icon: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: AppColors.of(context).error,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Grid tiles are at most 300 px wide; decode for that at 2x DPR.
  static const int _thumbDecodeWidth = 640;

  /// Helper method to display thumbnail from local file or network URL
  Widget _buildThumbnailImage(String url) {
    if (url.startsWith('assets/showcase/')) {
      return Image.asset(url, fit: BoxFit.cover);
    }
    // Only treat as network URL if it explicitly starts with http:// or https://
    final isNetworkUrl =
        url.startsWith('http://') || url.startsWith('https://');

    if (isNetworkUrl) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: _thumbDecodeWidth,
        errorBuilder: (context, _, _) => Center(
          child: Icon(
            Icons.movie_outlined,
            color: AppColors.of(context).textSecondary,
          ),
        ),
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
      cacheWidth: _thumbDecodeWidth,
      errorBuilder: (context, _, _) => Center(
        child: Icon(
          Icons.movie_outlined,
          color: AppColors.of(context).textSecondary,
        ),
      ),
    );
  }
}
