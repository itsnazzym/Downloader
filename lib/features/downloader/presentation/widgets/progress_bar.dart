import 'package:flutter/material.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';

class ProgressBar extends StatelessWidget {
  final double progress;
  final double height;
  final Color? color;

  const ProgressBar({
    super.key,
    required this.progress,
    this.height = 6,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fill = color ?? colors.primary;
    final clampedProgress = progress.clamp(0.0, 1.0);

    return RepaintBoundary(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: colors.surfaceHighlight,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: clampedProgress),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
