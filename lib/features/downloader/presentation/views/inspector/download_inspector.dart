import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/components/status_badge.dart';
import 'package:modern_downloader/core/download/download_file_resolver.dart';
import 'package:modern_downloader/core/download/extraction_placeholders.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/core/ui/widgets/log_viewer.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'video_preview_widget.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';

import 'package:flutter_animate/flutter_animate.dart';

class DownloadInspector extends ConsumerWidget {
  final String downloadId;

  const DownloadInspector({super.key, required this.downloadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Find the item
    final downloadsAsync = ref.watch(downloadListProvider);
    final downloads = downloadsAsync.valueOrNull ?? [];
    final item = downloads.firstWhere(
      (element) => element.id == downloadId,
      orElse: () => DownloadItem(
        id: 'deleted',
        request: const DownloadRequest(url: ''),
        status: DownloadStatus.queued,
      ),
    );

    if (item.id == 'deleted') {
      return Center(child: Text(l10n.selectDownload));
    }

    return Animate(
      key: ValueKey(downloadId),
      effects: const [
        FadeEffect(),
        SlideEffect(begin: Offset(0.05, 0)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.of(context).border),
              ),
            ),
            child: Text(
              l10n.inspector,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preview
                  // Preview
                  // Preview
                  // Preview
                  // Preview
                  // Preview
                  (() {
                    final validPath = DownloadFileResolver.resolvePlayablePath(
                      item.filePath,
                      title: item.title,
                    );
                    if (validPath != null &&
                        DownloadFileResolver.isMediaPath(validPath) &&
                        !DownloadFileResolver.isAudioPath(validPath)) {
                      // Unmount the native inspector player while fullscreen
                      // so it cannot steal the D3D/MF device (black first frame).
                      final fullscreenOpen = ref.watch(
                        mediaPlayerProvider.select((s) => s.isOpen),
                      );
                      if (fullscreenOpen) {
                        return _FullscreenPlayingPlaceholder(
                          thumbnailUrl: item.thumbnailUrl,
                        );
                      }
                      return VideoPreviewWidget(
                        filePath: validPath,
                        thumbnailUrl: item.thumbnailUrl,
                        onFullscreen: () => _openMediaFile(ref, validPath),
                      );
                    }
                    return Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.of(context).border),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (item.thumbnailUrl != null)
                            Opacity(
                              opacity: 0.5,
                              child: _buildThumbnail(
                                item.thumbnailUrl!,
                                context,
                              ),
                            ),
                          Icon(
                            Icons.movie_creation_outlined,
                            size: 48,
                            color: AppColors.of(context).textSecondary,
                          ),
                          if (validPath != null)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _openMediaFile(ref, validPath),
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.of(
                                      context,
                                    ).primary.withValues(alpha: 0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  })(),

                  const SizedBox(height: 24),

                  // Metadata
                  _InfoRow(
                    label: l10n.title,
                    value:
                        item.status == DownloadStatus.extracting &&
                            ExtractionPlaceholders.isGenericTitle(item.title)
                        ? l10n.extractingTitle
                        : TitleCleanerService.clean(item.title ?? l10n.unknown),
                  ),
                  _InfoRow(
                    label: l10n.status,
                    value: downloadStatusLabel(context, item.status),
                  ),
                  _InfoRow(
                    label: l10n.progress,
                    value: "${(item.progress * 100).toStringAsFixed(1)}%",
                  ),
                  _InfoRow(
                    label: l10n.inspectorId,
                    value: item.id,
                    isMono: true,
                  ),

                  if (item.error != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.of(
                          context,
                        ).error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.of(
                            context,
                          ).error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppColors.of(context).error,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.error!,
                              style: TextStyle(
                                color: AppColors.of(context).error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      if (item.status == DownloadStatus.downloading ||
                          item.status == DownloadStatus.extracting ||
                          item.status == DownloadStatus.processing) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ref
                                  .read(downloadListProvider.notifier)
                                  .pauseDownload(item.id);
                            },
                            icon: const Icon(Icons.pause, size: 18),
                            label: Text(l10n.pause),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ref
                                  .read(downloadListProvider.notifier)
                                  .cancelDownload(item.id);
                            },
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: Text(l10n.cancel),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.of(context).error,
                              side: BorderSide(
                                color: AppColors.of(context).error,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      if (item.status == DownloadStatus.paused) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ref
                                  .read(downloadListProvider.notifier)
                                  .resumeDownload(item.id);
                            },
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: Text(l10n.resume),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.of(context).primary,
                              side: BorderSide(
                                color: AppColors.of(context).primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      if (item.status == DownloadStatus.failed ||
                          item.status == DownloadStatus.canceled ||
                          item.status == DownloadStatus.completed)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ref
                                  .read(downloadListProvider.notifier)
                                  .retryDownload(item);
                            },
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 18,
                            ),
                            label: Text(
                              item.status == DownloadStatus.completed
                                  ? l10n.restartDownload
                                  : l10n.retry,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.of(context).primary,
                              side: BorderSide(
                                color: AppColors.of(context).primary,
                              ),
                            ),
                          ),
                        ),

