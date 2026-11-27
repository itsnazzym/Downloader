import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/core/theme/theme_presets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a saved recolour theme moves to its design with that accent', () async {
    SharedPreferences.setMockInitialValues({
      'theme_preset': 'ocean',
      'custom_accent_color': 0xFF0EA5E9,
    });
    final prefs = await SharedPreferences.getInstance();
    initPrefs(prefs);

    final n = SettingsNotifier();
    expect(n.state.themePreset, 'nocturne');
    expect(n.state.customAccentColor, ThemePresets.nocturne.primary.toARGB32());
    expect(prefs.getString('theme_preset'), 'nocturne');
  });

  test('a current design keeps the accent the user picked', () async {
    SharedPreferences.setMockInitialValues({
      'theme_preset': 'signal',
      'custom_accent_color': 0xFFFF8FB8,
    });
    initPrefs(await SharedPreferences.getInstance());
    final n = SettingsNotifier();
    expect(n.state.themePreset, 'signal');
    expect(n.state.customAccentColor, 0xFFFF8FB8);
  });
}
