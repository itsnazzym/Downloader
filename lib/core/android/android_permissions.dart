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
      final videos = await Permission.videos.request();
      if (!videos.isGranted) {
        await Permission.storage.request();
      }
      // On Android 11+ (API 30+), check manageExternalStorage for broad directory access
      if (await Permission.manageExternalStorage.isRestricted != true) {
        final manageStatus = await Permission.manageExternalStorage.status;
        if (!manageStatus.isGranted && !manageStatus.isPermanentlyDenied) {
          await Permission.manageExternalStorage.request();
        }
      }
    } catch (e) {
      LoggerService.w('Storage permission request failed: $e');
    }
  }
}
