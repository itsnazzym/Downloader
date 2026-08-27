import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/spacing.dart';

/// Frosted panel used by the iOS chrome (and any caller that wants glass).
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final Border? border;
  final double blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.border,
    this.blur = 22.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = AppRadius.panelOf(context);
    final reduceTransparency = MediaQuery.of(context).disableAnimations;

    Widget card = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: reduceTransparency
            ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
            : ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color ?? colors.glassFill,
            borderRadius: radius,
            border: border ?? Border.all(color: colors.glassBorder, width: 1),
            boxShadow: colors.tintedShadow,
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: colors.glassHighlight, width: 0.8),
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: card),
      );
    }

    return card;
  }
}
