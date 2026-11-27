import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/android/android_engine_bridge.dart';
import 'package:tapload/core/android/media_sniffer_bridge.dart';
import 'package:tapload/features/browser/sniff/sniffed_media.dart';

SniffedMedia media(
  String url, {
  String page = 'https://example.com/watch/1',
  int ts = 0,
}) => SniffedMedia(
  url: url,
  kind: SniffedMediaFilter.classify(url) ?? SniffedKind.video,
  page: page,
  timestamp: ts,
);

void main() {
  group('classify', () {
    test('recognises manifests and files', () {
      expect(
        SniffedMediaFilter.classify('https://c.example/a/master.m3u8?t=1'),
        SniffedKind.hls,
      );
      expect(
        SniffedMediaFilter.classify('https://c.example/a/manifest.mpd'),
        SniffedKind.dash,
      );
      expect(
        SniffedMediaFilter.classify('https://c.example/v.ism/manifest'),
        SniffedKind.dash,
      );
      expect(
        SniffedMediaFilter.classify('https://c.example/v/clip.MP4?sig=x'),
        SniffedKind.video,
      );
      expect(
        SniffedMediaFilter.classify('https://c.example/s/track.m4a'),
        SniffedKind.audio,
      );
    });

    test('ignores segments, images and scripts', () {
      for (final u in [
        'https://c.example/seg_001.ts',
        'https://c.example/chunk.m4s',
        'https://c.example/poster.jpg',
        'https://c.example/app.js',
        'https://c.example/page.html',
      ]) {
        expect(SniffedMediaFilter.classify(u), isNull, reason: u);
      }
    });
  });

  group('heightHint', () {
    test('reads 720p and WxH', () {
      expect(SniffedMediaFilter.heightHint('https://c/x/720p/v.m3u8'), 720);
      expect(SniffedMediaFilter.heightHint('https://c/x/1280x720/v.mp4'), 720);
      expect(SniffedMediaFilter.heightHint('https://c/x/720x1280/v.mp4'), 720);
      expect(SniffedMediaFilter.heightHint('https://c/x/v.mp4'), isNull);
      expect(SniffedMediaFilter.heightHint('https://c/x/h264.mp4'), isNull);
    });
  });

  group('rank', () {
    test('drops ad hosts', () {
      final list = SniffedMediaFilter.rank([
        media('https://securepubads.g.doubleclick.net/ad.mp4'),
        media('https://imasdk.googleapis.com/x/vast.mp4'),
        media('https://cdn.example.com/clip.mp4'),
      ]);
      expect(list.map((m) => m.host), ['cdn.example.com']);
    });

    test('merges the same stream requested again with a new token', () {
      final list = SniffedMediaFilter.rank([
        media('https://cdn.example.com/a/clip.mp4?token=1', ts: 1),
        media('https://cdn.example.com/a/clip.mp4?token=2', ts: 2),
      ]);
      expect(list, hasLength(1));
      expect(list.single.url, endsWith('token=2'));
    });

    test('prefers the HLS master over its variants', () {
      final list = SniffedMediaFilter.rank([
        media('https://cdn.example.com/v/720p/index.m3u8'),
        media('https://cdn.example.com/v/master.m3u8'),
        media('https://cdn.example.com/v/audio_en.m3u8'),
        media('https://cdn.example.com/v/chunklist_480.m3u8'),
      ]);
      expect(list.map((m) => m.fileName), ['master.m3u8']);
    });

    test('real hls.js page: the master hides its numbered variants', () {
      // Requests captured with REA on hls-js.netlify.app (headless Chrome).
      final list = SniffedMediaFilter.rank([
        media('https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8'),
        media(
          'https://test-streams.mux.dev/x36xhzz/url_0/193039199_mp4_h264_aac_hd_7.m3u8',
        ),
        media(
          'https://test-streams.mux.dev/x36xhzz/url_2/193039199_mp4_h264_aac_fhd_7.m3u8',
        ),
      ]);
      expect(list.map((m) => m.fileName), ['x36xhzz.m3u8']);
    });

    test('keeps variants when no master was seen', () {
      final list = SniffedMediaFilter.rank([
        media('https://cdn.example.com/v/720p/index.m3u8'),
        media('https://cdn.example.com/v/480p/index.m3u8'),
      ]);
      expect(list, hasLength(2));
    });

    test('orders manifests, then files by height, then audio', () {
      final list = SniffedMediaFilter.rank([
        media('https://cdn.example.com/a.mp3'),
        media('https://cdn.example.com/480p/clip.mp4'),
        media('https://cdn.example.com/1080p/clip.mp4'),
        media('https://cdn.example.com/stream.mpd'),
        media('https://cdn.example.com/master.m3u8'),
      ]);
      expect(list.map((m) => m.kind), [
        SniffedKind.hls,
        SniffedKind.dash,
        SniffedKind.video,
        SniffedKind.video,
        SniffedKind.audio,
      ]);
      expect(list[2].heightHint, 1080);
    });
  });

  test('mergeNetscape keeps one header and drops duplicates', () {
    final merged = SniffedMediaFilter.mergeNetscape([
      '# Netscape HTTP Cookie File\n.a.com\tTRUE\t/\tTRUE\t0\tk\t1\n',
      '# Netscape HTTP Cookie File\n.a.com\tTRUE\t/\tTRUE\t0\tk\t1\n'
          '.cdn.com\tTRUE\t/\tTRUE\t0\tj\t2\n',
    ]);
    expect('# Netscape'.allMatches(merged).length, 1);
    expect(merged.split('\n').where((l) => l.contains('\tk\t')).length, 1);
    expect(merged, contains('.cdn.com'));
  });

  group('MediaSnifferBridge', () {
    const sniffer = MethodChannel('test/sniffer');
    const engine = MethodChannel('test/engine');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestWidgetsFlutterBinding.ensureInitialized();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(sniffer, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'attach':
            return true;
          case 'streams':
            return [
              {
                'url': 'https://cdn.example.com/v/master.m3u8?t=1',
                'page': 'https://example.com/watch/1',
                'referer': 'https://example.com/',
                'userAgent': 'UA',
                'ts': 5,
              },
              {
                'url': 'https://ads.doubleclick.net/x.mp4',
                'page': 'https://example.com/watch/1',
                'ts': 6,
              },
            ];
        }
        return null;
      });
      messenger.setMockMethodCallHandler(engine, (call) async {
        if (call.method == 'webViewCookies') {
          final url = (call.arguments as Map)['url'] as String;
          return url.contains('cdn') ? 'cdnk=2' : 'pagek=1';
        }
        return null;
      });
    });

    MediaSnifferBridge bridge() => MediaSnifferBridge(
      channel: sniffer,
      engine: AndroidEngineBridge(
        methodChannel: engine,
        eventChannel: const EventChannel('test/engineEvents'),
      ),
    );

    test('attach passes the WebView identifier', () async {
      expect(await bridge().attach(42), isTrue);
      expect(calls.single.arguments, {'id': 42});
    });

    test('streams are ranked and ad hosts removed', () async {
      final list = await bridge().streams();
      expect(list, hasLength(1));
      expect(list.single.kind, SniffedKind.hls);
      expect(list.single.referer, 'https://example.com/');
      expect(list.single.userAgent, 'UA');
    });

    test('session cookies cover the page and the stream hosts', () async {
      final b = bridge();
      final list = await b.streams();
      final cookies = await b.sessionCookies(list.single);
      expect(cookies, contains('.example.com\tTRUE\t/\tTRUE\t0\tpagek\t1'));
      expect(cookies, contains('.cdn.example.com\tTRUE\t/\tTRUE\t0\tcdnk\t2'));
    });
  });
}
