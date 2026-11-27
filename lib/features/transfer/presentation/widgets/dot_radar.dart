import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tapload/core/ui/mobile/oled/oled_kit.dart';

/// Radar made of three dotted rings that rotate slowly, with the local device
/// in the centre and up to four nearby devices drawn as small outlined nodes.
/// Decorative only. Stays still when reduced motion is requested.
class DotRadar extends StatefulWidget {
  const DotRadar({super.key, this.size = 260, this.blips = const []});

  final double size;

  /// Icons of the nearby devices (the first four are drawn).
  final List<IconData> blips;

  @override
  State<DotRadar> createState() => _DotRadarState();
}

class _DotRadarState extends State<DotRadar>
    with SingleTickerProviderStateMixin {
  // 1260 s is the least common multiple of the three ring periods (60, 90 and
  // 140 s), so the loop is seamless.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1260),
  );

  bool _still = false;

  static const List<Alignment> _slots = [
    Alignment(-0.57, -0.44),
    Alignment(0.57, 0.37),
    Alignment(0.47, -0.82),
    Alignment(-0.47, 0.82),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = oledReduceMotion(context);
    if (_still) {
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
    final k = widget.size / 300;
    final blipCount = math.min(widget.blips.length, _slots.length);
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _RingsPainter(
                    animation: _c,
                    ink: t.ink,
                    animate: !_still,
                  ),
                ),
              ),
            ),
            for (var i = 0; i < blipCount; i++)
              Align(
                alignment: _slots[i],
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.bg,
                    border: Border.all(color: t.ink, width: 1.5),
                  ),
                  child: Icon(widget.blips[i], size: 17, color: t.ink),
                ),
              ),
            Container(
              width: 60 * k,
              height: 60 * k,
              decoration: BoxDecoration(shape: BoxShape.circle, color: t.ink),
              child: Icon(
                Icons.smartphone_rounded,
                size: 24 * k,
                color: t.onInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring {
  const _Ring({
    required this.radius,
    required this.spacing,
    required this.dot,
    required this.alpha,
    required this.turns,
  });

  /// Radius on a 300 px reference square.
  final double radius;

  /// Distance between two dots along the ring, on the same reference.
  final double spacing;

  /// Dot diameter.
  final double dot;
  final double alpha;

  /// Full turns over the whole animation; the sign is the direction.
  final double turns;
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.animation,
    required this.ink,
    required this.animate,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color ink;
  final bool animate;

  static const List<_Ring> _rings = [
    _Ring(radius: 142, spacing: 9.1, dot: 2.0, alpha: 0.35, turns: 9),
    _Ring(radius: 104, spacing: 8.1, dot: 2.4, alpha: 0.55, turns: -14),
    _Ring(radius: 66, spacing: 7.1, dot: 2.8, alpha: 0.85, turns: 21),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 300;
    final center = size.center(Offset.zero);
    final t = animate ? animation.value : 0.0;
    for (final ring in _rings) {
      final r = ring.radius * k;
      final count = math.max(
        12,
        (2 * math.pi * r / (ring.spacing * k)).round(),
      );
      final paint = Paint()..color = ink.withValues(alpha: ring.alpha);
      final phase = t * ring.turns * 2 * math.pi;
      final dotRadius = ring.dot * k / 2;
      for (var i = 0; i < count; i++) {
        final a = phase + i * 2 * math.pi / count;
        canvas.drawCircle(
          center + Offset(math.cos(a) * r, math.sin(a) * r),
          dotRadius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.ink != ink || old.animate != animate || old.animation != animation;
}
