import 'package:flutter/foundation.dart';

import 'transfer_models.dart';

@immutable
class TransferredFileRecord {
  const TransferredFileRecord({
    required this.sha256,
    required this.size,
    required this.firstTransferredAt,
    required this.lastFileName,
    this.lastSource,
  });

  final String sha256;
  final int size;
  final DateTime firstTransferredAt;
  final String lastFileName;
  final String? lastSource;

  Map<String, Object?> toJson() {
    return {
      'size': size,
      'firstTransferredAt': firstTransferredAt.toUtc().toIso8601String(),
      'lastFileName': lastFileName,
      if (lastSource != null) 'lastSource': lastSource,
    };
  }

  static TransferredFileRecord? fromJson(String sha256, Object? raw) {
    if (sha256.isEmpty || raw is! Map) return null;
    final size = raw['size'];
    final at = raw['firstTransferredAt'];
    final name = raw['lastFileName'];
    if (size is! int || size < 0) return null;
    if (at is! String || at.isEmpty) return null;
    if (name is! String || name.isEmpty) return null;
    final parsed = DateTime.tryParse(at);
    if (parsed == null) return null;
    return TransferredFileRecord(
      sha256: sha256,
      size: size,
      firstTransferredAt: parsed.toUtc(),
      lastFileName: name,
      lastSource: raw['lastSource'] is String
          ? raw['lastSource'] as String
          : null,
    );
  }

  static TransferredFileRecord fromFile(
    TransferFile file, {
    DateTime? at,
  }) {
    return TransferredFileRecord(
      sha256: file.sha256 ?? '',
      size: file.size,
      firstTransferredAt: (at ?? DateTime.now()).toUtc(),
      lastFileName: file.fileName,
      lastSource: file.creatorKey ?? file.creatorHandle,
    );
  }
}

@immutable
class FolderSendCounts {
  const FolderSendCounts({
    required this.key,
    required this.found,
    required this.already,
    required this.newest,
  });

  final String key;
  final int found;
  final int already;
  final int newest;
}

@immutable
class SendPreview {
  const SendPreview({
    required this.found,
    required this.already,
    required this.newest,
    required this.newBytes,
    required this.hasPeer,
    this.folders = const [],
  });

  static const empty = SendPreview(
    found: 0,
    already: 0,
    newest: 0,
    newBytes: 0,
    hasPeer: false,
  );

  final int found;
  final int already;
  final int newest;
  final int newBytes;
  final bool hasPeer;
  final List<FolderSendCounts> folders;

  FolderSendCounts? forKey(String key) {
    for (final folder in folders) {
      if (folder.key == key) return folder;
    }
    return null;
  }
}

class SendMemoryFilter {
  const SendMemoryFilter._();

  static SendPreview preview({
    required List<TransferFile> files,
    required String? fingerprint,
    required bool Function(String sha256) isTransferred,
    bool considerHistoryWithoutPeer = true,
  }) {
    final explicitPeer = fingerprint != null && fingerprint.isNotEmpty;
    final checkTransferred = explicitPeer || considerHistoryWithoutPeer;
    final byKey = <String, List<int>>{};
    var found = 0;
    var already = 0;
    var newest = 0;
    var newBytes = 0;
    final seenNew = <String>{};

    for (final file in files) {
      found += 1;
      final key = file.creatorKey ?? file.creatorHandle ?? '_';
      final counts = byKey.putIfAbsent(key, () => [0, 0, 0]);
      counts[0] += 1;

      final sha = file.sha256;
      final hasSha = sha != null && sha.isNotEmpty;
      final transferred = hasSha && checkTransferred && isTransferred(sha);
      if (transferred) {
        already += 1;
        counts[1] += 1;
        continue;
      }

      final dedupKey = hasSha ? sha : (file.localPath ?? file.fileName);
      if (seenNew.add(dedupKey)) {
        newest += 1;
        newBytes += file.size;
        counts[2] += 1;
      }
    }

    final folders = [
      for (final entry in byKey.entries)
        FolderSendCounts(
          key: entry.key,
          found: entry.value[0],
          already: entry.value[1],
          newest: entry.value[2],
        ),
    ]..sort((a, b) => a.key.compareTo(b.key));

    return SendPreview(
      found: found,
      already: already,
      newest: newest,
      newBytes: newBytes,
      hasPeer: explicitPeer || already > 0,
      folders: folders,
    );
  }

  static List<TransferFile> outgoing({
    required List<TransferFile> files,
    required String? fingerprint,
    required bool Function(String sha256) isTransferred,
    bool considerHistoryWithoutPeer = true,
  }) {
    final explicitPeer = fingerprint != null && fingerprint.isNotEmpty;
    final checkTransferred = explicitPeer || considerHistoryWithoutPeer;
    final seen = <String>{};
    final next = <TransferFile>[];
    for (final file in files) {
      final sha = file.sha256;
      final hasSha = sha != null && sha.isNotEmpty;
      if (hasSha && checkTransferred && isTransferred(sha)) {
        continue;
      }
      final dedupKey = hasSha ? sha : (file.localPath ?? file.fileName);
      if (!seen.add(dedupKey)) continue;
      next.add(file);
    }
    return next;
  }
}
