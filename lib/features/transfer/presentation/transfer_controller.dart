import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/android/android_storage.dart';
import 'package:modern_downloader/core/logger/logger_service.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/transfer/data/lan_ipv4.dart';
import 'package:modern_downloader/features/transfer/data/localsend_api.dart';
import 'package:modern_downloader/features/transfer/data/localsend_client.dart';
import 'package:modern_downloader/features/transfer/data/payload_scanner.dart';
import 'package:modern_downloader/features/transfer/data/transfer_discovery.dart';
import 'package:modern_downloader/features/transfer/data/transfer_lan_server.dart';
import 'package:modern_downloader/features/transfer/data/transfer_security.dart';
import 'package:modern_downloader/features/transfer/data/transfer_zip_bundle.dart';
import 'package:modern_downloader/features/transfer/data/trusted_devices_store.dart';
import 'package:modern_downloader/features/transfer/domain/library_manifest.dart';
import 'package:modern_downloader/features/transfer/domain/qr_payload.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

enum TransferTab { send, receive }

@immutable
class TransferUiState {
  const TransferUiState({
    this.started = false,
    this.pin = '',
    this.port,
    this.lanIp,
    this.alias = 'Modern Downloader',
    this.fingerprint = '',
    this.portConflict = false,
    this.activeTab = TransferTab.send,
    this.peers = const [],
    this.selectedCreatorKeys = const {},
    this.extraFolders = const [],
    this.extraFiles = const [],
    this.compressZip = false,
    this.selectedFilesCount = 0,
    this.selectedTotalBytes = 0,
    this.progress,
    this.incoming,
    this.peerPinPrompt,
    this.lastError,
    this.diagnosticMessage,
    this.lastPeerAttempt,
    this.isScanningSubnet = false,
    this.subnetScanProgress,
  });

  final bool started;
  final String pin;
  final int? port;
  final String? lanIp;
  final String alias;
  final String fingerprint;
  final bool portConflict;
  final TransferTab activeTab;
  final List<TransferPeer> peers;
  final Set<String> selectedCreatorKeys;
  final List<String> extraFolders;
  final List<String> extraFiles;
  final bool compressZip;
  final int selectedFilesCount;
  final int selectedTotalBytes;
  final TransferProgress? progress;
  final IncomingOffer? incoming;
  final TransferPeer? peerPinPrompt;
  final String? lastError;
  final String? diagnosticMessage;
  final TransferPeer? lastPeerAttempt;
  final bool isScanningSubnet;
  final double? subnetScanProgress;

  String? get qrUrl {
    final ip = lanIp;
    final bound = port;
    if (ip == null || ip.isEmpty || bound == null || pin.isEmpty) return null;
    return QrPayload(ip: ip, port: bound, pin: pin).toUri().toString();
  }

  TransferUiState copyWith({
    bool? started,
    String? pin,
    int? port,
    String? lanIp,
    String? alias,
    String? fingerprint,
    bool? portConflict,
    TransferTab? activeTab,
    List<TransferPeer>? peers,
    Set<String>? selectedCreatorKeys,
    List<String>? extraFolders,
    List<String>? extraFiles,
    bool? compressZip,
    int? selectedFilesCount,
    int? selectedTotalBytes,
    TransferProgress? progress,
    IncomingOffer? incoming,
    TransferPeer? peerPinPrompt,
    String? lastError,
    String? diagnosticMessage,
    TransferPeer? lastPeerAttempt,
    bool? isScanningSubnet,
    double? subnetScanProgress,
    bool clearIncoming = false,
    bool clearPeerPin = false,
    bool clearError = false,
    bool clearProgress = false,
    bool clearDiagnostic = false,
  }) {
    return TransferUiState(
      started: started ?? this.started,
      pin: pin ?? this.pin,
      port: port ?? this.port,
      lanIp: lanIp ?? this.lanIp,
      alias: alias ?? this.alias,
      fingerprint: fingerprint ?? this.fingerprint,
      portConflict: portConflict ?? this.portConflict,
      activeTab: activeTab ?? this.activeTab,
      peers: peers ?? this.peers,
      selectedCreatorKeys: selectedCreatorKeys ?? this.selectedCreatorKeys,
      extraFolders: extraFolders ?? this.extraFolders,
      extraFiles: extraFiles ?? this.extraFiles,
      compressZip: compressZip ?? this.compressZip,
      selectedFilesCount: selectedFilesCount ?? this.selectedFilesCount,
      selectedTotalBytes: selectedTotalBytes ?? this.selectedTotalBytes,
      progress: clearProgress ? null : (progress ?? this.progress),
      incoming: clearIncoming ? null : (incoming ?? this.incoming),
      peerPinPrompt: clearPeerPin
          ? null
          : (peerPinPrompt ?? this.peerPinPrompt),
      lastError: clearError ? null : (lastError ?? this.lastError),
      diagnosticMessage: clearDiagnostic
          ? null
          : (diagnosticMessage ?? this.diagnosticMessage),
      lastPeerAttempt: lastPeerAttempt ?? this.lastPeerAttempt,
      isScanningSubnet: isScanningSubnet ?? this.isScanningSubnet,
      subnetScanProgress: subnetScanProgress ?? this.subnetScanProgress,
    );
  }
}

