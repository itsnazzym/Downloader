import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tapload/core/design_system/foundation/typography.dart';
import 'package:tapload/core/theme/app_colors.dart';

import '../shared/local_thumb.dart';

/// iOS « Liquid Glass » building blocks, measured on the iOS-*.dc.html
/// mockups. Glass is faked: a translucent gradient, a light edge and a top
/// highlight over the chrome's ambient, which is already soft, so no
/// BackdropFilter runs on Windows.

Duration iosMotion(BuildContext context, int ms) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: ms);

const Curve iosEase = Cubic(0.2, 0.8, 0.2, 1);

/// The switch knob's overshoot (`cubic-bezier(.3,1.4,.5,1)`).
const Curve iosSpring = Cubic(0.3, 1.4, 0.5, 1);

/// The mockup's `t` tokens: dark is the reference, light is the white
/// frosted glass on a pale ambient (iOS-Accueil-Clair). The blues follow the
/// accent setting.
class IosTokens {
  const IosTokens._({
    required this.dark,
    required this.base,
    required this.glassTop,
    required this.glassBottom,
    required this.edge,
    required this.highlight,
    required this.shadow,
    required this.pillTop,
    required this.pillBottom,
    required this.pillShadow,
    required this.text,
    required this.sub,
    required this.soft,
    required this.blue,
    required this.blueFill,
    required this.red,
    required this.redFill,
    required this.green,
    required this.hover,
    required this.track,
  });

  final bool dark;
  final Color base;
  final Color glassTop;
  final Color glassBottom;
  final Color edge;

  /// The 1px inner highlight along the top edge.
  final Color highlight;
  final List<BoxShadow> shadow;
  final Color pillTop;
  final Color pillBottom;
  final List<BoxShadow> pillShadow;
  final Color text;
  final Color sub;

  /// Secondary text on glass cards (#D5DAE5 on the dark mockups).
  final Color soft;
  final Color blue;
  final Color blueFill;
  final Color red;
  final Color redFill;
  final Color green;
  final Color hover;

  /// Progress and switch track.
  final Color track;

  static IosTokens of(BuildContext context) {
    final primary = AppColors.of(context).primary;
    if (Theme.of(context).brightness == Brightness.light) {
      return IosTokens._(
        dark: false,
        base: const Color(0xFFEEF3FA),
        glassTop: const Color(0xC7FFFFFF),
        glassBottom: const Color(0x75FFFFFF),
        edge: const Color(0xF2FFFFFF),
        highlight: Colors.white,
        shadow: const [
          BoxShadow(
            color: Color(0x241E325A),
            blurRadius: 50,
            offset: Offset(0, 18),
          ),
        ],
        pillTop: Colors.white,
        pillBottom: const Color(0xBFFFFFFF),
        pillShadow: const [
          BoxShadow(
            color: Color(0x1F1E325A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        text: const Color(0xFF0A0C10),
        sub: const Color(0xFF586070),
        soft: const Color(0xFF3A4252),
        blue: Color.lerp(primary, Colors.black, 0.12)!,
        blueFill: primary,
        red: const Color(0xFFC4261D),
        redFill: const Color(0xFFD12E24),
        green: const Color(0xFF1F9D55),
        hover: const Color(0x1F7F7F8C),
        track: const Color(0x1A0A0C10),
      );
    }
    return IosTokens._(
      dark: true,
      base: const Color(0xFF04060C),
      glassTop: const Color(0x26FFFFFF),
      glassBottom: const Color(0x0DFFFFFF),
      edge: const Color(0x2EFFFFFF),
      highlight: const Color(0x59FFFFFF),
      shadow: const [
        BoxShadow(
          color: Color(0x59000000),
          blurRadius: 50,
          offset: Offset(0, 18),
        ),
      ],
      pillTop: const Color(0x3DFFFFFF),
      pillBottom: const Color(0x1AFFFFFF),
      pillShadow: const [],
      text: const Color(0xFFF5F7FB),
      sub: const Color(0xFFA9B1C2),
      soft: const Color(0xFFD5DAE5),
      blue: Color.lerp(primary, Colors.white, 0.3)!,
      blueFill: primary,
      red: const Color(0xFFFF7A70),
      redFill: const Color(0xFFE5372C),
      green: const Color(0xFF5CF2B0),
      hover: const Color(0x247F7F8C),
      track: const Color(0x24FFFFFF),
    );
  }

  /// The primary capsule's gradient (`#3B92FF → #0050D0` for the default
  /// blue).
  LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.lerp(blueFill, Colors.white, 0.2)!,
      Color.lerp(blueFill, Colors.black, 0.2)!,
    ],
  );

  LinearGradient get pillGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [pillTop, pillBottom],
  );
}

