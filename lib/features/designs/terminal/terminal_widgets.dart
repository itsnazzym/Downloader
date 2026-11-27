import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';

import '../shared/local_thumb.dart';

/// Terminal's building blocks (mockups Terminal*.dc.html): one mono size,
/// square corners, hairline panels, key hints.

TextStyle tm(
  Color color, {
  FontWeight weight = FontWeight.w400,
  double? size,
}) => AppTypography.mono.copyWith(
  fontSize: size ?? 12.5,
  color: color,
  fontWeight: weight,
);

Duration tMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 120);

/// `$ tapload <cmd> <flag> # comment`.
class TPrompt extends StatelessWidget {
  const TPrompt(this.cmd, this.flag, {super.key, this.comment});

  final String cmd;
  final String flag;
  final String? comment;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text.rich(
      TextSpan(
        text: '\$ tapload $cmd ',
        style: tm(colors.textDisabled),
        children: [
          TextSpan(text: flag, style: tm(colors.primary)),
          if (comment != null) TextSpan(text: ' # $comment'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// `p pause · c annuler`: only keys that really work.
class THints extends StatelessWidget {
  const THints(this.hints, {super.key});

  final List<(String, String)> hints;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text(
      [for (final (k, label) in hints) '$k $label'].join(' · '),
      style: tm(colors.textDisabled),
    );
  }
}

/// The mockup's `.panel`: surface fill, 1 px inset hairline.
class TPanel extends StatelessWidget {
  const TPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.accentLeft,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accentLeft;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final side = BorderSide(color: borderColor ?? colors.border);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        border: Border(
          top: side,
          right: side,
          bottom: side,
          left: accentLeft == null
              ? side
              : BorderSide(color: accentLeft!, width: 2),
        ),
      ),
      child: child,
    );
  }
}

/// The segmented bar: 6 px cells, 2 px gaps, filled up to [value].
class TSeg extends StatelessWidget {
  const TSeg({super.key, required this.value, this.height = 10, this.color});

  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.fromHeight(height),
        painter: _SegPainter(
          value.clamp(0.0, 1.0),
          color ?? colors.primary,
          colors.surfaceHighlight,
        ),
      ),
    );
  }
}

class _SegPainter extends CustomPainter {
  _SegPainter(this.value, this.fill, this.track);

  final double value;
  final Color fill;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final on = Paint()..color = fill;
    final off = Paint()..color = track;
    final edge = size.width * value;
    for (var x = 0.0; x < size.width; x += 8) {
      final w = (size.width - x).clamp(0.0, 6.0);
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), off);
      if (x < edge) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, (edge - x).clamp(0.0, w), size.height),
          on,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SegPainter old) =>
      old.value != value || old.fill != fill || old.track != track;
}

enum TButtonKind { normal, primary, danger }

/// `.btn`: key hint + label, hairline, square; primary is filled.
class TButton extends StatefulWidget {
  const TButton({
    super.key,
    required this.label,
    required this.onTap,
    this.keyHint,
    this.kind = TButtonKind.normal,
    this.height = 30,
    this.tooltip,
    this.square = false,
  });

  final String label;
  final String? keyHint;
  final VoidCallback? onTap;
  final TButtonKind kind;
  final double height;
  final String? tooltip;
  final bool square;

  @override
  State<TButton> createState() => _TButtonState();
}

