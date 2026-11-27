import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/design_system/components/status_badge.dart'
    show downloadStatusLabel;
import 'package:tapload/core/download/download_file_resolver.dart';
import 'package:tapload/core/download/download_queue_controller.dart';
import 'package:tapload/core/download/download_status_guard.dart';
import 'package:tapload/core/download/extraction_placeholders.dart';
import 'package:tapload/core/services/title_cleaner_service.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/ui/media_player/media_player_provider.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/views/dialogs/age_verification_help_dialog.dart';
import 'package:tapload/features/downloader/presentation/views/inspector/video_preview_widget.dart';
import 'package:tapload/features/downloader/presentation/widgets/confirm_file_deletion.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import '../signal/signal_widgets.dart' show SignalThumb;
import 'nocturne_widgets.dart';

/// Nocturne's inspector: the preview in a night frame (a ring while the
/// download runs), play, the item's facts, copy and reveal, the error or
/// age-check help, the actions its status allows, then the log.
class NocturneInspector extends ConsumerWidget {
  const NocturneInspector({super.key, required this.downloadId});

  final String downloadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final item = ref.watch(downloadItemByIdProvider(downloadId));
    if (item == null) {
      return Center(
        child: Text(
          l10n.selectDownload,
          style: nocturneText(c, color: c.textSecondary),
        ),
      );
    }
    // Progress ticks rebuild this; the resolver may scan folders, and there
    // is no playable file until the download ends.
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
    final finished =
        status == DownloadStatus.failed ||
        status == DownloadStatus.canceled ||
        status == DownloadStatus.completed;

