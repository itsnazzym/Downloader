import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A small drawn scene of each design (mockup Mini.dc.html), on a fixed
/// 360 x 225 canvas: scale it with a [FittedBox]. Decorative only.
class DesignMiniature extends StatelessWidget {
  const DesignMiniature(this.id, {super.key});

  final String id;

  static const Size size = Size(360, 225);

  @override
  Widget build(BuildContext context) {
    // A picture of a design, not part of the page: never mirrored in RTL.
    return ExcludeSemantics(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox.fromSize(
          size: size,
          child: ClipRect(
            child: switch (id) {
              'porcelaine' => const _Porcelaine(),
              'pastille' => const _Pastille(),
              'studio' => const _Studio(),
              'terminal' => const _Terminal(),
              'nocturne' => const _Nocturne(),
              'oled' => const _Oled(),
              'ios' => const _Ios(),
              _ => const _Signal(),
            },
          ),
        ),
      ),
    );
  }
}

// Inter stops at w700 here: the test harness preloads no heavier face.
TextStyle _font(
  String family,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w700,
  double? height,
  double? spacing,
  List<Shadow>? shadows,
}) {
  final style = TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: spacing,
    shadows: shadows,
  );
  try {
    return GoogleFonts.getFont(family, textStyle: style);
  } catch (_) {
    return style;
  }
}

Widget _bar(double? w, double h, Color c, [double r = 0]) => Container(
  width: w,
  height: h,
  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(r)),
);

/// A track of [fill] over [track], [part] of it filled.
Widget _track(double h, double part, Color fill, Color track, [double r = 0]) =>
    Container(
      height: h,
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(r),
      ),
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: part,
        child: _bar(null, h, fill, r),
      ),
    );

/// A CSS angle (0 = to top, clockwise) as begin/end alignments.
(Alignment, Alignment) _angle(double deg) {
  final a = deg * math.pi / 180;
  final end = Alignment(math.sin(a), -math.cos(a));
  return (-end, end);
}

LinearGradient _linear(double deg, List<Color> colors, [List<double>? stops]) {
  final (begin, end) = _angle(deg);
  return LinearGradient(begin: begin, end: end, colors: colors, stops: stops);
}

class _Signal extends StatelessWidget {
  const _Signal();

  static const _lime = Color(0xFFD2F34C);
  static const _card = Color(0xFF191916);
  static const _ink = Color(0xFFF2F0E6);
  static const _dim = Color(0xFF3A3A34);

