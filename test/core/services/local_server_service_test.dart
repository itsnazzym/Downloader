import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/download/extension_download_batcher.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/core/services/download_stats_service.dart';
import 'package:tapload/core/services/local_server_service.dart';
import 'package:tapload/core/theme/extension_theme.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/entities/download_request.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/domain/repositories/i_downloader_repository.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:tapload/features/archive/domain/repositories/i_tiktok_archive_repository.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../visual/visual_fakes.dart';

class _MemoryTikTokArchiveRepository implements ITikTokArchiveRepository {
  TikTokArchiveCatalog? catalog;

  @override
  Future<TikTokArchiveCatalog?> getCachedCatalog() async => catalog;

  @override
  Future<TikTokArchiveCatalog> importFromFile(String filePath) async =>
      catalog ?? TikTokArchiveCatalog.empty;

  @override
  Future<void> saveCatalog(TikTokArchiveCatalog value) async {
    catalog = value;
  }

  @override
  Future<void> clearCatalog() async {
    catalog = null;
  }
}

class _FakeRepo implements IDownloaderRepository {
  List<DownloadItem> items = [];
  final _controller = StreamController<DownloadItem>.broadcast();

  @override
  Future<void> get initialized => Future.value();

  @override
  Future<void> cancelDownload(String id) async {}

  @override
  Future<void> clearHistory() async {}

  @override
  Future<void> deleteDownload(String id, {bool deleteFiles = true}) async {}

  @override
  Stream<DownloadItem> get downloadUpdateStream => _controller.stream;

  @override
  Future<void> exportHistory(String path) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchPlaylist(
    String url, {
    bool? useTorProxy,
  }) async => [];

  @override
  Future<Map<String, dynamic>> fetchMetadata(
    String url, {
    String? cookies,
    bool? useTorProxy,
  }) async {
    return {};
  }

  @override
  List<DownloadItem> getCurrentDownloads() => items;

  @override
  Future<void> importHistory(String path) async {}

  @override
  Future<void> pauseDownload(String id) async {}

  @override
  Future<void> refreshLibrary() async {}

  @override
  Future<void> reorderDownloads(int oldIndex, int newIndex) async {}

  @override
  Future<void> resumeDownload(String id) async {}

  @override
  Future<String> startDownload(DownloadRequest request) async => 'mock-id';

  Future<void> dispose() => _controller.close();
}

/// Records the commands the server forwards instead of running them.
class _RecordingList extends DownloadListNotifier {
  _RecordingList(super.repository, super.ref);

  final List<String> calls = [];

  /// Runs inside cancel, like the real awaits during which a download can end.
  void Function(String id)? onCancel;

  @override
  Future<void> cancelDownload(String id) async {
    calls.add('cancel:$id');
    onCancel?.call(id);
  }

  @override
  Future<void> pauseDownload(String id) async => calls.add('pause:$id');

  @override
  Future<void> resumeDownload(String id) async => calls.add('resume:$id');

  @override
  Future<void> retryDownload(DownloadItem item) async =>
      calls.add('retry:${item.id}');
}

