import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/design_system/foundation/spacing.dart';
import 'package:tapload/core/design_system/foundation/typography.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import '../../providers/downloader_provider.dart';
import '../../providers/filtered_downloads_provider.dart';

/// Shared focus target so Ctrl/Cmd+F from the download list can jump here.
class DownloadSearchFocus {
  static FocusNode? _node;

  static FocusNode attach(FocusNode node) {
    _node = node;
    return node;
  }

  static void detach(FocusNode node) {
    if (identical(_node, node)) {
      _node = null;
    }
  }

  static void request() {
    _node?.requestFocus();
  }
}

/// Recessed library filter — instrument rail, not a Material/Cupertino pill.
class DownloadSearchField extends ConsumerStatefulWidget {
  const DownloadSearchField({
    super.key,
    required this.onChanged,
    this.focusNode,
  });

  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;

  @override
  ConsumerState<DownloadSearchField> createState() =>
      _DownloadSearchFieldState();
}

class _DownloadSearchFieldState extends ConsumerState<DownloadSearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _ownsFocusNode = false;
  var _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(downloadSearchQueryProvider),
    );
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode(debugLabel: 'download-search');
    DownloadSearchFocus.attach(_focusNode);
    _focusNode.addListener(_onFocus);
    _controller.addListener(_onText);
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _focusNode.removeListener(_onFocus);
    DownloadSearchFocus.detach(_focusNode);
    _controller.dispose();
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocus() {
    if (!mounted) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  void _emit(String value) {
    widget.onChanged(value);
  }

  void _clear() {
    _controller.clear();
    _emit('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(downloadSearchQueryProvider, (previous, next) {
      if (_controller.text == next) return;
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    });

    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final query = _controller.text;
    final hasQuery = query.isNotEmpty;
    final total =
        ref.watch(downloadListProvider.select((s) => s.valueOrNull?.length)) ??
        0;
    final visible = ref.watch(filteredDownloadListPhaseProvider).valueOrNull ?? 0;
    final radius = colors.isIosChrome ? 10.0 : 6.0;
    final spine = _focused
        ? colors.primary
        : hasQuery
        ? colors.primary.withValues(alpha: 0.65)
        : colors.border;
    final well = Color.alphaBlend(
      colors.textPrimary.withValues(alpha: _focused ? 0.06 : 0.035),
      colors.background,
    );

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (hasQuery) {
            _clear();
          } else {
            _focusNode.unfocus();
          }
        },
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 40,
        decoration: BoxDecoration(
          color: well,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: _focused
                ? colors.primary.withValues(alpha: 0.55)
                : colors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 2,
              color: spine,
            ),
            const SizedBox(width: 10),
            ExcludeSemantics(
              child: Text(
                '/',
                style: AppTypography.mono.copyWith(
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: _focused
                      ? colors.textSecondary
                      : colors.textDisabled,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textAlign: TextAlign.start,
                cursorWidth: 1.2,
                cursorHeight: 16,
                cursorColor: colors.primary,
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.1,
                  height: 1.2,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.searchDownloads,
                  hintStyle: AppTypography.bodySmall.copyWith(
                    color: colors.textDisabled,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.1,
                    height: 1.2,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  // The row centres the line: no padding, so a design can
                  // set a shorter field (Terminal: 30 px) without clipping.
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: _emit,
                textInputAction: TextInputAction.search,
              ),
            ),
            if (total > 0) ...[
              const SizedBox(width: AppSpacing.xs),
              IgnorePointer(
                child: Text(
                  hasQuery ? l10n.searchMatchCount(visible, total) : '$total',
                  style: AppTypography.mono.copyWith(
                    fontSize: 11,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: hasQuery && visible == 0
                        ? colors.warning
                        : colors.textDisabled,
                  ),
                ),
              ),
            ],
            if (hasQuery)
              Semantics(
                button: true,
                label: l10n.searchClear,
                child: IconButton(
                  onPressed: _clear,
                  tooltip: l10n.searchClear,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 28,
                  ),
                  icon: Icon(
                    Icons.close,
                    size: 14,
                    color: colors.textSecondary,
                  ),
                ),
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}
