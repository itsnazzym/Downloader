import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/download/fragment_budget.dart';

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

  group('kYtDlpBufferSize', () {
    test('stays small so progress is reported while the file downloads', () {
      // yt-dlp reports progress once per read, and the first read is this
      // size: anything above a few MB freezes the live progress of a short
      // download at 0 % until it ends (measured: 64M gave 2 progress lines
      // for a 59 MB file, 1M gave 18).
      final match = RegExp(r'^(\d+)([KM])$').firstMatch(kYtDlpBufferSize);
      expect(match, isNotNull);
      final value = int.parse(match!.group(1)!);
      final megabytes = match.group(2) == 'M' ? value : value / 1024;
      expect(megabytes, lessThanOrEqualTo(1));
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
