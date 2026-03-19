import 'package:flutter/material.dart';
import '../foundation/colors.dart';
import '../foundation/spacing.dart';
import '../foundation/typography.dart';
import 'package:gap/gap.dart';

enum AppButtonType { primary, secondary, ghost }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonType type;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.type = AppButtonType.primary,
    this.isLoading = false,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  }) : type = AppButtonType.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  }) : type = AppButtonType.secondary;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  }) : type = AppButtonType.ghost;

  @override
  Widget build(BuildContext context) {
    // Colors based on type
    final Color bgColor = switch (type) {
      AppButtonType.primary => AppColors.primary,
      AppButtonType.secondary => AppColors.surfaceHighlight,
      AppButtonType.ghost => Colors.transparent,
    };

    final Color contentColor = switch (type) {
      AppButtonType.primary => AppColors.onPrimary,
      AppButtonType.secondary => AppColors.textPrimary,
      AppButtonType.ghost => AppColors.textSecondary,
    };

    final BorderSide? border = switch (type) {
      AppButtonType.secondary => BorderSide(color: AppColors.border),
      _ => null,
    };

    return SizedBox(
      height: 36,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: contentColor,
          elevation: 0,
          side: border,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mediumBorder),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: contentColor,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 16), const Gap(8)],
                  Text(
                    label,
                    style: AppTypography.label.copyWith(color: contentColor),
                  ),
                ],
              ),
      ),
    );
  }
}
