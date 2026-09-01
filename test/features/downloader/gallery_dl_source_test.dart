import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/data/sources/gallery_dl_source.dart';

void main() {
  group('GalleryDlSource.shouldUseFallback', () {
    test('matches known social and adult hosts', () {
      expect(
        GalleryDlSource.shouldUseFallback('https://x.com/a/status/1'),
        isTrue,
      );
      expect(
        GalleryDlSource.shouldUseFallback('https://www.instagram.com/p/abc'),
        isTrue,
      );
      expect(
        GalleryDlSource.shouldUseFallback('https://www.youtube.com/watch?v=1'),
        isFalse,
      );
    });
  });

  group('GalleryDlSource.fileNameFromPath', () {
    test('strips directories and extension', () {
      expect(
        GalleryDlSource.fileNameFromPath(r'C:\Videos\Twitter\clip [123].mp4'),
        'clip [123]',
      );
      expect(
        GalleryDlSource.fileNameFromPath('/home/user/out/video.webm'),
        'video',
      );
    });
  });
}
