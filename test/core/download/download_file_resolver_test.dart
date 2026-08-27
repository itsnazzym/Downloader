import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/download_file_resolver.dart';

void main() {
  group('DownloadFileResolver.normalizePath', () {
    test('trims and strips quotes', () {
      expect(
        DownloadFileResolver.normalizePath('  "C:\\Videos\\a.mp4"  '),
        'C:\\Videos\\a.mp4',
      );
    });
  });

  group('DownloadFileResolver.isFragmentPath', () {
    test('detects .f401.mp4 fragments', () {
      expect(
        DownloadFileResolver.isFragmentPath(r'C:\dl\video.f401.mp4'),
        isTrue,
      );
      expect(DownloadFileResolver.isFragmentPath(r'C:\dl\video.mp4'), isFalse);
    });
  });

  group('DownloadFileResolver.extractBracketId', () {
    test('extracts id from filename', () {
      expect(
        DownloadFileResolver.extractBracketId(
          r'C:\dl\title [209191506225657].mp4',
        ),
        '209191506225657',
      );
    });
  });

  group('DownloadFileResolver.resolve', () {
    test('returns existing non-fragment candidate', () {
      final resolved = DownloadFileResolver.resolve(
        candidatePath: r'C:\dl\final.mp4',
        preferredExtension: '.mp4',
        existsSync: (p) => p == r'C:\dl\final.mp4',
      );
      expect(resolved, r'C:\dl\final.mp4');
    });

    test('swaps fragment .f401.mp4 to .mp4 when fragment missing', () {
      final resolved = DownloadFileResolver.resolve(
        candidatePath: r'C:\dl\clip.f401.mp4',
        preferredExtension: '.mp4',
        existsSync: (p) => p == r'C:\dl\clip.mp4',
      );
      expect(resolved, r'C:\dl\clip.mp4');
    });

    test('swaps .webm candidate to preferred .mp4', () {
      final resolved = DownloadFileResolver.resolve(
        candidatePath: r'C:\dl\clip.webm',
        preferredExtension: '.mp4',
        existsSync: (p) => p == r'C:\dl\clip.mp4',
      );
      expect(resolved, r'C:\dl\clip.mp4');
    });

    test('finds file by video id in directory', () {
      late Directory dir;
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      dir = Directory.systemTemp.createTempSync('md_resolver_');
      final file = File(
        '${dir.path}${Platform.pathSeparator}tweet [abc123].mp4',
      );
      file.writeAsBytesSync([0, 0, 0]);

      final resolved = DownloadFileResolver.resolve(
        candidatePath: '${dir.path}${Platform.pathSeparator}missing.f401.mp4',
        outputFolder: dir.path,
        videoId: 'abc123',
        preferredExtension: '.mp4',
      );
      expect(resolved, file.path);
    });
  });

  group('DownloadFileResolver.formattedFileSize', () {
    test('formats existing file length', () {
      late Directory dir;
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      dir = Directory.systemTemp.createTempSync('md_size_');
      final file = File('${dir.path}${Platform.pathSeparator}clip.mp4');
      file.writeAsBytesSync([1, 2, 3, 4, 5]);

      expect(DownloadFileResolver.formattedFileSize(file.path), '5.0 B');
    });

    test('returns null for missing or empty files', () {
      expect(DownloadFileResolver.formattedFileSize(null), isNull);
      expect(DownloadFileResolver.formattedFileSize(''), isNull);
      expect(
        DownloadFileResolver.formattedFileSize(r'C:\missing\nope.mp4'),
        isNull,
      );
    });

    test('displaySize prefers stored size then disk then unknown', () {
      late Directory dir;
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      dir = Directory.systemTemp.createTempSync('md_display_');
      final file = File('${dir.path}${Platform.pathSeparator}clip.mp4');
      file.writeAsBytesSync([1, 2, 3, 4, 5]);

      expect(
        DownloadFileResolver.displaySize(
          storedTotalSize: '12.3 MB',
          filePath: file.path,
          unknownLabel: 'Unknown size',
        ),
        '12.3 MB',
      );
      expect(
        DownloadFileResolver.displaySize(
          storedTotalSize: '',
          filePath: file.path,
          unknownLabel: 'Unknown size',
        ),
        '5.0 B',
      );
      expect(
        DownloadFileResolver.displaySize(
          storedTotalSize: '',
          filePath: r'C:\missing\nope.mp4',
          unknownLabel: 'Unknown size',
        ),
        'Unknown size',
      );
    });
  });
}
