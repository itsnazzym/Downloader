import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:modern_downloader/core/ui/widgets/custom_empty_state.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../../../core/design_system/foundation/colors.dart';
import '../../../../../core/design_system/foundation/spacing.dart';
import '../../../../../core/design_system/foundation/typography.dart';
import '../../../../../core/design_system/components/app_card.dart';

import '../../../../../core/design_system/components/status_badge.dart';
import '../../../domain/entities/download_item.dart';
import '../../../domain/enums/download_status.dart';
import '../../../domain/utils/download_item_media.dart';
import '../../providers/filtered_downloads_provider.dart';
import '../../providers/downloader_provider.dart';
import 'download_item_skeleton.dart';

class DownloadList extends ConsumerWidget {
  const DownloadList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(downloadSearchQueryProvider);
    final statusFilter = ref.watch(downloadStatusFilterProvider);
    final isReorderEnabled =
        searchQuery.isEmpty && statusFilter == DownloadStatusFilter.all;

    final downloadsAsync = ref.watch(filteredDownloadsProvider);
    final selectedId = ref.watch(selectedDownloadIdProvider);
    final viewMode = ref.watch(downloadViewModeProvider);

    return downloadsAsync.when(
      loading: () => ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.m),
        itemCount: 5,
        separatorBuilder: (ctx, i) => const Gap(AppSpacing.s),
        itemBuilder: (context, index) => const DownloadItemSkeleton(),
      ),

      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const Gap(AppSpacing.m),
            Text(
              "Error loading downloads",
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
            ),
            const Gap(AppSpacing.s),
            Text(
              error.toString(),
              style: AppTypography.caption.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      data: (downloads) {
        if (downloads.isEmpty) {
          return const CustomEmptyState(
            title: "No downloads found",
            description: "Your download list is empty.",
            icon: Icons.inbox_outlined,
          );
        }

        if (viewMode == DownloadViewMode.detailed) {
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.m),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              mainAxisExtent: 280,
              crossAxisSpacing: AppSpacing.m,
              mainAxisSpacing: AppSpacing.m,
            ),
            itemCount: downloads.length,
            itemBuilder: (context, index) {
              final item = downloads[index];
              final isSelected = item.id == selectedId;
              return _DownloadItemGridCard(
                item: item,
                isSelected: isSelected,
                onTap: () {
                  ref.read(selectedDownloadIdProvider.notifier).state = item.id;
                },
                onRetry: () =>
                    ref.read(downloadListProvider.notifier).retryDownload(item),
                onCancel: () => ref
                    .read(downloadListProvider.notifier)
                    .deleteDownload(item.id),
              );
            },
          );
        }

        if (!isReorderEnabled) {
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.m),
            itemCount: downloads.length,
            separatorBuilder: (ctx, i) => const Gap(AppSpacing.s),
            itemBuilder: (context, index) {
              final item = downloads[index];
              final isSelected = item.id == selectedId;
              return _DownloadItemCard(
                item: item,
                isSelected: isSelected,
                onTap: () {
                  ref.read(selectedDownloadIdProvider.notifier).state = item.id;
                },
                onRetry: () =>
                    ref.read(downloadListProvider.notifier).retryDownload(item),
                onCancel: () => ref
                    .read(downloadListProvider.notifier)
                    .deleteDownload(item.id),
              );
            },
          );
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.all(AppSpacing.m),
          itemCount: downloads.length,
          proxyDecorator: (widget, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (BuildContext context, Widget? child) {
                final double animValue = Curves.easeInOut.transform(
                  animation.value,
                );
                final double elevation = lerpDouble(0, 6, animValue)!;
                return Material(
                  elevation: elevation,
                  color: Colors.transparent,
                  shadowColor: Colors.black.withValues(alpha: 0.5),
                  child: widget,
                );
              },
              child: widget,
            );
          },
          onReorder: (oldIndex, newIndex) {
            ref.read(downloadListProvider.notifier).reorder(oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final item = downloads[index];
            final isSelected = item.id == selectedId;

            return Container(
              key: ValueKey(item.id),
              margin: const EdgeInsets.only(bottom: AppSpacing.s),
              child: _DownloadItemCard(
                item: item,
                isSelected: isSelected,
                onTap: () {
                  ref.read(selectedDownloadIdProvider.notifier).state = item.id;
                },
                onRetry: () =>
                    ref.read(downloadListProvider.notifier).retryDownload(item),
                onCancel: () => ref
                    .read(downloadListProvider.notifier)
                    .deleteDownload(item.id),
              ),
            );
          },
        );
      },
    );
  }
}

class _DownloadItemGridCard extends StatefulWidget {
  final DownloadItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const _DownloadItemGridCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  State<_DownloadItemGridCard> createState() => _DownloadItemGridCardState();
}