class TransferController extends StateNotifier<TransferUiState> {
  TransferController(this._ref) : super(const TransferUiState());

  final Ref _ref;
  final LocalSendClient _client = LocalSendClient();
  TransferLanServer? _server;
  TransferDiscovery? _discovery;
  TrustedDevicesStore? _trusted;
  Completer<bool>? _incomingWait;
  bool _busy = false;
  int _sendId = 0;
  int _bytesDone = 0;
  DateTime _lastUi = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSpeedSample = DateTime.fromMillisecondsSinceEpoch(0);
  int _bytesDeltaSample = 0;
  double _currentSpeed = 0.0;

  Future<void> start() async {
    if (state.started) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'transfer_v1'));
      await dir.create(recursive: true);
      final identityStore = TransferIdentityStore(
        File(p.join(dir.path, 'identity.json')),
      );
      _trusted = TrustedDevicesStore(File(p.join(dir.path, 'trusted.json')));
      await _trusted!.load();
      final fingerprint = await identityStore.loadOrCreate(
        fixedFingerprint: TransferSecurity.certificateFingerprint,
      );
      String alias;
      try {
        alias = Platform.localHostname;
      } catch (_) {
        alias = 'Modern Downloader';
      }
      if (alias.trim().isEmpty) alias = 'Modern Downloader';
      final identity = TransferIdentity(
        alias: alias,
        fingerprint: fingerprint,
        deviceModel: Platform.operatingSystem,
        deviceType: PlatformInfo.isMobile
            ? TransferDeviceType.mobile
            : TransferDeviceType.desktop,
      );
      final pin = TransferPin.sixDigits();
      final settings = _ref.read(settingsProvider);
      var destRoot = settings.outputFolder;
      if (destRoot.trim().isEmpty) {
        destRoot = await AndroidStorage.resolveDefaultOutputFolder();
      }
      _server = TransferLanServer(
        identity: identity,
        destRoot: destRoot,
        forbiddenPort: settings.serverPort,
        isTrusted: (fp) => _trusted?.contains(fp) ?? false,
        onIncoming: _onIncoming,
        onPeer: _addPeer,
      );
      _server!.pin = pin;
      final port = await _server!.start();
      final conflict = port != LocalSendApi.defaultPort;
      final ip = await LanIpv4.detect();
      _discovery = TransferDiscovery(
        identity: identity,
        client: _client,
        onPeer: _addPeer,
      );
      await _discovery!.start(ourPort: port);
      state = state.copyWith(
        started: true,
        pin: pin,
        port: port,
        lanIp: ip,
        alias: alias,
        fingerprint: fingerprint,
        portConflict: conflict,
        clearError: true,
      );
      _refreshShare();
    } catch (e) {
      LoggerService.e('Transfer hub failed to start', e);
      state = state.copyWith(lastError: e.toString());
    }
  }

  Future<void> stop() async {
    await _discovery?.stop();
    await _server?.stop();
    _discovery = null;
    _server = null;
    state = state.copyWith(started: false, clearProgress: true);
  }

  @override
  void dispose() {
    unawaited(stop());
    _client.close();
    super.dispose();
  }

  void toggleCreator(String key) {
    final next = {...state.selectedCreatorKeys};
    if (!next.add(key)) next.remove(key);
    state = state.copyWith(selectedCreatorKeys: next);
    _refreshShare();
  }

  void addCreator(String key) {
    if (key.isEmpty || state.selectedCreatorKeys.contains(key)) return;
    state = state.copyWith(
      selectedCreatorKeys: {...state.selectedCreatorKeys, key},
    );
    _refreshShare();
  }

  void replaceCreators(Set<String> keys) {
    state = state.copyWith(selectedCreatorKeys: keys);
    _refreshShare();
  }

  void clearCreators() {
    if (state.selectedCreatorKeys.isEmpty) return;
    state = state.copyWith(selectedCreatorKeys: const {});
    _refreshShare();
  }

  void clearAllPayload() {
    state = state.copyWith(
      selectedCreatorKeys: const {},
      extraFolders: const [],
      extraFiles: const [],
    );
    _refreshShare();
  }

  Future<void> addExtraFolder() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null || path.isEmpty) return;
      if (state.extraFolders.contains(path)) return;
      state = state.copyWith(extraFolders: [...state.extraFolders, path]);
      _refreshShare();
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
    }
  }

  Future<List<String>?> inspectSubfolders(String parentPath) async {
    try {
      final dir = Directory(parentPath);
      if (!await dir.exists()) return null;
      final subdirs = <String>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          subdirs.add(entity.path);
        }
      }
      subdirs.sort((a, b) => p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase()));
      return subdirs;
    } catch (_) {
      return null;
    }
  }

  void addFolders(List<String> paths) {
    final next = {...state.extraFolders, ...paths}.toList();
    state = state.copyWith(extraFolders: next);
    _refreshShare();
  }

  void removeExtraFolder(String path) {
    state = state.copyWith(
      extraFolders: [
        for (final item in state.extraFolders)
          if (item != path) item,
      ],
    );
    _refreshShare();
  }

  Future<void> addExtraFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const [
          'mp4', 'mkv', 'webm', 'mov', 'avi', 'flv', 'm4v',
          'mp3', 'm4a', 'wav', 'flac', 'opus', 'aac', 'ogg',
          'zip',
        ],
      );
      if (result == null || result.files.isEmpty) return;
      final paths = result.files
          .map((f) => f.path)
          .whereType<String>()
          .where((p) => p.isNotEmpty)
          .toList();
      if (paths.isEmpty) return;
      final next = {...state.extraFiles, ...paths}.toList();
      state = state.copyWith(extraFiles: next);
      _refreshShare();
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
    }
  }

  void removeExtraFile(String path) {
    state = state.copyWith(
      extraFiles: [
        for (final item in state.extraFiles)
          if (item != path) item,
      ],
    );
    _refreshShare();
  }

  void setCompressZip(bool value) {
    state = state.copyWith(compressZip: value);
    _refreshShare();
  }

  void toggleCompressZip() {
    setCompressZip(!state.compressZip);
  }

  void answerIncoming(bool accept) {
    final offer = state.incoming;
    _incomingWait?.complete(accept);
    _incomingWait = null;
    if (accept && offer != null && offer.fingerprint.isNotEmpty) {
      unawaited(_trusted?.add(offer.fingerprint));
    }
    state = state.copyWith(clearIncoming: true);
  }

  void dismissPeerPin() {
    state = state.copyWith(clearPeerPin: true);
  }

  void setTab(TransferTab tab) {
    if (state.activeTab == tab) return;
    state = state.copyWith(activeTab: tab);
  }

  void cancelTransfer() {
    _sendId++;
    _busy = false;
    _client.abort();
    state = state.copyWith(
      clearProgress: true,
      clearError: true,
      clearDiagnostic: true,
    );
    _refreshShare();
  }

  bool _isActive(int id) => id == _sendId;

  void retryLastTransfer() {
    final peer = state.lastPeerAttempt;
    if (peer != null) {
      unawaited(sendTo(peer));
    }
  }

  Future<TransferPeer?> connectDirectIp(
    String ip, {
    int port = LocalSendApi.defaultPort,
  }) async {
    final discovery = _discovery;
    if (discovery == null) return null;
    state = state.copyWith(clearError: true, clearDiagnostic: true);
    final peer = await discovery.probeIp(ip, port: port);
    if (peer == null) {
      state = state.copyWith(
        lastError: 'Appareil injoignable ($ip:$port)',
        diagnosticMessage:
            'Vérifiez que LocalSend est ouvert sur cet appareil, sur le même réseau Wi-Fi.',
      );
    }
    return peer;
  }

  Future<void> scanSubnet() async {
    final ip = state.lanIp;
    final discovery = _discovery;
    if (ip == null || discovery == null || state.isScanningSubnet) return;
    state = state.copyWith(isScanningSubnet: true, subnetScanProgress: 0.0);
    try {
      await discovery.scanSubnet(
        ip,
        port: state.port ?? LocalSendApi.defaultPort,
        onProgress: (fraction) {
          state = state.copyWith(subnetScanProgress: fraction);
        },
      );
    } finally {
      state = state.copyWith(isScanningSubnet: false, subnetScanProgress: null);
    }
  }

  Future<void> sendTo(TransferPeer peer, {String? pin}) async {
    if (_busy) return;
    final id = ++_sendId;
    _busy = true;
    _bytesDone = 0;
    _bytesDeltaSample = 0;
    _currentSpeed = 0.0;
    _lastSpeedSample = DateTime.now();
    state = state.copyWith(
      progress: const TransferProgress(
        phase: TransferPhase.preparing,
        bytesDone: 0,
        bytesTotal: 0,
      ),
      clearError: true,
      clearDiagnostic: true,
      clearPeerPin: true,
      lastPeerAttempt: peer,
    );
    File? tempZipToCleanup;
    try {
      final bundle = await _buildBundle(hash: false);
      if (!_isActive(id)) return;
      if (bundle.files.isEmpty) {
        state = state.copyWith(
          progress: const TransferProgress(
            phase: TransferPhase.failed,
            bytesDone: 0,
            bytesTotal: 0,
            error: 'empty',
          ),
          lastError: 'empty',
        );
        return;
      }
      var files = bundle.files;
      if (TransferZipBundle.shouldArchive(
        compressZip: state.compressZip,
        fileCount: files.length,
      )) {
        final rawTotal = files.fold<int>(0, (sum, f) => sum + f.size);
        state = state.copyWith(
          progress: TransferProgress(
            phase: TransferPhase.compressing,
            bytesDone: 0,
            bytesTotal: rawTotal,
            currentName: 'archive.zip',
          ),
        );
        final zipPath = p.join(
          Directory.systemTemp.path,
          'md-bundle-${const Uuid().v4()}.zip',
        );
        tempZipToCleanup = File(zipPath);
        final zipFuture = TransferZipBundle.writeToTempIsolated(
          files,
          zipPath: zipPath,
          flatten: true,
        );
        while (true) {
          final finished = await Future.any<bool>([
            zipFuture.then((_) => true),
            Future<bool>.delayed(const Duration(milliseconds: 200), () => false),
          ]);
          if (!_isActive(id)) {
            try {
              await zipFuture;
            } catch (_) {}
            return;
          }
          if (finished) break;
          var written = 0;
          try {
            if (await tempZipToCleanup.exists()) {
              written = await tempZipToCleanup.length();
            }
          } catch (_) {}
          state = state.copyWith(
            progress: TransferProgress(
              phase: TransferPhase.compressing,
              bytesDone: written,
              bytesTotal: rawTotal,
              currentName: 'archive.zip',
            ),
          );
        }
        final zipFile = await zipFuture;
        if (!_isActive(id)) return;
        final zipSize = await zipFile.length();
        final zipName = '${TransferZipBundle.archiveName(files)}.zip';
        files = [
          TransferFile(
            id: const Uuid().v4(),
            fileName: zipName,
            size: zipSize,
            localPath: zipFile.path,
          ),
        ];
      }
      final listed = files.fold<int>(0, (sum, file) => sum + file.size);
      LoggerService.i('Transfer LocalSend ${files.length} items, $listed B');
      state = state.copyWith(
        progress: TransferProgress(
          phase: TransferPhase.waitingPeer,
          bytesDone: 0,
          bytesTotal: listed,
        ),
      );
      _refreshShare(files: files);
      final identity = TransferIdentity(
        alias: state.alias,
        fingerprint: state.fingerprint,
        deviceModel: Platform.operatingSystem,
        deviceType: PlatformInfo.isMobile
            ? TransferDeviceType.mobile
            : TransferDeviceType.desktop,
      );
      final outcome = await _client.prepareUpload(
        peer: peer,
        identity: identity,
        files: files,
        ourPort: state.port ?? LocalSendApi.defaultPort,
        pin: pin,
      );
      if (!_isActive(id)) return;
      final target = outcome.via ?? peer;
      if (target.protocol != peer.protocol) {
        _addPeer(target);
      }
      if (outcome.code == TransferProtocolCode.pinRequired && pin == null) {
        state = state.copyWith(peerPinPrompt: target, clearProgress: true);
        return;
      }
      if (!outcome.isOk || outcome.success == null) {
        final diag = switch (outcome.code) {
          TransferProtocolCode.timeout =>
            'Délai de connexion dépassé. Vérifiez que l\'appareil récepteur est allumé et sur le même Wi-Fi.',
          TransferProtocolCode.connectionRefused =>
            'Connexion refusée. Ouvrez LocalSend sur l\'appareil récepteur et activez le mode Recevoir.',
          TransferProtocolCode.pinRequired =>
            'Code PIN requis par l\'appareil récepteur.',
          TransferProtocolCode.rejected =>
            'Transfert refusé par l\'utilisateur sur l\'appareil récepteur.',
          TransferProtocolCode.busy =>
            'L\'appareil récepteur est déjà occupé par un autre transfert.',
          TransferProtocolCode.checksumMismatch =>
            'Erreur d\'intégrité des données (somme de contrôle non concordante).',
          _ => outcome.message ?? 'Erreur de communication avec l\'appareil.',
        };
        state = state.copyWith(
          progress: TransferProgress(
            phase: TransferPhase.failed,
            bytesDone: 0,
            bytesTotal: 0,
            error: outcome.code.name,
          ),
          lastError: outcome.message ?? outcome.code.name,
          diagnosticMessage: diag,
          lastPeerAttempt: target,
        );
        return;
      }
      final tokens = outcome.success!.tokens;
      final accepted = [
        for (final file in files)
          if (tokens.containsKey(file.id)) file,
      ];
      final skipped = files.length - accepted.length;
      final total = accepted.fold<int>(0, (sum, file) => sum + file.size);
      _bytesDone = 0;
      state = state.copyWith(
        progress: TransferProgress(
          phase: TransferPhase.transferring,
          bytesDone: 0,
          bytesTotal: total,
          skipped: skipped,
        ),
      );
      await _client.uploadAll(
        peer: target,
        sessionId: outcome.success!.sessionId,
        tokens: tokens,
        files: accepted,
        onProgress: _onBytes,
      );
      if (!_isActive(id)) return;
      if (peer.fingerprint.isNotEmpty) {
        await _trusted?.add(peer.fingerprint);
      }
      state = state.copyWith(
        progress: TransferProgress(
          phase: TransferPhase.done,
          bytesDone: total,
          bytesTotal: total,
          skipped: skipped,
        ),
      );
    } catch (e) {
      if (!_isActive(id)) return;
      LoggerService.e('Transfer send failed', e);
      state = state.copyWith(
        progress: TransferProgress(
          phase: TransferPhase.failed,
          bytesDone: _bytesDone,
          bytesTotal: state.progress?.bytesTotal ?? 0,
          error: e.toString(),
        ),
        lastError: e.toString(),
      );
    } finally {
      if (_isActive(id)) {
        _busy = false;
      }
      if (tempZipToCleanup != null) {
        try {
          if (await tempZipToCleanup.exists()) {
            await tempZipToCleanup.delete();
          }
        } catch (_) {}
      }
      _refreshShare();
    }
  }

  Future<PayloadBundle> _buildBundle({bool hash = false}) async {
    final output = _ref.read(settingsProvider).outputFolder;
    final folders = _ref.read(creatorFoldersProvider).folders;
    final items = _ref.read(downloadListProvider).valueOrNull ?? const [];
    final files = <TransferFile>[];
    final entries = <LibraryManifestEntry>[];
    final usedNames = <String>{};

    for (final folder in folders) {
      if (!state.selectedCreatorKeys.contains(folder.key)) continue;
      final subset = [
        for (final item in items)
          if (folder.itemIds.contains(item.id)) item,
      ];
      final part = await PayloadScanner.fromDownloadItems(
        items: subset,
        outputFolder: output,
        creatorKey: folder.key,
        creatorHandle: folder.handle,
        hash: hash,
        flatten: true,
        usedNames: usedNames,
      );
      files.addAll(part.files);
      entries.addAll(part.manifest.entries);
    }
    if (state.extraFolders.isNotEmpty) {
      final part = await PayloadScanner.scanDirectories(
        [for (final path in state.extraFolders) Directory(path)],
        hash: hash,
        flatten: true,
        usedNames: usedNames,
      );
      files.addAll(part.files);
      entries.addAll(part.manifest.entries);
    }
    if (state.extraFiles.isNotEmpty) {
      final part = await PayloadScanner.scanFiles(
        [for (final path in state.extraFiles) File(path)],
        hash: hash,
        flatten: true,
        usedNames: usedNames,
      );
      files.addAll(part.files);
      entries.addAll(part.manifest.entries);
    }
    return PayloadBundle(
      files: files,
      manifest: LibraryManifest(entries: entries),
    );
  }

  void _refreshShare({List<TransferFile>? files}) {
    final server = _server;
    if (server == null) return;
    if (files != null) {
      server.setShare(ShareOffer(files: files, pin: state.pin));
      return;
    }
    unawaited(() async {
      try {
        final bundle = await _buildBundle();
        final total = bundle.files.fold<int>(0, (sum, f) => sum + f.size);
        state = state.copyWith(
          selectedFilesCount: bundle.files.length,
          selectedTotalBytes: total,
        );
        server.setShare(ShareOffer(files: bundle.files, pin: state.pin));
      } catch (e) {
        LoggerService.w('Share offer refresh failed: $e');
      }
    }());
  }

  Future<bool> _onIncoming(IncomingOffer offer) async {
    _incomingWait?.complete(false);
    final wait = Completer<bool>();
    _incomingWait = wait;
    state = state.copyWith(incoming: offer);
    return wait.future;
  }

  void _addPeer(TransferPeer peer) {
    final known = _trusted?.contains(peer.fingerprint) ?? false;
    final tagged = peer.copyWith(known: known);
    final next = [
      for (final item in state.peers)
        if (item.fingerprint != tagged.fingerprint) item,
      tagged,
    ];
    state = state.copyWith(peers: next);
  }

  void _onBytes(int delta, String name) {
    final positive = max(0, delta);
    _bytesDone += positive;
    _bytesDeltaSample += positive;
    final now = DateTime.now();
    final speedElapsed = now.difference(_lastSpeedSample).inMilliseconds;
    if (speedElapsed >= 400) {
      _currentSpeed = (_bytesDeltaSample * 1000) / speedElapsed;
      _bytesDeltaSample = 0;
      _lastSpeedSample = now;
    }
    if (now.difference(_lastUi).inMilliseconds < 150) return;
    _lastUi = now;
    final current = state.progress;
    if (current == null) return;
    state = state.copyWith(
      progress: TransferProgress(
        phase: TransferPhase.transferring,
        bytesDone: _bytesDone,
        bytesTotal: current.bytesTotal,
        currentName: name,
        skipped: current.skipped,
        failed: current.failed,
        bytesPerSecond: _currentSpeed,
      ),
    );
  }
}

final transferControllerProvider =
    StateNotifierProvider<TransferController, TransferUiState>((ref) {
      return TransferController(ref);
    });
