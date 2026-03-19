import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:modern_downloader/theme/palette.dart';

/// A beautiful animated background with floating color orbs
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
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _controller2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _controller3 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
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
    return Container(
      color: Palette.backgroundDeep,
      child: Stack(
        children: [
          // Orb 1 - Blue/Cyan (top-right)
          AnimatedBuilder(
            animation: _controller1,
            builder: (context, child) {
              return Positioned(
                top: -100 + (50 * math.sin(_controller1.value * math.pi)),
                right: -50 + (30 * math.cos(_controller1.value * math.pi)),
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Palette.neonBlue.withValues(alpha: 0.3),
                        Palette.neonCyan.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          // Orb 2 - Purple/Pink (bottom-left)
          AnimatedBuilder(
            animation: _controller2,
            builder: (context, child) {
              return Positioned(
                bottom:
                    -150 + (80 * math.sin(_controller2.value * math.pi * 1.5)),
                left: -100 + (60 * math.cos(_controller2.value * math.pi)),
                child: Container(
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Palette.neonPurple.withValues(alpha: 0.25),
                        Palette.neonPink.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          // Orb 3 - Cyan (center-right)
          AnimatedBuilder(
            animation: _controller3,
            builder: (context, child) {
              return Positioned(
                top: 200 + (100 * math.sin(_controller3.value * math.pi * 0.8)),
                right:
                    -200 + (50 * math.cos(_controller3.value * math.pi * 1.2)),
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Palette.neonCyan.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                      stops: [0.0, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          // Noise/grain overlay for texture
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Palette.backgroundDeep.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ),

          // Content
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}
