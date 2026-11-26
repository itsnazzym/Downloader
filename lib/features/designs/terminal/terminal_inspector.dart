import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/design_system/components/status_badge.dart';
import 'package:modern_downloader/core/download/download_file_resolver.dart';
import 'package:modern_downloader/core/download/download_queue_controller.dart';
import 'package:modern_downloader/core/download/download_status_guard.dart';
import 'package:modern_downloader/core/download/extraction_placeholders.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/age_verification_help_dialog.dart';
import 'package:modern_downloader/features/downloader/presentation/views/inspector/video_preview_widget.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/confirm_file_deletion.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'terminal_widgets.dart';

/// Terminal's inspector: `## inspecteur`, the framed preview, `key value`
/// fields, key buttons and the log as printed lines. Same fields and
/// actions as today's inspector (desktop only: no Android share/open-with).
class TerminalInspector extends ConsumerWidget {
  const TerminalInspector({super.key, required this.downloadId});

  final String downloadId;

  static void _reveal(String path) {
    if (Platform.isWindows) {
      Process.run('explorer', ['/select,', path]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [File(path).parent.path]);
    }
  }

  static void _openOutside(String path) {
    if (Platform.isWindows) {
      Process.run('explorer', [path]);
    } else if (Platform.isMacOS) {
      Process.run('open', [path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [path]);
    }
  }

  // Media plays in the app's player, anything else opens outside.
  static void _open(WidgetRef ref, String path) {
    if (DownloadFileResolver.isMediaPath(path)) {
      ref.read(mediaPlayerProvider.notifier).openFile(path);
    } else {
      _openOutside(path);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final item = ref.watch(downloadItemByIdProvider(downloadId));
    if (item == null) {
      return Center(
        child: Text('# ${l10n.selectDownload}', style: tm(colors.textDisabled)),
      );
    }
    // Rebuilt on every progress tick: no file to resolve (and no folder
    // scan on the UI thread) until the download ends.
    final path = DownloadQueueController.isBusy(item.status)
        ? null
        : DownloadFileResolver.resolvePlayablePath(
            item.filePath,
            title: item.title,
            outputFolder: item.request.outputFolder,
          );
    final notifier = ref.read(downloadListProvider.notifier);
    final busy =
        item.status == DownloadStatus.downloading ||
        item.status == DownloadStatus.extracting ||
        item.status == DownloadStatus.processing;
    final restartable =
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.canceled ||
        item.status == DownloadStatus.completed;
    final title =
        item.status == DownloadStatus.extracting &&
            ExtractionPlaceholders.isGenericTitle(item.title)
        ? l10n.extractingTitle
        : TitleCleanerService.clean(item.title ?? l10n.unknown);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: AlignmentDirectional.centerStart,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Text(
            '## ${l10n.inspector.toLowerCase()}',
            style: tm(colors.primary, weight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Preview(item: item, path: path, onOpen: (p) => _open(ref, p)),
                if (path != null) ...[
                  const SizedBox(height: 10),
                  TButton(
                    label: l10n.inspectorPlayMedia,
                    kind: TButtonKind.primary,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _open(ref, path);
                    },
                  ),
                ],
                const SizedBox(height: 14),
                _Field(l10n.title, title),
                _Field(l10n.status, downloadStatusLabel(context, item.status)),
                _Field(
                  l10n.progress,
                  '${(item.progress * 100).toStringAsFixed(1)}%',
                  bar: item.progress,
                ),
                _Field(l10n.inspectorId, item.id),
                _Field(l10n.inspectorSourceUrl, item.request.url),
                if (path != null) _Field(l10n.inspectorLocalFile, path),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TButton(
                      label: l10n.copyUrl,
                      height: 28,
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
                      TButton(
                        label: l10n.showInFolder,
                        height: 28,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _reveal(path);
                        },
                      ),
                  ],
                ),
                if (item.error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBlock(item: item),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (busy) ...[
                      TButton(
                        label: l10n.pause,
                        height: 28,
                        onTap: () => notifier.pauseDownload(item.id),
                      ),
                      TButton(
                        label: l10n.cancel,
                        height: 28,
                        kind: TButtonKind.danger,
                        onTap: () => notifier.cancelDownload(item.id),
                      ),
                    ],
                    if (item.status == DownloadStatus.paused)
                      TButton(
                        label: l10n.resume,
                        height: 28,
                        onTap: () => notifier.resumeDownload(item.id),
                      ),
                    if (restartable)
                      TButton(
                        label: item.status == DownloadStatus.completed
                            ? l10n.restartDownload
                            : l10n.retry,
                        height: 28,
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
                    TButton(
                      label: l10n.delete,
                      height: 28,
                      kind: TButtonKind.danger,
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
                const SizedBox(height: 18),
                Text(
                  '## ${l10n.logs.toLowerCase()}',
                  style: tm(colors.textDisabled),
                ),
                const SizedBox(height: 6),
                _Log(item: item),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The preview in a hairline frame; while the fullscreen player is open the
/// inline player unmounts (it would steal the video device).
class _Preview extends ConsumerWidget {
  const _Preview({
    required this.item,
    required this.path,
    required this.onOpen,
  });

  final DownloadItem item;
  final String? path;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final p = path;
    final video =
        p != null &&
        DownloadFileResolver.isMediaPath(p) &&
        !DownloadFileResolver.isAudioPath(p);
    if (video && !ref.watch(mediaPlayerProvider.select((s) => s.isOpen))) {
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(border: Border.all(color: colors.border)),
        child: ClipRect(
          child: VideoPreviewWidget(
            filePath: p,
            thumbnailUrl: item.thumbnailUrl,
            onFullscreen: () => onOpen(p),
          ),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.5,
            child: TThumb(url: item.thumbnailUrl, filePath: item.filePath),
          ),
          if (video)
            Center(
              child: Text(
                '▶ ${context.l10n.inspectorPlayMedia.toLowerCase()}',
                style: tm(colors.textSecondary),
              ),
            )
          else if (p != null)
            Center(
              child: TButton(
                label: '▶',
                square: true,
                kind: TButtonKind.primary,
                height: 40,
                tooltip: context.l10n.inspectorPlayMedia,
                onTap: () => onOpen(p),
              ),
            ),
        ],
      ),
    );
  }
}

/// `label` dim over its value; the progress also gets a segmented bar.
class _Field extends StatelessWidget {
  const _Field(this.label, this.value, {this.bar});

  final String label;
  final String value;
  final double? bar;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label.toLowerCase(), style: tm(colors.textDisabled)),
          const SizedBox(height: 2),
          if (bar != null)
            Row(
              children: [
                Expanded(child: TSeg(value: bar!, height: 8)),
                const SizedBox(width: 10),
                Text(value, style: tm(colors.textPrimary)),
              ],
            )
          else
            Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: tm(colors.textPrimary),
            ),
        ],
      ),
    );
  }
}

