import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/theme/theme_resolver.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const designs = ['signal', 'porcelaine', 'pastille', 'studio', 'terminal', 'nocturne'];

  test('every desktop design has a preset and a spec', () {
    for (final id in designs) {
      expect(ThemePresets.getById(id).id, id);
      expect(DesignSpec.forId(id).id, id);
      expect(DesignSpec.forId(id).brightness, isNotNull);
    }
  });

  test('text reaches 4.5:1 on background and surface in every design', () {
    for (final id in designs) {
      final p = ThemePresets.getById(id);
      for (final text in [p.textPrimary, p.textSecondary, p.textDisabled, p.error]) {
        for (final ground in [p.background, p.surface]) {
          expect(
            _contrast(text, ground),
            greaterThanOrEqualTo(4.5),
            reason: '$id: $text on $ground',
          );
        }
      }
      expect(_contrast(p.onPrimary, p.primary), greaterThanOrEqualTo(4.5), reason: '$id on primary');
    }
  });

  test('legacy recolour themes land on the design that replaced them', () {
    expect(ThemePresets.getById('midnight').id, 'signal');
    expect(ThemePresets.getById('ocean').id, 'nocturne');
    expect(ThemePresets.getById('forest').id, 'nocturne');
    expect(ThemePresets.getById('sunset').id, 'pastille');
    expect(ThemePresets.getById('neon').id, 'terminal');
    expect(ThemePresets.getById('monochrome').id, 'studio');
    expect(ThemePresets.getById('unknown').id, 'signal');
  });

  test('a legacy theme ignores the old stored accent', () {
    // Midnight users have the old teal stored as their accent.
    final resolved = ThemeResolver.resolve(
      presetId: 'midnight',
      customAccentArgb: 0xFF0D9488,
    );
    expect(resolved.id, 'signal');
    expect(resolved.primary, ThemePresets.signal.primary);
  });

  test('a current design still honours a custom accent', () {
    final resolved = ThemeResolver.resolve(
      presetId: 'signal',
      customAccentArgb: 0xFFFF8FB8,
    );
    expect(resolved.primary, const Color(0xFFFF8FB8));
  });

  test('designs with a fixed brightness keep their own colours', () {
    final light = ThemeResolver.forBrightness(ThemePresets.porcelaine, Brightness.light);
    expect(light.background, ThemePresets.porcelaine.background);
    final darkAsked = ThemeResolver.forBrightness(ThemePresets.porcelaine, Brightness.dark);
    expect(darkAsked.background, ThemePresets.porcelaine.background);
    final signalLight = ThemeResolver.forBrightness(ThemePresets.signal, Brightness.light);
    expect(signalLight.background, ThemePresets.signal.background);
  });
}
