import 'package:flutter/material.dart';
import '../shared/empty_art.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';

import 'signal_widgets.dart';

/// Signal's situations: empty, no results, loading and error, drawn as bento
/// cards.

/// The empty-state picture: a small bento of placeholder tiles, one of them
/// the accent tile with the download arrow. Shows
/// the Blender loop (`emptyArtAsset`) instead when it loads.
class SignalEmptyArt extends StatelessWidget {
  const SignalEmptyArt({super.key, this.width = 260, this.height = 176});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Image.asset(
      emptyArtAsset(context, 'signal'),
      fit: BoxFit.contain,
      errorBuilder: (context, _, _) => const _BentoArt(),
    ),
  );
}

class _BentoArt extends StatelessWidget {
  const _BentoArt();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Widget tile({required Widget child, bool accent = false}) => Container(
      decoration: BoxDecoration(
        color: accent
            ? colors.primary
            : colors.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent
              ? colors.primary
              : colors.textPrimary.withValues(alpha: 0.1),
        ),
        boxShadow: accent
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.25),
                  blurRadius: 24,
                ),
              ]
            : null,
      ),
      child: child,
    );
    Widget bone(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: colors.textPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(h),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: tile(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bone(54, 6),
                  const Spacer(),
                  bone(80, 10),
                  const SizedBox(height: 8),
                  // An empty progress track.
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.inputBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: tile(
                  accent: true,
                  child: Center(
                    child: Icon(
                      Icons.south_rounded,
                      size: 30,
                      color: colors.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: tile(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final h in const [0.2, 0.35, 0.15, 0.3]) ...[
                          Expanded(
                            child: FractionallySizedBox(
                              heightFactor: h,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colors.textPrimary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A situation card: optional picture, eyebrow, headline, one sentence and
/// actions. Side by side when wide, stacked when narrow.
class SignalStateCard extends StatelessWidget {
  const SignalStateCard({
    super.key,
    required this.title,
    required this.body,
    this.eyebrow,
    this.eyebrowColor,
    this.art,
    this.actions = const [],
  });

  final String title;
  final String body;
  final String? eyebrow;
  final Color? eyebrowColor;
  final Widget? art;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null) ...[
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: eyebrowColor ?? colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: SignalEyebrow(eyebrow!)),
            ],
          ),
          const SizedBox(height: 14),
        ],
        Text(
          title,
          style: AppTypography.display(
            30,
            weight: FontWeight.w600,
          ).copyWith(color: colors.textPrimary, height: 1.1),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: AppTypography.body.copyWith(
            fontSize: 14.5,
            height: 1.5,
            color: colors.textSecondary,
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 22),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ],
    );
    return SignalCard(
      padding: const EdgeInsets.all(32),
      child: LayoutBuilder(
        builder: (context, c) {
          final a = art;
          if (a == null) return text;
          if (c.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [a, const SizedBox(height: 24), text],
            );
          }
          return Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: 40),
              a,
            ],
          );
        },
      ),
    );
  }
}

/// A grey placeholder block; give it a [SignalShimmer] ancestor.
class SignalBone extends StatelessWidget {
  const SignalBone({super.key, this.width, required this.height, this.radius});

  final double? width;
  final double height;
  final double? radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.of(context).textPrimary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(radius ?? height / 2),
    ),
  );
}

/// A soft light band sweeping across its [SignalBone]s; still when
/// animations are off.
class SignalShimmer extends StatefulWidget {
  const SignalShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<SignalShimmer> createState() => _SignalShimmerState();
}

class _SignalShimmerState extends State<SignalShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
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
    final glow = AppColors.of(context).textPrimary.withValues(alpha: 0.08);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          if (!_c.isAnimating) return child!;
          final x = -1.5 + 3 * _c.value;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(x - 0.6, 0),
              end: Alignment(x + 0.6, 0),
              colors: [
                glow.withValues(alpha: 0),
                glow,
                glow.withValues(alpha: 0),
              ],
            ).createShader(rect),
            child: child,
          );
        },
      ),
    );
  }
}
