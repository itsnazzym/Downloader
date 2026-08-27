import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';

/// Ambient mesh used by the iOS chrome. Orbs follow the active primary.
class MeshGradientBackground extends StatefulWidget {
  final Widget? child;
  const MeshGradientBackground({super.key, this.child});

  @override
  State<MeshGradientBackground> createState() => _MeshGradientBackgroundState();
}

class _MeshGradientBackgroundState extends State<MeshGradientBackground>
    with TickerProviderStateMixin {
  late final AnimationController _controller1;
  late final AnimationController _controller2;
  late final AnimationController _controller3;

  @override
  void initState() {
    super.initState();
    _controller1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _controller2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);

    _controller3 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reduce = MediaQuery.of(context).disableAnimations;

    if (reduce) {
      return Container(color: colors.background, child: widget.child);
    }

    return Container(
      color: colors.background,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller1,
            builder: (context, child) {
              return Positioned(
                top: -100 + (50 * math.sin(_controller1.value * math.pi)),
                right: -50 + (30 * math.cos(_controller1.value * math.pi)),
                child: _Orb(
                  size: 400,
                  color: colors.primary.withValues(alpha: 0.22),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _controller2,
            builder: (context, child) {
              return Positioned(
                bottom:
                    -150 + (80 * math.sin(_controller2.value * math.pi * 1.5)),
                left: -100 + (60 * math.cos(_controller2.value * math.pi)),
                child: _Orb(
                  size: 480,
                  color: colors.info.withValues(alpha: 0.16),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _controller3,
            builder: (context, child) {
              return Positioned(
                top: 200 + (100 * math.sin(_controller3.value * math.pi * 0.8)),
                right:
                    -200 + (50 * math.cos(_controller3.value * math.pi * 1.2)),
                child: _Orb(
                  size: 320,
                  color: colors.primary.withValues(alpha: 0.10),
                ),
              );
            },
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;

  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0.0)]),
      ),
    );
  }
}
