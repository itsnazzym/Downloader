import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../download/download_file_resolver.dart';

class FolderSizeEntry {
  const FolderSizeEntry({required this.name, required this.bytes});

  final String name;
  final int bytes;
}

class FolderSizeSnapshot {
  const FolderSizeSnapshot({
    required this.path,
    required this.totalBytes,
    required this.fileCount,
    required this.topSubfolders,
    required this.videoBytes,
    required this.audioBytes,
    required this.otherBytes,
    required this.scannedAt,
  });

  final String path;
  final int totalBytes;
  final int fileCount;
  final List<FolderSizeEntry> topSubfolders;
  final int videoBytes;
  final int audioBytes;
  final int otherBytes;
  final DateTime scannedAt;

  FolderSizeSnapshot copyWith({DateTime? scannedAt}) {
    return FolderSizeSnapshot(
      path: path,
      totalBytes: totalBytes,
      fileCount: fileCount,
      topSubfolders: topSubfolders,
      videoBytes: videoBytes,
      audioBytes: audioBytes,
      otherBytes: otherBytes,
      scannedAt: scannedAt ?? this.scannedAt,
    );
  }
}

sealed class FolderSizeResult {}

class FolderSizeOk extends FolderSizeResult {
  FolderSizeOk(this.snapshot);
  final FolderSizeSnapshot snapshot;
}

class FolderSizeError extends FolderSizeResult {
  FolderSizeError(this.path);
  final String path;
}

typedef FolderScanner = Future<FolderSizeSnapshot> Function(String path);

FolderSizeSnapshot _emptySnapshot(String path, DateTime scannedAt) {
  return FolderSizeSnapshot(
    path: path,
    totalBytes: 0,
    fileCount: 0,
    topSubfolders: const [],
    videoBytes: 0,
    audioBytes: 0,
    otherBytes: 0,
    scannedAt: scannedAt,
  );
}

Future<FolderSizeSnapshot> scanFolderSize(String path) async {
  final trimmed = path.trim();
  final scannedAt = DateTime.now();
  if (trimmed.isEmpty) {
    return _emptySnapshot(path, scannedAt);
  }

  final dir = Directory(trimmed);
  final exists = dir.existsSync();
  if (!exists) {
    return _emptySnapshot(trimmed, scannedAt);
  }

  final subfolderBytes = <String, int>{};
  try {
    await for (final entity in dir.list(followLinks: false).handleError((Object _, StackTrace __) {})) {
      final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        subfolderBytes[p.basename(entity.path)] = 0;
      }
    }
  } on FileSystemException {
    rethrow;
  }

  var totalBytes = 0;
  var fileCount = 0;
  var videoBytes = 0;
  var audioBytes = 0;
  var otherBytes = 0;

  try {
    await for (final entity in dir.list(recursive: true, followLinks: false).handleError((Object _, StackTrace __) {})) {
      final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file) {
        continue;
      }
      late final int length;
      try {
        length = File(entity.path).lengthSync();
      } on FileSystemException {
        continue;
      }
      totalBytes += length;
      fileCount += 1;
      if (DownloadFileResolver.isVideoPath(entity.path)) {
        videoBytes += length;
      } else if (DownloadFileResolver.isAudioPath(entity.path)) {
        audioBytes += length;
      } else {
        otherBytes += length;
      }
      final rel = p.relative(entity.path, from: dir.path);
      final parts = p.split(rel);
      if (parts.length > 1) {
        final name = parts.first;
        subfolderBytes[name] = (subfolderBytes[name] ?? 0) + length;
      }
    }
  } on FileSystemException {
    rethrow;
  }

  final ranked = subfolderBytes.entries.toList()
    ..sort((a, b) {
      final byBytes = b.value.compareTo(a.value);
      if (byBytes != 0) {
        return byBytes;
      }
      return a.key.compareTo(b.key);
    });
  final topSubfolders = ranked
      .take(3)
      .map((e) => FolderSizeEntry(name: e.key, bytes: e.value))
      .toList(growable: false);

  return FolderSizeSnapshot(
    path: trimmed,
    totalBytes: totalBytes,
    fileCount: fileCount,
    topSubfolders: topSubfolders,
    videoBytes: videoBytes,
    audioBytes: audioBytes,
    otherBytes: otherBytes,
    scannedAt: scannedAt,
  );
}

class FolderSizeService {
  FolderSizeService({
    FolderScanner? scanner,
    DateTime Function()? clock,
  }) : _scanner = scanner ?? ((path) => compute(scanFolderSize, path)),
       _clock = clock ?? DateTime.now;

  static const Duration cacheTtl = Duration(minutes: 10);

  final FolderScanner _scanner;
  final DateTime Function() _clock;
  final Map<String, FolderSizeSnapshot> _cache = {};
  final Map<String, Future<FolderSizeResult>> _inFlight = {};

  String _cacheKey(String path) {
    return path.trim().replaceAll('/', '\\').toLowerCase();
  }

  bool isFresh(FolderSizeSnapshot snapshot) {
    return _clock().difference(snapshot.scannedAt) < cacheTtl;
  }

  FolderSizeSnapshot? peek(String path) {
    return _cache[_cacheKey(path)];
  }

  void resetCache() {
    _cache.clear();
    _inFlight.clear();
  }

  Future<FolderSizeResult> getSize(String path, {bool force = false}) async {
    try {
      final snapshot = (await _scanner(path)).copyWith(scannedAt: _clock());
      _cache[_cacheKey(path)] = snapshot;
      return FolderSizeOk(snapshot);
    } catch (_) {
      return FolderSizeError(path);
    }
  }
}
