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
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/age_verification_help_dialog.dart';
import 'package:modern_downloader/features/downloader/presentation/views/inspector/video_preview_widget.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/confirm_file_deletion.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'pastille_kit.dart';
import 'pastille_parts.dart';

/// Pastille's inspector: the selected download as a dark panel, its preview
/// framed in a tile of its state's tone, the big Sora percent, the facts in
/// hairline rows and pill actions. Same fields and actions as today's
/// inspector (preview and player, open file or folder, copy link, pause,
/// cancel, resume, restart, delete, age-check help, log).
class PastilleInspector extends ConsumerWidget {
  const PastilleInspector({
    super.key,
    required this.downloadId,
    this.onCollapse,
  });

  final String downloadId;
  final VoidCallback? onCollapse;

  static void _openFile(String path) {
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

  static void _openInFolder(String path) {
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

  /// Media in the built-in player, anything else with the system.
  static void _openMedia(WidgetRef ref, String path) {
    if (DownloadFileResolver.isMediaPath(path)) {
      ref.read(mediaPlayerProvider.notifier).openFile(path);
    } else {
      _openFile(path);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final item = ref.watch(downloadItemByIdProvider(downloadId));
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 14, 12),
      child: Row(
        children: [
          Icon(Icons.tune_rounded, size: 16, color: PTones.of(context).butter),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.inspector,
              style: pBody(size: 13, weight: FontWeight.w600, color: pCream),
            ),
          ),
          if (onCollapse != null)
            PButton(
              icon: Icons.chevron_right_rounded,
              tooltip: l10n.collapseInspector,
              kind: PButtonKind.ghost,
              height: 34,
              iconSize: 18,
              onTap: onCollapse,
            ),
        ],
      ),
    );
    if (item == null) {
      return Column(
        children: [
          header,
          Expanded(
            child: Center(
              child: Text(l10n.selectDownload, style: pBody(color: pMuted)),
            ),
          ),
        ],
      );
    }
    // Rebuilt on every progress tick; the resolver may scan folders, and a
    // busy download has no playable file yet.
    final path = DownloadQueueController.isBusy(item.status)
        ? null
        : DownloadFileResolver.resolvePlayablePath(
            item.filePath,
            title: item.title,
            outputFolder: item.request.outputFolder,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: TweenAnimationBuilder<double>(
            key: ValueKey(downloadId),
            tween: Tween(begin: 0, end: 1),
            duration: pMotion(context, 380),
            curve: pPop,
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(18 * (1 - t), 0),
                child: child,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
              child: _Body(item: item, path: path),
            ),
          ),
        ),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.item, required this.path});

  final DownloadItem item;
  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    final notifier = ref.read(downloadListProvider.notifier);
    final path = this.path;
    final busy =
        item.status == DownloadStatus.downloading ||
        item.status == DownloadStatus.extracting ||
        item.status == DownloadStatus.processing;
    final finished =
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.canceled ||
        item.status == DownloadStatus.completed;
    final pct = (item.progress * 100).clamp(0, 100);
    final title =
        item.status == DownloadStatus.extracting &&
            ExtractionPlaceholders.isGenericTitle(item.title)
        ? l10n.extractingTitle
        : TitleCleanerService.clean(item.title ?? l10n.unknown);
    final ageBlocked = DownloadStatusGuard.isAgeVerificationFailure(
      error: item.error,
      url: item.request.url,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Preview(item: item, path: path),
        const SizedBox(height: 18),
        Semantics(
          header: true,
          child: Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: pNum(
              21,
              weight: FontWeight.w700,
              color: pCream,
            ).copyWith(height: 1.2, letterSpacing: -0.5),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text.rich(
              TextSpan(
                text: pct.floor().toString(),
                style: pNum(48, color: pCream),
                children: [
                  TextSpan(
                    text: '%',
                    style: pNum(24, color: pCream),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: PStatusPill(status: item.status),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PDots(
          count: 50,
          columns: 25,
          gap: 4,
          on: (pct / 2).floor(),
          live: busy,
          paused: !busy,
          semanticLabel: '${pct.toStringAsFixed(1)} %',
        ),
        if (path != null) ...[
          const SizedBox(height: 18),
          PButton(
            label: l10n.inspectorPlayMedia,
            icon: Icons.play_arrow_rounded,
            iconSize: 20,
            kind: PButtonKind.butter,
            height: 46,
            expand: true,
            onTap: () {
              HapticFeedback.mediumImpact();
              PastilleInspector._openMedia(ref, path);
            },
          ),
        ],
        const SizedBox(height: 18),
        _Fact(
          label: l10n.status,
          value: downloadStatusLabel(context, item.status),
          first: true,
        ),
        _Fact(
          label: l10n.progress,
          value: '${(item.progress * 100).toStringAsFixed(1)}%',
        ),
        _Fact(label: l10n.title, value: title),
        _Fact(label: l10n.inspectorId, value: item.id, mono: true),
        _Fact(
          label: l10n.inspectorSourceUrl,
          value: item.request.url,
          mono: true,
        ),
        if (path != null)
          _Fact(label: l10n.inspectorLocalFile, value: path, mono: true),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PButton(
              label: l10n.copyUrl,
              icon: Icons.link_rounded,
              iconSize: 15,
              kind: PButtonKind.ghost,
              height: 38,
              padH: 14,
              onTap: () {
                HapticFeedback.lightImpact();
                Clipboard.setData(ClipboardData(text: item.request.url));
                pNotice(context, l10n.urlCopied);
              },
            ),
            if (path != null)
              PButton(
                label: l10n.showInFolder,
                icon: Icons.folder_open_rounded,
                iconSize: 15,
                kind: PButtonKind.ghost,
                height: 38,
                padH: 14,
                onTap: () {
                  HapticFeedback.lightImpact();
                  PastilleInspector._openInFolder(path);
                },
              ),
          ],
        ),
        if (item.error != null) ...[
          const SizedBox(height: 18),
          _ErrorTile(item: item, ageBlocked: ageBlocked),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (busy) ...[
              PButton(
                label: l10n.pause,
                icon: Icons.pause_rounded,
                kind: PButtonKind.cream,
                height: 40,
                padH: 16,
                onTap: () => notifier.pauseDownload(item.id),
              ),
              PButton(
                label: l10n.cancel,
                icon: Icons.close_rounded,
                kind: PButtonKind.rose,
                height: 40,
                padH: 16,
                onTap: () => notifier.cancelDownload(item.id),
              ),
            ],
            if (item.status == DownloadStatus.paused)
              PButton(
                label: l10n.resume,
                icon: Icons.play_arrow_rounded,
                kind: PButtonKind.butter,
                height: 40,
                padH: 16,
                onTap: () => notifier.resumeDownload(item.id),
              ),
            if (finished)
              PButton(
                label: item.status == DownloadStatus.completed
                    ? l10n.restartDownload
                    : l10n.retry,
                icon: Icons.restart_alt_rounded,
                kind: PButtonKind.cream,
                height: 40,
                padH: 16,
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
            PButton(
              label: l10n.delete,
              icon: Icons.delete_outline_rounded,
              kind: PButtonKind.ghost,
              height: 40,
              padH: 16,
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
        const SizedBox(height: 22),
        Text(
          l10n.logs,
          style: pBody(size: 13, weight: FontWeight.w600, color: pCream),
        ),
        const SizedBox(height: 8),
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: pInkDeep,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: pCream.withValues(alpha: 0.06), spreadRadius: 1),
            ],
          ),
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              for (final line in [
                l10n.designLogInit(item.id),
                if (item.status != DownloadStatus.queued) l10n.designLogStarted,
                if (item.step.isNotEmpty) '[STEP] ${item.step}',
                if (item.speed.isNotEmpty &&
                    !item.speed.toLowerCase().contains('retry'))
                  '[SPEED] ${item.speed}',
                if (item.error != null) '[ERROR] ${item.error}',
                if (item.status == DownloadStatus.completed &&
                    item.error == null)
                  l10n.designLogCompleted,
                if (item.status == DownloadStatus.canceled)
                  l10n.designLogCanceled,
              ])
                SelectableText(
                  line,
                  style: pMono(
                    size: 11.5,
                    color: line.startsWith('[ERROR]') ? tones.rose : pMuted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The preview in a tile of the download's tone: the player for a video
/// file, a dimmed still while the full-screen player owns the video device,
/// else the thumbnail with a play pill when there is a file.
class _Preview extends ConsumerWidget {
  const _Preview({required this.item, required this.path});

  final DownloadItem item;
  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final path = this.path;
    final video =
        path != null &&
        DownloadFileResolver.isMediaPath(path) &&
        !DownloadFileResolver.isAudioPath(path);
    final fullscreen =
        video && ref.watch(mediaPlayerProvider.select((s) => s.isOpen));
    final Widget inner;
    if (video && !fullscreen) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: VideoPreviewWidget(
          filePath: path,
          thumbnailUrl: item.thumbnailUrl,
          onFullscreen: () => PastilleInspector._openMedia(ref, path),
        ),
      );
    } else {
      inner = SizedBox(
        height: 190,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: fullscreen ? 0.4 : 1,
              child: PThumb(
                url: item.thumbnailUrl,
                filePath: item.filePath,
                tone: pInk.withValues(alpha: 0.12),
                radius: 18,
              ),
            ),
            if (fullscreen)
              const Icon(
                Icons.play_circle_fill_rounded,
                size: 48,
                color: pCream,
              )
            else if (path != null)
              PButton(
                icon: Icons.play_arrow_rounded,
                tooltip: l10n.inspectorPlayMedia,
                height: 52,
                iconSize: 24,
                onTap: () => PastilleInspector._openMedia(ref, path),
              )
            else if (item.thumbnailUrl == null)
              Icon(
                Icons.movie_creation_outlined,
                size: 40,
                color: pInk.withValues(alpha: 0.45),
              ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: pToneOf(context, item.status),
        borderRadius: BorderRadius.circular(26),
      ),
      child: inner,
    );
  }
}

/// A fact: a soft label over its value, hairline between facts.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    this.mono = false,
    this.first = false,
  });

  final String label;
  final String value;
  final bool mono;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(
                top: BorderSide(
                  color: pCream.withValues(alpha: 0.08),
                  width: 1.5,
                ),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: pBody(size: 12, weight: FontWeight.w500, color: pFaint),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: mono
                ? pMono(size: 12.5, color: pCream)
                : pBody(size: 13.5, weight: FontWeight.w600, color: pCream),
          ),
        ],
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.item, required this.ageBlocked});

  final DownloadItem item;
  final bool ageBlocked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: ageBlocked ? tones.butter : tones.rose,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                ageBlocked
                    ? Icons.shield_outlined
                    : Icons.error_outline_rounded,
                size: 18,
                color: pInk,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ageBlocked
                      ? l10n.ageCheckRequired
                      : (downloadErrorReason(item.error).isEmpty
                            ? l10n.designFailed
                            : downloadErrorReason(item.error)),
                  style: pBody(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: pInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            item.error!,
            style: pBody(size: 12.5, color: pSubInk, height: 1.35),
          ),
          if (ageBlocked) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: PButton(
                label: l10n.ageCheckSeeSolutions,
                icon: Icons.help_outline_rounded,
                iconSize: 15,
                height: 38,
                onTap: () => AgeVerificationHelpDialog.show(context, item),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
