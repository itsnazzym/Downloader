import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/core/security/paired_browsers.dart';
import 'package:tapload/core/security/pairing_coordinator.dart';
import 'package:tapload/core/services/local_server_service.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/entities/download_request.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';

import '../../visual/visual_fakes.dart';

const _manual = 'manual-token-abc';
const _ext = 'chrome-extension://abcdefghijklmnopabcdefghijklmnop';
const _ext2 = 'moz-extension://9a8b7c6d-1111-2222-3333-444455556666';
const _chromeUa =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
const _edgeUa = '$_chromeUa Edg/131.0.0.0';

// Short real server delays; the coordinator's 2-min expiry is a fake timer.
const _hello = Duration(milliseconds: 500);
const _window = Duration(milliseconds: 500);
const _keepAlive = Duration(milliseconds: 100);
const _wait = Duration(seconds: 3);

class _FakeTimer implements Timer {
  _FakeTimer(this.callback);
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

/// Always draws [value]: the comparison code becomes '0007'.
class _FixedRandom implements Random {
  @override
  int nextInt(int max) => 7 % max;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

/// The store only uses getString / setString; writes can be made to fail.
class _FailablePrefs implements SharedPreferences {
  _FailablePrefs(this._inner);
  final SharedPreferences _inner;
  bool failWrites = false;

  @override
  String? getString(String key) => _inner.getString(key);

  @override
  Future<bool> setString(String key, String value) {
    if (failWrites) return Future.error(StateError('disk full'));
    return _inner.setString(key, value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One client socket with a readable inbox (THEME / LIBRARY_KEYS skipped).
class _Peer {
  _Peer(this.ws) {
    ws.listen(
      (event) {
        final m = jsonDecode(event as String) as Map<String, dynamic>;
        types.add(m['type'] as String?);
        if (m['type'] == 'THEME' || m['type'] == 'LIBRARY_KEYS_RESULT') return;
        inbox.add(m);
        _wake();
      },
      onDone: () {
        if (!closed.isCompleted) closed.complete();
        _wake();
      },
    );
  }

  final WebSocket ws;
  final inbox = <Map<String, dynamic>>[];
  final types = <String?>[]; // every message type received, THEME included
  final closed = Completer<void>();
  var _read = 0;
  Completer<void>? _waiter;

  bool get isClosed => closed.isCompleted;

  void _wake() {
    _waiter?.complete();
    _waiter = null;
  }

  void send(Map<String, dynamic> message) => ws.add(jsonEncode(message));

  String? _lastType;

  /// The next message; PAIR_PENDING reminders after a PAIR_PENDING are
  /// skipped so the keep-alive rhythm never shifts what a test reads.
  Future<Map<String, dynamic>> next() async {
    while (true) {
      while (_read >= inbox.length) {
        if (isClosed) throw StateError('closed with no further message');
        _waiter ??= Completer<void>();
        await _waiter!.future.timeout(_wait);
      }
      final m = inbox[_read++];
      final reminder = m['type'] == 'PAIR_PENDING' && _lastType == m['type'];
      _lastType = m['type'] as String?;
      if (!reminder) return m;
    }
  }

  Future<void> waitClosed() => closed.future.timeout(_wait);
}

HttpClient _clientWithUa(String ua) {
  // The test binding fakes every HttpClient; a real one is needed to send a
  // single User-Agent (WebSocket.connect headers would add a second one).
  final previous = HttpOverrides.current;
  HttpOverrides.global = null;
  try {
    return HttpClient()..userAgent = ua;
  } finally {
    HttpOverrides.global = previous;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late _FailablePrefs storePrefs;
  late PairedBrowsersStore store;
  late List<_FakeTimer> expiryTimers;
  late Random coordinatorRandom;
  late ProviderContainer container;
  late LocalServerService server;
  late int notifications;
  late List<String> logs;
  late List<HttpClient> clients;
  late FakeDownloaderRepository repo;

  PairingCoordinator coordinator() =>
      container.read(pairingCoordinatorProvider.notifier);

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'api_token': _manual,
      'server_port': 0,
      'do_not_disturb': true,
    });
    final prefs = await SharedPreferences.getInstance();
    initPrefs(prefs);
    storePrefs = _FailablePrefs(prefs);
    now = DateTime.utc(2026, 11, 27, 12);
    expiryTimers = [];
    coordinatorRandom = Random(42);
    notifications = 0;
    logs = [];
    clients = [];
    repo = FakeDownloaderRepository([]);
    store = PairedBrowsersStore(
      storePrefs,
      clock: () => now,
      random: Random(7),
    );

    container = ProviderContainer(
      overrides: [
        downloaderRepositoryProvider.overrideWithValue(repo),
        pairedBrowsersProvider.overrideWith((ref) => store),
        pairingCoordinatorProvider.overrideWith(
          (ref) => PairingCoordinator(
            ref.watch(pairedBrowsersProvider.notifier),
            clock: () => now,
            random: coordinatorRandom,
            schedule: (d, cb) {
              final t = _FakeTimer(cb);
              expiryTimers.add(t);
              return t;
            },
          ),
        ),
        localServerServiceProvider.overrideWith(
          (ref) => LocalServerService(
            ref,
            onExtensionFlush: (_) {},
            helloTimeout: _hello,
            pairRequestWindow: _window,
            pendingKeepAlive: _keepAlive,
            maxUnauthenticatedSockets: 9,
            showExtensionConnected: () async => notifications++,
          ),
        ),
      ],
    );
    server = container.read(localServerServiceProvider);
    // Server callbacks run in this zone: every log line is captured.
    await runZoned(
      server.start,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logs.add(line),
      ),
    );
    expect(server.boundPort, greaterThan(0));
  });

