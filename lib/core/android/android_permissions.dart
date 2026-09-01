import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../logger/logger_service.dart';

class AndroidPermissions {
  AndroidPermissions._();

  static Future<void> ensure() async {
    if (!Platform.isAndroid) return;
    try {
      await Permission.notification.request();
    } catch (e) {
      LoggerService.w('Notification permission request failed: $e');
    }
    try {
      final photos = await Permission.videos.request();
      if (!photos.isGranted) {
        await Permission.storage.request();
      }
    } catch (e) {
      LoggerService.w('Storage permission request failed: $e');
    }
  }
}
