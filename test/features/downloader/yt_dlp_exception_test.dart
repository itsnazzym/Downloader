import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/domain/exceptions/yt_dlp_exception.dart';

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
  });
}