  tearDown(() async {
    await server.stop();
    container.dispose();
    for (final c in clients) {
      c.close(force: true);
    }
  });

  Future<_Peer> open({String? origin = _ext, String ua = _chromeUa}) async {
    final client = _clientWithUa(ua);
    clients.add(client);
    final ws = await WebSocket.connect(
      'ws://127.0.0.1:${server.boundPort}/',
      headers: origin == null ? null : {'Origin': origin},
      customClient: client,
    );
    final peer = _Peer(ws);
    addTearDown(() => ws.close().timeout(_wait, onTimeout: () {}));
    return peer;
  }

  /// Hand-written upgrade request (HttpClient cannot repeat a header line);
  /// returns the response head.
  Future<String> rawUpgrade(List<String> extraLines) async {
    final socket = await Socket.connect('127.0.0.1', server.boundPort!);
    addTearDown(socket.destroy);
    socket.write(
      [
        'GET / HTTP/1.1',
        'Host: 127.0.0.1:${server.boundPort}',
        'Connection: Upgrade',
        'Upgrade: websocket',
        'Sec-WebSocket-Version: 13',
        'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==',
        ...extraLines,
        '',
        '',
      ].join('\r\n'),
    );
    return latin1.decode(await socket.first.timeout(_wait));
  }

  /// HELLO without a token, then PAIR_REQUEST; returns the PAIR_PENDING.
  Future<Map<String, dynamic>> requestPairing(
    _Peer p, {
    Map<String, dynamic> extra = const {},
  }) async {
    p.send({'type': 'HELLO', 'version': '2.2.0'});
    expect(await p.next(), {
      'type': 'AUTH_FAILED',
      'reason': 'pairing_required',
    });
    p.send({'type': 'PAIR_REQUEST', 'extensionVersion': '2.2.0', ...extra});
    return p.next();
  }

  /// Full pairing through the protocol; returns the issued token.
  Future<String> pairBrowser({String origin = _ext}) async {
    final p = await open(origin: origin);
    final pending = await requestPairing(p);
    expect(pending['type'], 'PAIR_PENDING');
    expect(await coordinator().approve(pending['requestId'] as String), isTrue);
    final ok = await p.next();
    expect(ok['type'], 'PAIR_OK');
    await p.waitClosed();
    return ok['token'] as String;
  }

  Future<void> settle([Duration d = const Duration(milliseconds: 150)]) =>
      Future<void>.delayed(d);

  void expectCleanLogs({List<String> secrets = const []}) {
    expect(logs.where((l) => l.startsWith('[ERROR]')), isEmpty);
    for (final s in secrets) {
      expect(logs.where((l) => l.contains(s)), isEmpty, reason: 'leaked');
    }
  }

