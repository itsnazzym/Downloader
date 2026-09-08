import 'dart:convert';
import 'dart:io';

import 'package:modern_downloader/core/logger/logger_service.dart';
import 'package:modern_downloader/features/transfer/domain/send_memory.dart';
import 'package:path/path.dart' as p;

class HashCacheEntry {
  const HashCacheEntry({
    required this.size,
    required this.mtimeMs,
    required this.sha256,
  });

  final int size;
  final int mtimeMs;
  final String sha256;
}

class SendMemoryStore {
  SendMemoryStore(this.file);

  static const int schemaVersion = 1;

  final File file;
  final Map<String, Map<String, TransferredFileRecord>> _devices =
      <String, Map<String, TransferredFileRecord>>{};
  final Map<String, HashCacheEntry> _hashCache = <String, HashCacheEntry>{};
  bool _dirty = false;

  Future<void> load() async {
    _devices.clear();
    _hashCache.clear();
    _dirty = false;
    try {
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return;
      final devices = decoded['devices'];
      if (devices is Map) {
        devices.forEach((key, value) {
          if (key is! String || key.isEmpty || value is! Map) return;
          final records = <String, TransferredFileRecord>{};
          value.forEach((sha, raw) {
            if (sha is! String) return;
            final record = TransferredFileRecord.fromJson(sha, raw);
            if (record != null) records[sha] = record;
          });
          if (records.isNotEmpty) _devices[key] = records;
        });
      }
      final cache = decoded['hashCache'];
      if (cache is Map) {
        cache.forEach((key, value) {
          if (key is! String || key.isEmpty || value is! Map) return;
          final size = value['size'];
          final mtime = value['mtimeMs'];
          final sha = value['sha256'];
          if (size is! int || mtime is! int || sha is! String || sha.isEmpty) {
            return;
          }
          _hashCache[key] = HashCacheEntry(
            size: size,
            mtimeMs: mtime,
            sha256: sha,
          );
        });
      }
    } catch (e) {
      LoggerService.w('Send memory load failed: $e');
    }
  }

  Set<String> get knownDevices => Set.unmodifiable(_devices.keys);

  int deviceRecordCount(String fingerprint) =>
      _devices[fingerprint]?.length ?? 0;

  bool isTransferred(String? fingerprint, String sha256) {
    if (sha256.isEmpty) return false;
    if (fingerprint != null && fingerprint.isNotEmpty) {
      return _devices[fingerprint]?.containsKey(sha256) ?? false;
    }
    if (_devices.isEmpty) return false;
    return _devices.values.any((bucket) => bucket.containsKey(sha256));
  }

  String? cachedSha256(String path, {required int size, required int mtimeMs}) {
    final entry = _hashCache[_norm(path)];
    if (entry == null) return null;
    if (entry.size != size || entry.mtimeMs != mtimeMs) return null;
    return entry.sha256;
  }

  void putHashCache(
    String path, {
    required int size,
    required int mtimeMs,
    required String sha256,
  }) {
    if (path.isEmpty || sha256.isEmpty) return;
    _hashCache[_norm(path)] = HashCacheEntry(
      size: size,
      mtimeMs: mtimeMs,
      sha256: sha256,
    );
    _dirty = true;
  }

  Future<void> commit(
    String fingerprint,
    List<TransferredFileRecord> records,
  ) async {
    if (fingerprint.isEmpty || records.isEmpty) return;
    final bucket = _devices.putIfAbsent(
      fingerprint,
      () => <String, TransferredFileRecord>{},
    );
    for (final record in records) {
      if (record.sha256.isEmpty) continue;
      final existing = bucket[record.sha256];
      bucket[record.sha256] = existing == null
          ? record
          : TransferredFileRecord(
              sha256: record.sha256,
              size: record.size,
              firstTransferredAt: existing.firstTransferredAt,
              lastFileName: record.lastFileName,
              lastSource: record.lastSource ?? existing.lastSource,
            );
    }
    _dirty = true;
    await persist();
  }

  Future<void> forgetDevice(String fingerprint) async {
    if (fingerprint.isEmpty) return;
    if (_devices.remove(fingerprint) == null) return;
    _dirty = true;
    await persist();
  }

  Future<void> clearAll() async {
    if (_devices.isEmpty) return;
    _devices.clear();
    _dirty = true;
    await persist();
  }

  Future<void> persist() async {
    if (!_dirty) return;
    try {
      await _atomicWrite(jsonEncode(_toJson()));
      _dirty = false;
    } catch (e) {
      LoggerService.w('Send memory save failed: $e');
    }
  }

  Map<String, Object?> _toJson() {
    return {
      'version': schemaVersion,
      'devices': {
        for (final device in _devices.entries)
          device.key: {
            for (final record in device.value.entries)
              record.key: record.value.toJson(),
          },
      },
      'hashCache': {
        for (final entry in _hashCache.entries)
          entry.key: {
            'size': entry.value.size,
            'mtimeMs': entry.value.mtimeMs,
            'sha256': entry.value.sha256,
          },
      },
    };
  }

  String _norm(String path) => p.normalize(path);

  Future<void> _atomicWrite(String content) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    final bak = File('${file.path}.bak');
    await tmp.writeAsString(content, flush: true);
    if (await file.exists()) {
      try {
        if (await bak.exists()) await bak.delete();
        await file.copy(bak.path);
      } catch (_) {}
      try {
        await file.delete();
      } catch (_) {
        await tmp.copy(file.path);
        try {
          await tmp.delete();
        } catch (_) {}
        return;
      }
    }
    try {
      await tmp.rename(file.path);
    } catch (_) {
      await tmp.copy(file.path);
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }
}