class _DownloadItemGridCardState extends State<_DownloadItemGridCard> {
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
                    color: AppColors.background,
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
                        else
                          Center(
                            child: Icon(
                              _placeholderIcon(),
                              color: AppColors.textSecondary,
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
                            child: LinearProgressIndicator(
                              value: widget.item.progress > 0
                                  ? widget.item.progress
                                  : null,
                              backgroundColor: Colors.transparent,
                              color: AppColors.primary,
                              minHeight: 4,
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
                          widget.item.title ?? "Unknown Title",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            color: widget.isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
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
                                    '${widget.item.source} | ${DownloadItemMedia.label(DownloadItemMedia.detect(widget.item))}',
                                    style: AppTypography.mono.copyWith(
                                      fontSize: 10,
                                    ),
                                  ),
                                  const Gap(2),
                                  Text(
                                    isDownloading &&
                                            widget.item.speed.isNotEmpty
                                        ? widget.item.speed
                                        : (widget.item.totalSize.isNotEmpty
                                              ? widget.item.totalSize
                                              : "Unknown Size"),
                                    style: AppTypography.caption,
                                  ),
                                ],
                              ),
                            ),
                            if (widget.item.status == DownloadStatus.failed ||
                                widget.item.status == DownloadStatus.canceled)
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: widget.onRetry,
                                    icon: Icon(
                                      Icons.refresh,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: widget.onCancel,
                                    icon: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: AppColors.error,
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

  /// Helper method to display thumbnail from local file or network URL
  Widget _buildThumbnailImage(String url) {
    // Only treat as network URL if it explicitly starts with http:// or https://
    final isNetworkUrl =
        url.startsWith('http://') || url.startsWith('https://');

    if (isNetworkUrl) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Center(
          child: Icon(Icons.movie_outlined, color: AppColors.textSecondary),
        ),
      );
    }

    // Everything else is treated as a local file path
    // Decode URL-encoded paths if needed
    String decodedPath = url;
    try {
      decodedPath = Uri.decodeFull(url);
    } catch (_) {}

    final file = File(decodedPath);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Center(
          child: Icon(Icons.movie_outlined, color: AppColors.textSecondary),
        ),
      );
    }

    // File doesn't exist - show placeholder
    return Center(
      child: Icon(Icons.movie_outlined, color: AppColors.textSecondary),
    );
  }

  IconData _placeholderIcon() {
    switch (DownloadItemMedia.detect(widget.item)) {
      case DownloadMediaType.audio:
        return Icons.audiotrack_rounded;
      case DownloadMediaType.video:
      case DownloadMediaType.unknown:
        return Icons.movie_outlined;
    }
  }
}

class _DownloadItemCard extends StatefulWidget {
  final DownloadItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const _DownloadItemCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  State<_DownloadItemCard> createState() => _DownloadItemCardState();
}

class _DownloadItemCardState extends State<_DownloadItemCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final bool isDownloading = widget.item.status == DownloadStatus.downloading;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _isHovering ? -2 : 0, 0),
          child: AppCard(
            onTap: widget.onTap,
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                // Thumbnail / Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.item.thumbnailUrl != null
                      ? Hero(
                          tag: 'thumbnail_${widget.item.id}',
                          child: _buildThumbnailImage(
                            widget.item.thumbnailUrl!,
                          ),
                        )
                      : Icon(
                          _placeholderIcon(),
                          color: AppColors.textSecondary,
                          size: 24,
                        ),
                ),
                const Gap(AppSpacing.m),

                // Info Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (widget.item.title == null ||
                                      widget.item.title!.isEmpty)
                                  ? "Unknown Title"
                                  : widget.item.title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label.copyWith(
                                color: widget.isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const Gap(AppSpacing.s),
                          StatusBadge(
                            status: widget.item.status,
                            error: widget.item.error,
                          ),
                        ],
                      ),

                      const Gap(4),

                      // Meta Row or Progress
                      if (isDownloading ||
                          widget.item.status == DownloadStatus.extracting) ...[
                        const Gap(4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: widget.item.progress > 0
                                ? widget.item.progress
                                : null,
                            backgroundColor: AppColors.background,
                            color: AppColors.primary,
                            minHeight: 4,
                          ),
                        ),
                        const Gap(6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${(widget.item.progress * 100).toStringAsFixed(1)}%",
                              style: AppTypography.mono.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            const Gap(8),
                            Flexible(
                              child: Text(
                                _buildMetaString(),
                                style: AppTypography.mono,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ] else
                        Text(
                          _buildMetaString(),
                          style: AppTypography.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

                // Action Buttons
                if (widget.item.status == DownloadStatus.failed ||
                    widget.item.status == DownloadStatus.canceled) ...[
                  const Gap(AppSpacing.s),
                  IconButton(
                    onPressed: widget.onRetry,
                    icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
                    tooltip: "Retry Download",
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                    tooltip: "Remove",
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildMetaString() {
    final parts = <String>[];

    // Source
    parts.add(widget.item.source);
    parts.add(DownloadItemMedia.label(DownloadItemMedia.detect(widget.item)));

    // Size logic
    if (widget.item.totalSize.isNotEmpty) {
      if (widget.item.downloadedSize.isNotEmpty &&
          widget.item.status == DownloadStatus.downloading) {
        parts.add("${widget.item.downloadedSize} / ${widget.item.totalSize}");
      } else {
        parts.add(widget.item.totalSize);
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

  /// Helper method to display thumbnail from local file or network URL
  Widget _buildThumbnailImage(String url) {
    // Only treat as network URL if it explicitly starts with http:// or https://
    final isNetworkUrl =
        url.startsWith('http://') || url.startsWith('https://');

    if (isNetworkUrl) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: 48,
        height: 48,
        errorWidget: (_, _, _) => Icon(
          Icons.movie_outlined,
          color: AppColors.textSecondary,
          size: 24,
        ),
        placeholder: (_, _) => Container(
          color: AppColors.background,
          child: Center(
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

    final file = File(decodedPath);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: 48,
        height: 48,
        errorBuilder: (_, _, _) => Icon(
          Icons.movie_outlined,
          color: AppColors.textSecondary,
          size: 24,
        ),
      );
    }

    // File doesn't exist - show placeholder
    return Icon(Icons.movie_outlined, color: AppColors.textSecondary, size: 24);
  }

  IconData _placeholderIcon() {
    switch (DownloadItemMedia.detect(widget.item)) {
      case DownloadMediaType.audio:
        return Icons.audiotrack_rounded;
      case DownloadMediaType.video:
      case DownloadMediaType.unknown:
        return Icons.movie_outlined;
    }
  }
}
