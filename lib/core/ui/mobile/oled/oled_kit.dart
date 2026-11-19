import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

/// Design tokens of the Android OLED interface. Everything derives from the
/// active [AppColors], so other presets still render correctly.
class OledTokens {
  OledTokens._(this.c);

  final AppColors c;

  factory OledTokens.of(BuildContext context) =>
      OledTokens._(AppColors.of(context));

  /// Signal colour, reserved for "live" activity.
  static const Color live = Color(0xFFFF4A3D);

  Color get bg => c.background;
  Color get ink => c.textPrimary;
  Color get ink2 => c.textSecondary;
  Color get ink3 => c.textDisabled;
  Color get warn => c.warning;

  /// Text drawn on top of an [ink]-filled surface.
  Color get onInk => bg;

  Color get fill => ink.withValues(alpha: 0.045);
  Color get fillStrong => ink.withValues(alpha: 0.09);
  Color get line => ink.withValues(alpha: 0.12);
  Color get lineStrong => ink.withValues(alpha: 0.22);
}

/// Typography: Instrument Sans for the UI, Doto (dot-matrix) for big numbers.
class OledText {
  const OledText._();

  static TextStyle _family(String family) {
    try {
      return GoogleFonts.getFont(family);
    } catch (_) {
      return GoogleFonts.inter();
    }
  }

