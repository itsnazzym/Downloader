import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/async_serializer.dart';
import 'package:modern_downloader/core/download/extension_download_batcher.dart';
import 'package:modern_downloader/core/download/fragment_budget.dart';

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
  group('ExtensionDownloadBatcher', () {
    test('N URLs flush once with one focus and one persist', () {
      var focusCalls = 0;
      var persistCalls = 0;
      var notifyCount = 0;
      final queued = <String>[];
      late void Function() fire;

      final batcher = ExtensionDownloadBatcher(
        debounce: const Duration(milliseconds: 120),
        onFlush: (batch) {
          focusCalls++;
          persistCalls++;
          notifyCount = batch.length;
          queued.addAll(batch.map((item) => item.url));
        },
        startTimer: (duration, callback) {
          fire = callback;
          return _ManualTimer();
        },
      );

      const maxConcurrent = 15;
      const total = 100;
      for (var i = 0; i < total; i++) {
        batcher.add(
          ExtensionDownloadIngest(url: 'https://example.com/watch?v=$i'),
        );
      }

      expect(batcher.isScheduled, isTrue);
      fire();

      expect(batcher.flushCount, 1);
      expect(focusCalls, 1);
      expect(persistCalls, 1);
      expect(notifyCount, total);
      expect(queued, hasLength(total));

      final started = computeStartableCount(
        activeCount: 0,
        maxConcurrent: maxConcurrent,
        pendingCount: queued.length,
      );
      expect(started, maxConcurrent);
      expect(started, lessThanOrEqualTo(maxConcurrent));
      expect(queued.length - started, 85);

      batcher.dispose();
    });

    test('does not flush an empty buffer', () {
      var flushes = 0;
      final batcher = ExtensionDownloadBatcher(onFlush: (_) => flushes++);
      batcher.flush();
      expect(flushes, 0);
      batcher.dispose();
    });
  });

  group('AsyncSerializer', () {
    test('overlapping persist awaits run one at a time', () async {
      final serializer = AsyncSerializer();
      var inFlight = 0;
      var maxInFlight = 0;
      var persistCalls = 0;

      Future<void> persist() {
        return serializer.run(() async {
          inFlight++;
          if (inFlight > maxInFlight) {
            maxInFlight = inFlight;
          }
          persistCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          inFlight--;
        });
      }

      await Future.wait<void>([persist(), persist(), persist()]);
      expect(persistCalls, 3);
      expect(maxInFlight, 1);
    });
  });
}
