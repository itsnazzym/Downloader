import 'package:flutter/material.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';

import 'signal_widgets.dart';

/// Signal's form controls, measured on the Reglages and Transfert mockups.

/// A text field decoration with no box of its own (it sits in a
/// [SignalInset]); overrides the theme's borders and fill.
InputDecoration signalBareInput(BuildContext context, String hint) {
  final colors = AppColors.of(context);
  return InputDecoration(
    isDense: true,
    isCollapsed: true,
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    hintText: hint,
    hintMaxLines: 1,
    hintStyle: AppTypography.body.copyWith(
      fontSize: 13,
      color: colors.textDisabled,
    ),
  );
}

/// 44x26 switch: sunken track, accent fill and dark knob when on.
class SignalSwitch extends StatelessWidget {
  const SignalSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      label: label,
      enabled: enabled,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => onChanged?.call(!value),
          ),
        },
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return GestureDetector(
              onTap: enabled ? () => onChanged!(!value) : null,
              child: Opacity(
                opacity: enabled ? 1 : 0.5,
                child: AnimatedContainer(
                  duration: signalMotion(context, 200),
                  width: 44,
                  height: 26,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: value ? colors.primary : colors.inputBackground,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: focused
                          ? colors.textPrimary
                          : (value
                                ? colors.primary
                                : colors.textPrimary.withValues(alpha: 0.12)),
                    ),
                    boxShadow: value
                        ? [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.22),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedAlign(
                    duration: signalMotion(context, 380),
                    curve: const Cubic(0.3, 1.25, 0.4, 1),
                    alignment: value
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: value ? colors.onPrimary : colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Round icon button with a tooltip and a hover fill.
class SignalIconButton extends StatefulWidget {
  const SignalIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 36,
    this.iconSize = 16,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? color;

  @override
  State<SignalIconButton> createState() => _SignalIconButtonState();
}

class _SignalIconButtonState extends State<SignalIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final enabled = widget.onTap != null;
    return Tooltip(
      message: widget.tooltip,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (h) => setState(() => _hover = h),
        customBorder: const CircleBorder(),
        focusColor: colors.primary.withValues(alpha: 0.25),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: signalMotion(context, 180),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover && enabled
                ? colors.surfaceHighlight
                : Colors.transparent,
          ),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: !enabled
                ? colors.textDisabled
                : (widget.color ??
                      (_hover ? colors.textPrimary : colors.textSecondary)),
          ),
        ),
      ),
    );
  }
}

/// Sunken pill (folder path, IP address, select, stepper).
class SignalInset extends StatelessWidget {
  const SignalInset({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 4, 0),
    this.height = 40,
    this.ring = 0.08,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;
  final double ring;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.textPrimary.withValues(alpha: ring)),
      ),
      child: child,
    );
  }
}

/// Square checkbox of the Transfert mockup: hairline box, cream when on.
class SignalCheck extends StatelessWidget {
  const SignalCheck({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedContainer(
      duration: signalMotion(context, 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: value ? colors.textPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: value
              ? colors.textPrimary
              : colors.textPrimary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: value
          ? Icon(Icons.check_rounded, size: 15, color: colors.background)
          : null,
    );
  }
}

/// Grey mono pill used for tool names and small tags.
class SignalTag extends StatelessWidget {
  const SignalTag(this.text, {super.key, this.mono = true});

  final String text;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.textPrimary.withValues(alpha: 0.12)),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          text,
          style: (mono ? AppTypography.mono : AppTypography.body).copyWith(
            fontSize: 12.5,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
