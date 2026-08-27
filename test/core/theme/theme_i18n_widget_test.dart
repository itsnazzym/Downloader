import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/theme/app_palette.dart';
import 'package:modern_downloader/core/theme/app_theme.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('French locale paints translated chrome strings', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) => Text(context.l10n.newDownload)),
      ),
    );

    expect(find.text('Nouveau téléchargement'), findsOneWidget);
  });

  testWidgets('AppColors.of reads the ThemeExtension palette', (tester) async {
    final ocean = ThemePresets.ocean;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.fromPalette(ocean, Brightness.dark),
        home: Builder(
          builder: (context) {
            final colors = AppColors.of(context);
            return ColoredBox(
              key: const Key('palette-swatch'),
              color: colors.primary,
              child: Text(
                'swatch',
                style: TextStyle(color: colors.textPrimary),
              ),
            );
          },
        ),
      ),
    );

    final coloredBox = tester.widget<ColoredBox>(
      find.byKey(const Key('palette-swatch')),
    );
    expect(coloredBox.color, ocean.primary);

    final element = tester.element(find.byKey(const Key('palette-swatch')));
    expect(AppColors.of(element).primary, ocean.primary);
    expect(AppPalette.of(element).preset.id, ocean.id);
  });
}
