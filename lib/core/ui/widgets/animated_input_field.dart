import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';

class AnimatedInputField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;

  const AnimatedInputField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onSubmitted,
  });

  @override
  State<AnimatedInputField> createState() => _AnimatedInputFieldState();
}

class _AnimatedInputFieldState extends State<AnimatedInputField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
    widget.controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reduce = MediaQuery.of(context).disableAnimations;
    return AnimatedContainer(
      duration: reduce ? Duration.zero : 240.ms,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: _isFocused ? colors.glassFill : colors.inputBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isFocused ? colors.primary : colors.glassBorder,
          width: _isFocused ? 1.5 : 1,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : colors.tintedShadow,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        style: AppTypography.body.copyWith(color: colors.textPrimary),
        cursorColor: colors.primary,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 18,
          ),
          hintText: widget.hintText,
          hintStyle: AppTypography.body.copyWith(color: colors.textSecondary),
          prefixIcon:
              Icon(
                    Icons.link_rounded,
                    color: _isFocused ? colors.primary : colors.textSecondary,
                  )
                  .animate(target: _isFocused && !reduce ? 1 : 0)
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1, 1),
                  ),
          suffixIcon: AnimatedOpacity(
            duration: 200.ms,
            opacity: widget.controller.text.isNotEmpty ? 1 : 0,
            child: IconButton(
              icon: Icon(Icons.clear_rounded, color: colors.textSecondary),
              onPressed: widget.controller.clear,
            ),
          ),
        ),
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}
