import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/design_system/components/status_badge.dart';
import 'package:tapload/core/download/download_file_resolver.dart';
import 'package:tapload/core/download/download_queue_controller.dart';
import 'package:tapload/core/download/download_status_guard.dart';
import 'package:tapload/core/download/extraction_placeholders.dart';
import 'package:tapload/core/services/title_cleaner_service.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/ui/media_player/media_player_provider.dart';
import 'package:tapload/core/ui/widgets/log_viewer.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/views/dialogs/age_verification_help_dialog.dart';
import 'package:tapload/features/downloader/presentation/views/inspector/video_preview_widget.dart';
import 'package:tapload/features/downloader/presentation/widgets/confirm_file_deletion.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import '../shared/local_thumb.dart';
import 'studio_widgets.dart';

/// Studio's inspector, beside the table or in the narrow window's sheet:
/// a framed preview, the title as a headline, the facts as a captioned list,
/// then ringed actions and the log. Everything today's inspector offers:
/// play, show in folder, copy the link, pause / cancel / resume, retry,
/// delete (both ask first), the age-check help and the log.
class StudioInspector extends ConsumerStatefulWidget {
  const StudioInspector({super.key, required this.downloadId});

  final String downloadId;

  @override
  ConsumerState<StudioInspector> createState() => _StudioInspectorState();
}

class _StudioInspectorState extends ConsumerState<StudioInspector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    MediaQuery.disableAnimationsOf(context)
        ? _enter.value = 1
        : _enter.forward();
  }

  @override
  void didUpdateWidget(StudioInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.downloadId != widget.downloadId &&
        !MediaQuery.disableAnimationsOf(context)) {
      _enter.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  void _open(String path) {
    if (DownloadFileResolver.isMediaPath(path)) {
      ref.read(mediaPlayerProvider.notifier).openFile(path);
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final item = ref.watch(downloadItemByIdProvider(widget.downloadId));
    if (item == null) {
      return Center(
        child: Text(
          l10n.selectDownload,
          style: studioText(c, color: c.textSecondary),
        ),
      );
    }
    // Rebuilt on every progress tick, and the resolver may scan folders on
    // the UI thread: there is no playable file until the download ends.
    final path = DownloadQueueController.isBusy(item.status)
        ? null
        : DownloadFileResolver.resolvePlayablePath(
            item.filePath,
            title: item.title,
            outputFolder: item.request.outputFolder,
          );
    final title =
        item.status == DownloadStatus.extracting &&
            ExtractionPlaceholders.isGenericTitle(item.title)
        ? l10n.extractingTitle
        : TitleCleanerService.clean(item.title ?? l10n.unknown);
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        _Preview(item: item, path: path, onPlay: _open),
        if (path != null) ...[
          const SizedBox(height: 12),
          StudioButton(
            label: l10n.inspectorPlayMedia,
            icon: Icons.play_arrow_rounded,
            onTap: () {
              HapticFeedback.mediumImpact();
              _open(path);
            },
          ),
        ],
        const SizedBox(height: 20),
        Text(title, maxLines: 3, style: studioTitle(c, 20)),
        const SizedBox(height: 10),
        _StatusLine(item: item),
        const SizedBox(height: 18),
        _Fact(
          label: l10n.status,
          value: downloadStatusLabel(context, item.status),
        ),
        _Fact(
          label: l10n.progress,
          value: '${(item.progress * 100).toStringAsFixed(1)}%',
          mono: true,
        ),
        _Fact(label: l10n.inspectorId, value: item.id, mono: true),
        _Fact(
          label: l10n.inspectorSourceUrl,
          value: item.request.url,
          mono: true,
        ),
        if (path != null)
          _Fact(label: l10n.inspectorLocalFile, value: path, mono: true),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StudioButton(
              label: l10n.copyUrl,
              icon: Icons.link_rounded,
              kind: StudioButtonKind.light,
              height: 32,
              onTap: () {
                HapticFeedback.lightImpact();
                Clipboard.setData(ClipboardData(text: item.request.url));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.urlCopied),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            if (path != null)
              StudioButton(
                label: l10n.showInFolder,
                icon: Icons.folder_open_rounded,
                kind: StudioButtonKind.light,
                height: 32,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _reveal(path);
                },
              ),
          ],
        ),
        if (item.error != null) ...[
          const SizedBox(height: 20),
          _ErrorNote(item: item),
        ],
        const SizedBox(height: 20),
        const StudioRule(strong: true),
        const SizedBox(height: 16),
        _Actions(item: item),
        const SizedBox(height: 24),
        StudioCap(l10n.logs),
        const SizedBox(height: 8),
        Container(
          height: 200,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.border),
          ),
          child: LogViewer(
            logs: [
              l10n.designLogInit(item.id),
              if (item.status != DownloadStatus.queued) l10n.designLogStarted,
              if (item.step.isNotEmpty) '[STEP] ${item.step}',
              if (item.speed.isNotEmpty &&
                  !item.speed.toLowerCase().contains('retry'))
                '[SPEED] ${item.speed}',
              if (item.error != null) '[ERROR] ${item.error}',
              if (item.status == DownloadStatus.completed && item.error == null)
                l10n.designLogCompleted,
              if (item.status == DownloadStatus.canceled) l10n.designLogCanceled,
            ],
          ),
        ),
      ],
    );
    final enter = _enter.drive(CurveTween(curve: studioEase));
    return ColoredBox(
      color: c.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: AlignmentDirectional.centerStart,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: StudioCap(l10n.inspector),
          ),
          Expanded(
            child: FadeTransition(
              opacity: enter,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.03, 0),
                  end: Offset.zero,
                ).animate(enter),
                child: body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The preview: today's player framed in a hairline ring, a still while the
