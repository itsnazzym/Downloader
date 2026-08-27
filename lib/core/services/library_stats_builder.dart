import 'dart:io';

import 'package:modern_downloader/core/download/media_source_resolver.dart';
import 'package:modern_downloader/core/services/download_stats_service.dart';
import 'package:modern_downloader/core/utils/format_utils.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

/// Builds [DownloadStats] from the current library — unique files, real sizes,
/// known platforms only (never "Local").
class LibraryStatsBuilder {
  const LibraryStatsBuilder._();

  static DownloadStats fromItems(
    List<DownloadItem> items, {
    DateTime? now,
    int Function(String path)? fileLengthBytes,
    DateTime Function(String path)? fileModified,
  }) {
    final clock = now ?? DateTime.now();
    final seen = <String>{};
    var totalDownloads = 0;
    var totalBytes = 0;
    var downloadsToday = 0;
    var bytesToday = 0;
    final sources = <String, int>{};
    final byDay = <String, DailyStats>{
      for (var i = 6; i >= 0; i--)
        _dayKey(clock.subtract(Duration(days: i))): DailyStats(
          date: _dayKey(clock.subtract(Duration(days: i))),
        ),
    };

    for (final item in items) {
      if (item.status != DownloadStatus.completed) continue;
      final path = item.filePath;
      final key = (path != null && path.isNotEmpty)
          ? path.toLowerCase()
          : item.id;
      if (!seen.add(key)) continue;

      totalDownloads++;
      final bytes = _bytesFor(item, fileLengthBytes);
      totalBytes += bytes;

      final source = MediaSourceResolver.resolve(
        url: item.request.url,
        filePath: path,
      );
      if (source != null) {
        sources[source] = (sources[source] ?? 0) + 1;
      }

      final modified = _modifiedFor(path, fileModified) ?? clock;
      final day = _dayKey(modified);
      final existing = byDay[day];
      if (existing != null) {
        byDay[day] = DailyStats(
          date: day,
          downloads: existing.downloads + 1,
          bytes: existing.bytes + bytes,
        );
      }
      if (day == _dayKey(clock)) {
        downloadsToday++;
        bytesToday += bytes;
      }
    }

    final history = byDay.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return DownloadStats(
      totalDownloads: totalDownloads,
      totalBytesDownloaded: totalBytes,
      downloadsToday: downloadsToday,
      bytesToday: bytesToday,
      downloadsBySource: sources,
      dailyHistory: history,
      lastUpdated: clock,
    );
  }

  static int _bytesFor(
    DownloadItem item,
    int Function(String path)? fileLengthBytes,
  ) {
    final path = item.filePath;
    if (path != null && path.isNotEmpty) {
      try {
        if (fileLengthBytes != null) {
          final n = fileLengthBytes(path);
          if (n > 0) return n;
        } else {
          final file = File(path);
          if (file.existsSync()) {
            final n = file.lengthSync();
            if (n > 0) return n;
          }
        }
      } catch (_) {}
    }
    final parsed = FormatUtils.parseBytes(item.totalSize);
    if (parsed > 0) return parsed;
    return FormatUtils.parseBytes(item.downloadedSize);
  }

  static DateTime? _modifiedFor(
    String? path,
    DateTime Function(String path)? fileModified,
  ) {
    if (path == null || path.isEmpty) return null;
    try {
      if (fileModified != null) return fileModified(path);
      final file = File(path);
      if (file.existsSync()) return file.lastModifiedSync();
    } catch (_) {}
    return null;
  }

  static String _dayKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
