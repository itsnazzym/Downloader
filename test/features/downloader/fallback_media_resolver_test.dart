import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/data/sources/fallback_media_resolver.dart';

void main() {
  const fx = '''
{"code":200,"tweet":{"text":"https://candyai.gg/inaya","author":{"screen_name":"AestheticBLJB"},
"media":{"videos":[{"thumbnail_url":"https://pbs.twimg.com/t.jpg",
"url":"https://video.twimg.com/amplify_video/1/vid/avc1/720x1280/a.mp4?tag=29",
"formats":[
{"container":"m3u8","url":"https://video.twimg.com/amplify_video/1/pl/x.m3u8?tag=29"},
{"container":"mp4","url":"https://video.twimg.com/amplify_video/1/vid/avc1/320x568/b.mp4?tag=29"},
{"container":"mp4","url":"https://video.twimg.com/amplify_video/1/vid/avc1/480x852/c.mp4?tag=29"},
{"container":"mp4","url":"https://video.twimg.com/amplify_video/1/vid/avc1/720x1280/a.mp4?tag=29"}]}]}}}
''';

  group('parseFxTwitter', () {
    test('lists the mp4 streams tallest first and ignores the playlist', () {
      final m = FallbackMediaResolver.parseFxTwitter(fx, tweetId: '9')!;
      expect(m.candidates.map((c) => c.height), [720, 480, 320]);
      expect(m.candidates.first.url, contains('720x1280/a.mp4'));
      expect(m.thumbnail, 'https://pbs.twimg.com/t.jpg');
      expect(m.id, '9');
    });

    test('a link-only tweet is titled by author and id', () {
      final m = FallbackMediaResolver.parseFxTwitter(fx, tweetId: '9')!;
      expect(m.title, 'AestheticBLJB - 9');
    });

    test('pick follows the requested quality', () {
      final m = FallbackMediaResolver.parseFxTwitter(fx, tweetId: '9')!;
      expect(m.pick('best').height, 720);
      expect(m.pick('480').height, 480);
      expect(m.pick('600').height, 480);
      expect(m.pick('240').height, 320); // nothing fits: smallest
    });

    test('no video means null', () {
      expect(
        FallbackMediaResolver.parseFxTwitter(
          '{"tweet":{"text":"hi","media":{"photos":[{"url":"x"}]}}}',
          tweetId: '1',
        ),
        isNull,
      );
      expect(
        FallbackMediaResolver.parseFxTwitter('not json', tweetId: '1'),
        isNull,
      );
    });
  });

  group('parseVxTwitter', () {
    test('reads video entries of media_extended', () {
      final m = FallbackMediaResolver.parseVxTwitter(
        '{"text":"clip","user_screen_name":"u","media_extended":['
        '{"type":"image","url":"https://i/x.jpg"},'
        '{"type":"video","url":"https://video.twimg.com/v/avc1/720x1280/a.mp4",'
        '"thumbnail_url":"https://i/t.jpg"}]}',
        tweetId: '5',
      )!;
      expect(m.candidates, hasLength(1));
      expect(m.title, 'clip');
    });
  });

  group('parsePage', () {
    final base = Uri.parse('https://example.com/watch/42');

    test('reads Open Graph video and title', () {
      final m = FallbackMediaResolver.parsePage(
        '<html><head><title>Fallback</title>'
        '<meta property="og:title" content="My &amp; clip">'
        '<meta property="og:video:url" content="/media/clip.mp4">'
        '<meta property="og:image" content="/thumb.jpg"></head></html>',
        base: base,
      )!;
      expect(m.candidates.single.url, 'https://example.com/media/clip.mp4');
      expect(m.title, 'My & clip');
      expect(m.thumbnail, 'https://example.com/thumb.jpg');
    });

    test('reads video and source tags', () {
      final m = FallbackMediaResolver.parsePage(
        '<video controls><source src="https://cdn.example.com/a.m3u8" type="x">'
        '</video>',
        base: base,
      )!;
      expect(m.candidates.single.url, 'https://cdn.example.com/a.m3u8');
    });

    test('ignores loose mp4 strings and non-media sources', () {
      expect(
        FallbackMediaResolver.parsePage(
          '<script>var ad = "https://ads.example.com/promo.mp4";</script>'
          '<video src="/player.html"></video>',
          base: base,
        ),
        isNull,
      );
    });
  });

  group('resolve', () {
    test('uses fxtwitter first and falls back to vxtwitter', () async {
      final asked = <String>[];
      final resolver = FallbackMediaResolver(
        fetchText: (url) async {
          asked.add(url.host);
          return url.host == 'api.vxtwitter.com'
              ? '{"text":"t","media_extended":[{"type":"video",'
                    '"url":"https://video.twimg.com/v/avc1/480x852/a.mp4"}]}'
              : null;
        },
      );
      final m = await resolver.resolve(
        'https://x.com/u/status/2122798036061483429',
      );
      expect(asked, ['api.fxtwitter.com', 'api.vxtwitter.com']);
      expect(m?.source, 'vxtwitter');
    });

    test('rejects non-http links without any request', () async {
      var called = false;
      final resolver = FallbackMediaResolver(
        fetchText: (_) async {
          called = true;
          return null;
        },
      );
      expect(await resolver.resolve('file:///etc/passwd'), isNull);
      expect(called, isFalse);
    });
  });
}