/// fullscreen player holds the device, else the thumbnail with an ink play
/// button when there is a file to play.
class _Preview extends ConsumerWidget {
  const _Preview({
    required this.item,
    required this.path,
    required this.onPlay,
  });

  final DownloadItem item;
  final String? path;
  final ValueChanged<String> onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final path = this.path;
    Widget frame(Widget child) => Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.primary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
    if (path != null &&
        DownloadFileResolver.isMediaPath(path) &&
        !DownloadFileResolver.isAudioPath(path)) {
      // The inspector's native player would steal the fullscreen player's
      // device: unmount it meanwhile.
      if (ref.watch(mediaPlayerProvider.select((s) => s.isOpen))) {
        return frame(
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: 0.35,
                  child: StudioThumb(item: item, radius: 0),
                ),
                Icon(
                  Icons.play_circle_outline_rounded,
                  color: c.surface.withValues(alpha: 0.7),
                  size: 40,
                ),
              ],
            ),
          ),
        );
      }
      return frame(
        VideoPreviewWidget(
          filePath: path,
          thumbnailUrl: item.thumbnailUrl,
          onFullscreen: () => onPlay(path),
        ),
      );
    }
    return frame(
      AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            StudioThumb(item: item, radius: 0),
            if (path != null)
              Center(
                child: Material(
                  color: c.surface,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onPlay(path),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: c.textPrimary,
                        size: 26,
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

/// The recording dot and percent while live, then the progress line.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final live = isActiveStatus(item.status);
    final failed =
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.canceled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (live) ...[const StudioRecDot(), const SizedBox(width: 8)],
            if (failed) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: c.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              downloadStatusLabel(context, item.status),
              style: studioText(c, color: failed ? c.error : c.textSecondary),
            ),
            if (live || item.status == DownloadStatus.paused) ...[
              const Spacer(),
              Text(
                '${(item.progress * 100).round()} %',
                style: studioMono(c, size: 12),
              ),
            ],
          ],
        ),
        if (live || item.status == DownloadStatus.paused) ...[
          const SizedBox(height: 8),
          StudioLine(value: item.progress),
        ],
      ],
    );
  }
}

bool isActiveStatus(DownloadStatus s) =>
    s == DownloadStatus.downloading ||
    s == DownloadStatus.extracting ||
    s == DownloadStatus.processing;

/// A captioned fact: the cap above, the value under it, a hairline below.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioCap(label),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: mono
                ? studioMono(c, size: 12, color: c.textPrimary)
                : studioText(c),
          ),
        ],
      ),
    );
  }
}

