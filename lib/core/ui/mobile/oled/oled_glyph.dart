import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tapload/core/ui/mobile/oled/oled_kit.dart';

/// The logo's dot-matrix "download" glyph: an arrow dropping into a tray.
/// `#` lit, `*` live (red), `.` unlit.
const List<String> kOledGlyph = [
  '...#...',
  '...#...',
  '...#...',
  '#..#..#',
  '.#.#.#.',
  '..###..',
  '...*...',
  '.......',
  '.#####.',
];

const int kOledGlyphCols = 7;
const int kOledGlyphRows = 9;

/// Paints the glyph and animates it.
///
/// * [reveal] 0 -> 1 ignites the field from the centre outwards.
/// * [pulse] 0 -> 1 (looping) breathes the red dot.
/// * [drop] 0 -> 1 (looping) sends a bright pulse down the arrow shaft into
///   the tray, like a file being downloaded.
class OledGlyph extends StatelessWidget {
  const OledGlyph({
    super.key,
    required this.width,
    this.reveal = const AlwaysStoppedAnimation(1),
    this.pulse = const AlwaysStoppedAnimation(0),
    this.drop = const AlwaysStoppedAnimation(-1),
  });

  final double width;
  final Animation<double> reveal;
  final Animation<double> pulse;
  final Animation<double> drop;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, width * kOledGlyphRows / kOledGlyphCols),
        painter: _GlyphPainter(
          reveal: reveal,
          pulse: pulse,
          drop: drop,
          ink: t.ink,
          unlit: t.ink.withValues(alpha: 0.09),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({
    required this.reveal,
    required this.pulse,
    required this.drop,
    required this.ink,
    required this.unlit,
  }) : super(repaint: Listenable.merge([reveal, pulse, drop]));

  final Animation<double> reveal;
  final Animation<double> pulse;
  final Animation<double> drop;
  final Color ink;
  final Color unlit;

  @override
  void paint(Canvas canvas, Size size) {
    final pitch = size.width / kOledGlyphCols;
    final radius = pitch * 0.33;
    const centerCol = (kOledGlyphCols - 1) / 2;
    const centerRow = (kOledGlyphRows - 1) / 2;
    final maxDistance = math.sqrt(
      centerCol * centerCol + centerRow * centerRow,
    );
    final paint = Paint()..isAntiAlias = true;

    for (var r = 0; r < kOledGlyphRows; r++) {
      for (var c = 0; c < kOledGlyphCols; c++) {
        final cell = kOledGlyph[r][c];
        final dx = c - centerCol;
        final dy = r - centerRow;
        final delay = math.sqrt(dx * dx + dy * dy) / maxDistance; // 0..1
        // Each cell has its own window inside the reveal so the wave travels.
        final local = ((reveal.value * 1.5) - delay * 0.5).clamp(0.0, 1.0);
        final eased = Curves.easeOutBack.transform(local);
        final centre = Offset((c + 0.5) * pitch, (r + 0.5) * pitch);

        Color color;
        double scale = eased;
        switch (cell) {
          case '#':
            color = Color.lerp(unlit, ink, Curves.easeIn.transform(local))!;
          case '*':
            final breathe = 0.5 + 0.5 * math.sin(pulse.value * 2 * math.pi);
            color = OledTokens.live;
            scale = eased * (1 + 0.28 * breathe);
            if (local > 0.6) {
              paint.color = OledTokens.live.withValues(
                alpha: 0.22 * breathe * local,
              );
              canvas.drawCircle(centre, radius * 2.6, paint);
            }
          default:
            color = unlit;
        }

        // The downloading pulse: rows 0..5 of the shaft, then the tray.
        if (cell == '#' && drop.value >= 0) {
          final head = drop.value * (kOledGlyphRows + 2) - 1;
          final isShaft = c == 3 && r <= 5;
          final isTray = r == 8;
          if (isShaft || isTray) {
            final target = isTray ? 8.0 : r.toDouble();
            final glow = (1 - (head - target).abs() / 2).clamp(0.0, 1.0);
            if (glow > 0) {
              paint.color = ink.withValues(alpha: 0.28 * glow);
              canvas.drawCircle(centre, radius * (1.4 + 0.5 * glow), paint);
              color = Color.lerp(color, Colors.white, glow * 0.6)!;
            }
          }
        }

        paint.color = color;
        canvas.drawCircle(centre, radius * scale.clamp(0.0, 1.35), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.ink != ink || old.unlit != unlit;
}
