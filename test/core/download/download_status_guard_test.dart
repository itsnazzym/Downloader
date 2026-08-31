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

  group('DownloadStatusGuard.isPermanentDownloadError', () {
    test('detects suspended tweets', () {
      const sample =
          'ERROR: [twitter] 2091798624661602420: Suspended';
      expect(DownloadStatusGuard.isPermanentDownloadError(sample), isTrue);
      expect(
        DownloadStatusGuard.userFacingDownloadErrorMessage(sample),
        contains('suspendu'),
      );
    });

    test('detects tweets without video', () {
      const sample =
          'ERROR: [twitter] 2093058718350893415: No video could be found in this tweet';
      expect(DownloadStatusGuard.isPermanentDownloadError(sample), isTrue);
      expect(
        DownloadStatusGuard.userFacingDownloadErrorMessage(sample),
        contains('Aucune vidéo'),
      );
    });

    test('detects unsupported URLs', () {
      const sample =
          'ERROR: Unsupported URL: https://discord.com/invite/JoinForbidden';
      expect(DownloadStatusGuard.isPermanentDownloadError(sample), isTrue);
      expect(
        DownloadStatusGuard.userFacingDownloadErrorMessage(sample),
        contains('non prise en charge'),
      );
    });

    test('does not retry permanent errors', () {
      const sample = 'ERROR: [twitter] 123: Suspended';
      expect(DownloadStatusGuard.isNonRetryableError(sample), isTrue);
    });
  });
}
