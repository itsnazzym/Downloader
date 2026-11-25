import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:modern_downloader/features/transfer/domain/library_manifest.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_media_filter.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_path_guard.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class TransferZipBundle {
  const TransferZipBundle._();

  static String archiveName(List<TransferFile> files) {
    final handles = <String>{};
    final tops = <String>{};
    for (final file in files) {
      if (file.fileName == LibraryManifest.fileName) continue;
      final handle = file.creatorHandle?.trim();
      if (handle != null && handle.isNotEmpty) {
        handles.add(handle);
      }
      final rel = TransferPathGuard.relativePathOrNull(file.fileName);
      if (rel == null || rel.isEmpty) continue;
      tops.add(rel.split('/').first);
    }
    if (handles.length == 1) {
      return _safeZipStem(handles.first);
    }
    if (tops.length == 1) {
      return _safeZipStem(tops.first);
    }
    return 'ModernDownloader';
  }

  static bool shouldArchive({
    required bool compressZip,
    required int fileCount,
  }) {
    return compressZip && fileCount > 1;
  }

  static Future<File> writeToTemp(
    List<TransferFile> files, {
    Directory? tempDir,
    bool flatten = false,
  }) async {
    final dir = tempDir ?? Directory.systemTemp;
    await dir.create(recursive: true);
    final zipPath = p.join(dir.path, 'md-bundle-${const Uuid().v4()}.zip');
    // The zip encoder reads files synchronously: keep GBs off the UI isolate.
    return writeToTempIsolated(files, zipPath: zipPath, flatten: flatten);
  }

  static Future<File> writeToTempIsolated(
    List<TransferFile> files, {
    required String zipPath,
    bool flatten = false,
  }) async {
    final entries = _entriesOf(files);
    await Isolate.run(() {
      return _writeEntriesToPath(
        entries: entries,
        zipPath: zipPath,
        flatten: flatten,
      );
    });
    return File(zipPath);
  }

  static List<({String fileName, String localPath})> _entriesOf(
    List<TransferFile> files,
  ) {
    return [
      for (final file in files)
        if (file.localPath != null && file.localPath!.isNotEmpty)
          (fileName: file.fileName, localPath: file.localPath!),
    ];
  }

  static Future<void> _writeEntriesToPath({
    required List<({String fileName, String localPath})> entries,
    required String zipPath,
    required bool flatten,
  }) async {
    final encoder = ZipFileEncoder();
    encoder.create(zipPath, level: ZipFileEncoder.store);
    try {
      for (final entry in entries) {
        final rel = TransferPathGuard.relativePathOrNull(entry.fileName);
        if (rel == null || !TransferMediaFilter.isTransferableMedia(rel)) {
          continue;
        }
        final io = File(entry.localPath);
        if (!await io.exists()) continue;
        final entryName = flatten ? p.basename(rel) : rel;
        await encoder.addFile(io, entryName, ZipFileEncoder.store);
      }
      await encoder.close();
    } catch (_) {
      try {
        await encoder.close();
      } catch (_) {}
      try {
        await File(zipPath).delete();
      } catch (_) {}
      rethrow;
    }
  }

  static String _safeZipStem(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[<>:"|?*\\/]'), '_').trim();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      return 'ModernDownloader';
    }
    return cleaned;
  }
}
