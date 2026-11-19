import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'archive_hub_view.dart';
import 'mobile/tiktok_hub_mobile_view.dart';
import 'desktop/tiktok_archive_desktop_view.dart';
import 'mobile/tiktok_archive_mobile_view.dart';

class TikTokArchiveView extends ConsumerWidget {
  const TikTokArchiveView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final state = ref.watch(tikTokArchiveProvider);

    // 1. Loading State
    if (state.isLoading) {
      if (PlatformInfo.isMobile) return const TikTokLoadingMobileView();
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colors.primary),
              const SizedBox(height: 16),
              Text(
                'Analyse et indexation du catalogue TikTok en cours...',
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'Traitement en isolate d\'arrière-plan (sans bloquer l\'application)',
                style: AppTypography.caption.copyWith(
                  color: colors.textDisabled,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Hub Mode or Empty State: Render the central Archives & Imports Hub
    if (state.viewMode == TikTokViewMode.hub || !state.hasCatalog) {
      return const ArchiveHubView();
    }

    // 3. Loaded State in active browsing mode: Adaptive layout (Desktop vs Mobile)
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 800) {
          return TikTokArchiveDesktopView(catalog: state.catalog!);
        } else {
          return TikTokArchiveMobileView(catalog: state.catalog!);
        }
      },
    );
  }
}
