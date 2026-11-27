import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/features/archive/data/datasources/tiktok_archive_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TikTokArchiveParser', () {
    test('parses small synthetic JSON correctly with deduplication', () async {
      const mockJson = '''
      {
        "Likes and Favorites": {
          "Favorite Videos": {
            "FavoriteVideoList": [
              {
                "Date": "2026-09-02 21:00:03",
                "Link": "https://www.tiktokv.com/share/video/7674494971336019232/"
              },
              {
                "Date": "2025-01-10 12:00:00",
                "Link": "https://www.tiktokv.com/share/video/1111111111111111111/"
              }
            ]
          },
          "Like List": {
            "ItemFavoriteList": [
              {
                "date": "2026-09-02 21:00:02",
                "link": "https://www.tiktokv.com/share/video/7674494971336019232/"
              },
              {
                "date": "2026-08-01 10:00:00",
                "link": "https://www.tiktokv.com/share/video/2222222222222222222/"
              }
            ]
          },
          "Favorite Collection": {
            "FavoriteCollectionList": [
              {
                "Date": "2026-09-07 03:41:21",
                "FavoriteCollection": "Collection Test"
              }
            ]
          },
          "Favorite Sounds": {
            "FavoriteSoundList": [
              {
                "Date": "2026-05-01 10:00:00",
                "Link": "https://www.tiktokv.com/share/music/Son-Viral-70001"
              }
            ]
          }
        }
      }
      ''';

      final catalog = await TikTokArchiveParser.parseFromString(mockJson);

      expect(catalog.totalFavorites, equals(2));
      expect(catalog.totalLikes, equals(2));
      expect(catalog.totalOverlap, equals(1));
      expect(catalog.totalUniqueVideos, equals(3));
      expect(catalog.collections.length, greaterThanOrEqualTo(1));
      expect(catalog.collections.any((c) => c.name == 'Collection Test'), isTrue);
      expect(catalog.sounds.length, equals(1));
      expect(catalog.sounds.first.title, contains('Son Viral'));

      // Check item with overlap
      final merged = catalog.videos.firstWhere((v) => v.id == '7674494971336019232');
      expect(merged.isFavorite, isTrue);
      expect(merged.isLiked, isTrue);
    });

    test('parses real user TikTok export file if present', () async {
      const realPath = r'C:\Users\entre\Downloads\tiktok_data\user_data_tiktok.json';
      if (!File(realPath).existsSync()) return;

      final stopwatch = Stopwatch()..start();
      final catalog = await TikTokArchiveParser.parseFromFile(realPath);
      stopwatch.stop();

      // ignore: avoid_print
      print('Parsed ${catalog.totalUniqueVideos} unique videos in ${stopwatch.elapsedMilliseconds} ms');

      expect(catalog.totalFavorites, equals(18416));
      expect(catalog.totalLikes, equals(6000));
      expect(catalog.totalOverlap, equals(4572));
      expect(catalog.totalUniqueVideos, equals(19844));
      expect(catalog.collections.length, greaterThanOrEqualTo(127));
      expect(catalog.sounds.length, equals(308));
      expect(stopwatch.elapsedMilliseconds, lessThan(3000)); // Well under 3 seconds
    });
  });
}
