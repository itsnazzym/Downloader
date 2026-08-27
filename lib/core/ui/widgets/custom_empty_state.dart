import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';

class CustomEmptyState extends StatelessWidget {
  final String title;
  final String? description;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const CustomEmptyState({
    super.key,
    required this.title,
    this.description,
    required this.icon,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.of(context).surface.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.of(context).border.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: AppColors.of(
                    context,
                  ).textSecondary.withValues(alpha: 0.5),
                ),
              )
              .animate()
              .scale(duration: 400.ms, curve: Curves.easeOutBack)
              .fade(duration: 400.ms),
          const Gap(24),
          Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.of(context).textPrimary,
                ),
                textAlign: TextAlign.center,
              )
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms)
              .slideY(
                begin: 0.2,
                end: 0,
                delay: 100.ms,
                duration: 400.ms,
                curve: Curves.easeOut,
              ),
          if (description != null) ...[
            const Gap(8),
            Text(
              description!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.of(context).textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
          ],
          if (onAction != null && actionLabel != null) ...[
            const Gap(24),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add, size: 18),
              label: Text(actionLabel!),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.of(context).primary,
                side: BorderSide(color: AppColors.of(context).primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ).animate().fadeIn(delay: 300.ms).scale(delay: 300.ms),
          ],
        ],
      ),
    );
  }
}
