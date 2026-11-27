import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../shared/empty_art.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';

/// Nocturne's building blocks, measured on the Nocturne*.dc.html mockups.

Duration nocturneMotion(BuildContext context, int ms) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: ms);

const Curve nocturneEase = Cubic(0.2, 0.8, 0.2, 1);

/// Ring and bar track (#1B2442 on the mockup).
Color nocturneTrack(AppColors c) => Color.lerp(c.surface, c.primary, 0.08)!;

/// Page padding of every Nocturne page (main: 34px 40px).
const nocturnePagePadding = EdgeInsets.fromLTRB(40, 34, 40, 40);

TextStyle nocturneText(
  AppColors c, {
  double size = 13.5,
  FontWeight weight = FontWeight.w400,
  Color? color,
}) => AppTypography.body.copyWith(
  fontSize: size,
  fontWeight: weight,
  height: 1.35,
  color: color ?? c.textPrimary,
);

TextStyle nocturneMono(AppColors c, {double size = 12, Color? color}) =>
    AppTypography.mono.copyWith(
      fontSize: size,
      height: 1.35,
      color: color ?? c.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Page title: 30/700, tight tracking.
TextStyle nocturneDisplay(AppColors c) => AppTypography.display(
  30,
  weight: FontWeight.w700,
).copyWith(letterSpacing: -0.9, height: 1.37, color: c.textPrimary);

/// `.cardn`: 18px corners, a periwinkle hairline and a deep shadow; lifts
/// 2px on hover. [highlight] draws the 1.5px selected ring.
class NocturneCard extends StatefulWidget {
  const NocturneCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.lift = true,
    this.highlight = false,
    this.strongHighlight = false,
    this.color,
    this.radius = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool lift;
  final bool highlight;

  /// Full-accent ring (selected collection) instead of the soft one.
  final bool strongHighlight;
  final Color? color;
  final double radius;

  @override
  State<NocturneCard> createState() => _NocturneCardState();
}

class _NocturneCardState extends State<NocturneCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final up = widget.lift && _hover;
    final ring = widget.strongHighlight
        ? c.primary
        : widget.highlight
        ? c.primary.withValues(alpha: 0.55)
        : c.primary.withValues(alpha: up ? 0.16 : 0.08);
    final card = AnimatedContainer(
      duration: nocturneMotion(context, 250),
      curve: nocturneEase,
      transform: Matrix4.translationValues(0, up ? -2 : 0, 0),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color ?? c.surface,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(
          color: ring,
          width: widget.highlight || widget.strongHighlight ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: up ? 0.5 : 0.4),
            blurRadius: up ? 48 : 40,
            offset: Offset(0, up ? 24 : 18),
          ),
        ],
      ),
      child: widget.child,
    );
    if (!widget.lift) return card;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: card,
    );
  }
}

enum NocturneButtonKind { plain, primary, ghost, danger }

/// `.btn` and its variants: plain (#18213A), primary (accent with glow),
/// ghost and danger. Lifts 1px on hover, accent ring on keyboard focus.
class NocturneButton extends StatefulWidget {
  const NocturneButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = NocturneButtonKind.plain,
    this.icon,
    this.height = 38,
    this.radius = 12,
    this.fontSize = 13,
    this.weight,
    this.padding = 16,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onTap;
  final NocturneButtonKind kind;
  final IconData? icon;
  final double height;
  final double radius;
  final double fontSize;
  final FontWeight? weight;
  final double padding;
  final String? tooltip;

  @override
  State<NocturneButton> createState() => _NocturneButtonState();
}

