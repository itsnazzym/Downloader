import '../../features/downloader/domain/enums/download_status.dart';

class DownloadStatusGuard {
  static bool shouldRetryAfterError(DownloadStatus? status) {
    if (status == DownloadStatus.canceled || status == DownloadStatus.paused) {
      return false;
    }
    return true;
  }

  /// Errors that must fail immediately (no Retry 3/3, no gallery-dl fallback).
  static bool isNonRetryableError(Object error) {
    return isNonRetryableProxyError(error) || isPermanentExtractorError(error);
  }

  /// Proxy / connection-refused errors must fail immediately (no Retry 3/3).
  static bool isNonRetryableProxyError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('winerror 10061') ||
        text.contains('sockshttpsconnection') ||
        text.contains('connection refused') ||
        text.contains('failed to establish a new connection') ||
        text.contains('aucune connexion n\'a pu être établie') ||
        text.contains('expressément refusée') ||
        text.contains('expressement refusee') ||
        text.contains('proxy/tor unreachable');
  }

  /// yt-dlp / extractor failures that will not change on retry.
  ///
  /// Typical X-feed / extension cases: suspended tweet, tweet without video,
  /// Discord invite or other page yt-dlp cannot extract.
  static bool isPermanentExtractorError(Object error) {
    final text = error.toString().toLowerCase();
    if (_isTwitterSuspended(text)) return true;
    if (text.contains('no video could be found in this tweet')) return true;
    if (text.contains('this tweet has no downloadable video')) return true;
    if (text.contains('unsupported url')) return true;
    if (text.contains('this url is not a supported video page')) return true;
    return false;
  }

  static bool _isTwitterSuspended(String text) {
    if (!text.contains('twitter') &&
        !text.contains('[twitter]') &&
        !text.contains('x account or tweet is suspended')) {
      return false;
    }
    return text.contains(': suspended') ||
        text.contains('account is suspended') ||
        text.contains('user has been suspended') ||
        text.contains('x account or tweet is suspended');
  }

  static String userFacingProxyErrorMessage(Object error) {
    if (isNonRetryableProxyError(error)) {
      return 'Proxy/Tor unreachable (127.0.0.1:9050). '
          'Disable Tor bypass in Advanced settings, or start Tor, then retry once.';
    }
    return error.toString();
  }

  static String userFacingErrorMessage(Object error) {
    if (isNonRetryableProxyError(error)) {
      return userFacingProxyErrorMessage(error);
    }
    final lower = error.toString().toLowerCase();
    if (_isTwitterSuspended(lower)) {
      return 'X account or tweet is suspended. Retry will not work.';
    }
    if (lower.contains('no video could be found in this tweet') ||
        lower.contains('this tweet has no downloadable video')) {
      return 'This tweet has no downloadable video.';
    }
    if (lower.contains('unsupported url') ||
        lower.contains('this url is not a supported video page')) {
      return 'This URL is not a supported video page.';
    }
    return error.toString();
  }
}
