import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:modern_downloader/core/ui/mobile/back_navigation.dart';
import 'package:modern_downloader/core/ui/mobile/oled/oled_glyph.dart';
import 'package:modern_downloader/core/ui/mobile/oled/oled_kit.dart';
import 'package:modern_downloader/features/onboarding/data/onboarding_store.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_controller.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

/// Whether the phone introduction is on screen. It runs once on a fresh
/// install and can be replayed from the settings.
class MobileOnboardingController extends StateNotifier<bool> {
  MobileOnboardingController(this._store)
    : super(PlatformInfo.isMobile && !_store.completed);

  final OnboardingPersistence _store;

  void replay() => state = true;

  Future<void> finish() async {
    await _store.setCompleted(true);
    state = false;
  }
}

final mobileOnboardingProvider =
    StateNotifierProvider<MobileOnboardingController, bool>(
      (ref) => MobileOnboardingController(ref.watch(onboardingStoreProvider)),
    );

/// Mounts the introduction above the app once the launch screen is gone.
class MobileOnboardingGate extends ConsumerWidget {
  const MobileOnboardingGate({super.key, required this.ready});

  /// The launch screen has finished.
  final bool ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(mobileOnboardingProvider);
    if (!show || !ready) return const SizedBox.shrink();
    return MobileOnboarding(
      onFinish: () => ref.read(mobileOnboardingProvider.notifier).finish(),
    );
  }
}

const _pageCount = 4;

class MobileOnboarding extends ConsumerStatefulWidget {
  const MobileOnboarding({super.key, required this.onFinish});

  final Future<void> Function() onFinish;

  @override
  ConsumerState<MobileOnboarding> createState() => _MobileOnboardingState();
}

