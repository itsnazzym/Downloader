import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/data/datasources/download_queue_codec.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';

void main() {
  group('DownloadQueueCodec', () {
    test('round-trips download requests', () {
      const original = [
        DownloadRequest(url: 'https://example.com/a', audioOnly: true),
        DownloadRequest(url: 'https://example.com/b', preferredQuality: '720p'),
      ];

      final encoded = DownloadQueueCodec.encode(original);
      final decoded = DownloadQueueCodec.decode(encoded);

      expect(decoded, hasLength(2));
      expect(decoded[0].url, 'https://example.com/a');
      expect(decoded[0].audioOnly, isTrue);
      expect(decoded[1].preferredQuality, '720p');
    });

    test('returns an empty list for invalid json', () {
      expect(DownloadQueueCodec.decode('not-json'), isEmpty);
      expect(DownloadQueueCodec.decode('{}'), isEmpty);
    });
  });
}
