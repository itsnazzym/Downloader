import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/core/security/paired_browsers.dart';
import 'package:tapload/core/security/pairing_coordinator.dart';
import 'package:tapload/core/services/local_server_service.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';

import '../../visual/visual_fakes.dart';

// End to end through the real server and the real store (mocked
// SharedPreferences): what the extension does, message by message.

const _manual = 'manual-token-abc';
const _chrome = 'chrome-extension://abcdefghijklmnopabcdefghijklmnop';
const _firefox = 'moz-extension://9a8b7c6d-1111-2222-3333-444455556666';
const _wait = Duration(seconds: 3);

class _FakeTimer implements Timer {
  _FakeTimer(this.callback);
  final void Function() callback;
  var cancelled = false;

  @override
  void cancel() => cancelled = true;
  @override
  bool get isActive => !cancelled;
  @override
  int get tick => 0;
}

/// One extension socket with a readable inbox (THEME / LIBRARY_KEYS skipped).
class _Peer {
  _Peer(this.ws) {
    ws.listen(
      (event) {
        final m = jsonDecode(event as String) as Map<String, dynamic>;
        if (m['type'] == 'THEME' || m['type'] == 'LIBRARY_KEYS_RESULT') return;
        inbox.add(m);
        _waiter?.complete();
        _waiter = null;
      },
      onDone: () {
        if (!closed.isCompleted) closed.complete();
        _waiter?.complete();
        _waiter = null;
      },
    );
  }

  final WebSocket ws;
  final inbox = <Map<String, dynamic>>[];
  final closed = Completer<void>();
  var _read = 0;
  Completer<void>? _waiter;
  String? _lastType;

  void send(Map<String, dynamic> message) => ws.add(jsonEncode(message));

  /// The next message, skipping PAIR_PENDING reminders.
  Future<Map<String, dynamic>> next() async {
    while (true) {
      while (_read >= inbox.length) {
        if (closed.isCompleted) throw StateError('closed with no message');
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

HttpClient _realClient() {
  // The test binding fakes every HttpClient; the socket needs a real one.
  final previous = HttpOverrides.current;
  HttpOverrides.global = null;
  try {
    return HttpClient();
  } finally {
    HttpOverrides.global = previous;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late PairedBrowsersStore store;
  late ProviderContainer container;
  late LocalServerService server;
  late List<String> logs;
  late List<WebSocket> sockets;
  late List<HttpClient> clients;

  PairingCoordinator coordinator() =>
      container.read(pairingCoordinatorProvider.notifier);

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'api_token': _manual,
      'server_port': 0,
      'do_not_disturb': true,
    });
    prefs = await SharedPreferences.getInstance();
    initPrefs(prefs);
    logs = [];
    sockets = [];
    clients = [];
    store = PairedBrowsersStore(prefs);
    container = ProviderContainer(
      overrides: [
        downloaderRepositoryProvider.overrideWithValue(
          FakeDownloaderRepository([]),
        ),
        pairedBrowsersProvider.overrideWith((ref) => store),
        // The 2-minute expiry never runs for real in a test.
        pairingCoordinatorProvider.overrideWith(
          (ref) => PairingCoordinator(
            ref.watch(pairedBrowsersProvider.notifier),
            schedule: (d, cb) => _FakeTimer(cb),
          ),
        ),
        localServerServiceProvider.overrideWith(
          (ref) => LocalServerService(
            ref,
            onExtensionFlush: (_) {},
            helloTimeout: const Duration(seconds: 2),
            pairRequestWindow: const Duration(seconds: 2),
            pendingKeepAlive: const Duration(milliseconds: 200),
            showExtensionConnected: () async {},
          ),
        ),
      ],
    );
    server = container.read(localServerServiceProvider);
    await runZoned(
      server.start,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logs.add(line),
      ),
    );
    expect(server.boundPort, greaterThan(0));
  });

  tearDown(() async {
    for (final ws in sockets) {
      await ws.close().timeout(_wait, onTimeout: () {});
    }
    await server.stop();
    container.dispose();
    for (final c in clients) {
      c.close(force: true);
    }
  });

