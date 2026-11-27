import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/features/downloader/domain/exceptions/yt_dlp_exception.dart';

void main() {
  group('YtDlpException.fromLog', () {
    test('maps suspended tweets', () {
      final error = YtDlpException.fromLog(
        'ERROR: [twitter] 2091798624661602420: Suspended',
      );
      expect(error, isA<SuspendedContentException>());
    });

    test('maps missing video', () {
      final error = YtDlpException.fromLog(
        'ERROR: [twitter] 2093058718350893415: No video could be found in this tweet',
      );
      expect(error, isA<NoMediaFoundException>());
    });

    test('maps unsupported URLs', () {
      final error = YtDlpException.fromLog(
        'ERROR: Unsupported URL: https://discord.com/invite/JoinForbidden',
      );
      expect(error, isA<UnsupportedUrlException>());
    });

    test('returns null for unknown logs', () {
      expect(YtDlpException.fromLog('WARNING: fragment retry'), isNull);
    });

    test('ignores copyright in a title without ERROR lines', () {
      expect(
        YtDlpException.fromLog(
          '[download] Destination: Essay on copyright law.mp4\n'
          '[info] Writing video metadata',
        ),
        isNull,
      );
    });

    test('ignores YouTube bot-check wording without age restriction', () {
      expect(
        YtDlpException.fromLog(
          'ERROR: Sign in to confirm you’re not a bot. '
          'Use --cookies-from-browser.',
        ),
        isNull,
      );
    });

    test('maps copyright only on ERROR lines', () {
      expect(
        YtDlpException.fromLog(
          'ERROR: This video contains copyrighted content',
        ),
        isA<CopyrightException>(),
      );
    });
  });

  group('TikTok refusals', () {
    // The exact log of the 49 failed archive downloads (2026-11).
    const log =
        'WARNING: [TikTok] 7670635041910754573: Failed to parse JSON (caused '
        'by JSONDecodeError("Expecting value in \'\': line 1 column 1 (char '
        '0)")); trying with webpage\n'
        'ERROR: [TikTok] 7670635041910754573: Video not available, status '
        'code 10231; please report this issue on  https://github.com/yt-dlp/'
        'yt-dlp/issues?q= , filling out the appropriate issue template.';

    test('"Video not available, status code N" is a TikTok refusal', () {
      final error = YtDlpException.fromLog(log);
      expect(error, isA<TikTokRefusedException>());
      expect(error!.message, contains('10231'));
      expect(
        YtDlpException.fromLog(
          'ERROR: [TikTok] 7589106706517478678: Video not available, status '
          'code 0',
        ),
        isA<TikTokRefusedException>(),
      );
    });

    test('the Android impersonation warning never names the error', () {
      const warning =
          'WARNING: [TikTok] The extractor is attempting impersonation, but '
          'no impersonate target is available. If you encounter errors, then '
          'see https://github.com/yt-dlp/yt-dlp#impersonation';
      expect(YtDlpException.fromLog(warning), isNull);
      expect(
        YtDlpException.fromLog(
          '$warning\nERROR: Postprocessing: Error opening output files: '
          'Invalid argument',
        ),
        isNot(isA<NoVideoFormatsException>()),
      );
      expect(
        YtDlpException.fromLog(
          '$warning\nERROR: [TikTok] 7589106706517478678: Video not '
          'available, status code 0',
        ),
        isA<TikTokRefusedException>(),
      );
    });

    test('a TikTok post without video formats is a photo post', () {
      final error = YtDlpException.fromLog(
        'ERROR: [TikTok] 7235285015339257089: No video formats found!; '
        'please report this issue',
      );
      expect(error, isA<TikTokPhotoPostException>());
      expect(
        YtDlpException.fromLog('ERROR: [generic] x: No video formats found!'),
        isA<NoVideoFormatsException>(),
      );
    });

    test('a video ID that contains 10204 is not a private post', () {
      final error = YtDlpException.fromLog(
        'ERROR: [TikTok] 7310204998877665544: Unable to download webpage: '
        'HTTP Error 500',
      );
      expect(error, isNot(isA<PrivateVideoException>()));
    });
  });
}
