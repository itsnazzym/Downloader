import 'dart:math' as math;

import 'package:tapload/core/utils/format_utils.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/l10n/app_localizations.dart';

/// True while a download is being fetched or post-processed.
bool isActiveDownload(DownloadItem item) =>
    item.status == DownloadStatus.downloading ||
    item.status == DownloadStatus.extracting ||
    item.status == DownloadStatus.processing;

/// The active items of [catalog], each replaced by its live copy when there is
/// one. Progress ticks (percent, speed, ETA) only reach the per-download
/// runtime item; the catalog copy keeps the values from when the row last
/// changed status, so reading the catalog alone shows a frozen 0 %.
List<DownloadItem> liveActiveItems(
  Iterable<DownloadItem> catalog,
  DownloadItem? Function(String id) runtimeOf,
) {
  return [
    for (final item in catalog)
      if (isActiveDownload(item)) runtimeOf(item.id) ?? item,
  ];
}

/// Reads a speed into bytes per second. Accepts yt-dlp's own "6.2MiB/s" and
/// the "7.6 Mbps" form the download parser stores in `DownloadItem.speed`
/// (decimal megabits, converted from MiB/s). Returns null for anything else.
double? parseSpeed(String raw) {
  final bits = RegExp(
    r'([0-9]+(?:[.,][0-9]+)?)\s*([KMGT]?)bps',
    caseSensitive: false,
  ).firstMatch(raw);
  if (bits != null) {
    final number = double.tryParse(bits.group(1)!.replaceAll(',', '.'));
    if (number == null) return null;
    const exponents = <String, int>{'': 0, 'K': 1, 'M': 2, 'G': 3, 'T': 4};
    final exponent = exponents[bits.group(2)!.toUpperCase()] ?? 0;
    return number * math.pow(1000, exponent) / 8;
  }
  final match = RegExp(
    r'([0-9]+(?:[.,][0-9]+)?)\s*([KMGT]?)i?B\s*/\s*s',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return null;
  final number = double.tryParse(match.group(1)!.replaceAll(',', '.'));
  if (number == null) return null;
  const exponents = <String, int>{'': 0, 'K': 1, 'M': 2, 'G': 3, 'T': 4};
  final exponent = exponents[match.group(2)!.toUpperCase()] ?? 0;
  return number * math.pow(1024, exponent);
}

/// Sum of the parseable speeds, or null when none of the items has one.
double? aggregateSpeed(Iterable<DownloadItem> items) {
  var total = 0.0;
  var found = false;
  for (final item in items) {
    final speed = parseSpeed(item.speed);
    if (speed != null) {
      total += speed;
      found = true;
    }
  }
  return found ? total : null;
}

/// Reads a yt-dlp ETA ("08", "00:08", "1:02:03") as a duration.
Duration? parseEta(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final parts = text.split(':');
  if (parts.length > 3) return null;
  final numbers = <int>[];
  for (final part in parts) {
    final n = int.tryParse(part);
    if (n == null || n < 0) return null;
    numbers.add(n);
  }
  var seconds = 0;
  for (final n in numbers) {
    seconds = seconds * 60 + n;
  }
  return Duration(seconds: seconds);
}

/// "8 s", "1 min 12 s", "1 h 05 min": readable, in the user's language.
/// Falls back to the raw text when it cannot be read as a duration.
String etaLabel(AppLocalizations l10n, String raw) {
  final eta = parseEta(raw);
  if (eta == null) return raw;
  final total = eta.inSeconds;
  if (total >= 3600) {
    return l10n.etaHoursMinutes(total ~/ 3600, (total % 3600) ~/ 60);
  }
  if (total >= 60) {
    return l10n.etaMinutesSeconds(total ~/ 60, total % 60);
  }
  return l10n.etaSeconds(total);
}

/// A speed split into the number and its unit, ready for a big readout.
class SpeedLabel {
  const SpeedLabel(this.value, this.unit);

  final String value;
  final String unit;
}

/// "12,4" + "Mo/s": binary units like the rest of the app, localised unit and
/// decimal separator. "—" with no unit when there is no speed yet.
SpeedLabel formatSpeed(AppLocalizations l10n, double? bytesPerSecond) {
  if (bytesPerSecond == null) return const SpeedLabel('—', '');
  const k = 1024.0;
  final decimalSeparator = l10n.localeName.startsWith('en') ? '.' : ',';
  String fmt(double v) =>
      v.toStringAsFixed(v >= 100 ? 0 : 1).replaceAll('.', decimalSeparator);
  if (bytesPerSecond >= k * k * k) {
    return SpeedLabel(
      fmt(bytesPerSecond / (k * k * k)),
      l10n.libraryHeaderUnitGBps,
    );
  }
  if (bytesPerSecond >= k * k) {
    return SpeedLabel(
      fmt(bytesPerSecond / (k * k)),
      l10n.libraryHeaderUnitMBps,
    );
  }
  if (bytesPerSecond >= k) {
    return SpeedLabel(fmt(bytesPerSecond / k), l10n.libraryHeaderUnitKBps);
  }
  return SpeedLabel(
    bytesPerSecond.round().toString(),
    l10n.libraryHeaderUnitBps,
  );
}

/// What a download is doing before (or after) the bytes flow.
enum LivePhase { analyzing, connecting, finalizing }

/// The phase to show instead of a dash. Null once bytes are flowing.
LivePhase? livePhase(DownloadItem item, double? bytesPerSecond) {
  switch (item.status) {
    case DownloadStatus.extracting:
      return LivePhase.analyzing;
    case DownloadStatus.processing:
      return LivePhase.finalizing;
    case DownloadStatus.downloading:
      final started = item.progress > 0 || bytesPerSecond != null;
      return started ? null : LivePhase.connecting;
    case DownloadStatus.queued:
    case DownloadStatus.paused:
    case DownloadStatus.completed:
    case DownloadStatus.failed:
    case DownloadStatus.canceled:
    case DownloadStatus.duplicate:
      return null;
  }
}

String livePhaseLabel(AppLocalizations l10n, LivePhase phase) {
  switch (phase) {
    case LivePhase.analyzing:
      return l10n.libraryPhaseAnalyzing;
    case LivePhase.connecting:
      return l10n.libraryPhaseConnecting;
    case LivePhase.finalizing:
      return l10n.libraryPhaseFinalizing;
  }
}

/// What the panel shows for a few seconds once a download is done.
class CompletionSummary {
  const CompletionSummary({
    required this.id,
    required this.title,
    required this.sizeText,
    required this.duration,
    required this.bytesPerSecond,
  });

  final String id;
  final String title;
  final String sizeText;
  final Duration duration;

  /// Average speed over the transfer, or null when it was too short to mean
  /// anything.
  final double? bytesPerSecond;
}

/// Builds the summary of [done], which just completed. [firstBytesAt] is when
/// its first progress was seen, [now] when it finished.
CompletionSummary summarizeCompletion(
  DownloadItem done, {
  required DateTime firstBytesAt,
  required DateTime now,
  required String title,
}) {
  final elapsed = now.difference(firstBytesAt);
  final duration = elapsed.isNegative ? Duration.zero : elapsed;
  final size = done.totalSize.isNotEmpty ? done.totalSize : done.downloadedSize;
  final bytes = FormatUtils.parseBytes(size);
  final seconds = duration.inMilliseconds / 1000;
  // Under a second the average is noise (and a divide-by-almost-zero).
  final average = bytes > 0 && seconds >= 1 ? bytes / seconds : null;
  return CompletionSummary(
    id: done.id,
    title: title,
    sizeText: size,
    duration: duration,
    bytesPerSecond: average,
  );
}

/// "5 s", "1 min 12 s": how long a finished download took.
String durationLabel(AppLocalizations l10n, Duration duration) {
  final total = duration.inSeconds < 1 ? 1 : duration.inSeconds;
  if (total >= 3600) {
    return l10n.etaHoursMinutes(total ~/ 3600, (total % 3600) ~/ 60);
  }
  if (total >= 60) return l10n.etaMinutesSeconds(total ~/ 60, total % 60);
  return l10n.etaSeconds(total);
}
