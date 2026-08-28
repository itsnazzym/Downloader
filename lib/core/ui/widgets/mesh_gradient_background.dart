import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';

/// Ambient mesh used by the iOS chrome. Orbs follow the active primary.
class MeshGradientBackground extends StatefulWidget {
  final Widget? child;
  const MeshGradientBackground({super.key, this.child});

  @override
  State<MeshGradientBackground> createState() => MeshGradientBackgroundState();
}

class MeshGradientBackgroundState extends State<MeshGradientBackground>
    with TickerProviderStateMixin {
  /// Pointer-idle delay before orbs freeze in place (tickers stop).
  @visibleForTesting
  static const Duration idleTimeout = Duration(seconds: 3);

  late final AnimationController _controller1;
  late final AnimationController _controller2;
  late final AnimationController _controller3;

  Timer? _idleTimer;
  bool _reduceMotion = false;
  bool _frozen = false;
  bool _motionInitialized = false;

  @visibleForTesting
  bool get isAnimating =>
      _controller1.isAnimating ||
      _controller2.isAnimating ||
      _controller3.isAnimating;

  @override
  void initState() {
    super.initState();
    _controller1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _controller2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    _controller3 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (_motionInitialized && reduce == _reduceMotion) return;
    _motionInitialized = true;
    _reduceMotion = reduce;
    if (reduce) {
      _frozen = false;
      _cancelIdleTimer();
      _stopRepeating();
    } else {
      _startRepeating();
      _armIdleTimer();
    }
  }

  @override
  void dispose() {
    _cancelIdleTimer();
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  void _onPointerActivity() {
    if (_reduceMotion || !mounted) return;
    if (_frozen) {
      _frozen = false;
      _startRepeating();
    }
    _armIdleTimer();
  }

  void _armIdleTimer() {
    _cancelIdleTimer();
    if (_reduceMotion) return;
    try {
      _idleTimer = Timer(idleTimeout, _freezeForIdle);
    } catch (e) {
      debugPrint('MeshGradientBackground: idle timer failed: $e');
    }
  }

  void _freezeForIdle() {
    if (!mounted || _reduceMotion) return;
    _frozen = true;
    _stopRepeating();
  }

  void _startRepeating() {
    if (_reduceMotion || _frozen) return;
    try {
      if (!_controller1.isAnimating) {
        _controller1.repeat(reverse: true);
      }
      if (!_controller2.isAnimating) {
        _controller2.repeat(reverse: true);
      }
      if (!_controller3.isAnimating) {
        _controller3.repeat(reverse: true);
      }
    } catch (e) {
      debugPrint('MeshGradientBackground: failed to start: $e');
    }
  }

  void _stopRepeating() {
    try {
      _controller1.stop();
      _controller2.stop();
      _controller3.stop();
    } catch (e) {
      debugPrint('MeshGradientBackground: failed to stop: $e');
    }
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    if (reduce) {
      return Container(color: colors.background, child: widget.child);
    }

    return MouseRegion(
      onEnter: (_) => _onPointerActivity(),
      onHover: (_) => _onPointerActivity(),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _onPointerActivity(),
        child: Container(
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
                        -150 +
                        (80 * math.sin(_controller2.value * math.pi * 1.5)),
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
                    top:
                        200 +
                        (100 * math.sin(_controller3.value * math.pi * 0.8)),
                    right:
                        -200 +
                        (50 * math.cos(_controller3.value * math.pi * 1.2)),
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
        ),
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
