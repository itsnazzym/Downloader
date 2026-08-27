import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/download_file_resolver.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_view.dart';
import 'package:modern_downloader/core/ui/media_player/media_playlist.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

void main() {
  group('wrapIndex', () {
    test('0 - 1 wraps to last', () {
      expect(wrapIndex(0, -1, 5), 4);
    });

    test('last + 1 wraps to 0', () {
      expect(wrapIndex(4, 1, 5), 0);
    });

    test('single item restarts same index', () {
      expect(wrapIndex(0, 1, 1), 0);
      expect(wrapIndex(0, -1, 1), 0);
    });

    test('empty length returns 0', () {
      expect(wrapIndex(0, 1, 0), 0);
    });
  });

  group('DownloadFileResolver media helpers', () {
    test('isAudioPath / isMediaPath', () {
      expect(DownloadFileResolver.isAudioPath(r'C:\a.mp3'), isTrue);
      expect(DownloadFileResolver.isMediaPath(r'C:\a.mp3'), isTrue);
      expect(DownloadFileResolver.isMediaPath(r'C:\a.mp4'), isTrue);
      expect(DownloadFileResolver.isMediaPath(r'C:\a.txt'), isFalse);
      expect(DownloadFileResolver.isMediaPath(r'C:\a.part'), isTrue);
    });

    test('resolvePlayablePath skips non-media', () {
      final resolved = DownloadFileResolver.resolvePlayablePath(
        r'C:\dl\notes.txt',
        existsSync: (p) => p == r'C:\dl\notes.txt',
      );
      expect(resolved, isNull);
    });

    test('resolvePlayablePath returns existing video', () {
      final resolved = DownloadFileResolver.resolvePlayablePath(
        r'C:\dl\clip.mp4',
        existsSync: (p) => p == r'C:\dl\clip.mp4',
      );
      expect(resolved, r'C:\dl\clip.mp4');
    });
  });

  group('mediaPlaylistProvider', () {
    late Directory tempDir;
    late File videoA;
    late File videoB;
    late File textFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('md_playlist_');
      videoA = File('${tempDir.path}${Platform.pathSeparator}a.mp4')
        ..writeAsBytesSync([0]);
      videoB = File('${tempDir.path}${Platform.pathSeparator}b.mp4')
        ..writeAsBytesSync([0]);
      textFile = File('${tempDir.path}${Platform.pathSeparator}notes.txt')
        ..writeAsBytesSync([0]);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    DownloadItem item({required String id, required String? path}) {
      return DownloadItem(
        id: id,
        request: const DownloadRequest(url: 'https://example.com'),
        status: DownloadStatus.completed,
        title: id,
        filePath: path,
      );
    }

    test('skips non-playable entries and keeps list order', () {
      final container = ProviderContainer(
        overrides: [
          filteredDownloadsProvider.overrideWith(
            (ref) => AsyncValue.data([
              item(id: 'a', path: videoA.path),
              item(id: 'skip', path: textFile.path),
              item(id: 'b', path: videoB.path),
              item(id: 'missing', path: r'C:\nope\missing.mp4'),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final playlist = container.read(mediaPlaylistProvider);
      expect(playlist.map((e) => e.id).toList(), ['a', 'b']);
      expect(playlist.map((e) => e.filePath).toList(), [
        videoA.path,
        videoB.path,
      ]);
    });
  });

  group('MediaPlaylistController + didComplete', () {
    test('skipBy wraps and syncs selection', () async {
      const entries = [
        PlaylistEntry(id: '1', filePath: r'C:\a.mp4', title: 'A'),
        PlaylistEntry(id: '2', filePath: r'C:\b.mp4', title: 'B'),
        PlaylistEntry(id: '3', filePath: r'C:\c.mp4', title: 'C'),
      ];

      final container = ProviderContainer(
        overrides: [
          mediaPlayerProvider.overrideWith(
            (ref) => MediaPlayerNotifier(testMode: true),
          ),
          mediaPlaylistProvider.overrideWith((ref) => entries),
        ],
      );
      addTearDown(container.dispose);

      final player = container.read(mediaPlayerProvider.notifier);
      await player.switchFile(entries.first.filePath);
      expect(
        container.read(mediaPlayerProvider).currentFile,
        entries[0].filePath,
      );

      await container.read(mediaPlaylistControllerProvider).skipBy(-1);
      expect(
        container.read(mediaPlayerProvider).currentFile,
        entries[2].filePath,
      );
      expect(container.read(selectedDownloadIdProvider), '3');

      await container.read(mediaPlaylistControllerProvider).skipBy(1);
      expect(
        container.read(mediaPlayerProvider).currentFile,
        entries[0].filePath,
      );
      expect(container.read(selectedDownloadIdProvider), '1');
    });

    test('single item skip restarts same file', () async {
      const entries = [
        PlaylistEntry(id: 'only', filePath: r'C:\only.mp4', title: 'Only'),
      ];

      final container = ProviderContainer(
        overrides: [
          mediaPlayerProvider.overrideWith(
            (ref) => MediaPlayerNotifier(testMode: true),
          ),
          mediaPlaylistProvider.overrideWith((ref) => entries),
        ],
      );
      addTearDown(container.dispose);

      final player = container.read(mediaPlayerProvider.notifier);
      await player.switchFile(entries.first.filePath);
      await container.read(mediaPlaylistControllerProvider).skipBy(1);
      expect(
        container.read(mediaPlayerProvider).currentFile,
        entries.first.filePath,
      );
      expect(container.read(mediaPlayerProvider).didComplete, isFalse);
    });

    testWidgets('didComplete triggers skipBy(1)', (tester) async {
      const entries = [
        PlaylistEntry(id: '1', filePath: r'C:\a.mp4', title: 'A'),
        PlaylistEntry(id: '2', filePath: r'C:\b.mp4', title: 'B'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaPlayerProvider.overrideWith(
              (ref) => MediaPlayerNotifier(testMode: true),
            ),
            mediaPlaylistProvider.overrideWith((ref) => entries),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaPlayerView(),
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MediaPlayerView)),
      );
      final player = container.read(mediaPlayerProvider.notifier);
      await player.switchFile(entries.first.filePath);
      await tester.pump();

      expect(
        container.read(mediaPlayerProvider).currentFile,
        entries[0].filePath,
      );

      player.simulateCompleted();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        container.read(mediaPlayerProvider).currentFile,
        entries[1].filePath,
      );
      expect(container.read(selectedDownloadIdProvider), '2');
      expect(container.read(mediaPlayerProvider).didComplete, isFalse);
    });
  });
}
