import 'dart:async';
import 'dart:io';

typedef TorPortProbe =
    Future<bool> Function(String host, int port, Duration timeout);

/// Resolves a SOCKS endpoint for yt-dlp without silently falling back to direct
/// network access when Tor is enabled.
class TorProxyGuard {
  static const String host = '127.0.0.1';
  static const int port = 9050;
  static const String proxyUrl = 'socks5h://$host:$port';
  static const Duration defaultTimeout = Duration(seconds: 2);

  /// Returns null only when Tor is disabled. An unavailable proxy is an error,
  /// so a Tor-enabled download cannot leak onto the direct connection.
  static Future<String?> resolveProxyUrl({
    required bool useTorProxy,
    TorPortProbe? probe,
    Duration timeout = defaultTimeout,
  }) async {
    if (!useTorProxy) return null;
    final isUp = await (probe ?? isTorListening)(host, port, timeout);
    if (!isUp) {
      throw TorProxyUnavailableException(
        'Tor is enabled, but its SOCKS proxy is not ready at $host:$port.',
      );
    }
    return proxyUrl;
  }

  /// Checks both TCP reachability and the SOCKS5 greeting. This avoids treating
  /// an unrelated service on port 9050 as a working Tor proxy.
  static Future<bool> isTorListening(
    String host,
    int port,
    Duration timeout,
  ) async {
    Socket? socket;
    StreamSubscription<dynamic>? responseSubscription;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      final response = Completer<List<int>>();
      final received = <int>[];
      responseSubscription = socket.listen(
        (chunk) {
          received.addAll(chunk as List<int>);
          if (received.length >= 2 && !response.isCompleted) {
            response.complete(received.take(2).toList(growable: false));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!response.isCompleted) {
            response.completeError(error, stackTrace);
          }
        },
        onDone: () {
          if (!response.isCompleted) {
            response.completeError(
              const SocketException('SOCKS5 proxy closed before replying.'),
            );
          }
        },
      );
      socket.add(const [0x05, 0x01, 0x00]); // SOCKS5, no authentication.
      await socket.flush();
      final greeting = await response.future.timeout(timeout);
      return greeting[0] == 0x05 && greeting[1] == 0x00;
    } on Object {
      return false;
    } finally {
      await responseSubscription?.cancel();
      try {
        await socket?.close();
      } on Object {
        // A failed probe should not mask the original connection result.
      }
    }
  }
}

class TorProxyUnavailableException implements Exception {
  const TorProxyUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}
