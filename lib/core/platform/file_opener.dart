import 'dart:io';

import '../logger/logger_service.dart';
import 'android_ytdlp_client.dart';
import 'platform_info.dart';

class FileOpener {
  const FileOpener._();

  static Future<void> open(String path) async {
    try {
      if (PlatformInfo.isAndroid) {
        await AndroidYtDlpClient.instance.openPath(path);
        return;
      }
      if (Platform.isWindows) {
        await Process.start('explorer.exe', [path]);
        return;
      }
      if (Platform.isMacOS) {
        await Process.start('open', [path]);
        return;
      }
      await Process.start('xdg-open', [path]);
    } catch (error) {
      LoggerService.w('Failed to open $path: $error');
    }
  }

  static Future<void> reveal(String path) async {
    try {
      if (PlatformInfo.isAndroid) {
        await AndroidYtDlpClient.instance.openPath(path, reveal: true);
        return;
      }
      if (Platform.isWindows) {
        await Process.start('explorer.exe', ['/select,', path]);
        return;
      }
      if (Platform.isMacOS) {
        await Process.start('open', ['-R', path]);
        return;
      }
      await Process.start('xdg-open', [File(path).parent.path]);
    } catch (error) {
      LoggerService.w('Failed to reveal $path: $error');
    }
  }
}
