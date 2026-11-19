import 'dart:async';
import 'dart:io';
import 'package:universal_disk_space/universal_disk_space.dart';
import '../android/android_engine_bridge.dart';
import '../logger/logger_service.dart';
import '../utils/format_utils.dart';

/// Service to check available disk space using native Win32 APIs.
class DiskSpaceService {
  const DiskSpaceService._();

  /// Minimum required disk space in bytes (500 MB).
  static const int minRequiredBytes = 500 * 1024 * 1024;

  static const Duration cacheTtl = Duration(seconds: 30);

  static final Map<String, int> _cachedBytes = {};
  static final Map<String, DateTime> _cachedAt = {};
  static final Map<String, Future<int?>> _inFlight = {};

  /// Test hook to clear the ~30s cache.
  static void resetCache() {
    _cachedBytes.clear();
    _cachedAt.clear();
    _inFlight.clear();
  }

  /// Returns the free disk space in bytes for the target drive [path], or null if unavailable.
  static Future<int?> getFreeDiskSpace([String? targetPath]) async {
    final path = targetPath ??
        (Platform.isWindows
            ? (Platform.environment['USERPROFILE'] ?? 'C:\\')
            : (Platform.environment['HOME'] ?? '/'));
    final rootKey = _extractDriveKey(path);

    final now = DateTime.now();
    final cachedTime = _cachedAt[rootKey];
    final cachedVal = _cachedBytes[rootKey];
    if (cachedVal != null &&
        cachedTime != null &&
        now.difference(cachedTime) < cacheTtl) {
      return cachedVal;
    }

    if (_inFlight.containsKey(rootKey)) {
      return _inFlight[rootKey];
    }

    final future = _probeFreeDiskSpace(path);
    _inFlight[rootKey] = future;
    try {
      final bytes = await future;
      if (bytes != null) {
        _cachedBytes[rootKey] = bytes;
        _cachedAt[rootKey] = DateTime.now();
      }
      return bytes;
    } finally {
      unawaited(_inFlight.remove(rootKey));
    }
  }

  static String _extractDriveKey(String path) {
    if (Platform.isWindows) {
      final normalized = path.replaceAll('/', '\\');
      final match = RegExp(
        r'^([a-zA-Z]:)',
        caseSensitive: false,
      ).firstMatch(normalized);
      return match != null ? match.group(1)!.toUpperCase() : 'C:';
    }

    if (path.startsWith('/storage')) {
      final segments =
          path.split('/').where((s) => s.isNotEmpty).take(3).toList();
      return '/${segments.join('/')}';
    }
    if (path.startsWith('/Volumes')) {
      final segments =
          path.split('/').where((s) => s.isNotEmpty).take(2).toList();
      return '/${segments.join('/')}';
    }
    return '/';
  }

  static Future<int?> _probeFreeDiskSpace(String path) async {
    if (Platform.isAndroid) {
      return (await AndroidEngineBridge.instance.diskSpace())?.free;
    }
    try {
      final diskSpace = DiskSpace();
      await diskSpace.scan();
      final disks = diskSpace.disks;
      if (disks.isEmpty) return null;

      final normalized = Platform.isWindows
          ? path.replaceAll('/', '\\').toUpperCase()
          : path;

      Disk? targetDisk;
      for (final disk in disks) {
        final devicePath = Platform.isWindows
            ? disk.devicePath.toUpperCase()
            : disk.devicePath;
        if (normalized.startsWith(devicePath) ||
            normalized.startsWith(disk.mountPath)) {
          targetDisk = disk;
          break;
        }
      }
      targetDisk ??= disks.first;
      return targetDisk.availableSpace;
    } catch (e) {
      LoggerService.w('Failed to check disk space via native API: $e');
    }
    return null;
  }

  /// Checks that at least [minRequiredBytes] of disk space is available for [targetPath].
  /// Throws an [Exception] if disk space is critically low.
  static Future<void> checkDiskSpace([String? targetPath]) async {
    final bytes = await getFreeDiskSpace(targetPath);
    if (bytes != null) {
      if (bytes < minRequiredBytes) {
        throw Exception(
          'Espace disque faible (${FormatUtils.formatBytes(bytes)} libres). Minimum 500 Mo requis.',
        );
      }
      LoggerService.debug(
        'Disk Space Check for ${targetPath ?? 'root'}: ${FormatUtils.formatBytes(bytes)} free (OK)',
      );
    }
  }
}
