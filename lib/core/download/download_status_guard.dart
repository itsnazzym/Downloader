import '../../features/downloader/domain/enums/download_status.dart';
import '../../features/downloader/domain/exceptions/yt_dlp_exception.dart';

class DownloadStatusGuard {
  static bool shouldRetryAfterError(DownloadStatus? status) {
    if (status == DownloadStatus.canceled || status == DownloadStatus.paused) {
      return false;
    }
    return true;
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

  /// Content-side failures that will not succeed on retry (suspended tweet, etc.).
  static bool isPermanentDownloadError(Object error) {
    if (error is SuspendedContentException ||
        error is NoMediaFoundException ||
        error is UnsupportedUrlException ||
        error is VideoUnavailableException ||
        error is PrivateVideoException ||
        error is GeoBlockedException ||
        error is CopyrightException ||
        error is AgeRestrictedException ||
        error is LiveStreamOfflineException) {
      return true;
    }
    final text = error.toString().toLowerCase();
    if (text.contains('unsupported url') ||
        text.contains('this url is not a supported video page')) {
      return true;
    }
    if (text.contains('no video could be found') ||
        text.contains('this tweet has no downloadable video')) {
      return true;
    }
    if (_isTwitterSuspended(text)) return true;
    if (text.contains('tweet is unavailable') ||
        text.contains('this tweet is unavailable')) {
      return true;
    }
    if (text.contains('video unavailable') ||
        text.contains('private video') ||
        text.contains('geo-restricted')) {
      return true;
    }
    return false;
  }

  /// Avoid matching unrelated logs such as "connection suspended by peer".
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

  static bool isNonRetryableError(Object error) {
    return isNonRetryableProxyError(error) || isPermanentDownloadError(error);
  }

  static String userFacingProxyErrorMessage(Object error) {
    if (isNonRetryableProxyError(error)) {
      return 'Proxy/Tor unreachable (127.0.0.1:9050). '
          'Disable Tor bypass in Advanced settings, or start Tor, then retry once.';
    }
    return error.toString();
  }

  static String userFacingDownloadErrorMessage(Object error) {
    if (isNonRetryableProxyError(error)) {
      return userFacingProxyErrorMessage(error);
    }
    if (error is YtDlpException) {
      return error.message;
    }
    final mapped = YtDlpException.fromLog(error.toString());
    if (mapped != null) return mapped.message;
    return error.toString();
  }
}
