import 'package:modern_downloader/core/download/extension_download_batcher.dart';
import 'package:modern_downloader/core/download/x_download_url.dart';
import 'package:modern_downloader/core/logger/logger_service.dart';
import 'package:modern_downloader/core/utils/download_url_validator.dart';

/// Result of parsing an extension DOWNLOAD payload.
class LocalServerDownloadIntakeResult {
  const LocalServerDownloadIntakeResult.ok(this.ingest) : errorCode = null;

  const LocalServerDownloadIntakeResult.error(this.errorCode) : ingest = null;

  final String? errorCode;
  final ExtensionDownloadIngest? ingest;

  bool get isOk => errorCode == null && ingest != null;
}

/// Pure URL/payload validation for extension DOWNLOAD messages.
class LocalServerDownloadIntake {
  LocalServerDownloadIntake._();

  static LocalServerDownloadIntakeResult parse(Map<String, dynamic> data) {
    final url = data['url'] as String?;
    final cookies = data['cookies'] as String?;
    final userAgent = data['userAgent'] as String?;
    final isAudioOnly = data['isAudioOnly'] as bool?;
    final isPlaylist = data['isPlaylist'] as bool?;
    final cookieBrowser = data['cookieBrowser'] as String?;
    final preferredQuality = data['preferredQuality'] as String?;

    if (url == null || url.isEmpty) {
      return const LocalServerDownloadIntakeResult.error('invalid_url');
    }

    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      LoggerService.w('Rejected non-http(s) download URL from extension');
      return const LocalServerDownloadIntakeResult.error('invalid_url');
    }

    if (DownloadUrlValidator.isNonMediaPageUrl(url)) {
      LoggerService.w('Rejected non-media download URL from extension: $url');
      return const LocalServerDownloadIntakeResult.error('unsupported_url');
    }

    late final String downloadUrl;
    try {
      final referrerRaw = data['referrer'];
      final referrer = referrerRaw is String ? referrerRaw : null;
      final resolved = XDownloadUrl.resolveForDownload(url, referrer);
      if (resolved == null) {
        LoggerService.w(
          'Rejected X CDN download without a tweet permalink: $url',
        );
        return const LocalServerDownloadIntakeResult.error('need_tweet_url');
      }
      final canonicalUri = Uri.tryParse(resolved);
      if (canonicalUri == null ||
          (canonicalUri.scheme != 'http' && canonicalUri.scheme != 'https') ||
          canonicalUri.host.isEmpty) {
        LoggerService.w('Resolved download URL was not http(s)');
        return const LocalServerDownloadIntakeResult.error('invalid_url');
      }
      downloadUrl = resolved;
    } catch (e) {
      LoggerService.w('Failed to resolve download URL: $e');
      return const LocalServerDownloadIntakeResult.error('invalid_url');
    }

    LoggerService.i('📥 Received download request: $downloadUrl');
    if (cookies != null) {
      LoggerService.debug('With Cookies: ${cookies.length} chars');
    }
    if (isPlaylist == true) {
      LoggerService.i('Playlist Mode Detected');
    }
    if (userAgent != null) {
      LoggerService.debug('With UA length: ${userAgent.length}');
    }

    return LocalServerDownloadIntakeResult.ok(
      ExtensionDownloadIngest(
        url: downloadUrl,
        cookies: cookies,
        userAgent: userAgent,
        isAudioOnly: isAudioOnly ?? false,
        isPlaylist: isPlaylist ?? false,
        cookieBrowser: cookieBrowser,
        preferredQuality: preferredQuality,
      ),
    );
  }
}