TextStyle iosText(
  IosTokens t, {
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? spacing,
}) => AppTypography.body.copyWith(
  fontSize: size,
  fontWeight: weight,
  height: 1.3,
  letterSpacing: spacing,
  color: color ?? t.text,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// `h1`: 38/900, -0.035em.
class IosTitle extends StatelessWidget {
  const IosTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: iosText(
      IosTokens.of(context),
      size: 38,
      weight: FontWeight.w900,
      spacing: -1.33,
    ).copyWith(height: 1.1),
  );
}

/// `h2`: 22/800, -0.02em.
class IosHeading extends StatelessWidget {
  const IosHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: iosText(
      IosTokens.of(context),
      size: 22,
      weight: FontWeight.w800,
      spacing: -0.44,
    ),
  );
}

/// `.lg`: a glass panel. [pill] draws the brighter selected capsule.
class IosGlass extends StatelessWidget {
  const IosGlass({
    super.key,
    required this.child,
    this.radius = 26,
    this.padding = EdgeInsets.zero,
    this.pill = false,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool pill;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final shadows = pill ? t.pillShadow : (shadow ? t.shadow : null);
    final Widget box = CustomPaint(
      painter: IosGlassPainter(
        top: pill ? t.pillTop : t.glassTop,
        bottom: pill ? t.pillBottom : t.glassBottom,
        edge: pill ? Colors.transparent : t.edge,
        highlight: t.highlight,
        radius: radius,
        shadows: shadows ?? const [],
      ),
      child: Padding(padding: padding, child: child),
    );
    return box;
  }
}

/// The glass fill, its 1px edge and the top inner highlight, in one pass.
class IosGlassPainter extends CustomPainter {
  IosGlassPainter({
    required this.top,
    required this.bottom,
    required this.edge,
    required this.highlight,
    required this.radius,
    this.shadows = const [],
  });

  /// Drawn outside the panel only, like CSS: a translucent glass must not
  /// show its own shadow through itself.
  final List<BoxShadow> shadows;
  final Color top;
  final Color bottom;
  final Color edge;
  final Color highlight;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = Radius.circular(radius.clamp(0, size.shortestSide / 2));
    final rrect = RRect.fromRectAndRadius(rect, r);
    if (shadows.isNotEmpty) {
      canvas.save();
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect.inflate(200))
          ..addRRect(rrect),
      );
      for (final s in shadows) {
        canvas.drawRRect(
          rrect.shift(s.offset).inflate(s.spreadRadius),
          s.toPaint(),
        );
      }
      canvas.restore();
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );
    // The edge, brightest along the top like `inset 0 1px 0`.
    final edgeTop = Color.lerp(edge, highlight, 0.85)!;
    final split = size.height <= 0 ? 0.0 : (18 / size.height).clamp(0.0, 0.5);
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [edgeTop, edge, edge],
          stops: [0, split, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(IosGlassPainter old) =>
      old.top != top ||
      old.bottom != bottom ||
      old.edge != edge ||
      old.highlight != highlight ||
      old.radius != radius ||
      !listEquals(old.shadows, shadows);
}

/// Hover, focus and tap around anything; [builder] reads the hover state.
class IosTap extends StatefulWidget {
  const IosTap({
    super.key,
    required this.builder,
    this.onTap,
    this.onDoubleTap,
    this.radius = 999,
    this.tooltip,
    this.semanticLabel,
    this.selected,
  });

