import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/transfer/domain/library_manifest.dart';
import 'package:tapload/features/transfer/domain/transfer_media_filter.dart';
import 'package:tapload/features/transfer/domain/transfer_models.dart';
import 'package:tapload/features/transfer/domain/transfer_path_guard.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

typedef ContentHashResolver = Future<String> Function(File file, FileStat stat);

typedef ScanProgressCallback = void Function(
  int scannedDirs,
  int totalDirs,
  int filesFound,
  int totalBytes,
);

class PayloadBundle {
  const PayloadBundle({required this.files, required this.manifest});

  final List<TransferFile> files;
  final LibraryManifest manifest;
}

class PayloadScanner {
  const PayloadScanner._();

  static Future<String> sha256File(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  static String _flatUniqueName(
    String filePath,
    Set<String> seenNames, {
    String? folderPrefix,
    Map<String, int>? counters,
  }) {
    final base = p.basename(filePath);
    if (!seenNames.contains(base)) {
      seenNames.add(base);
      return base;
    }
    if (folderPrefix != null && folderPrefix.trim().isNotEmpty) {
      final safePrefix = folderPrefix
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .trim();
      final prefixed = '${safePrefix}_$base';
      if (!seenNames.contains(prefixed)) {
        seenNames.add(prefixed);
        return prefixed;
      }
    }
    final ext = p.extension(base);
    final withoutExt = p.basenameWithoutExtension(base);
    final key = folderPrefix != null && folderPrefix.trim().isNotEmpty
        ? '${folderPrefix}_$withoutExt'
        : withoutExt;
    var count = counters != null ? (counters[key] ?? 1) : 1;
    while (true) {
      final candidate = '$withoutExt ($count)$ext';
      if (!seenNames.contains(candidate)) {
        seenNames.add(candidate);
        if (counters != null) counters[key] = count + 1;
        return candidate;
      }
      count++;
    }
  }

  static Future<String?> _hashOf(
    File file,
    FileStat stat, {
    required bool hash,
    ContentHashResolver? hashOf,
  }) async {
    if (hashOf != null) {
      final res = await hashOf(file, stat);
      if (res.isNotEmpty) return res;
    }
    if (!hash) return null;
    return sha256File(file);
  }

  static Future<PayloadBundle> scanDirectories(
    List<Directory> dirs, {
    bool hash = true,
    bool flatten = false,
    Set<String>? usedNames,
    ContentHashResolver? hashOf,
    ScanProgressCallback? onProgress,
  }) async {
    final files = <TransferFile>[];
    final entries = <LibraryManifestEntry>[];
    final seen = usedNames ?? <String>{};
    final counters = <String, int>{};
    var scannedDirs = 0;
    var totalBytes = 0;
    final totalDirs = dirs.length;

    for (final dir in dirs) {
      scannedDirs++;
      if (onProgress != null &&
          (scannedDirs % 25 == 0 || scannedDirs == totalDirs)) {
        onProgress(scannedDirs, totalDirs, files.length, totalBytes);
      }
      if (!await dir.exists()) continue;
      final prefix = p.basename(dir.path);
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        if (!TransferMediaFilter.isTransferableMedia(entity.path)) continue;
        final name = flatten
            ? _flatUniqueName(
                entity.path,
                seen,
                folderPrefix: prefix,
                counters: counters,
              )
            : (() {
                final rel = p
                    .split(p.relative(entity.path, from: dir.path))
                    .join('/');
                return TransferPathGuard.relativePathOrNull('$prefix/$rel');
              })();
        if (name == null) continue;
        final stat = await entity.stat();
        if (stat.size <= 0) continue;
        final hashHex = await _hashOf(
          entity,
          stat,
          hash: hash,
          hashOf: hashOf,
        );
        files.add(
          TransferFile(
            id: const Uuid().v4(),
            fileName: name,
            size: stat.size,
            sha256: hashHex,
            localPath: entity.path,
            creatorHandle: prefix,
            creatorKey: prefix.toLowerCase(),
          ),
        );
        totalBytes += stat.size;
        entries.add(
          LibraryManifestEntry(
            relativePath: name,
            creatorHandle: prefix,
            creatorKey: prefix.toLowerCase(),
          ),
        );
      }
    }
    if (onProgress != null) {
      onProgress(scannedDirs, totalDirs, files.length, totalBytes);
    }
    return PayloadBundle(
      files: files,
      manifest: LibraryManifest(entries: entries),
    );
  }

