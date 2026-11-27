import '../../domain/entities/tiktok_archive_catalog.dart';
import '../../domain/repositories/i_tiktok_archive_repository.dart';
import '../datasources/tiktok_archive_parser.dart';
import '../datasources/tiktok_archive_storage.dart';
import '../services/tiktok_archive_merger.dart';

class TikTokArchiveRepositoryImpl implements ITikTokArchiveRepository {
  final TikTokArchiveStorage _storage;

  TikTokArchiveRepositoryImpl({TikTokArchiveStorage? storage})
      : _storage = storage ?? TikTokArchiveStorage();

  static const _merger = TikTokArchiveMerger();

  /// Loads the saved catalog. When it holds no collection membership at all
  /// (first launch after the data folder was renamed, or an export imported
  /// before memberships were kept), memberships are recovered from the old
  /// folder first; a backup of the saved file is written before any rewrite.
  @override
  Future<TikTokArchiveCatalog?> getCachedCatalog() async {
    final current = await _storage.loadCatalog();
    if (current != null &&
        current.videos.any((video) => video.collectionIds.isNotEmpty)) {
      return current;
    }
    final legacy = await _storage.loadLegacyCatalogs();
    if (legacy.isEmpty) return current;
    final recovered = current == null
        ? _merger.recoverLegacy(legacy.first, legacy.skip(1).toList()).catalog
        : _merger.recoverLegacy(current, legacy).catalog;
    // Nothing recoverable: do not rewrite the file (or rotate its backups) on
    // every launch.
    if (current != null &&
        !recovered.videos.any((video) => video.collectionIds.isNotEmpty)) {
      return current;
    }
    await _storage.backupCatalog();
    await _storage.saveCatalog(recovered);
    return recovered;
  }

  /// Parses the export and merges it into the saved catalog: classification
  /// already known (or recoverable from the old folder) survives, so importing
  /// again never un-files a favorite.
  @override
  Future<TikTokArchiveCatalog> importFromFile(String filePath) async {
    final fresh = await TikTokArchiveParser.parseFromFile(filePath);
    final current = await _storage.loadCatalog();
    var merged = _merger.mergeExport(fresh, current);
    final legacy = await _storage.loadLegacyCatalogs();
    if (legacy.isNotEmpty) {
      merged = _merger.recoverLegacy(merged, legacy).catalog;
    }
    await _storage.backupCatalog();
    await _storage.saveCatalog(merged);
    return merged;
  }

  @override
  Future<void> saveCatalog(TikTokArchiveCatalog catalog) {
    return _storage.saveCatalog(catalog);
  }

  @override
  Future<void> clearCatalog() {
    return _storage.clearCatalog();
  }
}
