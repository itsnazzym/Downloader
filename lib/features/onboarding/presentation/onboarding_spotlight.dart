import 'package:flutter/material.dart';

import 'onboarding_tokens.dart';
import 'shadcn_primitives.dart';

class SpotlightPainter extends CustomPainter {
  SpotlightPainter({
    required this.hole,
    required this.radius,
    required this.veil,
  });

  final Rect? hole;
  final double radius;
  final Color veil;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final veilPaint = Paint()..color = veil;
    if (hole == null || hole!.isEmpty) {
      canvas.drawPath(full, veilPaint);
      return;
    }
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(hole!, Radius.circular(radius)));
    final dimmed = Path.combine(PathOperation.difference, full, holePath);
    canvas.drawPath(dimmed, veilPaint);
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter oldDelegate) {
    return oldDelegate.hole != hole ||
        oldDelegate.radius != radius ||
        oldDelegate.veil != veil;
  }

  @override
  bool hitTest(Offset position) => true;
}

class OnboardingSpotlightRim extends StatelessWidget {
  const OnboardingSpotlightRim({super.key, required this.hole});

  final Rect hole;

  @override
  Widget build(BuildContext context) {
    final zinc = ShadcnZinc.of(context);
    const inset = 1.0;
    final width = hole.width - inset * 2;
    final height = hole.height - inset * 2;
    if (width <= 0 || height <= 0) return const SizedBox.shrink();
    return Positioned(
      left: hole.left + inset,
      top: hole.top + inset,
      width: width,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              (OnboardingTokens.holeRadius - inset).clamp(
                0,
                OnboardingTokens.holeRadius,
              ),
            ),
            border: Border.all(
              color: zinc.ring.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}
