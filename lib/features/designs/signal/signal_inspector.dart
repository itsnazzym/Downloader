
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/design_system/components/design_progress_bar.dart';
import 'package:tapload/core/design_system/components/status_badge.dart';
import 'package:tapload/core/design_system/foundation/typography.dart';
import 'package:tapload/core/download/download_file_resolver.dart';
import 'package:tapload/core/download/download_queue_controller.dart';
import 'package:tapload/core/download/download_status_guard.dart';
import 'package:tapload/core/download/extraction_placeholders.dart';
import 'package:tapload/core/services/title_cleaner_service.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/ui/media_player/media_player_provider.dart';
import 'package:tapload/core/ui/widgets/log_viewer.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:tapload/features/downloader/presentation/views/dialogs/age_verification_help_dialog.dart';
import 'package:tapload/features/downloader/presentation/views/inspector/video_preview_widget.dart';
import 'package:tapload/features/downloader/presentation/widgets/confirm_file_deletion.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import 'signal_controls.dart';
import 'signal_theme.dart';
import 'signal_widgets.dart';
import 'package:tapload/core/utils/file_reveal.dart';

/// Signal's inspector beside the home: preview (the player itself, framed
/// in a Signal card), Lire, the metadata, copy link / show in folder, the
/// failure (with the age-check help), pause / cancel / resume / retry /
/// delete, and the log. Same fields and actions as the shared inspector.
class SignalInspector extends ConsumerWidget {
  const SignalInspector({super.key, required this.downloadId});

  final String downloadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final item = ref.watch(downloadItemByIdProvider(downloadId));
    if (item == null) {
      return Center(
        child: Text(
          l10n.selectDownload,
          style: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
      );
    }
    // Rebuilds on every progress tick; no file to resolve while busy.
    final path = DownloadQueueController.isBusy(item.status)
        ? null
        : DownloadFileResolver.resolvePlayablePath(
            item.filePath,
            title: item.title,
            outputFolder: item.request.outputFolder,
          );
    final notifier = ref.read(downloadListProvider.notifier);
    final status = item.status;
    final running =
        status == DownloadStatus.downloading ||
        status == DownloadStatus.extracting ||
        status == DownloadStatus.processing;
    final ended =
        status == DownloadStatus.failed ||
        status == DownloadStatus.canceled ||
        status == DownloadStatus.completed;

    void open(String p) {
      if (DownloadFileResolver.isMediaPath(p)) {
        ref.read(mediaPlayerProvider.notifier).openFile(p);
      } else {
        openWithSystem(p);
      }
    }

    final Widget preview;
    if (path != null &&
        DownloadFileResolver.isMediaPath(path) &&
        !DownloadFileResolver.isAudioPath(path)) {
      // The fullscreen player owns the video device: no inline player then.
      preview = ref.watch(mediaPlayerProvider.select((s) => s.isOpen))
          ? _Poster(url: item.thumbnailUrl, filePath: path, playing: true)
          : ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: VideoPreviewWidget(
                filePath: path,
                thumbnailUrl: item.thumbnailUrl,
                onFullscreen: () => open(path),
              ),
            );
    } else {
      preview = _Poster(
        url: item.thumbnailUrl,
        filePath: item.filePath,
        onPlay: path == null ? null : () => open(path),
      );
    }

    final title =
        status == DownloadStatus.extracting &&
            ExtractionPlaceholders.isGenericTitle(item.title)
        ? l10n.extractingTitle
        : TitleCleanerService.clean(item.title ?? l10n.unknown);