  group('authentication', () {
    test('the manual token still gets HELLO_OK, with or without an extension '
        'Origin, and notifies once per session', () async {
      for (final origin in [null, _ext]) {
        final p = await open(origin: origin);
        p.send({'type': 'HELLO', 'token': _manual});
        expect((await p.next())['type'], 'HELLO_OK', reason: '$origin');
        p.send({'type': 'PING'});
        expect((await p.next())['type'], 'PONG');
        await p.ws.close();
      }
      expect(notifications, 1);
      expectCleanLogs(secrets: [_manual]);
    });

    test('no Origin and no token: plain AUTH_FAILED, then close', () async {
      final p = await open(origin: null);
      p.send({'type': 'HELLO'});
      expect(await p.next(), {'type': 'AUTH_FAILED'});
      await p.waitClosed();
    });

    test(
      'no Origin and a wrong token: plain AUTH_FAILED, then close',
      () async {
        final p = await open(origin: null);
        p.send({'type': 'HELLO', 'token': 'A' * 43});
        expect(await p.next(), {'type': 'AUTH_FAILED'});
        await p.waitClosed();
      },
    );

    test('an extension with a missing, empty, non-string or unknown token is '
        'asked to pair', () async {
      for (final token in <Object?>[null, '', 42, 'wrong', 'B' * 43]) {
        final p = await open();
        p.send({'type': 'HELLO', if (token != null) 'token': token});
        expect(await p.next(), {
          'type': 'AUTH_FAILED',
          'reason': 'pairing_required',
        }, reason: '$token');
        await p.ws.close();
      }
      expect(coordinator().state, isNull); // HELLO alone never invites
    });

    test(
      'other messages before authentication stay not_authenticated',
      () async {
        final p = await open();
        p.send({'type': 'PING'});
        expect(await p.next(), {
          'type': 'AUTH_FAILED',
          'reason': 'not_authenticated',
        });
      },
    );

    test(
      'without PAIR_REQUEST the socket is closed after the window',
      () async {
        final p = await open();
        p.send({'type': 'HELLO'});
        await p.next();
        await p.waitClosed();
        expect(coordinator().state, isNull);
      },
    );

    test('HELLO timeout still closes a silent socket', () async {
      final p = await open();
      expect(await p.next(), {
        'type': 'AUTH_FAILED',
        'reason': 'hello_timeout',
      });
      await p.waitClosed();
    });
  });

