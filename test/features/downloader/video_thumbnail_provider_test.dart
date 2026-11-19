import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/video_thumbnail_provider.dart';

void main() {
  test('the cache name is stable per video and distinct between videos', () {
    final a = thumbnailCachePath('/cache', '/Download/MD/a [1].mp4');
    expect(thumbnailCachePath('/cache', '/Download/MD/a [1].mp4'), a);
    expect(thumbnailCachePath('/cache', '/Download/MD/b [2].mp4'), isNot(a));
    expect(a.replaceAll(r'\', '/'), startsWith('/cache/video_thumbs/'));
    expect(a, endsWith('.jpg'));
  });
}
