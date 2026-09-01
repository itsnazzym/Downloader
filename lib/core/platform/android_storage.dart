import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../android/android_engine_bridge.dart';
import '../android/android_permissions.dart';
import '../logger/logger_service.dart';
import 'platform_info.dart';

/// Android-only storage helpers (output folder + runtime permissions).
class AndroidStorage {
  const AndroidStorage._();

  static Future<String> defaultOutputFolder() async {
    if (!PlatformInfo.isAndroid) {
      throw StateError('AndroidStorage.defaultOutputFolder is Android-only');
    }

    try {
      final native = await AndroidEngineBridge.instance.defaultOutputDir();
      if (native != null && native.trim().isNotEmpty) {
        return native;
      }
    } catch (error) {
      LoggerService.w('Native Android output folder failed: $error');
    }

    try {
      final external = await getExternalStorageDirectory();
      final base = external?.path ?? Directory.systemTemp.path;
      final dest = Directory('$base/ModernDownloader');
      if (!await dest.exists()) {
        await dest.create(recursive: true);
      }
      return dest.path;
    } catch (error) {
      LoggerService.w('Fallback Android output folder failed: $error');
      return Directory.systemTemp.path;
    }
  }

  static Future<void> requestPermissions() async {
    await AndroidPermissions.ensure();
  }
}