  group('pairing', () {
    test('PAIR_REQUEST gets PAIR_PENDING with a 4-digit code', () async {
      final p = await open();
      final pending = await requestPairing(p);
      final request = coordinator().state!;

      expect(pending, {
        'type': 'PAIR_PENDING',
        'requestId': request.id,
        'code': request.code,
        'expiresInSeconds': 120,
      });
      expect(pending['code'], matches(RegExp(r'^\d{4}$')));
      expect(request.origin, _ext);
      expect(request.label, 'Chrome');
      expectCleanLogs(secrets: [request.code]);
    });

    test('PAIR_REQUEST before AUTH_FAILED pairing_required is '
        'not_authenticated; after it, it is accepted', () async {
      final p = await open();
      p.send({'type': 'PAIR_REQUEST'});
      expect(await p.next(), {
        'type': 'AUTH_FAILED',
        'reason': 'not_authenticated',
      });
      expect(coordinator().state, isNull);
      expect((await requestPairing(p))['type'], 'PAIR_PENDING');
    });

    test(
      'PAIR_REQUEST from an authenticated extension socket is ignored',
      () async {
        final p = await open();
        p.send({'type': 'HELLO', 'token': _manual});
        expect((await p.next())['type'], 'HELLO_OK');
        p.send({'type': 'PAIR_REQUEST'});
        p.send({'type': 'PING'});
        expect(await p.next(), {'type': 'PONG'});
        expect(coordinator().state, isNull);
      },
    );

    test('a small code is still sent as a 4-character string', () async {
      coordinatorRandom = _FixedRandom();
      final p = await open();
      final pending = await requestPairing(p);
      expect(pending['code'], '0007');
    });

    test(
      'approve sends PAIR_OK, closes, and the token then authenticates',
      () async {
        final p = await open();
        final pending = await requestPairing(p);
        expect(
          await coordinator().approve(pending['requestId'] as String),
          isTrue,
        );
        final ok = await p.next();
        expect(ok.keys, unorderedEquals(['type', 'token']));
        expect(ok['type'], 'PAIR_OK');
        final token = ok['token'] as String;
        await p.waitClosed();
        expect(notifications, 1);
        expect(store.state.browsers.single.lastSeenAt, isNull);

        now = now.add(const Duration(minutes: 5));
        final again = await open();
        again.send({'type': 'HELLO', 'token': token});
        expect((await again.next())['type'], 'HELLO_OK');
        expect(store.state.browsers.single.lastSeenAt, now);
        expect(container.read(extensionConnectedClientsProvider), 1);
        expect(notifications, 1, reason: 'no second notification on reconnect');
        expectCleanLogs(secrets: [token]);
      },
    );

    test('a browser paired in an earlier session notifies on its first '
        'connection only, each browser once', () async {
      final (_, first) = await store.pair(origin: _ext, label: 'Chrome');
      final (_, second) = await store.pair(origin: _ext2, label: 'Firefox');

      for (final token in [first, first, second]) {
        final p = await open();
        p.send({'type': 'HELLO', 'token': token});
        expect((await p.next())['type'], 'HELLO_OK');
        await p.ws.close();
        await p.waitClosed();
      }
      expect(notifications, 2);
    });

    test('a paired token also works without Origin (local tool)', () async {
      final token = await pairBrowser();
      final p = await open(origin: null);
      p.send({'type': 'HELLO', 'token': token});
      expect((await p.next())['type'], 'HELLO_OK');
    });

    test('deny sends PAIR_DENIED, then a new request is PAIR_PAUSED', () async {
      final p = await open();
      final pending = await requestPairing(p);
      await coordinator().deny(pending['requestId'] as String);
      expect(await p.next(), {'type': 'PAIR_DENIED', 'retryAfterSeconds': 600});
      await p.waitClosed();

      now = now.add(const Duration(minutes: 1));
      final again = await open();
      expect(await requestPairing(again), {
        'type': 'PAIR_PAUSED',
        'retryAfterSeconds': 540,
      });
      await again.waitClosed();
    });

    test(
      'deny(always) sends PAIR_DENIED for a day, and so does a new request',
      () async {
        final p = await open();
        final pending = await requestPairing(p);
        await coordinator().deny(pending['requestId'] as String, always: true);
        expect(await p.next(), {
          'type': 'PAIR_DENIED',
          'retryAfterSeconds': 86400,
        });
        await p.waitClosed();

        final again = await open();
        expect(await requestPairing(again), {
          'type': 'PAIR_DENIED',
          'retryAfterSeconds': 86400,
        });
        await again.waitClosed();
        expect(coordinator().state, isNull);
      },
    );

    test('the 4th request within the hour is PAIR_PAUSED', () async {
      for (var i = 0; i < 3; i++) {
        final p = await open();
        expect((await requestPairing(p))['type'], 'PAIR_PENDING');
        expiryTimers.last.fire();
        expect(await p.next(), {'type': 'PAIR_EXPIRED'});
        now = now.add(const Duration(minutes: 10));
      }
      final p = await open();
      expect(await requestPairing(p), {
        'type': 'PAIR_PAUSED',
        'retryAfterSeconds': 1800,
      });
    });

    test('expiry sends PAIR_EXPIRED, then close', () async {
      final p = await open();
      await requestPairing(p);
      expiryTimers.single.fire();
      expect(await p.next(), {'type': 'PAIR_EXPIRED'});
      await p.waitClosed();
      expect(store.state.browsers, isEmpty);
    });

    test('a socket without Origin can never request pairing', () async {
      final p = await open(origin: null);
      p.send({'type': 'PAIR_REQUEST'});
      expect(await p.next(), {
        'type': 'AUTH_FAILED',
        'reason': 'not_authenticated',
      });
      p.send({'type': 'HELLO'});
      expect(await p.next(), {'type': 'AUTH_FAILED'});
      await p.waitClosed();
      expect(coordinator().state, isNull);
    });

    test('PAIR_REQUEST is accepted once per socket', () async {
      final p = await open();
      final pending = await requestPairing(p);
      p.send({'type': 'PAIR_REQUEST'});
      expect(await p.next(), {
        'type': 'AUTH_FAILED',
        'reason': 'not_authenticated',
      });
      expect(coordinator().state!.id, pending['requestId']);
    });

    test('the origin comes from the header and the label from the '
        'User-Agent, never from the message body', () async {
      final p = await open(ua: _edgeUa);
      final pending = await requestPairing(
        p,
        extra: {
          'origin': 'chrome-extension://evilevilevilevilevil',
          'label': 'Trusted',
          'browser': 'Trusted',
        },
      );
      expect(pending['type'], 'PAIR_PENDING');
      expect(coordinator().state!.origin, _ext);
      expect(coordinator().state!.label, 'Edge');
    });

    test('an unknown User-Agent gives the neutral label', () async {
      final p = await open(ua: 'curl/8.0');
      await requestPairing(p);
      expect(coordinator().state!.label, 'Navigateur');
    });

    test('two User-Agent header lines do not break the upgrade', () async {
      final head = await rawUpgrade([
        'Origin: $_ext',
        'User-Agent: $_chromeUa',
        'User-Agent: $_edgeUa',
      ]);
      expect(head.split('\r\n').first, contains('101'));
    });
  });

