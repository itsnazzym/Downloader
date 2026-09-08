import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:modern_downloader/core/logger/logger_service.dart';
import 'package:modern_downloader/features/transfer/data/lan_ipv4.dart';
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
  String _protocol = 'https';
  Set<String> _ourIps = {};

  Future<void> start({
    required int ourPort,
    String protocol = 'https',
  }) async {
    await stop();
    _ourPort = ourPort;
    _protocol = protocol;
    _ourIps = await LanIpv4.allLocalIps();
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        LocalSendApi.defaultPort,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );
    } catch (e) {
      LoggerService.w('UDP discovery bind on default port failed: $e, falling back to ephemeral port');
      try {
        _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
          reuseAddress: true,
        );
      } catch (e2) {
        LoggerService.w('UDP discovery ephemeral bind failed: $e2');
        _socket = null;
      }
    }

    if (_socket != null) {
      _socket!.broadcastEnabled = true;
      final group = InternetAddress(LocalSendApi.multicastGroup);
      try {
        _socket!.joinMulticast(group);
      } catch (e) {
        LoggerService.w('Multicast join default failed: $e');
      }

      // Join multicast on all physical network interfaces
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLinkLocal: false,
        );
        for (final iface in interfaces) {
          try {
            _socket!.joinMulticast(group, iface);
          } catch (_) {}
        }
      } catch (_) {}

      _socket!.listen(_onDatagram);
    }

    _pulse = Timer.periodic(const Duration(seconds: 4), (_) => announce());
    await announce();
  }

  Future<List<InternetAddress>> _getBroadcastTargets() async {
    final targets = <InternetAddress>{
      InternetAddress(LocalSendApi.multicastGroup),
      InternetAddress('255.255.255.255'),
    };
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            targets.add(InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'));
          }
        }
      }
    } catch (_) {}
    return targets.toList();
  }

  Future<void> announce() async {
    if (_socket == null) return;
    final payload = utf8.encode(
      jsonEncode(
        LocalSendApi.multicastDto(
          identity,
          port: _ourPort,
          download: true,
          announce: true,
          protocol: _protocol,
        ),
      ),
    );
    final targets = await _getBroadcastTargets();
    for (final target in targets) {
      try {
        _socket?.send(payload, target, LocalSendApi.defaultPort);
      } catch (_) {}
    }
  }

  Future<TransferPeer?> probeIp(
    String ip, {
    int port = LocalSendApi.defaultPort,
  }) async {
    final cleanIp = ip.trim();
    if (cleanIp.isEmpty) return null;
    if (_ourIps.contains(cleanIp) && port == _ourPort) return null;

    Future<TransferPeer?> testAt(int targetPort) async {
      if (_ourIps.contains(cleanIp) && targetPort == _ourPort) return null;

      final candidate = TransferPeer(
        alias: 'Device',
        fingerprint: '',
        ip: cleanIp,
        port: targetPort,
        protocol: 'https',
      );
      final verified = await client.testPeerConnection(
        candidate,
        timeout: const Duration(seconds: 2),
      );
      if (verified != null) {
        final isSelf = _ourIps.contains(cleanIp) && targetPort == _ourPort;
        final isSameDevice = identity.deviceId != null &&
            verified.deviceId != null &&
            verified.deviceId == identity.deviceId;
        if (!isSelf && !isSameDevice) {
          onPeer(verified);
          unawaited(
            client.register(
              peer: verified,
              identity: identity,
              ourPort: _ourPort,
            ),
          );
          return verified;
        }
      }
      return null;
    }

    final p1 = await testAt(port);
    if (p1 != null) return p1;
    // Probe alternate port (check 53318 if 53317, or 53317 if 53318)
    if (port == LocalSendApi.defaultPort) {
      return await testAt(53318);
    } else if (port == 53318) {
      return await testAt(LocalSendApi.defaultPort);
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

    final ips = [
      for (var i = 1; i <= total; i++)
        if (i != ourLast) '$prefix$i',
    ];

    Future<bool> isPortOpen(String targetIp, int targetPort) async {
      try {
        final sock = await Socket.connect(
          targetIp,
          targetPort,
          timeout: const Duration(milliseconds: 350),
        );
        sock.destroy();
        return true;
      } catch (_) {
        return false;
      }
    }

    const batchSize = 30;
    for (var i = 0; i < ips.length; i += batchSize) {
      final batch = ips.sublist(i, (i + batchSize).clamp(0, ips.length));
      final results = await Future.wait(batch.map((ip) async {
        final open = await isPortOpen(ip, port) || await isPortOpen(ip, 53318);
        if (!open) return null;
        return await probeIp(ip, port: port);
      }));
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

    final incomingDeviceId = map['deviceId'] as String?;
    if (incomingDeviceId != null &&
        identity.deviceId != null &&
        incomingDeviceId == identity.deviceId) {
      return;
    }

    final senderIp = datagram.address.address;
    final senderPort = map['port'] is int ? map['port'] as int : datagram.port;
    if (_ourIps.contains(senderIp) && senderPort == _ourPort) {
      return;
    }

    if (incomingDeviceId == null &&
        map['fingerprint'] == identity.fingerprint &&
        _ourIps.contains(senderIp)) {
      return;
    }

    final peer = LocalSendApi.peerFromRegister(
      map,
      ip: senderIp,
    );
    if (peer == null) return;
    onPeer(peer.copyWith(lastSeen: DateTime.now()));

    // Send immediate unicast UDP announcement reply back to sender
    try {
      final reply = utf8.encode(
        jsonEncode(
          LocalSendApi.multicastDto(
            identity,
            port: _ourPort,
            download: true,
            announce: true,
            protocol: _protocol,
          ),
        ),
      );
      _socket?.send(reply, datagram.address, LocalSendApi.defaultPort);
      if (datagram.port != LocalSendApi.defaultPort) {
        _socket?.send(reply, datagram.address, datagram.port);
      }
    } catch (_) {}

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
