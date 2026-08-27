import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/data/datasources/startup_cleanup_service.dart';

void main() {
  group('StartupCleanupService.shouldDelete', () {
    test('keeps yt-dlp resume artifacts', () {
      expect(
        StartupCleanupService.shouldDelete(r'C:\dl\video.mp4.part'),
        isFalse,
      );
      expect(
        StartupCleanupService.shouldDelete(r'C:\dl\video.mp4.ytdl'),
        isFalse,
      );
      expect(
        StartupCleanupService.shouldDelete(r'C:\dl\video.mp4.aria2'),
        isFalse,
      );
    });

    test('still removes leftover .temp files', () {
      expect(StartupCleanupService.shouldDelete(r'C:\dl\scratch.temp'), isTrue);
    });

    test('does not delete completed media', () {
      expect(StartupCleanupService.shouldDelete(r'C:\dl\video.mp4'), isFalse);
    });
  });
}
