import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/download/site_backoff.dart';

class _NoSpread implements Random {
  @override
  double nextDouble() => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  var clock = DateTime(2026, 11, 27, 12);
  SiteBackoff backoff() =>
      SiteBackoff(random: _NoSpread(), now: () => clock);

  setUp(() => clock = DateTime(2026, 11, 27, 12));

  test('retry delays grow 5 s, 20 s, 80 s, then stay at 2 min', () {
    final b = backoff();
    expect(
      [for (var i = 1; i <= 5; i++) b.retryDelay(i).inSeconds],
      [5, 20, 80, 120, 120],
    );
  });

  test('spread stays within 25 %', () {
    final b = SiteBackoff(random: Random(1));
    for (var i = 0; i < 50; i++) {
      final d = b.retryDelay(2).inMilliseconds;
      expect(d, inInclusiveRange(20000, 25000));
    }
  });

  test('a refusal pauses every request to the same site', () {
    final b = backoff();
    b.recordRefusal('https://www.tiktokv.com/share/video/1/');
    expect(b.waitFor('https://www.tiktok.com/@a/video/2').inSeconds, 5);
    expect(b.waitFor('https://x.com/a/status/3'), Duration.zero);
    b.recordRefusal('https://www.tiktok.com/@a/video/2');
    expect(b.waitFor('https://www.tiktokv.com/share/video/9/').inSeconds, 20);
  });

  test('the pause runs out, and a success lifts it at once', () {
    final b = backoff();
    b.recordRefusal('https://www.tiktok.com/@a/video/1');
    clock = clock.add(const Duration(seconds: 6));
    expect(b.waitFor('https://www.tiktok.com/@a/video/2'), Duration.zero);

    b.recordRefusal('https://www.tiktok.com/@a/video/1');
    b.recordSuccess('https://www.tiktok.com/@a/video/3');
    expect(b.waitFor('https://www.tiktok.com/@a/video/2'), Duration.zero);
    b.recordRefusal('https://www.tiktok.com/@a/video/1');
    expect(b.waitFor('https://www.tiktok.com/@a/video/2').inSeconds, 5);
  });
}
