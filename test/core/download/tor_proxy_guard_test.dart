import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/tor_proxy_guard.dart';

void main() {
  group('TorProxyGuard.resolveProxyUrl', () {
    test('returns null when Tor is disabled', () async {
      final proxy = await TorProxyGuard.resolveProxyUrl(
        useTorProxy: false,
        probe: (host, port, timeout) async => true,
      );
      expect(proxy, isNull);
    });

    test('returns socks5 URL when Tor is enabled and listening', () async {
      final proxy = await TorProxyGuard.resolveProxyUrl(
        useTorProxy: true,
        probe: (host, port, timeout) async {
          expect(host, TorProxyGuard.host);
          expect(port, TorProxyGuard.port);
          return true;
        },
      );
      expect(proxy, TorProxyGuard.proxyUrl);
    });

    test('returns null when Tor is enabled but port is closed', () async {
      final proxy = await TorProxyGuard.resolveProxyUrl(
        useTorProxy: true,
        probe: (host, port, timeout) async => false,
      );
      expect(proxy, isNull);
    });
  });
}
