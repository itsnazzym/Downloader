import 'dart:io';

import 'package:modern_downloader/core/security/local_server_auth.dart';

/// Resolves per-domain heartbeat cookie files written by the local WS bridge.
class HeartbeatCookieLocator {
  HeartbeatCookieLocator._();

  static Future<String?> pathForUrl(String url) async {
    try {
      final host = Uri.parse(url).host;
      if (host.isEmpty) return null;
      final appDir = Directory.systemTemp;
      await for (final entity in appDir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : entity.path;
        if (!name.startsWith('heartbeat_cookies_') || !name.endsWith('.txt')) {
          continue;
        }
        final domainPart = name.substring(
          'heartbeat_cookies_'.length,
          name.length - '.txt'.length,
        );
        if (LocalServerAuth.hostMatchesDomain(host, domainPart)) {
          return entity.path;
        }
      }
    } catch (_) {}
    return null;
  }
}
