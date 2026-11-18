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
    service = TikTokVideoCacheService(cacheDirectory: tempDir);
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

  test(
    'getCachedVideoPath returns valid path when file exists and is valid size',
    () async {
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
    },
  );

  test('getCachedVideoPath detects unavailable marker file', () async {
    final cacheDir = await service.getCacheDirectory();
    final unavailFile = File(
      p.join(cacheDir.path, 'deleted_vid_1.unavailable'),
    );
    await unavailFile.writeAsString(
      'confirmed_tiktok_unavailable_v1:404 Not Found',
    );

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
    await unavailFile.writeAsString(
      'confirmed_tiktok_unavailable_v1:404 Not Found',
    );

    await service.getCachedVideoPath('deleted_99');
    expect(service.unavailableIds.contains('deleted_99'), isTrue);

    // Subsequent call to getVideoState immediately reflects unavailable
    final state = service.getVideoState('deleted_99');
    expect(state.isUnavailable, isTrue);

    // Cleanup
    if (await unavailFile.exists()) await unavailFile.delete();
  });

  test(
    'legacy unavailable marker from a temporary failure is retried',
    () async {
      final cacheDir = await service.getCacheDirectory();
      final marker = File(
        p.join(cacheDir.path, 'temporary_failure.unavailable'),
      );
      await marker.writeAsString('unavailable');

      await service.getCachedVideoPath('temporary_failure');

      expect(service.unavailableIds.contains('temporary_failure'), isFalse);
      expect(await marker.exists(), isFalse);
    },
  );

  test(
    'old private-video markers are cleared instead of hiding the video',
    () async {
      final cacheDir = await service.getCacheDirectory();
      final marker = File(p.join(cacheDir.path, 'private_video.unavailable'));
      await marker.writeAsString(
        'confirmed_tiktok_unavailable_v1:This video is private',
      );

      await service.getCachedVideoPath('private_video');

      expect(service.unavailableIds.contains('private_video'), isFalse);
      expect(await marker.exists(), isFalse);
    },
  );

  test('network errors do not hide a video as deleted', () async {
    service.dispose();
    service = TikTokVideoCacheService(
      cacheDirectory: tempDir,
      outputDownloader: (id, url, onProgress) async {
        throw const SocketException('Connection timed out');
      },
    );
    final finalState = service.stateStream.firstWhere(
      (state) => state.status == TikTokVideoStatus.idle,
    );

    await service.requestVideo(
      '7444444444444444444',
      url: 'https://www.tiktokv.com/share/video/7444444444444444444/',
    );
    final state = await finalState.timeout(const Duration(seconds: 5));

    expect(service.unavailableIds, isEmpty);
    expect(state.errorMessage, contains('Connexion à TikTok impossible'));
  });

  test(
    'TikTok login and audience gates stay retryable and show guidance',
    () async {
      service.dispose();
      service = TikTokVideoCacheService(
        cacheDirectory: tempDir,
        outputDownloader: (id, url, onProgress) async {
          throw StateError(
            'yt-dlp exited with code 1. This post may not be comfortable '
            'for some audiences. Log in for access. Use --cookies-from-browser.',
          );
        },
      );
      final finalState = service.stateStream.firstWhere(
        (state) => state.status == TikTokVideoStatus.idle,
      );

      await service.requestVideo(
        '7444444444444444445',
        url: 'https://www.tiktokv.com/share/video/7444444444444444445/',
      );
      final state = await finalState.timeout(const Duration(seconds: 5));

      expect(state.errorMessage, contains('session connectée'));
      expect(state.errorMessage, contains('Chrome si tu utilises Chrome'));
      expect(service.unavailableIds, isEmpty);
    },
  );

  test('a confirmed 404 hides the video and persists its status', () async {
    service.dispose();
    service = TikTokVideoCacheService(
      cacheDirectory: tempDir,
      outputDownloader: (id, url, onProgress) async {
        throw StateError('TikTok returned HTTP 404: Not Found');
      },
    );
    final finalState = service.stateStream.firstWhere(
      (state) => state.status == TikTokVideoStatus.unavailable,
    );

    await service.requestVideo(
      '7555555555555555555',
      url: 'https://www.tiktokv.com/share/video/7555555555555555555/',
    );
    await finalState.timeout(const Duration(seconds: 5));

    expect(service.unavailableIds, contains('7555555555555555555'));
  });

  test('checkAvailability returns false and records video when video is already in unavailableIds', () async {
    final cacheDir = await service.getCacheDirectory();
    final marker = File(p.join(cacheDir.path, 'known_dead_123.unavailable'));
    await marker.writeAsString('confirmed_tiktok_unavailable_v1:404 Not Found');

    await service.getCachedVideoPath('known_dead_123');
    expect(service.isUnavailable('known_dead_123'), isTrue);

    final isAvailable = await service.checkAvailability('known_dead_123');
    expect(isAvailable, isFalse);
  });

  test('checkAvailability returns true when video is already downloaded locally', () async {
    final cacheDir = await service.getCacheDirectory();
    final videoFile = File(p.join(cacheDir.path, 'downloaded_vid_456.mp4'));
    await videoFile.writeAsBytes(List.filled(2048, 1));

    final isAvailable = await service.checkAvailability('downloaded_vid_456');
    expect(isAvailable, isTrue);

    if (await videoFile.exists()) await videoFile.delete();
  });
}

