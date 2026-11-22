import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:modern_downloader/core/logger/logger_service.dart';
import 'package:modern_downloader/features/transfer/data/localsend_api.dart';
import 'package:modern_downloader/features/transfer/data/transfer_security.dart';
import 'package:modern_downloader/features/transfer/data/transfer_zip_bundle.dart';
import 'package:modern_downloader/features/transfer/domain/library_manifest.dart';
import 'package:modern_downloader/features/transfer/domain/resume_filter.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_path_guard.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

typedef IncomingDecision = Future<bool> Function(IncomingOffer offer);

class ShareOffer {
  const ShareOffer({required this.files, required this.pin});

  final List<TransferFile> files;
  final String pin;
}

class TransferLanServer {
  TransferLanServer({
    required this.identity,
    required this.destRoot,
    required this.isTrusted,
    required this.onIncoming,
    required this.onPeer,
    this.forbiddenPort = 6969,
  });

  final TransferIdentity identity;
  final String destRoot;
  final bool Function(String fingerprint) isTrusted;
  final IncomingDecision onIncoming;
  final void Function(TransferPeer peer) onPeer;
  final int forbiddenPort;

  HttpServer? _server;
  ShareOffer? _share;
  _ActiveSession? _session;
  Timer? _sessionTimeout;
  String pin = '000000';

  int? get port => _server?.port;
  bool get isBusy => _session != null;

  void _armSessionTimeout() {
    _sessionTimeout?.cancel();
    _sessionTimeout = Timer(const Duration(seconds: 60), () {
      if (_session != null) {
        LoggerService.i('Transfer session ${_session?.id} expired after 60s inactivity');
        _session = null;
      }
    });
  }

  void _clearSession() {
    _sessionTimeout?.cancel();
    _sessionTimeout = null;
    _session = null;
  }

  void setShare(ShareOffer? offer) {
    _share = offer;
    if (offer != null) pin = offer.pin;
  }

  bool _isHttps = false;
  bool get isHttps => _isHttps;

  Future<int> start({
    int preferredPort = LocalSendApi.defaultPort,
    InternetAddress? address,
    bool secure = true,
  }) async {
    await stop();
    final bindAddr = address ?? InternetAddress.anyIPv4;

    Future<HttpServer> bindServer(dynamic addr, int port) async {
      if (secure) {
        try {
          final ctx = TransferSecurity.createSecurityContext();
          final s = await HttpServer.bindSecure(addr, port, ctx, shared: true);
          _isHttps = true;
          return s;
        } catch (e) {
          LoggerService.w('Transfer HTTPS bindSecure failed ($e), fallback to HTTP');
        }
      }
      _isHttps = false;
      return await HttpServer.bind(addr, port, shared: true);
    }

    if (preferredPort == 0) {
      _server = await bindServer(bindAddr, 0);
      if (_server!.port == forbiddenPort) {
        await _server!.close(force: true);
        _server = await bindServer(bindAddr, 0);
      }
      _server!.listen(
        _handle,
        onError: (Object e) {
          LoggerService.w('Transfer LAN server error: $e');
        },
      );
      return _server!.port;
    }
    final ports = <int>[
      if (preferredPort > 0 && preferredPort != forbiddenPort) preferredPort,
    ];
    for (var extra = 53318; extra <= 53327; extra++) {
      if (extra != forbiddenPort) ports.add(extra);
    }
    SocketException? last;
    for (final candidate in ports) {
      try {
        _server = await bindServer(bindAddr, candidate);
        last = null;
        break;
      } on SocketException catch (e) {
        last = e;
      }
    }
    if (_server == null) {
      _server = await bindServer(bindAddr, 0);
      if (_server!.port == forbiddenPort) {
        await _server!.close(force: true);
        _server = await bindServer(bindAddr, 0);
      }
    }
    if (last != null && _server == null) {
      throw last;
    }
    _server!.listen(
      _handle,
      onError: (Object e) {
        LoggerService.w('Transfer LAN server error: $e');
      },
    );
    return _server!.port;
  }

