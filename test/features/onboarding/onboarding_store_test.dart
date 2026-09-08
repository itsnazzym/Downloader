import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/onboarding/data/onboarding_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to not completed', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OnboardingStore(await SharedPreferences.getInstance());
    expect(store.completed, isFalse);
  });

  test('persists completed and replay reset', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = OnboardingStore(prefs);

    await store.setCompleted(true);
    expect(store.completed, isTrue);
    expect(prefs.getBool(OnboardingStore.prefsKey), isTrue);

    await store.setCompleted(false);
    expect(store.completed, isFalse);
    expect(OnboardingStore(prefs).completed, isFalse);
  });

  test('memory store mirrors persist API', () async {
    final store = MemoryOnboardingStore();
    expect(store.completed, isFalse);
    await store.setCompleted(true);
    expect(store.completed, isTrue);
  });
}