                      if (item.status == DownloadStatus.failed ||
                          item.status == DownloadStatus.canceled ||
                          item.status == DownloadStatus.completed)
                        const SizedBox(width: 12),

                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Confirm delete? For now just do it.
                            ref
                                .read(downloadListProvider.notifier)
                                .deleteDownload(item.id);
                            // Clear selection handled by parent usually, but safe to do?
                            // The view will rebuild and might error content if we don't handle "not found" carefully.
                            // It's handled below.
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(l10n.delete),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.of(context).textPrimary,
                            side: BorderSide(
                              color: AppColors.of(context).border,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Logs
                  Text(
                    l10n.logs,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    width: double.infinity,
                    padding: const EdgeInsets.all(
                      0,
                    ), // LogViewer handles padding
                    decoration: BoxDecoration(
                      color: AppColors.of(context).background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.of(context).border),
                    ),
                    child: LogViewer(
                      logs: [
                        "Initialized download for ${item.id}",
                        if (item.status != DownloadStatus.queued)
                          "Download started...",
                        if (item.step.isNotEmpty) "[STEP] ${item.step}",
                        if (item.speed.isNotEmpty &&
                            !item.speed.toLowerCase().contains('retry'))
                          "[SPEED] ${item.speed}",
                        if (item.error != null) "[ERROR] ${item.error}",
                        if (item.status == DownloadStatus.completed &&
                            item.error == null)
                          "Download completed successfully.",
                        if (item.status == DownloadStatus.canceled)
                          "Download canceled.",
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFile(String path) {
    try {
      Process.run('explorer', [path]);
    } catch (e) {
      debugPrint("Error opening file: $e");
    }
  }

  /// Open media files in the built-in player, others in Explorer
  void _openMediaFile(WidgetRef ref, String path) {
    if (DownloadFileResolver.isMediaPath(path)) {
      ref.read(mediaPlayerProvider.notifier).openFile(path);
    } else {
      _openFile(path);
    }
  }

  Widget _buildThumbnail(String url, BuildContext context) {
    final isNetwork = url.startsWith('http://') || url.startsWith('https://');
    if (isNetwork) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => const SizedBox(),
      );
    }

    String decodedPath = url;
    try {
      decodedPath = Uri.decodeFull(url);
    } catch (_) {}

    final file = File(decodedPath);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => const SizedBox(),
      );
    }
    return const SizedBox();
  }
}

class _FullscreenPlayingPlaceholder extends StatelessWidget {
  final String? thumbnailUrl;

  const _FullscreenPlayingPlaceholder({this.thumbnailUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.of(context).border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl != null)
            Opacity(
              opacity: 0.35,
              child: thumbnailUrl!.startsWith('http')
                  ? Image.network(
                      thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(),
                    )
                  : (File(thumbnailUrl!).existsSync()
                        ? Image.file(
                            File(thumbnailUrl!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(),
                          )
                        : const SizedBox()),
            ),
          const Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMono;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isMono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: AppColors.of(context).textSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppColors.of(context).textPrimary,
              fontSize: 13,
              fontFamily: isMono ? 'JetBrains Mono' : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
