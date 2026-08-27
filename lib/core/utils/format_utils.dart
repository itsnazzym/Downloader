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

  /// Parses a human-readable size ("12.3 MB", "10.00MiB") back to bytes.
  static int parseBytes(String input) {
    final match = RegExp(
      r'([\d.,]+)\s*([KMGT]I?B|B)\b',
      caseSensitive: false,
    ).firstMatch(input.trim());
    if (match == null) return 0;
    final n = double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 0;
    if (n <= 0) return 0;
    final unit = match.group(2)!.toUpperCase().replaceAll('I', '');
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = suffixes.indexOf(unit);
    if (i <= 0) return n.round();
    return (n * pow(1024, i)).round();
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
}
