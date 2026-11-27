import 'package:flutter/material.dart';
import 'package:modern_downloader/core/ui/mobile/oled/oled_glyph.dart'
    show kOledGlyph, kOledGlyphCols, kOledGlyphRows;

import 'oled_theme.dart';

/// OLED's building blocks, measured on the Main / OLED-*.dc.html mockups.

enum OledPillKind {
  /// `.o-ghost`: #333 outline, soft text; lights up white on hover.
  ghost,

  /// `.o-btn`: white outline that fills white on hover.
  outline,

  /// Ion outline and text (« Télécharger la sélection »).
  ion,

  /// Ion fill, black text (« Envoyer »).
  solid,
}

/// The mockups' round pill button.
class OledPill extends StatefulWidget {
  const OledPill({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = OledPillKind.ghost,
    this.height = 44,
    this.padding = 20,
    this.fontSize = 14,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final OledPillKind kind;
  final double height;
  final double padding;
  final double fontSize;
  final IconData? icon;

  @override
  State<OledPill> createState() => _OledPillState();
}

class _OledPillState extends State<OledPill> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final lit = enabled && (_hover || _focus);
    final (Color fill, Color border, Color fg) = switch (widget.kind) {
      OledPillKind.ghost => (
        OledInk.bg,
        lit ? OledInk.ink : OledInk.ghost,
        lit ? OledInk.ink : OledInk.soft,
      ),
      OledPillKind.outline => (
        lit ? OledInk.ink : OledInk.bg,
        OledInk.ink,
        lit ? OledInk.bg : OledInk.ink,
      ),
      OledPillKind.ion => (
        lit ? OledInk.ion.withValues(alpha: 0.1) : OledInk.bg,
        OledInk.ion,
        OledInk.ion,
      ),
      OledPillKind.solid => (
        lit ? Color.lerp(OledInk.ion, OledInk.bright, 0.25)! : OledInk.ion,
        OledInk.ion,
        OledInk.bg,
      ),
    };
    final weight = widget.kind == OledPillKind.ghost
        ? FontWeight.w500
        : FontWeight.w600;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Semantics(
        button: true,
        enabled: enabled,
        child: FocusableActionDetector(
          enabled: enabled,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onShowHoverHighlight: (v) => setState(() => _hover = v),
          onShowFocusHighlight: (v) => setState(() => _focus = v),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) => widget.onTap?.call(),
            ),
          },
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: oledMotion(context, 160),
              height: widget.height,
              padding: EdgeInsets.symmetric(horizontal: widget.padding),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: widget.fontSize + 2, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    maxLines: 1,
                    style: oledText(
                      size: widget.fontSize,
                      weight: weight,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A text link / tab: white when [selected] or hovered, grey otherwise.
class OledTextLink extends StatefulWidget {
  const OledTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.size = 14,
    this.trailing,
    this.selectedWeight = FontWeight.w600,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final double size;

  /// A count after the label ("Échecs 52").
  final InlineSpan? trailing;
  final FontWeight selectedWeight;

  @override
  State<OledTextLink> createState() => _OledTextLinkState();
}

class _OledTextLinkState extends State<OledTextLink> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.selected;
    final color = on || _hover || _focus ? OledInk.ink : OledInk.mute;
    return Semantics(
      button: true,
      selected: on,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onTap?.call(),
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text.rich(
              TextSpan(
                text: widget.label,
                children: [
                  if (widget.trailing != null) ...[
                    const TextSpan(text: ' '),
                    widget.trailing!,
                  ],
                ],
              ),
              maxLines: 1,
              style:
                  oledText(
                    size: widget.size,
                    weight: on ? widget.selectedWeight : FontWeight.w500,
                    color: color,
                  ).copyWith(
                    decoration: _focus ? TextDecoration.underline : null,
                    decorationColor: OledInk.ion,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The lit dot: 8px of ion with its glow. [breathe] makes it pulse slowly
/// (the logo's dot), still when animations are reduced.
class OledLiveDot extends StatefulWidget {
  const OledLiveDot({
    super.key,
    this.size = 8,
    this.breathe = false,
    this.color = OledInk.ion,
  });

  final double size;
  final bool breathe;
  final Color color;

  @override
  State<OledLiveDot> createState() => _OledLiveDotState();
}

class _OledLiveDotState extends State<OledLiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      value: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (widget.breathe && !still) {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    } else {
      _breath
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.color,
            blurRadius: widget.size * 1.5,
            spreadRadius: -widget.size / 4,
          ),
        ],
      ),
    );
    // `breathe`: opacity 1 -> .35 -> 1 over 2.4 s.
    return FadeTransition(
      opacity: _breath.drive(Tween(begin: 0.35, end: 1.0)),
      child: dot,
    );
  }
}

/// The hero progress: 40 rounded dots, the lit ones in ion, the leading one
/// glowing.
class OledDots extends StatelessWidget {
  const OledDots({super.key, required this.value, this.count = 40});

