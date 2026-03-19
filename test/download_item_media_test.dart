import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/domain/utils/download_item_media.dart';

void main() {
  group('DownloadItemMedia.detect', () {
    test('detects video files', () {
      final item = DownloadItem(
        id: '1',
        request: const DownloadRequest(url: 'https://example.com/video'),
        status: DownloadStatus.completed,
        filePath: r'C:\Downloads\clip.mp4',
      );

      expect(DownloadItemMedia.detect(item), DownloadMediaType.video);
    });

    test('detects audio-only requests without a file path', () {
      final item = DownloadItem(
        id: '2',
        request: const DownloadRequest(
          url: 'https://example.com/audio',
          audioOnly: true,
        ),
        status: DownloadStatus.downloading,
      );

      expect(DownloadItemMedia.detect(item), DownloadMediaType.audio);
    });

    test('treats image files as unsupported content', () {
      final item = DownloadItem(
        id: '3',
        request: const DownloadRequest(url: 'https://example.com/image'),
        status: DownloadStatus.completed,
        filePath: r'C:\Downloads\image.jpg',
      );

      expect(DownloadItemMedia.detect(item), DownloadMediaType.unknown);
    });

    test('treats gallery directory entries as unsupported content', () {
      final item = DownloadItem(
        id: '4',
        request: const DownloadRequest(url: 'https://example.com/gallery'),
        status: DownloadStatus.completed,
        filePath: r'C:\Downloads\Gallery Folder',
        thumbnailUrl: r'C:\Downloads\Gallery Folder\cover.jpg',
      );

      expect(DownloadItemMedia.detect(item), DownloadMediaType.unknown);
    });
  });
}
