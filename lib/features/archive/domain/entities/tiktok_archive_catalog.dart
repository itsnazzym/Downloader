import 'package:flutter/foundation.dart';
import '../../../../core/download/tiktok_video_url.dart';

/// Single TikTok video item inside the archive catalog.
@immutable
class TikTokArchiveItem {
  final String id;
  final String url;
  final DateTime date;
  final bool isFavorite;
  final bool isLiked;
  final List<String> collectionIds;
  final String? collectionName;
  final bool isDownloaded;

  String? get collectionId =>
      collectionIds.isEmpty ? null : collectionIds.first;

  TikTokArchiveItem({
    required this.id,
    required this.url,
    required this.date,
    this.isFavorite = false,
    this.isLiked = false,
    String? collectionId,
    List<String> collectionIds = const [],
    this.collectionName,
    this.isDownloaded = false,
  }) : collectionIds = collectionIds.isNotEmpty
           ? collectionIds
           : collectionId == null
           ? const []
           : [collectionId];

  TikTokArchiveItem copyWith({
    String? id,
    String? url,
    DateTime? date,
    bool? isFavorite,
    bool? isLiked,
    String? collectionId,
    List<String>? collectionIds,
    String? collectionName,
    bool clearCollection = false,
    bool? isDownloaded,
  }) {
    return TikTokArchiveItem(
      id: id ?? this.id,
      url: url ?? this.url,
      date: date ?? this.date,
      isFavorite: isFavorite ?? this.isFavorite,
      isLiked: isLiked ?? this.isLiked,
      collectionIds: clearCollection
          ? const []
          : collectionIds ??
                (collectionId != null ? [collectionId] : this.collectionIds),
      collectionName: clearCollection
          ? null
          : (collectionName ?? this.collectionName),
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'date': date.toIso8601String(),
    'isFavorite': isFavorite,
    'isLiked': isLiked,
    if (collectionIds.isNotEmpty) 'collectionIds': collectionIds,
    if (collectionName != null) 'collectionName': collectionName,
    'isDownloaded': isDownloaded,
  };

  factory TikTokArchiveItem.fromJson(Map<String, dynamic> json) {
    return TikTokArchiveItem(
      id: json['id'] as String? ?? '',
      url: TikTokVideoUrl.forDownload(json['url'] as String? ?? ''),
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      isFavorite: json['isFavorite'] as bool? ?? false,
      isLiked: json['isLiked'] as bool? ?? false,
      collectionId: json['collectionId'] as String?,
      collectionIds: (json['collectionIds'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      collectionName: json['collectionName'] as String?,
      isDownloaded: json['isDownloaded'] as bool? ?? false,
    );
  }
}

/// TikTok Collection metadata.
@immutable
class TikTokCollectionItem {
  final String? id;
  final String name;
  final String? coverUrl;
  final DateTime? date;
  final int videoCount;
  final int? declaredTotal;
  final int? heuristicCount;
  final bool? syncComplete;
  final String? syncError;

  const TikTokCollectionItem({
    this.id,
    required this.name,
    this.coverUrl,
    this.date,
    this.videoCount = 0,
    this.declaredTotal,
    this.heuristicCount,
    this.syncComplete,
    this.syncError,
  });

  TikTokCollectionItem copyWith({
    String? id,
    String? name,
    String? coverUrl,
    DateTime? date,
    int? videoCount,
    int? declaredTotal,
    int? heuristicCount,
    bool? syncComplete,
    String? syncError,
  }) {
    return TikTokCollectionItem(
      id: id ?? this.id,
      name: name ?? this.name,
      coverUrl: coverUrl ?? this.coverUrl,
      date: date ?? this.date,
      videoCount: videoCount ?? this.videoCount,
      declaredTotal: declaredTotal ?? this.declaredTotal,
      heuristicCount: heuristicCount ?? this.heuristicCount,
      syncComplete: syncComplete ?? this.syncComplete,
      syncError: syncError ?? this.syncError,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    if (coverUrl != null) 'coverUrl': coverUrl,
    if (date != null) 'date': date!.toIso8601String(),
    'videoCount': videoCount,
    if (declaredTotal != null) 'declaredTotal': declaredTotal,
    if (heuristicCount != null) 'heuristicCount': heuristicCount,
    if (syncComplete != null) 'syncComplete': syncComplete,
    if (syncError != null) 'syncError': syncError,
  };

  factory TikTokCollectionItem.fromJson(Map<String, dynamic> json) {
    return TikTokCollectionItem(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String)
          : null,
      videoCount: json['videoCount'] as int? ?? 0,
      declaredTotal: json['declaredTotal'] as int?,
      heuristicCount: json['heuristicCount'] as int?,
      syncComplete: json['syncComplete'] as bool?,
      syncError: json['syncError'] as String?,
    );
  }
}

/// A collection snapshot returned by the logged-in browser extension.
@immutable
class TikTokCollectionSnapshot {
  final String id;
  final String name;
  final String? coverUrl;
  final int? declaredTotal;
  final List<String> videoIds;
  final Map<String, String> videoUrls;
  final bool complete;
  final String? error;

  const TikTokCollectionSnapshot({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.videoIds,
    required this.complete,
    this.videoUrls = const {},
    this.declaredTotal,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (coverUrl != null) 'coverUrl': coverUrl,
    if (declaredTotal != null) 'declaredTotal': declaredTotal,
    'videoIds': videoIds,
    if (videoUrls.isNotEmpty) 'videoUrls': videoUrls,
    'complete': complete,
    if (error != null) 'error': error,
  };

  factory TikTokCollectionSnapshot.fromJson(Map<String, dynamic> json) {
    return TikTokCollectionSnapshot(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      declaredTotal: (json['declaredTotal'] as num?)?.toInt(),
      videoIds: (json['videoIds'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      videoUrls: (json['videoUrls'] as Map<dynamic, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      complete: json['complete'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }
}

/// A proposed collection assignment that needs the user's confirmation.
@immutable
class TikTokCollectionSuggestion {
  final String videoId;
  final String? collectionId;
  final String collectionName;
  final String reason;

  const TikTokCollectionSuggestion({
    required this.videoId,
    required this.collectionName,
    required this.reason,
    this.collectionId,
  });

  String get key => '$videoId::${collectionId ?? collectionName}';

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    if (collectionId != null) 'collectionId': collectionId,
    'collectionName': collectionName,
    'reason': reason,
  };

  factory TikTokCollectionSuggestion.fromJson(Map<String, dynamic> json) {
    return TikTokCollectionSuggestion(
      videoId: json['videoId'] as String? ?? '',
      collectionId: json['collectionId'] as String?,
      collectionName: json['collectionName'] as String? ?? '',
      reason: json['reason'] as String? ?? 'legacy_assignment',
    );
  }
}

/// TikTok Sound / Music metadata.
@immutable
class TikTokSoundItem {
  final String title;
  final String url;
  final DateTime date;

  const TikTokSoundItem({
    required this.title,
    required this.url,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'date': date.toIso8601String(),
  };

  factory TikTokSoundItem.fromJson(Map<String, dynamic> json) {
    return TikTokSoundItem(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Complete aggregated TikTok Archive Catalog.
@immutable
class TikTokArchiveCatalog {
  final List<TikTokArchiveItem> videos;
  final List<TikTokCollectionItem> collections;
  final List<TikTokCollectionSuggestion> suggestions;
  final List<TikTokSoundItem> sounds;
  final int totalFavorites;
  final int totalLikes;
  final int totalOverlap;
  final Map<int, int> yearCounts;

  const TikTokArchiveCatalog({
    required this.videos,
    required this.collections,
    required this.sounds,
    this.suggestions = const [],
    required this.totalFavorites,
    required this.totalLikes,
    required this.totalOverlap,
    required this.yearCounts,
  });

  int get totalUniqueVideos => videos.length;

  static const empty = TikTokArchiveCatalog(
    videos: [],
    collections: [],
    sounds: [],
    totalFavorites: 0,
    totalLikes: 0,
    totalOverlap: 0,
    yearCounts: {},
  );

  TikTokArchiveCatalog copyWith({
    List<TikTokArchiveItem>? videos,
    List<TikTokCollectionItem>? collections,
    List<TikTokCollectionSuggestion>? suggestions,
    List<TikTokSoundItem>? sounds,
    int? totalFavorites,
    int? totalLikes,
    int? totalOverlap,
    Map<int, int>? yearCounts,
  }) {
    return TikTokArchiveCatalog(
      videos: videos ?? this.videos,
      collections: collections ?? this.collections,
      suggestions: suggestions ?? this.suggestions,
      sounds: sounds ?? this.sounds,
      totalFavorites: totalFavorites ?? this.totalFavorites,
      totalLikes: totalLikes ?? this.totalLikes,
      totalOverlap: totalOverlap ?? this.totalOverlap,
      yearCounts: yearCounts ?? this.yearCounts,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 2,
    'videos': videos.map((v) => v.toJson()).toList(),
    'collections': collections.map((c) => c.toJson()).toList(),
    'suggestions': suggestions.map((s) => s.toJson()).toList(),
    'sounds': sounds.map((s) => s.toJson()).toList(),
    'totalFavorites': totalFavorites,
    'totalLikes': totalLikes,
    'totalOverlap': totalOverlap,
    'yearCounts': yearCounts.map((k, v) => MapEntry(k.toString(), v)),
  };

  factory TikTokArchiveCatalog.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as int? ?? 1;
    final rawYears = json['yearCounts'] as Map<String, dynamic>? ?? {};
    final parsedYears = <int, int>{};
    for (final entry in rawYears.entries) {
      final y = int.tryParse(entry.key);
      if (y != null && entry.value is int) {
        parsedYears[y] = entry.value as int;
      }
    }

    var parsedVideos = (json['videos'] as List<dynamic>? ?? [])
        .map((item) => TikTokArchiveItem.fromJson(item as Map<String, dynamic>))
        .toList();
    var parsedCollections = (json['collections'] as List<dynamic>? ?? [])
        .map(
          (item) => TikTokCollectionItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
    final suggestions = (json['suggestions'] as List<dynamic>? ?? [])
        .map(
          (item) =>
              TikTokCollectionSuggestion.fromJson(item as Map<String, dynamic>),
        )
        .toList();

    if (schemaVersion < 2) {
      final migratedVideos = <TikTokArchiveItem>[];
      for (final video in parsedVideos) {
        final name = video.collectionName;
        if (name != null &&
            name != 'Vidéos Likées' &&
            name != 'Favoris non classés') {
          suggestions.add(
            TikTokCollectionSuggestion(
              videoId: video.id,
              collectionId: video.collectionId,
              collectionName: name,
              reason: 'legacy_assignment',
            ),
          );
          migratedVideos.add(video.copyWith(clearCollection: true));
        } else {
          migratedVideos.add(video);
        }
      }
      parsedVideos = migratedVideos;

      final countsById = <String, int>{};
      final countsByName = <String, int>{};
      var unclassifiedFavorites = 0;
      var likedCount = 0;
      for (final video in parsedVideos) {
        if (video.collectionId != null) {
          countsById[video.collectionId!] =
              (countsById[video.collectionId!] ?? 0) + 1;
        } else if (video.collectionName == 'Vidéos Likées') {
          likedCount++;
        } else if (video.isFavorite) {
          unclassifiedFavorites++;
          if (video.collectionName != null) {
            countsByName[video.collectionName!] =
                (countsByName[video.collectionName!] ?? 0) + 1;
          }
        }
      }
      parsedCollections = parsedCollections.map((collection) {
        if (collection.name == 'Favoris non classés') {
          return collection.copyWith(videoCount: unclassifiedFavorites);
        }
        if (collection.name == 'Vidéos Likées') {
          return collection.copyWith(videoCount: likedCount);
        }
        return collection.copyWith(
          videoCount: collection.id == null
              ? (countsByName[collection.name] ?? 0)
              : (countsById[collection.id!] ?? 0),
        );
      }).toList();
      if (unclassifiedFavorites > 0 &&
          !parsedCollections.any(
            (collection) => collection.name == 'Favoris non classés',
          )) {
        parsedCollections.add(
          TikTokCollectionItem(
            name: 'Favoris non classés',
            videoCount: unclassifiedFavorites,
          ),
        );
      }
    }

    return TikTokArchiveCatalog(
      videos: parsedVideos,
      collections: parsedCollections,
      suggestions: suggestions,
      sounds: (json['sounds'] as List<dynamic>? ?? [])
          .map((item) => TikTokSoundItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalFavorites: json['totalFavorites'] as int? ?? 0,
      totalLikes: json['totalLikes'] as int? ?? 0,
      totalOverlap: json['totalOverlap'] as int? ?? 0,
      yearCounts: parsedYears,
    );
  }
}
