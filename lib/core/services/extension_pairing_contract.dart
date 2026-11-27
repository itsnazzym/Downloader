import '../security/pairing_coordinator.dart';

/// WebSocket messages of the extension pairing handshake. The server only
/// reports decisions: approval happens in the app UI, never through a message.
class ExtensionPairingContract {
  ExtensionPairingContract._();

  // client -> server
  static const hello = 'HELLO';
  static const pairRequest = 'PAIR_REQUEST';

  // server -> client
  static const helloOk = 'HELLO_OK';
  static const authFailed = 'AUTH_FAILED';
  static const pairPending = 'PAIR_PENDING';
  static const pairOk = 'PAIR_OK';
  static const pairDenied = 'PAIR_DENIED';
  static const pairExpired = 'PAIR_EXPIRED';
  static const pairPaused = 'PAIR_PAUSED';
  static const pairBusy = 'PAIR_BUSY';

  // AUTH_FAILED reasons
  static const pairingRequired = 'pairing_required';
  static const notAuthenticated = 'not_authenticated';
  static const helloTimeout = 'hello_timeout';

  /// What an origin blocked with "Always deny" is told to wait.
  static const blockedRetryAfter = Duration(days: 1);

  static Map<String, dynamic> authFailedMessage([String? reason]) => {
    'type': authFailed,
    'reason': ?reason,
  };

  /// [code] stays a string so leading zeros survive ('0042').
  static Map<String, dynamic> pending(
    PairingRequest request,
    Duration expiresIn,
  ) => {
    'type': pairPending,
    'requestId': request.id,
    'code': request.code,
    'expiresInSeconds': _seconds(expiresIn),
  };

  static Map<String, dynamic> ok(String token) => {
    'type': pairOk,
    'token': token,
  };

  static Map<String, dynamic> denied(Duration retryAfter) => {
    'type': pairDenied,
    'retryAfterSeconds': _seconds(retryAfter),
  };

  static Map<String, dynamic> paused(Duration retryAfter) => {
    'type': pairPaused,
    'retryAfterSeconds': _seconds(retryAfter),
  };

  static Map<String, dynamic> expired() => {'type': pairExpired};

  static Map<String, dynamic> busy() => {'type': pairBusy};

  /// Rounded up: a client waiting this long never retries too early.
  static int _seconds(Duration d) =>
      d.isNegative ? 0 : (d.inMicroseconds + 999999) ~/ 1000000;
}