class _TButtonState extends State<TButton> {
  bool _hover = false;
  bool _focus = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final enabled = widget.onTap != null;
    final primary = widget.kind == TButtonKind.primary && enabled;
    final danger = widget.kind == TButtonKind.danger && enabled;
    final fg = !enabled
        ? colors.textDisabled
        : primary
        ? colors.background
        : danger
        ? colors.error
        : colors.textPrimary;
    final keyColor = !enabled
        ? colors.textDisabled
        : primary
        ? colors.background
        : danger
        ? colors.error
        : colors.primary;
    // Pressed: primary darkens, the others light up like a selected key.
    final bg = primary
        ? (_pressed
              ? Color.lerp(colors.primary, Colors.black, 0.25)!
              : _hover
              ? Color.lerp(colors.primary, Colors.white, 0.5)!
              : colors.primary)
        : _pressed
        ? (danger ? colors.error : colors.primary).withValues(alpha: 0.16)
        : danger && _hover
        ? colors.error.withValues(alpha: 0.08)
        : (enabled ? colors.surface : Colors.transparent);
    final line = primary
        ? Colors.transparent
        : danger
        ? colors.error
        : (_hover && enabled ? colors.primary : colors.border);
    Widget button = Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: widget.square,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onTap?.call(),
          ),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: () {
            if (mounted) setState(() => _pressed = false);
          },
          child: AnimatedContainer(
            duration: tMotion(context),
            height: widget.height,
            width: widget.square ? widget.height : null,
            padding: widget.square
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: line),
            ),
            foregroundDecoration: _focus
                ? BoxDecoration(border: Border.all(color: colors.primary))
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.keyHint != null) ...[
                  Text(
                    widget.keyHint!,
                    style: tm(
                      keyColor,
                      weight: primary ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: tm(
                    fg,
                    weight: primary ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}

/// `.sw`: a 40 x 18 square switch, thumb slides in three steps.
class TSwitch extends StatelessWidget {
  const TSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      toggled: value,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged!(!value),
          focusColor: colors.primary.withValues(alpha: 0.2),
          hoverColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          // A 44 x 30 hit area around the 18 px track (30 px config lines).
          child: SizedBox(
            width: 44,
            height: 30,
            child: Center(
              child: Container(
                width: 40,
                height: 18,
                decoration: BoxDecoration(
                  color: colors.background,
                  border: Border.all(
                    color: value ? colors.primary : colors.border,
                  ),
                ),
                child: AnimatedAlign(
                  duration: tMotion(context),
                  curve: const _Steps(3),
                  alignment: value
                      ? const Alignment(0.86, 0)
                      : const Alignment(-0.86, 0),
                  child: Container(
                    width: 12,
                    height: 12,
                    color: value ? colors.primary : colors.textDisabled,
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

class _Steps extends Curve {
  const _Steps(this.n);

  final int n;

  @override
  double transformInternal(double t) => (t * n).ceil() / n;
}

/// One keyed line (`.k`): key hint, label, optional count. Selected = filled
/// primary, background-coloured bold text. Used by the sidebar and tab rows.
class TKeyRow extends StatefulWidget {
  const TKeyRow({
    super.key,
    required this.keyHint,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.countColor,
    this.expand = true,
    this.height = 28,
  });

  final String keyHint;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? count;
  final Color? countColor;
  final bool expand;
  final double height;

  @override
  State<TKeyRow> createState() => _TKeyRowState();
}

class _TKeyRowState extends State<TKeyRow> {
  bool _hover = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final on = widget.selected;
    final weight = on ? FontWeight.w700 : FontWeight.w400;
    final fg = on
        ? colors.background
        : (_hover ? colors.textPrimary : colors.textSecondary);
    final label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tm(fg, weight: weight),
    );
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (v) => setState(() => _hover = v),
          onFocusChange: (v) => setState(() => _focused = v),
          hoverColor: colors.primary.withValues(alpha: 0.06),
          focusColor: colors.primary.withValues(alpha: 0.2),
          splashFactory: NoSplash.splashFactory,
          child: AnimatedContainer(
            duration: tMotion(context),
            height: widget.height,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            // The fill hides focus ink, so keyboard focus gets an outline.
            decoration: BoxDecoration(
              color: on ? colors.primary : Colors.transparent,
              border: _focused
                  ? Border.all(color: on ? colors.background : colors.primary)
                  : null,
            ),
            child: Row(
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Text(
                  widget.keyHint,
                  style: tm(
                    on ? colors.background : colors.primary,
                    weight: weight,
                  ),
                ),
                const SizedBox(width: 10),
                if (widget.expand) Expanded(child: label) else label,
                if (widget.count != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    widget.count!,
                    style: tm(
                      on
                          ? colors.background
                          : (widget.countColor ?? colors.textDisabled),
                      weight: weight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A table line (`.ln`): hover tints it and lights a 2 px left rule.
class THoverLine extends StatefulWidget {
  const THoverLine({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.selected = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final bool selected;
  final EdgeInsetsGeometry padding;

  @override
  State<THoverLine> createState() => _THoverLineState();
}

class _THoverLineState extends State<THoverLine> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final lit = _hover || widget.selected;
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: AnimatedContainer(
          duration: tMotion(context),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: lit
                ? colors.primary.withValues(
                    alpha: widget.selected ? 0.08 : 0.05,
                  )
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: lit ? colors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// An underlined inline link (`r réessayer`).
class TLink extends StatefulWidget {
  const TLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<TLink> createState() => _TLinkState();
}

class _TLinkState extends State<TLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final c = _hover
        ? Color.lerp(colors.primary, Colors.white, 0.5)!
        : colors.primary;
    return Semantics(
      link: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Text(
            widget.label,
            style: tm(c).copyWith(
              decoration: TextDecoration.underline,
              decorationColor: c,
            ),
          ),
        ),
      ),
    );
  }
}

/// A page's bare-key bindings. The chrome's single keyboard handler asks the
/// mounted page first, so a page key always wins over a sidebar key.
class TerminalPageKeys extends StatefulWidget {
  const TerminalPageKeys({
    super.key,
    required this.bindings,
    required this.child,
  });

  /// Keys are [terminalKeyName]s: 'p', '1', 'delete', 'enter'... (Esc stays the
  /// app's: it minimizes the window.)
  final Map<String, VoidCallback> bindings;
  final Widget child;

  static VoidCallback? lookup(String key) =>
      _TerminalPageKeysState._active?.widget.bindings[key];

  @override
  State<TerminalPageKeys> createState() => _TerminalPageKeysState();
}

class _TerminalPageKeysState extends State<TerminalPageKeys> {
  static _TerminalPageKeysState? _active;

  @override
  void initState() {
    super.initState();
    _active = this;
  }

  @override
  void dispose() {
    if (_active == this) _active = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

final _digits = {
  PhysicalKeyboardKey.digit1: '1',
  PhysicalKeyboardKey.digit2: '2',
  PhysicalKeyboardKey.digit3: '3',
  PhysicalKeyboardKey.digit4: '4',
  PhysicalKeyboardKey.numpad1: '1',
  PhysicalKeyboardKey.numpad2: '2',
  PhysicalKeyboardKey.numpad3: '3',
  PhysicalKeyboardKey.numpad4: '4',
};

/// A layout-proof name for a bare key: physical digits (AZERTY top row),
/// a few named keys, else the typed character.
String? terminalKeyName(KeyEvent event) {
  final digit = _digits[event.physicalKey];
  if (digit != null) return digit;
  final logical = event.logicalKey;
  if (logical == LogicalKeyboardKey.delete) return 'delete';
  if (logical == LogicalKeyboardKey.enter ||
      logical == LogicalKeyboardKey.numpadEnter) {
    return 'enter';
  }
  final ch = event.character;
  if (ch != null && ch.trim().isNotEmpty) return ch.toLowerCase();
  final label = logical.keyLabel;
  return label.length == 1 ? label.toLowerCase() : null;
}

/// A square text field: hairline box, optional `/` or `›` prefix.
class TField extends StatelessWidget {
  const TField({
    super.key,
    required this.controller,
    this.hint,
    this.prefix,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? hint;
  final String? prefix;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: colors.inputBackground,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          if (prefix != null) ...[
            Text(prefix!, style: tm(colors.primary)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              cursorColor: colors.primary,
              style: tm(colors.textPrimary),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: hint,
                hintStyle: tm(colors.textDisabled),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `key = value` with the value in amber, as in config.toml.
class TKeyValue extends StatelessWidget {
  const TKeyValue(this.k, this.value, {super.key});

  final String k;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text.rich(
      TextSpan(
        text: '$k = ',
        children: [TextSpan(text: value, style: tm(colors.warning))],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tm(colors.textPrimary),
    );
  }
}

/// A config line: optional `# comment` above, the line, its control on the
/// right. Hover lights a 2 px left rule; [onTap] makes it a focusable key.
class TConfLine extends StatefulWidget {
  const TConfLine({
    super.key,
    required this.body,
    this.comment,
    this.commentMaxLines = 2,
    this.control,
    this.onTap,
  });

  final Widget body;
  final String? comment;
  final int commentMaxLines;
  final Widget? control;
  final VoidCallback? onTap;

  @override
  State<TConfLine> createState() => _TConfLineState();
}

class _TConfLineState extends State<TConfLine> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final comment = widget.comment;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (v) => setState(() => _hover = v),
          hoverColor: colors.primary.withValues(alpha: 0.05),
          focusColor: colors.primary.withValues(alpha: 0.16),
          splashFactory: NoSplash.splashFactory,
          child: AnimatedContainer(
            duration: tMotion(context),
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: _hover ? colors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (comment != null && comment.isNotEmpty)
                  Text(
                    '# $comment',
                    maxLines: widget.commentMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: tm(colors.textSecondary),
                  ),
                Row(
                  children: [
                    Expanded(child: widget.body),
                    if (widget.control != null) ...[
                      const SizedBox(width: 12),
                      widget.control!,
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A [TSeg] you can click or drag to set a value between [min] and [max].
class TSegSlider extends StatelessWidget {
  const TSegSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.label,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final span = max - min;
    return LayoutBuilder(
      builder: (context, c) {
        void at(double dx) {
          final f = (dx / c.maxWidth).clamp(0.0, 1.0);
          final raw = min + f * span;
          onChanged((((raw - min) / step).round() * step + min));
        }

        return Semantics(
          slider: true,
          label: label,
          value: '${value.round()}',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => at(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => at(d.localPosition.dx),
              child: SizedBox(
                height: 28,
                child: Center(
                  child: TSeg(
                    value: span <= 0 ? 0 : (value - min) / span,
                    height: 12,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// `.sel`: a square select.
class TSelect extends StatelessWidget {
  const TSelect({
    super.key,
    required this.value,
    required this.options,
    required this.label,
    required this.onChanged,
  });

  final String value;
  final Map<String, String> options;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PopupMenuButton<String>(
      tooltip: label,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.zero,
      ),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final e in options.entries)
          PopupMenuItem<String>(
            value: e.key,
            height: 36,
            child: Text(
              '${e.key == value ? '[x]' : '[ ]'} ${e.value}',
              style: tm(e.key == value ? colors.primary : colors.textPrimary),
            ),
          ),
      ],
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              options[value] ?? value,
              style: tm(colors.textPrimary, weight: FontWeight.w500),
            ),
            const SizedBox(width: 6),
            Text('▾', style: tm(colors.primary)),
          ],
        ),
      ),
    );
  }
}

/// A square thumbnail: the remote image, else the downloaded file's own
/// frame, else a `▶` on the surface.
class TThumb extends StatelessWidget {
  const TThumb({super.key, this.url, this.filePath, this.cacheWidth = 320});

  final String? url;
  final String? filePath;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final empty = ColoredBox(
      color: colors.surfaceHighlight,
      child: Center(child: Text('▶', style: tm(colors.textDisabled))),
    );
    final local = LocalVideoThumb(
      filePath: filePath,
      placeholder: empty,
      cacheWidth: cacheWidth,
    );
    final u = url;
    Widget image = local;
    if (u != null && u.isNotEmpty) {
      image = u.startsWith('http://') || u.startsWith('https://')
          ? CachedNetworkImage(
              imageUrl: u,
              fit: BoxFit.cover,
              memCacheWidth: cacheWidth,
              placeholder: (_, _) => empty,
              errorWidget: (_, _, _) => local,
            )
          : u.startsWith('assets/')
          ? Image.asset(u, fit: BoxFit.cover, errorBuilder: (_, _, _) => local)
          : Image.file(
              File(u),
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              errorBuilder: (_, _, _) => local,
            );
    }
    return Container(
      clipBehavior: Clip.hardEdge,
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: colors.border),
      ),
      decoration: const BoxDecoration(),
      child: SizedBox.expand(child: image),
    );
  }
}

/// A square, hairline dialog in the design's language.
class TDialog extends StatelessWidget {
  const TDialog({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.zero,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: DefaultTextStyle(
            style: tm(colors.textPrimary),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '## $title',
                  style: tm(colors.primary, weight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                body,
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