class _NocturneButtonState extends State<NocturneButton> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = widget.onTap != null;
    final hover = _hover && enabled;
    final (Color bg, Color fg, FontWeight w) = switch (widget.kind) {
      NocturneButtonKind.plain => (
        hover
            ? Color.lerp(c.surfaceHighlight, c.primary, 0.05)!
            : c.surfaceHighlight,
        c.textPrimary,
        FontWeight.w600,
      ),
      NocturneButtonKind.primary => (
        hover ? Color.lerp(c.primary, Colors.white, 0.15)! : c.primary,
        c.background,
        FontWeight.w700,
      ),
      NocturneButtonKind.ghost => (
        hover ? c.primary.withValues(alpha: 0.08) : Colors.transparent,
        hover ? c.textPrimary : c.textSecondary,
        FontWeight.w600,
      ),
      NocturneButtonKind.danger => (
        c.error.withValues(alpha: hover ? 0.16 : 0.1),
        c.error,
        FontWeight.w600,
      ),
    };
    final radius = BorderRadius.circular(widget.radius);
    Widget button = Opacity(
      opacity: enabled ? 1 : 0.45,
      child: AnimatedContainer(
        duration: nocturneMotion(context, 200),
        curve: nocturneEase,
        transform: Matrix4.translationValues(0, hover ? -1 : 0, 0),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: Border.all(
            color: _focus
                ? c.primary
                : widget.kind == NocturneButtonKind.danger
                ? c.error.withValues(alpha: 0.22)
                : Colors.transparent,
            width: _focus ? 2 : 1,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
          boxShadow: widget.kind == NocturneButtonKind.primary
              ? [
                  BoxShadow(
                    color: c.primary.withValues(alpha: 0.3),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onHover: (v) => setState(() => _hover = v),
            onFocusChange: (v) => setState(() => _focus = v),
            borderRadius: radius,
            hoverColor: Colors.transparent,
            mouseCursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.forbidden,
            child: Container(
              height: widget.height,
              padding: EdgeInsets.symmetric(horizontal: widget.padding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 16, color: fg),
                    if (widget.label.isNotEmpty) const SizedBox(width: 8),
                  ],
                  if (widget.label.isNotEmpty)
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: nocturneText(
                          c,
                          size: widget.fontSize,
                          weight: widget.weight ?? w,
                          color: fg,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final tip = widget.tooltip;
    if (tip != null) button = Tooltip(message: tip, child: button);
    return button;
  }
}

/// Square icon-only button (stepper, row actions); 36px target.
class NocturneIconButton extends StatelessWidget {
  const NocturneIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 36,
    this.ghost = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: Material(
            color: ghost ? Colors.transparent : c.surfaceHighlight,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              hoverColor: c.primary.withValues(alpha: 0.08),
              focusColor: c.primary.withValues(alpha: 0.2),
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  icon,
                  size: 17,
                  color: ghost ? c.textSecondary : c.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NocturneSegment<T> {
  const NocturneSegment(this.value, this.label, {this.count});

  final T value;
  final String label;
  final String? count;
}

/// `.seg` / `.tab`: a dark well holding raised tabs.
class NocturneSegmented<T> extends StatelessWidget {
  const NocturneSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.height = 34,
    this.padding = 14,
  });

  final List<NocturneSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.inputBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            _SegmentTab<T>(
              segment: segments[i],
              selected: segments[i].value == value,
              onTap: () => onChanged(segments[i].value),
              height: height,
              padding: padding,
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentTab<T> extends StatefulWidget {
  const _SegmentTab({
    required this.segment,
    required this.selected,
    required this.onTap,
    required this.height,
    required this.padding,
  });

  final NocturneSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  final double padding;

  @override
  State<_SegmentTab<T>> createState() => _SegmentTabState<T>();
}

class _SegmentTabState<T> extends State<_SegmentTab<T>> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final on = widget.selected;
    final radius = BorderRadius.circular(11);
    return Semantics(
      selected: on,
      button: true,
      child: AnimatedContainer(
        duration: nocturneMotion(context, 200),
        decoration: BoxDecoration(
          color: on ? c.surfaceHighlight : Colors.transparent,
          borderRadius: radius,
          border: _focus
              ? Border.all(
                  color: c.primary,
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignOutside,
                )
              : null,
          boxShadow: on
              ? const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onHover: (v) => setState(() => _hover = v),
            onFocusChange: (v) => setState(() => _focus = v),
            borderRadius: radius,
            hoverColor: Colors.transparent,
            child: Container(
              height: widget.height,
              padding: EdgeInsets.symmetric(horizontal: widget.padding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.segment.label,
                    style: nocturneText(
                      c,
                      size: 13,
                      weight: FontWeight.w600,
                      color: on || _hover ? c.textPrimary : c.textSecondary,
                    ),
                  ),
                  if (widget.segment.count != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      widget.segment.count!,
                      style: nocturneMono(
                        c,
                        size: 11.5,
                        color: on ? c.primary : c.textDisabled,
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

/// `.track` / `.fill`: a 6px rounded bar.
class NocturneBar extends StatelessWidget {
  const NocturneBar({super.key, required this.value, this.height = 6});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: nocturneTrack(c),
        borderRadius: BorderRadius.circular(height),
      ),
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(height),
          ),
        ),
      ),
    );
  }
}

/// Progress ring (the mockups' SVG circles): track, then an accent arc with
/// round caps from 12 o'clock, [child] centred.
class NocturneRing extends StatelessWidget {
  const NocturneRing({
    super.key,
    required this.value,
    required this.size,
    required this.stroke,
    required this.radius,
    this.child,
  });

  final double value;
  final double size;
  final double stroke;

  /// Radius of the stroke's centre line (the SVG circle's r).
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0.0, 1.0),
          stroke: stroke,
          radius: radius,
          track: nocturneTrack(c),
          color: c.primary,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.radius,
    required this.track,
    required this.color,
  });

  final double value;
  final double stroke;
  final double radius;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = radius;
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, r, paint);
    if (value <= 0) return;
    paint
      ..color = color
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// `.sw`: 42x24 switch, knob slides 18px.
class NocturneSwitch extends StatefulWidget {
  const NocturneSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  State<NocturneSwitch> createState() => _NocturneSwitchState();
}

class _NocturneSwitchState extends State<NocturneSwitch> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final on = widget.value;
    return Semantics(
      toggled: on,
      label: widget.label,
      child: InkWell(
        onTap: () => widget.onChanged(!on),
        onFocusChange: (v) => setState(() => _focus = v),
        borderRadius: BorderRadius.circular(12),
        hoverColor: Colors.transparent,
        child: AnimatedContainer(
          duration: nocturneMotion(context, 200),
          width: 42,
          height: 24,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: on ? c.primary : Color.lerp(c.surface, c.primary, 0.155),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focus
                  ? c.primary
                  : (on
                        ? Colors.transparent
                        : c.primary.withValues(alpha: 0.16)),
              width: _focus ? 2 : 1,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
          ),
          child: AnimatedAlign(
            duration: nocturneMotion(context, 220),
            curve: nocturneEase,
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? c.background : c.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.box`: 20px rounded checkbox.
class NocturneCheck extends StatelessWidget {
  const NocturneCheck({super.key, required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnimatedContainer(
      duration: nocturneMotion(context, 150),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: checked ? c.primary : c.inputBackground,
        borderRadius: BorderRadius.circular(7),
        border: checked ? null : Border.all(color: c.textDisabled, width: 1.5),
      ),
      child: checked
          ? Icon(Icons.check_rounded, size: 14, color: c.background)
          : null,
    );
  }
}

/// Grey eyebrow + 30/700 title of every Nocturne page, [trailing] on the
/// right.
class NocturneHeader extends StatelessWidget {
  const NocturneHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(eyebrow, style: nocturneText(c, size: 13, color: c.textDisabled)),
        const SizedBox(height: 4),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: nocturneDisplay(c),
        ),
      ],
    );
    if (trailing == null) return text;
    return Row(
      children: [
        Expanded(child: text),
        const SizedBox(width: 16),
        trailing!,
      ],
    );
  }
}

/// A card title (15/700).
class NocturneTitle extends StatelessWidget {
  const NocturneTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text(
      text,
      style: nocturneText(
        c,
        size: 15,
        weight: FontWeight.w700,
      ).copyWith(letterSpacing: -0.15),
    );
  }
}

/// Initials tile with the mockups' muted gradients (`.t1`…`.t4`).
class NocturneMonogram extends StatelessWidget {
  const NocturneMonogram({
    super.key,
    required this.text,
    this.size = 34,
    this.radius = 11,
    this.fontSize = 12,
  });

  final String text;
  final double size;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: nocturneTint(text.hashCode),
        border: Border.all(color: c.primary.withValues(alpha: 0.12)),
      ),
      child: Text(
        nocturneInitials(text),
        style: nocturneText(c, size: fontSize, weight: FontWeight.w700),
      ),
    );
  }
}

/// The four muted tints of the mockups, picked by [seed].
LinearGradient nocturneTint(int seed) {
  const tints = [
    [Color(0xFF24304F), Color(0xFF33304A)],
    [Color(0xFF1F3346), Color(0xFF24304F)],
    [Color(0xFF2A2A3E), Color(0xFF1F3346)],
    [Color(0xFF33304A), Color(0xFF2A2A3E)],
  ];
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: tints[seed.abs() % tints.length],
  );
}

String nocturneInitials(String name) {
  final words = name
      .replaceAll(RegExp(r'[@_.\-]'), ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final w = words.first;
    return w.substring(0, math.min(2, w.length)).toUpperCase();
  }
  return (words[0][0] + words[1][0]).toUpperCase();
}

/// The mockups' thin line icons (24-unit SVG paths, 1.7 stroke).
enum NocturneGlyph { add, inbox, download, archive, stats, transfer, settings }

class NocturneIcon extends StatelessWidget {
  const NocturneIcon(
    this.glyph, {
    super.key,
    this.size = 20,
    this.stroke = 1.7,
    required this.color,
  });

  final NocturneGlyph glyph;
  final double size;
  final double stroke;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _GlyphPainter(glyph, stroke, color),
  );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.stroke, this.color);

  final NocturneGlyph glyph;
  final double stroke;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    Path poly(List<double> xy, {bool close = false}) {
      final path = Path()..moveTo(xy[0], xy[1]);
      for (var i = 2; i < xy.length; i += 2) {
        path.lineTo(xy[i], xy[i + 1]);
      }
      if (close) path.close();
      return path;
    }

    void line(List<double> xy) => canvas.drawPath(poly(xy), p);
    switch (glyph) {
      case NocturneGlyph.add:
        line([12, 4, 12, 16]);
        line([6, 11, 12, 17, 18, 11]);
        line([5, 20, 19, 20]);
      case NocturneGlyph.inbox:
        line([4, 13, 8, 13, 10, 16, 14, 16, 16, 13, 20, 13]);
        canvas.drawPath(
          poly([5.5, 5, 18.5, 5, 21, 13, 21, 19, 3, 19, 3, 13], close: true),
          p,
        );
      case NocturneGlyph.download:
        line([12, 4, 12, 14]);
        line([8, 10, 12, 14, 16, 10]);
        line([5, 19, 19, 19]);
      case NocturneGlyph.archive:
        canvas.drawRRect(
          RRect.fromLTRBR(3.5, 4.5, 20.5, 9.5, const Radius.circular(1.5)),
          p,
        );
        line([5.5, 9.5, 5.5, 19, 18.5, 19, 18.5, 9.5]);
      case NocturneGlyph.stats:
        line([5, 19, 5, 11]);
        line([12, 19, 12, 5]);
        line([19, 19, 19, 13]);
      case NocturneGlyph.transfer:
        line([7, 7, 18, 7, 15, 4]);
        line([17, 17, 6, 17, 9, 20]);
      case NocturneGlyph.settings:
        canvas.drawCircle(const Offset(12, 12), 3, p);
        line([12, 3, 12, 5.5]);
        line([12, 18.5, 12, 21]);
        line([3, 12, 5.5, 12]);
        line([18.5, 12, 21, 12]);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.stroke != stroke;
}

/// The empty states' visual: a night orbit. A soft glow, a thin outer orbit
/// with one star, the progress ring waiting with a short arc, [icon] inside.
class NocturneOrbit extends StatelessWidget {
  const NocturneOrbit({
    super.key,
    required this.size,
    required this.icon,
    this.color,
    this.arc = 0.12,
  });

  final double size;
  final IconData icon;

  /// Accent of the arc, star and icon; the theme's primary by default.
  final Color? color;
  final double arc;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final accent = color ?? c.primary;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _OrbitPainter(
          accent: accent,
          track: nocturneTrack(c),
          core: c.surfaceHighlight,
          arc: arc,
        ),
        child: Center(
          child: Icon(icon, size: size * 0.16, color: accent),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({
    required this.accent,
    required this.track,
    required this.core,
    required this.arc,
  });

  final Color accent;
  final Color track;
  final Color core;
  final double arc;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final o = size.center(Offset.zero);
    canvas.drawCircle(
      o,
      s * 0.5,
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withValues(alpha: 0.18), accent.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: o, radius: s * 0.5)),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = track;
    canvas.drawCircle(o, s * 0.46, line);
    final star = o + Offset.fromDirection(-math.pi / 5, s * 0.46);
    canvas.drawCircle(star, s * 0.022, Paint()..color = accent);
    canvas.drawCircle(
      o + Offset.fromDirection(math.pi * 0.8, s * 0.46),
      s * 0.012,
      Paint()..color = accent.withValues(alpha: 0.5),
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.05
      ..color = track;
    canvas.drawCircle(o, s * 0.33, ring);
    if (arc > 0) {
      ring
        ..color = accent
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: o, radius: s * 0.33),
        -math.pi / 2,
        2 * math.pi * arc,
        false,
        ring,
      );
    }
    canvas.drawCircle(o, s * 0.2, Paint()..color = core);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      old.accent != accent ||
      old.track != track ||
      old.core != core ||
      old.arc != arc;
}

/// The empty library's illustration: the Blender loop (`emptyArtAsset`)
/// when it ships, else the [NocturneOrbit] drawn in code.
class NocturneEmptyArt extends StatelessWidget {
  const NocturneEmptyArt({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        emptyArtAsset(context, 'nocturne'),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) =>
            NocturneOrbit(size: size, icon: Icons.nightlight_round),
      ),
    );
  }
}

/// A skeleton block in the ring track's colour.
class NocturneBone extends StatelessWidget {
  const NocturneBone({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: nocturneTrack(AppColors.of(context)),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Sweeps a faint moonlight band across [child]'s bones, driven by the
/// page's single [animation] (still when animations are off).
class NocturneShimmer extends StatelessWidget {
  const NocturneShimmer({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final base = nocturneTrack(c);
    final light = Color.lerp(base, c.primary, 0.12)!;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final t = animation.value * 3 - 1;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: [base, light, base],
            ).createShader(rect),
            child: child,
          );
        },
      ),
    );
  }
}

/// CSS `grid-template-columns: repeat(auto-fill, minmax(min, 1fr))`: as many
/// columns as fit, children left-aligned, rows of equal height.
class NocturneAutoGrid extends StatelessWidget {
  const NocturneAutoGrid({
    super.key,
    required this.minWidth,
    required this.children,
    this.gap = 14,
    this.maxColumns = 12,
  });

  final double minWidth;
  final List<Widget> children;
  final double gap;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = ((box.maxWidth + gap) / (minWidth + gap)).floor().clamp(
          1,
          maxColumns,
        );
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i += cols) ...[
              if (i > 0) SizedBox(height: gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      var j = i;
                      j < i + cols && j < children.length;
                      j++
                    ) ...[
                      if (j > i) SizedBox(width: gap),
                      SizedBox(width: w, child: children[j]),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The settings' pill menu: the current choice in a raised pill, a checked
/// list on tap.
class NocturnePillMenu<T> extends StatelessWidget {
  const NocturnePillMenu({
    super.key,
    required this.value,
    required this.options,
    required this.onSelected,
    required this.tooltip,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onSelected;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return PopupMenuButton<T>(
      tooltip: tooltip,
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final e in options.entries)
          CheckedPopupMenuItem(
            value: e.key,
            checked: e.key == value,
            child: Text(e.value),
          ),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.surfaceHighlight,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                options[value] ?? '$value',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nocturneText(c, size: 13, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: c.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
