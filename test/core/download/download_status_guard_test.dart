import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/download_status_guard.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

void main() {
  group('DownloadStatusGuard.shouldRetryAfterError', () {
    test('does not retry canceled or paused downloads', () {
      expect(
        DownloadStatusGuard.shouldRetryAfterError(DownloadStatus.canceled),
        isFalse,
      );
      expect(
        DownloadStatusGuard.shouldRetryAfterError(DownloadStatus.paused),
        isFalse,
      );
    });

    test('retries other statuses', () {
      expect(
        DownloadStatusGuard.shouldRetryAfterError(DownloadStatus.downloading),
        isTrue,
      );
      expect(
        DownloadStatusGuard.shouldRetryAfterError(DownloadStatus.extracting),
        isTrue,
      );
      expect(DownloadStatusGuard.shouldRetryAfterError(null), isTrue);
    });
  });

  group('DownloadStatusGuard.isNonRetryableProxyError', () {
    test('detects WinError 10061 and SocksHTTPSConnection', () {
      const sample =
          "SocksHTTPSConnection(host='x.com', port=443): Failed to establish a new connection: [WinError 10061] Aucune connexion n'a pu être établie";
      expect(DownloadStatusGuard.isNonRetryableProxyError(sample), isTrue);
      expect(
        DownloadStatusGuard.userFacingProxyErrorMessage(sample),
        contains('127.0.0.1:9050'),
      );
    });

    test('does not treat normal yt-dlp errors as proxy failures', () {
      expect(
        DownloadStatusGuard.isNonRetryableProxyError('Video unavailable'),
        isFalse,
      );
    });
  });

  group('DownloadStatusGuard.isPermanentExtractorError', () {
    test('treats X suspended tweets as permanent', () {
      const sample =
          'yt-dlp exited with code 1. Error: ERROR: [twitter] 2091798624661602420: Suspended';
      expect(DownloadStatusGuard.isPermanentExtractorError(sample), isTrue);
      expect(DownloadStatusGuard.isNonRetryableError(sample), isTrue);
      expect(
        DownloadStatusGuard.userFacingErrorMessage(sample),
        contains('suspended'),
      );
    });

    test('treats tweets without video as permanent', () {
      const sample =
          'yt-dlp exited with code 1. Error: ERROR: [twitter] 2093058718350893415: No video could be found in this tweet';
      expect(DownloadStatusGuard.isPermanentExtractorError(sample), isTrue);
      expect(
        DownloadStatusGuard.userFacingErrorMessage(sample),
        contains('no downloadable video'),
      );
    });

    test('treats unsupported invite URLs as permanent', () {
      const sample =
          'yt-dlp exited with code 1. Error: WARNING: [generic] Falling back on generic information extractor\nERROR: Unsupported URL: https://discord.com/invite/JoinForbidden';
      expect(DownloadStatusGuard.isPermanentExtractorError(sample), isTrue);
      expect(
        DownloadStatusGuard.userFacingErrorMessage(sample),
        contains('not a supported video page'),
      );
    });

    test('does not treat transient extractor errors as permanent', () {
      expect(
        DownloadStatusGuard.isPermanentExtractorError(
          'HTTP Error 429: Too Many Requests',
        ),
        isFalse,
      );
      expect(
        DownloadStatusGuard.isPermanentExtractorError('Video unavailable'),
        isFalse,
      );
      expect(
        DownloadStatusGuard.isPermanentExtractorError(
          'connection suspended by peer',
        ),
        isFalse,
      );
    });
  });
}