  group('one request per origin', () {
    // The code is known only to the one live socket that will get the token:
    // a same-origin newcomer (a local process can forge the Origin) is never
    // handed the pending request, its code, or the token.
    test('while the first socket waits, a newer same-origin socket gets '
        'PAIR_BUSY without a code and is closed; the token goes to the '
        'first', () async {
      final a = await open();
      final b = await open();
      final pa = await requestPairing(a);
      expect(await requestPairing(b), {'type': 'PAIR_BUSY'});
      await b.waitClosed();
      expect(b.inbox.where((m) => m.containsKey('code')), isEmpty);
      expect(coordinator().state!.id, pa['requestId']);

      expect(await coordinator().approve(pa['requestId'] as String), isTrue);
      expect((await a.next())['type'], 'PAIR_OK');
      await a.waitClosed();
      expect(b.inbox.where((m) => m['type'] == 'PAIR_OK'), isEmpty);
      expect(store.state.browsers, hasLength(1));
      expect(notifications, 1);
      await settle();
      expect(server.liveConnectionCount, 0);
    });

    test(
      'a same-origin socket that never sent PAIR_REQUEST gets no token',
      () async {
        final asker = await open();
        final idle = await open();
        idle.send({'type': 'HELLO'});
        expect((await idle.next())['reason'], 'pairing_required');
        final pending = await requestPairing(asker);
        await coordinator().approve(pending['requestId'] as String);
        expect((await asker.next())['type'], 'PAIR_OK');
        await idle.waitClosed();
        expect(idle.inbox.where((m) => m['type'] == 'PAIR_OK'), isEmpty);
      },
    );

    test('the waiting socket closing withdraws the request; a reconnect '
        'gets a new request id and a new code, and the token', () async {
      final first = await open();
      final pending = await requestPairing(first);
      await first.ws.close();
      await first.waitClosed();
      await settle();
      expect(coordinator().state, isNull);
      expect(store.pauseRemaining(_ext), isNull);

      final second = await open();
      final renewed = await requestPairing(second);
      expect(renewed['type'], 'PAIR_PENDING');
      expect(renewed['requestId'], isNot(pending['requestId']));
      expect(renewed['code'], isNot(pending['code']));
      expect(
        await coordinator().approve(pending['requestId'] as String),
        isFalse,
      );
      expect(
        await coordinator().approve(renewed['requestId'] as String),
        isTrue,
      );
      expect((await second.next())['type'], 'PAIR_OK');
    });

    test('another origin while one is pending gets PAIR_BUSY', () async {
      final a = await open();
      await requestPairing(a);
      final b = await open(origin: _ext2);
      expect(await requestPairing(b), {'type': 'PAIR_BUSY'});
      await b.waitClosed();
    });

    test(
      'a full store gets PAIR_BUSY at submit, before any invitation',
      () async {
        for (var i = 0; i < 20; i++) {
          await store.pair(origin: 'chrome-extension://full$i', label: 'x');
        }
        final p = await open();
        expect(await requestPairing(p), {'type': 'PAIR_BUSY'});
        await p.waitClosed();
        expect(coordinator().state, isNull);
      },
    );
  });

