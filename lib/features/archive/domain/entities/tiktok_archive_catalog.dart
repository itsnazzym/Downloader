import 'package:flutter/foundation.dart';

/// Single TikTok video item inside the archive catalog.
@immutable
class TikTokArchiveItem {
  final String id;
  final String url;
  final DateTime date;
  final bool isFavorite;
  final bool isLiked;
  final String? collectionName;
  final bool isDownloaded;

  const TikTokArchiveItem({
    required this.id,
    required this.url,
    required this.date,
    this.isFavorite = false,
    this.isLiked = false,
    this.collectionName,
    this.isDownloaded = false,
  });

  TikTokArchiveItem copyWith({
    String? id,
    String? url,
    DateTime? date,
    bool? isFavorite,
    bool? isLiked,
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
      collectionName: clearCollection ? null : (collectionName ?? this.collectionName),
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'date': date.toIso8601String(),
    'isFavorite': isFavorite,
    'isLiked': isLiked,
    if (collectionName != null) 'collectionName': collectionName,
    'isDownloaded': isDownloaded,
  };

  factory TikTokArchiveItem.fromJson(Map<String, dynamic> json) {
    return TikTokArchiveItem(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      isFavorite: json['isFavorite'] as bool? ?? false,
      isLiked: json['isLiked'] as bool? ?? false,
      collectionName: json['collectionName'] as String?,
      isDownloaded: json['isDownloaded'] as bool? ?? false,
    );
  }
}

/// TikTok Collection metadata.
@immutable
class TikTokCollectionItem {
  final String name;
  final DateTime? date;
  final int videoCount;
  final int? declaredTotal;
  final int? heuristicCount;

  const TikTokCollectionItem({
    required this.name,
    this.date,
    this.videoCount = 0,
    this.declaredTotal,
    this.heuristicCount,
  });

  TikTokCollectionItem copyWith({
    String? name,
    DateTime? date,
    int? videoCount,
    int? declaredTotal,
    int? heuristicCount,
  }) {
    return TikTokCollectionItem(
      name: name ?? this.name,
      date: date ?? this.date,
      videoCount: videoCount ?? this.videoCount,
      declaredTotal: declaredTotal ?? this.declaredTotal,
      heuristicCount: heuristicCount ?? this.heuristicCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (date != null) 'date': date!.toIso8601String(),
    'videoCount': videoCount,
    if (declaredTotal != null) 'declaredTotal': declaredTotal,
    if (heuristicCount != null) 'heuristicCount': heuristicCount,
  };

  factory TikTokCollectionItem.fromJson(Map<String, dynamic> json) {
    return TikTokCollectionItem(
      name: json['name'] as String? ?? '',
      date: json['date'] != null ? DateTime.tryParse(json['date'] as String) : null,
      videoCount: json['videoCount'] as int? ?? 0,
      declaredTotal: json['declaredTotal'] as int?,
      heuristicCount: json['heuristicCount'] as int?,
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
  final List<TikTokSoundItem> sounds;
  final int totalFavorites;
  final int totalLikes;
  final int totalOverlap;
  final Map<int, int> yearCounts;

  const TikTokArchiveCatalog({
    required this.videos,
    required this.collections,
    required this.sounds,
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

  Map<String, dynamic> toJson() => {
    'videos': videos.map((v) => v.toJson()).toList(),
    'collections': collections.map((c) => c.toJson()).toList(),
    'sounds': sounds.map((s) => s.toJson()).toList(),
    'totalFavorites': totalFavorites,
    'totalLikes': totalLikes,
    'totalOverlap': totalOverlap,
    'yearCounts': yearCounts.map((k, v) => MapEntry(k.toString(), v)),
  };

  factory TikTokArchiveCatalog.fromJson(Map<String, dynamic> json) {
    final rawYears = json['yearCounts'] as Map<String, dynamic>? ?? {};
    final parsedYears = <int, int>{};
    for (final entry in rawYears.entries) {
      final y = int.tryParse(entry.key);
      if (y != null && entry.value is int) {
        parsedYears[y] = entry.value as int;
      }
    }

    return TikTokArchiveCatalog(
      videos: (json['videos'] as List<dynamic>? ?? [])
          .map((item) => TikTokArchiveItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      collections: (json['collections'] as List<dynamic>? ?? [])
          .map((item) => TikTokCollectionItem.fromJson(item as Map<String, dynamic>))
          .toList(),
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
