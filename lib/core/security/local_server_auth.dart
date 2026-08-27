import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Authentication helpers for the local WebSocket bridge used by browser extensions.
class LocalServerAuth {
  LocalServerAuth._();

  /// Returns true when [providedToken] matches [expectedToken] using a
  /// constant-time comparison of SHA-256 digests (avoids length/timing leaks).
  static bool isAuthorized({
    required String expectedToken,
    String? providedToken,
  }) {
    if (expectedToken.isEmpty) return false;
    if (providedToken == null || providedToken.isEmpty) return false;
    return _constantTimeEquals(providedToken, expectedToken);
  }

  static String? tokenFromMessage(Map<String, dynamic> data) {
    final token = data['token'];
    if (token is String && token.isNotEmpty) {
      return token;
    }
    return null;
  }

  /// Host suffix match: `youtube.com` matches `www.youtube.com` but not
  /// `youtube.com.evil.com`.
  static bool hostMatchesDomain(String hostname, String domain) {
    final host = hostname.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
    final d = domain.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
    if (host.isEmpty || d.isEmpty) return false;
    return host == d || host.endsWith('.$d');
  }

  /// Sanitize a domain for use as a filename fragment.
  static String sanitizeDomainForFilename(String domain) {
    final cleaned = domain
        .toLowerCase()
        .replaceFirst(RegExp(r'^\.'), '')
        .replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
    if (cleaned.isEmpty) return 'unknown';
    return cleaned;
  }

  static bool _constantTimeEquals(String a, String b) {
    final digestA = sha256.convert(utf8.encode(a)).bytes;
    final digestB = sha256.convert(utf8.encode(b)).bytes;
    // Digests are always the same length (32); XOR-accumulate without early exit.
    var diff = 0;
    for (var i = 0; i < digestA.length; i++) {
      diff |= digestA[i] ^ digestB[i];
    }
    // Also fold in raw length mismatch so unequal plaintext lengths never match
    // even if an attacker somehow forced colliding digests (defense in depth).
    diff |= a.length ^ b.length;
    return diff == 0;
  }
}
