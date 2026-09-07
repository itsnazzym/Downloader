import 'package:modern_downloader/features/downloader/presentation/models/creator_folder.dart';

class TransferCreatorQuery {
  const TransferCreatorQuery._();

  static String normalize(String raw) {
    return raw.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');
  }

  /// Typeahead hits. Never dumps the full library.
  static List<CreatorFolder> matches(
    List<CreatorFolder> folders,
    String raw, {
    int limit = 8,
  }) {
    final query = normalize(raw);
    if (query.isEmpty || limit <= 0) return const [];

    final hits = <CreatorFolder>[];
    for (final folder in folders) {
      final handle = (folder.handle ?? '').toLowerCase();
      final key = folder.key.toLowerCase();
      if (handle.contains(query) || key.contains(query)) {
        hits.add(folder);
        if (hits.length >= limit) break;
      }
    }
    return hits;
  }
}
