import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';

/// Porcelaine's building blocks, measured on Espace.dc.html and the
/// Porcelaine-*.dc.html mockups.

/// The mockups' muted thumbnail tones, used when an item has no image.
const _tones = [
  Color(0xFFC9D3CC),
  Color(0xFFD8CFBD),
  Color(0xFFCDCAD8),
  Color(0xFFD5CEC4),
  Color(0xFFD6CBD2),
  Color(0xFFCDD2C2),
];

/// `.th`: a flat thumbnail with a hairline; a stone tone picked from [seed]
/// when there is no image.
class PThumb extends StatelessWidget {
  const PThumb({
    super.key,
    required this.url,
    required this.seed,
    this.width,
    required this.height,
    this.radius = 12,
  });

  final String? url;
  final String seed;
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tone = _tones[seed.hashCode.abs() % _tones.length];
    final u = url;
    Widget image = ColoredBox(color: tone);
    Widget fallback(BuildContext c, Object e, StackTrace? s) =>
        ColoredBox(color: tone);
    final decode = ((width ?? 240) * 2.5).round();
    if (u != null && u.isNotEmpty) {
      if (u.startsWith('assets/')) {
        image = Image.asset(u, fit: BoxFit.cover, errorBuilder: fallback);
      } else if (u.startsWith('http://') || u.startsWith('https://')) {
        image = CachedNetworkImage(
          imageUrl: u,
          fit: BoxFit.cover,
          memCacheWidth: decode,
          placeholder: (c, _) => ColoredBox(color: tone),
          errorWidget: (c, _, _) => ColoredBox(color: tone),
          fadeInDuration: const Duration(milliseconds: 160),
        );
      } else {
        var path = u;
        try {
          path = Uri.decodeFull(u);
        } catch (_) {}
        image = Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: decode,
          errorBuilder: fallback,
        );
      }
    }
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: colors.textPrimary.withValues(alpha: 0.06),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Duration pMotion(BuildContext context, int ms) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: ms);

const Curve pEase = Cubic(0.2, 0.8, 0.2, 1);

/// The mockups' head-icon tints. Porcelaine is light only, so these sit on
/// white like the mockup's `color-mix(c 12%, #fff)`.
const pGreen = Color(0xFF1E8E4E);
const pPink = Color(0xFFB4235A);
const pSlate = Color(0xFF5B6170);

/// A real face of [family] at [weight]. `AppTypography` styles are built at
/// the regular weight and re-weighted with copyWith, which Flutter fakes by
/// smearing the regular face; the mockups use the true 500–800 faces.
TextStyle _face(String family, FontWeight weight) {
  try {
    return GoogleFonts.getFont(family, fontWeight: weight);
  } catch (_) {
    return GoogleFonts.inter(fontWeight: weight);
  }
}

/// `.disp`: Plus Jakarta Sans 800, -0.045em.
TextStyle pDisp(double size, {Color? color}) =>
    _face(DesignSpec.porcelaine.displayFont, FontWeight.w800).copyWith(
      fontSize: size,
      height: 1.0,
      letterSpacing: -0.045 * size,
      color: color,
    );

TextStyle pBody(
  AppColors colors, {
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color? color,
}) => _face(
  DesignSpec.porcelaine.uiFont,
  weight,
).copyWith(fontSize: size, color: color ?? colors.textPrimary, height: 1.45);

