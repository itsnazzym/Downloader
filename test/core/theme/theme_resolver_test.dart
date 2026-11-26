import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:modern_downloader/core/theme/app_palette.dart';
import 'package:modern_downloader/core/theme/app_theme.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/theme/theme_resolver.dart';

void main() {
  group('ThemeResolver.resolve', () {
    test('returns the named preset when accent matches preset primary', () {
      final nocturne = ThemePresets.nocturne;
      final resolved = ThemeResolver.resolve(
        presetId: 'nocturne',
        customAccentArgb: nocturne.primary.toARGB32(),
      );
      expect(resolved.id, 'nocturne');
      expect(resolved.primary, nocturne.primary);
      expect(resolved.background, nocturne.background);
    });

    test('overrides primary with the custom accent color', () {
      const accent = Color(0xFFEF4444);
      final resolved = ThemeResolver.resolve(
        presetId: 'signal',
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

    test('falls back to signal for unknown ids', () {
      final resolved = ThemeResolver.resolve(
        presetId: 'does-not-exist',
        customAccentArgb: ThemePresets.midnight.primary.toARGB32(),
      );
      expect(resolved.id, 'signal');
    });
  });

  group('ThemeResolver.forBrightness', () {
    test('keeps dark surfaces in dark mode', () {
      final dark = ThemeResolver.forBrightness(
        ThemePresets.nocturne,
        Brightness.dark,
      );
      expect(dark.background, ThemePresets.nocturne.background);
      expect(dark.primary, ThemePresets.nocturne.primary);
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
      // iOS follows the light/dark setting; the desktop designs do not.
      final light = ThemeResolver.forBrightness(
        ThemePresets.ios,
        Brightness.light,
      );
      expect(light.primary, ThemePresets.ios.primary);
      expect(light.background, isNot(ThemePresets.ios.background));
      expect(light.textPrimary.computeLuminance(), lessThan(0.5));
    });
  });

  group('AppTheme.fromPalette', () {
    test('applies palette colors to ThemeData', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final theme = AppTheme.fromPalette(
        ThemePresets.nocturne,
        Brightness.dark,
        useGoogleFonts: false,
      );
      expect(theme.colorScheme.primary, ThemePresets.nocturne.primary);
      expect(theme.scaffoldBackgroundColor, ThemePresets.nocturne.background);
      expect(theme.brightness, Brightness.dark);
      expect(
        theme.extension<AppPalette>()!.primary,
        ThemePresets.nocturne.primary,
      );
    });
  });
}
