import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import '../shared/local_thumb.dart';

/// Pastille's building blocks, measured on the Pastille*.dc.html mockups.

/// Text on pastel tiles is always this dark ink, never white.
const pInk = Color(0xFF1A1714);
const pInkDeep = Color(0xFF0F0E0D);
const pSubInk = Color(0xFF4A433C);
const pCream = Color(0xFFF4EFE6);
const pMuted = Color(0xFFB5ADA3);
const pFaint = Color(0xFF8F877D);
const pBackground = Color(0xFF191715);
const pCard = Color(0xFF24211E);

const Curve pEase = Cubic(0.2, 0.8, 0.2, 1);
const Curve pPop = Cubic(0.2, 0.9, 0.3, 1.15);

Duration pMotion(BuildContext context, int ms) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: ms);

/// The six pastel tones of the design (lavender, sage, rose, sky, butter,
/// cream), from [DesignSpec.tiles].
class PTones {
  PTones._(this._t);

  factory PTones.of(BuildContext context) {
    final t = DesignSpec.of(context).tiles;
    return PTones._(t.length >= 6 ? t : DesignSpec.pastille.tiles);
  }

  final List<Color> _t;
  Color get lav => _t[0];
  Color get sage => _t[1];
  Color get rose => _t[2];
  Color get sky => _t[3];
  Color get butter => _t[4];
  Color get cream => _t[5];
}

bool _isDark(Color c) => c.computeLuminance() < 0.2;

/// A real face of [family] at [weight] (asking the engine for a weight on a
/// regular face only fakes the bold).
TextStyle _face(String family, double size, FontWeight weight) {
  try {
    return GoogleFonts.getFont(family, fontSize: size, fontWeight: weight);
  } catch (_) {
    return TextStyle(fontSize: size, fontWeight: weight);
  }
}

/// Big Sora numbers (`.num`): 800, tight tracking, 0.9 line height.
TextStyle pNum(
  double size, {
  FontWeight weight = FontWeight.w800,
  Color? color,
}) => _face(DesignSpec.pastille.displayFont, size, weight).copyWith(
  letterSpacing: -0.05 * size,
  height: 0.9,
  color: color,
  leadingDistribution: TextLeadingDistribution.even,
);

TextStyle pBody({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double height = 1.45,
}) => _face(DesignSpec.pastille.uiFont, size, weight).copyWith(
  color: color,
  height: height,
  leadingDistribution: TextLeadingDistribution.even,
);

TextStyle pMono({
  double size = 12,
  FontWeight weight = FontWeight.w400,
  Color? color,
}) => _face(DesignSpec.pastille.monoFont, size, weight).copyWith(
  color: color,
  height: 1.45,
  leadingDistribution: TextLeadingDistribution.even,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// `.sub`: 12.5/500 in a softer ink (or warm grey on ink tiles).
TextStyle pSub(BuildContext context, {double size = 12.5}) => pBody(
  size: size,
  weight: FontWeight.w500,
  color: PTileScope.darkOf(context) ? pMuted : pSubInk,
);

/// Tells descendants whether they sit on the ink tile (cream text) or on a
/// pastel one (ink text).
class PTileScope extends InheritedWidget {
  const PTileScope({super.key, required this.dark, required super.child});

  final bool dark;

  static bool darkOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PTileScope>()?.dark ?? true;

  static Color fgOf(BuildContext context) => darkOf(context) ? pCream : pInk;

  @override
  bool updateShouldNotify(PTileScope old) => old.dark != dark;
}

// ── Tile ─────────────────────────────────────────────────────────────────────

/// A solid tile: 30px corners, light top edge, soft drop; pops in, tilts
/// back in 3D on hover and squishes on press.
class PTile extends StatefulWidget {
  const PTile({
    super.key,
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 20, 22, 20),
    this.delay = 0,
    this.onTap,
    this.picked = false,
    this.semanticLabel,
  });

  final Color color;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final int delay;
  final VoidCallback? onTap;

  /// The ring of a selected or current tile.
  final bool picked;
  final String? semanticLabel;

  @override
  State<PTile> createState() => _PTileState();
}

