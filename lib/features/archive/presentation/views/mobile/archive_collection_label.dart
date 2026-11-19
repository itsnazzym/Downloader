import 'package:modern_downloader/l10n/app_localizations.dart';

/// The parser stores two system collections under French names that are also
/// data keys; only the label shown to the user is translated.
String archiveCollectionLabel(AppLocalizations l10n, String name) {
  switch (name) {
    case 'Vidéos Likées':
      return l10n.archiveMobileCollectionLiked;
    case 'Favoris non classés':
      return l10n.archiveMobileCollectionUnsortedFavorites;
    default:
      return name;
  }
}

/// System collections are derived from the data, not real folders: they can
/// be listed and opened but not emptied or deleted.
bool isSystemCollection(String name) =>
    name == 'Vidéos Likées' || name == 'Favoris non classés';
