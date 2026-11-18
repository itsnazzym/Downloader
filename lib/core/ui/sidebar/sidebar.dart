import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../design_system/components/app_button.dart';
import 'widgets/sidebar_nav_items.dart';
import 'widgets/sidebar_sources_section.dart';
import '../../../../features/downloader/presentation/views/dialogs/add_download_dialog.dart';
import '../../../../features/onboarding/presentation/onboarding_targets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/downloader/presentation/providers/filtered_downloads_provider.dart';
import '../../../../features/downloader/presentation/providers/downloader_provider.dart';
import '../../../../features/downloader/presentation/providers/download_library_counts.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/plugins/feature_activation.dart';
import '../../../../core/ui/layout/pane_layout_provider.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import '../../../../features/archive/presentation/providers/tiktok_archive_provider.dart';

import 'dart:ui'; // For ImageFilter

class AppSidebar extends ConsumerWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch relevant state
    final statusFilter = ref.watch(downloadStatusFilterProvider);
    final sourceFilter = ref.watch(downloadSourceFilterProvider);
    final libraryCounts = ref.watch(downloadLibraryCountsProvider);
    final listLoading = ref.watch(
      downloadListProvider.select((async) => async.isLoading),
    );
    final settings = ref.watch(settingsProvider);
    final features = ref.watch(featureActivationProvider);
    final featureCatalog = ref.watch(featureCatalogProvider);
    final locale = Localizations.localeOf(context).languageCode;

    final countActive = libraryCounts.active;
    final countCompleted = libraryCounts.completed;
    final countFailed = libraryCounts.failed;
    final sourceCounts = libraryCounts.sourceCounts;

    final List<String> availableSources = [
      'YouTube',
      'Instagram',
      'Twitter',
      'Twitch',
      'Kick',
    ];

    // Add dynamically discovered sources
    for (var source in sourceCounts.keys) {
      // Basic Adult Filtering
      if (!settings.adultSitesEnabled) {
        const adultKeywords = [
          'Pornhub',
          'Xvideos',
          'Xhamster',
          'Youporn',
          'Xnxx',
          'Chaturbate',
          'Onlyfans',
        ];
        if (adultKeywords.contains(source)) continue;
      }

      if (!availableSources.contains(source) && source != 'Other') {
        availableSources.add(source);
      }
    }

    void setStatus(DownloadStatusFilter status) {
      ref.read(downloadStatusFilterProvider.notifier).state = status;
      ref.read(downloadSourceFilterProvider.notifier).state =
          null; // Reset source
      if (GoRouterState.of(context).uri.path != '/') {
        context.go('/');
      }
    }

    void setSource(String? source) {
      ref.read(downloadSourceFilterProvider.notifier).state = source;
      ref.read(downloadStatusFilterProvider.notifier).state =
          DownloadStatusFilter.all; // Reset status
      if (GoRouterState.of(context).uri.path != '/') {
        context.go('/');
      }
    }

    final l10n = context.l10n;

    String sourceLabel(String source) {
      switch (source) {
        case 'YouTube':
          return l10n.sourceYouTube;
        case 'Instagram':
          return l10n.sourceInstagram;
        case 'Twitter':
          return l10n.sourceTwitter;
        case 'Twitch':
          return l10n.sourceTwitch;
        case 'Kick':
          return l10n.sourceKick;
        default:
          return source;
      }
    }

    final String location = GoRouterState.of(context).uri.path;
    final bool isSettingsActive = location.startsWith('/settings');
    final colors = AppColors.of(context);
    final ios = colors.isIosChrome;
    final collapsed = ref.watch(
      paneLayoutProvider.select((s) => s.sidebarCollapsed),
    );

    void toggleCollapsed() {
      ref.read(paneLayoutProvider.notifier).toggleSidebarCollapsed();
      ref.read(paneLayoutProvider.notifier).persist();
    }

    void openNewDownload() {
      showDialog(
        context: context,
        builder: (context) => const AddDownloadDialog(),
      );
    }

    Widget buildRail(bool compact) {
      Widget rail = Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: ios ? colors.surface.withValues(alpha: 0.55) : colors.surface,
          border: Border(
            right: BorderSide(
              color: colors.border.withValues(alpha: ios ? 0.4 : 1),
              width: 1,
            ),
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.xs : AppSpacing.s,
          vertical: AppSpacing.m,
        ),
        child: SidebarDensity(
          compact: compact,
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: Align(
                  alignment: compact ? Alignment.center : Alignment.centerRight,
                  child: IconButton(
                    tooltip: collapsed
                        ? l10n.expandSidebar
                        : l10n.collapseSidebar,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: Icon(
                      collapsed
                          ? Icons.chevron_right_rounded
                          : Icons.chevron_left_rounded,
                      color: colors.textSecondary,
                    ),
                    onPressed: toggleCollapsed,
                  ),
                ),
              ),
              const Gap(AppSpacing.s),
              KeyedSubtree(
                key: OnboardingTargets.newDownload,
                child: compact
                    ? Tooltip(
                        message: l10n.newDownload,
                        child: Material(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: openNewDownload,
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(
                                Icons.add,
                                color: colors.onPrimary,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      )
                    : AppButton.primary(
                        label: l10n.newDownload,
                        icon: Icons.add,
                        expand: true,
                        onPressed: openNewDownload,
                      ),
              ),

              const Gap(AppSpacing.l),
              const Gap(AppSpacing.l),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      KeyedSubtree(
                        key: OnboardingTargets.library,
                        child: SidebarNavSection(
                          title: l10n.librarySection,
                          children: [
                            SidebarNavItem(
                              icon: Icons.inbox_rounded,
                              label: l10n.allDownloads,
                              count: libraryCounts.total,
                              isLoading: listLoading,
                              isSelected:
                                  statusFilter == DownloadStatusFilter.all &&
                                  sourceFilter == null,
                              onTap: () => setStatus(DownloadStatusFilter.all),
                            ),
                            SidebarNavItem(
                              icon: Icons.downloading_rounded,
                              label: l10n.sidebarActive,
                              count: countActive,
                              isLoading: listLoading,
                              isSelected:
                                  statusFilter == DownloadStatusFilter.active,
                              onTap: () =>
                                  setStatus(DownloadStatusFilter.active),
                            ),
                            SidebarNavItem(
                              icon: Icons.check_circle_outline_rounded,
                              label: l10n.sidebarCompleted,
                              count: countCompleted,
                              isLoading: listLoading,
                              isSelected:
                                  statusFilter ==
                                  DownloadStatusFilter.completed,
                              onTap: () =>
                                  setStatus(DownloadStatusFilter.completed),
                            ),
                            SidebarNavItem(
                              icon: Icons.error_outline_rounded,
                              label: l10n.sidebarFailed,
                              count: countFailed,
                              isLoading: listLoading,
                              isSelected:
                                  statusFilter == DownloadStatusFilter.failed,
                              onTap: () =>
                                  setStatus(DownloadStatusFilter.failed),
                            ),
                            const Gap(AppSpacing.s),
                            if (features.isEnabledById('statistics'))
                              SidebarNavItem(
                                icon: Icons.bar_chart_rounded,
                                label: l10n.statistics,
                                isSelected: location == '/stats',
                                onTap: () => context.go('/stats'),
                              ),
                            if (features.isEnabledById('device_transfer'))
                              SidebarNavItem(
                                icon: Icons.ios_share_rounded,
                                label: l10n.transferTitle,
                                isSelected: location == '/transfer',
                                onTap: () => context.go('/transfer'),
                              ),
                            if (features.isEnabledById('tiktok_archives'))
                              SidebarNavItem(
                                icon: Icons.inventory_2_rounded,
                                label: featureCatalog.byId['tiktok_archives']!
                                    .nameFor(locale),
                                isSelected: location == '/archive',
                                onTap: () {
                                  ref
                                      .read(tikTokArchiveProvider.notifier)
                                      .setViewMode(TikTokViewMode.hub);
                                  context.go('/archive');
                                },
                              ),
                          ],
                        ),
                      ),
                      const Gap(AppSpacing.m),
                      Divider(
                        color: AppColors.of(
                          context,
                        ).border.withValues(alpha: 0.3),
                        height: 1,
                      ),
                      const Gap(AppSpacing.m),
                      SidebarSourcesSection(
                        availableSources: availableSources,
                        sourceCounts: sourceCounts,
                        activeSourceFilter: sourceFilter,
                        listLoading: listLoading,
                        onSelectSource: setSource,
                        sourceLabel: sourceLabel,
                      ),
                      const Gap(AppSpacing.l),
                    ],
                  ),
                ),
              ),

              const Gap(AppSpacing.l),

              Divider(
                color: AppColors.of(context).border.withValues(alpha: 0.3),
                height: 1,
              ),
              const Gap(AppSpacing.m),

              SidebarExpandableNavItem(
                icon: Icons.settings_outlined,
                label: l10n.settings,
                initiallyExpanded: isSettingsActive,
                children: [
                  SidebarNavItem(
                    icon: Icons.home_filled,
                    label: l10n.mainPage,
                    isSelected: false,
                    onTap: () => context.go('/'),
                  ),
                  SidebarNavItem(
                    icon: Icons.tune,
                    label: l10n.settingsGeneral,
                    isSelected: location == '/settings/general',
                    onTap: () => context.push('/settings/general'),
                  ),
                  SidebarNavItem(
                    icon: Icons.folder_open_outlined,
                    label: l10n.settingsOutput,
                    isSelected: location == '/settings/output',
                    onTap: () => context.push('/settings/output'),
                  ),
                  SidebarNavItem(
                    icon: Icons.build_circle_outlined,
                    label: l10n.settingsAdvanced,
                    isSelected: location == '/settings/advanced',
                    onTap: () => context.push('/settings/advanced'),
                  ),
                  SidebarNavItem(
                    icon: Icons.speed_rounded,
                    label: l10n.settingsPerformance,
                    isSelected: location == '/settings/performance',
                    onTap: () => context.push('/settings/performance'),
                  ),
                  SidebarNavItem(
                    icon: Icons.memory_outlined,
                    label: l10n.settingsSystem,
                    isSelected: location == '/settings/system',
                    onTap: () => context.push('/settings/system'),
                  ),
                  SidebarNavItem(
                    icon: Icons.palette_outlined,
                    label: l10n.settingsAppearance,
                    isSelected: location == '/settings/appearance',
                    onTap: () => context.push('/settings/appearance'),
                  ),
                  SidebarNavItem(
                    icon: Icons.extension_outlined,
                    label: l10n.settingsPlugins,
                    isSelected: location == '/settings/plugins',
                    onTap: () => context.push('/settings/plugins'),
                  ),
                  SidebarNavItem(
                    icon: Icons.auto_awesome_motion,
                    label: l10n.smartOrganization,
                    isSelected: location == '/settings/smart_organizer',
                    onTap: () => context.push('/settings/smart_organizer'),
                  ),
                ],
              ),
              const Gap(AppSpacing.m),
            ],
          ),
        ),
      );

      if (ios) {
        rail = ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: rail,
          ),
        );
      }
      return rail;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            collapsed || constraints.maxWidth < PaneLayout.sidebarMin;
        return buildRail(compact);
      },
    );
  }
}