class _PTileState extends State<PTile> with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.delay + 550),
    );
  }

  bool _started = false;
  bool _hover = false;
  bool _down = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pop.value = 1;
    } else {
      _pop.forward();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(widget.color);
    final fg = dark ? pCream : pInk;
    final radius = BorderRadius.circular(30);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final up = _hover && !reduce;
    final shadows = <BoxShadow>[
      if (widget.picked) ...const [
        BoxShadow(color: pCream, spreadRadius: 6),
        BoxShadow(color: pBackground, spreadRadius: 3),
      ],
      if (dark && !widget.picked)
        BoxShadow(color: pCream.withValues(alpha: 0.08), spreadRadius: 1),
      if (!dark)
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: up ? 4 : 2,
          offset: Offset(0, up ? 2 : 1),
        ),
      BoxShadow(
        color: Colors.black.withValues(alpha: up ? 0.8 : 0.7),
        blurRadius: up ? 50 : 36,
        spreadRadius: up ? -20 : -18,
        offset: Offset(0, up ? 30 : 18),
      ),
    ];
    Widget content = Padding(
      padding: widget.padding,
      child: PTileScope(
        dark: dark,
        child: DefaultTextStyle(
          style: pBody(color: fg),
          child: IconTheme(
            data: IconThemeData(color: fg, size: 16),
            child: widget.child,
          ),
        ),
      ),
    );
    if (widget.onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: radius,
          focusColor: fg.withValues(alpha: 0.12),
          hoverColor: Colors.transparent,
          splashColor: fg.withValues(alpha: 0.06),
          highlightColor: Colors.transparent,
          child: content,
        ),
      );
    }
    final box = AnimatedContainer(
      duration: pMotion(context, 350),
      curve: pEase,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: radius,
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            content,
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 1,
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: dark ? 0.08 : 0.35),
                ),
              ),
            ),
            if (!dark)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 2,
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: AnimatedBuilder(
            animation: _pop,
            builder: (context, child) {
              final start = widget.delay / (widget.delay + 550);
              final t = _pop.value <= start
                  ? 0.0
                  : pPop.transform((_pop.value - start) / (1 - start));
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 14 * (1 - t)),
                  child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
                ),
              );
            },
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: up ? 1 : 0),
              duration: pMotion(context, 350),
              curve: pEase,
              builder: (context, h, child) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 1 / 900)
                  ..translateByDouble(0, -4 * h, 0, 1)
                  ..rotateX(-3 * math.pi / 180 * h),
                child: child,
              ),
              child: AnimatedScale(
                scale: _down && !reduce ? 0.985 : 1,
                duration: pMotion(context, 160),
                child: box,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.lab`: a 16px icon and a 13/600 label, with an optional right part.
class PLabel extends StatelessWidget {
  const PLabel({
    super.key,
    required this.icon,
    required this.text,
    this.trailing,
    this.iconColor,
  });

  final IconData icon;
  final String text;
  final Widget? trailing;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final fg = PTileScope.fgOf(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor ?? fg),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: pBody(size: 13, weight: FontWeight.w600, color: fg),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          DefaultTextStyle.merge(
            style: pMono(size: 12, weight: FontWeight.w500, color: fg),
            child: trailing!,
          ),
        ],
      ],
    );
  }
}

// ── Buttons ──────────────────────────────────────────────────────────────────

enum PButtonKind { ink, butter, cream, rose }

/// `.btn`: a pill that lifts 1px on hover and squishes on press.
class PButton extends StatefulWidget {
  const PButton({
    super.key,
    this.label = '',
    this.icon,
    required this.onTap,
    this.kind = PButtonKind.ink,
    this.height = 40,
    this.padH = 18,
    this.fontSize = 13.5,
    this.iconSize = 16,
    this.expand = false,
    this.tooltip,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final PButtonKind kind;
  final double height;
  final double padH;
  final double fontSize;
  final double iconSize;
  final bool expand;
  final String? tooltip;

  @override
  State<PButton> createState() => _PButtonState();
}

class _PButtonState extends State<PButton> {
  bool _hover = false;
  bool _down = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final tones = PTones.of(context);
    final (bg, fg) = switch (widget.kind) {
      PButtonKind.ink => (pInk, pCream),
      PButtonKind.butter => (tones.butter, pInk),
      PButtonKind.cream => (tones.cream, pInk),
      PButtonKind.rose => (tones.rose, pInk),
    };
    final enabled = widget.onTap != null;
    final iconOnly = widget.label.isEmpty;
    final radius = BorderRadius.circular(999);
    final raised =
        widget.kind == PButtonKind.butter || widget.kind == PButtonKind.rose;
    // Focus ring: butter on the dark page, ink on pastel tiles.
    final ring = PTileScope.darkOf(context) ? tones.butter : pInk;
    final dy = !enabled ? 0.0 : (_down ? 1.0 : (_hover ? -1.0 : 0.0));
    Widget body = Container(
      height: widget.height,
      width: iconOnly
          ? widget.height
          : (widget.expand ? double.infinity : null),
      padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : widget.padH),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        boxShadow: widget.kind == PButtonKind.ink
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 14,
                  spreadRadius: -6,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null)
                Icon(widget.icon, size: widget.iconSize, color: fg),
              if (widget.icon != null && !iconOnly) const SizedBox(width: 8),
              if (!iconOnly)
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pBody(
                      size: widget.fontSize,
                      weight: FontWeight.w700,
                      color: fg,
                      height: 1.2,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    if (raised) {
      body = ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            body,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1,
              child: ColoredBox(color: Colors.white.withValues(alpha: 0.5)),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 2,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.12)),
            ),
          ],
        ),
      );
    }
    Widget button = Semantics(
      button: true,
      enabled: enabled,
      label: iconOnly ? widget.tooltip : null,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Listener(
          onPointerDown: (_) => setState(() => _down = true),
          onPointerUp: (_) => setState(() => _down = false),
          onPointerCancel: (_) => setState(() => _down = false),
          child: AnimatedContainer(
            duration: pMotion(context, 160),
            curve: pEase,
            transform: Matrix4.translationValues(0, dy, 0),
            child: AnimatedScale(
              scale: _down && enabled ? 0.97 : 1,
              duration: pMotion(context, 160),
              child: Opacity(
                opacity: enabled ? 1 : 0.45,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: widget.onTap,
                        borderRadius: radius,
                        onFocusChange: (f) => setState(() => _focus = f),
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        splashColor: fg.withValues(alpha: 0.12),
                        highlightColor: Colors.transparent,
                        child: body,
                      ),
                    ),
                    if (_focus)
                      Positioned(
                        left: -6,
                        top: -6,
                        right: -6,
                        bottom: -6,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: radius,
                              border: Border.all(color: ring, width: 3),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}

// ── Dots, calendar, liquid, bars ─────────────────────────────────────────────

/// A grid of round dots: the first [on] are ink and pop in as a cascade, the
/// dot right after blinks while [live]. Used for progress (100 dots).
class PDots extends StatefulWidget {
  const PDots({
    super.key,
    required this.count,
    required this.columns,
    required this.on,
    this.live = false,
    this.paused = false,
    this.step = 12,
    this.gap = 6,
    this.square = false,
    this.levels,
    this.maxWidth,
    this.semanticLabel,
  });

  final int count;
  final int columns;
  final int on;
  final bool live;
  final bool paused;

  /// Milliseconds between two dots of the pop-in cascade.
  final int step;
  final double gap;

  /// Calendar cells (7px corners) instead of round dots.
  final bool square;

  /// Per-cell intensity 0–4 (dot calendar); overrides [on].
  final List<int>? levels;
  final double? maxWidth;
  final String? semanticLabel;

  @override
  State<PDots> createState() => _PDotsState();
}

class _PDotsState extends State<PDots> with TickerProviderStateMixin {
  late final AnimationController _cascade;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _cascade = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.count * widget.step + 400),
    );
  }

  late final AnimationController _blink;
  bool _started = false;

  void _syncBlink() {
    final run =
        widget.live &&
        !widget.paused &&
        !MediaQuery.disableAnimationsOf(context);
    if (run && !_blink.isAnimating) _blink.repeat();
    if (!run && _blink.isAnimating) _blink.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (MediaQuery.disableAnimationsOf(context)) {
        _cascade.value = 1;
      } else {
        _cascade.forward();
      }
    }
    _syncBlink();
  }

  @override
  void didUpdateWidget(PDots old) {
    super.didUpdateWidget(old);
    _syncBlink();
  }

  @override
  void dispose() {
    _cascade.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fg = PTileScope.fgOf(context);
    return Semantics(
      label: widget.semanticLabel,
      image: widget.semanticLabel != null,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = math.min(c.maxWidth, widget.maxWidth ?? double.infinity);
          final cols = widget.columns;
          final cell = (w - widget.gap * (cols - 1)) / cols;
          final rows = (widget.count / cols).ceil();
          return RepaintBoundary(
            child: CustomPaint(
              size: Size(w, rows * cell + (rows - 1) * widget.gap),
              painter: _DotsPainter(
                widget: widget,
                cell: cell,
                ink: fg,
                cascade: _cascade,
                blink: _blink,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({
    required this.widget,
    required this.cell,
    required this.ink,
    required this.cascade,
    required this.blink,
  }) : super(repaint: Listenable.merge([cascade, blink]));

  final PDots widget;
  final double cell;
  final Color ink;
  final Animation<double> cascade;
  final Animation<double> blink;

  static const _alpha = [0.14, 0.22, 0.45, 0.7, 1.0];
  static const Curve _dotCurve = Cubic(0.2, 0.9, 0.3, 1.4);

  @override
  void paint(Canvas canvas, Size size) {
    final total = widget.count * widget.step + 400.0;
    final elapsed = cascade.value * total;
    final paint = Paint();
    final radius = widget.square ? 7.0 : cell / 2;
    for (var i = 0; i < widget.count; i++) {
      final x = (i % widget.columns) * (cell + widget.gap);
      final y = (i ~/ widget.columns) * (cell + widget.gap);
      final level = widget.levels != null
          ? (i < widget.levels!.length ? widget.levels![i].clamp(0, 4) : 0)
          : (i < widget.on ? 4 : 0);
      final isLive = widget.levels == null && widget.live && i == widget.on;
      var scale = 1.0;
      var color = ink.withValues(alpha: _alpha[0]);
      if (level > 0) {
        final t = ((elapsed - i * widget.step) / 400).clamp(0.0, 1.0);
        scale = _dotCurve.transform(t);
        color = ink.withValues(alpha: _alpha[level]);
      } else if (isLive) {
        final o = widget.paused
            ? 0.45
            : 1 - 0.75 * math.sin(blink.value * math.pi);
        color = ink.withValues(alpha: o);
      }
      if (level > 0) {
        // The empty cell stays under a popping dot.
        paint.color = ink.withValues(alpha: _alpha[0]);
        _cell(canvas, paint, x, y, radius, 1);
      }
      paint.color = color;
      _cell(canvas, paint, x, y, radius, scale);
    }
  }

  void _cell(Canvas c, Paint p, double x, double y, double r, double s) {
    if (s <= 0) return;
    final half = cell / 2;
    final rect = Rect.fromCenter(
      center: Offset(x + half, y + half),
      width: cell * s,
      height: cell * s,
    );
    c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r * s)), p);
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.widget != widget || old.cell != cell || old.ink != ink;
}

/// The liquid gauge: an ink fill in a soft tank whose surface sways gently
/// (stopped when effects are reduced).
class PLiquid extends StatefulWidget {
  const PLiquid({super.key, required this.fraction, this.radius = 18});

  final double fraction;
  final double radius;

  @override
  State<PLiquid> createState() => _PLiquidState();
}

class _PLiquidState extends State<PLiquid> with TickerProviderStateMixin {
  late final AnimationController _wave;

  @override
  void initState() {
    super.initState();
    _fill = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
  }

  late final AnimationController _fill;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      reduce ? _fill.value = 1 : _fill.forward();
    }
    if (reduce) {
      _wave.stop();
    } else if (!_wave.isAnimating) {
      _wave.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _LiquidPainter(
          fraction: widget.fraction.clamp(0.0, 1.0),
          radius: widget.radius,
          ink: PTileScope.fgOf(context),
          wave: _wave,
          fill: _fill,
        ),
      ),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  _LiquidPainter({
    required this.fraction,
    required this.radius,
    required this.ink,
    required this.wave,
    required this.fill,
  }) : super(repaint: Listenable.merge([wave, fill]));

  final double fraction;
  final double radius;
  final Color ink;
  final Animation<double> wave;
  final Animation<double> fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.drawRRect(rrect, Paint()..color = ink.withValues(alpha: 0.12));
    final level = size.height * fraction * pEase.transform(fill.value);
    if (level <= 0) return;
    canvas.save();
    canvas.clipRRect(rrect);
    final top = size.height - level;
    final paint = Paint()..color = ink;
    canvas.drawRect(Rect.fromLTRB(0, top, size.width, size.height), paint);
    final w = Curves.easeInOut.transform(wave.value);
    final span = size.width * 1.2;
    final dx = span * (-0.04 + 0.08 * w);
    final sy = 0.8 + 0.4 * w;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2 + dx, top),
        width: span,
        height: 14 * sy,
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LiquidPainter old) =>
      old.fraction != fraction || old.ink != ink;
}

/// Chunky bars growing from the bottom; [hi] is drawn in full ink.
class PBars extends StatelessWidget {
  const PBars({
    super.key,
    required this.values,
    this.hi,
    this.gap = 5,
    this.height = 56,
  });

  /// 0–1 heights.
  final List<double> values;
  final int? hi;
  final double gap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ink = PTileScope.fgOf(context);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.1, end: 1),
                duration: pMotion(context, 700 + i * 15),
                curve: pEase,
                builder: (context, t, child) => FractionallySizedBox(
                  heightFactor: (values[i].clamp(0.04, 1.0)) * t,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: i == hi ? ink : ink.withValues(alpha: 0.22),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                      bottom: Radius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Controls ─────────────────────────────────────────────────────────────────

/// `.sw`: a chunky 58×34 switch with an ink ring.
class PSwitch extends StatelessWidget {
  const PSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    const ink = pInk;
    return Semantics(
      toggled: value,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged!(!value),
          borderRadius: BorderRadius.circular(999),
          focusColor: ink.withValues(alpha: 0.2),
          child: AnimatedContainer(
            duration: pMotion(context, 250),
            width: 58,
            height: 34,
            decoration: BoxDecoration(
              color: value ? ink : ink.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ink, width: 2.5),
            ),
            child: AnimatedAlign(
              duration: pMotion(context, 300),
              curve: const Cubic(0.2, 0.9, 0.3, 1.3),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: AnimatedContainer(
                  duration: pMotion(context, 250),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: value ? pCream : ink,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.ck`: a round check, ink ring empty, ink disc with a cream tick when on.
class PCheck extends StatelessWidget {
  const PCheck({super.key, required this.on, this.size = 30});

  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: pMotion(context, 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: on ? pInk : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: pInk, width: 2.5),
      ),
      child: on
          ? Icon(Icons.check_rounded, size: size * 0.5, color: pCream)
          : null,
    );
  }
}

