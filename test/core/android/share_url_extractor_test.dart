import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/android/share_url_extractor.dart';

void main() {
  group('ShareUrlExtractor', () {
    test('accepts a bare tweet URL', () {
      expect(
        ShareUrlExtractor.extract(
          'https://x.com/user/status/1234567890123456789',
        ),
        'https://x.com/user/status/1234567890123456789',
      );
    });

    test('extracts a tweet URL from share text', () {
      expect(
        ShareUrlExtractor.extract(
          'Check this https://twitter.com/foo/status/1234567890123456789 wow',
        ),
        'https://twitter.com/foo/status/1234567890123456789',
      );
    });

    test('strips trailing punctuation', () {
      expect(
        ShareUrlExtractor.extract('https://x.com/user/status/1.'),
        'https://x.com/user/status/1',
      );
    });

    test('returns null for empty or non-http text', () {
      expect(ShareUrlExtractor.extract(''), isNull);
      expect(ShareUrlExtractor.extract('hello world'), isNull);
      expect(ShareUrlExtractor.extract('ftp://example.com/a'), isNull);
    });

    test('prefers an X permalink over another URL in the same text', () {
      expect(
        ShareUrlExtractor.extract(
          'https://example.com/v https://x.com/a/status/99',
        ),
        'https://x.com/a/status/99',
      );
    });
  });
}
