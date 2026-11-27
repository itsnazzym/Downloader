import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/design_system/design_skin.dart';
import 'package:tapload/core/platform/platform_info.dart';
import 'package:tapload/core/theme/app_theme.dart';
import 'package:tapload/core/theme/theme_presets.dart';
import 'package:tapload/core/ui/settings/widgets/settings_tiles.dart';

Widget _app(String preset, Widget child) => MaterialApp(
  theme: AppTheme.fromPalette(ThemePresets.getById(preset), Brightness.dark),
  home: Scaffold(body: child),
);

void main() {
  tearDown(() => PlatformInfo.debugForceMobile = null);

  testWidgets('a desktop design draws the shared tiles through its skin', (
    tester,
  ) async {
    PlatformInfo.debugForceMobile = false;
    DesignSkin.register(
      'terminal',
      DesignSkin(
        switchTile: (context, tile) =>
            Text('[${tile.value ? 'x' : ' '}] ${tile.title}'),
      ),
    );
    final tile = SwitchTile(
      title: 'Auto-start',
      subtitle: '',
      value: true,
      onChanged: (_) {},
      icon: Icons.play_arrow,
    );
    await tester.pumpWidget(_app('terminal', tile));
    expect(find.text('[x] Auto-start'), findsOneWidget);

    // A design without a builder keeps the shared tile.
    await tester.pumpWidget(_app('signal', tile));
    await tester.pump(const Duration(seconds: 1)); // the theme animates over
    expect(find.text('[x] Auto-start'), findsNothing);

    // Phones never use a desktop skin.
    PlatformInfo.debugForceMobile = true;
    await tester.pumpWidget(_app('terminal', tile));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('[x] Auto-start'), findsNothing);
  });
}
