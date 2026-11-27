import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapload/core/security/paired_browsers.dart';

const _key = 'paired_browsers_v1';
const _origin = 'chrome-extension://abcdefghijklmnopabcdefghijklmnop';
const _other = 'moz-extension://11111111-2222-3333-4444-555555555555';

void main() {
  late SharedPreferences prefs;
  late DateTime now;
  late PairedBrowsersStore store;

  PairedBrowsersStore newStore({Random? random}) =>
      PairedBrowsersStore(prefs, clock: () => now, random: random);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime.utc(2026, 11, 27, 12);
    store = newStore();
  });

  tearDown(() => store.dispose());

  group('pair', () {
    test(
      'returns a 43-char base64url token and stores only its hash',
      () async {
        final (browser, token) = await store.pair(
          origin: _origin,
          label: 'Chrome',
        );

        expect(token, hasLength(43));
        expect(token, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
        expect(browser.tokenHash, PairedBrowsersStore.hashToken(token));
        expect(jsonEncode(browser.toJson()), isNot(contains(token)));
        expect(prefs.getString(_key), isNot(contains(token)));
        expect(prefs.getString(_key), contains(browser.tokenHash));
        expect(store.state.browsers, [browser]);
      },
    );

    test('two pairings give different tokens and ids', () async {
      final (a, ta) = await store.pair(origin: _origin, label: 'Chrome');
      final (b, tb) = await store.pair(origin: _other, label: 'Firefox');

      expect(ta, isNot(tb));
      expect(a.id, isNot(b.id));
      expect(a.id, matches(RegExp(r'^[0-9a-f]{16}$')));
    });
  });

  group('authenticate', () {
    test('accepts the good token and updates lastSeenAt', () async {
      final (browser, token) = await store.pair(origin: _origin, label: 'C');
      expect(browser.lastSeenAt, isNull);

      now = now.add(const Duration(minutes: 5));
      final found = store.authenticate(token);

      expect(found?.id, browser.id);
      expect(store.state.browsers.single.lastSeenAt, now);
    });

    test('rejects a token modified by one character', () async {
      final (_, token) = await store.pair(origin: _origin, label: 'C');
      final last = token[42] == 'A' ? 'B' : 'A';
      expect(store.authenticate(token.substring(0, 42) + last), isNull);
      final first = token[0] == 'A' ? 'B' : 'A';
      expect(store.authenticate(first + token.substring(1)), isNull);
    });

    test('rejects empty, short, long and unknown tokens', () async {
      final (_, token) = await store.pair(origin: _origin, label: 'C');
      expect(store.authenticate(''), isNull);
      expect(store.authenticate('abc'), isNull);
      expect(store.authenticate(token.substring(0, 20)), isNull);
      expect(store.authenticate('${token}x'), isNull);
      expect(store.authenticate('A' * 43), isNull);
    });

    test('finds the right browser among several', () async {
      await store.pair(origin: _origin, label: 'C');
      final (second, token) = await store.pair(origin: _other, label: 'F');
      expect(store.authenticate(token)?.id, second.id);
    });

    test('5000 authentications stay fast', () async {
      for (var i = 0; i < 5; i++) {
        await store.pair(
          origin: 'chrome-extension://abcdefghijklmnop$i',
          label: '$i',
        );
      }
      final sw = Stopwatch()..start();
      for (var i = 0; i < 5000; i++) {
        store.authenticate('A' * 42 + String.fromCharCode(65 + i % 26));
      }
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });
  });

  group('revoke', () {
    test('removes the browser, pauses its origin 10 min and emits', () async {
      final (browser, token) = await store.pair(origin: _origin, label: 'C');
      final emitted = expectLater(store.revoked, emits(isA<PairedBrowser>()));

      await store.revoke(browser.id);
      await emitted;

      expect(store.state.browsers, isEmpty);
      expect(store.authenticate(token), isNull);
      expect(store.pauseRemaining(_origin), const Duration(minutes: 10));
      now = now.add(const Duration(minutes: 4));
      expect(store.pauseRemaining(_origin), const Duration(minutes: 6));
      now = now.add(const Duration(minutes: 6));
      expect(store.pauseRemaining(_origin), isNull);
    });

    test('unknown id is a no-op', () async {
      await store.pair(origin: _origin, label: 'C');
      await store.revoke('nope');
      expect(store.state.browsers, hasLength(1));
      expect(store.pauseRemaining(_origin), isNull);
    });

    test(
      'revokeAll removes everything, pauses every origin, emits each',
      () async {
        final (a, _) = await store.pair(origin: _origin, label: 'C');
        final (b, _) = await store.pair(origin: _other, label: 'F');
        final emitted = expectLater(
          store.revoked.map((x) => x.id),
          emitsInAnyOrder([a.id, b.id]),
        );

        await store.revokeAll();
        await emitted;

        expect(store.state.browsers, isEmpty);
        expect(store.pauseRemaining(_origin), const Duration(minutes: 10));
        expect(store.pauseRemaining(_other), const Duration(minutes: 10));
      },
    );
  });

  group('block', () {
    test('block / isBlocked / unblock', () async {
      expect(store.isBlocked(_origin), isFalse);
      await store.block(_origin);
      expect(store.isBlocked(_origin), isTrue);
      expect(store.isBlocked(_other), isFalse);
      await store.unblock(_origin);
      expect(store.isBlocked(_origin), isFalse);
    });
  });

  group('persistence', () {
    test('a new instance reloads browsers, blocks and pauses', () async {
      final (browser, token) = await store.pair(origin: _origin, label: 'C');
      final (gone, _) = await store.pair(origin: _other, label: 'F');
      await store.revoke(gone.id);
      await store.block('https://evil.example');

      final reloaded = newStore();
      expect(reloaded.state.browsers.map((b) => b.id), [browser.id]);
      expect(reloaded.authenticate(token)?.id, browser.id);
      expect(reloaded.isBlocked('https://evil.example'), isTrue);
      expect(reloaded.pauseRemaining(_other), const Duration(minutes: 10));
      reloaded.dispose();
    });

    test(
      'corrupt or odd values give an empty state without throwing',
      () async {
        for (final bad in [
          'not json',
          '[]',
          '42',
          '{"browsers": 3, "blockedOrigins": "x", "pausedUntil": []}',
          '{"browsers": [1, {"id": 5}, null], "pausedUntil": {"o": 7}}',
        ]) {
          await prefs.setString(_key, bad);
          final s = newStore();
          expect(s.state.browsers, isEmpty, reason: bad);
          expect(s.state.blockedOrigins, isEmpty, reason: bad);
          expect(s.state.pausedUntil, isEmpty, reason: bad);
          s.dispose();
        }
      },
    );

    test('missing key gives an empty state', () {
      expect(store.state.browsers, isEmpty);
    });

    test('expired pauses are dropped on load', () async {
      await prefs.setString(
        _key,
        jsonEncode({
          'browsers': [],
          'blockedOrigins': [],
          'pausedUntil': {
            _origin: now.subtract(const Duration(seconds: 1)).toIso8601String(),
            _other: now.add(const Duration(minutes: 3)).toIso8601String(),
          },
        }),
      );
      final s = newStore();
      expect(s.state.pausedUntil.keys, [_other]);
      expect(s.pauseRemaining(_origin), isNull);
      expect(s.pauseRemaining(_other), const Duration(minutes: 3));
      s.dispose();
    });
  });
}
