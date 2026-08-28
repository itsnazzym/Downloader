import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/fragment_budget.dart';

void main() {
  group('computeConcurrentFragments', () {
    test('one max-speed job still gets 64 fragments', () {
      expect(
        computeConcurrentFragments(perJob: 64, activeCount: 1),
        kMaxSpeedFragmentsPerJob,
      );
    });

    test('two max-speed jobs share the 64 budget', () {
      expect(computeConcurrentFragments(perJob: 64, activeCount: 2), 32);
    });

    test('max speed with 15 active yields 4 fragments per job', () {
      expect(computeConcurrentFragments(perJob: 64, activeCount: 15), 4);
    });

    test('never exceeds the per-job slider', () {
      expect(computeConcurrentFragments(perJob: 9, activeCount: 1), 9);
      expect(computeConcurrentFragments(perJob: 9, activeCount: 15), 4);
    });

    test('guards invalid counts', () {
      expect(computeConcurrentFragments(perJob: 64, activeCount: 0), 64);
      expect(computeConcurrentFragments(perJob: 0, activeCount: 3), 1);
    });
  });

  group('computeYtDlpBufferSize', () {
    test('caps at 16M when more than 4 jobs are active', () {
      expect(
        computeYtDlpBufferSize(concurrentFragments: 64, activeCount: 5),
        '16M',
      );
      expect(
        computeYtDlpBufferSize(concurrentFragments: 64, activeCount: 15),
        '16M',
      );
    });

    test('keeps turbo buffers for 1–4 jobs', () {
      expect(
        computeYtDlpBufferSize(concurrentFragments: 64, activeCount: 1),
        '128M',
      );
      expect(
        computeYtDlpBufferSize(concurrentFragments: 16, activeCount: 2),
        '64M',
      );
    });
  });

  group('computeStartableCount', () {
    test('queue still respects maxConcurrent', () {
      expect(
        computeStartableCount(
          activeCount: 0,
          maxConcurrent: 15,
          pendingCount: 100,
        ),
        15,
      );
      expect(
        computeStartableCount(
          activeCount: 15,
          maxConcurrent: 15,
          pendingCount: 100,
        ),
        0,
      );
      expect(
        computeStartableCount(
          activeCount: 10,
          maxConcurrent: 15,
          pendingCount: 100,
        ),
        5,
      );
      expect(
        computeStartableCount(
          activeCount: 0,
          maxConcurrent: 3,
          pendingCount: 2,
        ),
        2,
      );
    });
  });
}
