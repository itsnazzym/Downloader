import 'dart:async';

import 'package:flutter/material.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';

import 'terminal_widgets.dart';

/// Terminal's situations and motion: typed lines, a blinking block cursor,
/// segment fills that step. Never a smooth fade.

/// The readable part of a download error: the `ERROR:` line (else the first
/// line), without yt-dlp's prefixes and boilerplate.
String terminalErrorReason(String? raw) {
  final lines = (raw ?? '')
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return '';
  var s = lines.firstWhere(
    (l) => l.toUpperCase().startsWith('ERROR:'),
    orElse: () => lines.first,
  );
  s = s
      .replaceFirst(RegExp(r'^ERROR:\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^\[[^\]]+\]\s*(?:[\w-]+:\s*)?'), '')
      .replaceFirst(
        RegExp(
          r'^Unable to (?:download|extract)(?: webpage| video data)?:\s*',
          caseSensitive: false,
        ),
        '',
      )
      .replaceFirst(
        RegExp(r';\s*please report this issue.*$', caseSensitive: false),
        '',
      )
      .replaceFirst(RegExp(r'\s*\(caused by .*\)$', caseSensitive: false), '');
  return s.trim();
}

/// A line typed in once, character by character (< 0.7 s), then an optional
/// blinking block cursor. The untyped rest is laid out transparent, so the
/// line never reflows while it types.
class TTyped extends StatefulWidget {
  const TTyped(
    this.text, {
    super.key,
    required this.style,
    this.cursor = false,
  });

  final String text;
  final TextStyle style;
  final bool cursor;

  @override
  State<TTyped> createState() => _TTypedState();
}

