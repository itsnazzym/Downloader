import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../../../core/design_system/components/app_skeleton.dart';
import '../../../../../core/design_system/foundation/colors.dart';
import '../../../../../core/design_system/foundation/spacing.dart';

class DownloadItemSkeleton extends StatelessWidget {
  const DownloadItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.of(context).border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Thumbnail Skeleton
          const AppSkeleton(
            width: 48,
            height: 48,
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
          const Gap(AppSpacing.m),

          // Content Skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const AppSkeleton(
                  width: 180,
                  height: 14,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                const Gap(8),
                // Status / Meta
                const Row(
                  children: [
                    AppSkeleton(
                      width: 60,
                      height: 10,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    Gap(8),
                    AppSkeleton(
                      width: 40,
                      height: 10,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ],
                ),
                const Gap(8),
                // Progress Bar
                const AppSkeleton(
                  width: double.infinity,
                  height: 4,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
