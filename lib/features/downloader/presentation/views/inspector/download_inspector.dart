import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/core/utils/media_file_utils.dart';
import 'package:modern_downloader/features/downloader/domain/utils/download_item_media.dart';

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
      return Center(child: Text("Select a download"));
    }

    return Animate(
      key: ValueKey(downloadId),
      effects: [
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
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Text(
              "Inspector",
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  (() {
                    final validPath = _getExistingTargetPath(item.filePath);
                    if (validPath != null &&
                        File(validPath).existsSync() &&
                        _isVideo(validPath)) {
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
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (item.thumbnailUrl != null)
                            Opacity(
                              opacity: 0.5,
                              child: _buildPreviewImage(item.thumbnailUrl!),
                            ),
                          Icon(
                            _iconForItem(item, validPath),
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          if (validPath != null)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _openPreviewTarget(ref, validPath),
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.8,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.open_in_new_rounded,
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

                  SizedBox(height: 24),

                  // Metadata
                  _InfoRow(
                    label: "Title",
                    value: TitleCleanerService.clean(item.title ?? "Unknown"),
                  ),
                  _InfoRow(
                    label: "Status",
                    value: item.status.toString().split('.').last,
                  ),
                  _InfoRow(
                    label: "Progress",
                    value: "${(item.progress * 100).toStringAsFixed(1)}%",
                  ),
                  _InfoRow(label: "ID", value: item.id, isMono: true),

                  if (item.error != null) ...[
                    SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.error!,
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      if (item.status == DownloadStatus.downloading ||
                          item.status == DownloadStatus.extracting)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ref
                                  .read(downloadListProvider.notifier)
                                  .cancelDownload(item.id);
                            },
                            icon: Icon(Icons.cancel_outlined, size: 18),
                            label: Text("Cancel"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(color: AppColors.error),
                            ),
                          ),
                        ),

                      if (item.status == DownloadStatus.downloading ||
                          item.status == DownloadStatus.extracting)
                        SizedBox(width: 12),

                      // Retry button for failed/canceled/paused downloads
                      if (item.status == DownloadStatus.failed ||
                          item.status == DownloadStatus.canceled ||
                          item.status == DownloadStatus.paused)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ref
                                  .read(downloadListProvider.notifier)
                                  .retryDownload(item);
                            },
                            icon: Icon(Icons.refresh, size: 18),
                            label: Text("Retry"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),

                      if (item.status == DownloadStatus.failed ||
                          item.status == DownloadStatus.canceled ||
                          item.status == DownloadStatus.paused)
                        SizedBox(width: 12),

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
                          icon: Icon(Icons.delete_outline, size: 18),
                          label: Text("Delete"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Logs
                  Text("Logs", style: Theme.of(context).textTheme.titleSmall),
                  SizedBox(height: 8),
                  Container(
                    height: 200,
                    width: double.infinity,
                    padding: const EdgeInsets.all(
                      0,
                    ), // LogViewer handles padding
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: LogViewer(
                      logs: [
                        "Initialized download for ${item.id}",
                        if (item.status != DownloadStatus.queued)
                          "Download started...",
                        if (item.step.isNotEmpty) "[STEP] ${item.step}",
                        if (item.speed.isNotEmpty) "[SPEED] ${item.speed}",
                        if (item.error != null) "[ERROR] ${item.error}",
                        if (item.status == DownloadStatus.completed)
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
      final target = FileSystemEntity.isDirectorySync(path)
          ? path
          : '/select,$path';
      Process.run('explorer', [target]);
    } catch (e) {
      debugPrint("Error opening file: $e");
    }
  }

  /// Open media files in the built-in player, others in Explorer
  void _openMediaFile(WidgetRef ref, String path) {
    if (_isMedia(path)) {
      ref.read(mediaPlayerProvider.notifier).openFile(path);
    } else {
      _openFile(path);
    }
  }

  void _openPreviewTarget(WidgetRef ref, String path) {
    _openMediaFile(ref, path);
  }

  bool _isMedia(String path) {
    final ext = path.toLowerCase();
    return _isVideo(ext) || _isAudio(ext);
  }

  bool _isAudio(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.mp3') ||
        ext.endsWith('.aac') ||
        ext.endsWith('.opus') ||
        ext.endsWith('.m4a') ||
        ext.endsWith('.ogg') ||
        ext.endsWith('.flac') ||
        ext.endsWith('.wav') ||
        ext.endsWith('.wma');
  }

  bool _isVideo(String path) {
    final ext = path.toLowerCase();
    return MediaFileUtils.isVideoFile(ext) ||
        ext.endsWith('.flv') ||
        ext.endsWith('.m4v') ||
        ext.endsWith('.3gp') ||
        ext.contains('.fhls') || // Handle HLS fragments
        ext.contains('.f\\d+') || // Fragment fragments
        ext.endsWith('.part'); // Allow previewing partial files if supported
  }

  String? _getExistingTargetPath(String? path) {
    if (path == null || path.isEmpty) return null;
    if (File(path).existsSync()) return path;

    // Fallback: Check common extensions if not present
    final extensions = [
      ...MediaFileUtils.videoExtensions,
      ...MediaFileUtils.audioExtensions,
    ];
    for (final ext in extensions) {
      if (!path.toLowerCase().endsWith(ext)) {
        final newPath = '$path$ext';
        if (File(newPath).existsSync()) return newPath;
      }
    }

    return null;
  }

  Widget _buildPreviewImage(String source) {
    if (MediaFileUtils.isNetworkUrl(source)) {
      return Image.network(
        source,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    final file = File(source);
    if (!file.existsSync()) {
      return const SizedBox.shrink();
    }

    return Image.file(
      file,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  IconData _iconForItem(DownloadItem item, String? path) {
    if (path != null && _isAudio(path)) {
      return Icons.audiotrack_rounded;
    }

    switch (DownloadItemMedia.detect(item)) {
      case DownloadMediaType.audio:
        return Icons.audiotrack_rounded;
      case DownloadMediaType.video:
      case DownloadMediaType.unknown:
        return Icons.movie_creation_outlined;
    }
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
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
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
