import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/archive/data/services/tiktok_video_cache_service.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TikTokVideoCacheService service;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tiktok_cache_test_');
    service = TikTokVideoCacheService();
  });

  tearDown(() async {
    service.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('getVideoState returns idle by default', () {
    final state = service.getVideoState('123456');
    expect(state.status, equals(TikTokVideoStatus.idle));
    expect(state.videoId, equals('123456'));
    expect(state.localPath, isNull);
    expect(state.isReady, isFalse);
  });

  test('getCachedVideoPath returns valid path when file exists and is valid size', () async {
    final cacheDir = await service.getCacheDirectory();
    final testFile = File(p.join(cacheDir.path, 'test_vid_99.mp4'));
    // Write > 1000 bytes
    await testFile.writeAsBytes(List.filled(2048, 42));

    final cachedPath = await service.getCachedVideoPath('test_vid_99');
    expect(cachedPath, isNotNull);
    expect(cachedPath, equals(testFile.path));

    final state = service.getVideoState('test_vid_99');
    expect(state.isReady, isTrue);
    expect(state.localPath, equals(testFile.path));

    // Cleanup
    if (await testFile.exists()) await testFile.delete();
  });

  test('getCachedVideoPath detects unavailable marker file', () async {
    final cacheDir = await service.getCacheDirectory();
    final unavailFile = File(p.join(cacheDir.path, 'deleted_vid_1.unavailable'));
    await unavailFile.writeAsString('deleted');

    final cachedPath = await service.getCachedVideoPath('deleted_vid_1');
    expect(cachedPath, isNull);

    final state = service.getVideoState('deleted_vid_1');
    expect(state.isUnavailable, isTrue);

    // Cleanup
    if (await unavailFile.exists()) await unavailFile.delete();
  });

  test('preloadAround prioritizes active and lookahead items without error', () {
    final items = List.generate(
      10,
      (i) => TikTokArchiveItem(
        id: 'vid_$i',
        url: 'https://www.tiktok.com/@/video/vid_$i',
        date: DateTime.now(),
        isFavorite: true,
        isLiked: false,
      ),
    );

    // Should schedule vid_2 as priority 0, and vid_3, vid_4, vid_5 as lookahead
    service.preloadAround(items, 2, lookAhead: 3);

    final state2 = service.getVideoState('vid_2');
    expect(state2.videoId, equals('vid_2'));
  });

  test('unavailableIds includes detected unavailable videos', () async {
    final cacheDir = await service.getCacheDirectory();
    final unavailFile = File(p.join(cacheDir.path, 'deleted_99.unavailable'));
    await unavailFile.writeAsString('deleted');

    await service.getCachedVideoPath('deleted_99');
    expect(service.unavailableIds.contains('deleted_99'), isTrue);

    // Subsequent call to getVideoState immediately reflects unavailable
    final state = service.getVideoState('deleted_99');
    expect(state.isUnavailable, isTrue);

    // Cleanup
    if (await unavailFile.exists()) await unavailFile.delete();
  });
}
