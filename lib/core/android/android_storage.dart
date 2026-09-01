import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'android_engine_bridge.dart';

/// Resolves a writable default library folder per platform.
class AndroidStorage {
  AndroidStorage._();

  static const String folderName = 'ModernDownloader';
  static const String androidPublicFallback =
      '/storage/emulated/0/Download/ModernDownloader';

  static Future<String> resolveDefaultOutputFolder() async {
    if (Platform.isAndroid) {
      try {
        final native = await AndroidEngineBridge.instance.defaultOutputDir();
        if (native != null && native.trim().isNotEmpty) {
          return native;
        }
      } catch (_) {}
      return androidPublicFallback;
    }

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        return '$userProfile\\Downloads';
      }
    }

    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return p.join(downloads.path, folderName);
      }
    } catch (_) {}

    try {
      final docs = await getApplicationDocumentsDirectory();
      return p.join(docs.path, folderName);
    } catch (_) {
      return folderName;
    }
  }
}
