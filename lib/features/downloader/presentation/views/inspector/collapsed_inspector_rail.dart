import 'package:flutter/material.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

class CollapsedInspectorRail extends StatelessWidget {
  final VoidCallback onExpand;

  const CollapsedInspectorRail({super.key, required this.onExpand});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ColoredBox(
      color: AppColors.of(context).surface,
      child: Center(
        child: IconButton(
          tooltip: l10n.expandInspector,
          onPressed: onExpand,
          icon: Icon(
            Icons.chevron_left_rounded,
            color: AppColors.of(context).textSecondary,
          ),
        ),
      ),
    );
  }
}