  Future<_Peer> connect(String? origin) async {
    final client = _realClient();
    clients.add(client);
    final ws = await WebSocket.connect(
      'ws://127.0.0.1:${server.boundPort}/',
      headers: origin == null ? null : {'Origin': origin},
      customClient: client,
    );
    sockets.add(ws);
    return _Peer(ws);
  }

  Future<Map<String, dynamic>> askToPair(_Peer p) async {
    p.send({'type': 'HELLO', 'version': '2.2.0', 'token': ''});
    expect(await p.next(), {
      'type': 'AUTH_FAILED',
      'reason': 'pairing_required',
    });
    p.send({'type': 'PAIR_REQUEST', 'extensionVersion': '2.2.0'});
    return p.next();
  }

  /// The whole first pairing; returns the issued token.
  Future<String> pair(String origin) async {
    final p = await connect(origin);
    final pending = await askToPair(p);
    expect(pending['type'], 'PAIR_PENDING');
    expect(pending['code'], coordinator().state!.code);
    expect(await coordinator().approve(pending['requestId'] as String), isTrue);
    final ok = await p.next();
    expect(ok['type'], 'PAIR_OK');
    await p.waitClosed();
    return ok['token'] as String;
  }

  test('a web page origin never reaches the protocol', () async {
    for (final origin in [
      'https://example.com',
      'http://localhost:3000',
      'http://127.0.0.1:6969',
      'null',
    ]) {
      await expectLater(
        connect(origin),
        throwsA(
          isA<WebSocketException>().having(
            (e) => e.toString(),
            'status',
            contains('status code: 403'),
          ),
        ),
        reason: origin,
      );
    }
    expect(coordinator().state, isNull);
    expect(store.state.browsers, isEmpty);
    expect(logs.where((l) => l.contains('origin rejected:https')), isNotEmpty);
    // The manual token path keeps working beside the refusals.
    final local = await connect(null);
    local.send({'type': 'HELLO', 'token': _manual});
    expect((await local.next())['type'], 'HELLO_OK');
  });

  test(
    'an extension origin pairs end to end, then reconnects with its token',
    () async {
      for (final origin in [_chrome, _firefox]) {
        final token = await pair(origin);
        expect(store.state.browsers.map((b) => b.origin), contains(origin));

        final again = await connect(origin);
        again.send({'type': 'HELLO', 'version': '2.2.0', 'token': token});
        expect((await again.next())['type'], 'HELLO_OK', reason: origin);
        again.send({'type': 'PING'});
        expect((await again.next())['type'], 'PONG');
      }
      expect(store.state.browsers, hasLength(2));
      expect(logs.where((l) => l.startsWith('[ERROR]')), isEmpty);
    },
  );

  test('revoking closes the live socket and pauses the next request', () async {
    final token = await pair(_chrome);
    final live = await connect(_chrome);
    live.send({'type': 'HELLO', 'token': token});
    expect((await live.next())['type'], 'HELLO_OK');

    await store.revoke(store.state.browsers.single.id);
    await live.waitClosed();

    final retry = await connect(_chrome);
    retry.send({'type': 'HELLO', 'token': token});
    expect(await retry.next(), {
      'type': 'AUTH_FAILED',
      'reason': 'pairing_required',
    });
    retry.send({'type': 'PAIR_REQUEST', 'extensionVersion': '2.2.0'});
    final paused = await retry.next();
    expect(paused['type'], 'PAIR_PAUSED');
    // A real clock: the ceiling of the 10 minutes left, give or take a second.
    expect(paused['retryAfterSeconds'], inInclusiveRange(599, 600));
    await retry.waitClosed();
    expect(coordinator().state, isNull, reason: 'no invitation during a pause');
  });

  test('the manual token is untouched by pairing and revocation', () async {
    Future<void> manualWorks({String? origin}) async {
      final p = await connect(origin);
      p.send({'type': 'HELLO', 'token': _manual});
      expect((await p.next())['type'], 'HELLO_OK', reason: '$origin');
    }

    await manualWorks();
    await manualWorks(origin: _chrome);
    await pair(_chrome);
    await store.revoke(store.state.browsers.single.id);
    await manualWorks();
    await manualWorks(origin: _chrome);
    expect(prefs.getString('api_token'), _manual);
  });
}
