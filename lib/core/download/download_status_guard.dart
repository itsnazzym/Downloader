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

  /// Content-side failures that will not succeed on retry (suspended tweet, etc.).
  static bool isPermanentDownloadError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('unsupported url')) return true;
    if (text.contains('no video could be found')) return true;
    if (text.contains(': suspended') || text.endsWith('suspended')) {
      return true;
    }
    if (text.contains('tweet is unavailable') ||
        text.contains('this tweet is unavailable')) {
      return true;
    }
    if (text.contains('account is suspended') ||
        text.contains('user has been suspended')) {
      return true;
    }
    return false;
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
    final text = error.toString().toLowerCase();
    if (text.contains('unsupported url')) {
      return 'URL non prise en charge par yt-dlp '
          '(lien externe, invitation Discord, etc.).';
    }
    if (text.contains('no video could be found')) {
      return 'Aucune vidéo dans ce tweet '
          '(texte, image, GIF ou vidéo supprimée).';
    }
    if (text.contains(': suspended') ||
        text.contains('account is suspended') ||
        text.contains('user has been suspended')) {
      return 'Tweet ou compte X suspendu — contenu indisponible.';
    }
    if (text.contains('tweet is unavailable') ||
        text.contains('this tweet is unavailable')) {
      return 'Tweet X supprimé ou indisponible.';
    }
    return error.toString();
  }
}
