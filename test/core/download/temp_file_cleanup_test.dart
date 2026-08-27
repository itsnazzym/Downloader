import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/temp_file_cleanup.dart';

void main() {
  group('TempFileCleanup.isFragmentOrTemp', () {
    test('matches numeric yt-dlp fragment suffixes', () {
      expect(TempFileCleanup.isFragmentOrTemp('video.f134'), isTrue);
      expect(TempFileCleanup.isFragmentOrTemp('video.f134.mp4'), isFalse);
    });

    test('matches known temp extensions', () {
      expect(TempFileCleanup.isFragmentOrTemp('video.part'), isTrue);
      expect(TempFileCleanup.isFragmentOrTemp('video.ytdl'), isTrue);
      expect(TempFileCleanup.isFragmentOrTemp('video.aria2'), isTrue);
      expect(TempFileCleanup.isFragmentOrTemp('video.temp'), isTrue);
    });

    test('does not match completed files', () {
      expect(TempFileCleanup.isFragmentOrTemp('video.mp4'), isFalse);
    });
  });
}
