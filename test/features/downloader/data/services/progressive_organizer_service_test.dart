import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tapload/features/downloader/data/services/progressive_organizer_service.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/entities/download_request.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ProgressiveOrganizerService - Unit Tests', () {
    test(
      'extractCreatorFromUrl extracts creator and strips leading @ (AAA Pattern)',
      () {
        // Arrange & Act
        final tiktok1 = ProgressiveOrganizerService.extractCreatorFromUrl(
          'https://www.tiktok.com/@hijabi1/video/7106594312292453675',
        );
        final tiktok2 = ProgressiveOrganizerService.extractCreatorFromUrl(
          'https://m.tiktok.com/v/7106594312292453675.html?u=@sarah_b.99',
        );
        final twitter1 = ProgressiveOrganizerService.extractCreatorFromUrl(
          'https://x.com/elonmusk/status/1891234567890123456',
        );
        final twitter2 = ProgressiveOrganizerService.extractCreatorFromUrl(
          'https://twitter.com/@nasa/status/1891234567890123456',
        );
        final youtube1 = ProgressiveOrganizerService.extractCreatorFromUrl(
          'https://www.youtube.com/@Veritasium',
        );
        final instagram1 = ProgressiveOrganizerService.extractCreatorFromUrl(
          'https://www.instagram.com/natgeo/reel/C8_xyz123/',
        );

        // Assert
        expect(tiktok1, 'hijabi1');
        expect(tiktok2, 'sarah_b.99');
        expect(twitter1, 'elonmusk');
        expect(twitter2, 'nasa');
        expect(youtube1, 'Veritasium');
        expect(instagram1, 'natgeo');
      },
    );

    test(
      'getSiteName eliminates Other for twimg, local directories, and detected domains',
      () {
        expect(
          ProgressiveOrganizerService.getSiteName(
            'https://video.twimg.com/amplify_video/2092593651679649792/vid/avc1/720x1278/clip.mp4',
          ),
          'Twitter',
        );
        expect(
          ProgressiveOrganizerService.getSiteName(
            'https://twitter.detected/imported',
            filePath: r'E:\Videos\Twitter\clip.mp4',
          ),
          'Twitter',
        );
        expect(
          ProgressiveOrganizerService.getSiteName(
            null,
            filePath: r'E:\Videos\Twimg\clip.mp4',
          ),
          'Twitter',
        );
        expect(
          ProgressiveOrganizerService.getSiteName(
            'https://www.tiktok.com/@user/video/1',
          ),
          'TikTok',
        );
        expect(
          ProgressiveOrganizerService.getSiteName(
            'https://youtu.be/dQw4w9WgXcQ',
          ),
          'YouTube',
        );
        expect(
          ProgressiveOrganizerService.getSiteName(
            'https://unknown.invalid/imported',
          ),
          'Other',
        );
      },
    );

    test(
      'extractCreatorFromTitleOrFilename parses creator patterns and strips @ (P0)',
      () {
        // 1. Dash pattern with @
        final c1 =
            ProgressiveOrganizerService.extractCreatorFromTitleOrFilename(
              '@Adult_Hoodz - Visit the website for more [2085212002805223424]',
              null,
            );
        expect(c1, 'Adult_Hoodz');

        // 2. Dash pattern without @
        final c2 =
            ProgressiveOrganizerService.extractCreatorFromTitleOrFilename(
              '100yenAVshop - 2093101471554556190 [2093101471554556190]',
              null,
            );
        expect(c2, '100yenAVshop');

        // 3. Explicit Credit pattern
        final c3 =
            ProgressiveOrganizerService.extractCreatorFromTitleOrFilename(
              '⋆ Blowjob Queen ⋆ - Credit @LolaSky69 [2093310019303272448]',
              null,
            );
        expect(c3, 'LolaSky69');

        // 4. Bracket pattern directly after name
        final c4 =
            ProgressiveOrganizerService.extractCreatorFromTitleOrFilename(
              '⋆ Blowjob Queen ⋆ [2092675645528555520]',
              null,
            );
        expect(c4, '⋆ Blowjob Queen ⋆');
      },
    );

    test(
      'buildTweetIdToCreatorIndex correlates ID from item with known creator',
      () async {
        final itemWithUrl = DownloadItem(
          id: '1',
          request: const DownloadRequest(
            url: 'https://x.com/Throatology5000/status/2092415517956956639',
          ),
          title: 'Throat Clip',
          filePath: r'E:\Videos\Twitter\clip [2092415517956956639].mp4',
        );

        final index =
            await ProgressiveOrganizerService.buildTweetIdToCreatorIndex([
              itemWithUrl,
            ]);

        expect(index['2092415517956956639'], 'Throatology5000');
      },
    );

    test('extractCreatorFromInfoJson reads sidecar JSON uploader', () {
      final tempDir = Directory.systemTemp.createTempSync('md_info_json_test_');
      try {
        final video = File(p.join(tempDir.path, 'video.mp4'))
          ..writeAsStringSync('video');
        File(p.join(tempDir.path, 'video.info.json')).writeAsStringSync(
          jsonEncode({'uploader': 'CoolArtist', 'id': '999'}),
        );

        final creator = ProgressiveOrganizerService.extractCreatorFromInfoJson(
          video.path,
        );
        expect(creator, 'CoolArtist');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('resolveCollision increments file counter when target exists', () {
      final tempDir = Directory.systemTemp.createTempSync('md_collision_test_');
      try {
        File(p.join(tempDir.path, 'video.mp4')).writeAsStringSync('1');
        File(p.join(tempDir.path, 'video (1).mp4')).writeAsStringSync('2');

        final target = p.join(tempDir.path, 'video.mp4');
        final resolved = ProgressiveOrganizerService.resolveCollision(target);

        expect(p.basename(resolved), 'video (2).mp4');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'findSidecars identifies .jpg, .srt, and .info.json next to video',
      () {
        final tempDir = Directory.systemTemp.createTempSync(
          'md_sidecars_test_',
        );
        try {
          final video = File(p.join(tempDir.path, 'clip [123].mp4'))
            ..writeAsStringSync('video');
          File(
            p.join(tempDir.path, 'clip [123].jpg'),
          ).writeAsStringSync('thumb');
          File(p.join(tempDir.path, 'clip [123].srt')).writeAsStringSync('sub');
          File(
            p.join(tempDir.path, 'clip [123].info.json'),
          ).writeAsStringSync('{}');
          File(p.join(tempDir.path, 'other.jpg')).writeAsStringSync('other');

          final sidecars = ProgressiveOrganizerService.findSidecars(video.path);

          expect(sidecars.length, 3);
          expect(sidecars.any((s) => s.endsWith('.jpg')), isTrue);
          expect(sidecars.any((s) => s.endsWith('.srt')), isTrue);
          expect(sidecars.any((s) => s.endsWith('.info.json')), isTrue);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
    );

    test(
      'reorganize moves files out of Inconnu/ and deletes empty Inconnu folder (P2)',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'md_inconnu_drain_test_',
        );
        try {
          // Arrange: Video currently trapped inside Twitter/Inconnu/
          final twitterInconnuDir = Directory(
            p.join(tempDir.path, 'Twitter', 'Inconnu'),
          )..createSync(recursive: true);
          final video = File(
            p.join(twitterInconnuDir.path, '100yenAVshop - funny [777].mp4'),
          )..writeAsStringSync('video_bytes');

          final item = DownloadItem(
            id: 'item_inconnu_1',
            request: const DownloadRequest(
              url: 'https://twitter.detected/imported',
            ),
            title: '100yenAVshop - funny [777]',
            filePath: video.path,
          );

          final service = ProgressiveOrganizerService();

          // Act 1: Simulation (Dry-Run)
          final preview = await service.simulate(
            items: [item],
            defaultBaseFolder: tempDir.path,
            organizeBySite: true,
          );

          // Assert 1: Preview knows it should move from Inconnu to 100yenAVshop
          expect(preview.totalToMove, 1);
          expect(preview.itemsToMove.first.creator, '100yenAVshop');
          expect(preview.itemsToMove.first.site, 'Twitter');

          // Act 2: Execute progressive reorganization
          final stream = service.executeProgressively(
            planItems: preview.itemsToMove,
            stepDelay: Duration.zero,
            onFileMoved: (id, newPath, newThumb) async {},
          );

          await for (final progress in stream) {
            expect(progress.isCompleted, isTrue);
          }

          // Assert 2: File moved to target, old Inconnu directory was emptied and cleaned up
          final expectedTarget = p.join(
            tempDir.path,
            'Twitter',
            '100yenAVshop',
            '100yenAVshop - funny [777].mp4',
          );
          expect(File(expectedTarget).existsSync(), isTrue);
          expect(video.existsSync(), isFalse);
          expect(
            twitterInconnuDir.existsSync(),
            isFalse,
            reason: 'Empty Inconnu folder must be deleted',
          );
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
    );

    test(
      'onlineMetadataFetcher resolves raw ID video without title (P1)',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'md_online_resolve_test_',
        );
        try {
          final video = File(
            p.join(
              tempDir.path,
              '2093112487948541952 [2093112487948541952].mp4',
            ),
          )..writeAsStringSync('raw');

          final item = DownloadItem(
            id: 'raw_id_item',
            request: const DownloadRequest(
              url: 'https://x.com/i/status/2093112487948541952',
            ),
            title: '2093112487948541952',
            filePath: video.path,
          );

          final service = ProgressiveOrganizerService();

          final creator = await service.resolveCreator(
            item,
            onlineMetadataFetcher: (url) async {
              if (url.contains('2093112487948541952')) {
                return {
                  'uploader': 'SecretCreator',
                  'uploader_id': 'secret_123',
                };
              }
              return null;
            },
          );

          expect(creator, 'SecretCreator');
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
    );
  });
}
