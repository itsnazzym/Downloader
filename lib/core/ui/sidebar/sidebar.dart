import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../design_system/foundation/typography.dart';
import '../../design_system/components/app_button.dart';
import '../../../../core/ui/primary_button.dart';
import '../../design_system/components/app_skeleton.dart';
import '../../../../features/downloader/presentation/views/dialogs/add_download_dialog.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/downloader/presentation/providers/filtered_downloads_provider.dart';
import '../../../../features/downloader/presentation/providers/downloader_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/ui/layout/pane_layout_provider.dart';
import '../../../../features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'dart:ui'; // For ImageFilter

class AppSidebar extends ConsumerWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch relevant state
    final statusFilter = ref.watch(downloadStatusFilterProvider);
    final sourceFilter = ref.watch(downloadSourceFilterProvider);
    final allDownloadsAsync = ref.watch(downloadListProvider);
    final allDownloads = allDownloadsAsync.valueOrNull ?? [];
    final settings = ref.watch(settingsProvider);

    // Calculate Counts
    final countActive = allDownloads
        .where(
          (i) =>
              i.status == DownloadStatus.downloading ||
              i.status == DownloadStatus.queued ||
              i.status == DownloadStatus.extracting ||
              i.status == DownloadStatus.processing,
        )
        .length;
    final countCompleted = allDownloads
        .where((i) => i.status == DownloadStatus.completed)
        .length;
    final countFailed = allDownloads
        .where(
          (i) =>
              i.status == DownloadStatus.failed ||
              i.status == DownloadStatus.canceled,
        )
        .length;

    // Determine Sources
    final Map<String, int> sourceCounts = {};
    for (var item in allDownloads) {
      sourceCounts[item.source] = (sourceCounts[item.source] ?? 0) + 1;
    }

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
        child: _SidebarDensity(
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
              if (compact)
                Tooltip(
                  message: l10n.newDownload,
                  child: Center(
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Material(
                        color: colors.primary,
                        borderRadius: AppRadius.controlOf(context),
                        child: InkWell(
                          onTap: openNewDownload,
                          borderRadius: AppRadius.controlOf(context),
                          child: Icon(
                            Icons.add,
                            size: 18,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                ios
                    ? SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: l10n.newDownload,
                          icon: Icons.add,
                          onPressed: openNewDownload,
                        ),
                      )
                    : AppButton.primary(
                        label: l10n.newDownload,
                        icon: Icons.add,
                        expand: true,
                        onPressed: openNewDownload,
                      ),

              const Gap(AppSpacing.l),
              const Gap(AppSpacing.l),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _NavSection(
                        title: l10n.librarySection,
                        children: [
                          _NavItem(
                            icon: Icons.inbox_rounded,
                            label: l10n.allDownloads,
                            count: allDownloads.length,
                            isLoading: allDownloadsAsync.isLoading,
                            isSelected:
                                statusFilter == DownloadStatusFilter.all &&
                                sourceFilter == null,
                            onTap: () => setStatus(DownloadStatusFilter.all),
                          ),
                          _NavItem(
                            icon: Icons.downloading_rounded,
                            label: l10n.sidebarActive,
                            count: countActive,
                            isLoading: allDownloadsAsync.isLoading,
                            isSelected:
                                statusFilter == DownloadStatusFilter.active,
                            onTap: () => setStatus(DownloadStatusFilter.active),
                          ),
                          _NavItem(
                            icon: Icons.check_circle_outline_rounded,
                            label: l10n.sidebarCompleted,
                            count: countCompleted,
                            isLoading: allDownloadsAsync.isLoading,
                            isSelected:
                                statusFilter == DownloadStatusFilter.completed,
                            onTap: () =>
                                setStatus(DownloadStatusFilter.completed),
                          ),
                          _NavItem(
                            icon: Icons.error_outline_rounded,
                            label: l10n.sidebarFailed,
                            count: countFailed,
                            isLoading: allDownloadsAsync.isLoading,
                            isSelected:
                                statusFilter == DownloadStatusFilter.failed,
                            onTap: () => setStatus(DownloadStatusFilter.failed),
                          ),
                          const Gap(AppSpacing.s),
                          _NavItem(
                            icon: Icons.bar_chart_rounded,
                            label: l10n.statistics,
                            isSelected: location == '/stats',
                            onTap: () => context.go('/stats'),
                          ),
                        ],
                      ),
                      const Gap(AppSpacing.m),
                      Divider(
                        color: AppColors.of(
                          context,
                        ).border.withValues(alpha: 0.3),
                        height: 1,
                      ),
                      const Gap(AppSpacing.m),
                      _NavSection(
                        title: l10n.sourcesSection,
                        children: allDownloadsAsync.isLoading
                            ? List.generate(
                                3,
                                (index) => const Padding(
                                  padding: EdgeInsets.only(
                                    bottom: 8,
                                    left: 12,
                                    right: 12,
                                  ),
                                  child: AppSkeleton(
                                    height: 24,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(6),
                                    ),
                                  ),
                                ),
                              )
                            : availableSources.map((source) {
                                IconData icon = Icons.public;
                                if (source == 'YouTube') {
                                  icon = Icons.video_library_outlined;
                                } else if (source == 'Instagram') {
                                  icon = Icons.photo_camera_outlined;
                                } else if (source == 'Twitter') {
                                  icon = Icons.alternate_email;
                                } else if (source == 'Twitch') {
                                  icon = Icons.videogame_asset_outlined;
                                } else if (source == 'Kick') {
                                  icon = Icons.bolt;
                                }

                                return _NavItem(
                                  icon: icon,
                                  label: sourceLabel(source),
                                  count: sourceCounts[source] ?? 0,
                                  isSelected: sourceFilter == source,
                                  onTap: () => setSource(source),
                                );
                              }).toList(),
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

              _ExpandableNavItem(
                icon: Icons.settings_outlined,
                label: l10n.settings,
                initiallyExpanded: isSettingsActive,
                children: [
                  _NavItem(
                    icon: Icons.home_filled,
                    label: l10n.mainPage,
                    isSelected: false,
                    onTap: () => context.go('/'),
                  ),
                  _NavItem(
                    icon: Icons.tune,
                    label: l10n.settingsGeneral,
                    isSelected: location == '/settings/general',
                    onTap: () => context.push('/settings/general'),
                  ),
                  _NavItem(
                    icon: Icons.folder_open_outlined,
                    label: l10n.settingsOutput,
                    isSelected: location == '/settings/output',
                    onTap: () => context.push('/settings/output'),
                  ),
                  _NavItem(
                    icon: Icons.build_circle_outlined,
                    label: l10n.settingsAdvanced,
                    isSelected: location == '/settings/advanced',
                    onTap: () => context.push('/settings/advanced'),
                  ),
                  _NavItem(
                    icon: Icons.speed_rounded,
                    label: l10n.settingsPerformance,
                    isSelected: location == '/settings/performance',
                    onTap: () => context.push('/settings/performance'),
                  ),
                  _NavItem(
                    icon: Icons.memory_outlined,
                    label: l10n.settingsSystem,
                    isSelected: location == '/settings/system',
                    onTap: () => context.push('/settings/system'),
                  ),
                  _NavItem(
                    icon: Icons.palette_outlined,
                    label: l10n.settingsAppearance,
                    isSelected: location == '/settings/appearance',
                    onTap: () => context.push('/settings/appearance'),
                  ),
                  _NavItem(
                    icon: Icons.extension_outlined,
                    label: l10n.settingsPlugins,
                    isSelected: location == '/settings/plugins',
                    onTap: () => context.push('/settings/plugins'),
                  ),
                  _NavItem(
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

class _SidebarDensity extends InheritedWidget {
  final bool compact;

  const _SidebarDensity({required this.compact, required super.child});

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_SidebarDensity>()
            ?.compact ??
        false;
  }

  @override
  bool updateShouldNotify(_SidebarDensity oldWidget) {
    return compact != oldWidget.compact;
  }
}

class _NavSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _NavSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final compact = _SidebarDensity.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xxs,
            ),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Gap(AppSpacing.xxs),
        ],
        ...children,
      ],
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;
  final bool isLoading;

  const _NavItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
    required this.onTap,
    this.count,
    this.isLoading = false,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final compact = _SidebarDensity.of(context);
    final isSelected = widget.isSelected;

    Color backgroundColor = Colors.transparent;
    if (isSelected) {
      backgroundColor = AppColors.of(context).primary.withValues(alpha: 0.15);
    } else if (_isHovering) {
      backgroundColor = AppColors.of(
        context,
      ).surfaceHighlight.withValues(alpha: 0.5);
    }

    final textColor = isSelected
        ? AppColors.of(context).textPrimary
        : (_isHovering
              ? AppColors.of(context).textPrimary
              : AppColors.of(context).textSecondary);

    final iconColor = isSelected
        ? AppColors.of(context).primary
        : (_isHovering
              ? AppColors.of(context).textPrimary
              : AppColors.of(context).textSecondary);

    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      height: 32,
      width: compact ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.mediumBorder,
        border: Border.all(
          color: isSelected
              ? AppColors.of(context).primary.withValues(alpha: 0.2)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: compact
          ? Center(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(widget.icon, size: 16, color: iconColor),
                  ),
                  if (!widget.isLoading &&
                      widget.count != null &&
                      widget.count! > 0)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: AppColors.of(context).primary,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          widget.count! > 99 ? '99+' : '${widget.count}',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption.copyWith(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          : Row(
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(widget.icon, size: 16, color: iconColor),
                ),
                const Gap(AppSpacing.s),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: textColor,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (widget.isLoading)
                  const AppSkeleton(
                    width: 24,
                    height: 16,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  )
                else if (widget.count != null && widget.count! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.of(context).primary
                          : AppColors.of(context).surfaceHighlight,
                      borderRadius: AppRadius.fullBorder,
                    ),
                    child: Text(
                      widget.count.toString(),
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : AppColors.of(context).textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: compact ? Tooltip(message: widget.label, child: row) : row,
      ),
    );
  }
}

class _ExpandableNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _ExpandableNavItem({
    required this.icon,
    required this.label,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  State<_ExpandableNavItem> createState() => _ExpandableNavItemState();
}

class _ExpandableNavItemState extends State<_ExpandableNavItem>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _iconTurns;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconTurns = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_ExpandableNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded && !oldWidget.initiallyExpanded) {
      setState(() {
        _isExpanded = true;
        _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = _SidebarDensity.of(context);
    if (compact) {
      return Tooltip(
        message: widget.label,
        child: _NavItem(
          icon: widget.icon,
          label: widget.label,
          isSelected: widget.initiallyExpanded,
          onTap: () => GoRouter.of(context).push('/settings/general'),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Parent Item
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            borderRadius: AppRadius.mediumBorder,
            hoverColor: AppColors.of(context).surfaceHighlight,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              decoration: BoxDecoration(borderRadius: AppRadius.mediumBorder),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 16,
                    color: AppColors.of(context).textSecondary,
                  ),
                  const Gap(AppSpacing.s),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.of(context).textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: _iconTurns,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.of(context).textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Children
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: SizedBox(
            width: double.infinity,
            child: _isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.children,
                    ),
                  )
                : SizedBox.shrink(), // Should hide completely
          ),
        ),
      ],
    );
  }
}
