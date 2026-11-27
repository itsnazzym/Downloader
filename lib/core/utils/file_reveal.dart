import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:modern_downloader/core/android/android_engine_bridge.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';

/// Opens [path] with the system's default app, on every platform.
void openWithSystem(String path) {
  try {
    if (Platform.isWindows) {
      Process.run('explorer', [path]);
    } else if (Platform.isMacOS) {
      Process.run('open', [path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [path]);
    } else if (PlatformInfo.isAndroid) {
      AndroidEngineBridge.instance.viewFile(path);
    }
  } catch (e) {
    debugPrint('Error opening file: $e');
  }
}

/// Shows [path] selected in the system's file manager (its folder on Linux).
void revealInFolder(String path) {
  try {
    if (Platform.isWindows) {
      Process.run('explorer', ['/select,', path]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [File(path).parent.path]);
    } else if (PlatformInfo.isAndroid) {
      AndroidEngineBridge.instance.viewFile(path);
    }
  } catch (e) {
    debugPrint('Error revealing file: $e');
  }
}
