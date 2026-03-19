import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:modern_downloader/theme/ios_theme.dart';

class CupertinoSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String placeholder;
  final Function(String) onSubmitted;
  final Widget? trailing;

  const CupertinoSearchBar({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.placeholder = 'Search',
    this.trailing,
  });

  @override
  State<CupertinoSearchBar> createState() => _CupertinoSearchBarState();
}

class _CupertinoSearchBarState extends State<CupertinoSearchBar> {
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
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _isFocused
            ? IOSTheme.systemGray5
            : IOSTheme.systemGray5.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.search,
            color: _isFocused ? IOSTheme.systemBlue : IOSTheme.systemGray,
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              style: IOSTheme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: IOSTheme.textTheme.bodyMedium?.copyWith(
                  color: IOSTheme.systemGray,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: widget.onSubmitted,
            ),
          ),
          if (widget.controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                widget.controller.clear();
                setState(() {});
              },
              child: Icon(
                CupertinoIcons.clear_circled_solid,
                color: IOSTheme.systemGray,
                size: 18,
              ),
            ),
          if (widget.trailing != null) ...[
            SizedBox(width: 8),
            widget.trailing!,
          ],
        ],
      ),
    );
  }
}
