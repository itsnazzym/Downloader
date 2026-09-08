import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/tiktok_archive_catalog.dart';
import '../../../../core/logger/logger_service.dart';

class TikTokArchiveStorage {
  static const String _catalogFileName = 'tiktok_archive_catalog.json';

  Future<File> _getCatalogFile() async {
    final dir = await getApplicationSupportDirectory();
    final archiveDir = Directory(p.join(dir.path, 'tiktok_archive'));
    if (!archiveDir.existsSync()) {
      archiveDir.createSync(recursive: true);
    }
    return File(p.join(archiveDir.path, _catalogFileName));
  }

  Future<void> saveCatalog(TikTokArchiveCatalog catalog) async {
    try {
      final file = await _getCatalogFile();
      // Write in background via compute
      await compute(_writeCatalogIsolate, {
        'filePath': file.path,
        'catalogJson': catalog.toJson(),
      });
      LoggerService.i('TikTok archive catalog saved successfully (${catalog.totalUniqueVideos} videos).');
    } catch (e, st) {
      LoggerService.e('Failed to save TikTok catalog: $e', e, st);
    }
  }

  Future<TikTokArchiveCatalog?> loadCatalog() async {
    try {
      final file = await _getCatalogFile();
      if (!file.existsSync()) return null;

      final catalog = await compute(_readCatalogIsolate, file.path);
      LoggerService.i('Loaded cached TikTok catalog (${catalog.totalUniqueVideos} videos).');
      return catalog;
    } catch (e, st) {
      LoggerService.e('Failed to load cached TikTok catalog: $e', e, st);
      return null;
    }
  }

  Future<void> clearCatalog() async {
    try {
      final file = await _getCatalogFile();
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      LoggerService.w('Could not delete TikTok catalog file: $e');
    }
  }

  static void _writeCatalogIsolate(Map<String, dynamic> args) {
    final filePath = args['filePath'] as String;
    final jsonMap = args['catalogJson'] as Map<String, dynamic>;
    final file = File(filePath);
    final encoded = jsonEncode(jsonMap);
    file.writeAsStringSync(encoded, flush: true);
  }

  static TikTokArchiveCatalog _readCatalogIsolate(String filePath) {
    final file = File(filePath);
    final content = file.readAsStringSync();
    final Map<String, dynamic> jsonMap = jsonDecode(content);
    return TikTokArchiveCatalog.fromJson(jsonMap);
  }
}
