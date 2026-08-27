import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/yt_dlp_progress_parser.dart';

void main() {
  group('YtDlpProgressParser', () {
    test('after_move path alone succeeds when file exists with size > 0', () {
      late Directory dir;
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      dir = Directory.systemTemp.createTempSync('md_parser_after_move_');
      final filePath = '${dir.path}${Platform.pathSeparator}foo [id].mp4';
      File(filePath).writeAsBytesSync([1, 2, 3, 4]);

      final parser = YtDlpProgressParser(
        baseFolder: dir.path,
        preferredExt: '.mp4',
      );

      parser.onLine(filePath);

      expect(parser.hasProgress, isFalse);
      expect(parser.afterMovePath, filePath);
      expect(parser.currentFilePath, filePath);
      expect(
        parser.isSuccessfulExit(outputFolder: dir.path, videoId: 'id'),
        isTrue,
      );
    });

    test('stderr percent line sets hasProgress', () {
      final parser = YtDlpProgressParser(
        baseFolder: r'C:\Videos',
        preferredExt: '.mp4',
      );

      final updates = parser.onLine(
        '[download]  12.3% of 10.00MiB at 1.00MiB/s ETA 00:08',
      );

      expect(parser.hasProgress, isTrue);
      expect(updates, isNotEmpty);
      expect(updates.first.progress, closeTo(0.123, 0.0001));
      expect(parser.isSuccessfulExit(), isTrue);
    });

    test('already downloaded marks success and duplicate', () {
      final parser = YtDlpProgressParser(
        baseFolder: r'C:\Videos',
        preferredExt: '.mp4',
      );

      final updates = parser.onLine(
        '[download] C:\\Videos\\clip.mp4 has already been downloaded',
      );

      expect(parser.hasProgress, isTrue);
      expect(updates, isNotEmpty);
      expect(updates.first.isDuplicate, isTrue);
      expect(updates.first.progress, 1.0);
      expect(parser.isSuccessfulExit(), isTrue);
    });

    test('after_move with missing or empty file is not successful', () {
      final parser = YtDlpProgressParser(
        baseFolder: r'C:\Videos',
        preferredExt: '.mp4',
        fileExistsSync: (_) => false,
        fileLengthSync: (_) => 0,
      );

      parser.onLine(r'C:\Videos\missing [id].mp4');

      expect(parser.afterMovePath, r'C:\Videos\missing [id].mp4');
      expect(parser.hasProgress, isFalse);
      expect(parser.isSuccessfulExit(videoId: 'id'), isFalse);
    });
  });
}
