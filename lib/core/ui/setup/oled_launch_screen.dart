import 'package:flutter/material.dart';
import 'package:modern_downloader/core/ui/mobile/oled/oled_glyph.dart';
import 'package:modern_downloader/core/ui/mobile/oled/oled_kit.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

/// Phone launch screen: the logo's dot-matrix glyph ignites from the centre,
/// the red dot breathes while the engine warms up, and a segmented bar with a
/// dot-matrix readout tracks the real progress.
class OledLaunchScreen extends StatefulWidget {
  const OledLaunchScreen({
    super.key,
    required this.progress,
    required this.showContinue,
    required this.onContinue,
    this.finishing = false,
  });

  /// 0.0 to 1.0, from the warm-up pipeline.
  final double progress;

  /// Offer "continue anyway" when a warm-up stage failed.
  final bool showContinue;
  final VoidCallback onContinue;

  /// Warm-up is done: the glyph plays its closing "download" beat.
  final bool finishing;

  @override
  State<OledLaunchScreen> createState() => _OledLaunchScreenState();
}

class _OledLaunchScreenState extends State<OledLaunchScreen>
    with TickerProviderStateMixin {
  late final AnimationController _reveal;
  late final AnimationController _pulse;
  late final AnimationController _drop;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _drop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (oledReduceMotion(context)) {
      _reveal.value = 1;
      return;
    }
    _reveal.forward();
    _pulse.repeat();
  }

  @override
  void didUpdateWidget(OledLaunchScreen old) {
    super.didUpdateWidget(old);
    if (widget.finishing && !old.finishing && !oledReduceMotion(context)) {
      _drop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    _pulse.dispose();
    _drop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final percent = (widget.progress.clamp(0.0, 1.0) * 100).round();
    final glyphWidth = (MediaQuery.sizeOf(context).width * 0.46).clamp(
      140.0,
      220.0,
    );

    return OledBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 5),
              OledGlyph(
                width: glyphWidth,
                reveal: _reveal,
                pulse: _pulse,
                drop: _drop.isAnimating || _drop.value > 0
                    ? _drop
                    : const AlwaysStoppedAnimation(-1),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _reveal,
                  curve: const Interval(0.55, 1, curve: Curves.easeOut),
                ),
                child: SlideTransition(
                  position:
                      Tween(
                        begin: const Offset(0, 0.25),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _reveal,
                          curve: const Interval(0.55, 1, curve: Curves.easeOut),
                        ),
                      ),
                  child: Text(
                    l10n.launchWordmark,
                    textAlign: TextAlign.center,
                    style: OledText.title(context, size: 26),
                  ),
                ),
              ),
              const Spacer(flex: 4),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _reveal,
                  curve: const Interval(0.7, 1),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$percent',
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
                    const SizedBox(height: 12),
                    _SegmentBar(value: widget.progress),
                  ],
                ),
              ),
              SizedBox(
                height: 76,
                child: widget.showContinue
                    ? Align(
                        alignment: Alignment.bottomCenter,
                        child: OledButton(
                          label: l10n.launchContinueAnyway,
                          filled: false,
                          height: 46,
                          onPressed: widget.onContinue,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// 24 discrete cells; each lights up as the progress passes it.
class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    const segments = 24;
    final filled = (value.clamp(0.0, 1.0) * segments).floor();
    return SizedBox(
      height: 6,
      child: Row(
        children: [
          for (var i = 0; i < segments; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == segments - 1 ? 0 : 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  decoration: BoxDecoration(
                    color: i < filled ? t.ink : t.fillStrong,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
