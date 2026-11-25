import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/design_system/components/app_skeleton.dart';
import 'package:modern_downloader/core/design_system/foundation/colors.dart';
import 'package:modern_downloader/core/design_system/foundation/spacing.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';

class SidebarDensity extends InheritedWidget {
  final bool compact;

  const SidebarDensity({super.key, required this.compact, required super.child});

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<SidebarDensity>()
            ?.compact ??
        false;
  }

  @override
  bool updateShouldNotify(SidebarDensity oldWidget) {
    return compact != oldWidget.compact;
  }
}

class SidebarNavSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SidebarNavSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final compact = SidebarDensity.of(context);
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

class SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;
  final bool isLoading;

  const SidebarNavItem({
    super.key,
    required this.icon,
    required this.label,
    this.isSelected = false,
    required this.onTap,
    this.count,
    this.isLoading = false,
  });

  @override
  State<SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<SidebarNavItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final compact = SidebarDensity.of(context);
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
      // InkWell (not GestureDetector) so Tab reaches the item, Enter/Space
      // activate it and a focus ring shows; hover keeps its own look.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: AppColors.of(context).primary.withValues(alpha: 0.18),
          child: compact ? Tooltip(message: widget.label, child: row) : row,
        ),
      ),
    );
  }
}

class SidebarExpandableNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final List<Widget> children;
  final bool initiallyExpanded;

  const SidebarExpandableNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  State<SidebarExpandableNavItem> createState() =>
      _SidebarExpandableNavItemState();
}

class _SidebarExpandableNavItemState extends State<SidebarExpandableNavItem>
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
  void didUpdateWidget(SidebarExpandableNavItem oldWidget) {
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
    final compact = SidebarDensity.of(context);
    if (compact) {
      return Tooltip(
        message: widget.label,
        child: SidebarNavItem(
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
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
