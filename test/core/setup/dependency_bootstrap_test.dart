import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/setup/dependency_catalog.dart';
import 'package:modern_downloader/core/setup/zip_binary_extractor.dart';

void main() {
  group('DependencyCatalog', () {
    test('covers yt-dlp, ffmpeg/ffprobe, and aria2c', () {
      final ids = DependencyCatalog.windowsRequired.map((pkg) => pkg.id);
      expect(ids, containsAll(['yt-dlp', 'ffmpeg', 'aria2c']));
      expect(
        DependencyCatalog.allExecutableNames(),
        containsAll(['yt-dlp.exe', 'ffmpeg.exe', 'ffprobe.exe', 'aria2c.exe']),
      );
      expect(
        DependencyCatalog.allSetupExecutableNames(),
        contains('gobird.exe'),
      );
      expect(DependencyCatalog.isOptionalExecutable('gobird.exe'), isTrue);
    });
  });

  group('ZipBinaryExtractor', () {
    test('extracts executables from nested zip folders', () {
      final archive = Archive()
        ..addFile(ArchiveFile('ffmpeg-release/bin/ffmpeg.exe', 3, [1, 2, 3]))
        ..addFile(ArchiveFile('ffmpeg-release/bin/ffprobe.exe', 2, [4, 5]))
        ..addFile(
          ArchiveFile('ffmpeg-release/doc/readme.txt', 4, [9, 9, 9, 9]),
        );
      final zipBytes = ZipEncoder().encode(archive);

      final found = ZipBinaryExtractor.extractExecutables(zipBytes, {
        'ffmpeg.exe',
        'ffprobe.exe',
      });

      expect(found['ffmpeg.exe'], [1, 2, 3]);
      expect(found['ffprobe.exe'], [4, 5]);
      expect(found.containsKey('readme.txt'), isFalse);
    });

    test('is case-insensitive on file names', () {
      final archive = Archive()
        ..addFile(ArchiveFile('Aria2/ARIA2C.EXE', 1, [7]));
      final zipBytes = ZipEncoder().encode(archive);

      final found = ZipBinaryExtractor.extractExecutables(zipBytes, {
        'aria2c.exe',
      });

      expect(found['aria2c.exe'], [7]);
    });
  });
}
