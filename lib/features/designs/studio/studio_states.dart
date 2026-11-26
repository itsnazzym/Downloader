import 'package:flutter/material.dart';
import '../shared/empty_art.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';

import 'studio_widgets.dart';

/// Studio's situations: an empty page drawn as an unwritten ledger, the
/// skeleton shimmer, and the short readable reason of a failed download.

/// The editorial "nothing recorded yet" block: a heavy ink rule, a title bar
/// and empty ledger lines, an unlit recording ring on the first one. Shows
/// the Blender loop (`emptyArtAsset`) instead when it loads.
class StudioEmptyArt extends StatelessWidget {
  const StudioEmptyArt({super.key, this.broken = false});

  /// Drawn for an error: the rule turns red and the ring is struck.
  final bool broken;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final code = CustomPaint(
      size: const Size(280, 120),
      painter: _LedgerPainter(
        ink: broken ? c.error : c.textPrimary,
        bar: c.border,
        line: c.borderSubtle,
        ring: broken ? c.error : c.accent,
        broken: broken,
      ),
    );
    if (broken) return code;
    return Image.asset(
      emptyArtAsset(context, 'studio'),
      width: 280,
      height: 160,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => code,
    );
  }
}

class _LedgerPainter extends CustomPainter {
  _LedgerPainter({
    required this.ink,
    required this.bar,
    required this.line,
    required this.ring,
    required this.broken,
  });

  final Color ink;
  final Color bar;
  final Color line;
  final Color ring;
  final bool broken;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, 2), Paint()..color = ink);
    final fill = Paint()..color = bar;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 16, w * 0.46, 8),
        const Radius.circular(2),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 30, w * 0.28, 5),
        const Radius.circular(2),
      ),
      Paint()..color = line,
    );
    final hair = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = 58.0 + i * 24;
      canvas.drawLine(Offset(0, y), Offset(w, y), hair);
      // The size column, right-aligned, like the table's.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w - 34, y + 9, 34, 5),
          const Radius.circular(2),
        ),
        Paint()..color = line,
      );
    }
    final ringPaint = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    const center = Offset(4.5, 70);
    canvas.drawCircle(center, 3.5, ringPaint);
    if (broken) {
      canvas.drawLine(const Offset(0, 74.5), const Offset(9, 65.5), ringPaint);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(16, 67, w * 0.38, 6),
        const Radius.circular(2),
      ),
      Paint()..color = line,
    );
  }

  @override
  bool shouldRepaint(_LedgerPainter old) =>
      old.ink != ink ||
      old.bar != bar ||
      old.line != line ||
      old.ring != ring ||
      old.broken != broken;
}

/// The page-wide situation block: art, a title, one sentence, actions.
/// Left-aligned like a column of print, centred in the space it gets.
class StudioSituation extends StatelessWidget {
  const StudioSituation({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
    this.broken = false,
    this.detail,
  });

  final String title;
  final String body;
  final List<Widget> actions;
  final bool broken;

  /// A technical line under the sentence (the raw error), in mono.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudioEmptyArt(broken: broken),
              const SizedBox(height: 28),
              Text(title, style: studioTitle(c, 24)),
              const SizedBox(height: 8),
              Text(
                body,
                style: studioText(c, size: 14, color: c.textSecondary),
              ),
              if (detail != null && detail!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  detail!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: studioMono(c, size: 11, color: c.textDisabled),
                ),
              ],
              const SizedBox(height: 22),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}

/// A soft light sweeping across [child]'s bars every 1.4 s; still when
/// effects are reduced.
class StudioShimmer extends StatefulWidget {
  const StudioShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<StudioShimmer> createState() => _StudioShimmerState();
}

class _StudioShimmerState extends State<StudioShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    final base = c.borderSubtle;
    final light = Color.lerp(base, c.surface, 0.75)!;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final x = _controller.value * 3 - 1.5;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(x - 0.6, 0),
              end: Alignment(x + 0.6, 0),
              colors: [base, light, base],
            ).createShader(rect),
            child: child,
          );
        },
      ),
    );
  }
}

/// A grey placeholder bar for skeletons.
class StudioBone extends StatelessWidget {
  const StudioBone({super.key, required this.width, this.height = 8});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.of(context).borderSubtle,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