  static Future<PayloadBundle> scanFiles(
    List<File> filesList, {
    bool hash = true,
    bool flatten = true,
    Set<String>? usedNames,
    ContentHashResolver? hashOf,
  }) async {
    final files = <TransferFile>[];
    final entries = <LibraryManifestEntry>[];
    final seen = usedNames ?? <String>{};
    final counters = <String, int>{};
    for (final file in filesList) {
      if (!await file.exists()) continue;
      if (!TransferMediaFilter.isTransferableMedia(file.path)) continue;
      final stat = await file.stat();
      if (stat.size <= 0) continue;
      final name = flatten
          ? _flatUniqueName(file.path, seen, counters: counters)
          : p.basename(file.path);
      final hashHex = await _hashOf(file, stat, hash: hash, hashOf: hashOf);
      files.add(
        TransferFile(
          id: const Uuid().v4(),
          fileName: name,
          size: stat.size,
          sha256: hashHex,
          localPath: file.path,
        ),
      );
      entries.add(LibraryManifestEntry(relativePath: name));
    }
    return PayloadBundle(
      files: files,
      manifest: LibraryManifest(entries: entries),
    );
  }

  static Future<PayloadBundle> fromDownloadItems({
    required List<DownloadItem> items,
    required String outputFolder,
    required String creatorKey,
    String? creatorHandle,
    bool hash = true,
    bool flatten = false,
    Set<String>? usedNames,
    ContentHashResolver? hashOf,
  }) async {
    final files = <TransferFile>[];
    final entries = <LibraryManifestEntry>[];
    final seen = usedNames ?? <String>{};
    final counters = <String, int>{};
    for (final item in items) {
      final path = item.filePath;
      if (path == null || path.isEmpty) continue;
      if (!TransferMediaFilter.isTransferableMedia(path)) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      final name = flatten
          ? _flatUniqueName(
              path,
              seen,
              folderPrefix: creatorHandle,
              counters: counters,
            )
          : (() {
              final relative = _relativeFor(
                path: path,
                outputFolder: outputFolder,
                handle: creatorHandle,
              );
              return TransferPathGuard.relativePathOrNull(relative);
            })();
      if (name == null) continue;
      final stat = await file.stat();
      if (stat.size <= 0) continue;
      files.add(
        TransferFile(
          id: const Uuid().v4(),
          fileName: name,
          size: stat.size,
          sha256: await _hashOf(file, stat, hash: hash, hashOf: hashOf),
          localPath: path,
          downloadId: item.id,
          creatorKey: creatorKey,
          creatorHandle: creatorHandle,
        ),
      );
      entries.add(
        LibraryManifestEntry(
          relativePath: name,
          downloadId: item.id,
          creatorKey: creatorKey,
          creatorHandle: creatorHandle,
        ),
      );
    }
    return PayloadBundle(
      files: files,
      manifest: LibraryManifest(entries: entries),
    );
  }

  static String _relativeFor({
    required String path,
    required String outputFolder,
    String? handle,
  }) {
    final rel = outputFolder.isNotEmpty && p.isWithin(outputFolder, path)
        ? p.split(p.relative(path, from: outputFolder)).join('/')
        : p.basename(path);
    if (handle == null || handle.isEmpty) return rel;
    final first = rel.split('/').first;
    if (first.toLowerCase() == handle.toLowerCase()) return rel;
    return '$handle/$rel';
  }

  static TransferFile manifestFile(LibraryManifest manifest) {
    final bytes = utf8.encode(jsonEncode(manifest.toJson()));
    return TransferFile(
      id: 'manifest',
      fileName: LibraryManifest.fileName,
      size: bytes.length,
      localPath: null,
      sha256: sha256.convert(bytes).toString(),
    );
  }
}