  @override
  Widget build(BuildContext context) {
    final card = BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(12),
    );
    return Container(
      color: const Color(0xFF0F0F0D),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _bar(12, 12, _lime, 4),
              const SizedBox(width: 6),
              _bar(44, 14, _lime, 999),
              const SizedBox(width: 6),
              _bar(34, 6, _dim, 3),
              const SizedBox(width: 6),
              _bar(34, 6, _dim, 3),
            ],
          ),
          const SizedBox(height: 9),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: card,
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Qu'est-ce qu'on\ntélécharge ?",
                          style: _font(
                            'Bricolage Grotesque',
                            15,
                            _ink,
                            height: 1.05,
                          ),
                        ),
                        Container(
                          height: 16,
                          padding: const EdgeInsets.all(2),
                          alignment: AlignmentDirectional.centerEnd,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B0B0A),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: _bar(36, 12, _lime, 999),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: card,
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '3',
                          style: _font('Bricolage Grotesque', 24, _ink),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _bar(6, 8, _dim),
                            const SizedBox(width: 3),
                            _bar(6, 14, _dim),
                            const SizedBox(width: 3),
                            _bar(6, 22, _lime),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 46,
            decoration: card,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                _bar(40, 26, const Color(0xFF2A2A25), 6),
                const SizedBox(width: 8),
                Expanded(
                  child: _track(4, 0.62, _lime, const Color(0xFF2A2A25), 2),
                ),
                const SizedBox(width: 8),
                Text('62%', style: _font('Inter', 12, _ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Porcelaine extends StatelessWidget {
  const _Porcelaine();

  static const _ground = Color(0xFFECEAE5);
  static const _ink = Color(0xFF16171A);
  static const _cobalt = Color(0xFF2747F5);

  @override
  Widget build(BuildContext context) {
    Widget card({Widget? child, EdgeInsets? padding}) => Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
    return Container(
      color: _ground,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _bar(36, 12, _ink, 999),
                const SizedBox(width: 5),
                _bar(26, 12, _ground, 999),
                const SizedBox(width: 5),
                _bar(26, 12, _ground, 999),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text('Bonsoir.', style: _font('Inter', 16, _ink)),
          const SizedBox(height: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 2,
                        child: card(
                          padding: const EdgeInsets.all(9),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '● En cours',
                                style: _font('Inter', 9, _cobalt),
                              ),
                              Text('62%', style: _font('Inter', 20, _ink)),
                              _track(4, 0.62, _cobalt, _ground, 2),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: card(
                          padding: const EdgeInsets.fromLTRB(9, 39, 9, 9),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: _bar(double.infinity, 14, _cobalt, 999),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: card()),
                      const SizedBox(width: 8),
                      Expanded(child: card()),
                      const SizedBox(width: 8),
                      Expanded(child: card()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille();

  static const _ground = Color(0xFF191715);

  @override
  Widget build(BuildContext context) {
    Widget tile(Color c) => Container(
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(14),
      ),
    );
    Widget dot(Color c) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Container(
          height: 6,
          decoration: ShapeDecoration(color: c, shape: const OvalBorder()),
        ),
      ),
    );
    return Container(
      color: _ground,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bonsoir, tout tourne.',
            style: _font('Inter', 15, const Color(0xFFF4EFE6)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 14,
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB9A8F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '62%',
                          style: _font('Inter', 30, _ground, height: 1),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (var i = 0; i < 8; i++)
                              dot(i < 5 ? _ground : const Color(0xFF8E7FD0)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  flex: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: tile(const Color(0xFFA8C686))),
                      const SizedBox(height: 7),
                      Expanded(child: tile(const Color(0xFFF4B3C2))),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  flex: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: tile(const Color(0xFF9ACDF5))),
                      const SizedBox(height: 7),
                      Expanded(child: tile(const Color(0xFFF4DA7A))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(child: _bar(110, 18, const Color(0xFF0E0D0C), 999)),
        ],
      ),
    );
  }
}

class _Studio extends StatelessWidget {
  const _Studio();

  static const _ink = Color(0xFF17171A);
  static const _rule = Color(0xFFE2E0DB);
  static const _faint = Color(0xFFCFCCC5);
  static const _grey = Color(0xFF8A877F);
  static const _red = Color(0xFFE5483B);

  @override
  Widget build(BuildContext context) {
    Widget line(Color main, Color tail) => Row(
      children: [
        Expanded(child: _bar(null, 5, main)),
        const SizedBox(width: 6),
        _bar(30, 5, tail),
      ],
    );
    const gap = SizedBox(height: 7);
    return Container(
      color: const Color(0xFFF5F4F1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: const BoxDecoration(
              border: BorderDirectional(end: BorderSide(color: _rule)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(40, 6, _ink),
                const SizedBox(height: 6),
                _bar(46, 5, _faint),
                const SizedBox(height: 6),
                _bar(36, 5, _faint),
                const SizedBox(height: 6),
                _bar(42, 5, _faint),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Bibliothèque',
                    style: _font('Inter', 20, _ink, spacing: -0.6),
                  ),
                  gap,
                  _bar(null, 2, _ink),
                  gap,
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: _red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: _bar(null, 5, _ink)),
                      const SizedBox(width: 6),
                      _bar(30, 5, _faint),
                    ],
                  ),
                  for (final tail in const [_faint, _faint, _red]) ...[
                    gap,
                    _bar(null, 1, _rule),
                    gap,
                    line(_grey, tail),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Terminal extends StatelessWidget {
  const _Terminal();

  static const _green = Color(0xFF8BE9A0);
  static const _bright = Color(0xFFE3EAE4);

  @override
  Widget build(BuildContext context) {
    final base = _font(
      'JetBrains Mono',
      10.5,
      const Color(0xFF9AA59B),
      weight: FontWeight.w500,
    );
    TextStyle tint(Color c) => base.copyWith(color: c);
    const gap = SizedBox(height: 6);
    return Container(
      color: const Color(0xFF0A0D0B),
      padding: const EdgeInsets.all(12),
      child: DefaultTextStyle(
        style: base,
        maxLines: 1,
        overflow: TextOverflow.clip,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'tapload', style: tint(_green)),
                  const TextSpan(text: ' › coller une URL'),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 3),
                      child: _bar(6, 11, _green),
                    ),
                  ),
                ],
              ),
            ),
            gap,
            Text(r'$ tapload status --live', style: tint(_bright)),
            gap,
            Text('▶ Documentaire, les derniers glaciers', style: tint(_bright)),
            gap,
            Row(
              children: [
                Expanded(flex: 12, child: _bar(null, 7, _green)),
                const SizedBox(width: 2),
                Expanded(
                  flex: 8,
                  child: _bar(null, 7, const Color(0xFF1C241E)),
                ),
              ],
            ),
            gap,
            const Text('62% · 6,2 Mo/s · eta 5 s'),
            const SizedBox(height: 10),
            Text(r'$ tapload ls --recent', style: tint(_bright)),
            gap,
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'ok  ', style: tint(_green)),
                  const TextSpan(text: 'Concert acoustique'),
                ],
              ),
            ),
            gap,
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'ok  ', style: tint(_green)),
                  const TextSpan(text: 'Monter un PC'),
                ],
              ),
            ),
            gap,
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'err ', style: tint(const Color(0xFFFF8A73))),
                  const TextSpan(text: 'Clip court '),
                  TextSpan(
                    text: 'r réessayer',
                    style: tint(const Color(0xFFE8C468)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Nocturne extends StatelessWidget {
  const _Nocturne();

  static const _blue = Color(0xFF8EA7FF);
  static const _card = Color(0xFF111831);
  static const _line = Color(0xFF1C2540);
  static const _ink = Color(0xFFEEF1FA);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0F1E),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 34,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 7),
            decoration: const BoxDecoration(
              border: BorderDirectional(
                end: BorderSide(color: Color(0xFF151D33)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _bar(null, 20, _blue, 6),
                const SizedBox(height: 9),
                _bar(null, 12, _line, 4),
                const SizedBox(height: 9),
                _bar(null, 12, _line, 4),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '1 téléchargement en cours',
                    style: _font('Inter', 14, _ink),
                  ),
                  const SizedBox(height: 9),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [_blue, _blue, _line, _line],
                                stops: [0, 0.62, 0.62, 1],
                                // CSS conic gradients start at the top.
                                transform: GradientRotation(-math.pi / 2),
                              ),
                            ),
                            child: Container(
                              width: 50,
                              height: 50,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: _card,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '62%',
                                style: _font('Inter', 12, _ink),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FractionallySizedBox(
                                  widthFactor: 0.9,
                                  child: _bar(null, 6, _ink, 3),
                                ),
                                const SizedBox(height: 6),
                                FractionallySizedBox(
                                  widthFactor: 0.6,
                                  child: _bar(
                                    null,
                                    5,
                                    const Color(0xFF3A4669),
                                    3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(child: _bar(null, 30, _card, 9)),
                      const SizedBox(width: 6),
                      Expanded(child: _bar(null, 30, _card, 9)),
                      const SizedBox(width: 6),
                      Expanded(child: _bar(null, 30, _card, 9)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Oled extends StatelessWidget {
  const _Oled();

  static const _cyan = Color(0xFF3CF2FF);
  static const _white = Color(0xFFF2F2F2);

  @override
  Widget build(BuildContext context) {
    Widget row(Color c) => Row(
      children: [
        Container(
          width: 30,
          height: 18,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF262626)),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _bar(null, 4, c)),
      ],
    );
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'tapload',
                style: _font('Doto', 13, _white, weight: FontWeight.w900),
              ),
              Row(
                children: [
                  _bar(22, 4, _white),
                  const SizedBox(width: 8),
                  _bar(22, 4, const Color(0xFF3A3A3A)),
                  const SizedBox(width: 8),
                  _bar(22, 4, const Color(0xFF3A3A3A)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '62%',
            maxLines: 1,
            style: _font(
              'Doto',
              74,
              _cyan,
              weight: FontWeight.w900,
              height: 0.85,
              shadows: const [Shadow(color: Color(0x803CF2FF), blurRadius: 18)],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(flex: 15, child: _bar(null, 4, _cyan)),
              const SizedBox(width: 3),
              Expanded(flex: 9, child: _bar(null, 4, const Color(0xFF1C1C1C))),
            ],
          ),
          const SizedBox(height: 14),
          _bar(null, 1, const Color(0xFF141414)),
          const SizedBox(height: 8),
          row(const Color(0xFF8C8C8C)),
          const SizedBox(height: 8),
          row(const Color(0xFF5E5E5E)),
        ],
      ),
    );
  }
}

class _Ios extends StatelessWidget {
  const _Ios();

  @override
  Widget build(BuildContext context) {
    RadialGradient glow(Alignment at, Color c, double r) => RadialGradient(
      center: at,
      radius: r,
      colors: [c, c.withValues(alpha: 0)],
      stops: const [0, 0.7],
    );
    Widget tile(Gradient g) => Expanded(
      child: Container(
        decoration: BoxDecoration(
          gradient: g,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
    return Container(
      color: const Color(0xFF04060C),
      child: Stack(
        children: [
          Positioned(
            left: -30,
            top: -30,
            right: -30,
            bottom: -30,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (final g in [
                    glow(
                      const Alignment(-0.4, -0.64),
                      const Color(0xCC5096E6),
                      0.6,
                    ),
                    glow(
                      const Alignment(0.7, -0.8),
                      const Color(0x8C8C5AFF),
                      0.55,
                    ),
                    glow(
                      const Alignment(0.4, 1),
                      const Color(0x731EC8AA),
                      0.65,
                    ),
                  ])
                    DecoratedBox(decoration: BoxDecoration(gradient: g)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 78,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: _linear(180, const [
                      Color(0x2EFFFFFF),
                      Color(0x0FFFFFFF),
                    ]),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: _linear(160, const [
                            Color(0xFF4FA6FF),
                            Color(0xFF0050D0),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _bar(double.infinity, 14, const Color(0x42FFFFFF), 999),
                      const SizedBox(height: 6),
                      _bar(46, 5, const Color(0x73FFFFFF), 3),
                      const SizedBox(height: 6),
                      _bar(40, 5, const Color(0x73FFFFFF), 3),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Bibliothèque',
                          style: _font(
                            'Inter',
                            17,
                            const Color(0xFFF5F7FB),
                            spacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          height: 58,
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 7),
                          alignment: Alignment.bottomCenter,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: _linear(
                              180,
                              const [
                                Color(0xFFB7DBF7),
                                Color(0xFF74A8DA),
                                Color(0xFF22497C),
                              ],
                              const [0, 0.42, 1],
                            ),
                          ),
                          child: Container(
                            height: 4,
                            alignment: AlignmentDirectional.centerStart,
                            decoration: BoxDecoration(
                              color: const Color(0x4DFFFFFF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: FractionallySizedBox(
                              widthFactor: 0.62,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0xE6FFFFFF),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              tile(
                                const RadialGradient(
                                  center: Alignment.topCenter,
                                  radius: 1,
                                  colors: [
                                    Color(0xFFFFE0A3),
                                    Color(0xFFF08A43),
                                    Color(0xFF5A1B22),
                                  ],
                                  stops: [0, 0.4, 1],
                                ),
                              ),
                              const SizedBox(width: 6),
                              tile(
                                _linear(140, const [
                                  Color(0xFF0B2427),
                                  Color(0xFF1C6B5D),
                                ]),
                              ),
                              const SizedBox(width: 6),
                              tile(
                                _linear(170, const [
                                  Color(0xFFF2C85B),
                                  Color(0xFF9A5A1A),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
