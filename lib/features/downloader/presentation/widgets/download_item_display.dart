import 'package:flutter/material.dart';
import 'package:modern_downloader/core/download/download_file_resolver.dart';
import 'package:modern_downloader/core/download/extraction_placeholders.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

/// Shared labels and status helpers for list / grid / inspector cards.
class DownloadItemDisplay {
  DownloadItemDisplay._();

  static String title(BuildContext context, DownloadItem item) {
    final l10n = context.l10n;
    if (item.status == DownloadStatus.extracting &&
        ExtractionPlaceholders.isGenericTitle(item.title)) {
      return l10n.extractingTitle;
    }
    if (item.title == null || item.title!.trim().isEmpty) {
      return l10n.unknownTitle;
    }
    return item.title!;
  }

  static String source(BuildContext context, DownloadItem item) {
    if (ExtractionPlaceholders.showExtractingSource(
      status: item.status,
      source: item.source,
    )) {
      return context.l10n.extractingSource;
    }
    return item.source;
  }

  static String size(BuildContext context, DownloadItem item) {
    if (ExtractionPlaceholders.showExtractingSize(
      status: item.status,
      totalSize: item.totalSize,
    )) {
      return context.l10n.extractingSize;
    }
    return DownloadFileResolver.displaySize(
      storedTotalSize: item.totalSize,
      filePath: item.filePath,
      unknownLabel: context.l10n.unknownSize,
    );
  }

  static bool isActive(DownloadItem item) {
    return item.status == DownloadStatus.queued ||
        item.status == DownloadStatus.extracting ||
        item.status == DownloadStatus.downloading;
  }

  static bool showSpeed(DownloadItem item) {
    if (item.speed.isEmpty) return false;
    if (item.speed.toLowerCase().contains('retry')) return false;
    return item.status == DownloadStatus.downloading ||
        item.status == DownloadStatus.extracting ||
        item.status == DownloadStatus.processing;
  }

  static bool isTerminal(DownloadItem item) {
    return item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.canceled ||
        item.status == DownloadStatus.completed;
  }
}
