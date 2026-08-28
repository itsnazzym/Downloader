import 'dart:io';
import '../logger/logger_service.dart';
import '../utils/format_utils.dart';

/// Service to check available disk space.
class DiskSpaceService {
  const DiskSpaceService._();

  /// Minimum required disk space in bytes (2 GB).
  static const int minRequiredBytes = 2 * 1024 * 1024 * 1024;

  static const Duration cacheTtl = Duration(seconds: 30);

  static int? _cachedBytes;
  static DateTime? _cachedAt;
  static Future<int?>? _inFlight;

  /// Test hook to clear the ~30s cache.
  static void resetCache() {
    _cachedBytes = null;
    _cachedAt = null;
    _inFlight = null;
  }

  /// Returns the free disk space in bytes for the system drive, or null if unavailable.
  static Future<int?> getFreeDiskSpace() async {
    if (!Platform.isWindows) return null;
    final now = DateTime.now();
    final cachedAt = _cachedAt;
    if (_cachedBytes != null &&
        cachedAt != null &&
        now.difference(cachedAt) < cacheTtl) {
      return _cachedBytes;
    }
    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _probeFreeDiskSpace();
    _inFlight = future;
    try {
      final bytes = await future;
      _cachedBytes = bytes;
      _cachedAt = DateTime.now();
      return bytes;
    } finally {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }
  }

  static Future<int?> _probeFreeDiskSpace() async {
    try {
      final userProfile = Platform.environment['USERPROFILE'] ?? 'C:';
      final drive = userProfile.split(':')[0];
      final result = await Process.run('powershell', [
        '-Command',
        'Get-Volume -DriveLetter $drive | Select-Object -ExpandProperty SizeRemaining',
      ]);
      if (result.exitCode == 0) {
        return int.tryParse(result.stdout.toString().trim());
      }
    } catch (e) {
      LoggerService.w('Failed to check disk space: $e');
    }
    return null;
  }

  /// Checks that at least [minRequiredBytes] of disk space is available.
  /// Throws an [Exception] if disk space is critically low.
  static Future<void> checkDiskSpace() async {
    final bytes = await getFreeDiskSpace();
    if (bytes != null) {
      if (bytes < minRequiredBytes) {
        throw Exception(
          'Low Disk Space: ${FormatUtils.formatBytes(bytes)} free. Min 2GB required.',
        );
      }
      LoggerService.i(
        'Disk Space Check: ${FormatUtils.formatBytes(bytes)} free (OK)',
      );
    }
  }
}
