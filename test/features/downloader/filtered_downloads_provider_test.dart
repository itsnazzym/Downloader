import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';

DownloadItem _item(String id, String totalSize) {
  return DownloadItem(
    id: id,
    request: const DownloadRequest(url: 'https://www.youtube.com/watch?v=a'),
    totalSize: totalSize,
  );
}

void main() {
  group('compareDownloadSize', () {
    test('orders by parsed bytes, not lexicographic strings', () {
      final small = _item('a', '10 MB');
      final large = _item('b', '2 GB');

      expect(compareDownloadSize(small, large), lessThan(0));
      expect(compareDownloadSize(large, small), greaterThan(0));
      expect(compareDownloadSize(small, small), 0);
    });

    test('treats empty or unknown sizes as zero bytes', () {
      final unknown = _item('u', '');
      final known = _item('k', '1 KB');

      expect(compareDownloadSize(unknown, known), lessThan(0));
    });

    test('sorts mixed units correctly for sizeDesc', () {
      final items = [
        _item('mb', '10 MB'),
        _item('gb', '2 GB'),
        _item('kb', '500 KB'),
      ]..sort(compareDownloadSize);

      expect(items.map((e) => e.id).toList(), ['kb', 'mb', 'gb']);

      items.sort((a, b) => compareDownloadSize(b, a));
      expect(items.map((e) => e.id).toList(), ['gb', 'mb', 'kb']);
    });
  });
}