class PSegItem {
  const PSegItem(this.label, this.selected, this.onTap);

  final String label;
  final bool selected;
  final VoidCallback onTap;
}

/// `.seg`: pill tabs. [page] is the dark capsule used on the background;
/// otherwise the translucent ink track used on a tile.
class PSeg extends StatelessWidget {
  const PSeg({
    super.key,
    required this.items,
    this.page = false,
    this.height = 36,
    this.padH = 16,
    this.fontSize = 13.5,
  });

  final List<PSegItem> items;
  final bool page;
  final double height;
  final double padH;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: page ? pInkDeep : pInk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        boxShadow: page
            ? [BoxShadow(color: pCream.withValues(alpha: 0.1), spreadRadius: 1)]
            : null,
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final item in items)
            _SegButton(
              item: item,
              page: page,
              height: height,
              padH: padH,
              fontSize: fontSize,
            ),
        ],
      ),
    );
  }
}

class _SegButton extends StatefulWidget {
  const _SegButton({
    required this.item,
    required this.page,
    required this.height,
    required this.padH,
    required this.fontSize,
  });

  final PSegItem item;
  final bool page;
  final double height;
  final double padH;
  final double fontSize;

  @override
  State<_SegButton> createState() => _SegButtonState();
}

class _SegButtonState extends State<_SegButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.item.selected;
    final Color bg;
    final Color fg;
    if (widget.page) {
      bg = on
          ? pCream
          : (_hover ? pCream.withValues(alpha: 0.07) : Colors.transparent);
      fg = on ? pInk : (_hover ? pCream : pMuted);
    } else {
      bg = on
          ? pInk
          : (_hover ? pInk.withValues(alpha: 0.1) : Colors.transparent);
      fg = on ? pCream : pInk;
    }
    return Semantics(
      selected: on,
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.item.onTap,
            borderRadius: BorderRadius.circular(999),
            focusColor: (widget.page ? PTones.of(context).butter : pInk)
                .withValues(alpha: 0.35),
            hoverColor: Colors.transparent,
            child: AnimatedContainer(
              duration: pMotion(context, 200),
              height: widget.height,
              padding: EdgeInsets.symmetric(horizontal: widget.padH),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                widget.item.label,
                style: pBody(
                  size: widget.fontSize,
                  weight: FontWeight.w700,
                  color: fg,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Page frame ───────────────────────────────────────────────────────────────

/// The page header: four tone dots, `tapload · where`, a big Sora title and
/// actions on the right.
class PastilleHeader extends StatelessWidget {
  const PastilleHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.actions = const [],
  });

  final String eyebrow;
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tones = PTones.of(context);
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final c in [tones.lav, tones.sage, tones.rose, tones.butter])
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'tapload · $eyebrow',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: pBody(size: 13, weight: FontWeight.w500, color: pMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          // One line: the title shrinks beside wide actions instead of
          // breaking mid-word ("Appearanc / e").
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              maxLines: 1,
              style: pNum(
                44,
                weight: FontWeight.w700,
                color: pCream,
              ).copyWith(letterSpacing: -0.04 * 44),
            ),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (actions.isEmpty) {
          return Align(alignment: Alignment.centerLeft, child: left);
        }
        if (c.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              const SizedBox(height: 14),
              Wrap(spacing: 12, runSpacing: 12, children: actions),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: left),
            const SizedBox(width: 20),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              actions[i],
            ],
          ],
        );
      },
    );
  }
}

