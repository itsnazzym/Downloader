// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/features/transfer/data/lan_ipv4.dart';

void main() {
  test('detect LAN IPv4 on current host', () async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final iface in interfaces) {
      print('Interface ${iface.name}: ${iface.addresses.map((a) => a.address).toList()}');
    }
    final ip = await LanIpv4.detect();
    print('Detected LAN IP: $ip');
    expect(ip, isNotNull);
  });
}