class _MobileOnboardingState extends ConsumerState<MobileOnboarding>
    with TickerProviderStateMixin {
  final _pages = PageController();
  late final AnimationController _loop;
  late final AnimationController _enter;
  VoidCallback? _unregisterBack;
  int _index = 0;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    // Back steps through the pages; it never drops into the app half-way.
    _unregisterBack = ref.read(backInterceptorsProvider).register(() {
      if (_index > 0) {
        unawaited(_go(_index - 1));
      }
      return true;
    });
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (oledReduceMotion(context)) {
      _enter.value = 1;
      _loop.value = 0.85;
    } else {
      _enter.forward();
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _unregisterBack?.call();
    _pages.dispose();
    _loop.dispose();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _go(int page) => _pages.animateToPage(
    page.clamp(0, _pageCount - 1),
    duration: const Duration(milliseconds: 420),
    curve: Curves.easeOutCubic,
  );

  Future<void> _finish() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (mounted) await widget.onFinish();
  }

  void _next() {
    if (_index >= _pageCount - 1) {
      unawaited(_finish());
    } else {
      unawaited(_go(_index + 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final last = _index == _pageCount - 1;
    final copy = [
      (l10n.onbPage1Title, l10n.onbPage1Body),
      (l10n.onbPage2Title, l10n.onbPage2Body),
      (l10n.onbPage3Title, l10n.onbPage3Body),
      (l10n.onbPage4Title, l10n.onbPage4Body),
    ];

    return AnimatedOpacity(
      opacity: _leaving ? 0 : 1,
      duration: const Duration(milliseconds: 300),
      child: Material(
        color: t.bg,
        child: OledBackground(
          child: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 56,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: AnimatedOpacity(
                      opacity: last ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: TextButton(
                        onPressed: last ? null : _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: t.ink2,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        child: Text(
                          l10n.onbSkip,
                          style: OledText.ui(
                            context,
                            size: 15,
                            weight: FontWeight.w600,
                            color: t.ink2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _pageCount,
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _index = i);
                    },
                    itemBuilder: (context, i) {
                      return AnimatedBuilder(
                        animation: _pages,
                        builder: (context, _) {
                          final page = _pages.hasClients
                              ? (_pages.page ?? _index.toDouble())
                              : _index.toDouble();
                          return _OnboardingPage(
                            index: i,
                            offset: i - page,
                            loop: _loop,
                            enter: _enter,
                            title: copy[i].$1,
                            body: copy[i].$2,
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    children: [
                      _PageDots(index: _index),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: OledButton(
                          key: ValueKey(last),
                          label: last ? l10n.onbStart : l10n.onbNext,
                          onPressed: _next,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.index,
    required this.offset,
    required this.loop,
    required this.enter,
    required this.title,
    required this.body,
  });

  final int index;

  /// Position relative to the visible page: 0 = centred, -1 = left, 1 = right.
  final double offset;
  final Animation<double> loop;
  final Animation<double> enter;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final focus = (1 - offset.abs()).clamp(0.0, 1.0);
    final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    final width = MediaQuery.sizeOf(context).width;

    return LayoutBuilder(
      builder: (context, box) {
        final visualHeight = math.min(box.maxHeight * 0.52, 340.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              // The visual drifts faster than the text for a little depth.
              Transform.translate(
                offset: Offset(offset * width * 0.35 * dir, 0),
                child: Opacity(
                  opacity: focus,
                  child: SizedBox(
                    height: visualHeight,
                    width: double.infinity,
                    child: Center(
                      child: _Visual(
                        index: index,
                        loop: loop,
                        enter: enter,
                        height: visualHeight,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Transform.translate(
                offset: Offset(offset * 40 * dir, 0),
                child: Opacity(
                  opacity: focus,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: OledText.title(context, size: 32)),
                      const SizedBox(height: 10),
                      Text(
                        body,
                        style: OledText.ui(
                          context,
                          size: 16,
                          weight: FontWeight.w400,
                          color: t.ink2,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        );
      },
    );
  }
}

class _Visual extends StatelessWidget {
  const _Visual({
    required this.index,
    required this.loop,
    required this.enter,
    required this.height,
  });

  final int index;
  final Animation<double> loop;
  final Animation<double> enter;
  final double height;

  @override
  Widget build(BuildContext context) {
    switch (index) {
      case 0:
        // A file drops from the arrow into the tray, again and again.
        final drop = CurvedAnimation(
          parent: loop,
          curve: const Interval(0.05, 0.7, curve: Curves.easeInOut),
        );
        return OledGlyph(
          width: math.min(height * 0.62, 200),
          reveal: enter,
          pulse: loop,
          drop: _ClampedFrom(drop, 0.0),
        );
      case 1:
        return _ScanField(loop: loop, enter: enter);
      case 2:
        return _LibraryStack(loop: loop);
      default:
        return OledGlyph(
          width: math.min(height * 0.62, 200),
          reveal: enter,
          pulse: loop,
        );
    }
  }
}

/// Animation view that never goes below [floor]: the glyph treats negative
/// values as "no drop", so a looping 0..1 value is passed straight through.
class _ClampedFrom extends Animation<double>
    with AnimationWithParentMixin<double> {
  _ClampedFrom(this.parent, this.floor);

  @override
  final Animation<double> parent;
  final double floor;

  @override
  double get value => math.max(floor, parent.value);
}

/// Dot field with a scan band; the readout counts the media it "finds".
class _ScanField extends StatelessWidget {
  const _ScanField({required this.loop, required this.enter});

  final Animation<double> loop;
  final Animation<double> enter;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: _ScanPainter(
                loop: loop,
                enter: enter,
                ink: t.ink,
                unlit: t.ink.withValues(alpha: 0.09),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: loop,
            builder: (context, _) {
              final found = (((loop.value - 0.2) / 0.6).clamp(0.0, 1.0) * 3)
                  .ceil()
                  .clamp(0, 3);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: t.bg,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: t.lineStrong),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const OledLiveDot(size: 9),
                    const SizedBox(width: 10),
                    Text('$found', style: OledText.dot(context, size: 34)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ScanPainter extends CustomPainter {
  _ScanPainter({
    required this.loop,
    required this.enter,
    required this.ink,
    required this.unlit,
  }) : super(repaint: Listenable.merge([loop, enter]));

  final Animation<double> loop;
  final Animation<double> enter;
  final Color ink;
  final Color unlit;

  // Rows that hold a "media": the band lights them as it passes.
  static const _hits = {2, 6, 10};

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 14;
    const rows = 14;
    final pitch = math.min(size.width / cols, size.height / rows);
    final left = (size.width - pitch * cols) / 2;
    final top = (size.height - pitch * rows) / 2;
    final radius = pitch * 0.3;
    final band = (loop.value * 1.25 - 0.1) * rows;
    final paint = Paint()..isAntiAlias = true;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final centre = Offset(
          left + (c + 0.5) * pitch,
          top + (r + 0.5) * pitch,
        );
        final fromCentre = math.sqrt(
          math.pow(c - (cols - 1) / 2, 2) + math.pow(r - (rows - 1) / 2, 2),
        );
        final appear = ((enter.value * 1.6) - fromCentre / 10).clamp(0.0, 1.0);
        final near = (1 - (band - r).abs() / 1.6).clamp(0.0, 1.0);
        final passed = band > r;
        final hit = _hits.contains(r) && c >= 2 && c <= 11 && passed;
        var color = unlit;
        if (hit) color = ink.withValues(alpha: 0.85);
        if (near > 0) color = Color.lerp(color, ink, near * 0.9)!;
        paint.color = color;
        canvas.drawCircle(centre, radius * appear, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.ink != ink || old.unlit != unlit;
}

/// Three cards slide in, then a segmented bar fills: "your library, offline".
class _LibraryStack extends StatelessWidget {
  const _LibraryStack({required this.loop});

  final Animation<double> loop;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        final v = loop.value;
        double seg(double a, double b) => ((v - a) / (b - a)).clamp(0.0, 1.0);
        final fade = 1 - seg(0.92, 1.0);
        final fill = Curves.easeInOut.transform(seg(0.45, 0.85));
        return Opacity(
          opacity: fade,
          child: SizedBox(
            width: 260,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < 3; i++)
                  Builder(
                    builder: (context) {
                      final p = Curves.easeOutCubic.transform(
                        seg(0.02 + i * 0.09, 0.3 + i * 0.09),
                      );
                      return Opacity(
                        opacity: p,
                        child: Transform.translate(
                          offset: Offset(0, (1 - p) * 24),
                          child: Container(
                            height: 52,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: t.fill,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: t.line),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: t.fillStrong,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 6,
                                        width: 90.0 + i * 24,
                                        decoration: BoxDecoration(
                                          color: t.ink.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        height: 5,
                                        width: 56,
                                        decoration: BoxDecoration(
                                          color: t.fillStrong,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(fill * 100).round()}',
                      style: OledText.dot(context, size: 40),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '%',
                        style: OledText.ui(
                          context,
                          size: 16,
                          weight: FontWeight.w700,
                          color: t.ink3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 6,
                  child: Row(
                    children: [
                      for (var i = 0; i < 20; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: i == 19 ? 0 : 3),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: i < (fill * 20).floor()
                                    ? t.ink
                                    : t.fillStrong,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Dot pager: the current page stretches into a pill.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    return Semantics(
      label: context.l10n.onbPageLabel(index + 1, _pageCount),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _pageCount; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == index ? 28 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == index ? t.ink : t.fillStrong,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