DownloadItem _item(
  String id,
  DownloadStatus status, {
  String? filePath,
  String? cookies,
}) => DownloadItem(
  id: id,
  request: DownloadRequest(
    url: 'https://www.youtube.com/watch?v=$id',
    rawCookies: cookies,
  ),
  status: status,
  filePath: filePath,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expectedToken = 'test-token-abc';

  late _FakeRepo repo;
  late ProviderContainer container;
  late LocalServerService server;
  late List<List<ExtensionDownloadIngest>> flushed;
  late _RecordingList list;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'api_token': expectedToken,
      'server_port': 0,
      'do_not_disturb': true,
    });
    initPrefs(await SharedPreferences.getInstance());

    repo = _FakeRepo();
    flushed = <List<ExtensionDownloadIngest>>[];
    container = ProviderContainer(
      overrides: [
        downloaderRepositoryProvider.overrideWithValue(repo),
        tikTokArchiveRepositoryProvider.overrideWithValue(
          _MemoryTikTokArchiveRepository(),
        ),
        persistenceServiceProvider.overrideWith((ref) => FakePersistence()),
        downloadStatsProvider.overrideWith((ref) => FakeStatsNotifier()),
        downloadListProvider.overrideWith(
          (ref) => list = _RecordingList(
            ref.read(downloaderRepositoryProvider),
            ref,
          ),
        ),
        localServerServiceProvider.overrideWith(
          (ref) => LocalServerService(ref, onExtensionFlush: flushed.add),
        ),
      ],
    );
    server = container.read(localServerServiceProvider);
    await server.start();
    expect(server.boundPort, isNotNull);
    expect(server.boundPort, greaterThan(0));
  });

  tearDown(() async {
    await server.stop();
    container.dispose();
    await repo.dispose();
  });

  Future<WebSocket> connect() =>
      WebSocket.connect('ws://127.0.0.1:${server.boundPort}/');

  Future<Map<String, dynamic>> firstMessage(WebSocket ws) {
    final completer = Completer<Map<String, dynamic>>();
    ws.listen((event) {
      if (!completer.isCompleted) {
        completer.complete(jsonDecode(event as String) as Map<String, dynamic>);
      }
    });
    return completer.future;
  }

  test('start is idempotent and keeps the original server binding', () async {
    final firstPort = server.boundPort;

    await server.start();

    expect(server.boundPort, firstPort);
  });

  test('HELLO with correct token returns HELLO_OK', () async {
    final ws = await connect();
    final first = firstMessage(ws);
    ws.add(
      jsonEncode({'type': 'HELLO', 'token': expectedToken, 'version': '2.1.0'}),
    );
    final msg = await first.timeout(const Duration(seconds: 2));
    expect(msg['type'], 'HELLO_OK');
    await ws.close();
  });

  test(
    'the extension receives the desktop design after HELLO and on change',
    () async {
      final ws = await connect();
      final themes = <Map<String, dynamic>>[];
      final firstTheme = Completer<void>();
      ws.listen((event) {
        final data = jsonDecode(event as String) as Map<String, dynamic>;
        if (data['type'] == ExtensionTheme.messageType) {
          themes.add(data);
          if (!firstTheme.isCompleted) firstTheme.complete();
        }
      });
      ws.add(
        jsonEncode({
          'type': 'HELLO',
          'token': expectedToken,
          'version': '2.1.0',
        }),
      );
      await firstTheme.future.timeout(const Duration(seconds: 2));
      final current = ExtensionTheme.effectivePreset(
        container.read(settingsProvider),
      ).id;
      expect(themes.first['id'], current);

      container.read(settingsProvider.notifier).setThemePreset('pastille');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(themes.last['id'], 'pastille');
      expect(themes.last['tiles'], hasLength(3));
      await ws.close();
    },
  );

  group('Origin policy', () {
    Future<WebSocket> connectWithOrigin(String origin) => WebSocket.connect(
      'ws://127.0.0.1:${server.boundPort}/',
      headers: {'Origin': origin},
    );

    test('a web page origin is refused with 403 before the upgrade', () async {
      for (final origin in [
        'https://evil.example',
        'http://127.0.0.1',
        'null',
        'file://',
        'chrome-extension://',
      ]) {
        await expectLater(
          connectWithOrigin(origin),
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
    });

    test('an extension origin is upgraded', () async {
      for (final origin in [
        'chrome-extension://abcdefghijklmnopabcdefghijklmnop',
        'moz-extension://9a8b7c6d-1111-2222-3333-444455556666',
      ]) {
        final ws = await connectWithOrigin(origin);
        final first = firstMessage(ws);
        ws.add(jsonEncode({'type': 'HELLO', 'token': expectedToken}));
        final msg = await first.timeout(const Duration(seconds: 2));
        expect(msg['type'], 'HELLO_OK', reason: origin);
        await ws.close();
      }
    });

    // Hand-written upgrade request: HttpClient cannot send duplicate headers.
    Future<String> rawUpgradeStatusLine(List<String> originLines) async {
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
          ...originLines,
          '',
          '',
        ].join('\r\n'),
      );
      final bytes = await socket.first.timeout(const Duration(seconds: 2));
      return latin1.decode(bytes).split('\r\n').first;
    }

    test('two Origin headers get 403 and the server stays healthy', () async {
      final status = await rawUpgradeStatusLine([
        'Origin: chrome-extension://abcdefghijklmnopabcdefghijklmnop',
        'Origin: chrome-extension://abcdefghijklmnopabcdefghijklmnop',
      ]);
      expect(status, contains('403'));

      final ws = await connect();
      final first = firstMessage(ws);
      ws.add(jsonEncode({'type': 'HELLO', 'token': expectedToken}));
      expect(
        (await first.timeout(const Duration(seconds: 2)))['type'],
        'HELLO_OK',
      );
      await ws.close();
    });

    test('an empty Origin header gets 403', () async {
      final status = await rawUpgradeStatusLine(['Origin:']);
      expect(status, contains('403'));
    });

    test('/status stays reachable from a web page origin', () async {
      final previous = HttpOverrides.current;
      addTearDown(() => HttpOverrides.global = previous);
      HttpOverrides.global = null; // the test binding fakes every request
      final client = HttpClient();
      final req = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.boundPort}/status'),
      );
      req.headers.set('Origin', 'https://evil.example');
      final res = await req.close();
      expect(res.statusCode, HttpStatus.ok);
      await res.drain<void>();
      client.close();
    });
  });

  test('HELLO with wrong token returns AUTH_FAILED', () async {
    final ws = await connect();
    final first = firstMessage(ws);
    ws.add(jsonEncode({'type': 'HELLO', 'token': 'wrong', 'version': '2.1.0'}));
    final msg = await first.timeout(const Duration(seconds: 2));
    expect(msg['type'], 'AUTH_FAILED');
    await ws.close();
  });

  test('DOWNLOAD after HELLO is acknowledged and ingested', () async {
    final ws = await connect();
    final events = <Map<String, dynamic>>[];
    final helloOk = Completer<void>();
    final ack = Completer<void>();

    ws.listen((event) {
      final data = jsonDecode(event as String) as Map<String, dynamic>;
      events.add(data);
      if (data['type'] == 'HELLO_OK' && !helloOk.isCompleted) {
        helloOk.complete();
      }
      if (data['type'] == 'ACK' && !ack.isCompleted) {
        ack.complete();
      }
    });

    ws.add(
      jsonEncode({'type': 'HELLO', 'token': expectedToken, 'version': '2.1.0'}),
    );
    await helloOk.future.timeout(const Duration(seconds: 2));

    ws.add(
      jsonEncode({
        'type': 'DOWNLOAD',
        'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      }),
    );
    await ack.future.timeout(const Duration(seconds: 2));

    final ackMsg = events.firstWhere((e) => e['type'] == 'ACK');
    expect(ackMsg['ok'], isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(flushed, isNotEmpty);
    expect(flushed.first.first.url, contains('youtube.com'));
    await ws.close();
  });

  test('DOWNLOAD with bad URL is rejected after auth', () async {
    final ws = await connect();
    final helloOk = Completer<void>();
    final ack = Completer<Map<String, dynamic>>();

    ws.listen((event) {
      final data = jsonDecode(event as String) as Map<String, dynamic>;
      if (data['type'] == 'HELLO_OK' && !helloOk.isCompleted) {
        helloOk.complete();
      }
      if (data['type'] == 'ACK' && !ack.isCompleted) {
        ack.complete(data);
      }
    });

    ws.add(
      jsonEncode({'type': 'HELLO', 'token': expectedToken, 'version': '2.1.0'}),
    );
    await helloOk.future.timeout(const Duration(seconds: 2));

    ws.add(jsonEncode({'type': 'DOWNLOAD', 'url': 'file:///C:/secret.mp4'}));
    final ackMsg = await ack.future.timeout(const Duration(seconds: 2));
    expect(ackMsg['ok'], isFalse);
    expect(ackMsg['error'], 'invalid_url');
    expect(flushed, isEmpty);
    await ws.close();
  });

  test(
    'TIKTOK_COLLECTIONS_SYNC updates collections and receives ACK',
    () async {
      final ws = await connect();
      final helloOk = Completer<void>();
      final syncAck = Completer<Map<String, dynamic>>();

      ws.listen((event) {
        final data = jsonDecode(event as String) as Map<String, dynamic>;
        if (data['type'] == 'HELLO_OK' && !helloOk.isCompleted) {
          helloOk.complete();
        }
        if (data['type'] == 'TIKTOK_COLLECTIONS_SYNC_ACK' &&
            !syncAck.isCompleted) {
          syncAck.complete(data);
        }
      });

      ws.add(
        jsonEncode({
          'type': 'HELLO',
          'token': expectedToken,
          'version': '2.1.0',
        }),
      );
      await helloOk.future.timeout(const Duration(seconds: 2));

      expect(container.read(extensionConnectedClientsProvider), equals(1));

      ws.add(
        jsonEncode({
          'type': 'TIKTOK_COLLECTIONS_SYNC',
          'collections': [
            {
              'id': 'collection-humour',
              'name': 'Humour',
              'declaredTotal': 1,
              'videoIds': ['7123456789'],
              'complete': true,
            },
          ],
          'collectionListComplete': true,
        }),
      );

      final ackMsg = await syncAck.future.timeout(const Duration(seconds: 2));
      expect(ackMsg['ok'], isTrue);
      expect(ackMsg['collectionCount'], equals(1));
      expect(ackMsg['partial'], isFalse);
      expect(ackMsg['incompleteCount'], equals(0));

      await ws.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(extensionConnectedClientsProvider), equals(0));
    },
  );

  test(
    'TikTok sync waits for another browser after one reports no tab',
    () async {
      final firstBrowser = await connect();
      final secondBrowser = await connect();
      final firstHello = Completer<void>();
      final secondHello = Completer<void>();
      final firstRequest = Completer<Map<String, dynamic>>();
      final secondRequest = Completer<Map<String, dynamic>>();
      final successAck = Completer<Map<String, dynamic>>();

      void listen(
        WebSocket socket,
        Completer<void> hello,
        Completer<Map<String, dynamic>> request, {
        bool captureSuccessAck = false,
      }) {
        socket.listen((event) {
          final data = jsonDecode(event as String) as Map<String, dynamic>;
          if (data['type'] == 'HELLO_OK' && !hello.isCompleted) {
            hello.complete();
          }
          if (data['type'] == 'REQUEST_TIKTOK_COLLECTIONS_SYNC' &&
              !request.isCompleted) {
            request.complete(data);
          }
          if (captureSuccessAck &&
              data['type'] == 'TIKTOK_COLLECTIONS_SYNC_ACK' &&
              data['ok'] == true &&
              !successAck.isCompleted) {
            successAck.complete(data);
          }
        });
      }

      listen(firstBrowser, firstHello, firstRequest);
      listen(
        secondBrowser,
        secondHello,
        secondRequest,
        captureSuccessAck: true,
      );
      final hello = jsonEncode({
        'type': 'HELLO',
        'token': expectedToken,
        'version': '2.1.18',
      });
      firstBrowser.add(hello);
      secondBrowser.add(hello);
      await Future.wait([
        firstHello.future,
        secondHello.future,
      ]).timeout(const Duration(seconds: 2));

      container.read(tikTokArchiveProvider.notifier).triggerExtensionSync();
      final requests = await Future.wait([
        firstRequest.future,
        secondRequest.future,
      ]).timeout(const Duration(seconds: 2));
      final requestId = requests.first['requestId'];
      expect(requestId, isNotNull);
      expect(requests.last['requestId'], requestId);

      firstBrowser.add(
        jsonEncode({
          'type': 'TIKTOK_COLLECTIONS_SYNC',
          'collections': <Map<String, dynamic>>[],
          'collectionListComplete': false,
          'error': 'no_tiktok_tab',
          'requestId': requestId,
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        container.read(tikTokArchiveProvider).syncStatus,
        TikTokSyncStatus.waiting,
      );

      secondBrowser.add(
        jsonEncode({
          'type': 'TIKTOK_COLLECTIONS_SYNC',
          'collections': [
            {
              'id': 'collection-working-browser',
              'name': 'Navigateur actif',
              'declaredTotal': 1,
              'videoIds': ['7123456789'],
              'complete': true,
            },
          ],
          'collectionListComplete': true,
          'requestId': requestId,
        }),
      );

      await successAck.future.timeout(const Duration(seconds: 2));
      expect(
        container.read(tikTokArchiveProvider).syncStatus,
        TikTokSyncStatus.complete,
      );
      expect(
        container.read(tikTokArchiveProvider).catalog!.collections.single.name,
        'Navigateur actif',
      );

      await firstBrowser.close();
      await secondBrowser.close();
    },
  );

  test('empty TikTok sync reports the extraction failure', () async {
    final ws = await connect();
    final helloOk = Completer<void>();
    final syncAck = Completer<Map<String, dynamic>>();
    ws.listen((event) {
      final data = jsonDecode(event as String) as Map<String, dynamic>;
      if (data['type'] == 'HELLO_OK' && !helloOk.isCompleted) {
        helloOk.complete();
      }
      if (data['type'] == 'TIKTOK_COLLECTIONS_SYNC_ACK' &&
          !syncAck.isCompleted) {
        syncAck.complete(data);
      }
    });
    ws.add(
      jsonEncode({'type': 'HELLO', 'token': expectedToken, 'version': '2.1.0'}),
    );
    await helloOk.future.timeout(const Duration(seconds: 2));
    ws.add(
      jsonEncode({
        'type': 'TIKTOK_COLLECTIONS_SYNC',
        'collections': <String, List<String>>{},
        'error': 'collection_items_unavailable',
      }),
    );
    final ack = await syncAck.future.timeout(const Duration(seconds: 2));
    expect(ack['ok'], isFalse);
    expect(ack['error'], 'collection_items_unavailable');
    await ws.close();
  });

  group('extension queue', () {
    late WebSocket ws;
    late List<Map<String, dynamic>> inbox;

    Future<Map<String, dynamic>> next(String type) async {
      for (var i = 0; i < 100; i++) {
        final found = inbox.indexWhere((m) => m['type'] == type);
        if (found >= 0) return inbox.removeAt(found);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      fail('no $type received');
    }

    Future<void> openWith(List<DownloadItem> items) async {
      // Let the notifier finish its start-up while the repository is empty.
      container.read(downloadListProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      repo.items = items;
      ws = await connect();
      inbox = [];
      ws.listen(
        (e) => inbox.add(jsonDecode(e as String) as Map<String, dynamic>),
      );
      ws.add(jsonEncode({'type': 'HELLO', 'token': expectedToken}));
      await next('HELLO_OK');
    }

    Future<Map<String, dynamic>> send(String command, [String? id]) async {
      ws.add(
        jsonEncode({
          'type': 'DOWNLOAD_COMMAND',
          'command': command,
          if (id != null) 'id': id,
        }),
      );
      return next('DOWNLOAD_COMMAND_RESULT');
    }

    tearDown(() => ws.close());

    test('cancel on an existing id cancels it once and answers ok', () async {
      await openWith([_item('a', DownloadStatus.downloading)]);
      final res = await send('cancel', 'a');
      expect(res['ok'], isTrue);
      expect(res['command'], 'cancel');
      expect(res['id'], 'a');
      expect(list.calls, ['cancel:a']);
    });

    test('unknown id is refused without calling the provider', () async {
      await openWith([_item('a', DownloadStatus.downloading)]);
      final res = await send('cancel', 'nope');
      expect(res['ok'], isFalse);
      expect(res['error'], 'unknown_id');
      expect(list.calls, isEmpty);
    });

    test('pause, resume and retry reach the matching provider call', () async {
      await openWith([
        _item('running', DownloadStatus.downloading),
        _item('stopped', DownloadStatus.paused),
        _item('broken', DownloadStatus.failed),
      ]);
      expect((await send('pause', 'running'))['ok'], isTrue);
      expect((await send('resume', 'stopped'))['ok'], isTrue);
      expect((await send('retry', 'broken'))['ok'], isTrue);
      expect(list.calls, ['pause:running', 'resume:stopped', 'retry:broken']);
    });

    test(
      'a command that does not fit the status is refused untouched',
      () async {
        await openWith([
          _item('done', DownloadStatus.completed, filePath: r'C:\keep\a.mp4'),
          _item('dup', DownloadStatus.duplicate),
          _item('busy', DownloadStatus.downloading),
        ]);
        for (final refused in [
          ('retry', 'done'),
          ('pause', 'done'),
          ('cancel', 'done'),
          ('resume', 'done'),
          ('retry', 'dup'),
          ('cancel', 'dup'),
          ('retry', 'busy'),
          ('resume', 'busy'),
        ]) {
          final res = await send(refused.$1, refused.$2);
          expect(res['ok'], isFalse, reason: '$refused');
          expect(res['error'], 'invalid_state', reason: '$refused');
          expect(res['id'], refused.$2);
        }
        expect(list.calls, isEmpty);
      },
    );

    test('cancel_all cancels only the active items', () async {
      await openWith([
        _item('queued', DownloadStatus.queued),
        _item('extracting', DownloadStatus.extracting),
        _item('downloading', DownloadStatus.downloading),
        _item('processing', DownloadStatus.processing),
        _item('done', DownloadStatus.completed),
        _item('failed', DownloadStatus.failed),
        _item('paused', DownloadStatus.paused),
      ]);
      final res = await send('cancel_all');
      expect(res['ok'], isTrue);
      expect(list.calls, [
        'cancel:queued',
        'cancel:extracting',
        'cancel:downloading',
        'cancel:processing',
      ]);
    });

    test(
      'cancel_all skips an item that finished while the previous one was canceled',
      () async {
        await openWith([
          _item('a', DownloadStatus.downloading),
          _item('b', DownloadStatus.downloading),
          _item('c', DownloadStatus.queued),
        ]);
        list.onCancel = (id) {
          if (id != 'a') return;
          repo.items = [
            repo.items[0],
            _item('b', DownloadStatus.completed, filePath: r'C:\keep\b.mp4'),
            repo.items[2],
          ];
        };
        final res = await send('cancel_all');
        expect(res['ok'], isTrue);
        expect(list.calls, ['cancel:a', 'cancel:c']);
        // Retry on the finished item stays refused: it would delete its file.
        final retry = await send('retry', 'b');
        expect(retry['error'], 'invalid_state');
        expect(list.calls, ['cancel:a', 'cancel:c']);
      },
    );

    test('unknown command and missing id are refused', () async {
      await openWith([_item('a', DownloadStatus.downloading)]);
      final unknown = await send('explode', 'a');
      expect(unknown['ok'], isFalse);
      expect(unknown['error'], 'unknown_command');
      final missing = await send('cancel');
      expect(missing['ok'], isFalse);
      expect(missing['error'], 'missing_id');
      expect(list.calls, isEmpty);
    });

    test('snapshot sends the activity, not the whole library', () async {
      await openWith([
        for (var i = 0; i < 60; i++)
          _item('done$i', DownloadStatus.completed, filePath: 'C:/a$i.mp4'),
        _item('live', DownloadStatus.downloading),
        _item('broken', DownloadStatus.failed),
      ]);
      ws.add(jsonEncode({'type': 'QUEUE_SNAPSHOT_REQUEST'}));
      final items = (await next('QUEUE_SNAPSHOT'))['items'] as List;
      final ids = items.map((i) => (i as Map)['id']).toList();
      expect(ids, hasLength(52));
      expect(ids, containsAll(['live', 'broken', 'done10', 'done59']));
      expect(ids, isNot(contains('done9')));
      for (final i in items.cast<Map<String, dynamic>>()) {
        expect(i.containsKey('filePath'), isFalse);
      }
    });

    test(
      'snapshot returns the queue without paths, cookies or request',
      () async {
        await openWith([
          _item(
            'a',
            DownloadStatus.completed,
            filePath: r'C:\secret\a.mp4',
            cookies: 'sid=SECRET',
          ),
        ]);
        ws.add(jsonEncode({'type': 'QUEUE_SNAPSHOT_REQUEST'}));
        final res = await next('QUEUE_SNAPSHOT');
        final items = res['items'] as List;
        expect(items, hasLength(1));
        final item = items.single as Map<String, dynamic>;
        expect(item['id'], 'a');
        expect(item['status'], DownloadStatus.completed.index);
        expect(item.containsKey('filePath'), isFalse);
        expect(item.containsKey('cookies'), isFalse);
        expect(item.containsKey('request'), isFalse);
        expect(jsonEncode(res), isNot(contains('SECRET')));
        expect(jsonEncode(res), isNot(contains('secret')));
      },
    );
  });
}
