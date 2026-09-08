import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/bootstrap/app_warmup_models.dart';
import 'package:modern_downloader/core/bootstrap/app_warmup_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppWarmupProvider Tests', () {
    test('initial state contains all 4 stages pending with 0 progress', () {
      final state = AppWarmupState.initial();
      expect(state.progress, equals(0.0));
      expect(state.isCompleted, isFalse);
      expect(state.stages.length, equals(4));
      expect(
        state.stages.every((s) => s.status == WarmupStageStatus.pending),
        isTrue,
      );
      expect(state.stages[0].id, equals(WarmupStageId.mediaEngine));
      expect(state.stages[1].id, equals(WarmupStageId.localServices));
      expect(state.stages[2].id, equals(WarmupStageId.systemIntegrations));
      expect(state.stages[3].id, equals(WarmupStageId.storageCatalog));
    });

    test('continueAnyway unblocks completion flag', () {
      final container = ProviderContainer();
      final notifier = container.read(appWarmupProvider.notifier);
      notifier.continueAnyway();
      final state = container.read(appWarmupProvider);
      expect(state.isCompleted, isTrue);
      expect(state.canContinueAnyway, isFalse);
    });
  });
}
