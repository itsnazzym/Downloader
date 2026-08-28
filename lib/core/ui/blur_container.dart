import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/theme/ios_theme.dart';

class BlurContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onPressed;
  final bool useBlur;

  const BlurContainer({
    super.key,
    required this.child,
    this.borderRadius = IOSTheme.kRadiusLarge,
    this.blurSigma = 20.0,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.onPressed,
    this.useBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reduce = MediaQuery.of(context).disableAnimations;

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        children: [
          if (!reduce && useBlur)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: const SizedBox.expand(),
              ),
            ),
          Container(
            padding: padding,
            decoration: IOSTheme.glassDecorationFor(
              context,
              radius: borderRadius,
            ).copyWith(color: color ?? colors.glassFill),
            child: child,
          ),
        ],
      ),
    );

    if (onPressed != null) {
      return GestureDetector(onTap: onPressed, child: content);
    }

    return content;
  }
}
