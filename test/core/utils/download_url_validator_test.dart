import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/utils/download_url_validator.dart';

void main() {
  group('DownloadUrlValidator.isValidHttpUrl', () {
    test('accepts http and https URLs with a host', () {
      expect(
        DownloadUrlValidator.isValidHttpUrl('https://youtube.com/watch?v=1'),
        isTrue,
      );
      expect(
        DownloadUrlValidator.isValidHttpUrl('http://example.com/a'),
        isTrue,
      );
    });

    test('rejects empty, missing host, and non-http schemes', () {
      expect(DownloadUrlValidator.isValidHttpUrl(''), isFalse);
      expect(DownloadUrlValidator.isValidHttpUrl('   '), isFalse);
      expect(DownloadUrlValidator.isValidHttpUrl('not a url'), isFalse);
      expect(
        DownloadUrlValidator.isValidHttpUrl('ftp://files.example'),
        isFalse,
      );
      expect(DownloadUrlValidator.isValidHttpUrl('https://'), isFalse);
    });
  });
}
