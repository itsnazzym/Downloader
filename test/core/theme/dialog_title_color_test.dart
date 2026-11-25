import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modern_downloader/core/theme/app_theme.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('dialog titles use the readable text colour on dark themes', () async {
    final unexpected = <Object>[];
    // Building the google_fonts theme starts font loads that fail later in
    // tests (no assets, no network). Only the colours matter here, so those
    // late load errors are kept out of the test; anything else still fails.
    await runZonedGuarded(
      () async {
        for (final preset in [ThemePresets.midnight, ThemePresets.oled]) {
          // The google_fonts base theme carries its own (dark) colours.
          final theme = AppTheme.fromPalette(preset, Brightness.dark);
          // AlertDialog titles default to headlineSmall; dropdown values use
          // bodyLarge / titleMedium.
          for (final style in [
            theme.textTheme.headlineSmall,
            theme.textTheme.bodyLarge,
            theme.textTheme.titleMedium,
          ]) {
            expect(style?.color, preset.textPrimary, reason: preset.id);
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      },
      (error, _) {
        if (!error.toString().contains('allowRuntimeFetching')) {
          unexpected.add(error);
        }
      },
    );
    expect(unexpected, isEmpty);
  });
}
