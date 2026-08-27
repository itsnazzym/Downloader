import 'package:flutter/material.dart';
import '../foundation/colors.dart';
import '../foundation/spacing.dart';
import '../foundation/typography.dart';
import 'package:gap/gap.dart';

enum AppButtonType { primary, secondary, ghost }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonType type;
  final bool isLoading;
  final bool expand;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.expand = false,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  }) : type = AppButtonType.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  }) : type = AppButtonType.secondary;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  }) : type = AppButtonType.ghost;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hovering = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final ios = colors.isIosChrome;

    final Color baseBg = switch (widget.type) {
      AppButtonType.primary => colors.primary,
      AppButtonType.secondary => colors.surfaceHighlight,
      AppButtonType.ghost => Colors.transparent,
    };

    final Color bgColor = _hovering && widget.onPressed != null
        ? Color.lerp(
            baseBg,
            Colors.white,
            widget.type == AppButtonType.primary ? 0.08 : 0.04,
          )!
        : baseBg;

    final Color contentColor = switch (widget.type) {
      AppButtonType.primary => colors.onPrimary,
      AppButtonType.secondary => colors.textPrimary,
      AppButtonType.ghost => colors.textSecondary,
    };

    final BorderSide? border = switch (widget.type) {
      AppButtonType.secondary => BorderSide(color: colors.border),
      AppButtonType.ghost => ios ? BorderSide(color: colors.glassBorder) : null,
      AppButtonType.primary => null,
    };

    final scale = reduceMotion
        ? 1.0
        : (_pressed ? 0.98 : (_hovering ? 1.01 : 1.0));

    return FocusableActionDetector(
      enabled: widget.onPressed != null && !widget.isLoading,
      onShowFocusHighlight: (focused) => setState(() => _focused = focused),
      onShowHoverHighlight: (hovering) => setState(() => _hovering = hovering),
      child: GestureDetector(
        onTapDown: widget.onPressed == null || widget.isLoading
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: widget.expand ? double.infinity : null,
            height: ios ? 40 : 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: AppRadius.controlOf(context),
              border: Border.all(
                color: _focused
                    ? colors.primary
                    : (border?.color ?? Colors.transparent),
                width: _focused ? 2 : (border != null ? 1 : 0),
              ),
              boxShadow: widget.type == AppButtonType.primary && ios
                  ? [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.isLoading ? null : widget.onPressed,
                borderRadius: AppRadius.controlOf(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                  child: widget.isLoading
                      ? Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: contentColor,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisSize: widget.expand
                              ? MainAxisSize.max
                              : MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(widget.icon, size: 16, color: contentColor),
                              const Gap(8),
                            ],
                            if (widget.expand)
                              Expanded(
                                child: Text(
                                  widget.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.label.copyWith(
                                    color: contentColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              Text(
                                widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label.copyWith(
                                  color: contentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
