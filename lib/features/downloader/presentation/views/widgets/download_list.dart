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
import '../../widgets/download_card.dart';
import '../../widgets/download_item_context_menu.dart';

import '../../../../../core/design_system/components/status_badge.dart';
import '../../../../../core/download/download_file_resolver.dart';
import '../../../../../core/download/extraction_placeholders.dart';
import '../../../domain/entities/download_item.dart';
import '../../../domain/enums/download_status.dart';
import '../../providers/filtered_downloads_provider.dart';
import '../../providers/downloader_provider.dart';
import '../../widgets/download_item_display.dart';
import 'download_item_skeleton.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

class DownloadList extends ConsumerWidget {
  const DownloadList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final searchQuery = ref.watch(downloadSearchQueryProvider);
    final statusFilter = ref.watch(downloadStatusFilterProvider);
    final listPhase = ref.watch(filteredDownloadListPhaseProvider);
    final idList = ref.watch(filteredDownloadIdListProvider);
    final viewMode = ref.watch(downloadViewModeProvider);
    final isReorderEnabled =
        searchQuery.isEmpty &&
        statusFilter == DownloadStatusFilter.all &&
        idList.ids.length <= 50;

    return listPhase.when(
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
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.of(context).error,
            ),
            const Gap(AppSpacing.m),
            Text(
              l10n.error,
              style: AppTypography.body.copyWith(
                color: AppColors.of(context).textPrimary,
              ),
            ),
            const Gap(AppSpacing.s),
            Text(
              error.toString(),
              style: AppTypography.caption.copyWith(
                color: AppColors.of(context).error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      data: (count) {
        if (count == 0) {
          final isFiltered =
              searchQuery.isNotEmpty ||
              statusFilter != DownloadStatusFilter.all;
          return CustomEmptyState(
            title: isFiltered ? l10n.noResults : l10n.yourListIsEmpty,
            icon: Icons.inbox_outlined,
          );
        }

        final ids = idList.ids;

        if (viewMode == DownloadViewMode.detailed) {
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.m),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              mainAxisExtent: 280,
              crossAxisSpacing: AppSpacing.m,
              mainAxisSpacing: AppSpacing.m,
            ),
            itemCount: ids.length,
            itemBuilder: (context, index) {
              final id = ids[index];
              return _DownloadRowHost(
                key: ValueKey(id),
                id: id,
                useGridCard: true,
              );
            },
          );
        }

        if (!isReorderEnabled) {
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.m),
            itemCount: ids.length,
            separatorBuilder: (ctx, i) => const Gap(AppSpacing.s),
            itemBuilder: (context, index) {
              final id = ids[index];
              return _DownloadRowHost(key: ValueKey(id), id: id);
            },
          );
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.all(AppSpacing.m),
          itemCount: ids.length,
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
          onReorderItem: (oldIndex, newIndex) {
            ref.read(downloadListProvider.notifier).reorder(oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final id = ids[index];

            return Container(
              key: ValueKey(id),
              margin: const EdgeInsets.only(bottom: AppSpacing.s),
              child: _DownloadRowHost(id: id),
            );
          },
        );
      },
    );
  }
}

class _DownloadRowHost extends ConsumerWidget {
  const _DownloadRowHost({
    super.key,
    required this.id,
    this.useGridCard = false,
  });

  final String id;
  final bool useGridCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(downloadItemByIdProvider(id));
    if (item == null) {
      return const SizedBox.shrink();
    }
    final isSelected = ref.watch(
      selectedDownloadIdProvider.select((selected) => selected == id),
    );

    void onTap() {
      ref.read(selectedDownloadIdProvider.notifier).state = item.id;
    }

    void onRetry() {
      ref.read(downloadListProvider.notifier).retryDownload(item);
    }

    void onCancel() {
      ref.read(downloadListProvider.notifier).deleteDownload(item.id);
    }

