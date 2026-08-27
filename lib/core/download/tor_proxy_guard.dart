import 'dart:async';
import 'dart:io';

typedef TorPortProbe =
    Future<bool> Function(String host, int port, Duration timeout);

/// Decides whether yt-dlp should receive `--proxy socks5://127.0.0.1:9050`.
class TorProxyGuard {
  static const String host = '127.0.0.1';
  static const int port = 9050;
  static const String proxyUrl = 'socks5://$host:$port';
  static const Duration defaultTimeout = Duration(seconds: 1);

  /// Returns [proxyUrl] when Tor is reachable; otherwise null (download direct).
  static Future<String?> resolveProxyUrl({
    required bool useTorProxy,
    TorPortProbe? probe,
    Duration timeout = defaultTimeout,
  }) async {
    if (!useTorProxy) return null;
    final isUp = await (probe ?? isTorListening)(host, port, timeout);
    if (!isUp) return null;
    return proxyUrl;
  }

  static Future<bool> isTorListening(
    String host,
    int port,
    Duration timeout,
  ) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      await socket.close();
      return true;
    } on Object {
      return false;
    }
  }
}
