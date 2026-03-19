import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../design_system/foundation/typography.dart';
import '../../design_system/components/app_button.dart';
import '../../design_system/components/app_skeleton.dart';
import '../../../../features/downloader/presentation/views/dialogs/add_download_dialog.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/downloader/presentation/providers/filtered_downloads_provider.dart';
import '../../../../features/downloader/presentation/providers/downloader_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../features/downloader/domain/enums/download_status.dart';
import '../../../../features/downloader/domain/utils/download_item_media.dart';

import 'dart:ui'; // For ImageFilter

class AppSidebar extends ConsumerWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch relevant state
    final statusFilter = ref.watch(downloadStatusFilterProvider);
    final sourceFilter = ref.watch(downloadSourceFilterProvider);
    final mediaFilter = ref.watch(downloadMediaTypeFilterProvider);
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
    final countVideos = allDownloads
        .where(
          (item) => DownloadItemMedia.detect(item) == DownloadMediaType.video,
        )
        .length;
    final countAudios = allDownloads
        .where(
          (item) => DownloadItemMedia.detect(item) == DownloadMediaType.audio,
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
      ref.read(downloadMediaTypeFilterProvider.notifier).state =
          DownloadMediaTypeFilter.all;
    }

    void setSource(String? source) {
      ref.read(downloadSourceFilterProvider.notifier).state = source;
      ref.read(downloadStatusFilterProvider.notifier).state =
          DownloadStatusFilter.all; // Reset status
      ref.read(downloadMediaTypeFilterProvider.notifier).state =
          DownloadMediaTypeFilter.all;
    }

    void setMedia(DownloadMediaTypeFilter type) {
      ref.read(downloadMediaTypeFilterProvider.notifier).state = type;
      ref.read(downloadStatusFilterProvider.notifier).state =
          DownloadStatusFilter.all;
      ref.read(downloadSourceFilterProvider.notifier).state = null;
    }

    final String location = GoRouterState.of(context).uri.path;
    final bool isSettingsActive = location.startsWith('/settings');

    // Glassmorphism Container
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.6),
            border: Border(
              right: BorderSide(
                color: AppColors.border.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s,
            vertical: AppSpacing.m,
          ),
          child: Column(
            children: [
              // Primary Action
              AppButton.primary(
                label: "New Download",
                icon: Icons.add,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AddDownloadDialog(),
                  );
                },
              ),

              const Gap(AppSpacing.l),
              const Gap(AppSpacing.l),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _NavSection(
                        title: "LIBRARY",
                        children: [
                          _NavItem(
                            icon: Icons.inbox_rounded,
                            label: "All Downloads",
                            count: allDownloads.length,
                            isLoading: allDownloadsAsync.isLoading,
                            isSelected:
                                statusFilter == DownloadStatusFilter.all &&
                                sourceFilter == null &&
                                mediaFilter == DownloadMediaTypeFilter.all,
                            onTap: () => setStatus(DownloadStatusFilter.all),
                          ),
                          _NavItem(
                            icon: Icons.downloading_rounded,
                            label: "Active",
                            count: countActive,
                            isLoading: allDownloadsAsync.isLoading,
                            isSelected:
                                statusFilter == DownloadStatusFilter.active &&
                                sourceFilter == null &&
                                mediaFilter == DownloadMediaTypeFilter.all,
                            onTap: () => setStatus(DownloadStatusFilter.active),
                          ),
                          _NavItem(
                            icon: Icons.check_circle_outline_rounded,
                            label: "Completed",
                            count: countCompleted,
                            isLoading: allDownloadsAsync.isLoading,
                            isSelected:
                                statusFilter ==
                                    DownloadStatusFilter.completed &&
                                sourceFilter == null &&
                                mediaFilter == DownloadMediaTypeFilter.all,
                            onTap: () =>
                                setStatus(DownloadStatusFilter.completed),
                          ),
                          _NavItem(
                            icon: Icons.error_outline_rounded,
                            label: "Failed",
                            count: countFailed,
                            isLoading: allDownloadsAsync.isLoading,
                            isSelected:
                                statusFilter == DownloadStatusFilter.failed &&
                                sourceFilter == null &&
                                mediaFilter == DownloadMediaTypeFilter.all,
                            onTap: () => setStatus(DownloadStatusFilter.failed),
                          ),
                          const Gap(AppSpacing.s),
                          _NavItem(
                            icon: Icons.bar_chart_rounded,
                            label: "Statistics",
                            isSelected: location == '/stats',
                            onTap: () => context.go('/stats'),
                          ),
                        ],
                      ),
                      const Gap(AppSpacing.m),
                      Divider(
                        color: AppColors.border.withValues(alpha: 0.3),
                        height: 1,
                      ),
                      const Gap(AppSpacing.m),
                      _NavSection(
                        title: "MEDIA",
                        children: [
                          _NavItem(
                            icon: Icons.movie_creation_outlined,
                            label: "Videos",
                            count: countVideos,
                            isLoading: allDownloadsAsync.isLoading,
                            isSelected:
                                mediaFilter == DownloadMediaTypeFilter.video,
                            onTap: () =>
                                setMedia(DownloadMediaTypeFilter.video),
                          ),
                          _NavItem(
                            icon: Icons.audiotrack_rounded,
                            label: "Audio",
                            count: countAudios,
                            isLoading: allDownloadsAsync.isLoading,
                            isSelected:
                                mediaFilter == DownloadMediaTypeFilter.audio,
                            onTap: () =>
                                setMedia(DownloadMediaTypeFilter.audio),
                          ),
                        ],
                      ),
                      const Gap(AppSpacing.m),
                      Divider(
                        color: AppColors.border.withValues(alpha: 0.3),
                        height: 1,
                      ),
                      const Gap(AppSpacing.m),
                      _NavSection(
                        title: "SOURCES",
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
                                  label: source,
                                  count: sourceCounts[source] ?? 0,
                                  isSelected:
                                      sourceFilter == source &&
                                      statusFilter ==
                                          DownloadStatusFilter.all &&
                                      mediaFilter ==
                                          DownloadMediaTypeFilter.all,
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
                color: AppColors.border.withValues(alpha: 0.3),
                height: 1,
              ),
              const Gap(AppSpacing.m),

              _ExpandableNavItem(
                icon: Icons.settings_outlined,
                label: "Settings",
                initiallyExpanded: isSettingsActive,
                children: [
                  _NavItem(
                    icon: Icons.home_filled,
                    label: "Main Page",
                    isSelected: false,
                    onTap: () => context.go('/'),
                  ),
                  _NavItem(
                    icon: Icons.tune,
                    label: "General",
                    isSelected: location == '/settings/general',
                    onTap: () => context.push('/settings/general'),
                  ),
                  _NavItem(
                    icon: Icons.folder_open_outlined,
                    label: "Output",
                    isSelected: location == '/settings/output',
                    onTap: () => context.push('/settings/output'),
                  ),
                  _NavItem(
                    icon: Icons.build_circle_outlined,
                    label: "Advanced",
                    isSelected: location == '/settings/advanced',
                    onTap: () => context.push('/settings/advanced'),
                  ),
                  _NavItem(
                    icon: Icons.speed_rounded,
                    label: "Performance",
                    isSelected: location == '/settings/performance',
                    onTap: () => context.push('/settings/performance'),
                  ),
                  _NavItem(
                    icon: Icons.memory_outlined,
                    label: "System",
                    isSelected: location == '/settings/system',
                    onTap: () => context.push('/settings/system'),
                  ),
                  _NavItem(
                    icon: Icons.palette_outlined,
                    label: "Appearance",
                    isSelected: location == '/settings/appearance',
                    onTap: () => context.push('/settings/appearance'),
                  ),
                  _NavItem(
                    icon: Icons.extension_outlined,
                    label: "Plugins",
                    isSelected: location == '/settings/plugins',
                    onTap: () => context.push('/settings/plugins'),
                  ),
                ],
              ),
              const Gap(AppSpacing.m),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _NavSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          child: Text(
            title,
            style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const Gap(AppSpacing.xxs),
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
    // Determine effective colors based on state
    final isSelected = widget.isSelected;

    Color backgroundColor = Colors.transparent;
    if (isSelected) {
      backgroundColor = AppColors.primary.withValues(alpha: 0.15);
    } else if (_isHovering) {
      backgroundColor = AppColors.surfaceHighlight.withValues(alpha: 0.5);
    }

    final textColor = isSelected
        ? AppColors.textPrimary
        : (_isHovering ? AppColors.textPrimary : AppColors.textSecondary);

    final iconColor = isSelected
        ? AppColors.primary
        : (_isHovering ? AppColors.textPrimary : AppColors.textSecondary);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: AppRadius.mediumBorder,
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Icon with slight scale animation
              AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(widget.icon, size: 16, color: iconColor),
              ),
              const Gap(AppSpacing.s),

              // Label
              Expanded(
                child: Text(
                  widget.label,
                  style: AppTypography.bodySmall.copyWith(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),

              // Count Badge or Loader
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
                        ? AppColors.primary
                        : AppColors.surfaceHighlight,
                    borderRadius: AppRadius.fullBorder,
                  ),
                  child: Text(
                    widget.count.toString(),
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Parent Item
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            borderRadius: AppRadius.mediumBorder,
            hoverColor: AppColors.surfaceHighlight,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              decoration: BoxDecoration(borderRadius: AppRadius.mediumBorder),
              child: Row(
                children: [
                  Icon(widget.icon, size: 16, color: AppColors.textSecondary),
                  const Gap(AppSpacing.s),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: _iconTurns,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
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