  group('approval only through the app', () {
    test('no WebSocket message can approve a pending request', () async {
      final p = await open();
      final pending = await requestPairing(p);
      final id = pending['requestId'];
      final code = pending['code'];
      // An already authenticated (manual token) socket cannot approve either.
      final admin = await open(origin: null);
      admin.send({'type': 'HELLO', 'token': _manual});
      expect((await admin.next())['type'], 'HELLO_OK');

      for (final type in [
        'APPROVE',
        'PAIR_APPROVE',
        'PAIR_ALLOW',
        'PAIR_ACCEPT',
        'PAIR_OK',
        'PAIR_CONFIRM',
        'PAIR_REQUEST',
        'HELLO',
      ]) {
        final message = {
          'type': type,
          'requestId': id,
          'id': id,
          'code': code,
          'approve': true,
          'always': false,
        };
        p.send(message);
        admin.send(message);
      }
      await settle(const Duration(milliseconds: 300));

      expect(coordinator().state?.id, id);
      expect(store.state.browsers, isEmpty);
      for (final m in [...p.inbox, ...admin.inbox]) {
        expect(m['type'], isNot('PAIR_OK'));
        expect(m.containsKey('token'), isFalse);
      }
    });
  });

  group('held-open pending socket', () {
    test('PAIR_PENDING repeats with the countdown while the socket stays open '
        'past the HELLO and PAIR_REQUEST windows', () async {
      final p = await open();
      await requestPairing(p);
      now = now.add(const Duration(seconds: 30));
      await settle(_hello + _window + const Duration(milliseconds: 200));

      final pendings = p.inbox.where((m) => m['type'] == 'PAIR_PENDING');
      expect(pendings.length, greaterThanOrEqualTo(4));
      expect(pendings.last['expiresInSeconds'], 90);
      expect(pendings.map((m) => m['code']).toSet(), hasLength(1));
      expect(p.isClosed, isFalse);
      expect(p.ws.readyState, WebSocket.open);
    });

    test('closing sockets stops their timers', () async {
      final waiting = await open();
      await requestPairing(waiting);
      final windowed = await open();
      windowed.send({'type': 'HELLO'});
      await windowed.next();
      final silent = await open();
      await settle();
      expect(server.liveConnectionCount, 3);

      await Future.wait([
        waiting.ws.close(),
        windowed.ws.close(),
        silent.ws.close(),
      ]);
      await settle();
      expect(server.liveConnectionCount, 0);
      // Past every delay: a timer still running would log or throw here.
      await settle(_hello + _window + _keepAlive * 3);
      // Its only socket is gone: the request is withdrawn, not left dangling.
      expect(coordinator().state, isNull);
      expectCleanLogs();
      expect(logs.where((l) => l.startsWith('[WARN]')), isEmpty);
    });

    test('stop closes pending sockets too', () async {
      final p = await open();
      await requestPairing(p);
      await server.stop();
      await p.waitClosed();
      expect(server.liveConnectionCount, 0);
    });
  });

  group('revocation', () {
    test('revoke closes that browser socket at once; others stay', () async {
      final token = await pairBrowser();
      final paired = await open();
      paired.send({'type': 'HELLO', 'token': token});
      expect((await paired.next())['type'], 'HELLO_OK');
      final manual = await open(origin: null);
      manual.send({'type': 'HELLO', 'token': _manual});
      expect((await manual.next())['type'], 'HELLO_OK');
      expect(container.read(extensionConnectedClientsProvider), 2);

      await store.revoke(store.state.browsers.single.id);
      await paired.waitClosed();
      expect(container.read(extensionConnectedClientsProvider), 1);
      manual.send({'type': 'PING'});
      expect((await manual.next())['type'], 'PONG');
    });

    test('a revoke whose save fails still closes the socket', () async {
      final token = await pairBrowser();
      final paired = await open();
      paired.send({'type': 'HELLO', 'token': token});
      expect((await paired.next())['type'], 'HELLO_OK');

      storePrefs.failWrites = true;
      await expectLater(
        store.revoke(store.state.browsers.single.id),
        throwsStateError,
      );
      await paired.waitClosed();
    });

    test('revoke then an immediate reconnect is paused, not invited', () async {
      final token = await pairBrowser();
      await store.revoke(store.state.browsers.single.id);

      final p = await open();
      p.send({'type': 'HELLO', 'token': token});
      expect(await p.next(), {
        'type': 'AUTH_FAILED',
        'reason': 'pairing_required',
      });
      p.send({'type': 'PAIR_REQUEST'});
      expect(await p.next(), {'type': 'PAIR_PAUSED', 'retryAfterSeconds': 600});
      await p.waitClosed();
      expect(coordinator().state, isNull);
    });
  });

