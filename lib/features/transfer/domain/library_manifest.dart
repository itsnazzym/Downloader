import 'package:flutter/foundation.dart';

@immutable
class LibraryManifestEntry {
  const LibraryManifestEntry({
    required this.relativePath,
    this.downloadId,
    this.creatorKey,
    this.creatorHandle,
  });

  final String relativePath;
  final String? downloadId;
  final String? creatorKey;
  final String? creatorHandle;

  Map<String, Object?> toJson() {
    return {
      'relativePath': relativePath,
      if (downloadId != null) 'downloadId': downloadId,
      if (creatorKey != null) 'creatorKey': creatorKey,
      if (creatorHandle != null) 'creatorHandle': creatorHandle,
    };
  }

  static LibraryManifestEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['relativePath'];
    if (path is! String || path.isEmpty) return null;
    return LibraryManifestEntry(
      relativePath: path,
      downloadId: raw['downloadId'] is String
          ? raw['downloadId'] as String
          : null,
      creatorKey: raw['creatorKey'] is String
          ? raw['creatorKey'] as String
          : null,
      creatorHandle: raw['creatorHandle'] is String
          ? raw['creatorHandle'] as String
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryManifestEntry &&
        other.relativePath == relativePath &&
        other.downloadId == downloadId &&
        other.creatorKey == creatorKey &&
        other.creatorHandle == creatorHandle;
  }

  @override
  int get hashCode =>
      Object.hash(relativePath, downloadId, creatorKey, creatorHandle);
}

@immutable
class LibraryManifest {
  const LibraryManifest({required this.entries, this.version = 1});

  static const fileName = 'library-manifest.json';

  final int version;
  final List<LibraryManifestEntry> entries;

  Map<String, Object?> toJson() {
    return {
      'version': version,
      'entries': [for (final entry in entries) entry.toJson()],
    };
  }

  static LibraryManifest? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final version = raw['version'];
    final list = raw['entries'];
    if (list is! List) return null;
    final entries = <LibraryManifestEntry>[];
    for (final item in list) {
      final parsed = LibraryManifestEntry.fromJson(item);
      if (parsed != null) entries.add(parsed);
    }
    return LibraryManifest(
      version: version is int ? version : 1,
      entries: entries,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryManifest &&
        other.version == version &&
        listEquals(other.entries, entries);
  }

  @override
  int get hashCode => Object.hash(version, Object.hashAll(entries));
}
