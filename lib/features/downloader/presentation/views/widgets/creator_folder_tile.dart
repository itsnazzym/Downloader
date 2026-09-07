import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:modern_downloader/core/design_system/foundation/colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/features/downloader/presentation/models/creator_folder.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

/// Samsung-style vault tile: double-bezel well with a 2×2 peek mosaic.
class CreatorFolderTile extends StatefulWidget {
  const CreatorFolderTile({
    super.key,
    required this.folder,
    required this.onOpen,
    this.staggerIndex = 0,
  });

  final CreatorFolder folder;
  final VoidCallback onOpen;
  final int staggerIndex;

  static const motion = Cubic(0.32, 0.72, 0, 1);

  @override
  State<CreatorFolderTile> createState() => _CreatorFolderTileState();
}

class _CreatorFolderTileState extends State<CreatorFolderTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final title = widget.folder.isUnknown
        ? l10n.folderUnknownCreator
        : '@${widget.folder.handle}';
    final delayMs = reduce ? 0 : (widget.staggerIndex.clamp(0, 11) * 36);

    return Semantics(
      button: true,
      label: '$title, ${l10n.folderVideoCount(widget.folder.count)}',
      child: Tooltip(
        message: l10n.folderOpenHint,
        waitDuration: const Duration(milliseconds: 500),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: reduce ? 1 : 0, end: 1),
          duration: Duration(milliseconds: reduce ? 0 : 700 + delayMs),
          curve: CreatorFolderTile.motion,
          builder: (context, t, child) {
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 18 * (1 - t)),
                child: child,
              ),
            );
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: AnimatedScale(
                      scale: _hovering ? 1.035 : 1,
                      duration: Duration(milliseconds: reduce ? 0 : 420),
                      curve: CreatorFolderTile.motion,
                      child: _FolderWell(
                        hovering: _hovering,
                        child: _PeekMosaic(
                          urls: widget.folder.previewUrls,
                          overflowCount: widget.folder.overflowCount,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.15,
                      height: 1.15,
                      color: colors.textPrimary.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.folderVideoCount(widget.folder.count),
                    textAlign: TextAlign.center,
                    style: AppTypography.mono.copyWith(
                      fontSize: 10,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: colors.textSecondary.withValues(alpha: 0.78),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderWell extends StatelessWidget {
  const _FolderWell({required this.hovering, required this.child});

  final bool hovering;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final outerRadius = BorderRadius.circular(28);
    final innerRadius = BorderRadius.circular(22);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: CreatorFolderTile.motion,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: outerRadius,
        color: Color.lerp(
          colors.surface.withValues(alpha: 0.55),
          colors.surfaceHighlight.withValues(alpha: 0.72),
          hovering ? 1 : 0,
        ),
        border: Border.all(
          color: hovering
              ? colors.primary.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: hovering
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : const [],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: innerRadius,
          color: colors.background.withValues(alpha: 0.92),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: innerRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x14FFFFFF), Color(0x00000000)],
                  ),
                ),
              ),
              Padding(padding: const EdgeInsets.all(8), child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeekMosaic extends StatelessWidget {
  const _PeekMosaic({required this.urls, required this.overflowCount});

  final List<String?> urls;
  final int overflowCount;

  @override
  Widget build(BuildContext context) {
    if (urls.length == 1) {
      return _ThumbCell(url: urls.first, radius: 14);
    }

    Widget cell(int index) {
      final url = index < urls.length ? urls[index] : null;
      final showOverflow = index == 3 && overflowCount > 0;
      return _ThumbCell(
        url: url,
        radius: 8,
        overflowLabel: showOverflow ? '+$overflowCount' : null,
      );
    }

    const gap = SizedBox(width: 4, height: 4);
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: cell(0)),
              gap,
              Expanded(child: cell(1)),
            ],
          ),
        ),
        gap,
        Expanded(
          child: Row(
            children: [
              Expanded(child: cell(2)),
              gap,
              Expanded(child: cell(3)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThumbCell extends StatelessWidget {
  const _ThumbCell({this.url, this.overflowLabel, this.radius = 8});

  final String? url;
  final String? overflowLabel;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: colors.surfaceHighlight.withValues(alpha: 0.55)),
          if (url != null) Positioned.fill(child: _ThumbImage(url: url!)),
          if (overflowLabel != null)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xA608080A),
                child: Center(
                  child: Text(
                    overflowLabel!,
                    style: AppTypography.mono.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xF5F5F5F0),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThumbImage extends StatelessWidget {
  const _ThumbImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fallback = ColoredBox(
      color: colors.surfaceHighlight,
      child: Icon(
        Icons.play_arrow_rounded,
        size: 16,
        color: colors.textSecondary.withValues(alpha: 0.35),
      ),
    );

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 180),
        errorWidget: (context, _, _) => fallback,
        placeholder: (context, _) => fallback,
      );
    }

    var path = url;
    try {
      path = Uri.decodeFull(url);
    } catch (_) {}

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, _, _) => fallback,
    );
  }
}
