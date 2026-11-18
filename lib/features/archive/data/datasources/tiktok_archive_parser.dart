import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../domain/entities/tiktok_archive_catalog.dart';

/// High-performance asynchronous TikTok Archive JSON parser.
/// Executes in a dedicated background Isolate via [compute] to preserve 60/120 FPS UI.
class TikTokArchiveParser {
  /// Parse TikTok export file directly from disk in a background isolate.
  static Future<TikTokArchiveCatalog> parseFromFile(String filePath) async {
    return compute(_parseJsonFileIsolate, filePath);
  }

  /// Parse TikTok export from raw string in a background isolate.
  static Future<TikTokArchiveCatalog> parseFromString(String jsonString) async {
    return compute(_parseJsonStringIsolate, jsonString);
  }

  static TikTokArchiveCatalog _parseJsonFileIsolate(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('File not found', filePath);
    }
    final content = file.readAsStringSync(encoding: utf8);
    return _parseJsonStringIsolate(content);
  }

  static TikTokArchiveCatalog _parseJsonStringIsolate(String content) {
    final dynamic decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid TikTok JSON root: expected object');
    }

    final likesAndFav =
        decoded['Likes and Favorites'] as Map<String, dynamic>? ?? decoded;

    // 1. Raw collections list
    final collList =
        (likesAndFav['Favorite Collection']
                as Map<String, dynamic>?)?['FavoriteCollectionList']
            as List<dynamic>? ??
        [];

    // Parse raw collections with their creation/modification date
    final List<TikTokCollectionItem> parsedColls = [];
    for (final raw in collList) {
      if (raw is! Map<String, dynamic>) continue;
      final name =
          (raw['FavoriteCollection'] ?? raw['favoriteCollection']) as String? ??
          '';
      if (name.isEmpty) continue;

      final dateStr = (raw['Date'] ?? raw['date']) as String? ?? '';
      final parsedDate = DateTime.tryParse(dateStr);

      parsedColls.add(
        TikTokCollectionItem(name: name, date: parsedDate, videoCount: 0),
      );
    }

    // 2. Parse Favorite Videos
    final favList =
        (likesAndFav['Favorite Videos']
                as Map<String, dynamic>?)?['FavoriteVideoList']
            as List<dynamic>? ??
        [];

    // 3. Parse Liked Videos
    final likeList =
        (likesAndFav['Like List'] as Map<String, dynamic>?)?['ItemFavoriteList']
            as List<dynamic>? ??
        [];

    // 4. Parse Sounds
    final soundList =
        (likesAndFav['Favorite Sounds']
                as Map<String, dynamic>?)?['FavoriteSoundList']
            as List<dynamic>? ??
        [];

    final idRegex = RegExp(r'/video/(\d+)');
    final Map<String, TikTokArchiveItem> videoMap = {};
    int totalFavorites = 0;
    int totalLikes = 0;
    int overlap = 0;
    final Map<int, int> yearCounts = {};

    // Process Favorites (Unassigned to false collections until real browser sync)
    for (final raw in favList) {
      if (raw is! Map<String, dynamic>) continue;
      final link = (raw['Link'] ?? raw['link']) as String? ?? '';
      if (link.isEmpty) continue;

      totalFavorites++;
      final dateStr = (raw['Date'] ?? raw['date']) as String? ?? '';
      final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

      final match = idRegex.firstMatch(link);
      final id = match != null ? match.group(1)! : link;

      videoMap[id] = TikTokArchiveItem(
        id: id,
        url: _usableVideoUrl(link, id),
        date: parsedDate,
        isFavorite: true,
        isLiked: false,
        collectionName: null,
      );

      final year = parsedDate.year;
      yearCounts[year] = (yearCounts[year] ?? 0) + 1;
    }

    // Process Likes (Merge with Favorites or mark as Liked Videos collection)
    for (final raw in likeList) {
      if (raw is! Map<String, dynamic>) continue;
      final link = (raw['link'] ?? raw['Link']) as String? ?? '';
      if (link.isEmpty) continue;

      totalLikes++;
      final dateStr = (raw['date'] ?? raw['Date']) as String? ?? '';
      final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

      final match = idRegex.firstMatch(link);
      final id = match != null ? match.group(1)! : link;

      final existing = videoMap[id];
      if (existing != null) {
        overlap++;
        videoMap[id] = existing.copyWith(
          isLiked: true,
          // If like has a newer date, preserve the most recent
          date: parsedDate.isAfter(existing.date) ? parsedDate : existing.date,
        );
      } else {
        videoMap[id] = TikTokArchiveItem(
          id: id,
          url: _usableVideoUrl(link, id),
          date: parsedDate,
          isFavorite: false,
          isLiked: true,
          collectionName: 'Vidéos Likées',
        );

        final year = parsedDate.year;
        yearCounts[year] = (yearCounts[year] ?? 0) + 1;
      }
    }

    // Sort videos by date descending (most recent first)
    final sortedVideos = videoMap.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Calculate actual video counts per collection
    final collectionCounts = <String, int>{};
    int unclassifiedCount = 0;
    for (final v in sortedVideos) {
      if (v.collectionName != null) {
        collectionCounts[v.collectionName!] =
            (collectionCounts[v.collectionName!] ?? 0) + 1;
      } else if (v.isFavorite) {
        unclassifiedCount++;
      }
    }

    // Build final collections list with real counts
    final List<TikTokCollectionItem> finalCollections = [];

    // All unmapped favorites go here until real browser sync
    if (unclassifiedCount > 0) {
      finalCollections.add(
        TikTokCollectionItem(
          name: 'Favoris non classés',
          videoCount: unclassifiedCount,
        ),
      );
    }

    for (final c in parsedColls) {
      finalCollections.add(
        c.copyWith(videoCount: collectionCounts[c.name] ?? 0),
      );
    }

    if ((collectionCounts['Vidéos Likées'] ?? 0) > 0) {
      finalCollections.add(
        TikTokCollectionItem(
          name: 'Vidéos Likées',
          videoCount: collectionCounts['Vidéos Likées']!,
        ),
      );
    }

    finalCollections.sort((a, b) {
      // Put 'Favoris non classés' at top if present
      if (a.name == 'Favoris non classés') return -1;
      if (b.name == 'Favoris non classés') return 1;
      if (a.videoCount != b.videoCount) {
        return b.videoCount.compareTo(a.videoCount);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    // Process Sounds
    final List<TikTokSoundItem> sounds = [];
    final musicTitleRegex = RegExp(r'/music/([^/?]+)');
    for (final raw in soundList) {
      if (raw is! Map<String, dynamic>) continue;
      final link = (raw['Link'] ?? raw['link']) as String? ?? '';
      if (link.isEmpty) continue;

      final dateStr = (raw['Date'] ?? raw['date']) as String? ?? '';
      final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

      String title = 'TikTok Sound';
      final titleMatch = musicTitleRegex.firstMatch(link);
      if (titleMatch != null) {
        final rawTitle = Uri.decodeComponent(titleMatch.group(1)!);
        title = rawTitle.replaceAll('-', ' ');
      }

      sounds.add(TikTokSoundItem(title: title, url: link, date: parsedDate));
    }
    sounds.sort((a, b) => b.date.compareTo(a.date));

    return TikTokArchiveCatalog(
      videos: sortedVideos,
      collections: finalCollections,
      sounds: sounds,
      totalFavorites: totalFavorites,
      totalLikes: totalLikes,
      totalOverlap: overlap,
      yearCounts: yearCounts,
    );
  }

  static String _usableVideoUrl(String original, String id) {
    if (RegExp(
      r'https?://(?:www\.)?tiktok\.com/@[^/]+/video/\d+',
    ).hasMatch(original)) {
      return original;
    }
    if (RegExp(r'^\d{8,}$').hasMatch(id)) {
      return 'https://www.tiktokv.com/share/video/$id/';
    }
    return original;
  }
}