  Future<void> stop() async {
    _clearSession();
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (request.method == 'GET' && (path == '/' || path.isEmpty)) {
        await _writeHtml(request);
        return;
      }
      if (request.method == 'GET' &&
          (path == LocalSendApi.infoPath || path == '/api/localsend/v1/info')) {
        await _writeJson(
          request,
          200,
          LocalSendApi.infoDto(identity, download: _share != null),
        );
        return;
      }
      if (request.method == 'POST' &&
          (path == LocalSendApi.registerPath ||
              path == '/api/localsend/v1/register')) {
        await _onRegister(request);
        return;
      }
      if (request.method == 'POST' &&
          path == LocalSendApi.prepareDownloadPath) {
        await _onPrepareDownload(request);
        return;
      }
      if (request.method == 'GET' && path == LocalSendApi.downloadPath) {
        await _onDownload(request);
        return;
      }
      if (request.method == 'GET' && path == LocalSendApi.bundlePath) {
        await _onBundle(request);
        return;
      }
      if (request.method == 'POST' && path == LocalSendApi.prepareUploadPath) {
        await _onPrepareUpload(request);
        return;
      }
      if (request.method == 'POST' && path == LocalSendApi.uploadPath) {
        await _onUpload(request);
        return;
      }
      if (request.method == 'POST' && path == LocalSendApi.cancelPath) {
        _clearSession();
        request.response.statusCode = 200;
        await request.response.close();
        return;
      }
      request.response.statusCode = 404;
      await request.response.close();
    } catch (e) {
      LoggerService.w('Transfer request failed: $e');
      try {
        request.response.statusCode = 500;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _onRegister(HttpRequest request) async {
    final body = LocalSendApi.decodeMap(await utf8.decodeStream(request));
    request.response.statusCode = 200;
    await _writeJson(
      request,
      200,
      LocalSendApi.registerDto(
        identity,
        port: port ?? LocalSendApi.defaultPort,
        download: _share != null,
        protocol: _isHttps ? 'https' : 'http',
      ),
    );
    if (body == null) return;
    final incomingDeviceId = body['deviceId'] as String?;
    if (incomingDeviceId != null &&
        identity.deviceId != null &&
        incomingDeviceId == identity.deviceId) {
      return;
    }
    final ip = request.connectionInfo?.remoteAddress.address;
    if (ip == null || ip.isEmpty) return;
    final peer = LocalSendApi.peerFromRegister(
      body,
      ip: ip,
      fallbackPort: port,
    );
    if (peer != null) onPeer(peer);
  }

  Future<void> _onPrepareDownload(HttpRequest request) async {
    final share = _share;
    if (share == null) {
      request.response.statusCode = 403;
      await request.response.close();
      return;
    }
    if (!_pinOk(request, share.pin)) {
      request.response.statusCode = 401;
      await request.response.close();
      return;
    }
    final existingId = request.uri.queryParameters['sessionId'];
    final sessionId =
        (existingId != null &&
            _session?.id == existingId &&
            _session?.kind == _SessionKind.download)
        ? existingId
        : const Uuid().v4();
    _session = _ActiveSession(
      id: sessionId,
      kind: _SessionKind.download,
      tokens: {for (final file in share.files) file.id: file.id},
      files: {for (final file in share.files) file.id: file},
    );
    _armSessionTimeout();
    await _writeJson(request, 200, {
      'info': LocalSendApi.infoDto(identity, download: true),
      'sessionId': sessionId,
      'files': LocalSendApi.filesMap(share.files),
    });
  }

  Future<void> _onDownload(HttpRequest request) async {
    final session = _session;
    final fileId = request.uri.queryParameters['fileId'];
    final sessionId = request.uri.queryParameters['sessionId'];
    if (session == null ||
        session.kind != _SessionKind.download ||
        session.id != sessionId ||
        fileId == null) {
      request.response.statusCode = 403;
      await request.response.close();
      return;
    }
    _armSessionTimeout();
    final file = session.files[fileId];
    if (file == null) {
      request.response.statusCode = 400;
      await request.response.close();
      return;
    }
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (file.localPath == null && file.fileName == LibraryManifest.fileName) {
      final bytes = utf8.encode(
        jsonEncode(
          LibraryManifest(
            entries: [
              for (final item in session.files.values)
                if (item.fileName != LibraryManifest.fileName)
                  LibraryManifestEntry(
                    relativePath: item.fileName,
                    downloadId: item.downloadId,
                    creatorKey: item.creatorKey,
                    creatorHandle: item.creatorHandle,
                  ),
            ],
          ).toJson(),
        ),
      );
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.add(bytes);
      await request.response.close();
      return;
    }
    final path = file.localPath;
    if (path == null) {
      request.response.statusCode = 404;
      await request.response.close();
      return;
    }
    final ioFile = File(path);
    if (!await ioFile.exists()) {
      request.response.statusCode = 404;
      await request.response.close();
      return;
    }
    final size = file.size;
    var start = 0;
    var end = size;
    if (range != null && range.startsWith('bytes=')) {
      final spec = range.substring(6);
      final parts = spec.split('-');
      start = int.tryParse(parts[0]) ?? 0;
      if (parts.length > 1 && parts[1].isNotEmpty) {
        end = (int.tryParse(parts[1]) ?? (size - 1)) + 1;
      }
      start = start.clamp(0, size);
      end = end.clamp(start, size);
      request.response.statusCode = 206;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-${end - 1}/$size',
      );
    } else {
      request.response.statusCode = 200;
    }
    request.response.headers.contentType = ContentType.binary;
    request.response.contentLength = end - start;
    await request.response.addStream(ioFile.openRead(start, end));
    await request.response.close();
  }

  Future<void> _onPrepareUpload(HttpRequest request) async {
    if (_session != null) {
      request.response.statusCode = 409;
      await request.response.close();
      return;
    }
    final body = LocalSendApi.decodeMap(await utf8.decodeStream(request));
    if (body == null) {
      request.response.statusCode = 400;
      await request.response.close();
      return;
    }
    final info = body['info'];
    final infoMap = info is Map
        ? info.map((key, value) => MapEntry('$key', value))
        : <String, dynamic>{};
    final fingerprint = infoMap['fingerprint'] is String
        ? infoMap['fingerprint'] as String
        : '';
    final trusted = fingerprint.isNotEmpty && isTrusted(fingerprint);
    if (!trusted && pin.isNotEmpty && !_pinOk(request, pin)) {
      request.response.statusCode = 401;
      await request.response.close();
      return;
    }
    final files = LocalSendApi.filesFromDto(body['files']);
    if (files.isEmpty) {
      request.response.statusCode = 204;
      await request.response.close();
      return;
    }
    final alias = infoMap['alias'] is String
        ? infoMap['alias'] as String
        : 'Device';
    final accepted = await onIncoming(
      IncomingOffer(peerAlias: alias, fingerprint: fingerprint, files: files),
    );
    if (!accepted) {
      request.response.statusCode = 403;
      await request.response.close();
      return;
    }
    final dest = await _existingIndex();
    final pending = ResumeFilter.pending(
      files: files,
      destByRelativePath: dest,
    );
    if (pending.isEmpty) {
      request.response.statusCode = 204;
      await request.response.close();
      return;
    }
    final sessionId = const Uuid().v4();
    final tokens = <String, String>{
      for (final file in pending) file.id: const Uuid().v4(),
    };
    _session = _ActiveSession(
      id: sessionId,
      kind: _SessionKind.upload,
      tokens: tokens,
      files: {for (final file in pending) file.id: file},
    );
    _armSessionTimeout();
    await _writeJson(request, 200, {'sessionId': sessionId, 'files': tokens});
  }

  Future<void> _onUpload(HttpRequest request) async {
    final session = _session;
    final sessionId = request.uri.queryParameters['sessionId'];
    final fileId = request.uri.queryParameters['fileId'];
    final token = request.uri.queryParameters['token'];
    if (session == null ||
        session.kind != _SessionKind.upload ||
        session.id != sessionId ||
        fileId == null ||
        token == null ||
        session.tokens[fileId] != token) {
      request.response.statusCode = 403;
      await request.response.close();
      return;
    }
    final file = session.files[fileId];
    if (file == null) {
      request.response.statusCode = 400;
      await request.response.close();
      return;
    }
    final destName = _destRelative(file.fileName);
    final destPath = TransferPathGuard.resolveUnderRoot(destRoot, destName);
    if (destPath == null) {
      request.response.statusCode = 400;
      await request.response.close();
      return;
    }
    final dest = File(destPath);
    await dest.parent.create(recursive: true);
    final sink = dest.openWrite();
    try {
      await sink.addStream(request);
      await sink.close();
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      request.response.statusCode = 500;
      await request.response.close();
      return;
    }
    if (file.sha256 != null) {
      final digest = await sha256.bind(dest.openRead()).first;
      if (digest.toString() != file.sha256) {
        try {
          await dest.delete();
        } catch (_) {}
        request.response.statusCode = 422;
        await request.response.close();
        return;
      }
    }
    session.tokens.remove(fileId);
    if (session.tokens.isEmpty) {
      _clearSession();
    } else {
      _armSessionTimeout();
    }
    request.response.statusCode = 200;
    await request.response.close();
  }

  Future<void> _onBundle(HttpRequest request) async {
    final share = _share;
    if (share == null || share.files.isEmpty) {
      request.response.statusCode = 403;
      await request.response.close();
      return;
    }
    if (!_pinOk(request, share.pin)) {
      request.response.statusCode = 401;
      await request.response.close();
      return;
    }
    final existingId = request.uri.queryParameters['sessionId'];
    if (_session == null ||
        _session!.kind != _SessionKind.download ||
        (existingId != null && _session!.id != existingId)) {
      _session = _ActiveSession(
        id: existingId ?? const Uuid().v4(),
        kind: _SessionKind.download,
        tokens: {for (final file in share.files) file.id: file.id},
        files: {for (final file in share.files) file.id: file},
      );
    }
    File? zip;
    try {
      zip = await TransferZipBundle.writeToTemp(share.files);
      final stem = TransferZipBundle.archiveName(share.files);
      final bytes = await zip.length();
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType('application', 'zip');
      request.response.headers.set(
        HttpHeaders.contentDisposition,
        'attachment; filename="$stem.zip"',
      );
      request.response.contentLength = bytes;
      await request.response.addStream(zip.openRead());
      await request.response.close();
    } catch (e) {
      LoggerService.w('Transfer zip bundle failed: $e');
      try {
        request.response.statusCode = 500;
        await request.response.close();
      } catch (_) {}
    } finally {
      try {
        await zip?.delete();
      } catch (_) {}
    }
  }

  bool _pinOk(HttpRequest request, String expected) {
    final provided = request.uri.queryParameters['pin'];
    return provided != null && provided == expected && expected.isNotEmpty;
  }

  String _destRelative(String fileName) {
    final rel = TransferPathGuard.relativePathOrNull(fileName);
    if (rel == null) return 'Reçu/invalid';
    if (rel == LibraryManifest.fileName) return rel;
    if (rel.contains('/')) return rel;
    return 'Reçu/$rel';
  }

  Future<Map<String, ExistingDestFile>> _existingIndex() async {
    final map = <String, ExistingDestFile>{};
    final root = Directory(destRoot);
    if (!await root.exists()) return map;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final rel = p.split(p.relative(entity.path, from: destRoot)).join('/');
      final stat = await entity.stat();
      map[rel] = ExistingDestFile(size: stat.size);
      map['Reçu/$rel'] = ExistingDestFile(size: stat.size);
    }
    return map;
  }

