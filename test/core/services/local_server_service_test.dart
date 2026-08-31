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
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepo implements IDownloaderRepository {
  final _controller = StreamController<DownloadItem>.broadcast();

  @override
  Future<void> get initialized => Future.value();

  @override
  Future<void> cancelDownload(String id) async {}

  @override
  Future<void> clearHistory() async {}

  @override
  Future<void> deleteDownload(String id) async {}

  @override
  Stream<DownloadItem> get downloadUpdateStream => _controller.stream;

  @override
  Future<void> exportHistory(String path) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchPlaylist(String url) async => [];

  @override
  Future<Map<String, dynamic>> fetchMetadata(
    String url, {
    String? cookies,
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
        localServerServiceProvider.overrideWith(
          (ref) => LocalServerService(
            ref,
            onExtensionFlush: flushed.add,
          ),
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
        completer.complete(
          jsonDecode(event as String) as Map<String, dynamic>,
        );
      }
    });
    return completer.future;
  }

  test('HELLO with correct token returns HELLO_OK', () async {
    final ws = await connect();
    final first = firstMessage(ws);
    ws.add(
      jsonEncode({
        'type': 'HELLO',
        'token': expectedToken,
        'version': '2.1.0',
      }),
    );
    final msg = await first.timeout(const Duration(seconds: 2));
    expect(msg['type'], 'HELLO_OK');
    await ws.close();
  });

  test('HELLO with wrong token returns AUTH_FAILED', () async {
    final ws = await connect();
    final first = firstMessage(ws);
    ws.add(
      jsonEncode({'type': 'HELLO', 'token': 'wrong', 'version': '2.1.0'}),
    );
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
      jsonEncode({
        'type': 'HELLO',
        'token': expectedToken,
        'version': '2.1.0',
      }),
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
      jsonEncode({
        'type': 'HELLO',
        'token': expectedToken,
        'version': '2.1.0',
      }),
    );
    await helloOk.future.timeout(const Duration(seconds: 2));

    ws.add(jsonEncode({'type': 'DOWNLOAD', 'url': 'file:///C:/secret.mp4'}));
    final ackMsg = await ack.future.timeout(const Duration(seconds: 2));
    expect(ackMsg['ok'], isFalse);
    expect(ackMsg['error'], 'invalid_url');
    expect(flushed, isEmpty);
    await ws.close();
  });
}
