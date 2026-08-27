import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:modern_downloader/features/downloader/data/datasources/persistence_service.dart';

class MediaFingerprintMatch {
  final String originalPath;

  const MediaFingerprintMatch(this.originalPath);
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest digest) {
    value = digest;
  }

  @override
  void close() {}
}

/// Persists exact media identities. File size only limits which entries need
/// a SHA-256 comparison; it never establishes that files are duplicates.
class MediaFingerprintService {
  static const int _indexVersion = 1;
  static const int _chunkSize = 1024 * 1024;

  final PersistenceService _persistenceService;
  final Map<int, Map<String, String>> _entriesBySize = {};
  Future<void>? _loadFuture;
  Future<void> _operationQueue = Future<void>.value();

  MediaFingerprintService(this._persistenceService);

  /// Returns the known original when [filePath] is byte-for-byte identical,
  /// otherwise records the file's fingerprint and returns null.
  Future<MediaFingerprintMatch?> findDuplicateOrRegister(String filePath) {
    final operation = _operationQueue.then<MediaFingerprintMatch?>(
      (_) => _findDuplicateOrRegister(filePath),
    );
    _operationQueue = operation.then<void>(
      (_) {},
      onError: _ignoreOperationError,
    );
    return operation;
  }

  static void _ignoreOperationError(Object error, StackTrace stackTrace) {}

  Future<MediaFingerprintMatch?> _findDuplicateOrRegister(
    String filePath,
  ) async {
    await _ensureLoaded();

    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Final media file does not exist', filePath);
    }

    final size = await file.length();
    final candidates = _entriesBySize[size];
    if (candidates != null) {
      await _removeInvalidEntries(size, candidates);
    }

    final sha256 = await _hashFile(file);
    final originalPath = _entriesBySize[size]?[sha256];
    if (originalPath != null && !_sameFilePath(originalPath, filePath)) {
      return MediaFingerprintMatch(originalPath);
    }

    _entriesBySize.putIfAbsent(size, () => {})[sha256] = filePath;
    await _save();
    return null;
  }

  Future<void> _ensureLoaded() {
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    final data = await _persistenceService.loadMediaFingerprintIndex();
    if (data == null || data['version'] != _indexVersion) {
      return;
    }

    final entries = data['entries'];
    if (entries is! List) {
      return;
    }

    for (final entry in entries) {
      if (entry is! Map) {
        continue;
      }
      final size = entry['size'];
      final sha256 = entry['sha256'];
      final path = entry['path'];
      if (size is int &&
          sha256 is String &&
          sha256.isNotEmpty &&
          path is String &&
          path.isNotEmpty) {
        _entriesBySize.putIfAbsent(size, () => {})[sha256] = path;
      }
    }

    var changed = false;
    for (final entry in _entriesBySize.entries.toList()) {
      changed |= await _removeInvalidEntries(entry.key, entry.value);
    }
    if (changed) {
      await _save();
    }
  }

  Future<bool> _removeInvalidEntries(
    int expectedSize,
    Map<String, String> entries,
  ) async {
    var changed = false;
    for (final fingerprint in entries.keys.toList()) {
      final path = entries[fingerprint];
      if (path == null) {
        continue;
      }
      try {
        final file = File(path);
        if (!await file.exists() || await file.length() != expectedSize) {
          entries.remove(fingerprint);
          changed = true;
        }
      } on FileSystemException {
        entries.remove(fingerprint);
        changed = true;
      }
    }
    if (entries.isEmpty) {
      _entriesBySize.remove(expectedSize);
    }
    return changed;
  }

  Future<String> _hashFile(File file) async {
    RandomAccessFile? handle;
    try {
      handle = await file.open(mode: FileMode.read);
      final digestSink = _DigestSink();
      final hashSink = sha256.startChunkedConversion(digestSink);
      while (true) {
        final chunk = await handle.read(_chunkSize);
        if (chunk.isEmpty) {
          break;
        }
        hashSink.add(chunk);
      }
      hashSink.close();
      final digest = digestSink.value;
      if (digest == null) {
        throw StateError('SHA-256 digest was not produced');
      }
      return digest.toString();
    } finally {
      await handle?.close();
    }
  }

  Future<void> _save() {
    final entries = <Map<String, Object>>[];
    for (final sizeEntry in _entriesBySize.entries) {
      for (final fingerprintEntry in sizeEntry.value.entries) {
        entries.add({
          'size': sizeEntry.key,
          'sha256': fingerprintEntry.key,
          'path': fingerprintEntry.value,
        });
      }
    }
    return _persistenceService.saveMediaFingerprintIndex({
      'version': _indexVersion,
      'entries': entries,
    });
  }

  bool _sameFilePath(String first, String second) {
    return File(first).absolute.path == File(second).absolute.path;
  }
}