  final Widget Function(BuildContext context, bool hover) builder;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final double radius;
  final String? tooltip;
  final String? semanticLabel;
  final bool? selected;

  @override
  State<IosTap> createState() => _IosTapState();
}

class _IosTapState extends State<IosTap> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final radius = BorderRadius.circular(widget.radius);
    final enabled = widget.onTap != null || widget.onDoubleTap != null;
    Widget body = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onHover: (v) => setState(() => _hover = v),
        onFocusChange: (v) => setState(() => _focus = v),
        borderRadius: radius,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: t.text.withValues(alpha: 0.06),
        child: widget.builder(context, _hover && enabled),
      ),
    );
    if (_focus) {
      body = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: t.blue,
            width: 2,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        child: body,
      );
    }
    body = Semantics(
      button: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: body,
    );
    final tip = widget.tooltip;
    return tip == null ? body : Tooltip(message: tip, child: body);
  }
}

enum IosButtonKind { glass, primary, white, pill, danger }

/// A capsule button: glass, blue primary, the white « Tout télécharger »,
/// the brighter pill (« Copier », « Changer ») or red.
class IosButton extends StatelessWidget {
  const IosButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.kind = IosButtonKind.glass,
    this.height = 38,
    this.fontSize = 14,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final IosButtonKind kind;
  final double height;
  final double fontSize;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final disabled = onTap == null;
    final fg = switch (kind) {
      IosButtonKind.primary => Colors.white,
      IosButtonKind.white => const Color(0xFF0A0C10),
      IosButtonKind.danger => Colors.white,
      _ => t.text,
    };
    return IosTap(
      onTap: onTap,
      radius: height / 2,
      builder: (context, hover) {
        final content = Padding(
          padding: EdgeInsets.symmetric(horizontal: height * 0.42),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 3, color: fg),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: iosText(
                    t,
                    size: fontSize,
                    weight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        );
        final Widget box = switch (kind) {
          IosButtonKind.glass || IosButtonKind.pill => IosGlass(
            radius: height / 2,
            pill: kind == IosButtonKind.pill,
            shadow: false,
            child: content,
          ),
          IosButtonKind.primary => DecoratedBox(
            decoration: BoxDecoration(
              gradient: t.primaryGradient,
              borderRadius: BorderRadius.circular(height / 2),
              boxShadow: [
                BoxShadow(
                  color: t.blueFill.withValues(alpha: 0.45),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: content,
          ),
          IosButtonKind.white => DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(height / 2),
            ),
            child: content,
          ),
          IosButtonKind.danger => DecoratedBox(
            decoration: BoxDecoration(
              color: t.redFill,
              borderRadius: BorderRadius.circular(height / 2),
            ),
            child: content,
          ),
        };
        return AnimatedOpacity(
          duration: iosMotion(context, 160),
          opacity: disabled ? 0.45 : 1,
          child: SizedBox(
            height: height,
            child: hover
                ? ColorFiltered(colorFilter: _brighten, child: box)
                : box,
          ),
        );
      },
    );
  }
}

/// `filter: brightness(1.12)` on hover.
const _brighten = ColorFilter.matrix([
  1.12, 0, 0, 0, 0, //
  0, 1.12, 0, 0, 0, //
  0, 0, 1.12, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// A round glass button (sync, more, pause), or the blue one (new).
class IosRoundButton extends StatelessWidget {
  const IosRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 44,
    this.primary = false,
    this.onImage = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final bool primary;

  /// Over a picture (the hero): a whiter glass, always white icons.
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final iconColor = primary || onImage ? Colors.white : t.text;
    return IosTap(
      onTap: onTap,
      tooltip: tooltip,
      semanticLabel: tooltip,
      builder: (context, hover) {
        final glyph = Icon(icon, size: size * 0.42, color: iconColor);
        final Widget box;
        if (primary) {
          box = DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: t.primaryGradient,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: t.blueFill.withValues(alpha: 0.45),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(child: glyph),
          );
        } else if (onImage) {
          box = CustomPaint(
            painter: IosGlassPainter(
              top: const Color(0x52FFFFFF),
              bottom: const Color(0x1FFFFFFF),
              edge: const Color(0x59FFFFFF),
              highlight: const Color(0x99FFFFFF),
              radius: size / 2,
            ),
            child: Center(child: glyph),
          );
        } else {
          box = IosGlass(
            radius: size / 2,
            child: Center(child: glyph),
          );
        }
        return AnimatedOpacity(
          duration: iosMotion(context, 160),
          opacity: onTap == null ? 0.45 : 1,
          child: SizedBox.square(
            dimension: size,
            child: hover
                ? ColorFiltered(colorFilter: _brighten, child: box)
                : box,
          ),
        );
      },
    );
  }
}

