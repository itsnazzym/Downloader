import '../../features/downloader/domain/enums/download_status.dart';

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
        text.contains('expressement refusee');
  }

  static String userFacingProxyErrorMessage(Object error) {
    if (isNonRetryableProxyError(error)) {
      return 'Proxy/Tor unreachable (127.0.0.1:9050). '
          'Disable Tor bypass in Advanced settings, or start Tor, then retry once.';
    }
    return error.toString();
  }
}
