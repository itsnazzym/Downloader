import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:modern_downloader/theme/ios_theme.dart';
import 'package:modern_downloader/theme/palette.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: 300.ms,
      curve: Curves.easeOutCubic, // easeOutBack causes negative blur values
      decoration: BoxDecoration(
        color: _isFocused ? Palette.glassWhiteHover : Palette.glassWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isFocused ? Palette.neonBlue : Palette.borderWhite,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _isFocused
                ? Palette.neonBlue.withValues(alpha: 0.3)
                : Colors.transparent,
            blurRadius: _isFocused ? 20 : 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        style: IOSTheme.textTheme.bodyLarge,
        cursorColor: Palette.neonBlue,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          hintText: widget.hintText,
          hintStyle: IOSTheme.textTheme.bodyLarge?.copyWith(
            color: Palette.textTertiary,
          ),
          prefixIcon:
              Icon(
                    Icons.link_rounded,
                    color: _isFocused
                        ? Palette.neonBlue
                        : Palette.textSecondary,
                  )
                  .animate(target: _isFocused ? 1 : 0)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                  ),
          suffixIcon: AnimatedOpacity(
            duration: 200.ms,
            opacity: widget.controller.text.isNotEmpty ? 1 : 0,
            child: IconButton(
              icon: Icon(Icons.clear_rounded, color: Palette.textSecondary),
              onPressed: widget.controller.clear,
            ),
          ),
        ),
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}
