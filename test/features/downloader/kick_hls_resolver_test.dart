import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modern_downloader/features/downloader/data/sources/kick/kick_hls.dart';
import 'package:modern_downloader/features/downloader/data/sources/kick_source.dart';

void main() {
  group('KickPageRef.tryParse', () {
    test('parses VOD urls including /video/ alias and www host', () {
      final vod = KickPageRef.tryParse(
        'https://kick.com/mikeneko/videos/69d65b8d-89e2-4a5f-89b8-d2572d2f18cf',
      );
      expect(vod, isNotNull);
      expect(vod!.kind, KickContentKind.vod);
      expect(vod.channelSlug, 'mikeneko');
      expect(vod.contentId, '69d65b8d-89e2-4a5f-89b8-d2572d2f18cf');

      final alias = KickPageRef.tryParse(
        'https://www.kick.com/xqc/video/abcdef',
      );
      expect(alias!.kind, KickContentKind.vod);
      expect(alias.channelSlug, 'xqc');
      expect(alias.contentId, 'abcdef');
    });

    test('parses live channel and clip urls', () {
      final live = KickPageRef.tryParse('https://kick.com/xqc');
      expect(live!.kind, KickContentKind.live);
      expect(live.channelSlug, 'xqc');
      expect(live.contentId, isNull);

      final clip = KickPageRef.tryParse('https://kick.com/xqc/clips/clip123');
      expect(clip!.kind, KickContentKind.clip);
      expect(clip.contentId, 'clip123');
    });

    test('rejects non-kick and reserved slugs', () {
      expect(KickPageRef.tryParse('https://twitch.tv/xqc'), isNull);
      expect(KickPageRef.tryParse('https://kick.com/api/v1/video/x'), isNull);
      expect(KickPageRef.isKickHost('https://kick.com/xqc'), isTrue);
      expect(KickPageRef.isKickHost('https://web.kick.com/xqc'), isTrue);
    });
  });

  group('KickHlsCatalog', () {
    test('extracts ids from video_thumbnails and builds offset URLs', () {
      const thumb =
          'https://images.kick.com/video_thumbnails/chan123/rec456/thumb.webp';
      final pairs = KickHlsCatalog.idPairsFromThumbnail(thumb);
      expect(pairs, [
        const KickIdPair(channelId: 'chan123', videoId: 'rec456'),
      ]);

      final start = DateTime.utc(2025, 8, 1, 12, 0);
      final urls = KickHlsCatalog.buildMasterUrls(
        idPairs: pairs,
        startTimeUtc: start,
        offsetMinutes: 1,
      );

      expect(
        urls.first,
        'https://stream.kick.com/ivs/v1/196233775518/chan123/2025/8/1/12/0/rec456/media/hls/master.m3u8',
      );
      expect(urls.any((url) => url.contains('/2025/08/01/12/00/')), isTrue);
      expect(urls.any((url) => url.contains('/2025/8/1/12/1/')), isTrue);
      expect(urls.any((url) => url.contains('/2025/8/1/11/59/')), isTrue);
      expect(
        urls.every((url) => url.endsWith('/media/hls/master.m3u8')),
        isTrue,
      );
    });

    test('parses Kick timestamps as UTC', () {
      final parsed = KickHlsCatalog.parseKickTimestamp('2025-08-01 12:00:00');
      expect(parsed, DateTime.utc(2025, 8, 1, 12, 0));
      expect(
        KickHlsCatalog.parseKickTimestamp('2025-08-01T12:00:00Z'),
        DateTime.utc(2025, 8, 1, 12, 0),
      );
    });
  });

  group('KickHlsPlaylistParser', () {
    test('parses master playlist variants and relative paths', () {
      const master =
          'https://stream.kick.com/ivs/v1/196233775518/chan/2025/8/1/12/0/rec/media/hls/master.m3u8';
      const body = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=8000000,RESOLUTION=1920x1080,FRAME-RATE=60.000
1080p60/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=4000000,RESOLUTION=1280x720,FRAME-RATE=60
720p60/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=640x360
360p30/playlist.m3u8
''';
      final variants = KickHlsPlaylistParser.parseMaster(
        body: body,
        masterUrl: master,
      );
      expect(variants.map((v) => v.id).toList(), [
        '1080p60',
        '720p60',
        '360p30',
      ]);
      expect(variants.first.height, 1080);
      expect(variants.first.frameRate, 60);
      expect(
        variants.first.url,
        'https://stream.kick.com/ivs/v1/196233775518/chan/2025/8/1/12/0/rec/media/hls/1080p60/playlist.m3u8',
      );
    });
  });

  group('KickResolvedStream', () {
    test('selects variant playlist for format id', () {
      const stream = KickResolvedStream(
        masterPlaylistUrl: 'https://cdn.example/master.m3u8',
        title: 'Night stream',
        videoId: 'abc',
        variants: [
          KickStreamVariant(
            id: '720p60',
            url: 'https://cdn.example/720p60/playlist.m3u8',
            label: '720p60',
            height: 720,
          ),
        ],
      );
      expect(stream.playlistFor(), 'https://cdn.example/master.m3u8');
      expect(
        stream.playlistFor(formatId: '720p60'),
        'https://cdn.example/720p60/playlist.m3u8',
      );
      final metadata = stream.toYtDlpMetadata();
      expect(metadata['title'], 'Night stream');
      expect(metadata['formats'], isA<List<Map<String, dynamic>>>());
      expect((metadata['formats'] as List).length, 2);
    });
  });

  group('KickSource.resolve', () {
    test('resolves a VOD from 403 JSON metadata and parallel HLS probe', () async {
      const videoUuid = '69d65b8d-89e2-4a5f-89b8-d2572d2f18cf';
      const pageUrl = 'https://kick.com/tester/videos/$videoUuid';
      const masterUrl =
          'https://stream.kick.com/ivs/v1/196233775518/chan123/2025/8/1/12/0/rec456/media/hls/master.m3u8';
      const videoJson = {
        'uuid': videoUuid,
        'session_title': 'Sub VOD',
        'start_time': '2025-08-01 12:00:00',
        'live_stream_id': 99,
        'thumbnail': {
          'src':
              'https://images.kick.com/video_thumbnails/chan123/rec456/thumb.webp',
        },
        'channel': {'id': 'chan123', 'slug': 'tester'},
      };

      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('/api/v1/video/$videoUuid')) {
          return http.Response(
            jsonEncode(videoJson),
            403,
            headers: {'content-type': 'application/json'},
          );
        }
        if (url.contains('/api/') && url.contains('/channels/tester')) {
          return http.Response(
            jsonEncode({
              'id': 'chan123',
              'slug': 'tester',
              'user': {'username': 'tester', 'profile_pic': ''},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'HEAD' && url == masterUrl) {
          return http.Response('', 200);
        }
        if (request.method == 'GET' && url == masterUrl) {
          return http.Response(
            '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=1920x1080\n1080p60/playlist.m3u8\n',
            200,
          );
        }
        if (request.method == 'HEAD') {
          return http.Response('', 404);
        }
        return http.Response('not found', 404);
      });

      final source = KickSource(client: client);
      final resolved = await source.resolve(pageUrl);

      expect(resolved, isNotNull);
      expect(resolved!.masterPlaylistUrl, masterUrl);
      expect(resolved.title, 'Sub VOD');
      expect(resolved.variants, isNotEmpty);
      expect(resolved.variants.first.id, '1080p60');
    });

    test('resolves a live channel playback_url', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/channels/xqc')) {
          return http.Response(
            jsonEncode({
              'id': 1,
              'slug': 'xqc',
              'playback_url': 'https://fa.example/live.m3u8',
              'livestream': {'session_title': 'Live now'},
              'user': {'username': 'xqc'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.toString().endsWith('live.m3u8')) {
          return http.Response('#EXTM3U\n', 200);
        }
        return http.Response('no', 404);
      });

      final source = KickSource(client: client);
      final resolved = await source.resolve('https://kick.com/xqc');
      expect(resolved, isNotNull);
      expect(resolved!.masterPlaylistUrl, 'https://fa.example/live.m3u8');
      expect(resolved.title, 'Live now');
    });
  });
}
