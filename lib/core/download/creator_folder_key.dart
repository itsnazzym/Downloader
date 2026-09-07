import 'package:modern_downloader/core/services/progressive_organizer_service.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';

/// Identity used to group downloads into a creator folder.
class CreatorIdentity {
  const CreatorIdentity({required this.key, this.handle});

  static const unknownKey = '__unknown__';

  /// Lowercase grouping key. [unknownKey] when no creator could be parsed.
  final String key;

  /// Sanitized display handle without `@`. Null for the unknown bucket.
  final String? handle;

  bool get isUnknown => key == unknownKey || handle == null || handle!.isEmpty;

  @override
  bool operator ==(Object other) {
    return other is CreatorIdentity &&
        other.key == key &&
        other.handle == handle;
  }

  @override
  int get hashCode => Object.hash(key, handle);
}

/// Resolves a creator folder identity from URL, title, then filename.
class CreatorFolderKey {
  const CreatorFolderKey._();

  static CreatorIdentity of(DownloadItem item) {
    final fromUrl = ProgressiveOrganizerService.extractCreatorFromUrl(
      item.request.url,
    );
    if (fromUrl != null && fromUrl.trim().isNotEmpty) {
      return _fromRaw(fromUrl);
    }

    final fromTitle =
        ProgressiveOrganizerService.extractCreatorFromTitleOrFilename(
          item.title,
          item.filePath,
        );
    if (fromTitle != null && fromTitle.trim().isNotEmpty) {
      return _fromRaw(fromTitle);
    }

    return const CreatorIdentity(key: CreatorIdentity.unknownKey);
  }

  static CreatorIdentity _fromRaw(String raw) {
    final handle = ProgressiveOrganizerService.sanitizeFolderName(raw);
    if (handle.isEmpty || handle.toLowerCase() == 'inconnu') {
      return const CreatorIdentity(key: CreatorIdentity.unknownKey);
    }
    return CreatorIdentity(key: handle.toLowerCase(), handle: handle);
  }
}