    if (useGridCard) {
      return RepaintBoundary(
        child: DownloadItemContextMenu(
          item: item,
          child: _DownloadItemGridCard(
            item: item,
            isSelected: isSelected,
            onTap: onTap,
            onRetry: onRetry,
            onCancel: onCancel,
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: _adaptiveDownloadRow(
        context: context,
        ref: ref,
        item: item,
        isSelected: isSelected,
      ),
    );
  }
}

Widget _adaptiveDownloadRow({
  required BuildContext context,
  required WidgetRef ref,
  required DownloadItem item,
  required bool isSelected,
}) {
  void onTap() {
    ref.read(selectedDownloadIdProvider.notifier).state = item.id;
  }

  void onRetry() {
    ref.read(downloadListProvider.notifier).retryDownload(item);
  }

  void onCancel() {
    ref.read(downloadListProvider.notifier).deleteDownload(item.id);
  }

  if (AppColors.of(context).isIosChrome) {
    return DownloadItemContextMenu(
      item: item,
      child: DownloadCard(
        item: item,
        isSelected: isSelected,
        onTap: onTap,
        onRetry: onRetry,
        onCancel: onCancel,
      ),
    );
  }

  return DownloadItemContextMenu(
    item: item,
    child: _DownloadItemCard(
      item: item,
      isSelected: isSelected,
      onTap: onTap,
      onRetry: onRetry,
      onCancel: onCancel,
    ),
  );
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
                            child: LinearProgressIndicator(
                              value: widget.item.progress > 0
                                  ? widget.item.progress
                                  : null,
                              backgroundColor: Colors.transparent,
                              color: AppColors.of(context).primary,
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
                                    style: AppTypography.caption,
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

  /// Helper method to display thumbnail from local file or network URL
  Widget _buildThumbnailImage(String url) {
    // Only treat as network URL if it explicitly starts with http:// or https://
    final isNetworkUrl =
        url.startsWith('http://') || url.startsWith('https://');

    if (isNetworkUrl) {
      return Image.network(
        url,
        fit: BoxFit.cover,
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

    final file = File(decodedPath);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => Center(
          child: Icon(
            Icons.movie_outlined,
            color: AppColors.of(context).textSecondary,
          ),
        ),
      );
    }

    // File doesn't exist - show placeholder
    return Center(
      child: Icon(
        Icons.movie_outlined,
        color: AppColors.of(context).textSecondary,
      ),
    );
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
                    color: AppColors.of(context).background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.of(context).border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.item.thumbnailUrl != null
                      ? Hero(
                          tag: 'thumbnail_${widget.item.id}',
                          child: _buildThumbnailImage(
                            widget.item.thumbnailUrl!,
                          ),
                        )
                      : (ExtractionPlaceholders.showThumbnailSpinner(
                              status: widget.item.status,
                              thumbnailUrl: widget.item.thumbnailUrl,
                            )
                            ? Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.of(context).primary,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.movie_outlined,
                                color: AppColors.of(context).textSecondary,
                                size: 24,
                              )),
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
                              DownloadItemDisplay.title(context, widget.item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label.copyWith(
                                color: widget.isSelected
                                    ? AppColors.of(context).primary
                                    : AppColors.of(context).textPrimary,
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
                            backgroundColor: AppColors.of(context).background,
                            color: AppColors.of(context).primary,
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
                                color: AppColors.of(context).primary,
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
                    widget.item.status == DownloadStatus.canceled ||
                    widget.item.status == DownloadStatus.completed) ...[
                  const Gap(AppSpacing.s),
                  IconButton(
                    onPressed: widget.onRetry,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: AppColors.of(context).primary,
                    ),
                    tooltip: context.l10n.retryDownload,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.of(context).error,
                    ),
                    tooltip: context.l10n.remove,
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

    final file = File(decodedPath);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: 48,
        height: 48,
        errorBuilder: (context, _, _) => Icon(
          Icons.movie_outlined,
          color: AppColors.of(context).textSecondary,
          size: 24,
        ),
      );
    }

    // File doesn't exist - show placeholder
    return Icon(
      Icons.movie_outlined,
      color: AppColors.of(context).textSecondary,
      size: 24,
    );
  }
}
