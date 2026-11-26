import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/video_thumbnail_provider.dart';

void main() {
  test('runs at most two tasks at once and every task in turn', () async {
    final slots = ThumbnailSlots(2);
    var running = 0;
    var peak = 0;
    final gates = List.generate(5, (_) => Completer<void>());
    final done = [
      for (var i = 0; i < 5; i++)
        slots.run(() async {
          running++;
          peak = running > peak ? running : peak;
          await gates[i].future;
          running--;
          return i;
        }),
    ];
    await Future<void>.delayed(Duration.zero);
    expect(running, 2);
    for (final g in gates) {
      g.complete();
      await Future<void>.delayed(Duration.zero);
    }
    expect(await Future.wait(done), [0, 1, 2, 3, 4]);
    expect(peak, 2);
  });
}
