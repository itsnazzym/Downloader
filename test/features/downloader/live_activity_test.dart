import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/entities/download_request.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/live_activity.dart';
import 'package:tapload/l10n/app_localizations.dart';

DownloadItem _item(
  String id, {
  DownloadStatus status = DownloadStatus.downloading,
  double progress = 0,
  String speed = '',
  String eta = '',
}) {
  return DownloadItem(
    id: id,
    request: const DownloadRequest(url: 'https://example.com/v'),
    status: status,
    progress: progress,
    speed: speed,
    eta: eta,
  );
}

void main() {
  group('liveActiveItems', () {
    test('uses the live copy: the catalog copy still says 0 %', () {
      final catalog = [_item('a')];
      final live = _item('a', progress: 0.62, speed: '12.4MiB/s', eta: '00:05');

      final active = liveActiveItems(catalog, (id) => id == 'a' ? live : null);

      expect(active.single.progress, 0.62);
      expect(active.single.speed, '12.4MiB/s');
    });

    test('keeps the catalog copy until the first tick arrives', () {
      final active = liveActiveItems([_item('a')], (id) => null);
      expect(active.single.progress, 0);
    });

    test('leaves out finished, failed and queued rows', () {
      final catalog = [
        _item('done', status: DownloadStatus.completed),
        _item('bad', status: DownloadStatus.failed),
        _item('wait', status: DownloadStatus.queued),
        _item('run'),
        _item('merge', status: DownloadStatus.processing),
        _item('probe', status: DownloadStatus.extracting),
      ];
      final active = liveActiveItems(catalog, (id) => null);
      expect(active.map((i) => i.id), ['run', 'merge', 'probe']);
    });
  });

  group('parseSpeed', () {
    test('reads yt-dlp speeds into bytes per second', () {
      expect(parseSpeed('6.2MiB/s'), closeTo(6.2 * 1024 * 1024, 1));
      expect(parseSpeed('346.19KiB/s'), closeTo(346.19 * 1024, 1));
      expect(parseSpeed('1,5MiB/s'), closeTo(1.5 * 1024 * 1024, 1));
      expect(parseSpeed('900B/s'), 900);
    });

    test('reads the Mbps form the parser stores in the item', () {
      // 926.19KiB/s is stored as "7.6 Mbps" (decimal megabits).
      expect(parseSpeed('7.6 Mbps'), closeTo(7.6e6 / 8, 1));
      expect(parseSpeed('0.1 Mbps'), closeTo(0.1e6 / 8, 1));
      expect(parseSpeed('1,2Gbps'), closeTo(1.2e9 / 8, 1));
      // Round trip with the conversion done by the progress parser.
      expect(parseSpeed('92.2 Mbps')! / (1024 * 1024), closeTo(11.0, 0.05));
    });

    test('ignores text that is not a speed', () {
      expect(parseSpeed(''), isNull);
      expect(parseSpeed('Unknown B/s'), isNull);
      expect(parseSpeed('Terminé'), isNull);
    });

    test('aggregateSpeed adds up the parallel downloads', () {
      final total = aggregateSpeed([
        _item('a', speed: '1MiB/s'),
        _item('b', speed: '2MiB/s'),
        _item('c'),
      ]);
      expect(total, closeTo(3 * 1024 * 1024, 1));
      expect(aggregateSpeed([_item('a')]), isNull);
    });
  });

  group('formatSpeed', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    final en = lookupAppLocalizations(const Locale('en'));

    test('shows the number and its unit with the right separator', () {
      final fast = formatSpeed(fr, 12.4 * 1024 * 1024);
      expect(fast.value, '12,4');
      expect(fast.unit, fr.libraryHeaderUnitMBps);
      expect(formatSpeed(en, 12.4 * 1024 * 1024).value, '12.4');
      expect(formatSpeed(fr, 512 * 1024).unit, fr.libraryHeaderUnitKBps);
    });

    test('has a dash and no unit before the first measure', () {
      final none = formatSpeed(fr, null);
      expect(none.value, '—');
      expect(none.unit, isEmpty);
    });
  });

  group('ETA', () {
    test('parseEta reads seconds, mm:ss and h:mm:ss', () {
      expect(parseEta('08'), const Duration(seconds: 8));
      expect(parseEta('00:08'), const Duration(seconds: 8));
      expect(parseEta('02:54'), const Duration(minutes: 2, seconds: 54));
      expect(
        parseEta('1:02:03'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
      expect(parseEta('Unknown'), isNull);
      expect(parseEta(''), isNull);
      expect(parseEta('1:2:3:4'), isNull);
    });

    test('etaLabel is readable and translated', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final fr = lookupAppLocalizations(const Locale('fr'));
      expect(etaLabel(en, '00:05'), '5 s');
      expect(etaLabel(en, '02:54'), '2 min 54 s');
      expect(etaLabel(fr, '1:05:00'), '1 h 5 min');
      expect(etaLabel(en, 'Unknown'), 'Unknown');
    });
  });
}
