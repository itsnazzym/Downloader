import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:modern_downloader/core/download/x_download_url.dart';
import 'package:modern_downloader/core/download/x_library_title_repair.dart';
import 'package:modern_downloader/core/download/x_tweet_display_title.dart';
import 'package:modern_downloader/core/logger/logger_service.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

typedef XLibraryTitleMetadataFetcher =
    Future<Map<String, dynamic>?> Function(
      String permalink, {
      String? cookiesFilePath,
      String? rawCookies,
    });

/// Repairs opaque X/Twitter library titles from sidecar JSON or yt-dlp metadata.
class XLibraryTitleRepairService {
  XLibraryTitleRepairService({required this.fetchMetadata});

  final XLibraryTitleMetadataFetcher fetchMetadata;

  Future<List<DownloadItem>> repairItems(
    List<DownloadItem> items, {
    int maxConcurrent = 3,
    Duration timeout = const Duration(seconds: 25),
    bool Function()? shouldAbort,
    void Function(DownloadItem item)? onItemRepaired,
  }) async {
    final candidates = items.where(_canAttemptRepair).take(25).toList();
    if (candidates.isEmpty) return const [];

    final repaired = <DownloadItem>[];
    var next = 0;
    final workerCount = maxConcurrent.clamp(1, candidates.length);

    Future<void> worker() async {
      while (true) {
        if (shouldAbort?.call() == true) return;
        if (next >= candidates.length) return;
        final item = candidates[next];
        next += 1;
        try {
          final result = await repairItem(item).timeout(timeout);
          if (result != null) {
            repaired.add(result);
            onItemRepaired?.call(result);
          }
        } catch (e) {
          LoggerService.w('X title repair skipped for ${item.id}: $e');
        }
      }
    }

    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
    return repaired;
  }

  Future<DownloadItem?> repairItem(DownloadItem item) async {
    if (!_canAttemptRepair(item)) return null;

    final sidecar = _readSidecar(item.filePath);
    final tweetId =
        XLibraryTitleRepair.tweetIdFromItem(item) ??
        _tweetIdFromMetadata(sidecar);
    if (tweetId == null) return null;

    late final Map<String, dynamic> metadata;
    late final String title;
    final sidecarTitle = sidecar == null
        ? null
        : XTweetDisplayTitle.fromMetadata(sidecar, tweetId: tweetId);
    if (sidecar != null &&
        sidecarTitle != null &&
        !XLibraryTitleRepair.titleNeedsRepair(sidecarTitle) &&
        XTweetDisplayTitle.hasUsableTweetText(sidecar, tweetId: tweetId)) {
      metadata = sidecar;
      title = sidecarTitle;
    } else {
      final permalink = XDownloadUrl.permalinkForTweetId(tweetId);
      try {
        final fetchedMetadata = await fetchMetadata(
          permalink,
          cookiesFilePath: item.request.cookiesFilePath,
          rawCookies: item.request.rawCookies,
        );
        if (fetchedMetadata == null) return null;
        metadata = fetchedMetadata;
      } catch (e) {
        LoggerService.w('X title repair fetch failed for $tweetId: $e');
        return null;
      }
      title = XTweetDisplayTitle.fromMetadata(metadata, tweetId: tweetId);
    }

    if (title.isEmpty) return null;
    if (XLibraryTitleRepair.titleNeedsRepair(title) &&
        title == (item.title ?? '').trim()) {
      return null;
    }

    final permalink = XDownloadUrl.permalinkForTweetId(tweetId);
    String? newPath = item.filePath;
    if (item.filePath != null && item.filePath!.trim().isNotEmpty) {
      final renamed = await XLibraryTitleRepair.renameVideoFile(
        currentPath: item.filePath!,
        title: title,
        tweetId: tweetId,
      );
      if (renamed != null) {
        newPath = renamed;
      }
    }

    final thumbnail = _asString(metadata['thumbnail']);
    return item.copyWith(
      title: title,
      filePath: newPath,
      request: item.request.copyWith(url: permalink),
      thumbnailUrl: thumbnail,
    );
  }

  Map<String, dynamic>? _readSidecar(String? videoPath) {
    if (videoPath == null || videoPath.trim().isEmpty) return null;
    try {
      final file = File(videoPath);
      final dir = file.parent;
      final base = p.basenameWithoutExtension(videoPath);
      final candidates = <String>[
        p.join(dir.path, '$base.info.json'),
        p.join(dir.path, '${p.basename(videoPath)}.info.json'),
      ];
      for (final candidate in candidates) {
        final sidecar = File(candidate);
        if (!sidecar.existsSync()) continue;
        final decoded = jsonDecode(sidecar.readAsStringSync());
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      }
    } catch (e) {
      LoggerService.w('Could not read X info.json sidecar: $e');
    }
    return null;
  }

  String? _tweetIdFromMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    return XDownloadUrl.tweetIdFrom(_asString(metadata['webpage_url'])) ??
        XDownloadUrl.tweetIdFrom(_asString(metadata['original_url']));
  }

  String? _asString(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) return value.toString();
    return null;
  }

  bool _canAttemptRepair(DownloadItem item) {
    if (XLibraryTitleRepair.needsRepair(item)) return true;
    if (item.status == DownloadStatus.extracting ||
        item.status == DownloadStatus.downloading ||
        item.status == DownloadStatus.processing) {
      return false;
    }
    if (!XLibraryTitleRepair.isTwitterFamily(item) ||
        !XLibraryTitleRepair.titleNeedsRepair(item.title)) {
      return false;
    }
    return _readSidecar(item.filePath) != null;
  }
}
