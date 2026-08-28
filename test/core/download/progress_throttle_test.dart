import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/progress_throttle.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

class _ManualTimer implements Timer {
  bool _active = true;

  @override
  void cancel() {
    _active = false;
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

void main() {
  group('CoalescingThrottle', () {
    test(
      'many progress updates produce few list writes and no stats writes',
      () {
        var listWrites = 0;
        var statsWrites = 0;
        late void Function() fire;

        final throttle = CoalescingThrottle(
          interval: const Duration(milliseconds: 250),
          onFlush: () {
            listWrites++;
            if (isStatsRebuildStatus(DownloadStatus.downloading)) {
              statsWrites++;
            }
          },
          startTimer: (duration, callback) {
            fire = callback;
            return _ManualTimer();
          },
        );

        for (var i = 0; i < 80; i++) {
          throttle.schedule();
        }

        expect(throttle.scheduleCount, 80);
        expect(listWrites, 0);
        expect(statsWrites, 0);

        fire();
        expect(listWrites, 1);
        expect(statsWrites, 0);

        throttle.dispose();
      },
    );

    test('flushNow bypasses the timer', () {
      var flushes = 0;
      final throttle = CoalescingThrottle(onFlush: () => flushes++);
      throttle.flushNow();
      expect(flushes, 1);
      throttle.dispose();
    });
  });

  group('ProgressBroadcastFilter', () {
    test('drops unchanged percent within the throttle window', () {
      var now = DateTime(2026, 1, 1);
      final filter = ProgressBroadcastFilter(clock: () => now);

      expect(
        filter.shouldSend(
          id: 'a',
          status: DownloadStatus.downloading,
          progress: 0.10,
        ),
        isTrue,
      );
      expect(
        filter.shouldSend(
          id: 'a',
          status: DownloadStatus.downloading,
          progress: 0.11,
        ),
        isFalse,
      );

      now = now.add(const Duration(milliseconds: 250));
      expect(
        filter.shouldSend(
          id: 'a',
          status: DownloadStatus.downloading,
          progress: 0.40,
        ),
        isTrue,
      );
    });

    test('terminal status always sends', () {
      final filter = ProgressBroadcastFilter();
      expect(
        filter.shouldSend(
          id: 'b',
          status: DownloadStatus.completed,
          progress: 1,
        ),
        isTrue,
      );
    });
  });

  group('status helpers', () {
    test('progress ticks are not stats rebuilds', () {
      expect(isStatsRebuildStatus(DownloadStatus.downloading), isFalse);
      expect(isStatsRebuildStatus(DownloadStatus.extracting), isFalse);
      expect(isStatsRebuildStatus(DownloadStatus.completed), isTrue);
    });
  });
}
