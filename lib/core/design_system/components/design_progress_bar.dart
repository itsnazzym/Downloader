import 'package:flutter/material.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/theme/design_spec.dart';

/// Download progress drawn the way the active design draws it: a sheen
/// (Signal, Porcelaine), dots (Pastille), segments (Terminal), a hairline
/// (Studio) or a plain rounded bar. [value] null shows an indeterminate bar.
class DesignProgressBar extends StatelessWidget {
  const DesignProgressBar({
    super.key,
    required this.value,
    this.height,
    this.color,
    this.live = true,
  });

  final double? value;
  final double? height;
  final Color? color;

  /// Whether the download is running: only then does the sheen move.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final spec = DesignSpec.of(context);
    final fill = color ?? colors.primary;
    final track = colors.surfaceHighlight;
    final v = value;
    if (v == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          minHeight: height ?? 3,
          backgroundColor: track,
          valueColor: AlwaysStoppedAnimation<Color>(fill),
        ),
      );
    }
    final progress = v.clamp(0.0, 1.0);
    final style = spec.progress;
    final h =
        height ??
        switch (style) {
          DesignProgress.line => 2.0,
          DesignProgress.dots => 6.0,
          DesignProgress.segments => 8.0,
          _ => 5.0,
        };
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        builder: (context, p, _) {
          switch (style) {
            case DesignProgress.dots:
            case DesignProgress.segments:
              return CustomPaint(
                size: Size.fromHeight(h),
                painter: _UnitsPainter(
                  progress: p,
                  fill: fill,
                  track: track,
                  dots: style == DesignProgress.dots,
                ),
              );
            case DesignProgress.sheen:
              return _SheenBar(
                progress: p,
                height: h,
                fill: fill,
                track: track,
                live: live,
              );
            case DesignProgress.line:
            case DesignProgress.bar:
            case DesignProgress.ring:
              return _PlainBar(
                progress: p,
                height: h,
                fill: fill,
                track: track,
                radius: style == DesignProgress.line ? 0 : h / 2,
              );
          }
        },
      ),
    );
  }
}

class _PlainBar extends StatelessWidget {
  const _PlainBar({
    required this.progress,
    required this.height,
    required this.fill,
    required this.track,
    required this.radius,
  });

  final double progress;
  final double height;
  final Color fill;
  final Color track;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: progress,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}

/// Rounded bar with a highlight that glides across the filled part.
class _SheenBar extends StatefulWidget {
  const _SheenBar({
    required this.progress,
    required this.height,
    required this.fill,
    required this.track,
    required this.live,
  });

  final double progress;
  final double height;
  final Color fill;
  final Color track;
  final bool live;

  @override
  State<_SheenBar> createState() => _SheenBarState();
}

class _SheenBarState extends State<_SheenBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheen;

  @override
  void initState() {
    super.initState();
    _sheen = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_SheenBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final run =
        widget.live &&
        widget.progress > 0 &&
        widget.progress < 1 &&
        !MediaQuery.disableAnimationsOf(context);
    if (run && !_sheen.isAnimating) {
      _sheen.repeat();
    } else if (!run && _sheen.isAnimating) {
      _sheen.stop();
      _sheen.value = 0;
    }
  }

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.height / 2);
    return Container(
      height: widget.height,
      decoration: BoxDecoration(color: widget.track, borderRadius: r),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widget.progress,
        heightFactor: 1,
        child: ClipRRect(
          borderRadius: r,
          child: AnimatedBuilder(
            animation: _sheen,
            builder: (context, _) => CustomPaint(
              painter: _SheenPainter(
                fill: widget.fill,
                t: _sheen.isAnimating ? _sheen.value : -1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheenPainter extends CustomPainter {
  _SheenPainter({required this.fill, required this.t});

  final Color fill;

  /// Sheen position 0..1, or negative for none.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = fill);
    if (t < 0) return;
    final w = size.width * 0.35;
    final x = -w + (size.width + w) * Curves.easeInOutCubic.transform(t);
    final rect = Rect.fromLTWH(x, 0, w, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SheenPainter old) => old.t != t || old.fill != fill;
}

/// A row of dots (Pastille) or square segments (Terminal), filled up to the
/// progress.
class _UnitsPainter extends CustomPainter {
  _UnitsPainter({
    required this.progress,
    required this.fill,
    required this.track,
    required this.dots,
  });

  final double progress;
  final Color fill;
  final Color track;
  final bool dots;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final unit = dots ? h : h * 0.75;
    final gap = dots ? h * 0.6 : 2.0;
    final count = ((size.width + gap) / (unit + gap)).floor().clamp(1, 400);
    final filled = (count * progress).round();
    final on = Paint()..color = fill;
    final off = Paint()..color = track;
    for (var i = 0; i < count; i++) {
      final x = i * (unit + gap);
      final paint = i < filled ? on : off;
      if (dots) {
        canvas.drawCircle(Offset(x + unit / 2, h / 2), unit / 2, paint);
      } else {
        canvas.drawRect(Rect.fromLTWH(x, 0, unit, h), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_UnitsPainter old) =>
      old.progress != progress || old.fill != fill || old.track != track;
}
