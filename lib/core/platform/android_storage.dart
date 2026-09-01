import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../logger/logger_service.dart';
import 'android_ytdlp_client.dart';
import 'platform_info.dart';

class AndroidStorage {
  const AndroidStorage._();

  static Future<String> defaultOutputFolder() async {
    try {
      final native = await AndroidYtDlpClient.instance.defaultOutputFolder();
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
    if (!PlatformInfo.isAndroid) return;
    try {
      await Permission.notification.request();
    } catch (error) {
      LoggerService.w('Notification permission request failed: $error');
    }
    try {
      final storage = await Permission.storage.status;
      if (storage.isDenied || storage.isRestricted) {
        await Permission.storage.request();
      }
    } catch (error) {
      LoggerService.w('Storage permission request failed: $error');
    }
  }
}
