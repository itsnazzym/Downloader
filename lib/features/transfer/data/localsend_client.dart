import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:modern_downloader/features/transfer/data/localsend_api.dart';
import 'package:modern_downloader/features/transfer/data/transfer_security.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';

class LocalSendClient {
  LocalSendClient({HttpClient? httpClient, this.maxParallel = 3})
    : _http = httpClient ?? lanHttpClient();

  HttpClient _http;
  final int maxParallel;

  static const handshakeTimeout = Duration(seconds: 5);
  static const acceptTimeout = Duration(minutes: 3);

  static HttpClient lanHttpClient({
    Duration timeout = handshakeTimeout,
    SecurityContext? context,
  }) {
    final ctx = context ?? TransferSecurity.createSecurityContext();
    return HttpClient(context: ctx)
      ..connectionTimeout = timeout
      ..idleTimeout = const Duration(seconds: 30)
      ..badCertificateCallback = (cert, host, port) => true;
  }

  void abort() {
    try {
      _http.close(force: true);
    } catch (_) {}
    _http = lanHttpClient();
  }

  void close() {
    try {
      _http.close(force: true);
    } catch (_) {}
  }

  Future<TransferPeer?> testPeerConnection(
    TransferPeer peer, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final tested = await _testPeerOnce(peer, timeout: timeout);
    if (tested != null) return tested;
    return _testPeerOnce(peer.flippedProtocol, timeout: timeout);
  }

  Future<TransferPeer?> _testPeerOnce(
    TransferPeer peer, {
    required Duration timeout,
  }) async {
    final uri = _api(peer, LocalSendApi.infoPath, const {});
    try {
      final request = await _http.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final body = await utf8.decodeStream(response);
      final map = LocalSendApi.decodeMap(body);
      if (map == null) return null;
      return LocalSendApi.peerFromRegister(
        map,
        ip: peer.ip,
        fallbackPort: peer.port,
      )?.copyWith(protocol: peer.protocol, lastSeen: DateTime.now());
    } catch (_) {
      return null;
    }
  }

  Future<PrepareUploadOutcome> prepareUpload({
    required TransferPeer peer,
    required TransferIdentity identity,
    required List<TransferFile> files,
    int ourPort = LocalSendApi.defaultPort,
    String? pin,
  }) async {
    final reachable = await testPeerConnection(
      peer,
      timeout: handshakeTimeout,
    );
    if (reachable == null) {
      return PrepareUploadOutcome.error(
        TransferProtocolCode.connectionRefused,
        'unreachable',
        peer,
      );
    }
    final outcome = await _prepareOnce(
      peer: reachable,
      identity: identity,
      files: files,
      ourPort: ourPort,
      pin: pin,
    );
    return outcome.withVia(reachable);
  }

