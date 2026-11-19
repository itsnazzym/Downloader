import 'dart:math' as math;

import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

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
