import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:modern_downloader/core/logger/logger_service.dart';
import 'package:modern_downloader/features/transfer/data/localsend_api.dart';
import 'package:modern_downloader/features/transfer/data/localsend_client.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';

class TransferDiscovery {
  TransferDiscovery({
    required this.identity,
    required this.client,
    required this.onPeer,
  });

  final TransferIdentity identity;
  final LocalSendClient client;
  final void Function(TransferPeer peer) onPeer;

  RawDatagramSocket? _socket;
  Timer? _pulse;
  int _ourPort = LocalSendApi.defaultPort;

  Future<void> start({required int ourPort}) async {
    await stop();
    _ourPort = ourPort;
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        LocalSendApi.defaultPort,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );
      _socket!.broadcastEnabled = true;
      try {
        _socket!.joinMulticast(InternetAddress(LocalSendApi.multicastGroup));
      } catch (e) {
        LoggerService.w('Multicast join failed: $e');
      }
      _socket!.listen(_onDatagram);
    } catch (e) {
      LoggerService.w('UDP discovery bind failed: $e');
      _socket = null;
    }
    _pulse = Timer.periodic(const Duration(seconds: 4), (_) => announce());
    await announce();
  }

  Future<void> announce() async {
    final payload = utf8.encode(
      jsonEncode(
        LocalSendApi.multicastDto(
          identity,
          port: _ourPort,
          download: true,
          announce: true,
        ),
      ),
    );
    try {
      _socket?.send(
        payload,
        InternetAddress(LocalSendApi.multicastGroup),
        LocalSendApi.defaultPort,
      );
    } catch (_) {}
  }

  Future<TransferPeer?> probeIp(
    String ip, {
    int port = LocalSendApi.defaultPort,
  }) async {
    final cleanIp = ip.trim();
    if (cleanIp.isEmpty) return null;
    final candidate = TransferPeer(
      alias: 'Device',
      fingerprint: '',
      ip: cleanIp,
      port: port,
      protocol: 'https',
    );
    final verified = await client.testPeerConnection(
      candidate,
      timeout: const Duration(seconds: 3),
    );
    if (verified != null && verified.fingerprint != identity.fingerprint) {
      onPeer(verified);
      unawaited(
        client.register(peer: verified, identity: identity, ourPort: _ourPort),
      );
      return verified;
    }
    return null;
  }

  Future<int> scanSubnet(
    String localIp, {
    int port = LocalSendApi.defaultPort,
    void Function(double fraction)? onProgress,
  }) async {
    final parts = localIp.trim().split('.');
    if (parts.length != 4) return 0;
    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}.';
    final ourLast = int.tryParse(parts[3]) ?? 0;
    var found = 0;
    const total = 254;
    var completed = 0;

    // Scan in concurrent batches of 20
    final ips = [
      for (var i = 1; i <= total; i++)
        if (i != ourLast) '$prefix$i',
    ];

    const batchSize = 20;
    for (var i = 0; i < ips.length; i += batchSize) {
      final batch = ips.sublist(i, (i + batchSize).clamp(0, ips.length));
      final results = await Future.wait(batch.map((ip) => probeIp(ip, port: port)));
      found += results.where((p) => p != null).length;
      completed += batch.length;
      onProgress?.call(completed / ips.length);
    }
    return found;
  }

  void _onDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket?.receive();
    if (datagram == null) return;
    final map = LocalSendApi.decodeMap(utf8.decode(datagram.data));
    if (map == null) return;
    if (map['fingerprint'] == identity.fingerprint) return;
    if (map['announce'] != true) return;
    final peer = LocalSendApi.peerFromRegister(
      map,
      ip: datagram.address.address,
    );
    if (peer == null) return;
    onPeer(peer.copyWith(lastSeen: DateTime.now()));
    unawaited(
      client.register(peer: peer, identity: identity, ourPort: _ourPort),
    );
  }

  Future<void> stop() async {
    _pulse?.cancel();
    _pulse = null;
    _socket?.close();
    _socket = null;
  }
}
