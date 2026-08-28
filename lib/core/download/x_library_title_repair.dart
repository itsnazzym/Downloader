import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:modern_downloader/core/download/extraction_placeholders.dart';
import 'package:modern_downloader/core/download/media_source_resolver.dart';
import 'package:modern_downloader/core/download/x_download_url.dart';
import 'package:modern_downloader/core/logger/logger_service.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

/// Detects X/Twitter library rows whose titles came from CDN media keys.
class XLibraryTitleRepair {
  XLibraryTitleRepair._();

  static final RegExp _titleCaseWord = RegExp(r'^[A-Z][a-z]{2,}$');
  static final RegExp _tweetFallback = RegExp(
    r'^(Tweet \d{15,20}|.+ - \d{15,20})$',
  );
  static final RegExp _alnum = RegExp(r'^[A-Za-z0-9]+$');

  static bool isTwitterFamily(DownloadItem item) {
    final url = item.request.url;
    if (XDownloadUrl.isXFamilyUrl(url)) return true;
    final forceStream = item.request.forceStreamUrl;
    if (forceStream != null && XDownloadUrl.isXFamilyUrl(forceStream)) {
      return true;
    }
    final label = MediaSourceResolver.resolve(
      url: url,
      filePath: item.filePath,
    );
    return label == 'Twitter';
  }

  static bool looksLikeOpaqueMediaKeyTitle(String? title) {
    if (title == null) return false;
    final trimmed = title.trim();
    if (trimmed.isEmpty) return false;
    if (_tweetFallback.hasMatch(trimmed)) return false;

    final tokens = trimmed.split(RegExp(r'\s+'));
    if (tokens.length > 2) return false;
    for (final token in tokens) {
      if (!_alnum.hasMatch(token)) return false;
    }

    final collapsed = trimmed.replaceAll(RegExp(r'[\s_\-]'), '');
    if (collapsed.length < 10 || collapsed.length > 24) return false;
    if (!_alnum.hasMatch(collapsed)) return false;
    if (!RegExp(r'[A-Za-z]').hasMatch(collapsed)) return false;

    final titleCaseWords = tokens.every(_titleCaseWord.hasMatch);
    final hasDigit = RegExp(r'\d').hasMatch(collapsed);
    if (titleCaseWords && !hasDigit) return false;

    return hasDigit ||
        (RegExp(r'[a-z]').hasMatch(collapsed) &&
            RegExp(r'[A-Z]').hasMatch(collapsed));
  }

  static bool titleNeedsRepair(String? title) {
    if (title == null || title.trim().isEmpty) return true;
    if (_tweetFallback.hasMatch(title.trim())) return false;
    if (ExtractionPlaceholders.isGenericTitle(title)) return true;
    if (TitleCleanerService.isUrlOnlyTitle(title)) return true;
    return looksLikeOpaqueMediaKeyTitle(title);
  }

  static String? tweetIdFromItem(DownloadItem item) {
    return XDownloadUrl.tweetIdFrom(item.request.url) ??
        XDownloadUrl.tweetIdFrom(item.request.forceStreamUrl);
  }

  static bool needsRepair(DownloadItem item) {
    if (_isBusy(item.status)) return false;
    if (!isTwitterFamily(item)) return false;
    if (!titleNeedsRepair(item.title)) return false;
    return tweetIdFromItem(item) != null;
  }

  static Future<String?> renameVideoFile({
    required String currentPath,
    required String title,
    required String tweetId,
  }) async {
    try {
      final file = File(currentPath);
      if (!await file.exists()) return null;

      final ext = p.extension(currentPath);
      if (ext.isEmpty) return null;

      final stem = TitleCleanerService.filenameStem(title);
      if (stem.isEmpty) return null;

      final cleanId = tweetId.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
      if (cleanId.isEmpty) return null;

      final dest = p.join(file.parent.path, '$stem [$cleanId]$ext');
      if (p.equals(currentPath, dest)) return currentPath;

      if (await File(dest).exists()) return null;

      await file.rename(dest);
      return dest;
    } catch (e) {
      LoggerService.w('Could not rename repaired X video: $e');
      return null;
    }
  }

  static bool _isBusy(DownloadStatus status) {
    return status == DownloadStatus.extracting ||
        status == DownloadStatus.downloading ||
        status == DownloadStatus.processing;
  }
}
