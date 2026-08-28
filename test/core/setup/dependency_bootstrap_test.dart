import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_service.dart';
import 'package:modern_downloader/core/setup/dependency_catalog.dart';
import 'package:modern_downloader/core/setup/zip_binary_extractor.dart';
import 'package:modern_downloader/services/binary_locator.dart';

void main() {
  group('DependencyCatalog', () {
    test('covers yt-dlp, ffmpeg/ffprobe, and aria2c', () {
      final ids = DependencyCatalog.windowsRequired.map((pkg) => pkg.id);
      expect(ids, containsAll(['yt-dlp', 'ffmpeg', 'aria2c']));
      expect(
        DependencyCatalog.allExecutableNames(),
        containsAll(['yt-dlp.exe', 'ffmpeg.exe', 'ffprobe.exe', 'aria2c.exe']),
      );
      expect(
        DependencyCatalog.allSetupExecutableNames(),
        contains('gobird.exe'),
      );
      expect(DependencyCatalog.isOptionalExecutable('gobird.exe'), isTrue);
    });
  });

  group('ZipBinaryExtractor', () {
    test('extracts executables from nested zip folders', () {
      final archive = Archive()
        ..addFile(ArchiveFile('ffmpeg-release/bin/ffmpeg.exe', 3, [1, 2, 3]))
        ..addFile(ArchiveFile('ffmpeg-release/bin/ffprobe.exe', 2, [4, 5]))
        ..addFile(
          ArchiveFile('ffmpeg-release/doc/readme.txt', 4, [9, 9, 9, 9]),
        );
      final zipBytes = ZipEncoder().encode(archive);

      final found = ZipBinaryExtractor.extractExecutables(zipBytes, {
        'ffmpeg.exe',
        'ffprobe.exe',
      });

      expect(found['ffmpeg.exe'], [1, 2, 3]);
      expect(found['ffprobe.exe'], [4, 5]);
      expect(found.containsKey('readme.txt'), isFalse);
    });

    test('is case-insensitive on file names', () {
      final archive = Archive()
        ..addFile(ArchiveFile('Aria2/ARIA2C.EXE', 1, [7]));
      final zipBytes = ZipEncoder().encode(archive);

      final found = ZipBinaryExtractor.extractExecutables(zipBytes, {
        'aria2c.exe',
      });

      expect(found['aria2c.exe'], [7]);
    });
  });

  group('DependencyBootstrapService', () {
    setUp(BinaryLocator.clearResolvedPathCache);
    tearDown(BinaryLocator.clearResolvedPathCache);

    test(
      'skips gobird unless experimental feed is enabled',
      () async {
        final locator = _RecordingLocator();
        final service = DependencyBootstrapService(locator: locator);
        await service.ensureReady(
          onProgress: (_) {},
          checkOptionalGobird: false,
        );
        expect(locator.calls.contains('gobird'), isFalse);
      },
      skip: !Platform.isWindows,
    );

    test('checks gobird when experimental feed is enabled', () async {
      final locator = _RecordingLocator();
      final service = DependencyBootstrapService(locator: locator);
      await service.ensureReady(onProgress: (_) {}, checkOptionalGobird: true);
      expect(locator.calls, contains('gobird'));
    }, skip: !Platform.isWindows);

    test('checks required tools in parallel', () async {
      final barrier = Completer<void>();
      final locator = _BarrierLocator(barrier);
      final service = DependencyBootstrapService(locator: locator);
      final done = service.ensureReady(onProgress: (_) {});

      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (locator.started.length < 4 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(
        locator.started.toSet(),
        containsAll({'yt-dlp', 'ffmpeg', 'ffprobe', 'aria2c'}),
      );
      expect(locator.started.contains('gobird'), isFalse);

      barrier.complete();
      await done;
    }, skip: !Platform.isWindows);

    test('reaches ready without awaiting yt-dlp update', () async {
      final locator = _RecordingLocator();
      final service = _SpyUpdateService(locator);
      final steps = <SetupStep>[];
      await service.ensureReady(
        onProgress: (progress) => steps.add(progress.step),
      );
      expect(service.updateCalled, isFalse);
      expect(steps.contains(SetupStep.updating), isFalse);
      expect(steps.last, SetupStep.ready);
    }, skip: !Platform.isWindows);
  });

  group('DependencyBootstrapNotifier', () {
    setUp(BinaryLocator.clearResolvedPathCache);
    tearDown(BinaryLocator.clearResolvedPathCache);

    test('does not wait 1200ms before ready', () async {
      final service = DependencyBootstrapService(locator: _RecordingLocator());
      final notifier = DependencyBootstrapNotifier(
        service,
        updateYtDlp: false,
        autoStart: false,
      );
      final sw = Stopwatch()..start();
      await notifier.ensureReady(updateYtDlp: false);
      sw.stop();
      expect(notifier.state.isReady, isTrue);
      expect(sw.elapsedMilliseconds, lessThan(500));
    }, skip: !Platform.isWindows);

    test(
      'starts yt-dlp update in the background after ready',
      () async {
        final hang = Completer<void>();
        final started = Completer<void>();
        final service = _HangUpdateService(
          _RecordingLocator(),
          started: started,
          hang: hang,
        );
        final notifier = DependencyBootstrapNotifier(
          service,
          updateYtDlp: true,
          autoStart: false,
        );

        await notifier.ensureReady();
        expect(notifier.state.isReady, isTrue);
        expect(started.isCompleted, isTrue);
        expect(hang.isCompleted, isFalse);
        hang.complete();
      },
      skip: !Platform.isWindows,
    );
  });
}

class _RecordingLocator extends BinaryLocator {
  final List<String> calls = [];

  @override
  Future<String?> findYtDlp() async {
    calls.add('yt-dlp');
    return r'C:\bin\yt-dlp.exe';
  }

  @override
  Future<String?> findFfmpeg() async {
    calls.add('ffmpeg');
    return r'C:\bin\ffmpeg.exe';
  }

  @override
  Future<String?> findFfprobe() async {
    calls.add('ffprobe');
    return r'C:\bin\ffprobe.exe';
  }

  @override
  Future<String?> findAria2c() async {
    calls.add('aria2c');
    return r'C:\bin\aria2c.exe';
  }

  @override
  Future<String?> findGobird({bool allowPathProbe = false}) async {
    calls.add('gobird');
    return null;
  }
}

class _BarrierLocator extends BinaryLocator {
  _BarrierLocator(this.barrier);

  final Completer<void> barrier;
  final List<String> started = [];

  Future<String?> _enter(String name) async {
    started.add(name);
    await barrier.future;
    return 'C:\\bin\\$name.exe';
  }

  @override
  Future<String?> findYtDlp() => _enter('yt-dlp');

  @override
  Future<String?> findFfmpeg() => _enter('ffmpeg');

  @override
  Future<String?> findFfprobe() => _enter('ffprobe');

  @override
  Future<String?> findAria2c() => _enter('aria2c');

  @override
  Future<String?> findGobird({bool allowPathProbe = false}) => _enter('gobird');
}

class _SpyUpdateService extends DependencyBootstrapService {
  _SpyUpdateService(BinaryLocator locator) : super(locator: locator);

  bool updateCalled = false;

  @override
  Future<void> updateYtDlpInBackground() async {
    updateCalled = true;
    await super.updateYtDlpInBackground();
  }
}

class _HangUpdateService extends DependencyBootstrapService {
  _HangUpdateService(
    BinaryLocator locator, {
    required this.started,
    required this.hang,
  }) : super(locator: locator);

  final Completer<void> started;
  final Completer<void> hang;

  @override
  Future<void> updateYtDlpInBackground() async {
    if (!started.isCompleted) {
      started.complete();
    }
    await hang.future;
  }
}