/// Room kept under every page so the floating dock never hides content.
const double pDockClearance = 110;

/// A scrolling page: 1200px max, 30/32px padding, [gap] between [children];
/// [slivers] follow with the same side padding (long lists).
class PastillePage extends StatelessWidget {
  const PastillePage({
    super.key,
    required this.children,
    this.gap = 26,
    this.slivers = const [],
  });

  final List<Widget> children;
  final double gap;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: pBackground,
      child: LayoutBuilder(
        builder: (context, c) {
          final side = c.maxWidth > 1264 ? (c.maxWidth - 1200) / 2 : 32.0;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 30, side, 0),
                sliver: SliverList.list(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) SizedBox(height: gap),
                      children[i],
                    ],
                  ],
                ),
              ),
              for (final s in slivers)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  sliver: s,
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 24 + pDockClearance),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One tile of a [PGrid]: [w] columns by [h] rows.
class PCell {
  const PCell(this.child, {this.w = 1, this.h = 1});

  final Widget child;
  final int w;
  final int h;
}

/// The bento grid: 4 columns (2 below 900px), 14px gaps, CSS-like sparse
/// auto-placement. [rowHeights] overrides the height of given rows.
class PGrid extends StatelessWidget {
  const PGrid({
    super.key,
    required this.cells,
    this.rowHeight = 172,
    this.rowHeights = const {},
    this.gap = 14,
  });