TextStyle pMono(AppColors colors, {double size = 12, Color? color}) =>
    _face(DesignSpec.porcelaine.monoFont, FontWeight.w400).copyWith(
      fontSize: size,
      color: color ?? colors.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// The frosted card's fill (white at 78 % over the stone background).
Color pCardFill(AppColors colors) =>
    Color.alphaBlend(colors.surface.withValues(alpha: 0.78), colors.background);

/// The bar track (#E7E6E2 on the mockup).
Color pTrack(AppColors colors) => Color.alphaBlend(
  colors.textPrimary.withValues(alpha: 0.07),
  colors.surface,
);

List<BoxShadow> pCardShadow(AppColors colors, {bool up = false}) => [
  BoxShadow(
    color: colors.textPrimary.withValues(alpha: up ? 0.08 : 0.06),
    spreadRadius: 1,
  ),
  BoxShadow(
    color: colors.textPrimary.withValues(alpha: 0.06),
    blurRadius: up ? 4 : 2,
    offset: Offset(0, up ? 2 : 1),
  ),
  BoxShadow(
    color: colors.textPrimary.withValues(alpha: up ? 0.26 : 0.18),
    blurRadius: up ? 48 : 32,
    spreadRadius: up ? -16 : -12,
    offset: Offset(0, up ? 24 : 12),
  ),
];

/// `.wg`: the frosted 28px card; lifts 3px on hover.
class PCard extends StatefulWidget {
  const PCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.lift = true,
    this.radius = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool lift;
  final double radius;

  @override
  State<PCard> createState() => _PCardState();
}

class _PCardState extends State<PCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final up = widget.lift && _hover;
    return MouseRegion(
      onEnter: widget.lift ? (_) => setState(() => _hover = true) : null,
      onExit: widget.lift ? (_) => setState(() => _hover = false) : null,
      child: AnimatedContainer(
        duration: pMotion(context, 300),
        curve: pEase,
        transform: Matrix4.translationValues(0, up ? -3 : 0, 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: pCardFill(colors),
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: pCardShadow(colors, up: up),
        ),
        child: widget.child,
      ),
    );
  }
}

/// `.head`: a tinted 28px icon tile and a 13px semibold label.
class PHead extends StatelessWidget {
  Widget _label(AppColors colors) => Text(
    label,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: pBody(colors, size: 13, weight: FontWeight.w600),
  );

  const PHead({
    super.key,
    required this.icon,
    required this.label,
    this.tint,
    this.trailing,
    this.bottom = 14,
    this.end = 0,
  });

  final IconData icon;
  final String label;
  final Color? tint;
  final Widget? trailing;
  final double bottom;

  /// Room kept on the right (the widgets' « … » button).
  final double end;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final c = tint ?? colors.textPrimary;
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: bottom, end: end),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Color.alphaBlend(c.withValues(alpha: 0.12), Colors.white),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: c),
          ),
          const SizedBox(width: 10),
          // With a trailing part the label keeps its natural width, so an
          // Expanded trailing gets all the rest.
          if (trailing == null)
            Flexible(child: _label(colors))
          else ...[
            _label(colors),
            trailing!,
          ],
        ],
      ),
    );
  }
}

enum PBtnKind { accent, line, ghost, dark, danger }

