import 'package:shared_preferences/shared_preferences.dart';

abstract class OnboardingPersistence {
  bool get completed;
  Future<void> setCompleted(bool value);
}

class OnboardingStore implements OnboardingPersistence {
  OnboardingStore(this._prefs);

  static const String prefsKey = 'onboarding_completed';

  final SharedPreferences _prefs;

  @override
  bool get completed => _prefs.getBool(prefsKey) ?? false;

  @override
  Future<void> setCompleted(bool value) async {
    try {
      await _prefs.setBool(prefsKey, value);
    } catch (_) {
      // Persistence must never block dismissing the tour.
    }
  }
}

class MemoryOnboardingStore implements OnboardingPersistence {
  MemoryOnboardingStore({this.completed = false});

  @override
  bool completed;

  @override
  Future<void> setCompleted(bool value) async {
    completed = value;
  }
}
