import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/features/archive/presentation/views/mobile/archive_collection_label.dart';
import 'package:tapload/l10n/app_localizations.dart';

void main() {
  test('system collections are shown translated, user ones as typed', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(
      archiveCollectionLabel(en, 'Vidéos Likées'),
      en.archiveMobileCollectionLiked,
    );
    expect(
      archiveCollectionLabel(fr, 'Favoris non classés'),
      fr.archiveMobileCollectionUnsortedFavorites,
    );
    expect(archiveCollectionLabel(en, 'Cuisine'), 'Cuisine');
  });

  test('only the two derived collections are system ones', () {
    expect(isSystemCollection('Vidéos Likées'), isTrue);
    expect(isSystemCollection('Favoris non classés'), isTrue);
    expect(isSystemCollection('Cuisine'), isFalse);
  });

  test('the collection manager texts exist in every language', () {
    for (final code in ['en', 'fr', 'ar']) {
      final l10n = lookupAppLocalizations(Locale(code));
      expect(l10n.archiveCollResetBody(3, 'X'), contains('3'), reason: code);
      expect(l10n.archiveCollDeleteBody(3, 'X'), contains('X'), reason: code);
      expect(l10n.archiveCollDownloadAll(7), contains('7'), reason: code);
      expect(l10n.archiveCollClearBody, isNotEmpty, reason: code);
    }
  });
}
