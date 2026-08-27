import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/media_source_resolver.dart';
import 'package:modern_downloader/core/services/library_stats_builder.dart';
import 'package:modern_downloader/core/utils/format_utils.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

void main() {
  group('MediaSourceResolver', () {
    test('maps real platform URLs', () {
      expect(
        MediaSourceResolver.fromUrlString('https://x.com/a/status/1'),
        'Twitter',
      );
      expect(
        MediaSourceResolver.fromUrlString('https://twitter.com/a/status/1'),
        'Twitter',
      );
      expect(
        MediaSourceResolver.fromUrlString('https://www.youtube.com/watch?v=a'),
        'YouTube',
      );
    });

    test('maps folder-derived .detected URLs but not local', () {
      expect(
        MediaSourceResolver.fromUrlString('https://twitter.detected/imported'),
        'Twitter',
      );
      expect(
        MediaSourceResolver.fromUrlString('https://local.detected/imported'),
        isNull,
      );
      expect(
        MediaSourceResolver.fromUrlString('https://unknown.invalid/imported'),
        isNull,
      );
    });

    test('reads known parent folder from file path', () {
      expect(
        MediaSourceResolver.fromFilePath(r'C:\Videos\vidvid\Twitter\clip.mp4'),
        'Twitter',
      );
      expect(
        MediaSourceResolver.fromFilePath(r'C:\Videos\vidvid\clip.mp4'),
        isNull,
      );
    });
  });

  group('FormatUtils.parseBytes', () {
    test('parses decimal and binary units', () {
      expect(FormatUtils.parseBytes('5.0 B'), 5);
      expect(FormatUtils.parseBytes('1.0 KB'), 1024);
      expect(FormatUtils.parseBytes('10.00MiB'), closeTo(10 * 1024 * 1024, 1));
    });
  });

  group('LibraryStatsBuilder', () {
    test('counts unique completed files, sizes, and omits Local', () {
      final now = DateTime(2026, 8, 26, 22);
      final hijab = r'C:\Videos\vidvid\Twitter\hijab.mp4';
      final zina = r'C:\Videos\vidvid\Twitter\zina.mp4';
      final items = [
        DownloadItem(
          id: '1',
          request: const DownloadRequest(url: 'https://x.com/a/status/1'),
          status: DownloadStatus.completed,
          filePath: hijab,
          totalSize: '1.0 MB',
        ),
        DownloadItem(
          id: 'dup',
          request: const DownloadRequest(url: 'https://x.com/a/status/1b'),
          status: DownloadStatus.completed,
          filePath: hijab,
          totalSize: '1.0 MB',
        ),
        DownloadItem(
          id: '2',
          request: const DownloadRequest(
            url: 'https://local.detected/imported',
          ),
          status: DownloadStatus.completed,
          filePath: zina,
          totalSize: '2.0 MB',
        ),
      ];

      final stats = LibraryStatsBuilder.fromItems(
        items,
        now: now,
        fileLengthBytes: (path) =>
            path.contains('zina') ? 2 * 1024 * 1024 : 1024 * 1024,
        fileModified: (_) => now,
      );

      expect(stats.totalDownloads, 2);
      expect(stats.downloadsToday, 2);
      expect(stats.totalBytesDownloaded, 3 * 1024 * 1024);
      expect(stats.downloadsBySource['Twitter'], 2);
      expect(stats.downloadsBySource.containsKey('Local'), isFalse);
    });
  });
}
