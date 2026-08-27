import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/x_feed/x_media_identity.dart';

void main() {
  group('XMediaIdentity', () {
    test('matches X URLs when tracking parameter order differs', () {
      const first =
          'https://x.com/example/status/42?utm_source=feed&token=abc&ref=home';
      const second =
          'https://X.COM/example/status/42?token=abc&utm_campaign=spring';

      expect(XMediaIdentity.sameMedia(first, second), isTrue);
    });

    test('keeps quality and variant parameters distinct', () {
      const lowQuality = 'https://video.x.com/media/42?quality=low&variant=mp4';
      const highQuality =
          'https://video.x.com/media/42?quality=high&variant=mp4';

      expect(XMediaIdentity.sameMedia(lowQuality, highQuality), isFalse);
    });

    test('does not create identities for non-X URLs', () {
      const first = 'https://example.com/video?id=42&utm_source=feed';
      const second = 'https://example.com/video?id=42&utm_campaign=spring';

      expect(XMediaIdentity.mediaKey(first), isNull);
      expect(XMediaIdentity.mediaKey(second), isNull);
      expect(XMediaIdentity.sameMedia(first, second), isFalse);
    });
  });
}
