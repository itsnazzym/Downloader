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

  /// Real IP rate-limits or temporary captcha blocks (NOT author privacy setting).
  static bool isRateLimitOrCaptchaError(Object error) {
    if (error is RateLimitException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('429') ||
        text.contains('too many requests') ||
        text.contains('rate limit') ||
        text.contains('captcha') ||
        text.contains('cloudflare') ||
        text.contains('verify you are human');
  }

  /// Content-side failures that will not succeed on retry (suspended tweet, private video, etc.).
  static bool isPermanentDownloadError(Object error) {
    // If the error is an actual IP rate limit, captcha, or temporary network block,
    // do NOT treat it as a permanent video-deletion error.
    if (isRateLimitOrCaptchaError(error)) {
      return false;
    }

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
    final text = YtDlpException.withoutMediaIds(
      error.toString().toLowerCase(),
    );
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
        text.contains('this video is private') ||
        text.contains('geo-restricted') ||
        text.contains('your ip address is blocked from accessing this post') ||
        text.contains('status_self_see') ||
        text.contains('item_privacy_authorization') ||
        text.contains('item_privacy_auth') ||
        RegExp(r'\b10204\b').hasMatch(text) ||
        text.contains('comfortable for some audiences') ||
        text.contains('log in for access')) {
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

  /// The site refused for now (throttling, anti-bot, TikTok's error page):
  /// every job on that site should wait before its next request.
  static bool isSiteRefusal(Object error) =>
      error is TikTokRefusedException ||
      error is ExtractorProtectionException ||
      isRateLimitOrCaptchaError(error);

  static bool isNonRetryableError(Object error) {
    // A photo post never gains a video, but it is not deleted either: kept
    // out of [isPermanentDownloadError] so its row stays visible.
    return isNonRetryableProxyError(error) ||
        error is TikTokPhotoPostException ||
        isPermanentDownloadError(error);
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

  /// Detects if an error is due to an age verification requirement or +18 regional block.
  static bool isAgeVerificationFailure({
    required String? error,
    required String url,
  }) {
    if (error == null || error.isEmpty) return false;
    final lowerErr = error.toLowerCase();

    if (lowerErr.contains('age-restricted') ||
        lowerErr.contains('confirm your age') ||
        lowerErr.contains('age confirmation') ||
        lowerErr.contains('comfortable for some audiences')) {
      return true;
    }

    final lowerUrl = url.toLowerCase();
    final isAdultSite = lowerUrl.contains('xhamster') ||
        lowerUrl.contains('pornhub') ||
        lowerUrl.contains('xnxx') ||
        lowerUrl.contains('xvideos') ||
        lowerUrl.contains('spankbang') ||
        lowerUrl.contains('redtube') ||
        lowerUrl.contains('youporn');

    if (isAdultSite &&
        (lowerErr.contains('aucun format') ||
            lowerErr.contains('no video formats found') ||
            lowerErr.contains('no formats found') ||
            lowerErr.contains('cookies/navigateur') ||
            lowerErr.contains('cookies de session requis') ||
            lowerErr.contains('login required') ||
            lowerErr.contains('requires authentication'))) {
      return true;
    }

    return false;
  }
}

