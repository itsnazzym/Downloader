import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/tiktok_archive_catalog.dart';
import '../../../../core/logger/logger_service.dart';

class TikTokArchiveStorage {
  static const String _catalogFileName = 'tiktok_archive_catalog.json';

  /// [supportDirectory] replaces the platform app-data folder (tests).
  TikTokArchiveStorage({Directory? supportDirectory})
    : _supportDirectory = supportDirectory;

  final Directory? _supportDirectory;

  Future<File> _getCatalogFile() async {
    final dir = _supportDirectory ?? await getApplicationSupportDirectory();
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

  /// Copies the saved catalog to `<name>.bak-<timestamp>` before an import or
  /// a recovery rewrites it. Keeps the three newest copies.
  Future<void> backupCatalog() async {
    try {
      final file = await _getCatalogFile();
      if (!file.existsSync()) return;
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[^0-9]'), '')
          .substring(0, 14);
      file.copySync('${file.path}.bak-$stamp');
      final backups =
          file.parent
              .listSync()
              .whereType<File>()
              .where((f) => p.basename(f.path).startsWith('$_catalogFileName.bak-'))
              .toList()
            ..sort((a, b) => b.path.compareTo(a.path));
      for (final old in backups.skip(3)) {
        old.deleteSync();
      }
    } catch (e) {
      LoggerService.w('Could not back up the TikTok catalog: $e');
    }
  }

  /// Catalogs left by a previous app-data folder (the app was renamed), newest
  /// first, backups included. Read-only: the files are never modified.
  Future<List<TikTokArchiveCatalog>> loadLegacyCatalogs() async {
    try {
      final current = (await _getCatalogFile()).parent.parent;
      final files = <File>[];
      for (final dir in current.parent.listSync().whereType<Directory>()) {
        if (p.equals(dir.path, current.path)) continue;
        final archive = Directory(p.join(dir.path, 'tiktok_archive'));
        if (!archive.existsSync()) continue;
        files.addAll(
          archive.listSync().whereType<File>().where(
            (f) => p.basename(f.path).startsWith(_catalogFileName),
          ),
        );
      }
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      final catalogs = <TikTokArchiveCatalog>[];
      for (final file in files) {
        try {
          catalogs.add(await compute(_readCatalogIsolate, file.path));
        } catch (e) {
          LoggerService.w('Skipped unreadable legacy catalog ${file.path}: $e');
        }
      }
      return catalogs;
    } catch (e) {
      LoggerService.w('Could not look for legacy TikTok catalogs: $e');
      return const [];
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