class _TTypedState extends State<TTyped> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.text.length * 18).clamp(120, 700)),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctl.value = 1;
    } else {
      _ctl.forward();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.style.color ?? AppColors.of(context).textPrimary;
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) {
        final n = (widget.text.length * _ctl.value).round();
        final typing = n < widget.text.length;
        return Text.rich(
          TextSpan(
            style: widget.style,
            children: [
              TextSpan(text: widget.text.substring(0, n)),
              if (typing || widget.cursor)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: TBlockCursor(
                      color: color,
                      blink: !typing,
                      height: (widget.style.fontSize ?? 12.5) + 2,
                    ),
                  ),
                ),
              if (typing)
                TextSpan(
                  text: widget.text.substring(n),
                  style: const TextStyle(color: Colors.transparent),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The block cursor: a 2 Hz timer (two frames a second), still when effects
/// are off.
class TBlockCursor extends StatefulWidget {
  const TBlockCursor({
    super.key,
    required this.color,
    this.blink = true,
    this.height = 15,
  });

  final Color color;
  final bool blink;
  final double height;

  @override
  State<TBlockCursor> createState() => _TBlockCursorState();
}

class _TBlockCursorState extends State<TBlockCursor> {
  Timer? _timer;
  bool _on = true;

  void _sync() {
    final run = widget.blink && !MediaQuery.disableAnimationsOf(context);
    if (run && _timer == null) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => setState(() => _on = !_on),
      );
    } else if (!run) {
      _timer?.cancel();
      _timer = null;
      _on = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(TBlockCursor old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.height * 0.55,
        height: widget.height,
        child: _on ? ColoredBox(color: widget.color) : null,
      ),
    );
  }
}

/// Holds the page's one-time "print" of its first lines.
class TEntrance extends InheritedWidget {
  const TEntrance({super.key, required this.animation, required super.child});

  final Animation<double> animation;

  static const lines = 12;

  @override
  bool updateShouldNotify(TEntrance old) => old.animation != animation;
}

/// Line [index] appears when the entrance reaches it: a hard cut per line,
/// like terminal output scrolling in.
class TPrinted extends StatelessWidget {
  const TPrinted({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final a = context
        .dependOnInheritedWidgetOfExactType<TEntrance>()
        ?.animation;
    if (a == null || index >= TEntrance.lines || a.isCompleted) return child;
    return AnimatedBuilder(
      animation: a,
      child: child,
      builder: (context, child) => Opacity(
        opacity: a.value * (TEntrance.lines + 1) >= index + 1 ? 1 : 0,
        child: child,
      ),
    );
  }
}

/// The empty library's visual: an unformatted drive in ASCII blocks. Shown
/// unless `assets/designs/terminal/empty.png` exists.
class TEmptyVisual extends StatelessWidget {
  const TEmptyVisual({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 132,
      child: Image.asset(
        'assets/designs/terminal/empty.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => const _AsciiDrive(),
      ),
    );
  }
}

/// A drive drawn in the design's own blocks (glyph art depends on the font):
/// empty segment tracks, a hairline case, `0 B` and a lit status cell.
class _AsciiDrive extends StatelessWidget {
  const _AsciiDrive();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final line = BorderSide(color: colors.textDisabled);
    return Center(
      child: Container(
        width: 200,
        decoration: BoxDecoration(border: Border.fromBorderSide(line)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                children: [
                  for (var i = 0; i < 3; i++)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 5),
                      child: TSeg(value: 0, height: 10),
                    ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(border: Border(top: line)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text('0 B', style: tm(colors.primary)),
                    const Spacer(),
                    Text('/dev/tl0', style: tm(colors.textDisabled)),
                    const SizedBox(width: 10),
                    TBlockCursor(color: colors.primary, height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton table lines: segmented blocks where the real columns sit, and a
/// scanline that steps down one line at a time.
class TSkeletonLines extends StatefulWidget {
  const TSkeletonLines({
    super.key,
    required this.leading,
    required this.trailing,
    this.lines = 8,
    this.lineHeight = 32,
  });

  /// Widths of the fixed columns before the title, then after it.
  final List<double> leading;
  final List<double> trailing;
  final int lines;
  final double lineHeight;

  @override
  State<TSkeletonLines> createState() => _TSkeletonLinesState();
}

class _TSkeletonLinesState extends State<TSkeletonLines>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 140 * widget.lines),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctl.stop();
      _ctl.value = 0;
    } else if (!_ctl.isAnimating) {
      _ctl.repeat();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.fromHeight(widget.lines * widget.lineHeight),
        painter: _SkeletonPainter(
          _ctl,
          lines: widget.lines,
          lineHeight: widget.lineHeight,
          leading: widget.leading,
          trailing: widget.trailing,
          track: colors.surfaceHighlight,
          lit: Color.lerp(colors.surfaceHighlight, colors.primary, 0.22)!,
          animate: !MediaQuery.disableAnimationsOf(context),
        ),
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter(
    this.t, {
    required this.lines,
    required this.lineHeight,
    required this.leading,
    required this.trailing,
    required this.track,
    required this.lit,
    required this.animate,
  }) : super(repaint: t);

  final Animation<double> t;
  final int lines;
  final double lineHeight;
  final List<double> leading;
  final List<double> trailing;
  final Color track;
  final Color lit;
  final bool animate;

  static const _gap = 14.0;
  static const _titleShare = [.62, .44, .71, .36, .55, .67, .4, .5];
  static const _cellShare = [.35, .6, .45, .8, .5, .3, .7, .55];

  void _seg(Canvas canvas, double x, double y, double w, Paint p) {
    for (var cx = x; cx < x + w; cx += 8) {
      canvas.drawRect(Rect.fromLTWH(cx, y, (x + w - cx).clamp(0.0, 6.0), 8), p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scan = animate ? (t.value * lines).floor() : -1;
    final off = Paint()..color = track;
    final on = Paint()..color = lit;
    for (var i = 0; i < lines; i++) {
      final p = i == scan ? on : off;
      final y = i * lineHeight + (lineHeight - 8) / 2;
      var x = 14.0;
      for (final (k, w) in leading.indexed) {
        _seg(canvas, x, y, w * _cellShare[(i + k) % 8], p);
        x += w + _gap;
      }
      var right = size.width - 12;
      final ends = <(double, double)>[];
      for (final w in trailing.reversed) {
        ends.add((right - w, w));
        right -= w + _gap;
      }
      for (final (k, (ex, w)) in ends.indexed) {
        final len = w * _cellShare[(i + k + 3) % 8];
        // The last column is right-aligned, like the real table.
        _seg(canvas, k == 0 ? ex + w - len : ex, y, len, p);
      }
      _seg(canvas, x, y, (right - x) * _titleShare[i % 8], p);
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) =>
      old.track != track ||
      old.lit != lit ||
      old.animate != animate ||
      old.lines != lines;
}
