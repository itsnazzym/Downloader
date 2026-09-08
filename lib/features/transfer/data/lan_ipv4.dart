import 'dart:io';

class LanIpv4 {
  const LanIpv4._();

  static Future<String?> detect() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      String? bestIp;
      var bestScore = -1;

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final ip = addr.address;
          if (ip.startsWith('169.254.')) continue;
          final score = _scoreInterface(name, ip);
          if (score > bestScore) {
            bestScore = score;
            bestIp = ip;
          }
        }
      }
      return bestIp;
    } catch (_) {
      return null;
    }
  }

  static Future<Set<String>> allLocalIps() async {
    final ips = <String>{};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('169.254.')) {
            ips.add(addr.address);
          }
        }
      }
    } catch (_) {}
    return ips;
  }

  static int _scoreInterface(String name, String ip) {
    if (_isVirtual(name)) {
      return 10;
    }
    if (name.contains('wi-fi') || name.contains('wifi') || name.contains('wlan')) {
      return 100;
    }
    if (name.contains('ethernet') || name.contains('eth') || name.contains('en')) {
      return 90;
    }
    if (ip.startsWith('192.168.') || ip.startsWith('10.')) {
      return 80;
    }
    return 50;
  }

  static bool _isVirtual(String name) {
    return name.contains('vethernet') ||
        name.contains('virtual') ||
        name.contains('vbox') ||
        name.contains('vmnet') ||
        name.contains('wsl') ||
        name.contains('hyper-v') ||
        name.contains('docker') ||
        name.contains('tailscale') ||
        name.contains('zerotier') ||
        name.contains('tap') ||
        name.contains('tun') ||
        name.contains('pseudo') ||
        name.contains('bridge');
  }
}
