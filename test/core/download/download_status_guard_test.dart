import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/download_status_guard.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/domain/exceptions/yt_dlp_exception.dart';

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
      const sample = 'ERROR: [twitter] 2091798624661602420: Suspended';
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

    test('detects unsupported invite URLs wrapped in yt-dlp fallback logs', () {
      const sample =
          'yt-dlp exited with code 1. Error: WARNING: [generic] Falling back on generic information extractor\nERROR: Unsupported URL: https://discord.com/invite/JoinForbidden';
      expect(DownloadStatusGuard.isPermanentDownloadError(sample), isTrue);
      expect(DownloadStatusGuard.isNonRetryableError(sample), isTrue);
    });

    test('does not retry permanent errors', () {
      const sample = 'ERROR: [twitter] 123: Suspended';
      expect(DownloadStatusGuard.isNonRetryableError(sample), isTrue);
      expect(
        DownloadStatusGuard.isPermanentDownloadError(
          SuspendedContentException(log: sample),
        ),
        isTrue,
      );
    });

    test('does not treat transient extractor errors as permanent', () {
      expect(
        DownloadStatusGuard.isPermanentDownloadError(
          'HTTP Error 429: Too Many Requests',
        ),
        isFalse,
      );
      expect(
        DownloadStatusGuard.isPermanentDownloadError(
          'connection suspended by peer',
        ),
        isFalse,
      );
    });
  });

  group('DownloadStatusGuard.isAgeVerificationFailure', () {
    test('detects explicit age restricted error keywords', () {
      expect(
        DownloadStatusGuard.isAgeVerificationFailure(
          error: 'Video is age-restricted and requires login',
          url: 'https://youtube.com/watch?v=123',
        ),
        isTrue,
      );
      expect(
        DownloadStatusGuard.isAgeVerificationFailure(
          error: 'Sign in to confirm your age',
          url: 'https://youtube.com/watch?v=456',
        ),
        isTrue,
      );
    });

    test('detects no video format errors on adult sites like xHamster', () {
      expect(
        DownloadStatusGuard.isAgeVerificationFailure(
          error:
              'Aucun format vidéo accessible. Le site a peut-être changé sa structure ou bloque l\'accès sans cookies/navigateur.',
          url: 'https://fr.xhamster.com/videos/test-video-12345',
        ),
        isTrue,
      );
      expect(
        DownloadStatusGuard.isAgeVerificationFailure(
          error: 'ERROR: [xhamster] 12345: No video formats found!',
          url: 'https://xhamster.com/videos/sample',
        ),
        isTrue,
      );
      expect(
        DownloadStatusGuard.isAgeVerificationFailure(
          error: 'Connexion ou cookies de session requis pour accéder à cette vidéo.',
          url: 'https://www.pornhub.com/view_video.php?viewkey=ph123',
        ),
        isTrue,
      );
    });

    test('does not flag normal errors or non-adult websites', () {
      expect(
        DownloadStatusGuard.isAgeVerificationFailure(
          error: 'HTTP Error 404: Not Found',
          url: 'https://fr.xhamster.com/videos/missing',
        ),
        isFalse,
      );
      expect(
        DownloadStatusGuard.isAgeVerificationFailure(
          error: 'Aucun format vidéo accessible.',
          url: 'https://youtube.com/watch?v=regular',
        ),
        isFalse,
      );
      expect(
        DownloadStatusGuard.isAgeVerificationFailure(
          error: null,
          url: 'https://xhamster.com/videos/sample',
        ),
        isFalse,
      );
    });
  });

  group('TikTok refusals', () {
    test('are retried, not treated as deleted', () {
      final error = TikTokRefusedException(status: 10231);
      expect(DownloadStatusGuard.isPermanentDownloadError(error), isFalse);
      expect(DownloadStatusGuard.isSiteRefusal(error), isTrue);
    });

    test('photo posts stop retrying but are not deleted as unavailable', () {
      final error = TikTokPhotoPostException();
      expect(DownloadStatusGuard.isNonRetryableError(error), isTrue);
      expect(DownloadStatusGuard.isPermanentDownloadError(error), isFalse);
      expect(
        DownloadStatusGuard.isPermanentDownloadError(error.message),
        isFalse,
      );
    });

    test('rate limits are site refusals, ordinary failures are not', () {
      expect(DownloadStatusGuard.isSiteRefusal(RateLimitException()), isTrue);
      expect(
        DownloadStatusGuard.isSiteRefusal(NetworkException()),
        isFalse,
      );
    });

    test('an ID containing 10204 does not mark the post private', () {
      expect(
        DownloadStatusGuard.isPermanentDownloadError(
          Exception(
            'ERROR: [TikTok] 7310204998877665544: HTTP Error 500',
          ),
        ),
        isFalse,
      );
      expect(
        DownloadStatusGuard.isPermanentDownloadError(
          Exception('TikTok status code 10204'),
        ),
        isTrue,
      );
    });
  });
}
