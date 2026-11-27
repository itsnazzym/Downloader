import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/features/browser/sniff/sniffed_media.dart';
import 'package:tapload/features/browser/sniff/stream_probe.dart';

// Shaped like what x.com serves: portrait variants, absolute paths.
const _master = '''#EXTM3U
#EXT-X-VERSION:6
#EXT-X-INDEPENDENT-SEGMENTS
#EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=632155,BANDWIDTH=1330000,RESOLUTION=320x568,CODECS="mp4a.40.2,avc1.4d001e"
/ext/pl/320x568/a.m3u8
#EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=2200000,BANDWIDTH=3500000,RESOLUTION=720x1280,CODECS="mp4a.40.2,avc1.640020"
/ext/pl/720x1280/b.m3u8
#EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=1100000,BANDWIDTH=2000000,RESOLUTION=480x852,CODECS="mp4a.40.2,avc1.4d001f"
/ext/pl/480x852/c.m3u8
''';

const _vod = '''#EXTM3U
#EXT-X-PLAYLIST-TYPE:VOD
#EXTINF:6.000,
s0.m4s
#EXTINF:6.000,
s1.m4s
#EXTINF:3.500,
s2.m4s
#EXT-X-ENDLIST
''';

SniffedMedia _media(String url, SniffedKind kind) =>
    SniffedMedia(url: url, kind: kind, page: 'https://x.com/home');

void main() {
  group('HLS parsing', () {
    test('the best variant is the tallest picture, by its short side', () {
      final variants = parseHlsVariants(
        _master,
        Uri.parse('https://video.twimg.com/ext/pl/m.m3u8'),
      );
      expect(variants.map((v) => v.uri.path), [
        '/ext/pl/720x1280/b.m3u8',
        '/ext/pl/480x852/c.m3u8',
        '/ext/pl/320x568/a.m3u8',
      ]);
      // BANDWIDTH, not AVERAGE-BANDWIDTH.
      expect(variants.first.bandwidth, 3500000);
    });

    test('a media playlist has no variants', () {
      expect(parseHlsVariants(_vod, Uri.parse('https://c/x.m3u8')), isEmpty);
    });

    test('the length of a finished playlist is the sum of its segments', () {
      expect(parseHlsDuration(_vod), const Duration(milliseconds: 15500));
    });

    test('a live playlist has no length', () {
      expect(
        parseHlsDuration('#EXTM3U\n#EXTINF:6.0,\ns0.ts\n#EXTINF:6.0,\ns1.ts\n'),
        isNull,
      );
    });
  });

  group('DASH parsing', () {
    test('reads the duration and the tallest representation', () {
      final info = parseDash(
        '<MPD mediaPresentationDuration="PT1M12.5S"><Representation height="360"/>'
        '<Representation height="1080"/></MPD>',
      );
      expect(info.duration, const Duration(milliseconds: 72500));
      expect(info.height, 1080);
    });
  });

  test('clockLabel', () {
    expect(clockLabel(const Duration(seconds: 42)), '0:42');
    expect(clockLabel(const Duration(minutes: 12, seconds: 5)), '12:05');
    expect(
      clockLabel(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });

  group('probeStream over HTTP', () {
    late HttpServer server;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        final body = switch (request.uri.path) {
          '/master.m3u8' => _master,
          '/ext/pl/720x1280/b.m3u8' => _vod,
          _ => null,
        };
        if (body == null) {
          request.response.statusCode = 404;
        } else {
          request.response.write(body);
        }
        request.response.close();
      });
    });
    tearDown(() => server.close(force: true));

    test('reads size, length and picture of a master playlist', () async {
      final info = await probeStream(
        _media('http://127.0.0.1:${server.port}/master.m3u8', SniffedKind.hls),
      );
      expect(info!.height, 720);
      expect(info.duration, const Duration(milliseconds: 15500));
      // 3.5 Mbit/s over 15.5 s.
      expect(info.bytes, closeTo(3500000 / 8 * 15.5, 1));
    });

    test('an unreadable manifest gives null, not an error', () async {
      final info = await probeStream(
        _media('http://127.0.0.1:${server.port}/missing.m3u8', SniffedKind.hls),
      );
      expect(info, isNull);
    });
  });
}
