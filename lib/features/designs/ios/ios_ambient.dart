import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ios_glass.dart';

/// One blurred colour blob of the ambient: centre and radii as fractions of
/// the window, like `radial-gradient(45% 55% at 30% 18%, …)`.
typedef IosBlob = ({double x, double y, double rx, double ry, Color color});

/// Each page's hues, from its mockup's ambient layer (dark reference).
List<IosBlob> iosAmbientFor(String location) {
  IosBlob b(double x, double y, double rx, double ry, int argb) =>
      (x: x, y: y, rx: rx, ry: ry, color: Color(argb));
  if (location.startsWith('/archive')) {
    return [
      b(.30, .15, .45, .55, 0x99E66E46),
      b(.85, .20, .40, .50, 0x8C7846C8),
      b(.60, 1.0, .50, .60, 0x803C288C),
    ];
  }
  if (location.startsWith('/stats')) {
    return [
      b(.35, .20, .45, .55, 0x8C28BE96),
      b(.85, .15, .40, .50, 0x8C2878DC),
      b(.60, 1.0, .50, .60, 0x80145A6E),
    ];
  }
  if (location.startsWith('/transfer')) {
    return [
      b(.40, .30, .45, .55, 0x8C0A6CFF),
      b(.90, .15, .40, .50, 0x738C5AFF),
      b(.60, 1.0, .50, .60, 0x591EC8AA),
    ];
  }
  if (location.startsWith('/settings')) {
    return [
      b(.30, .20, .45, .55, 0x8C5E5CE6),
      b(.90, .25, .40, .50, 0x66FF508C),
      b(.55, 1.0, .50, .60, 0x730A6CFF),
    ];
  }
  return [
    b(.30, .18, .45, .55, 0xBF5096E6),
    b(.85, .10, .40, .50, 0xB32850A0),
    b(.70, 1.0, .50, .60, 0x991E3C78),
  ];
}

/// The light version of a hue: the same blob, pastel and denser (the mockup's
/// light Accueil turns rgba(80,150,230,.75) into rgba(150,200,255,.85)).
Color iosLightHue(Color c) => Color.lerp(
  c.withValues(alpha: 1),
  Colors.white,
  0.5,
)!.withValues(alpha: (c.a + 0.12).clamp(0.0, 1.0));

/// The coloured ambient behind the glass. Painted once per page (it never
/// moves), so it costs nothing while the page scrolls; the change of page
/// cross-fades the hues unless animations are reduced.
class IosAmbient extends StatelessWidget {
  const IosAmbient({super.key, required this.location});

  final String location;

  static String _page(String location) {
    for (final p in const ['/archive', '/stats', '/transfer', '/settings']) {
      if (location.startsWith(p)) return p;
    }
    return '/';
  }

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final page = _page(location);
    final blobs = [
      for (final blob in iosAmbientFor(page))
        (
          x: blob.x,
          y: blob.y,
          rx: blob.rx,
          ry: blob.ry,
          color: t.dark ? blob.color : iosLightHue(blob.color),
        ),
    ];
    return IgnorePointer(
      child: ColoredBox(
        color: t.base,
        child: AnimatedSwitcher(
          duration: iosMotion(context, 600),
          child: RepaintBoundary(
            key: ValueKey('$page-${t.dark}'),
            child: CustomPaint(
              painter: _AmbientPainter(blobs),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.blobs);

  final List<IosBlob> blobs;

  @override
  void paint(Canvas canvas, Size size) {
    // The mockup's layer overflows the window by 80px before its blur.
    final area = (Offset.zero & size).inflate(80);
    for (final blob in blobs) {
      final centre = Offset(
        area.left + area.width * blob.x,
        area.top + area.height * blob.y,
      );
      final rx = area.width * blob.rx;
      final ry = area.height * blob.ry;
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.scale(rx, ry);
      // `transparent 70%`, widened a little to stand in for the 60px blur.
      canvas.drawCircle(
        Offset.zero,
        1.15,
        Paint()
          ..shader = RadialGradient(
            colors: [blob.color, blob.color.withValues(alpha: 0)],
            stops: const [0, 0.78],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1.15)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => !listEquals(old.blobs, blobs);
}