  static TextStyle ui(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return _family('Instrument Sans').copyWith(
      fontSize: size,
      fontWeight: weight,
      color: color ?? OledTokens.of(context).ink,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle title(BuildContext context, {double size = 30}) => ui(
    context,
    size: size,
    weight: FontWeight.w600,
    letterSpacing: -size * 0.03,
    height: 1.1,
  );

  /// Dot-matrix numerals. Use for one hero figure per screen.
  static TextStyle dot(
    BuildContext context, {
    double size = 56,
    Color? color,
    FontWeight weight = FontWeight.w700,
  }) {
    return _family('Doto').copyWith(
      fontSize: size,
      fontWeight: weight,
      color: color ?? OledTokens.of(context).ink,
      height: 1.0,
      letterSpacing: -size * 0.02,
    );
  }

  static TextStyle log(BuildContext context, {Color? color}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: 11.5,
      height: 1.6,
      color: color ?? OledTokens.of(context).ink2,
    );
  }
}

bool oledReduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Pure black ground with a faint dot grid. Place it behind the content.
class OledBackground extends StatelessWidget {
  const OledBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    return ColoredBox(
      color: t.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _DotGridPainter(t.ink.withValues(alpha: 0.075)),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const pitch = 10.0;
    final points = <Offset>[];
    for (double y = pitch / 2; y < size.height; y += pitch) {
      for (double x = pitch / 2; x < size.width; x += pitch) {
        points.add(Offset(x, y));
      }
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}

/// Flat translucent panel with a hairline border.
class OledCard extends StatelessWidget {
  const OledCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.onTap,
    this.outlined = true,
    this.highlight = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final bool outlined;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: outlined
          ? BorderSide(
              color: highlight ? t.ink : t.line,
              width: highlight ? 1.5 : 1,
            )
          : BorderSide.none,
    );
    return Material(
      color: t.fill,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Filter chip. Selected = filled with ink, otherwise hairline outline.
class OledChip extends StatelessWidget {
  const OledChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.countColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final Color? countColor;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final fg = selected ? t.onInk : t.ink2;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? t.ink : Colors.transparent,
        shape: StadiumBorder(
          side: selected ? BorderSide.none : BorderSide(color: t.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: OledText.ui(
                      context,
                      size: 13,
                      weight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: fg,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '$count',
                      style: OledText.ui(
                        context,
                        size: 13,
                        color: selected
                            ? t.onInk.withValues(alpha: 0.6)
                            : (countColor ?? t.ink3),
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

/// Pill button. [filled] = ink background, otherwise hairline outline.
class OledButton extends StatelessWidget {
  const OledButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.icon,
    this.height = 52,
    this.expand = true,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final IconData? icon;
  final double height;
  final bool expand;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final enabled = onPressed != null;
    final fg = !enabled
        ? t.ink3
        : filled
        ? t.onInk
        : (danger ? t.warn : t.ink);
    final button = Material(
      color: filled && enabled ? t.ink : Colors.transparent,
      shape: StadiumBorder(
        side: filled && enabled
            ? BorderSide.none
            : BorderSide(color: t.lineStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onPressed!();
              }
            : null,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OledText.ui(
                      context,
                      size: 15,
                      weight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// 44px circular outline icon button.
class OledIconButton extends StatelessWidget {
  const OledIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.outlined = true,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool outlined;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(
          side: outlined ? BorderSide(color: t.line) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 20, color: color ?? t.ink),
          ),
        ),
      ),
    );
  }
}

/// Two- or three-way segmented control with a hairline frame.
class OledSegmented<T> extends StatelessWidget {
  const OledSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: Semantics(
                button: true,
                selected: entry.key == value,
                child: Material(
                  color: entry.key == value ? t.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(entry.key);
                    },
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: Text(
                          entry.value,
                          style: OledText.ui(
                            context,
                            size: 14,
                            weight: FontWeight.w600,
                            color: entry.key == value ? t.onInk : t.ink2,
                          ),
                        ),
                      ),
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

/// Custom switch: outlined track, ink knob when on.
class OledToggle extends StatelessWidget {
  const OledToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: SizedBox(
          width: 52,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 52,
              height: 32,
              padding: const EdgeInsets.all(4),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: value ? t.ink : Colors.transparent,
                border: Border.all(color: value ? t.ink : t.lineStrong),
              ),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? t.onInk : t.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// − value + stepper with a dot-matrix readout.
class OledStepper extends StatelessWidget {
  const OledStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OledIconButton(
          icon: Icons.remove_rounded,
          tooltip: context.l10n.oledKitStepperLess,
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 40,
          child: Center(
            child: Text('$value', style: OledText.dot(context, size: 30)),
          ),
        ),
        OledIconButton(
          icon: Icons.add_rounded,
          tooltip: context.l10n.oledKitStepperMore,
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

/// Pulsing red dot for "live" states.
class OledLiveDot extends StatefulWidget {
  const OledLiveDot({super.key, this.size = 8});

  final double size;

  @override
  State<OledLiveDot> createState() => _OledLiveDotState();
}

class _OledLiveDotState extends State<OledLiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (oledReduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return CustomPaint(
            painter: _LiveDotPainter(_c.value, oledReduceMotion(context)),
          );
        },
      ),
    );
  }
}

class _LiveDotPainter extends CustomPainter {
  _LiveDotPainter(this.t, this.still);

  final double t;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    if (!still) {
      final halo = Paint()
        ..color = OledTokens.live.withValues(alpha: 0.5 * (1 - t));
      canvas.drawCircle(c, r + r * 1.2 * t, halo);
    }
    canvas.drawCircle(c, r, Paint()..color = OledTokens.live);
  }

  @override
  bool shouldRepaint(_LiveDotPainter old) => old.t != t || old.still != still;
}

/// Line chart with a flat area fill that draws itself in once.
class OledSparkline extends StatelessWidget {
  const OledSparkline({
    super.key,
    required this.values,
    this.width = 150,
    this.height = 56,
  });

  final List<double> values;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final still = oledReduceMotion(context);
    return SizedBox(
      width: width,
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: still ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 1600),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) {
          return CustomPaint(
            painter: _SparklinePainter(
              values: values,
              progress: progress,
              ink: t.ink,
            ),
          );
        },
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.progress,
    required this.ink,
  });

  final List<double> values;
  final double progress;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final span = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);
    Offset pt(int i) => Offset(
      i * dx,
      size.height - 4 - ((values[i] - minV) / span) * (size.height - 12),
    );
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(pt(i).dx, pt(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()..color = ink.withValues(alpha: 0.06 * progress),
    );
    final metrics = line.computeMetrics().toList();
    if (metrics.isNotEmpty) {
      final metric = metrics.first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    if (progress >= 1) {
      canvas.drawCircle(
        pt(values.length - 1),
        3,
        Paint()..color = OledTokens.live,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.progress != progress || old.values != values || old.ink != ink;
}

/// Grid of fragments: done = ink, active = blinking red, pending = faint.
class OledFragmentMap extends StatefulWidget {
  const OledFragmentMap({
    super.key,
    required this.progress,
    this.cells = 72,
    this.columns = 24,
    this.active = 4,
    this.waiting = false,
  });

  /// While nothing has been received yet the active cells sweep across the
  /// grid instead of sitting at the start, so the wait does not look frozen.
  final bool waiting;

  /// 0.0 to 1.0
  final double progress;
  final int cells;
  final int columns;
  final int active;

  @override
  State<OledFragmentMap> createState() => _OledFragmentMapState();
}

class _OledFragmentMapState extends State<OledFragmentMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (oledReduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final rows = (widget.cells / widget.columns).ceil();
    final done = (widget.progress.clamp(0.0, 1.0) * widget.cells).floor();
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 3.0;
        final cell =
            (box.maxWidth - gap * (widget.columns - 1)) / widget.columns;
        final height = rows * cell + (rows - 1) * gap;
        return Semantics(
          label: context.l10n.oledKitFragmentsReceived(done, widget.cells),
          child: SizedBox(
            width: box.maxWidth,
            height: height,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                return CustomPaint(
                  painter: _FragmentPainter(
                    cells: widget.cells,
                    columns: widget.columns,
                    done: done,
                    active: widget.active,
                    waiting: widget.waiting,
                    phase: _c.value,
                    still: oledReduceMotion(context),
                    ink: t.ink,
                    cell: cell,
                    gap: gap,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _FragmentPainter extends CustomPainter {
  _FragmentPainter({
    required this.cells,
    required this.columns,
    required this.done,
    required this.active,
    required this.waiting,
    required this.phase,
    required this.still,
    required this.ink,
    required this.cell,
    required this.gap,
  });

  final int cells;
  final int columns;
  final int done;
  final int active;
  final bool waiting;
  final double phase;
  final bool still;
  final Color ink;
  final double cell;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < cells; i++) {
      final col = i % columns;
      final row = i ~/ columns;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(col * (cell + gap), row * (cell + gap), cell, cell),
        const Radius.circular(2),
      );
      Color color;
      if (waiting && !still) {
        // A small group of cells travelling over the grid, wrapping around.
        final start = (phase * cells).floor();
        final offset = (i - start + cells) % cells;
        color = offset < active
            ? OledTokens.live.withValues(alpha: 1 - offset / active * 0.7)
            : ink.withValues(alpha: 0.11);
      } else if (i < done) {
        color = ink.withValues(alpha: 0.95);
      } else if (i < done + active) {
        final k = i - done;
        final wave = still
            ? 1.0
            : 0.3 +
                  0.7 *
                      (0.5 + 0.5 * math.sin((phase - k * 0.15) * 2 * math.pi));
        color = OledTokens.live.withValues(alpha: wave);
      } else {
        color = ink.withValues(alpha: 0.11);
      }
      canvas.drawRRect(rect, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_FragmentPainter old) =>
      old.phase != phase ||
      old.done != done ||
      old.cell != cell ||
      old.ink != ink ||
      old.active != active ||
      old.waiting != waiting ||
      old.still != still ||
      old.columns != columns;
}

/// Honest thumbnail: the network image when available, otherwise a hatched
/// placeholder.
class OledThumb extends StatelessWidget {
  const OledThumb({
    super.key,
    this.url,
    this.width = 72,
    this.height = 42,
    this.radius = 8,
    this.badge,
    this.warn = false,
  });

  final String? url;
  final double width;
  final double height;
  final double radius;
  final String? badge;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final hasUrl = url != null && url!.isNotEmpty;
    final borderColor = warn ? t.warn.withValues(alpha: 0.5) : t.line;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 0.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasUrl)
                CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  memCacheWidth: (width * 3).round(),
                  placeholder: (context, _) =>
                      _Hatch(color: t.ink, warn: warn ? t.warn : null),
                  errorWidget: (context, url, error) =>
                      _Hatch(color: t.ink, warn: warn ? t.warn : null),
                )
              else
                _Hatch(color: t.ink, warn: warn ? t.warn : null),
              if (badge != null)
                Positioned(
                  right: 3,
                  bottom: 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.bg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      child: Text(
                        badge!,
                        style: OledText.ui(
                          context,
                          size: 11,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hatch extends StatelessWidget {
  const _Hatch({required this.color, this.warn});

  final Color color;
  final Color? warn;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HatchPainter(
        (warn ?? color).withValues(alpha: warn == null ? 0.09 : 0.22),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  _HatchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 6.0;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.color != color;
}

/// Small section heading, sentence case.
class OledSectionTitle extends StatelessWidget {
  const OledSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: OledText.ui(
                context,
                size: 15,
                weight: FontWeight.w600,
                color: t.ink,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
