import 'dart:io';

import 'package:modern_downloader/features/transfer/data/payload_scanner.dart';
import 'package:modern_downloader/features/transfer/data/send_memory_store.dart';

class ContentHash {
  const ContentHash._();

  static Future<String> resolve({
    required File file,
    required FileStat stat,
    SendMemoryStore? store,
  }) async {
    final path = file.absolute.path;
    final mtimeMs = stat.modified.millisecondsSinceEpoch;
    final cached = store?.cachedSha256(
      path,
      size: stat.size,
      mtimeMs: mtimeMs,
    );
    if (cached != null) return cached;
    final sha = await PayloadScanner.sha256File(file);
    store?.putHashCache(
      path,
      size: stat.size,
      mtimeMs: mtimeMs,
      sha256: sha,
    );
    return sha;
  }
}