  Future<void> _writeJson(
    HttpRequest request,
    int status,
    Map<String, Object?> body,
  ) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  Future<void> _writeHtml(HttpRequest request) async {
    final share = _share;
    final pinQ = request.uri.queryParameters['pin'] ?? pin;
    final files = share?.files ?? const <TransferFile>[];
    final zipStem = TransferZipBundle.archiveName(files);
    final html = '''
<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>TapLoad — Transfert</title>
  <style>
    :root {
      --bg: #090a0f;
      --card-bg: rgba(255, 255, 255, 0.04);
      --card-border: rgba(255, 255, 255, 0.08);
      --accent: #ff4081;
      --accent-grad: linear-gradient(135deg, #ff5252, #e040fb);
      --text: #f0f3f8;
      --text-dim: #8a94a6;
      --radius: 20px;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
      background: var(--bg);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px;
      line-height: 1.5;
    }
    .container {
      width: 100%;
      max-width: 480px;
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: var(--radius);
      backdrop-filter: blur(24px);
      -webkit-backdrop-filter: blur(24px);
      padding: 28px;
      box-shadow: 0 24px 64px rgba(0, 0, 0, 0.6);
    }
    .header {
      display: flex;
      align-items: center;
      gap: 14px;
      margin-bottom: 20px;
    }
    .icon-badge {
      width: 44px;
      height: 44px;
      border-radius: 12px;
      background: var(--accent-grad);
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 8px 20px rgba(224, 64, 251, 0.3);
    }
    .icon-badge svg {
      width: 24px;
      height: 24px;
      fill: #fff;
    }
    h1 { font-size: 20px; font-weight: 700; letter-spacing: -0.02em; }
    .status { font-size: 13px; color: var(--text-dim); margin-top: 2px; }
    .btn-download {
      display: block;
      width: 100%;
      padding: 16px;
      margin: 20px 0;
      border-radius: 14px;
      background: var(--accent-grad);
      color: #fff;
      font-size: 15px;
      font-weight: 600;
      text-align: center;
      text-decoration: none;
      box-shadow: 0 10px 25px rgba(224, 64, 251, 0.25);
      transition: transform 0.15s, opacity 0.15s;
    }
    .btn-download:active { transform: scale(0.98); opacity: 0.9; }
    .section-title {
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: var(--text-dim);
      margin-bottom: 10px;
    }
    .files-list {
      list-style: none;
      max-height: 220px;
      overflow-y: auto;
      border-radius: 12px;
      background: rgba(0, 0, 0, 0.25);
      border: 1px solid rgba(255, 255, 255, 0.04);
    }
    .files-list li {
      padding: 10px 14px;
      font-size: 13px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.04);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .files-list li:last-child { border-bottom: none; }
    .file-name {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      margin-right: 8px;
    }
    .file-tag {
      font-size: 11px;
      color: var(--text-dim);
      font-variant-numeric: tabular-nums;
      flex-shrink: 0;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="icon-badge">
        <svg viewBox="0 0 24 24"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM17 13l-5 5-5-5h3V9h4v4h3z"/></svg>
      </div>
      <div>
        <h1>TapLoad</h1>
        <div id="status" class="status">Connexion au serveur…</div>
      </div>
    </div>
    <a id="all" class="btn-download" href="#">Télécharger le pack ZIP ($zipStem.zip)</a>
    <div class="section-title">Contenu du transfert</div>
    <ul id="list" class="files-list"></ul>
  </div>
  <script>
  const pin = ${jsonEncode(pinQ)};
  async function boot() {
    try {
      const res = await fetch(${jsonEncode(LocalSendApi.prepareDownloadPath)} + '?pin=' + encodeURIComponent(pin), {method:'POST'});
      if (res.status === 401) { document.getElementById('status').textContent = 'Code PIN requis ou invalide'; return; }
      if (!res.ok) { document.getElementById('status').textContent = 'Aucun élément sélectionné'; return; }
      const data = await res.json();
      const count = Object.keys(data.files || {}).length;
      document.getElementById('status').textContent = (data.info?.alias || 'Appareil prêt') + ' · ' + count + ' fichier(s)';
      const zip = ${jsonEncode(LocalSendApi.bundlePath)} + '?sessionId=' + encodeURIComponent(data.sessionId) + '&pin=' + encodeURIComponent(pin);
      const all = document.getElementById('all');
      all.href = zip;
      all.setAttribute('download', ${jsonEncode('$zipStem.zip')});
      const list = document.getElementById('list');
      list.innerHTML = '';
      const files = Object.values(data.files || {});
      for (const f of files.slice(0, 30)) {
        const li = document.createElement('li');
        li.innerHTML = '<span class="file-name">' + f.fileName + '</span><span class="file-tag">' + (f.size ? Math.round(f.size/1024/1024*10)/10 + ' Mo' : '') + '</span>';
        list.appendChild(li);
      }
      if (files.length > 30) {
        const li = document.createElement('li');
        li.innerHTML = '<span class="file-name">+' + (files.length - 30) + ' autres fichiers</span>';
        list.appendChild(li);
      }
    } catch(e) {
      document.getElementById('status').textContent = 'Erreur de connexion';
    }
  }
  boot();
  </script>
</body>
</html>
''';
    request.response.statusCode = 200;
    request.response.headers.contentType = ContentType.html;
    request.response.write(html);
    await request.response.close();
  }
}

enum _SessionKind { download, upload }

class _ActiveSession {
  _ActiveSession({
    required this.id,
    required this.kind,
    required this.tokens,
    required this.files,
  });

  final String id;
  final _SessionKind kind;
  final Map<String, String> tokens;
  final Map<String, TransferFile> files;
}
