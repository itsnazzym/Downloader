import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapload/core/security/paired_browsers.dart';

const _key = 'paired_browsers_v1';
const _origin = 'chrome-extension://abcdefghijklmnopabcdefghijklmnop';
const _other = 'moz-extension://11111111-2222-3333-4444-555555555555';

void main() {
  late _CountingPrefs prefs;
  late DateTime now;
  late PairedBrowsersStore store;

  PairedBrowsersStore newStore({Random? random}) =>
      PairedBrowsersStore(prefs, clock: () => now, random: random);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = _CountingPrefs(await SharedPreferences.getInstance());
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

    test(
      '5000 authentications: all correct, at most one prefs write',
      () async {
        final (browser, token) = await store.pair(origin: _origin, label: 'C');
        final writesBefore = prefs.writes;
        for (var i = 0; i < 5000; i++) {
          if (i.isEven) {
            expect(store.authenticate(token)?.id, browser.id);
          } else {
            expect(
              store.authenticate('A' * 42 + String.fromCharCode(65 + i % 26)),
              isNull,
            );
          }
        }
        expect(prefs.writes - writesBefore, lessThanOrEqualTo(1));
      },
    );

    test('lastSeenAt throttle is measured against the STORED value', () async {
      final (_, token) = await store.pair(origin: _origin, label: 'C');
      final base = prefs.writes;

      store.authenticate(token); // never stored -> writes
      expect(prefs.writes, base + 1);

      now = now.add(const Duration(seconds: 30));
      store.authenticate(token); // in memory only
      expect(prefs.writes, base + 1);
      expect(store.state.browsers.single.lastSeenAt, now);

      now = now.add(const Duration(seconds: 29)); // 59 s after the write
      store.authenticate(token);
      expect(prefs.writes, base + 1);

      now = now.add(const Duration(seconds: 2)); // 61 s after the write
      store.authenticate(token);
      expect(prefs.writes, base + 2);
      await Future<void>.delayed(Duration.zero);
      final stored = jsonDecode(prefs.getString(_key)!) as Map;
      expect(
        (stored['browsers'] as List).single['lastSeenAt'],
        now.toIso8601String(),
      );
    });

    test('a failing prefs write never throws out of authenticate', () async {
      final (_, token) = await store.pair(origin: _origin, label: 'C');
      prefs.failWrites = true;
      expect(store.authenticate(token), isNotNull);
      await Future<void>.delayed(
        Duration.zero,
      ); // unhandled error would fail the test
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

  group('pauseOrigin', () {
    test('pauses 10 min by default without removing anything', () async {
      final (b, _) = await store.pair(origin: _origin, label: 'C');
      await store.pauseOrigin(_origin);

      expect(store.pauseRemaining(_origin), const Duration(minutes: 10));
      expect(store.pauseRemaining(_other), isNull);
      expect(store.state.browsers, [b]);
      now = now.add(const Duration(minutes: 10));
      expect(store.pauseRemaining(_origin), isNull);
    });

    test('custom duration, persisted, cleaned origin, bounded', () async {
      await store.pauseOrigin(
        'https://ev\nil.example',
        duration: const Duration(minutes: 3),
      );
      expect(
        store.pauseRemaining('https://evil.example'),
        const Duration(minutes: 3),
      );
      expect(newStore().pauseRemaining('https://evil.example'), isNotNull);

      for (var i = 0; i < 150; i++) {
        await store.pauseOrigin('https://o$i.example');
      }
      expect(store.state.pausedUntil.length, 100);
      expect(store.pauseRemaining('https://o149.example'), isNotNull);
    });

    test('throws ArgumentError on an empty origin', () {
      expect(() => store.pauseOrigin('​ '), throwsArgumentError);
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

  group('cleaners', () {
    // 19-char scheme prefix + 180 'a' puts a space at rune 200 (index 199).
    final spaceAtCap = 'chrome-extension://${'a' * 180} bbbb';
    final tricky = [
      '',
      '   ',
      _origin,
      ' $_origin\n',
      spaceAtCap,
      '${'x' * 199}\u{1F600}tail',
      '${'y' * 79} z',
      'a\u0000b‮c​d﻿',
      'lone \uD800 surrogate',
      '   \t mixed \r\n',
      'w' * 5000,
      '${' ' * 300}inner${' ' * 300}',
    ];

    test('cleanPairingOrigin trims after the rune cap', () {
      final c = cleanPairingOrigin(spaceAtCap);
      expect(c, 'chrome-extension://${'a' * 180}');
      expect(c.runes.length, lessThanOrEqualTo(200));
    });

    test('cleanPairingOrigin strips control and invisible chars', () {
      expect(
        cleanPairingOrigin(' chrome-extension://ab\ncd‮ '),
        'chrome-extension://abcd',
      );
    });

    test('cleanPairingLabel caps, collapses and falls back', () {
      expect(cleanPairingLabel('  Chro​me \r\n Edge  '), 'Chrome Edge');
      expect(cleanPairingLabel(' \u0000 '), 'Navigateur');
      expect(cleanPairingLabel('l' * 500).runes.length, 80);
    });

    test('both cleaners are idempotent', () {
      for (final raw in tricky) {
        final o = cleanPairingOrigin(raw);
        final l = cleanPairingLabel(raw);
        expect(cleanPairingOrigin(o), o, reason: 'origin of ${raw.length}');
        expect(cleanPairingLabel(l), l, reason: 'label of ${raw.length}');
      }
    });

    test('a stored origin survives a reload unchanged', () async {
      await store.pair(origin: spaceAtCap, label: 'x');
      final s = newStore();
      expect(
        s.state.browsers.single.origin,
        store.state.browsers.single.origin,
      );
      expect(s.isBlocked(spaceAtCap), isFalse);
      s.dispose();
    });
  });

  group('bounds', () {
    test(
      'label: control/bidi chars stripped, trimmed, collapsed, <= 80',
      () async {
        final (b, _) = await store.pair(
          origin: _origin,
          label: '\u202E  Chro\u200Bme\r\n\t  \u0000 Evil\u2066  ${'x' * 200}',
        );
        expect(b.label, startsWith('Chrome Evil '));
        expect(b.label.length, lessThanOrEqualTo(80));
        expect(
          b.label,
          isNot(
            matches(
              RegExp(r'[\u0000-\u001F\u200B-\u200F\u202A-\u202E\u2066-\u2069]'),
            ),
          ),
        );
        expect(b.label, isNot(contains('  ')));
      },
    );

    test(
      'label of 5 MB is capped and the persisted JSON stays small',
      () async {
        final (b, _) = await store.pair(
          origin: _origin,
          label: 'a' * 5 * 1024 * 1024,
        );
        expect(b.label.length, lessThanOrEqualTo(80));
        expect(prefs.getString(_key)!.length, lessThan(2000));
      },
    );

    test('empty or invisible-only label falls back to Navigateur', () async {
      final (a, _) = await store.pair(origin: _origin, label: '');
      final (b, _) = await store.pair(origin: _other, label: '\u200B\u202E \n');
      expect(a.label, 'Navigateur');
      expect(b.label, 'Navigateur');
    });

    test('origin: control chars stripped and capped at 200', () async {
      final (b, _) = await store.pair(
        origin: ' chrome-extension://ab\ncd\u200B ${'z' * 5000}',
        label: 'C',
      );
      expect(b.origin, startsWith('chrome-extension://abcd'));
      expect(b.origin.length, lessThanOrEqualTo(200));
    });

    test('empty origin throws ArgumentError in pair and block', () async {
      await expectLater(
        store.pair(origin: '', label: 'C'),
        throwsArgumentError,
      );
      await expectLater(
        store.pair(origin: ' \u200B\n', label: 'C'),
        throwsArgumentError,
      );
      expect(() => store.block(''), throwsArgumentError);
      expect(store.state.browsers, isEmpty);
      expect(store.state.blockedOrigins, isEmpty);
    });

    test('21st pairing throws PairedBrowsersFull and stores nothing', () async {
      for (var i = 0; i < 20; i++) {
        expect(store.isFull, isFalse);
        await store.pair(
          origin: 'chrome-extension://abcdefghijklmnop$i',
          label: '$i',
        );
      }
      expect(store.isFull, isTrue);
      final writesBefore = prefs.writes;
      final storedBefore = prefs.getString(_key);
      await expectLater(
        store.pair(origin: _origin, label: 'x'),
        throwsA(isA<PairedBrowsersFull>()),
      );
      expect(store.state.browsers, hasLength(20));
      expect(prefs.writes, writesBefore);
      expect(prefs.getString(_key), storedBefore);
      // Revoking frees a slot.
      await store.revoke(store.state.browsers.first.id);
      expect(store.isFull, isFalse);
      await store.pair(origin: _origin, label: 'x');
      expect(store.state.browsers, hasLength(20));
    });

    test('51st blocked origin drops the oldest', () async {
      for (var i = 0; i < 51; i++) {
        await store.block('https://site$i.example');
      }
      expect(store.state.blockedOrigins, hasLength(50));
      expect(store.isBlocked('https://site0.example'), isFalse);
      expect(store.isBlocked('https://site1.example'), isTrue);
      expect(store.isBlocked('https://site50.example'), isTrue);
    });

    test(
      'block does NOT invalidate existing pairings (new invitations only)',
      () async {
        final (browser, token) = await store.pair(origin: _origin, label: 'C');
        await store.block(_origin);
        expect(store.isBlocked(_origin), isTrue);
        expect(store.authenticate(token)?.id, browser.id);
      },
    );

    test(
      'same origin twice: revoking one pauses new pairings, other still authenticates',
      () async {
        final (a, _) = await store.pair(origin: _origin, label: 'A');
        final (b, tb) = await store.pair(origin: _origin, label: 'B');
        await store.revoke(a.id);
        expect(store.pauseRemaining(_origin), const Duration(minutes: 10));
        expect(store.authenticate(tb)?.id, b.id);
      },
    );

    test(
      'concurrent mutations: memory and prefs keep the last state',
      () async {
        final results = await Future.wait([
          store.pair(origin: _origin, label: 'A'),
          store.pair(origin: _other, label: 'B'),
          store.block('https://x.example'),
          store.block('https://y.example'),
        ]);
        expect(results, hasLength(4));
        expect(store.state.browsers, hasLength(2));
        expect(store.state.blockedOrigins, {
          'https://x.example',
          'https://y.example',
        });
        final reloaded = newStore();
        expect(
          reloaded.state.browsers.map((b) => b.id).toSet(),
          store.state.browsers.map((b) => b.id).toSet(),
        );
        expect(reloaded.state.blockedOrigins, store.state.blockedOrigins);
        reloaded.dispose();
      },
    );
  });

  group('surrogates', () {
    bool wellFormed(String s) => s.runes.every((r) => r < 0xD800 || r > 0xDFFF);

    test('lone high / lone low / reversed pair become U+FFFD', () async {
      for (final bad in ['ab\uD83Dcd', 'ab\uDE00cd', 'ab\uDE00\uD83Dcd']) {
        final (b, _) = await store.pair(origin: 'o$bad', label: bad);
        expect(wellFormed(b.label), isTrue, reason: bad);
        expect(wellFormed(b.origin), isTrue, reason: bad);
        expect(b.label, contains('\uFFFD'));
        expect(b.label, startsWith('ab'));
      }
      expect(wellFormed(prefs.getString(_key)!), isTrue);
    });

    test('valid emoji are preserved', () async {
      final (b, _) = await store.pair(
        origin: _origin,
        label: 'Chrome \u{1F600}',
      );
      expect(b.label, 'Chrome \u{1F600}');
    });

    test('emoji at the 80-rune cap boundary stay well-formed', () async {
      final (b, _) = await store.pair(
        origin: _origin,
        label: 'a' * 79 + '\u{1F600}' * 5,
      );
      expect(wellFormed(b.label), isTrue);
      expect(b.label.runes.length, 80);
      expect(b.label, endsWith('\u{1F600}'));
      expect(b.label, isNot(contains('\uFFFD')));
    });

    test('999 spaces + emoji: the pre-cap never splits the pair', () async {
      for (final label in [' ' * 999 + '\u{1F600}', 'a' * 999 + '\u{1F600}']) {
        final (b, _) = await store.pair(origin: _origin, label: label);
        expect(wellFormed(b.label), isTrue);
        expect(b.label, isNot(contains('\uFFFD')));
      }
      final (o, _) = await store.pair(
        origin: 'o' * 999 + '\u{1F600}',
        label: 'C',
      );
      expect(wellFormed(o.origin), isTrue);
      expect(o.origin, isNot(contains('\uFFFD')));
    });

    test('tampered prefs with lone surrogates load well-formed', () async {
      await prefs.setString(
        _key,
        jsonEncode({
          'browsers': [
            {
              'id': 'a',
              'origin': 'x\uD83Dy',
              'label': 'l\uDE00l',
              'tokenHash': PairedBrowsersStore.hashToken('t'),
              'createdAt': now.toIso8601String(),
            },
          ],
          'blockedOrigins': ['b\uD83D'],
          'pausedUntil': {
            'p\uDE00': now.add(const Duration(minutes: 5)).toIso8601String(),
          },
        }),
      );
      final s = newStore();
      expect(wellFormed(s.state.browsers.single.label), isTrue);
      expect(wellFormed(s.state.browsers.single.origin), isTrue);
      expect(s.state.blockedOrigins.every(wellFormed), isTrue);
      expect(s.state.pausedUntil.keys.every(wellFormed), isTrue);
      s.dispose();
    });
  });

  group('origin lookups use the cleaned origin', () {
    test(
      'isBlocked / unblock / pauseRemaining find a clamped origin',
      () async {
        final longOrigin = 'https://${'a' * 300}.example';
        final dirtyOrigin = 'https://ev\nil\u200B.example\t';
        for (final raw in [longOrigin, dirtyOrigin]) {
          await store.block(raw);
          expect(store.isBlocked(raw), isTrue, reason: raw);
          await store.unblock(raw);
          expect(store.isBlocked(raw), isFalse, reason: raw);
          expect(store.state.blockedOrigins, isEmpty, reason: raw);

          final (b, _) = await store.pair(origin: raw, label: 'C');
          await store.revoke(b.id);
          expect(store.pauseRemaining(raw), const Duration(minutes: 10));
          expect(store.pauseRemaining(b.origin), const Duration(minutes: 10));
        }
      },
    );

    test('queries on empty/garbage origins return false/null, never throw', () {
      expect(store.isBlocked(''), isFalse);
      expect(store.isBlocked('\u200B\n'), isFalse);
      expect(store.pauseRemaining(''), isNull);
      expect(store.unblock(''), completes);
    });
  });

  group('tampered prefs', () {
    String hash(int i) => PairedBrowsersStore.hashToken('t$i');
    Map<String, dynamic> entry(
      String id,
      String h, {
      String origin = _origin,
      String label = 'L',
    }) => {
      'id': id,
      'origin': origin,
      'label': label,
      'tokenHash': h,
      'createdAt': now.toIso8601String(),
      'lastSeenAt': null,
    };

    test('duplicate ids and duplicate token hashes are deduped', () async {
      await prefs.setString(
        _key,
        jsonEncode({
          'browsers': [
            entry('a', hash(1)),
            entry('a', hash(2)), // dup id
            entry('b', hash(1)), // dup hash
            entry('c', hash(3)),
            entry('d', 'not-a-hash'),
            entry('e', hash(4), origin: ' \u200B'),
          ],
        }),
      );
      final s = newStore();
      expect(s.state.browsers.map((b) => b.id), ['a', 'c']);
      s.dispose();
    });

    test(
      'over-long fields and too many entries are truncated on load',
      () async {
        await prefs.setString(
          _key,
          jsonEncode({
            'browsers': [
              for (var i = 0; i < 40; i++)
                entry('id$i', hash(i), origin: 'o' * 2000, label: 'l' * 2000),
            ],
            'blockedOrigins': [
              for (var i = 0; i < 80; i++) 'https://b$i.example',
            ],
            'pausedUntil': {
              for (var i = 0; i < 300; i++)
                'o$i': now.add(const Duration(minutes: 5)).toIso8601String(),
            },
          }),
        );
        expect(prefs.getString(_key)!.length, lessThan(256 * 1024));
        final s = newStore();
        expect(s.state.browsers, hasLength(20));
        expect(
          s.state.browsers.every(
            (b) => b.label.length <= 80 && b.origin.length <= 200,
          ),
          isTrue,
        );
        expect(s.state.blockedOrigins, hasLength(50));
        expect(s.state.blockedOrigins.contains('https://b79.example'), isTrue);
        expect(s.state.pausedUntil.length, lessThanOrEqualTo(100));
        s.dispose();
      },
    );

    test(
      'a 2 MB prefs string loads without throwing and keeps nothing',
      () async {
        await prefs.setString(
          _key,
          jsonEncode({
            'browsers': [entry('a', hash(1), label: 'l' * 2 * 1024 * 1024)],
          }),
        );
        final s = newStore();
        expect(s.state.browsers, isEmpty);
        expect(s.state.blockedOrigins, isEmpty);
        expect(s.state.pausedUntil, isEmpty);
        s.dispose();
      },
    );
  });
}

/// Counts writes; every other member is unused by the store.
class _CountingPrefs implements SharedPreferences {
  _CountingPrefs(this._inner);
  final SharedPreferences _inner;
  int writes = 0;
  bool failWrites = false;

  @override
  String? getString(String key) => _inner.getString(key);

  @override
  Future<bool> setString(String key, String value) {
    writes++;
    if (failWrites) return Future.error(StateError('disk full'));
    return _inner.setString(key, value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
