import 'dart:io';

import 'package:flutter/services.dart';

import '../logger/logger_service.dart';

class AndroidPermissions {
  AndroidPermissions._();

  static const MethodChannel _channel = MethodChannel(
    'tapload/permissions',
  );

  static Future<void> ensure() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('ensureRuntimePermissions');
    } catch (e) {
      LoggerService.w('Android runtime permission request failed: $e');
    }
  }
}
