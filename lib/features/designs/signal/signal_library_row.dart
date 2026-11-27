import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/design_system/components/design_progress_bar.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'signal_controls.dart';
import 'signal_widgets.dart';

/// Plays a finished download in the built-in player.
void signalPlay(WidgetRef ref, DownloadItem item) {
  final path = item.filePath;
  if (path != null && File(path).existsSync()) {
    ref.read(mediaPlayerProvider.notifier).openFile(path);
  }
}

/// Shows a finished download in Explorer.
void signalReveal(DownloadItem item) {
  final path = item.filePath;
  if (path != null && File(path).existsSync() && Platform.isWindows) {
    Process.run('explorer', ['/select,', path]);
  }
}

/// One library item in Signal: a thumbnail, title, source · format · size
/// (or progress and speed, or the failure reason), a thin live bar while it
/// downloads, Réessayer on a failure, and play / folder / delete on hover.
/// [grid] draws it as a card. The home's list and the shared list (folders)
/// both use it.
class SignalLibraryRow extends ConsumerStatefulWidget {
  const SignalLibraryRow({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onRetry,
    required this.onDelete,
    this.onDoubleTap,
    this.grid = false,
  });

  final DownloadItem item;
  final bool selected;
  final bool grid;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback onRetry;
  final VoidCallback onDelete;

  @override
  ConsumerState<SignalLibraryRow> createState() => _SignalLibraryRowState();
}

class _SignalLibraryRowState extends ConsumerState<SignalLibraryRow> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final item = widget.item;
    final selected = widget.selected;
    final failed =
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.canceled;
    final busy = isActiveDownload(item) || item.status == DownloadStatus.queued;
    final size = bytesOf(item);
    final reason = downloadErrorReason(item.error);
    final failLabel = item.status == DownloadStatus.canceled
        ? l10n.statusCanceled
        : l10n.designFailed;
    final speed = parseSpeed(item.speed);
    final phase = livePhase(item, speed);
    final rate = formatSpeed(l10n, speed);
    final meta = failed
        ? (reason.isEmpty ? failLabel : '$failLabel · $reason')
        : busy
        ? [
            item.source,
            '${(item.progress * 100).round()} %',
            if (phase != null)
              livePhaseLabel(l10n, phase)
            else if (item.status == DownloadStatus.paused)
              l10n.statusPaused
            else if (item.status == DownloadStatus.queued)
              l10n.statusQueued
            else if (speed != null)
              '${rate.value} ${rate.unit}',
          ].where((s) => s.isNotEmpty).join(' · ')
        : [
            item.source,
            formatLabelOf(item),
            if (size > 0) localBytes(l10n, size),
          ].where((s) => s.isNotEmpty).join(' · ');
    final done = item.status == DownloadStatus.completed;
    final showActions = _hover || _focus;

    final title = Text(
      titleOf(item),
      maxLines: widget.grid ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.body.copyWith(
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: colors.textPrimary,
      ),
    );
    final metaText = Text(
      meta,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.body.copyWith(
        fontSize: 12.5,
        color: failed ? colors.error : colors.textDisabled,
      ),
    );
    final bar = busy
        ? Padding(
            padding: const EdgeInsets.only(top: 6),
            child: DesignProgressBar(
              value: item.progress,
              height: 3,
              live: item.status == DownloadStatus.downloading,
            ),
          )
        : null;
    final retry = failed
        ? SignalButton(
            label: l10n.retry,
            icon: Icons.refresh_rounded,
            accent: false,
            height: 32,
            fontSize: 12.5,
            onTap: widget.onRetry,
          )
        : null;
    final actions = AnimatedOpacity(
      opacity: showActions ? 1 : 0,
      duration: signalMotion(context, 180),
      child: IgnorePointer(
        ignoring: !showActions,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (done) ...[
              SignalIconButton(
                icon: Icons.play_arrow_rounded,
                tooltip: l10n.detailsPlayVideo,
                onTap: () => signalPlay(ref, item),
              ),
              SignalIconButton(
                icon: Icons.folder_open_rounded,
                tooltip: l10n.openFolder,
                onTap: () => signalReveal(item),
              ),
            ],
            SignalIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: l10n.delete,
              onTap: widget.onDelete,
            ),
          ],
        ),
      ),
    );

    final Widget content;
    if (widget.grid) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                LayoutBuilder(
                  builder: (context, c) => SignalThumb(
                    url: item.thumbnailUrl,
                    filePath: item.filePath,
                    width: c.maxWidth,
                    height: c.maxHeight,
                    radius: 14,
                  ),
                ),
                Positioned(top: 6, right: 6, child: actions),
              ],
            ),
          ),
          const SizedBox(height: 12),
          title,
          const SizedBox(height: 4),
          metaText,
          if (bar != null) bar,
          if (retry != null) ...[
            const SizedBox(height: 10),
            Align(alignment: AlignmentDirectional.centerStart, child: retry),
          ],
        ],
      );
    } else {
      content = Row(
        children: [
          SignalThumb(
            url: item.thumbnailUrl,
            filePath: item.filePath,
            width: 88,
            height: 50,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 2),
                metaText,
                if (bar != null) bar,
              ],
            ),
          ),
          if (retry != null) ...[const SizedBox(width: 12), retry],
          actions,
        ],
      );
    }

    return Semantics(
      selected: selected,
      button: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (h) => setState(() => _hover = h),
        onShowFocusHighlight: (f) => setState(() => _focus = f),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap ?? () => signalPlay(ref, item),
          child: AnimatedContainer(
            duration: signalMotion(context, 180),
            curve: signalEase,
            padding: widget.grid
                ? const EdgeInsets.all(12)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected || _hover || widget.grid
                  ? colors.surface
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(widget.grid ? 20 : 14),
              border: Border.all(
                color: selected || _focus
                    ? colors.primary.withValues(alpha: _focus ? 1 : 0.5)
                    : (widget.grid
                          ? colors.textPrimary.withValues(
                              alpha: _hover ? 0.14 : 0.08,
                            )
                          : Colors.transparent),
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
