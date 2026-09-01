import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../platform/android_storage.dart' as platform_android;

/// Resolves a writable default library folder per platform.
class AndroidStorage {
  AndroidStorage._();

  static const String folderName = 'ModernDownloader';

  static Future<String> resolveDefaultOutputFolder() async {
    if (Platform.isAndroid) {
      return platform_android.AndroidStorage.defaultOutputFolder();
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
