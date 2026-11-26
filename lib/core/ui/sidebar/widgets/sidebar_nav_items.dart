import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/design_system/components/app_skeleton.dart';
import 'package:modern_downloader/core/design_system/foundation/colors.dart';
import 'package:modern_downloader/core/design_system/foundation/spacing.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';

class SidebarDensity extends InheritedWidget {
  final bool compact;

  const SidebarDensity({
    super.key,
    required this.compact,
    required super.child,
  });

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

/// Sidebar motion, or none when reduce effects / the OS asks for it.
Duration _motion(BuildContext context, int ms) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: ms);

/// A raised card that groups one sidebar section: gradient face, a light
/// top edge and a soft drop shadow give it depth without any blur.
class SidebarPanel extends StatelessWidget {
  const SidebarPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final compact = SidebarDensity.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 3 : AppSpacing.xs),
      decoration: BoxDecoration(
        borderRadius: AppRadius.largeBorder,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              colors.surfaceHighlight.withValues(alpha: 0.55),
              colors.surface,
            ),
            colors.surface,
          ],
        ),
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
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
    final colors = AppColors.of(context);
    return SidebarPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.xxs,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const Gap(AppSpacing.xs),
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ...children,
        ],
      ),
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
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final compact = SidebarDensity.of(context);
    final isSelected = widget.isSelected;
    final colors = AppColors.of(context);
    final motion = _motion(context, 180);
    final lifted = _isHovering && !_isPressed;

    final textColor = isSelected || _isHovering
        ? colors.textPrimary
        : colors.textSecondary;
    final iconColor = isSelected
        ? colors.primary
        : (_isHovering ? colors.textPrimary : colors.textSecondary);

    final decoration = BoxDecoration(
      borderRadius: AppRadius.mediumBorder,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isSelected
            ? [
                colors.primary.withValues(alpha: 0.30),
                colors.primary.withValues(alpha: 0.10),
              ]
            : [
                colors.surfaceHighlight.withValues(alpha: lifted ? 0.75 : 0),
                colors.surfaceHighlight.withValues(alpha: lifted ? 0.40 : 0),
              ],
      ),
      border: Border.all(
        color: isSelected
            ? colors.primary.withValues(alpha: 0.40)
            : colors.border.withValues(alpha: lifted ? 0.6 : 0),
      ),
      boxShadow: [
        BoxShadow(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.28)
              : Colors.black.withValues(alpha: lifted ? 0.30 : 0),
          blurRadius: isSelected ? 12 : 8,
          offset: Offset(0, isSelected ? 4 : 3),
        ),
      ],
    );

    final icon = AnimatedScale(
      scale: isSelected ? 1.12 : 1.0,
      duration: motion,
      curve: Curves.easeOutBack,
      child: Icon(widget.icon, size: 16, color: iconColor),
    );

    final row = AnimatedContainer(
      duration: motion,
      curve: Curves.easeOutCubic,
      height: 32,
      width: compact ? double.infinity : null,
      padding: EdgeInsets.only(
        left: compact ? AppSpacing.xs : 0,
        right: AppSpacing.xs,
      ),
      margin: const EdgeInsets.only(bottom: 2),
      // Hover lifts the tile; a press (scale below) pushes it back in.
      transform: Matrix4.translationValues(0, lifted ? -1.0 : 0, 0),
      decoration: decoration,
      child: compact
          ? Center(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  icon,
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
                          color: colors.primary,
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
                // Active indicator: grows out of the tile's left edge.
                AnimatedContainer(
                  duration: motion,
                  curve: Curves.easeOutCubic,
                  width: 3,
                  height: isSelected ? 16 : 0,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: AppRadius.fullBorder,
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.7),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const Gap(AppSpacing.xs),
                icon,
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
                          ? colors.primary
                          : colors.surfaceHighlight,
                      borderRadius: AppRadius.fullBorder,
                    ),
                    child: Text(
                      widget.count.toString(),
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : colors.textSecondary,
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
          onHighlightChanged: (down) => setState(() => _isPressed = down),
          borderRadius: BorderRadius.circular(8),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: colors.primary.withValues(alpha: 0.18),
          child: AnimatedScale(
            scale: _isPressed ? 0.97 : 1.0,
            duration: _motion(context, 90),
            child: compact ? Tooltip(message: widget.label, child: row) : row,
          ),
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
      return SidebarPanel(
        child: Tooltip(
          message: widget.label,
          child: SidebarNavItem(
            icon: widget.icon,
            label: widget.label,
            isSelected: widget.initiallyExpanded,
            onTap: () => GoRouter.of(context).go('/settings/general'),
          ),
        ),
      );
    }
    final colors = AppColors.of(context);
    final active = widget.initiallyExpanded;
    final motion = _motion(context, 220);
    return SidebarPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Parent Item
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleTap,
              borderRadius: AppRadius.mediumBorder,
              hoverColor: colors.surfaceHighlight.withValues(alpha: 0.6),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: 16,
                      color: active ? colors.primary : colors.textSecondary,
                    ),
                    const Gap(AppSpacing.s),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: active
                              ? colors.textPrimary
                              : colors.textSecondary,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    RotationTransition(
                      turns: _iconTurns,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Children
          AnimatedSize(
            duration: motion,
            curve: Curves.easeOutCubic,
            child: SizedBox(
              width: double.infinity,
              child: _isExpanded
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: motion,
                      curve: Curves.easeOutCubic,
                      builder: (context, t, child) => Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, (1 - t) * -6),
                          child: child,
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(
                          left: AppSpacing.s,
                          top: AppSpacing.xxs,
                        ),
                        padding: const EdgeInsets.only(left: AppSpacing.xxs),
                        // Guide line ties the sub-pages to their group.
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: colors.border.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: widget.children,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
