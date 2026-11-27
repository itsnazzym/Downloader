import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/theme/app_typography.dart';
import 'package:modern_downloader/core/design_system/components/status_badge.dart';
import 'package:modern_downloader/core/download/download_file_resolver.dart';
import 'package:modern_downloader/core/download/download_queue_controller.dart';
import 'package:modern_downloader/core/download/extraction_placeholders.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

import 'package:modern_downloader/core/download/download_status_guard.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/core/ui/widgets/log_viewer.dart';
import '../dialogs/age_verification_help_dialog.dart';
import 'video_preview_widget.dart';
import '../../widgets/confirm_file_deletion.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:modern_downloader/core/android/android_engine_bridge.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:modern_downloader/core/utils/file_reveal.dart';

class DownloadInspector extends ConsumerWidget {
  final String downloadId;

  const DownloadInspector({super.key, required this.downloadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final item = ref.watch(downloadItemByIdProvider(downloadId));

    if (item == null) {
      return Center(child: Text(l10n.selectDownload));
    }

    // This build reruns on every progress tick of an active download, and the
    // resolver falls back to recursive folder scans on the UI thread. There is
    // no playable file until the download ends, so skip it while busy.
    final validPath = DownloadQueueController.isBusy(item.status)
        ? null
        : DownloadFileResolver.resolvePlayablePath(
            item.filePath,
            title: item.title,
            outputFolder: item.request.outputFolder,
          );

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
            child: Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: AppColors.of(context).primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.inspector,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preview
                  (() {
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
                  if (validPath != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          _openMediaFile(ref, validPath);
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 22),
                        label: Text(
                          l10n.inspectorPlayMedia,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.of(context).primary,
                          foregroundColor: AppColors.of(context).onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

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
                  _InfoRow(
                    label: l10n.inspectorSourceUrl,
                    value: item.request.url,
                    isMono: true,
                  ),
                  if (validPath != null)
                    _InfoRow(
                      label: l10n.inspectorLocalFile,
                      value: validPath,
                      isMono: true,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Clipboard.setData(
                              ClipboardData(text: item.request.url),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.urlCopied),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.link_rounded, size: 16),
                          label: Text(l10n.copyUrl),
                        ),
                      ),
                      if (validPath != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              if (PlatformInfo.isAndroid) {
                                AndroidEngineBridge.instance.viewFile(
                                  validPath,
                                );
                              } else {
                                _openInFolder(validPath);
                              }
                            },
                            icon: Icon(
                              PlatformInfo.isAndroid
                                  ? Icons.open_in_new_rounded
                                  : Icons.folder_open_rounded,
                              size: 16,
                            ),
                            label: Text(
                              PlatformInfo.isAndroid
                                  ? 'Ouvrir avec'
                                  : l10n.showInFolder,
                            ),
                          ),
                        ),
                        if (PlatformInfo.isAndroid) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                AndroidEngineBridge.instance.shareFile(
                                  validPath,
                                );
                              },
                              icon: const Icon(Icons.share_rounded, size: 16),
                              label: const Text('Partager'),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),

                  if (item.error != null) ...[
                    const SizedBox(height: 24),
                    if (DownloadStatusGuard.isAgeVerificationFailure(
                      error: item.error,
                      url: item.request.url,
                    )) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.shield_outlined,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.ageCheckRequired,
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.error!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () =>
                                  AgeVerificationHelpDialog.show(context, item),
                              icon: const Icon(
                                Icons.help_outline_rounded,
                                size: 16,
                              ),
                              label: Text(l10n.ageCheckSeeSolutions),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.amber.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
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
                            icon: const Icon(Icons.pause, size: 16),
                            label: Text(
                              l10n.pause,
                              maxLines: 1,
                              softWrap: false,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                            ),
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
                            icon: const Icon(Icons.cancel_outlined, size: 16),
                            label: Text(
                              l10n.cancel,
                              maxLines: 1,
                              softWrap: false,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
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
                            icon: const Icon(Icons.play_arrow, size: 16),
                            label: Text(
                              l10n.resume,
                              maxLines: 1,
                              softWrap: false,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
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
                            onPressed: () async {
                              final notifier = ref.read(
                                downloadListProvider.notifier,
                              );
                              if (await confirmFileDeletion(
                                context,
                                item,
                                actionLabel: l10n.restartDownload,
                              )) {
                                await notifier.retryDownload(item);
                              }
                            },
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 16,
                            ),
                            label: Text(
                              item.status == DownloadStatus.completed
                                  ? l10n.restartDownload
                                  : l10n.retry,
                              maxLines: 1,
                              softWrap: false,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
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
                          onPressed: () async {
                            final notifier = ref.read(
                              downloadListProvider.notifier,
                            );
                            if (await confirmFileDeletion(
                              context,
                              item,
                              actionLabel: l10n.delete,
                            )) {
                              await notifier.deleteDownload(item.id);
                            }
                          },
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: Text(
                            l10n.delete,
                            maxLines: 1,
                            softWrap: false,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
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

  void _openFile(String path) => openWithSystem(path);

  void _openInFolder(String path) => revealInFolder(path);


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
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.border.withValues(alpha: 0.18),
            width: 0.6,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: isMono
                ? AppTypography.mono.copyWith(
                    color: colors.textPrimary,
                    fontSize: 12.5,
                  )
                : TextStyle(color: colors.textPrimary, fontSize: 13),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