  group('limits', () {
    test('unauthenticated sockets are capped with 503; authenticated ones do '
        'not count; a freed slot is reused', () async {
      final admin = await open(origin: null);
      admin.send({'type': 'HELLO', 'token': _manual});
      expect((await admin.next())['type'], 'HELLO_OK');
      // One pending socket and 8 silent ones fill the cap (9), opened at
      // once so all are inside the HELLO timeout.
      await requestPairing(await open());
      final silents = await Future.wait(List.generate(8, (_) => open()));
      final silent = silents.first;
      await settle(const Duration(milliseconds: 50));
      await expectLater(
        open(),
        throwsA(
          isA<WebSocketException>().having(
            (e) => e.toString(),
            'status',
            contains('status code: 503'),
          ),
        ),
      );

      await silent.ws.close();
      await silent.waitClosed();
      await settle();
      final p = await open();
      p.send({'type': 'HELLO', 'token': _manual});
      expect((await p.next())['type'], 'HELLO_OK');
    });

    test('binary, invalid and non-object frames before authentication close '
        'the socket cleanly', () async {
      for (final frame in <Object>[
        <int>[1, 2, 3],
        'not json',
        '[1, 2]',
        '"text"',
        '42',
        '{"type": 5}',
      ]) {
        final p = await open();
        p.ws.add(frame);
        await p.waitClosed();
        expect(p.inbox, isEmpty, reason: '$frame');
      }
      expectCleanLogs();
      final ok = await open();
      ok.send({'type': 'HELLO', 'token': _manual});
      expect((await ok.next())['type'], 'HELLO_OK');
    });

    test('after authentication a malformed frame keeps the socket and is '
        'logged by error type only', () async {
      final p = await open();
      p.send({'type': 'HELLO', 'token': _manual});
      expect((await p.next())['type'], 'HELLO_OK');
      p.ws.add('{"token": "SECRET-abc'); // FormatException quotes its source
      p.send({'type': 'PING'});
      expect((await p.next())['type'], 'PONG');
      final errors = logs.where((l) => l.contains('Error parsing WS message'));
      expect(errors.single, contains('FormatException'));
      expect(logs.where((l) => l.contains('SECRET')), isEmpty);
    });

    test('an unauthenticated frame over 4 KB closes the socket and is not '
        'logged', () async {
      final p = await open();
      p.send({'type': 'HELLO', 'token': 'Z' * 5000});
      await p.waitClosed();
      expect(p.inbox, isEmpty);
      expect(logs.where((l) => l.contains('ZZZZ')), isEmpty);
      expect(logs.where((l) => l.contains('frame refused')), hasLength(1));
    });

    test('the 6th failed HELLO closes the socket', () async {
      final p = await open();
      for (var i = 0; i < 6; i++) {
        p.send({'type': 'HELLO', 'token': 'wrong'});
      }
      await p.waitClosed();
      expect(
        p.inbox,
        List.filled(5, {'type': 'AUTH_FAILED', 'reason': 'pairing_required'}),
      );
      expect(coordinator().state, isNull);
    });
  });

