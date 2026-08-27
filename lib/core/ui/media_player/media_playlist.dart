import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/download/download_file_resolver.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';

/// One playable item in the fullscreen queue (filtered downloads order).
class PlaylistEntry {
  final String id;
  final String filePath;
  final String title;

  const PlaylistEntry({
    required this.id,
    required this.filePath,
    required this.title,
  });
}

/// Safe wrap: `((i % n) + n) % n` so negative deltas stay in range.
int wrapIndex(int index, int delta, int length) {
  if (length <= 0) return 0;
  final i = index + delta;
  return ((i % length) + length) % length;
}

/// Visible filtered downloads that resolve to an on-disk playable file.
final mediaPlaylistProvider = Provider<List<PlaylistEntry>>((ref) {
  final filtered = ref.watch(filteredDownloadsProvider);
  final items = filtered.valueOrNull ?? const [];
  final entries = <PlaylistEntry>[];

  for (final item in items) {
    try {
      final path = DownloadFileResolver.resolvePlayablePath(
        item.filePath,
        title: item.title,
      );
      if (path == null) continue;
      entries.add(
        PlaylistEntry(
          id: item.id,
          filePath: path,
          title: item.title ?? path.split(RegExp(r'[/\\]')).last,
        ),
      );
    } catch (_) {
      // Skip items whose path resolution fails unexpectedly.
    }
  }

  return entries;
});

/// Skip previous / next within [mediaPlaylistProvider], syncing list selection.
class MediaPlaylistController {
  MediaPlaylistController(this._ref);

  final Ref _ref;

  Future<void> skipBy(int delta) async {
    try {
      final playlist = _ref.read(mediaPlaylistProvider);
      if (playlist.isEmpty) return;

      final currentFile = _ref.read(mediaPlayerProvider).currentFile;
      var index = -1;
      if (currentFile != null && currentFile.isNotEmpty) {
        final normalizedCurrent = DownloadFileResolver.normalizePath(
          currentFile,
        );
        index = playlist.indexWhere(
          (e) =>
              e.filePath == currentFile ||
              DownloadFileResolver.normalizePath(e.filePath) ==
                  normalizedCurrent,
        );
      }
      if (index < 0) index = 0;

      final nextIndex = wrapIndex(index, delta, playlist.length);
      final entry = playlist[nextIndex];

      _ref.read(selectedDownloadIdProvider.notifier).state = entry.id;
      await _ref.read(mediaPlayerProvider.notifier).switchFile(entry.filePath);
    } catch (e, st) {
      debugPrint('MediaPlaylistController.skipBy failed: $e\n$st');
    }
  }
}

final mediaPlaylistControllerProvider = Provider<MediaPlaylistController>((
  ref,
) {
  return MediaPlaylistController(ref);
});
