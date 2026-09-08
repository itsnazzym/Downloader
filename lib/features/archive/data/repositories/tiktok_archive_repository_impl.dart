import '../../domain/entities/tiktok_archive_catalog.dart';
import '../../domain/repositories/i_tiktok_archive_repository.dart';
import '../datasources/tiktok_archive_parser.dart';
import '../datasources/tiktok_archive_storage.dart';

class TikTokArchiveRepositoryImpl implements ITikTokArchiveRepository {
  final TikTokArchiveStorage _storage;

  TikTokArchiveRepositoryImpl({TikTokArchiveStorage? storage})
      : _storage = storage ?? TikTokArchiveStorage();

  @override
  Future<TikTokArchiveCatalog?> getCachedCatalog() {
    return _storage.loadCatalog();
  }

  @override
  Future<TikTokArchiveCatalog> importFromFile(String filePath) async {
    final catalog = await TikTokArchiveParser.parseFromFile(filePath);
    await _storage.saveCatalog(catalog);
    return catalog;
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
