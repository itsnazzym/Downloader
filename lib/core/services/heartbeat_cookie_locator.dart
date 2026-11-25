import 'dart:io';

import 'package:modern_downloader/core/security/local_server_auth.dart';

/// Resolves per-domain heartbeat cookie files written by the local WS bridge.
class HeartbeatCookieLocator {
  HeartbeatCookieLocator._();

  static Future<String?> pathForUrl(String url) async {
    try {
      final host = Uri.parse(url).host;
      if (host.isEmpty) return null;
      // TikTok exports have no creator handle, so downloads use tiktokv.com's
      // share URL. Authentication still comes from the tiktok.com session.
      final cookieHost = host == 'tiktokv.com' || host == 'www.tiktokv.com'
          ? 'www.tiktok.com'
          : host;
      // Only the host and its parent domains can match: check those few
      // file names instead of listing %TEMP% (tens of thousands of entries on
      // a neglected PC) for every download.
      final labels = cookieHost.toLowerCase().split('.');
      for (var i = 0; i < labels.length; i++) {
        final domain = labels.sublist(i).join('.');
        final safeName = LocalServerAuth.sanitizeDomainForFilename(domain);
        final file = File(
          '${Directory.systemTemp.path}/heartbeat_cookies_$safeName.txt',
        );
        if (await file.exists()) return file.path;
      }
    } catch (_) {}
    return null;
  }
}
