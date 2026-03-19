import 'dart:math';

/// Shared formatting utilities used across the app.
class FormatUtils {
  const FormatUtils._();

  /// Formats bytes into a human-readable string (e.g., "1.5 GB").
  static String formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Formats a Duration into a compact display (e.g., "2h 15m" or "45s").
  static String formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }

  /// Formats a large number with K/M suffixes (e.g., 1500 → "1.5K").
  static String formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  /// Parses human-readable byte strings like "12.4MiB", "1.5 GB" or "950 KB".
  static int parseBytes(String value) {
    final normalized = value.trim().replaceAll('~', '');
    if (normalized.isEmpty) {
      return 0;
    }

    final match = RegExp(
      r'^([\d]+(?:[.,]\d+)?)\s*([KMGT]?i?B)?$',
      caseSensitive: false,
    ).firstMatch(normalized);

    if (match == null) {
      return 0;
    }

    final amount = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (amount == null) {
      return 0;
    }

    final unit = (match.group(2) ?? 'B').toUpperCase();
    const factors = <String, int>{
      'B': 1,
      'KB': 1000,
      'MB': 1000 * 1000,
      'GB': 1000 * 1000 * 1000,
      'TB': 1000 * 1000 * 1000 * 1000,
      'KIB': 1024,
      'MIB': 1024 * 1024,
      'GIB': 1024 * 1024 * 1024,
      'TIB': 1024 * 1024 * 1024 * 1024,
    };

    final factor = factors[unit];
    if (factor == null) {
      return 0;
    }

    return (amount * factor).round();
  }
}