/// `.btn`: 38px pill, accent / line / ghost; presses down 1px.
class PBtn extends StatefulWidget {
  const PBtn({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = PBtnKind.line,
    this.icon,
    this.height = 38,
    this.fontSize = 13.5,
    this.padding = 16,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onTap;
  final PBtnKind kind;
  final IconData? icon;
  final double height;
  final double fontSize;
  final double padding;
  final String? tooltip;

  @override
  State<PBtn> createState() => _PBtnState();
}

class _PBtnState extends State<PBtn> {
  bool _hover = false;
  bool _down = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final enabled = widget.onTap != null;
    final (Color bg, Color fg) = switch (widget.kind) {
      PBtnKind.accent => (
        _hover
            ? Color.lerp(colors.primary, Colors.white, 0.08)!
            : colors.primary,
        colors.onPrimary,
      ),
      PBtnKind.dark => (colors.textPrimary, colors.background),
      PBtnKind.danger => (
        _hover ? Color.lerp(colors.error, Colors.white, 0.08)! : colors.error,
        Colors.white,
      ),
      PBtnKind.line => (
        _hover ? const Color(0xFFF7F6F3) : colors.surface,
        colors.textPrimary,
      ),
      PBtnKind.ghost => (
        _hover
            ? colors.textPrimary.withValues(alpha: 0.06)
            : colors.textPrimary.withValues(alpha: 0),
        colors.textPrimary,
      ),
    };
    final shadows = switch (widget.kind) {
      PBtnKind.accent || PBtnKind.danger => [
        BoxShadow(
          color: colors.textPrimary.withValues(alpha: 0.2),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color:
              (widget.kind == PBtnKind.danger ? colors.error : colors.primary)
                  .withValues(alpha: 0.18),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
      PBtnKind.line => [
        BoxShadow(
          color: colors.textPrimary.withValues(alpha: 0.1),
          spreadRadius: 1,
        ),
        BoxShadow(
          color: colors.textPrimary.withValues(alpha: 0.06),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
      _ => const <BoxShadow>[],
    };
    Widget button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: AnimatedScale(
          scale: _down ? 0.98 : 1,
          duration: pMotion(context, 160),
          child: AnimatedContainer(
            duration: pMotion(context, 160),
            curve: pEase,
            height: widget.height,
            transform: Matrix4.translationValues(0, _down ? 1 : 0, 0),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              boxShadow: shadows,
              border: _focus
                  ? Border.all(color: colors.primary, width: 2)
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: (_) => setState(() => _down = true),
                onTapUp: (_) => setState(() => _down = false),
                onTapCancel: () => setState(() => _down = false),
                onFocusChange: (v) => setState(() => _focus = v),
                borderRadius: BorderRadius.circular(999),
                splashColor: Colors.transparent,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.padding),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 15, color: fg),
                        if (widget.label.isNotEmpty) const SizedBox(width: 8),
                      ],
                      if (widget.label.isNotEmpty)
                        Text(
                          widget.label,
                          maxLines: 1,
                          style: pBody(
                            colors,
                            size: widget.fontSize,
                            weight: FontWeight.w600,
                            color: fg,
                          ).copyWith(height: 1.2),
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
    final tip = widget.tooltip;
    if (tip != null) button = Tooltip(message: tip, child: button);
    return button;
  }
}

/// `.pill` inside a `.seg`: a segmented choice.
class PSegmented<T> extends StatelessWidget {
  const PSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, label) in options) ...[
            if (v != options.first.$1) const SizedBox(width: 4),
            PPill(
              label: label,
              selected: v == value,
              transparent: true,
              onTap: () => onChanged(v),
            ),
          ],
        ],
      ),
    );
  }
}

/// `.pill`: 30px, radius 10, ink when on.
class PPill extends StatefulWidget {
  const PPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.transparent = false,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool transparent;
  final String? trailing;

  @override
  State<PPill> createState() => _PPillState();
}

class _PPillState extends State<PPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final on = widget.selected;
    final fg = on
        ? colors.background
        : (_hover ? colors.textPrimary : colors.textSecondary);
    return Semantics(
      button: true,
      selected: on,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: pMotion(context, 150),
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: on
                    ? colors.textPrimary
                    : (widget.transparent
                          ? colors.inputBackground.withValues(alpha: 0)
                          : colors.inputBackground),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: pBody(
                      colors,
                      size: 12.5,
                      weight: FontWeight.w500,
                      color: fg,
                    ).copyWith(height: 1.2),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      widget.trailing!,
                      style: pMono(colors, size: 11.5, color: fg),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.bar`: a static 8px track with a fill.
class PBar extends StatelessWidget {
  const PBar({super.key, required this.value, this.height = 8, this.color});

  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: ColoredBox(
          color: pTrack(colors),
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: value.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color ?? colors.primary,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Page title (`h1.disp` 40px) with an optional eyebrow and subtitle.
class PPageTitle extends StatelessWidget {
  const PPageTitle({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            style: pBody(
              colors,
              size: 13,
              weight: FontWeight.w600,
              color: colors.textDisabled,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: pDisp(40, color: colors.textPrimary).copyWith(height: 1.05),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: pBody(colors, color: colors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// Centres the page content at the mockup's 1220px and pads it 32px.
class PPage extends StatelessWidget {
  const PPage({super.key, required this.children, this.top = 0});

  final List<Widget> children;
  final double top;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(32, top, 32, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1220),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// A switch drawn like the mockup's (44×26, ink off-track, accent on).
class PSwitch extends StatelessWidget {
  const PSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      toggled: value,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged!(!value),
          borderRadius: BorderRadius.circular(999),
          focusColor: colors.primary.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: AnimatedContainer(
              duration: pMotion(context, 200),
              width: 44,
              height: 26,
              padding: const EdgeInsets.all(3),
              alignment: value
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              decoration: BoxDecoration(
                color: value ? colors.primary : const Color(0xFF8E9097),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