  Future<PrepareUploadOutcome> _prepareOnce({
    required TransferPeer peer,
    required TransferIdentity identity,
    required List<TransferFile> files,
    required int ourPort,
    String? pin,
  }) async {
    final uri = _api(
      peer,
      LocalSendApi.prepareUploadPath,
      pin == null ? const {} : {'pin': pin},
    );
    try {
      final payload = utf8.encode(
        jsonEncode({
          'info': LocalSendApi.registerDto(
            identity,
            port: ourPort,
            download: true,
            protocol: peer.protocol,
          ),
          'files': LocalSendApi.filesMap(files),
        }),
      );
      final request = await _http.postUrl(uri).timeout(handshakeTimeout);
      request.headers.contentType = ContentType.json;
      request.contentLength = payload.length;
      request.add(payload);
      final response = await request.close().timeout(acceptTimeout);
      final body = await utf8.decodeStream(response);
      final code = LocalSendApi.statusToCode(response.statusCode);
      if (code != TransferProtocolCode.ok) {
        return PrepareUploadOutcome.error(code);
      }
      final map = LocalSendApi.decodeMap(body);
      if (map == null) {
        return const PrepareUploadOutcome.error(TransferProtocolCode.httpError);
      }
      final sessionId = map['sessionId'];
      final tokensRaw = map['files'];
      if (sessionId is! String || tokensRaw is! Map) {
        return const PrepareUploadOutcome.error(TransferProtocolCode.httpError);
      }
      final tokens = <String, String>{};
      for (final entry in tokensRaw.entries) {
        if (entry.value is String) {
          tokens['${entry.key}'] = entry.value as String;
        }
      }
      return PrepareUploadOutcome.ok(
        PrepareUploadSuccess(sessionId: sessionId, tokens: tokens),
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final code = msg.contains('timed out') ||
              msg.contains('timeoutexception') ||
              msg.contains('délai')
          ? TransferProtocolCode.timeout
          : (msg.contains('refused') ||
                  msg.contains('refusée') ||
                  msg.contains('failed to connect')
              ? TransferProtocolCode.connectionRefused
              : TransferProtocolCode.httpError);
      return PrepareUploadOutcome.error(code, e.toString());
    }
  }

  Future<TransferProtocolCode> uploadFile({
    required TransferPeer peer,
    required String sessionId,
    required String fileId,
    required String token,
    required Stream<List<int>> bytes,
    required int length,
  }) async {
    final uri = _api(peer, LocalSendApi.uploadPath, {
      'sessionId': sessionId,
      'fileId': fileId,
      'token': token,
    });
    try {
      final request = await _http.postUrl(uri);
      request.contentLength = length;
      await request.addStream(bytes);
      final response = await request.close();
      await response.drain<void>();
      return LocalSendApi.statusToCode(response.statusCode);
    } catch (_) {
      return TransferProtocolCode.httpError;
    }
  }

  Future<void> cancel({
    required TransferPeer peer,
    required String sessionId,
  }) async {
    final uri = _api(peer, LocalSendApi.cancelPath, {'sessionId': sessionId});
    try {
      final request = await _http.postUrl(uri);
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {}
  }

  Future<TransferProtocolCode> register({
    required TransferPeer peer,
    required TransferIdentity identity,
    required int ourPort,
  }) async {
    final first = await _registerOnce(peer, identity, ourPort);
    if (first != TransferProtocolCode.httpError) return first;
    return _registerOnce(peer.flippedProtocol, identity, ourPort);
  }

  Future<TransferProtocolCode> _registerOnce(
    TransferPeer peer,
    TransferIdentity identity,
    int ourPort,
  ) async {
    final uri = _api(peer, LocalSendApi.registerPath, const {});
    try {
      final payload = utf8.encode(
        jsonEncode(
          LocalSendApi.registerDto(identity, port: ourPort, download: true),
        ),
      );
      final request = await _http.postUrl(uri).timeout(handshakeTimeout);
      request.headers.contentType = ContentType.json;
      request.contentLength = payload.length;
      request.add(payload);
      final response = await request.close().timeout(handshakeTimeout);
      await response.drain<void>();
      return LocalSendApi.statusToCode(response.statusCode);
    } catch (_) {
      return TransferProtocolCode.httpError;
    }
  }

  Future<void> uploadAll({
    required TransferPeer peer,
    required String sessionId,
    required Map<String, String> tokens,
    required List<TransferFile> files,
    required void Function(int bytesDelta, String name) onProgress,
  }) async {
    final gate = _Gate(maxParallel);
    final tasks = <Future<void>>[];
    for (final file in files) {
      final token = tokens[file.id];
      final path = file.localPath;
      if (token == null || path == null) continue;
      tasks.add(() async {
        await gate.acquire();
        try {
          final ioFile = File(path);
          var sent = 0;
          final stream = ioFile.openRead().map((chunk) {
            sent += chunk.length;
            onProgress(chunk.length, file.fileName);
            return chunk;
          });
          final code = await uploadFile(
            peer: peer,
            sessionId: sessionId,
            fileId: file.id,
            token: token,
            bytes: stream,
            length: file.size,
          );
          if (code != TransferProtocolCode.ok) {
            throw HttpException(
              'Upload failed for ${file.fileName} with code $code',
            );
          }
          if (sent == 0) {
            onProgress(0, file.fileName);
          }
        } finally {
          gate.release();
        }
      }());
    }
    await Future.wait(tasks);
  }

  Uri _api(TransferPeer peer, String path, Map<String, String> query) {
    if (query.isEmpty) {
      return peer.origin().replace(path: path);
    }
    return peer.origin().replace(path: path, queryParameters: query);
  }
}

class _Gate {
  _Gate(this.max);
  final int max;
  int _active = 0;
  final _waiters = <Completer<void>>[];

  Future<void> acquire() async {
    while (_active >= max) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _active++;
  }

  void release() {
    if (_active > 0) {
      _active -= 1;
    }
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    }
  }
}
