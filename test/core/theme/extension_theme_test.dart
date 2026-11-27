import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/theme/extension_theme.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';

Color _color(String hex) => Color(int.parse('FF${hex.substring(1)}', radix: 16));

double _contrast(Color a, Color b) {
  final hi = a.computeLuminance() > b.computeLuminance() ? a : b;
  final lo = identical(hi, a) ? b : a;
  return (hi.computeLuminance() + 0.05) / (lo.computeLuminance() + 0.05);
}

void main() {
  final hex = RegExp(r'^#[0-9a-f]{6}$');

  for (final preset in ThemePresets.all) {
    group('extension theme: ${preset.id}', () {
      final dark = preset.background.computeLuminance() < 0.5;
      final message = ExtensionTheme.build(
        preset,
        brightness: dark ? Brightness.dark : Brightness.light,
      );

      test('every colour is an opaque #rrggbb string', () {
        final values = <String>[
          for (final key in ['canvas', 'panel', 'panel2', 'line', 'ink', 'sub', 'mute'])
            message[key] as String,
          for (final tile in message['tiles'] as List)
            ...[(tile as Map)['bg'] as String, tile['on'] as String],
          ...[
            for (final key in ['ok', 'bad'])
              ...[(message[key] as Map)['bg'] as String, (message[key] as Map)['on'] as String],
          ],
        ];
        for (final value in values) {
          expect(value, matches(hex), reason: value);
        }
      });

      test('three distinct action colours, each readable with its text colour', () {
        final tiles = (message['tiles'] as List).cast<Map>();
        expect(tiles, hasLength(3));
        expect({for (final t in tiles) t['bg']}, hasLength(3));
        for (final t in [...tiles, message['ok'] as Map, message['bad'] as Map]) {
          expect(
            _contrast(_color(t['bg'] as String), _color(t['on'] as String)),
            greaterThanOrEqualTo(4.5),
            reason: '${preset.id} ${t['bg']} on ${t['on']}',
          );
        }
      });

      test('main text is readable on the canvas and on panels', () {
        final ink = _color(message['ink'] as String);
        expect(_contrast(ink, _color(message['canvas'] as String)), greaterThanOrEqualTo(7));
        expect(_contrast(ink, _color(message['panel'] as String)), greaterThanOrEqualTo(7));
        expect(
          _contrast(_color(message['sub'] as String), _color(message['panel'] as String)),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('brightness and radii follow the design', () {
        expect(message['dark'], dark);
        expect(message['cardRadius'], isA<int>());
        expect(message['controlRadius'], isA<int>());
      });
    });
  }

  test('the translucent design border is flattened over the canvas', () {
    final message = ExtensionTheme.build(
      ThemePresets.signal,
      brightness: Brightness.dark,
    );
    expect(message['line'], matches(hex));
    expect(message['line'], isNot(message['canvas']));
  });
}
