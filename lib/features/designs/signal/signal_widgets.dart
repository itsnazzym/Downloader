import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';

/// Signal's building blocks, measured on the Main.dc.html mockup.

Duration signalMotion(BuildContext context, int ms) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: ms);

const Curve signalEase = Cubic(0.2, 0.8, 0.2, 1);

/// Bento card: 20px corners, a light top edge, hairline and two-layer
/// shadow; lifts 2px on hover when [lift].
class SignalCard extends StatefulWidget {
  const SignalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(28),
    this.lift = false,
    this.focus = false,
    this.ring,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool lift;

  /// Brighter hairline: the card the current section is about.
  final bool focus;

  /// Solid 1.5px outline (a selected card).
  final Color? ring;

  @override
  State<SignalCard> createState() => _SignalCardState();
}

class _SignalCardState extends State<SignalCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final up = widget.lift && _hover;
    return MouseRegion(
      onEnter: widget.lift ? (_) => setState(() => _hover = true) : null,
      onExit: widget.lift ? (_) => setState(() => _hover = false) : null,
      child: AnimatedContainer(
        duration: signalMotion(context, 280),
        curve: signalEase,
        transform: Matrix4.translationValues(0, up ? -2 : 0, 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                widget.ring ??
                colors.textPrimary.withValues(
                  alpha: widget.focus ? 0.3 : (up ? 0.14 : 0.08),
                ),
            width: widget.ring != null ? 1.5 : 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: const Alignment(0, -0.92),
            colors: [
              colors.textPrimary.withValues(alpha: 0.05),
              colors.surface,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: up ? 0.7 : 0.6),
              blurRadius: up ? 56 : 40,
              spreadRadius: up ? -14 : -12,
              offset: Offset(0, up ? 24 : 16),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Small grey label above a card's content ("Aujourd'hui", "File d'attente").
class SignalEyebrow extends StatelessWidget {
  const SignalEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTypography.body.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.24,
      color: AppColors.of(context).textDisabled,
    ),
  );
}

/// Pill button: accent fill with a top highlight, or a hairline ghost.
class SignalButton extends StatefulWidget {
  const SignalButton({
    super.key,
    required this.label,
    required this.onTap,
    this.accent = true,
    this.height = 44,
    this.fontSize = 14,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool accent;
  final double height;
  final double fontSize;
  final IconData? icon;

  @override
  State<SignalButton> createState() => _SignalButtonState();
}

class _SignalButtonState extends State<SignalButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = widget.accent;
    final fg = accent ? colors.onPrimary : colors.textPrimary;
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.98 : 1,
          duration: signalMotion(context, 120),
          child: AnimatedContainer(
            duration: signalMotion(context, 180),
            curve: signalEase,
            height: widget.height,
            padding: EdgeInsets.symmetric(horizontal: widget.height * 0.45),
            transform: Matrix4.translationValues(
              0,
              _down ? 1 : (_hover && enabled ? -1 : 0),
              0,
            ),
            decoration: BoxDecoration(
              color: accent
                  ? colors.primary
                  : (_hover ? colors.surfaceHighlight : Colors.transparent),
              borderRadius: BorderRadius.circular(999),
              border: accent
                  ? null
                  : Border.all(
                      color: colors.textPrimary.withValues(alpha: 0.16),
                    ),
              gradient: accent
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.alphaBlend(
                          Colors.white.withValues(alpha: 0.18),
                          colors.primary,
                        ),
                        colors.primary,
                        Color.alphaBlend(
                          Colors.black.withValues(alpha: 0.08),
                          colors.primary,
                        ),
                      ],
                      stops: const [0, 0.12, 1],
                    )
                  : null,
              boxShadow: accent
                  ? [
                      BoxShadow(
                        color: colors.primary.withValues(
                          alpha: _hover ? 0.28 : 0.2,
                        ),
                        blurRadius: _hover ? 30 : 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            // Centred, but as wide as the label (not the parent) in a Wrap.
            child: Center(
              widthFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: widget.fontSize + 2, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: AppTypography.body.copyWith(
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.w600,
                      color: fg,
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

/// Filter chip: hairline pill, cream fill when on.
class SignalChip extends StatefulWidget {
  const SignalChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  State<SignalChip> createState() => _SignalChipState();
}

class _SignalChipState extends State<SignalChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final on = widget.selected;
    final fg = on
        ? colors.background
        : (_hover ? colors.textPrimary : colors.textSecondary);
    return Semantics(
      selected: on,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: signalMotion(context, 200),
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: on ? colors.textPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: on
                    ? Colors.transparent
                    : colors.textPrimary.withValues(alpha: _hover ? 0.22 : 0.1),
              ),
            ),
            // Centred, but as wide as the label (not the parent) in a Wrap.
            child: Center(
              widthFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: AppTypography.body.copyWith(fontSize: 13, color: fg),
                  ),
                  if (widget.count != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${widget.count}',
                      style: AppTypography.mono.copyWith(
                        fontSize: 11,
                        color: fg.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thumbnail with a hairline and a bottom shade; a flat tone when there is
/// no image.
class SignalThumb extends StatelessWidget {
  const SignalThumb({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.radius = 10,
  });

  final String? url;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tone = Color.alphaBlend(
      colors.textPrimary.withValues(alpha: 0.08),
      colors.surface,
    );
    final decodeWidth = (width * 2.5).round();
    Widget image = ColoredBox(color: tone);
    final u = url;
    if (u != null && u.isNotEmpty) {
      Widget fallback(BuildContext c, Object e, StackTrace? s) =>
          ColoredBox(color: tone);
      if (u.startsWith('assets/')) {
        image = Image.asset(u, fit: BoxFit.cover, errorBuilder: fallback);
      } else if (u.startsWith('http://') || u.startsWith('https://')) {
        image = CachedNetworkImage(
          imageUrl: u,
          fit: BoxFit.cover,
          memCacheWidth: decodeWidth,
          placeholder: (c, _) => ColoredBox(color: tone),
          errorWidget: (c, _, _) => ColoredBox(color: tone),
          fadeInDuration: const Duration(milliseconds: 160),
        );
      } else {
        var path = u;
        try {
          path = Uri.decodeFull(u);
        } catch (_) {}
        image = Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: decodeWidth,
          errorBuilder: fallback,
        );
      }
    }
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: colors.textPrimary.withValues(alpha: 0.07),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                  stops: const [0.6, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page padding of the mockups: 32px sides, content capped at 1240px.
EdgeInsets signalPagePadding(double width, {double top = 32}) {
  final side = width > 1304 ? (width - 1240) / 2 : 32.0;
  return EdgeInsets.fromLTRB(side, top, side, 40);
}

/// Cards side by side with the mockup's flex ratios and equal heights, or
/// stacked below 900px.
Widget signalRow({
  required bool wide,
  required List<int> flexes,
  required List<Widget> children,
}) {
  if (!wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          children[i],
        ],
      ],
    );
  }
  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(flex: flexes[i], child: children[i]),
        ],
      ],
    ),
  );
}

/// A big display number with a smaller grey unit ("418 Go", "71%").
class SignalFigure extends StatelessWidget {
  const SignalFigure({
    super.key,
    required this.value,
    this.unit = '',
    this.size = 44,
    this.gap = 4,
  });

  final String value;
  final String unit;
  final double size;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text.rich(
      TextSpan(
        text: value,
        style: AppTypography.display(
          size,
          weight: FontWeight.w600,
        ).copyWith(color: colors.textPrimary),
        children: [
          if (unit.isNotEmpty)
            TextSpan(
              text: gap > 0 ? ' $unit' : unit,
              style: AppTypography.display(
                size / 2,
                weight: FontWeight.w600,
              ).copyWith(color: colors.textDisabled),
            ),
        ],
      ),
    );
  }
}

/// 6px sunken track with a cream fill ([value] 0..1).
class SignalMeter extends StatelessWidget {
  const SignalMeter({super.key, required this.value, this.color});

  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color ?? colors.textPrimary,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

/// Round initials badge on a faintly tinted surface.
class SignalAvatar extends StatelessWidget {
  const SignalAvatar({
    super.key,
    required this.name,
    this.size = 32,
    this.tint,
  });

  final String name;
  final double size;
  final Color? tint;

  static String initials(String name) {
    final words = name
        .replaceAll(RegExp(r'[@_.\-]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.characters.take(2).toString().toUpperCase();
    }
    return (words[0].characters.first + words[1].characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.alphaBlend(
          (tint ?? colors.textPrimary).withValues(alpha: 0.12),
          colors.surfaceHighlight,
        ),
        border: Border.all(color: colors.textPrimary.withValues(alpha: 0.1)),
      ),
      child: Text(
        initials(name),
        style: AppTypography.display(
          size * 0.375,
          weight: FontWeight.w600,
        ).copyWith(color: colors.textPrimary, letterSpacing: 0),
      ),
    );
  }
}