    Widget fact(String label, String value, {bool mono = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: nocturneText(c, size: 12.5, color: c.textDisabled),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: mono
                  ? nocturneMono(c, size: 12, color: c.textPrimary)
                  : nocturneText(c, size: 13, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    final facts = [
      fact(
        l10n.title,
        status == DownloadStatus.extracting &&
                ExtractionPlaceholders.isGenericTitle(item.title)
            ? l10n.extractingTitle
            : TitleCleanerService.clean(item.title ?? l10n.unknown),
      ),
      fact(l10n.status, downloadStatusLabel(context, status)),
      fact(l10n.progress, '${(item.progress * 100).toStringAsFixed(1)} %'),
      fact(l10n.inspectorId, item.id, mono: true),
      fact(l10n.inspectorSourceUrl, item.request.url, mono: true),
      if (path != null) fact(l10n.inspectorLocalFile, path, mono: true),
    ];

    final actions = <Widget>[
      if (running) ...[
        NocturneButton(
          label: l10n.pause,
          icon: Icons.pause_rounded,
          onTap: () => notifier.pauseDownload(item.id),
        ),
        NocturneButton(
          label: l10n.cancel,
          icon: Icons.close_rounded,
          kind: NocturneButtonKind.danger,
          onTap: () => notifier.cancelDownload(item.id),
        ),
      ],
      if (status == DownloadStatus.paused)
        NocturneButton(
          label: l10n.resume,
          icon: Icons.play_arrow_rounded,
          onTap: () => notifier.resumeDownload(item.id),
        ),
      if (finished)
        NocturneButton(
          label: status == DownloadStatus.completed
              ? l10n.restartDownload
              : l10n.retry,
          icon: Icons.restart_alt_rounded,
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
      NocturneButton(
        label: l10n.delete,
        icon: Icons.delete_outline_rounded,
        kind: NocturneButtonKind.ghost,
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
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: AlignmentDirectional.centerStart,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: c.primary.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            children: [
              Text(
                l10n.inspector,
                style: nocturneText(c, size: 15, weight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                downloadStatusLabel(context, status),
                style: nocturneText(
                  c,
                  size: 12,
                  weight: FontWeight.w600,
                  color: status == DownloadStatus.failed ? c.error : c.primary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey(downloadId),
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Preview(item: item, path: path),
                if (path != null) ...[
                  const SizedBox(height: 12),
                  NocturneButton(
                    label: l10n.inspectorPlayMedia,
                    icon: Icons.play_arrow_rounded,
                    kind: NocturneButtonKind.primary,
                    height: 42,
                    radius: 14,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _openMedia(ref, path);
                    },
                  ),
                ],
                const SizedBox(height: 18),
                NocturneCard(
                  lift: false,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < facts.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            color: c.primary.withValues(alpha: 0.06),
                          ),
                        facts[i],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    NocturneButton(
                      label: l10n.copyUrl,
                      icon: Icons.link_rounded,
                      kind: NocturneButtonKind.ghost,
                      onTap: () {
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
                    ),
                    if (path != null)
                      NocturneButton(
                        label: l10n.showInFolder,
                        icon: Icons.folder_open_rounded,
                        kind: NocturneButtonKind.ghost,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _reveal(path);
                        },
                      ),
                  ],
                ),
                if (item.error != null) ...[
                  const SizedBox(height: 18),
                  _ErrorPanel(item: item),
                ],
                const SizedBox(height: 18),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
                const SizedBox(height: 24),
                Text(
                  l10n.logs,
                  style: nocturneText(c, size: 13, weight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _Log(item: item),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

void _openFile(String path) {
  try {
    if (Platform.isWindows) {
      Process.run('explorer', [path]);
    } else if (Platform.isMacOS) {
      Process.run('open', [path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [path]);
    }
  } catch (e) {
    debugPrint('Error opening file: $e');
  }
}

void _reveal(String path) {
  try {
    if (Platform.isWindows) {
      Process.run('explorer', ['/select,', path]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [File(path).parent.path]);
    }
  } catch (e) {
    debugPrint('Error revealing file: $e');
  }
}

/// Media in the built-in player, anything else in the system's app.
void _openMedia(WidgetRef ref, String path) {
  if (DownloadFileResolver.isMediaPath(path)) {
    ref.read(mediaPlayerProvider.notifier).openFile(path);
  } else {
    _openFile(path);
  }
}

class _Preview extends ConsumerWidget {
  const _Preview({required this.item, required this.path});

  final DownloadItem item;
  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final p = path;
    final video =
        p != null &&
        DownloadFileResolver.isMediaPath(p) &&
        !DownloadFileResolver.isAudioPath(p);
    // Unmount the inspector's player while fullscreen plays, so it cannot
    // take the video device (black first frame).
    final fullscreen =
        video && ref.watch(mediaPlayerProvider.select((s) => s.isOpen));
    Widget child;
    if (video && !fullscreen) {
      child = VideoPreviewWidget(
        filePath: p,
        thumbnailUrl: item.thumbnailUrl,
        onFullscreen: () => _openMedia(ref, p),
      );
    } else {
      final busy = DownloadQueueController.isBusy(item.status);
      child = AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: busy || fullscreen ? 0.35 : 0.55,
              child: LayoutBuilder(
                builder: (context, box) => SignalThumb(
                  url: item.thumbnailUrl,
                  filePath: item.filePath,
                  width: box.maxWidth,
                  height: box.maxHeight,
                  radius: 0,
                ),
              ),
            ),
            Center(
              child: busy
                  ? NocturneRing(
                      value: item.progress,
                      size: 92,
                      stroke: 7,
                      radius: 38,
                      child: Text(
                        '${(item.progress * 100).clamp(0, 100).round()}%',
                        style: nocturneMono(c, size: 17, color: c.textPrimary),
                      ),
                    )
                  : p != null
                  ? NocturneIconButton(
                      icon: Icons.play_arrow_rounded,
                      tooltip: context.l10n.inspectorPlayMedia,
                      size: 52,
                      onTap: () => _openMedia(ref, p),
                    )
                  : Icon(
                      fullscreen
                          ? Icons.play_circle_outline_rounded
                          : Icons.movie_creation_outlined,
                      size: 40,
                      color: c.textSecondary,
                    ),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: c.inputBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.primary.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final age = DownloadStatusGuard.isAgeVerificationFailure(
      error: item.error,
      url: item.request.url,
    );
    final tone = age ? c.warning : c.error;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                age ? Icons.shield_outlined : Icons.error_outline_rounded,
                size: 18,
                color: tone,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  age ? l10n.ageCheckRequired : l10n.designFailed,
                  style: nocturneText(
                    c,
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: tone,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            item.error!,
            style: nocturneText(c, size: 12.5, color: c.textSecondary),
          ),
          if (age) ...[
            const SizedBox(height: 12),
            NocturneButton(
              label: l10n.ageCheckSeeSolutions,
              icon: Icons.help_outline_rounded,
              onTap: () => AgeVerificationHelpDialog.show(context, item),
            ),
          ],
        ],
      ),
    );
  }
}

/// The download's log lines in a dark mono well.
class _Log extends StatelessWidget {
  const _Log({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final lines = [
      l10n.nocturneLogInit(item.id),
      if (item.status != DownloadStatus.queued) l10n.nocturneLogStarted,
      if (item.step.isNotEmpty) '[STEP] ${item.step}',
      if (item.speed.isNotEmpty && !item.speed.toLowerCase().contains('retry'))
        '[SPEED] ${item.speed}',
      if (item.error != null) '[ERROR] ${item.error}',
      if (item.status == DownloadStatus.completed && item.error == null)
        l10n.nocturneLogCompleted,
      if (item.status == DownloadStatus.canceled) l10n.nocturneLogCanceled,
    ];
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.inputBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.primary.withValues(alpha: 0.08)),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          lines.join('\n'),
          style: nocturneMono(c, size: 11.5).copyWith(height: 1.6),
        ),
      ),
    );
  }
}