/// The failure as an `err` block; an age check gets its help instead.
class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final age = DownloadStatusGuard.isAgeVerificationFailure(
      error: item.error,
      url: item.request.url,
    );
    return TPanel(
      accentLeft: age ? colors.warning : colors.error,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            age ? '18+  ${l10n.ageCheckRequired}' : l10n.terminalStateErr,
            style: tm(
              age ? colors.warning : colors.error,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.error!,
            style: tm(
              age ? colors.textPrimary : colors.error,
            ).copyWith(height: 1.4),
          ),
          if (age) ...[
            const SizedBox(height: 10),
            TButton(
              label: l10n.ageCheckSeeSolutions,
              height: 28,
              onTap: () => AgeVerificationHelpDialog.show(context, item),
            ),
          ],
        ],
      ),
    );
  }
}

/// Today's log lines, printed on the background.
class _Log extends StatelessWidget {
  const _Log({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final lines = [
      l10n.terminalLogInit(item.id),
      if (item.status != DownloadStatus.queued) l10n.terminalLogStarted,
      if (item.step.isNotEmpty) '[STEP] ${item.step}',
      if (item.speed.isNotEmpty && !item.speed.toLowerCase().contains('retry'))
        '[SPEED] ${item.speed}',
      if (item.error != null) '[ERROR] ${item.error}',
      if (item.status == DownloadStatus.completed && item.error == null)
        l10n.terminalLogDone,
      if (item.status == DownloadStatus.canceled) l10n.terminalLogCanceled,
    ];
    return TPanel(
      color: colors.background,
      padding: const EdgeInsets.all(10),
      child: SelectableText.rich(
        TextSpan(
          children: [
            for (final (i, l) in lines.indexed)
              TextSpan(
                text: '${i == 0 ? '' : '\n'}› $l',
                style: tm(
                  l.startsWith('[ERROR]') ? colors.error : colors.textSecondary,
                ),
              ),
          ],
        ),
        style: tm(colors.textSecondary).copyWith(height: 1.5),
      ),
    );
  }
}

/// The collapsed inspector: a thin rail with one `‹` key to open it again.
class TerminalInspectorRail extends StatelessWidget {
  const TerminalInspectorRail({super.key, required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.of(context).surface,
    child: Center(
      child: TButton(
        label: '‹',
        square: true,
        tooltip: context.l10n.expandInspector,
        onTap: onExpand,
      ),
    ),
  );
}
