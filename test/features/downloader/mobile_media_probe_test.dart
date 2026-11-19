import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/presentation/views/mobile/media_probe.dart';

void main() {
  const mo = 1024 * 1024;
  const untitled = 'Média sans titre';

  Map<String, dynamic> metadata() => {
    'title': '  Documentaire  ',
    'uploader': 'Atelier Nord',
    'duration': 1425,
    'thumbnail': 'https://img.example/t.jpg',
    'formats': [
      {'vcodec': 'none', 'acodec': 'mp4a', 'filesize': 22 * mo},
      {'vcodec': 'avc1', 'acodec': 'none', 'height': 480, 'filesize': 61 * mo},
      {'vcodec': 'avc1', 'acodec': 'none', 'height': 720, 'filesize': 118 * mo},
      {
        'vcodec': 'avc1',
        'acodec': 'none',
        'height': 1080,
        'filesize_approx': 241 * mo,
      },
    ],
  };

  group('MediaProbe', () {
    test('reads the preview fields', () {
      final probe = MediaProbe.fromMetadata(
        metadata(),
        untitledTitle: untitled,
      );
      expect(probe.title, 'Documentaire');
      expect(probe.uploader, 'Atelier Nord');
      expect(probe.durationSeconds, 1425);
      expect(probe.thumbnail, 'https://img.example/t.jpg');
      expect(probe.maxHeight, 1080);
    });

    test('adds the audio stream to video-only formats', () {
      final probe = MediaProbe.fromMetadata(
        metadata(),
        untitledTitle: untitled,
      );
      expect(probe.estimateBytes('1080', audioOnly: false), 263 * mo);
      expect(probe.estimateBytes('720', audioOnly: false), 140 * mo);
      expect(probe.estimateBytes('best', audioOnly: false), 263 * mo);
      expect(probe.estimateBytes('best', audioOnly: true), 22 * mo);
    });

    test('does not add audio to a format that already has it', () {
      final probe = MediaProbe.fromMetadata({
        'formats': [
          {'vcodec': 'none', 'acodec': 'mp4a', 'filesize': 10 * mo},
          {
            'vcodec': 'avc1',
            'acodec': 'mp4a',
            'height': 720,
            'filesize': 50 * mo,
          },
        ],
      }, untitledTitle: untitled);
      expect(probe.estimateBytes('best', audioOnly: false), 50 * mo);
    });

    test('estimates from bitrate when no size is reported', () {
      final probe = MediaProbe.fromMetadata({
        'duration': 100,
        'formats': [
          {'vcodec': 'avc1', 'acodec': 'mp4a', 'height': 720, 'tbr': 800},
        ],
      }, untitledTitle: untitled);
      expect(probe.estimateBytes('720', audioOnly: false), 10000000);
    });

    test('hides qualities the source cannot serve', () {
      final probe = MediaProbe.fromMetadata({
        'formats': [
          {'vcodec': 'avc1', 'acodec': 'mp4a', 'height': 480, 'filesize': mo},
        ],
      }, untitledTitle: untitled);
      expect(probe.offers(480), isTrue);
      expect(probe.offers(720), isFalse);
      expect(probe.offers(1080), isFalse);
    });

    test('keeps every quality when the source exposes no resolution', () {
      final probe = MediaProbe.fromMetadata({
        'title': 'Direct',
      }, untitledTitle: untitled);
      expect(probe.offers(1080), isTrue);
      expect(probe.estimateBytes('best', audioOnly: false), isNull);
    });

    test('falls back to a title and drops non-http thumbnails', () {
      final probe = MediaProbe.fromMetadata({
        'thumbnail': 'data:image/png;x',
      }, untitledTitle: untitled);
      expect(probe.title, 'Média sans titre');
      expect(probe.thumbnail, isNull);
    });
  });

  group('formatting', () {
    String? fmt(int? bytes) =>
        formatApproxSize(bytes, kb: 'Ko', mb: 'Mo', gb: 'Go');

    test('formats sizes', () {
      expect(fmt(null), isNull);
      expect(fmt(0), isNull);
      expect(fmt(512 * 1024), '~512 Ko');
      expect(fmt(124 * mo), '~124 Mo');
      expect(fmt((1.5 * 1024 * mo).round()), '~1.5 Go');
    });

    test('formats clocks', () {
      expect(formatClock(5), '0:05');
      expect(formatClock(1425), '23:45');
      expect(formatClock(3723), '1:02:03');
    });
  });
}