    return Column(
      key: ValueKey(downloadId),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 16, 14),
          child: Row(
            children: [
              Expanded(child: SignalEyebrow(l10n.inspector)),
              SignalIconButton(
                icon: Icons.close_rounded,
                tooltip: l10n.close,
                size: 32,
                onTap: () =>
                    ref.read(selectedDownloadIdProvider.notifier).state = null,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                preview,
                const SizedBox(height: 18),
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(
                    20,
                    weight: FontWeight.w600,
                  ).copyWith(color: colors.textPrimary, height: 1.2),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SignalTag(
                      downloadStatusLabel(context, status),
                      mono: false,
                    ),
                    const Spacer(),
                    SignalFigure(
                      value: (item.progress * 100).toStringAsFixed(1),
                      unit: '%',
                      size: 28,
                      gap: 0,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DesignProgressBar(
                  value: item.progress,
                  height: 6,
                  live: status == DownloadStatus.downloading,
                ),
                if (path != null) ...[
                  const SizedBox(height: 18),
                  SignalButton(
                    label: l10n.inspectorPlayMedia,
                    icon: Icons.play_arrow_rounded,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      open(path);
                    },
                  ),
                ],
                const SizedBox(height: 20),
                SignalCard(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Field(
                        label: l10n.inspectorId,
                        value: item.id,
                        first: true,
                      ),
                      _Field(
                        label: l10n.inspectorSourceUrl,
                        value: item.request.url,
                      ),
                      if (path != null)
                        _Field(label: l10n.inspectorLocalFile, value: path),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SignalButton(
                      label: l10n.copyUrl,
                      icon: Icons.link_rounded,
                      accent: false,
                      height: 38,
                      fontSize: 13,
                      onTap: () {
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
                    ),
                    if (path != null)
                      SignalButton(
                        label: l10n.showInFolder,
                        icon: Icons.folder_open_rounded,
                        accent: false,
                        height: 38,
                        fontSize: 13,
                        onTap: () => revealInFolder(path),
                      ),
                  ],
                ),
                if (item.error != null) ...[
                  const SizedBox(height: 18),
                  _Failure(
                    text: item.error!,
                    ageCheck: DownloadStatusGuard.isAgeVerificationFailure(
                      error: item.error,
                      url: item.request.url,
                    ),
                    onHelp: () => AgeVerificationHelpDialog.show(context, item),
                  ),
                ],
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (running) ...[
                      SignalButton(
                        label: l10n.pause,
                        icon: Icons.pause_rounded,
                        accent: false,
                        height: 38,
                        fontSize: 13,
                        onTap: () => notifier.pauseDownload(item.id),
                      ),
                      _Danger(
                        label: l10n.cancel,
                        icon: Icons.close_rounded,
                        onTap: () => notifier.cancelDownload(item.id),
                      ),
                    ],
                    if (status == DownloadStatus.paused)
                      SignalButton(
                        label: l10n.resume,
                        icon: Icons.play_arrow_rounded,
                        height: 38,
                        fontSize: 13,
                        onTap: () => notifier.resumeDownload(item.id),
                      ),
                    if (ended)
                      SignalButton(
                        label: status == DownloadStatus.completed
                            ? l10n.restartDownload
                            : l10n.retry,
                        icon: Icons.restart_alt_rounded,
                        accent: status != DownloadStatus.completed,
                        height: 38,
                        fontSize: 13,
                        onTap: () async {
                          if (await confirmFileDeletion(
                            context,
                            item,
                            actionLabel: l10n.restartDownload,
                          )) {
                            await notifier.retryDownload(item);
                          }
                        },
                      ),
                    _Danger(
                      label: l10n.delete,
                      icon: Icons.delete_outline_rounded,
                      onTap: () async {
                        if (await confirmFileDeletion(
                          context,
                          item,
                          actionLabel: l10n.delete,
                        )) {
                          await notifier.deleteDownload(item.id);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SignalEyebrow(l10n.logs),
                const SizedBox(height: 10),
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: colors.inputBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.textPrimary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: LogViewer(
                    logs: [
                      l10n.designLogInit(item.id),
                      if (status != DownloadStatus.queued)
                        l10n.designLogStarted,
                      if (item.step.isNotEmpty) '[STEP] ${item.step}',
                      if (item.speed.isNotEmpty &&
                          !item.speed.toLowerCase().contains('retry'))
                        '[SPEED] ${item.speed}',
                      if (item.error != null) '[ERROR] ${item.error}',
                      if (status == DownloadStatus.completed &&
                          item.error == null)
                        l10n.designLogCompleted,
                      if (status == DownloadStatus.canceled)
                        l10n.designLogCanceled,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The preview when there is no inline player: the thumbnail, dimmed, with
/// a chartreuse play disc when the file can be opened.
class _Poster extends StatelessWidget {
  const _Poster({
    required this.url,
    required this.filePath,
    this.onPlay,
    this.playing = false,
  });

  final String? url;
  final String? filePath;
  final VoidCallback? onPlay;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          fit: StackFit.expand,
          children: [
            SignalThumb(
              url: url,
              filePath: filePath,
              width: c.maxWidth,
              height: c.maxHeight,
              radius: 14,
            ),
            if (playing)
              Center(
                child: Icon(
                  Icons.play_circle_outline_rounded,
                  size: 44,
                  color: colors.textPrimary.withValues(alpha: 0.6),
                ),
              )
            else if (onPlay != null)
              Center(
                child: Tooltip(
                  message: context.l10n.inspectorPlayMedia,
                  child: GestureDetector(
                    onTap: onPlay,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.35),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 28,
                          color: colors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.first = false});

  final String label;
  final String value;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(
                top: BorderSide(
                  color: colors.textPrimary.withValues(alpha: 0.06),
                ),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.body.copyWith(
              fontSize: 12,
              color: colors.textDisabled,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.mono.copyWith(
              fontSize: 12.5,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({
    required this.text,
    required this.ageCheck,
    required this.onHelp,
  });

  final String text;
  final bool ageCheck;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final tone = ageCheck ? colors.warning : colors.error;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ageCheck ? Icons.shield_outlined : Icons.error_outline_rounded,
                size: 18,
                color: tone,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ageCheck ? l10n.ageCheckRequired : l10n.designFailed,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: AppTypography.mono.copyWith(
              fontSize: 12,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
          if (ageCheck) ...[
            const SizedBox(height: 12),
            SignalButton(
              label: l10n.ageCheckSeeSolutions,
              icon: Icons.help_outline_rounded,
              height: 36,
              fontSize: 13,
              onTap: onHelp,
            ),
          ],
        ],
      ),
    );
  }
}

/// Ghost pill in the error tone (cancel, delete).
class _Danger extends StatelessWidget {
  const _Danger({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SignalMaterial(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.error,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          side: BorderSide(color: colors.error.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}
