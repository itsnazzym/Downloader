import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:modern_downloader/features/onboarding/data/onboarding_store.dart';
import 'package:modern_downloader/features/onboarding/presentation/mobile/mobile_onboarding.dart';

void main() {
  test('is never shown on desktop', () {
    final store = MemoryOnboardingStore();
    final controller = MobileOnboardingController(store);
    // Tests run on the desktop host.
    expect(PlatformInfo.isMobile, isFalse);
    expect(controller.debugState, isFalse);
  });

  test('replay shows it again and finish stores completion', () async {
    final store = MemoryOnboardingStore();
    final controller = MobileOnboardingController(store);

    controller.replay();
    expect(controller.debugState, isTrue);

    await controller.finish();
    expect(controller.debugState, isFalse);
    expect(store.completed, isTrue);
  });
}
