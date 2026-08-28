import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class LoggerService {
  static void i(String message, [String? name]) {
    if (!kReleaseMode) {
      // ignore: avoid_print
      print('ℹ️ [${name ?? 'INFO'}] $message');
    }
    developer.log(message, name: name ?? 'INFO', level: 800);
  }

  static void w(String message, [String? name]) {
    if (!kReleaseMode) {
      // ignore: avoid_print
      print('⚠️ [${name ?? 'WARN'}] $message');
    }
    developer.log(message, name: name ?? 'WARN', level: 900);
  }

  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    if (!kReleaseMode) {
      // ignore: avoid_print
      print('❌ [ERROR] $message');
      // ignore: avoid_print
      if (stackTrace != null) print(stackTrace);
    }
    developer.log(
      message,
      name: 'ERROR',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }

  static void debug(String message) {
    if (!kDebugMode) return;
    // ignore: avoid_print
    print('🐞 [DEBUG] $message');
    developer.log(message, name: 'DEBUG', level: 500);
  }
}
