import '../../domain/entities/tiktok_archive_catalog.dart';

abstract class ITikTokArchiveRepository {
  Future<TikTokArchiveCatalog?> getCachedCatalog();
  Future<TikTokArchiveCatalog> importFromFile(String filePath);
  Future<void> saveCatalog(TikTokArchiveCatalog catalog);
  Future<void> clearCatalog();
}
