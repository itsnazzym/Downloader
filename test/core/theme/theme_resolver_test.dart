import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:modern_downloader/core/theme/app_palette.dart';
import 'package:modern_downloader/core/theme/app_theme.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/theme/theme_resolver.dart';

void main() {
  group('ThemeResolver.resolve', () {
    test('returns the named preset when accent matches preset primary', () {
      final ocean = ThemePresets.ocean;
      final resolved = ThemeResolver.resolve(
        presetId: 'ocean',
        customAccentArgb: ocean.primary.toARGB32(),
      );
      expect(resolved.id, 'ocean');
      expect(resolved.primary, ocean.primary);
      expect(resolved.background, ocean.background);
    });

    test('overrides primary with the custom accent color', () {
      const accent = Color(0xFFEF4444);
      final resolved = ThemeResolver.resolve(
        presetId: 'midnight',
        customAccentArgb: accent.toARGB32(),
      );
      expect(resolved.primary, accent);
      expect(resolved.background, ThemePresets.midnight.background);
    });

    test('ios preset enables glass chrome, mesh, and dock', () {
      expect(ThemePresets.ios.isIosChrome, isTrue);
      expect(ThemePresets.ios.useMeshBackground, isTrue);
      expect(ThemePresets.ios.useFloatingDock, isTrue);
      expect(ThemePresets.midnight.isIosChrome, isFalse);
    });

    test('falls back to midnight for unknown ids', () {
      final resolved = ThemeResolver.resolve(
        presetId: 'does-not-exist',
        customAccentArgb: ThemePresets.midnight.primary.toARGB32(),
      );
      expect(resolved.id, 'midnight');
    });
  });

  group('ThemeResolver.forBrightness', () {
    test('keeps dark surfaces in dark mode', () {
      final dark = ThemeResolver.forBrightness(
        ThemePresets.ocean,
        Brightness.dark,
      );
      expect(dark.background, ThemePresets.ocean.background);
      expect(dark.primary, ThemePresets.ocean.primary);
    });

    test('light mode keeps iOS chrome flags', () {
      final iosLight = ThemeResolver.forBrightness(
        ThemePresets.ios,
        Brightness.light,
      );
      expect(iosLight.isIosChrome, isTrue);
      expect(iosLight.useFloatingDock, isTrue);
      expect(iosLight.primary, ThemePresets.ios.primary);
    });

    test('uses light surfaces but keeps the accent in light mode', () {
      final light = ThemeResolver.forBrightness(
        ThemePresets.ocean,
        Brightness.light,
      );
      expect(light.primary, ThemePresets.ocean.primary);
      expect(light.background, isNot(ThemePresets.ocean.background));
      expect(light.textPrimary.computeLuminance(), lessThan(0.5));
    });
  });

  group('AppTheme.fromPalette', () {
    test('applies palette colors to ThemeData', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final theme = AppTheme.fromPalette(
        ThemePresets.ocean,
        Brightness.dark,
        useGoogleFonts: false,
      );
      expect(theme.colorScheme.primary, ThemePresets.ocean.primary);
      expect(theme.scaffoldBackgroundColor, ThemePresets.ocean.background);
      expect(theme.brightness, Brightness.dark);
      expect(
        theme.extension<AppPalette>()!.primary,
        ThemePresets.ocean.primary,
      );
    });
  });
}
