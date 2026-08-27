import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/extraction_placeholders.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

void main() {
  group('ExtractionPlaceholders', () {
    test('treats platform stubs and empty titles as generic', () {
      expect(ExtractionPlaceholders.isGenericTitle(null), isTrue);
      expect(ExtractionPlaceholders.isGenericTitle(''), isTrue);
      expect(ExtractionPlaceholders.isGenericTitle('Twitter Video'), isTrue);
      expect(ExtractionPlaceholders.isGenericTitle('YouTube Video'), isTrue);
      expect(ExtractionPlaceholders.isGenericTitle('Video 12'), isTrue);
      expect(ExtractionPlaceholders.isGenericTitle('hijab'), isFalse);
    });

    test('shows a spinner only while extracting without a thumbnail', () {
      expect(
        ExtractionPlaceholders.showThumbnailSpinner(
          status: DownloadStatus.extracting,
          thumbnailUrl: null,
        ),
        isTrue,
      );
      expect(
        ExtractionPlaceholders.showThumbnailSpinner(
          status: DownloadStatus.extracting,
          thumbnailUrl: 'https://img.example/t.jpg',
        ),
        isFalse,
      );
      expect(
        ExtractionPlaceholders.showThumbnailSpinner(
          status: DownloadStatus.completed,
          thumbnailUrl: null,
        ),
        isFalse,
      );
    });

    test('shows extracting size only when total size is still empty', () {
      expect(
        ExtractionPlaceholders.showExtractingSize(
          status: DownloadStatus.extracting,
          totalSize: '',
        ),
        isTrue,
      );
      expect(
        ExtractionPlaceholders.showExtractingSize(
          status: DownloadStatus.extracting,
          totalSize: '12.0MiB',
        ),
        isFalse,
      );
    });
  });
}
