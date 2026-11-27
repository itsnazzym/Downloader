import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('reduce effects is off by default and persists', () async {
    SharedPreferences.setMockInitialValues({});
    initPrefs(await SharedPreferences.getInstance());
    final n = SettingsNotifier();
    expect(n.state.reduceEffects, isFalse);

    n.setReduceEffects(true);
    expect(n.state.reduceEffects, isTrue);
    expect(SettingsNotifier().state.reduceEffects, isTrue);
  });
}
