import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../logger/logger_service.dart';
import 'library_stats_builder.dart';
import '../../features/downloader/domain/entities/download_item.dart';

/// Tracks download statistics over time.
class DownloadStats {
  final int totalDownloads;
  final int totalBytesDownloaded;
  final int downloadsToday;
  final int bytesToday;
  final Map<String, int> downloadsBySource;
  final List<DailyStats> dailyHistory; // Last 30 days
  final DateTime lastUpdated;

  const DownloadStats({
    this.totalDownloads = 0,
    this.totalBytesDownloaded = 0,
    this.downloadsToday = 0,
    this.bytesToday = 0,
    this.downloadsBySource = const {},
    this.dailyHistory = const [],
    required this.lastUpdated,
  });

  DownloadStats copyWith({
    int? totalDownloads,
    int? totalBytesDownloaded,
    int? downloadsToday,
    int? bytesToday,
    Map<String, int>? downloadsBySource,
    List<DailyStats>? dailyHistory,
    DateTime? lastUpdated,
  }) {
    return DownloadStats(
      totalDownloads: totalDownloads ?? this.totalDownloads,
      totalBytesDownloaded: totalBytesDownloaded ?? this.totalBytesDownloaded,
      downloadsToday: downloadsToday ?? this.downloadsToday,
      bytesToday: bytesToday ?? this.bytesToday,
      downloadsBySource: downloadsBySource ?? this.downloadsBySource,
      dailyHistory: dailyHistory ?? this.dailyHistory,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() => {
    'totalDownloads': totalDownloads,
    'totalBytesDownloaded': totalBytesDownloaded,
    'downloadsToday': downloadsToday,
    'bytesToday': bytesToday,
    'downloadsBySource': downloadsBySource,
    'dailyHistory': dailyHistory.map((d) => d.toJson()).toList(),
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory DownloadStats.fromJson(Map<String, dynamic> json) {
    return DownloadStats(
      totalDownloads: json['totalDownloads'] as int? ?? 0,
      totalBytesDownloaded: json['totalBytesDownloaded'] as int? ?? 0,
      downloadsToday: json['downloadsToday'] as int? ?? 0,
      bytesToday: json['bytesToday'] as int? ?? 0,
      downloadsBySource:
          (json['downloadsBySource'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as int),
          ) ??
          {},
      dailyHistory:
          (json['dailyHistory'] as List<dynamic>?)
              ?.map((e) => DailyStats.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : DateTime.now(),
    );
  }
}

/// Stats for a single day.
class DailyStats {
  final String date; // YYYY-MM-DD
  final int downloads;
  final int bytes;

  const DailyStats({required this.date, this.downloads = 0, this.bytes = 0});

  Map<String, dynamic> toJson() => {
    'date': date,
    'downloads': downloads,
    'bytes': bytes,
  };

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      date: json['date'] as String,
      downloads: json['downloads'] as int? ?? 0,
      bytes: json['bytes'] as int? ?? 0,
    );
  }
}

const _kStatsKey = 'download_stats';

/// Manages download statistics with persistence.
class DownloadStatsNotifier extends StateNotifier<DownloadStats> {
  DownloadStatsNotifier() : super(DownloadStats(lastUpdated: DateTime.now())) {
    _load();
  }

  void _load() {
    try {
      final jsonStr = prefs.getString(_kStatsKey);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = DownloadStats.fromJson(data);
        _resetDailyIfNeeded();
      }
    } catch (e) {
      LoggerService.w('Failed to load download stats: $e');
    }
  }

  void _save() {
    try {
      final jsonStr = jsonEncode(state.toJson());
      prefs.setString(_kStatsKey, jsonStr);
    } catch (e) {
      LoggerService.w('Failed to save download stats: $e');
    }
  }

  void _resetDailyIfNeeded() {
    final today = _todayString();
    final lastDate = state.lastUpdated.toIso8601String().substring(0, 10);
    if (lastDate != today) {
      state = state.copyWith(
        downloadsToday: 0,
        bytesToday: 0,
        lastUpdated: DateTime.now(),
      );
      _save();
    }
  }

  /// Record a completed download.
  void recordDownload({required String source, int bytesDownloaded = 0}) {
    _resetDailyIfNeeded();

    final updatedSources = Map<String, int>.from(state.downloadsBySource);
    updatedSources[source] = (updatedSources[source] ?? 0) + 1;

    // Update daily history
    final today = _todayString();
    final history = List<DailyStats>.from(state.dailyHistory);
    final todayIndex = history.indexWhere((d) => d.date == today);

    if (todayIndex >= 0) {
      final existing = history[todayIndex];
      history[todayIndex] = DailyStats(
        date: today,
        downloads: existing.downloads + 1,
        bytes: existing.bytes + bytesDownloaded,
      );
    } else {
      history.add(
        DailyStats(date: today, downloads: 1, bytes: bytesDownloaded),
      );
    }

    // Keep only last 30 days
    while (history.length > 30) {
      history.removeAt(0);
    }

    state = state.copyWith(
      totalDownloads: state.totalDownloads + 1,
      totalBytesDownloaded: state.totalBytesDownloaded + bytesDownloaded,
      downloadsToday: state.downloadsToday + 1,
      bytesToday: state.bytesToday + bytesDownloaded,
      downloadsBySource: updatedSources,
      dailyHistory: history,
      lastUpdated: DateTime.now(),
    );

    _save();
  }

  /// Replace incremental event counts with a snapshot of the real library.
  void rebuildFromLibrary(List<DownloadItem> items) {
    state = LibraryStatsBuilder.fromItems(items);
    _save();
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

/// Global stats provider.
final downloadStatsProvider =
    StateNotifierProvider<DownloadStatsNotifier, DownloadStats>((ref) {
      return DownloadStatsNotifier();
    });