/// Why it failed, in red on the paper; for an age check, the way out.
class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final age = DownloadStatusGuard.isAgeVerificationFailure(
      error: item.error,
      url: item.request.url,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (age) ...[
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 15, color: c.error),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.ageCheckRequired,
                    style: studioText(
                      c,
                      color: c.error,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          SelectableText(
            item.error!,
            style: studioText(
              c,
              size: 12,
              color: age ? c.textSecondary : c.error,
            ).copyWith(height: 1.4),
          ),
          if (age) ...[
            const SizedBox(height: 12),
            StudioButton(
              label: l10n.ageCheckSeeSolutions,
              icon: Icons.help_outline_rounded,
              height: 32,
              onTap: () => AgeVerificationHelpDialog.show(context, item),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pause / cancel while live, resume when paused, retry (or restart a
/// finished one) and delete: the last two ask before touching the file.
class _Actions extends ConsumerWidget {
  const _Actions({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifier = ref.read(downloadListProvider.notifier);
    final status = item.status;
    final ended =
        status == DownloadStatus.failed ||
        status == DownloadStatus.canceled ||
        status == DownloadStatus.completed;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (isActiveStatus(status)) ...[
          StudioButton(
            label: l10n.pause,
            icon: Icons.pause_rounded,
            kind: StudioButtonKind.light,
            height: 32,
            onTap: () => notifier.pauseDownload(item.id),
          ),
          StudioButton(
            label: l10n.cancel,
            icon: Icons.close_rounded,
            kind: StudioButtonKind.danger,
            height: 32,
            onTap: () => notifier.cancelDownload(item.id),
          ),
        ],
        if (status == DownloadStatus.paused)
          StudioButton(
            label: l10n.resume,
            icon: Icons.play_arrow_rounded,
            height: 32,
            onTap: () => notifier.resumeDownload(item.id),
          ),
        if (ended)
          StudioButton(
            label: status == DownloadStatus.completed
                ? l10n.restartDownload
                : l10n.retry,
            icon: Icons.restart_alt_rounded,
            kind: status == DownloadStatus.completed
                ? StudioButtonKind.light
                : StudioButtonKind.ink,
            height: 32,
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
        StudioButton(
          label: l10n.delete,
          icon: Icons.delete_outline_rounded,
          kind: StudioButtonKind.light,
          height: 32,
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
    );
  }
}

/// The collapsed inspector: a paper rail with one ringed chevron.
class StudioInspectorRail extends StatelessWidget {
  const StudioInspectorRail({super.key, required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.of(context).surface,
      child: Center(
        child: StudioIconButton(
          icon: Icons.chevron_left_rounded,
          tooltip: context.l10n.expandInspector,
          onTap: onExpand,
        ),
      ),
    );
  }
}

/// An item's picture: its thumbnail (bundled, remote or local), else a
/// frame of the downloaded file, else a paper tone with a film glyph.
class StudioThumb extends StatelessWidget {
  const StudioThumb({super.key, required this.item, this.radius = 6});

  final DownloadItem item;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final placeholder = ColoredBox(
      color: Color.lerp(c.background, c.border, 0.5)!,
      child: Center(
        child: Icon(Icons.movie_outlined, size: 18, color: c.textDisabled),
      ),
    );
    final local = LocalVideoThumb(
      filePath: item.filePath,
      placeholder: placeholder,
      cacheWidth: 640,
    );
    Widget fallback(BuildContext _, Object _, StackTrace? _) => local;
    final u = item.thumbnailUrl;
    final Widget image;
    if (u == null || u.isEmpty) {
      image = local;
    } else if (u.startsWith('assets/')) {
      image = Image.asset(u, fit: BoxFit.cover, errorBuilder: fallback);
    } else if (u.startsWith('http://') || u.startsWith('https://')) {
      image = CachedNetworkImage(
        imageUrl: u,
        fit: BoxFit.cover,
        memCacheWidth: 640,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => local,
      );
    } else {
      var p = u;
      try {
        p = Uri.decodeFull(u);
      } catch (_) {}
      image = Image.file(
        File(p),
        fit: BoxFit.cover,
        cacheWidth: 640,
        errorBuilder: fallback,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.expand(child: image),
    );
  }
}
