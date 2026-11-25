import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/yt_dlp_progress_parser.dart';

void main() {
  test('repeated path and title on every line do not bypass the throttle', () {
    final gate = ProgressYieldGate();
    final t0 = DateTime(2026);
    YtDlpProgressUpdate line(double p) => YtDlpProgressUpdate(
      progress: p,
      title: 'Stream',
      filePath: r'C:\Videos\Stream.f137.mp4',
      step: 'Téléchargement',
    );

    expect(gate.shouldYield(line(0.10), t0), isTrue);
    // 30 lines in the next 200 ms, each carrying the same path and title.
    var yielded = 0;
    for (var i = 1; i <= 30; i++) {
      final at = t0.add(Duration(milliseconds: i * 6));
      if (gate.shouldYield(line(0.10 + i * 0.001), at)) yielded++;
    }
    expect(yielded, 0);

    // A new destination (next fragment / merged file) still goes through.
    expect(
      gate.shouldYield(
        const YtDlpProgressUpdate(
          progress: 0.2,
          title: 'Stream',
          filePath: r'C:\Videos\Stream.f251.webm',
          step: 'Téléchargement',
        ),
        t0.add(const Duration(milliseconds: 210)),
      ),
      isTrue,
    );
    // And time alone still lets a progress line through after 250 ms.
    expect(
      gate.shouldYield(line(0.21), t0.add(const Duration(milliseconds: 470))),
      isTrue,
    );
  });
}
