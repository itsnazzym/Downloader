import 'dart:io';

class LanIpv4 {
  const LanIpv4._();

  static Future<String?> detect() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      String? fallback;
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final ip = addr.address;
          if (ip.startsWith('169.254.')) continue;
          if (_looksLan(name)) return ip;
          fallback ??= ip;
        }
      }
      return fallback;
    } catch (_) {
      return null;
    }
  }

  static bool _looksLan(String name) {
    return name.contains('wi-fi') ||
        name.contains('wifi') ||
        name.contains('wlan') ||
        name.contains('ethernet') ||
        name.contains('lan') ||
        name.contains('eth');
  }
}
