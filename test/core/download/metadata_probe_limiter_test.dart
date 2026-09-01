import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/metadata_probe_limiter.dart';

void main() {
  group('MetadataProbeLimiter', () {
    test('caps parallel dump-json probes at 2', () {
      final limiter = MetadataProbeLimiter(maxParallel: 2);
      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isFalse);
      expect(limiter.inFlight, 2);
      limiter.release();
      expect(limiter.tryAcquire(), isTrue);
      limiter.reset();
      expect(limiter.inFlight, 0);
    });

    test('acquire waits until a slot is released', () async {
      final limiter = MetadataProbeLimiter(maxParallel: 1);
      expect(limiter.tryAcquire(), isTrue);

      var acquired = false;
      final waiting = limiter.acquire().then((_) {
        acquired = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(acquired, isFalse);
      expect(limiter.waiting, 1);

      limiter.release();
      await waiting;
      expect(acquired, isTrue);

      limiter.release();
      expect(limiter.inFlight, 0);
    });

    test('acquire throws when cancelled while waiting', () async {
      final limiter = MetadataProbeLimiter(maxParallel: 1);
      expect(limiter.tryAcquire(), isTrue);

      var cancelled = false;
      final waiting = limiter.acquire(isCancelled: () => cancelled);
      await Future<void>.delayed(Duration.zero);
      expect(limiter.waiting, 1);

      cancelled = true;
      await expectLater(
        waiting,
        throwsA(isA<MetadataProbeCancelledException>()),
      );
      expect(limiter.waiting, 0);

      limiter.release();
      expect(limiter.inFlight, 0);
    });
  });
}
