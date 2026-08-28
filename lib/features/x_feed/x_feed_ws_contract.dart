import 'package:modern_downloader/features/x_feed/gobird_x_feed_service.dart';

/// Pure helpers for the authenticated X_FEED WebSocket contract.
class XFeedWsContract {
  static const String requestType = 'X_FEED_REQUEST';
  static const String resultType = 'X_FEED_RESULT';
  /// Tweet budget for `count` on X_FEED_REQUEST (not the video display cap).
  static const int maxItems = GobirdXFeedService.maxTweetCount;

  /// Reject payloads that attempt to smuggle cookies through this channel.
  static bool containsCookieFields(Map<String, dynamic> data) {
    const forbidden = <String>{
      'cookies',
      'cookie',
      'auth_token',
      'ct0',
      'cookieHeader',
      'cookie_header',
    };
    for (final key in data.keys) {
      if (forbidden.contains(key.toLowerCase())) return true;
    }
    return false;
  }

  static int normalizeCount(Object? raw) {
    if (raw is int) return GobirdXFeedService.clampCount(raw);
    if (raw is num) return GobirdXFeedService.clampCount(raw.toInt());
    if (raw is String) {
      final parsed = int.tryParse(raw.trim());
      if (parsed != null) return GobirdXFeedService.clampCount(parsed);
    }
    return maxItems;
  }

  static String? requestIdFrom(Map<String, dynamic> data) {
    final id = data['requestId'] ?? data['id'];
    if (id is String && id.trim().isNotEmpty) return id.trim();
    if (id is num) return id.toString();
    return null;
  }
}
