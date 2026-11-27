import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapload/core/security/paired_browsers.dart';
import 'package:tapload/core/security/pairing_coordinator.dart';

const _origin = 'chrome-extension://abcdefghijklmnopabcdefghijklmnop';
const _other = 'moz-extension://11111111-2222-3333-4444-555555555555';

class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this.callback);
  final Duration duration;
  final void Function() callback;
  var cancelled = false;
  var fired = false;

  void fire() {
    fired = true;
    callback();
  }

  @override
  void cancel() => cancelled = true;
  @override
  bool get isActive => !cancelled && !fired;
  @override
  int get tick => fired ? 1 : 0;
}

void main() {
  late DateTime now;
  late PairedBrowsersStore store;
  late PairingCoordinator coordinator;
  late List<_FakeTimer> timers;

  PairingCoordinator newCoordinator({Random? random}) => PairingCoordinator(
    store,
    clock: () => now,
    random: random ?? Random(42),
    schedule: (d, cb) {
      final t = _FakeTimer(d, cb);
      timers.add(t);
      return t;
    },
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    now = DateTime.utc(2026, 11, 27, 12);
    timers = [];
    store = PairedBrowsersStore(prefs, clock: () => now, random: Random(7));
    coordinator = newCoordinator();
  });

  tearDown(() {
    if (coordinator.mounted) coordinator.dispose();
    store.dispose();
  });

  PairingSubmit submit([String origin = _origin]) =>
      coordinator.submit(origin: origin, label: 'Chrome');

  group('submit', () {
    test('creates a request with a 4-digit code and a 2-minute timer', () {
      final s = submit();

      expect(s.refusal, isNull);
      expect(s.request, isNotNull);
      expect(s.outcome, isNotNull);
      expect(s.request!.code, matches(RegExp(r'^\d{4}$')));
      expect(s.request!.id, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(s.request!.origin, _origin);
      expect(s.request!.label, 'Chrome');
      expect(s.request!.createdAt, now);
      expect(coordinator.state, s.request);
      expect(timers.single.duration, const Duration(minutes: 2));
    });

    test('keeps leading zeros in the code', () {
      // Scan seeds until one yields a code starting with 0 (about 10 %).
      for (var seed = 0; seed < 200; seed++) {
        final c = PairingCoordinator(
          store,
          clock: () => now,
          random: Random(seed),
          schedule: (d, cb) => _FakeTimer(d, cb),
        );
        final code = c.submit(origin: _origin, label: 'x').request!.code;
        c.dispose();
        if (code.startsWith('0')) {
          expect(code, hasLength(4));
          return;
        }
      }
      fail('no seed produced a leading zero');
    });

    test('a new request gets a different code and id', () async {
      final a = submit().request!;
      await coordinator.deny(a.id);
      final b = submit(_other).request!;

      expect(b.code, isNot(a.code));
      expect(b.id, isNot(a.id));
    });

    test('same origin while pending adopts: same request, same outcome, '
        'no extra rate slot', () async {
      final first = submit();
      for (var i = 0; i < 5; i++) {
        final again = submit();
        expect(again.request!.id, first.request!.id);
        expect(again.request!.code, first.request!.code);
        expect(identical(again.outcome, first.outcome), isTrue);
        expect(again.refusal, isNull);
      }
      expect(timers, hasLength(1));
      expect(await coordinator.approve(first.request!.id), isTrue);

      // 5 adoptions cost nothing: slots 2 and 3 are still available.
      for (var i = 0; i < 2; i++) {
        final s = submit();
        expect(s.request, isNotNull, reason: 'submission ${i + 2}');
        expect(await coordinator.approve(s.request!.id), isTrue);
      }
      expect(submit().refusal, PairingRefusal.rateLimited);
    });

    test('another origin while one is pending is busy and costs no slot', () {
      final first = submit();
      final other = submit(_other);

      expect(other.refusal, PairingRefusal.busy);
      expect(other.request, isNull);
      expect(other.outcome, isNull);
      expect(coordinator.state, first.request);
    });

    test('an empty origin is refused as blocked', () {
      final s = coordinator.submit(origin: ' \u200B ', label: 'x');
      expect(s.refusal, PairingRefusal.blocked);
      expect(coordinator.state, isNull);
    });

    test('origin and label are clamped in the request', () {
      final s = coordinator.submit(
        origin: 'chrome-extension://ab\ncd\u202E',
        label: 'Ch\u0000rome${'x' * 200}',
      );
      expect(s.request!.origin, 'chrome-extension://abcd');
      expect(s.request!.label.length, lessThanOrEqualTo(80));
      expect(s.request!.label, isNot(contains('\u0000')));
    });
  });

  group('limits', () {
    test(
      'after deny the origin is paused ~10 min, outcome is denied',
      () async {
        final s = submit();
        await coordinator.deny(s.request!.id);

        final outcome = await s.outcome!;
        expect(outcome, isA<PairingDenied>());
        expect(
          (outcome as PairingDenied).retryAfter,
          const Duration(minutes: 10),
        );
        expect(coordinator.state, isNull);
        expect(timers.single.cancelled, isTrue);

        final again = submit();
        expect(again.refusal, PairingRefusal.paused);
        expect(again.retryAfter, const Duration(minutes: 10));
        now = now.add(const Duration(minutes: 4));
        expect(submit().retryAfter, const Duration(minutes: 6));
        now = now.add(const Duration(minutes: 6));
        expect(submit().request, isNotNull);
      },
    );

    test('deny(always) blocks the origin until unblocked', () async {
      final s = submit();
      await coordinator.deny(s.request!.id, always: true);

      expect(await s.outcome!, isA<PairingDenied>());
      now = now.add(const Duration(days: 1));
      expect(submit().refusal, PairingRefusal.blocked);
      expect(submit(_other).request, isNotNull); // others unaffected
      await coordinator.deny(coordinator.state!.id);
      await store.unblock(_origin);
      expect(submit().request, isNotNull);
    });

    test('4th submission within the hour is rate limited, then passes', () {
      // Expire each request so only the rate limit can refuse.
      for (var i = 0; i < 3; i++) {
        expect(submit().request, isNotNull, reason: 'submission ${i + 1}');
        timers.last.fire();
        now = now.add(const Duration(minutes: 10));
      }
      expect(coordinator.state, isNull);

      final blocked = submit();
      expect(blocked.refusal, PairingRefusal.rateLimited);
      expect(blocked.request, isNull);
      expect(blocked.retryAfter, const Duration(minutes: 30));

      // A refused attempt is not counted: still allowed exactly at +1 h.
      now = now.add(const Duration(minutes: 30));
      expect(submit().request, isNotNull);
    });

    test('rate limit is per origin', () {
      for (var i = 0; i < 3; i++) {
        submit();
        timers.last.fire();
      }
      expect(submit().refusal, PairingRefusal.rateLimited);
      expect(submit(_other).request, isNotNull);
    });

    test('tracked origins are bounded', () {
      for (var i = 0; i < 250; i++) {
        coordinator.submit(origin: 'chrome-extension://o$i', label: 'x');
        timers.last.fire();
      }
      expect(coordinator.trackedOriginCount, lessThanOrEqualTo(100));
    });
  });

  group('approve', () {
    test('pairs once, resolves PairingApproved with a valid token', () async {
      final s = submit();
      final id = s.request!.id;

      expect(await coordinator.approve(id), isTrue);
      final outcome = await s.outcome!;
      expect(outcome, isA<PairingApproved>());
      final token = (outcome as PairingApproved).token;
      expect(store.authenticate(token)?.origin, _origin);
      expect(store.state.browsers.single.label, 'Chrome');
      expect(coordinator.state, isNull);
      expect(timers.single.cancelled, isTrue);
    });

    test(
      'twice (even concurrently): one true, one false, one browser',
      () async {
        final id = submit().request!.id;

        final results = await Future.wait([
          coordinator.approve(id),
          coordinator.approve(id),
        ]);
        expect(results, [true, false]);
        expect(await coordinator.approve(id), isFalse);
        expect(store.state.browsers, hasLength(1));
      },
    );

    test(
      'after expiry by the clock: false, no token, outcome expired',
      () async {
        final s = submit();
        now = now.add(const Duration(minutes: 2, seconds: 1));

        expect(await coordinator.approve(s.request!.id), isFalse);
        expect(await s.outcome!, isA<PairingExpired>());
        expect(store.state.browsers, isEmpty);
        expect(coordinator.state, isNull);
      },
    );

    test('after the timer fired: false and no browser', () async {
      final s = submit();
      timers.single.fire();

      expect(await s.outcome!, isA<PairingExpired>());
      expect(coordinator.state, isNull);
      expect(await coordinator.approve(s.request!.id), isFalse);
      expect(store.state.browsers, isEmpty);
    });

    test('after deny: false and no browser', () async {
      final s = submit();
      await coordinator.deny(s.request!.id);
      expect(await coordinator.approve(s.request!.id), isFalse);
      expect(store.state.browsers, isEmpty);
    });

    test('unknown id: false, pending request untouched', () async {
      final s = submit();
      expect(await coordinator.approve('0000000000000000'), isFalse);
      expect(coordinator.state, s.request);
      expect(store.state.browsers, isEmpty);
    });

    test('store full: outcome denied, false, state cleared', () async {
      for (var i = 0; i < 20; i++) {
        await store.pair(origin: 'chrome-extension://full$i', label: 'x');
      }
      final s = submit();

      expect(await coordinator.approve(s.request!.id), isFalse);
      expect(
        await s.outcome!.timeout(const Duration(seconds: 1)),
        isA<PairingDenied>(),
      );
      expect(coordinator.state, isNull);
      expect(store.state.browsers, hasLength(20));
      // Not stuck busy: another origin can be asked right away.
      expect(submit(_other).request, isNotNull);
    });
  });

  group('deny', () {
    test('unknown or stale id is a no-op', () async {
      final s = submit();
      await coordinator.deny('nope');
      expect(coordinator.state, s.request);
      expect(store.pauseRemaining(_origin), isNull);

      await coordinator.deny(s.request!.id);
      await coordinator.deny(s.request!.id); // second call: no-op
      expect(coordinator.state, isNull);
    });
  });

  group('expiry and dispose', () {
    test('the timer resolves PairingExpired and clears the state', () async {
      final s = submit();
      timers.single.fire();

      expect(await s.outcome!, isA<PairingExpired>());
      expect(coordinator.state, isNull);
      // Free again; expiry does not pause the origin.
      expect(submit().request, isNotNull);
    });

    test('dispose cancels the timer and completes pending outcomes', () async {
      final s = submit();
      coordinator.dispose();

      expect(timers.single.cancelled, isTrue);
      expect(await s.outcome!, isA<PairingExpired>());
    });
  });
}
