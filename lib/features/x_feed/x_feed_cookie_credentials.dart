import 'dart:io';

/// The two session cookies gobird needs to authenticate with X.
class XFeedCredentials {
  const XFeedCredentials({required this.authToken, required this.ct0});

  final String authToken;
  final String ct0;
}

/// Resolves X credentials from cookie files already stored locally.
///
/// The browser extension sends a Netscape cookie snapshot to the authenticated
/// loopback connection. This resolver reads that snapshot without putting
/// cookie values in command-line arguments or logs.
class XFeedCookieCredentials {
  const XFeedCookieCredentials._();

  static Future<XFeedCredentials?> resolve({String? cookiesFilePath}) async {
    final candidatePaths = <String>[];
    final explicitPath = cookiesFilePath?.trim();

    try {
      await for (final entity in Directory.systemTemp.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isEmpty
            ? entity.path
            : entity.uri.pathSegments.last;
        if (name == 'heartbeat_cookies_x.com.txt' ||
            name == 'heartbeat_cookies_twitter.com.txt') {
          candidatePaths.add(entity.path);
        }
      }
    } catch (_) {
      // An unavailable temp directory simply means no heartbeat was found.
    }
    if (explicitPath != null && explicitPath.isNotEmpty) {
      candidatePaths.add(explicitPath);
    }

    final seenPaths = <String>{};
    for (final path in candidatePaths) {
      if (!seenPaths.add(path)) continue;
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        final credentials = parseNetscapeCookies(await file.readAsString());
        if (credentials != null) return credentials;
      } catch (_) {
        // Continue with the next possible cookie source.
      }
    }
    return null;
  }

  /// Extracts only `auth_token` and `ct0` for X/Twitter domains.
  static XFeedCredentials? parseNetscapeCookies(String contents) {
    String? authToken;
    String? ct0;

    for (final rawLine in contents.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trimRight();
      final lowerLine = line.toLowerCase();
      if (line.isEmpty ||
          (line.startsWith('#') && !lowerLine.startsWith('#httponly_'))) {
        continue;
      }

      final fields = line.split('\t');
      if (fields.length < 7) continue;

      final domain = _normalizeDomain(fields[0]);
      if (!_isXDomain(domain)) continue;

      final name = fields[5].trim();
      final value = fields.sublist(6).join('\t').trim();
      if (!_isSafeCookieValue(value)) continue;

      if (name == 'auth_token' && _isGobirdAuthToken(value)) {
        authToken = value;
      } else if (name == 'ct0' && _isGobirdCt0(value)) {
        ct0 = value;
      }
    }

    if (authToken == null || ct0 == null) return null;
    return XFeedCredentials(authToken: authToken, ct0: ct0);
  }

  static String _normalizeDomain(String rawDomain) {
    var domain = rawDomain.trim().toLowerCase();
    if (domain.startsWith('#httponly_')) {
      domain = domain.substring('#httponly_'.length);
    }
    return domain.replaceFirst(RegExp(r'^\.+'), '');
  }

  static bool _isXDomain(String domain) {
    return domain == 'x.com' ||
        domain.endsWith('.x.com') ||
        domain == 'twitter.com' ||
        domain.endsWith('.twitter.com');
  }

  static bool _isSafeCookieValue(String value) {
    if (value.length < 8 || value.length > 512) return false;
    for (final codeUnit in value.codeUnits) {
      if (codeUnit < 0x21 || codeUnit > 0x7E) return false;
    }
    return true;
  }

  /// gobird 26.05.13: auth_token must be exactly 40 hex characters.
  static bool _isGobirdAuthToken(String value) {
    if (value.length != 40) return false;
    for (final codeUnit in value.codeUnits) {
      final isDigit = codeUnit >= 0x30 && codeUnit <= 0x39;
      final isLowerHex = codeUnit >= 0x61 && codeUnit <= 0x66;
      final isUpperHex = codeUnit >= 0x41 && codeUnit <= 0x46;
      if (!isDigit && !isLowerHex && !isUpperHex) return false;
    }
    return true;
  }

  /// gobird 26.05.13: ct0 must be 32–160 alphanumeric characters.
  static bool _isGobirdCt0(String value) {
    if (value.length < 32 || value.length > 160) return false;
    for (final codeUnit in value.codeUnits) {
      final isDigit = codeUnit >= 0x30 && codeUnit <= 0x39;
      final isUpper = codeUnit >= 0x41 && codeUnit <= 0x5A;
      final isLower = codeUnit >= 0x61 && codeUnit <= 0x7A;
      if (!isDigit && !isUpper && !isLower) return false;
    }
    return true;
  }
}