/// The capsule segmented control: a glass track, the selected tab as a pill.
class IosSegmented<T> extends StatelessWidget {
  const IosSegmented({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
    this.height = 30,
    this.fontSize = 13,
  });

  final T value;
  final List<(T, String)> segments;
  final ValueChanged<T> onChanged;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    return IosGlass(
      radius: (height + 8) / 2,
      shadow: false,
      padding: const EdgeInsets.all(3.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, label) in segments)
            IosTap(
              onTap: () => onChanged(v),
              radius: height / 2,
              selected: v == value,
              builder: (context, hover) {
                final on = v == value;
                return AnimatedContainer(
                  duration: iosMotion(context, 220),
                  curve: iosEase,
                  height: height,
                  padding: EdgeInsets.symmetric(horizontal: height * 0.5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height / 2),
                    gradient: on ? t.pillGradient : null,
                    color: on ? null : (hover ? t.hover : Colors.transparent),
                    boxShadow: on ? t.pillShadow : null,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    style: iosText(
                      t,
                      size: fontSize,
                      weight: FontWeight.w600,
                      color: on ? t.text : t.sub,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// The springy switch: 58×32, green when on, the knob overshooting a little.
class IosSwitch extends StatelessWidget {
  const IosSwitch({
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
    final t = IosTokens.of(context);
    final on = value;
    return Semantics(
      toggled: on,
      label: label,
      excludeSemantics: true,
      child: IosTap(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        builder: (context, hover) => Opacity(
          opacity: onChanged == null ? 0.45 : 1,
          child: SizedBox(
            width: 58,
            height: 32,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: iosMotion(context, 260),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: on ? null : t.track,
                      gradient: on
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF3FDA95), Color(0xFF1F9D55)],
                            )
                          : null,
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: iosMotion(context, 300),
                  curve: iosSpring,
                  top: 3,
                  left: on ? 29 : 3,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, Color(0xFFE4E8F0)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x59000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded progress bar; [glow] for the white bar over the hero.
class IosBar extends StatelessWidget {
  const IosBar({
    super.key,
    required this.value,
    this.height = 5,
    this.color,
    this.track,
    this.glow = false,
  });

  final double value;
  final double height;
  final Color? color;
  final Color? track;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final fill = color ?? t.blueFill;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: track ?? t.track,
        borderRadius: BorderRadius.circular(height),
      ),
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(height),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: fill.withValues(alpha: 0.7),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

/// A tinted circle with a white glyph (settings rows and sections).
class IosTintDot extends StatelessWidget {
  const IosTintDot({
    super.key,
    required this.colors,
    this.icon,
    this.size = 34,
  });

  final (Color, Color) colors;
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors.$1, colors.$2],
      ),
      border: Border(
        top: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
      ),
    ),
    child: icon == null
        ? null
        : Icon(icon, size: size * 0.5, color: Colors.white),
  );
}

/// The mockup's row tints (`linear-gradient(180deg, a, b)`).
abstract final class IosTints {
  static const green = (Color(0xFF5CE0A0), Color(0xFF128A5A));
  static const pink = (Color(0xFFFF8DB3), Color(0xFFD6336C));
  static const orange = (Color(0xFFFFB25B), Color(0xFFD9670F));
  static const blue = (Color(0xFF6BB6FF), Color(0xFF0A6CFF));
  static const violet = (Color(0xFFA59BFF), Color(0xFF5E5CE6));
  static const gray = (Color(0xFFA1A1AA), Color(0xFF5C5C66));
  static const graphite = (Color(0xFF8E8E99), Color(0xFF3A3A42));
  static const dark = (Color(0xFF6C6C78), Color(0xFF26262E));
}

/// The soft stand-in for a missing picture: one of the mockup's tile
/// gradients, picked from [seed].
class IosArt extends StatelessWidget {
  const IosArt({super.key, required this.seed, this.icon});

  final int seed;
  final IconData? icon;

  static const _pairs = [
    (Color(0xFFF28C5B), Color(0xFF8E2F3F)),
    (Color(0xFF62C3D9), Color(0xFF1E4F7A)),
    (Color(0xFFF2C85B), Color(0xFF9A5A1A)),
    (Color(0xFF9B8CF2), Color(0xFF3A2F7A)),
    (Color(0xFF6BD99B), Color(0xFF1E6A4F)),
    (Color(0xFFF27BA6), Color(0xFF7A1F4A)),
    (Color(0xFF74A8DA), Color(0xFF22497C)),
  ];

  @override
  Widget build(BuildContext context) {
    final (a, b) = _pairs[seed.abs() % _pairs.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.4, -1),
          end: const Alignment(0.4, 1),
          colors: [a, b],
        ),
      ),
      child: icon == null
          ? null
          : Center(
              child: Icon(
                icon,
                size: 30,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
    );
  }
}

/// A download's picture filling its box: the remote thumbnail, else the
/// preview taken from the file, else [IosArt].
class IosThumb extends StatelessWidget {
  const IosThumb({
    super.key,
    required this.url,
    required this.filePath,
    required this.seed,
    this.decodeWidth = 480,
    this.icon,
  });

  final String? url;
  final String? filePath;
  final int seed;
  final int decodeWidth;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final art = IosArt(seed: seed, icon: icon);
    final local = LocalVideoThumb(
      filePath: filePath,
      placeholder: art,
      cacheWidth: decodeWidth,
    );
    final u = url;
    if (u == null || u.isEmpty) return local;
    Widget fallback(BuildContext c, Object e, StackTrace? s) => local;
    if (u.startsWith('assets/')) {
      return Image.asset(u, fit: BoxFit.cover, errorBuilder: fallback);
    }
    if (u.startsWith('http://') || u.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: u,
        fit: BoxFit.cover,
        memCacheWidth: decodeWidth,
        placeholder: (c, _) => art,
        errorWidget: (c, _, _) => local,
        fadeInDuration: const Duration(milliseconds: 160),
      );
    }
    var path = u;
    try {
      path = Uri.decodeFull(u);
    } catch (_) {}
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: decodeWidth,
      errorBuilder: fallback,
    );
  }
}

/// A glass « illustration » for the states: concentric frosted rings and a
/// glyph in a blue drop, drawn in code (no rendered asset for iOS).
class IosStateArt extends StatelessWidget {
  const IosStateArt({
    super.key,
    required this.icon,
    this.size = 150,
    this.danger = false,
  });

  final IconData icon;
  final double size;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final core = danger ? t.redFill : t.blueFill;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IosGlass(
            radius: size / 2,
            child: SizedBox.square(dimension: size),
          ),
          IosGlass(
            radius: size * 0.34,
            shadow: false,
            child: SizedBox.square(dimension: size * 0.68),
          ),
          Container(
            width: size * 0.4,
            height: size * 0.4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(core, Colors.white, 0.25)!,
                  Color.lerp(core, Colors.black, 0.2)!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: core.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(icon, size: size * 0.18, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// A frosted placeholder block that breathes while the library loads (still
/// when animations are reduced).
class IosBone extends StatelessWidget {
  const IosBone({
    super.key,
    required this.pulse,
    this.radius = 22,
    this.height,
    this.width,
  });

  final Animation<double> pulse;
  final double radius;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    return FadeTransition(
      opacity: pulse.drive(Tween(begin: 0.45, end: 1.0)),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: t.glassTop,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: t.edge.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}
