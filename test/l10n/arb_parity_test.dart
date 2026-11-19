import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final en = _arb('en');
  final messageKeys = en.keys.where((k) => !k.startsWith('@')).toList();

  for (final lang in ['fr', 'ar']) {
    group('app_$lang.arb', () {
      final other = _arb(lang);

      test('has every key of app_en.arb', () {
        final missing = messageKeys.where((k) => !other.containsKey(k));
        expect(missing, isEmpty);
      });

      test('has no key that app_en.arb lacks', () {
        final extra = other.keys.where(
          (k) => !k.startsWith('@') && !en.containsKey(k),
        );
        expect(extra, isEmpty);
      });

      test('uses every placeholder declared in app_en.arb', () {
        final missing = <String>[];
        for (final k in messageKeys) {
          final meta = en['@$k'];
          final text = other[k];
          if (meta is! Map || text is! String) continue;
          final declared = (meta['placeholders'] as Map?)?.keys ?? const [];
          for (final name in declared) {
            if (!text.contains('{$name')) missing.add('$k:$name');
          }
        }
        expect(missing, isEmpty);
      });
    });
  }
}