  final double value;
  final int count;

  @override
  Widget build(BuildContext context) {
    final lit = (value.clamp(0.0, 1.0) * count).round();
    return Semantics(
      label: '${(value * 100).clamp(0, 100).round()} %',
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: i < lit ? OledInk.ion : OledInk.unlit,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: i == lit - 1
                      ? const [BoxShadow(color: OledInk.ion, blurRadius: 10)]
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A thin track with its fill (sources, files to send).
class OledBar extends StatelessWidget {
  const OledBar({
    super.key,
    required this.value,
    this.color = OledInk.ion,
    this.height = 4,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: OledInk.track),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// The settings switch: a black outlined track, the knob lit in ion when on.
class OledSwitch extends StatelessWidget {
  const OledSwitch({
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
    final on = value;
    return Semantics(
      toggled: on,
      label: label,
      enabled: onChanged != null,
      child: FocusableActionDetector(
        enabled: onChanged != null,
        mouseCursor: SystemMouseCursors.click,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => onChanged?.call(!on),
          ),
        },
        child: GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(!on),
          child: AnimatedContainer(
            duration: oledMotion(context, 180),
            width: 48,
            height: 28,
            decoration: BoxDecoration(
              color: OledInk.bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: on ? OledInk.ion : OledInk.ghost),
            ),
            child: AnimatedAlign(
              duration: oledMotion(context, 180),
              curve: Curves.easeOutCubic,
              alignment: on
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: on ? OledInk.ion : OledInk.knobOff,
                    shape: BoxShape.circle,
                    boxShadow: on
                        ? const [BoxShadow(color: OledInk.ion, blurRadius: 10)]
                        : null,
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

/// The square check of an archive card.
class OledCheck extends StatelessWidget {
  const OledCheck({super.key, required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: oledMotion(context, 140),
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      color: checked ? OledInk.ion : Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(
        color: checked ? OledInk.ion : const Color(0xFF3A3A3A),
      ),
    ),
    child: checked
        ? const Icon(Icons.check_rounded, size: 13, color: OledInk.bg)
        : null,
  );
}

/// A bordered block that brightens its hairline on hover (`.o-row`,
/// `.o-vid`): the row's own tap and focus stay with [child].
class OledHoverBox extends StatefulWidget {
  const OledHoverBox({
    super.key,
    required this.child,
    this.selected = false,
    this.radius = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.hoverColor = OledInk.lineHover,
  });

  final Widget child;
  final bool selected;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color hoverColor;

  @override
  State<OledHoverBox> createState() => _OledHoverBoxState();
}

class _OledHoverBoxState extends State<OledHoverBox> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: oledMotion(context, 140),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: OledInk.bg,
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(
            color: widget.selected
                ? OledInk.ion
                : (_hover ? widget.hoverColor : OledInk.line),
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

/// A big Doto figure over its small grey word (archive and stats).
class OledFigure extends StatelessWidget {
  const OledFigure({
    super.key,
    required this.value,
    required this.label,
    this.size = 88,
    this.lit = false,
    this.unit,
  });

  final String value;
  final String label;
  final double size;
  final bool lit;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final color = lit ? OledInk.ion : OledInk.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            text: value,
            children: [
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: oledDoto(size * 0.47, color: color),
                ),
            ],
          ),
          style: oledDoto(
            size,
            color: color,
            height: 0.85,
            glow: lit ? oledGlow(22) : null,
          ),
        ),
        SizedBox(height: size > 60 ? 10 : 4),
        Text(label, style: oledText(size: 13, color: OledInk.mute)),
      ],
    );
  }
}

/// The logo's dot-matrix glyph, drawn dim for the empty states: an arrow
/// dropping into a tray, its one live dot in ion.
class OledDotGlyph extends StatelessWidget {
  const OledDotGlyph({super.key, this.width = 84});

  final double width;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size(width, width * kOledGlyphRows / kOledGlyphCols),
      painter: const _DotGlyphPainter(),
    ),
  );
}

class _DotGlyphPainter extends CustomPainter {
  const _DotGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final pitch = size.width / kOledGlyphCols;
    final paint = Paint()..isAntiAlias = true;
    for (var r = 0; r < kOledGlyphRows; r++) {
      for (var c = 0; c < kOledGlyphCols; c++) {
        final cell = kOledGlyph[r][c];
        final centre = Offset((c + 0.5) * pitch, (r + 0.5) * pitch);
        if (cell == '*') {
          paint.color = OledInk.ionGlow;
          canvas.drawCircle(centre, pitch * 0.7, paint);
        }
        paint.color = switch (cell) {
          '#' => OledInk.ink.withValues(alpha: 0.32),
          '*' => OledInk.ion,
          _ => OledInk.unlit,
        };
        canvas.drawCircle(centre, pitch * 0.33, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGlyphPainter oldDelegate) => false;
}

void oledNotice(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
}
