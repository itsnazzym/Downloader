import 'package:flutter/material.dart';
import 'package:tapload/core/design_system/components/design_progress_bar.dart';

/// Download progress in the active design's style (see [DesignProgressBar]).
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
    return DesignProgressBar(value: progress, height: height, color: color);
  }
}