  final List<PCell> cells;
  final double rowHeight;
  final Map<int, double> rowHeights;
  final double gap;

  static final bool _placementChecked = _checkPlacement();

  @override
  Widget build(BuildContext context) {
    assert(_placementChecked);
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 560 ? 2 : 1);
        final colW = (c.maxWidth - gap * (cols - 1)) / cols;
        final placed = placeCells([for (final x in cells) (x.w, x.h)], cols);
        final rows = placed.fold<int>(0, (m, p) => math.max(m, p.$1 + p.$4));
        final narrow = cols < 4;
        final maxRow = rowHeights.values.fold<double>(rowHeight, math.max);
        double heightOf(int r) =>
            narrow ? maxRow : (rowHeights[r] ?? rowHeight);
        final tops = <double>[0];
        for (var r = 0; r < rows; r++) {
          tops.add(tops[r] + heightOf(r) + gap);
        }
        return SizedBox(
          height: rows == 0 ? 0 : tops[rows] - gap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < cells.length; i++)
                Positioned(
                  left: placed[i].$2 * (colW + gap),
                  top: tops[placed[i].$1],
                  width: placed[i].$3 * colW + (placed[i].$3 - 1) * gap,
                  height:
                      tops[placed[i].$1 + placed[i].$4] -
                      tops[placed[i].$1] -
                      gap,
                  child: cells[i].child,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The home bento must land where the mockup puts it.
bool _checkPlacement() {
  final home = placeCells([
    (2, 2),
    (2, 1),
    (1, 1),
    (1, 1),
    (2, 1),
    (1, 1),
    (1, 1),
  ], 4);
  return home.toString() ==
      '[(0, 0, 2, 2), (0, 2, 2, 1), (1, 2, 1, 1), (1, 3, 1, 1), '
          '(2, 0, 2, 1), (2, 2, 1, 1), (2, 3, 1, 1)]';
}

/// CSS grid sparse auto-placement: (row, col, width, height) per item, spans
/// clamped to [cols].
List<(int, int, int, int)> placeCells(List<(int, int)> spans, int cols) {
  final taken = <(int, int)>{};
  final out = <(int, int, int, int)>[];
  var r = 0;
  var col = 0;
  bool fits(int r0, int c0, int w, int h) {
    if (c0 + w > cols) return false;
    for (var y = r0; y < r0 + h; y++) {
      for (var x = c0; x < c0 + w; x++) {
        if (taken.contains((y, x))) return false;
      }
    }
    return true;
  }

  for (final (w0, h) in spans) {
    final w = math.min(w0, cols);
    while (!fits(r, col, w, h)) {
      col++;
      if (col + w > cols) {
        col = 0;
        r++;
      }
    }
    for (var y = r; y < r + h; y++) {
      for (var x = col; x < col + w; x++) {
        taken.add((y, x));
      }
    }
    out.add((r, col, w, h));
    col += w;
  }
  return out;
}

/// `.th`: a thumbnail filling its box, a flat [tone] while there is none.
class PThumb extends StatelessWidget {
  const PThumb({
    super.key,
    this.url,
    required this.tone,
    this.radius = 16,
    this.filePath,
  });

  final String? url;

  /// The downloaded file, previewed when [url] is missing or fails.
  final String? filePath;
  final Color tone;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final local = LocalVideoThumb(
      filePath: filePath,
      placeholder: ColoredBox(color: tone),
      cacheWidth: 480,
    );
    Widget image = local;
    final u = url;
    Widget fallback(BuildContext c, Object e, StackTrace? s) => local;
    if (u != null && u.isNotEmpty) {
      if (u.startsWith('http://') || u.startsWith('https://')) {
        image = CachedNetworkImage(
          imageUrl: u,
          fit: BoxFit.cover,
          memCacheWidth: 480,
          placeholder: (c, _) => ColoredBox(color: tone),
          errorWidget: (c, _, _) => local,
        );
      } else if (u.startsWith('assets/')) {
        image = Image.asset(u, fit: BoxFit.cover, errorBuilder: fallback);
      } else {
        image = Image.file(
          File(u),
          fit: BoxFit.cover,
          cacheWidth: 480,
          errorBuilder: fallback,
        );
      }
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius)),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: pInk.withValues(alpha: 0.08)),
      ),
      child: SizedBox.expand(child: image),
    );
  }
}

/// Newest first (highest sortOrder), keeping the list order on ties.
List<DownloadItem> pNewestFirst(Iterable<DownloadItem> items) {
  final indexed = items.toList().asMap().entries.toList()
    ..sort((a, b) {
      final c = b.value.sortOrder.compareTo(a.value.sortOrder);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}

/// Splits "412 Go" into ("412", "Go").
(String, String) pSplitUnit(String text) {
  final i = text.lastIndexOf(' ');
  return i < 0 ? (text, '') : (text.substring(0, i), text.substring(i + 1));
}