  group('while a request is pending', () {
    test('a valid-token HELLO on the waiting socket is refused: it stays '
        'pending and is not promoted', () async {
      final p = await open();
      final pending = await requestPairing(p);
      p.send({'type': 'HELLO', 'token': _manual});
      expect(await p.next(), {
        'type': 'AUTH_FAILED',
        'reason': 'not_authenticated',
      });
      expect(container.read(extensionConnectedClientsProvider), 0);
      p.send({'type': 'PING'});
      expect(await p.next(), {
        'type': 'AUTH_FAILED',
        'reason': 'not_authenticated',
      });

      await coordinator().approve(pending['requestId'] as String);
      expect((await p.next())['type'], 'PAIR_OK');
    });

    test('revoking a browser of the same origin keeps the request: approving '
        'stays the user\'s deliberate click', () async {
      final (browser, token) = await store.pair(origin: _ext, label: 'Chrome');
      final paired = await open();
      paired.send({'type': 'HELLO', 'token': token});
      expect((await paired.next())['type'], 'HELLO_OK');
      final waiting = await open();
      final pending = await requestPairing(waiting);

      await store.revoke(browser.id);
      await paired.waitClosed();
      expect(store.pauseRemaining(_ext), isNotNull);
      await settle(_keepAlive * 2);
      expect(waiting.isClosed, isFalse);
      expect(coordinator().state!.id, pending['requestId']);

      expect(
        await coordinator().approve(pending['requestId'] as String),
        isTrue,
      );
      expect((await waiting.next())['type'], 'PAIR_OK');
    });

    test('the waiting socket gets no PROGRESS or THEME broadcast', () async {
      final admin = await open(origin: null);
      admin.send({'type': 'HELLO', 'token': _manual});
      expect((await admin.next())['type'], 'HELLO_OK');
      final p = await open();
      await requestPairing(p);

      repo.emit(
        DownloadItem(
          id: 'd1',
          request: DownloadRequest(url: 'https://www.youtube.com/watch?v=d1'),
          status: DownloadStatus.completed,
        ),
      );
      container.read(settingsProvider.notifier).setThemePreset('pastille');
      expect((await admin.next())['type'], 'PROGRESS');
      await settle();
      expect(admin.types.where((t) => t == 'THEME'), hasLength(2));
      expect(p.types, isNot(contains('PROGRESS')));
      expect(p.types, isNot(contains('THEME')));
      expect(p.isClosed, isFalse);
    });

    test('a pairing the store cannot save gets PAIR_BUSY, not a 10-minute '
        'PAIR_DENIED', () async {
      final p = await open();
      final pending = await requestPairing(p);
      storePrefs.failWrites = true;
      expect(
        await coordinator().approve(pending['requestId'] as String),
        isFalse,
      );
      expect(await p.next(), {'type': 'PAIR_BUSY'});
      await p.waitClosed();
      expect(store.pauseRemaining(_ext), isNull);
    });
  });

  test('disposing the container stops the real provider\'s server', () async {
    final own = ProviderContainer(
      overrides: [
        downloaderRepositoryProvider.overrideWithValue(repo),
        pairedBrowsersProvider.overrideWith(
          (ref) => PairedBrowsersStore(storePrefs, clock: () => now),
        ),
      ],
    );
    final real = own.read(localServerServiceProvider);
    await real.start();
    final client = _clientWithUa(_chromeUa);
    clients.add(client);
    final p = _Peer(
      await WebSocket.connect(
        'ws://127.0.0.1:${real.boundPort}/',
        customClient: client,
      ),
    );
    p.send({'type': 'HELLO', 'token': _manual});
    expect((await p.next())['type'], 'HELLO_OK');

    own.dispose();
    await p.waitClosed();
    for (var i = 0; i < 20 && real.boundPort != null; i++) {
      await settle();
    }
    expect(real.boundPort, isNull);
  });

  group('upgrade errors', () {
    test('a duplicated Sec-WebSocket-Extensions header gets 400 and the '
        'server stays healthy', () async {
      final head = await rawUpgrade([
        'Sec-WebSocket-Extensions: permessage-deflate',
        'Sec-WebSocket-Extensions: permessage-deflate',
      ]);
      expect(head.split('\r\n').first, contains('400'));
      expect(head.toLowerCase(), isNot(contains('sec-websocket-accept')));

      final p = await open(origin: null);
      p.send({'type': 'HELLO', 'token': _manual});
      expect((await p.next())['type'], 'HELLO_OK');
    });
  });
}
