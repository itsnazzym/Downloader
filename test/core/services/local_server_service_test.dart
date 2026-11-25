import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/extension_download_batcher.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/services/local_server_service.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/repositories/i_downloader_repository.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/domain/repositories/i_tiktok_archive_repository.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<DownloadItem> getCurrentDownloads() => [];

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expectedToken = 'test-token-abc';

  late _FakeRepo repo;
  late ProviderContainer container;
  late LocalServerService server;
  late List<List<ExtensionDownloadIngest>> flushed;

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
}
