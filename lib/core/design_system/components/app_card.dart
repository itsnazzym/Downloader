import 'package:flutter/material.dart';
import '../../ui/glass_card.dart';
import '../foundation/colors.dart';
import '../foundation/spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (colors.isIosChrome) {
      return GlassCard(
        padding: padding ?? const EdgeInsets.all(AppSpacing.m),
        onTap: onTap,
        child: child,
      );
    }

    final content = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.panelOf(context),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppRadius.panelOf(context),
        child: content,
      );
    }

    return content;
  }
}
