import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/bootstrap/app_warmup_models.dart';
import 'package:tapload/core/bootstrap/app_warmup_provider.dart';
import 'package:tapload/core/services/clipboard_service.dart';
import 'package:tapload/core/services/local_server_service.dart';
import 'package:tapload/core/setup/dependency_bootstrap_provider.dart';
import 'package:tapload/core/setup/dependency_bootstrap_service.dart';

class _FakeServer extends LocalServerService {
  _FakeServer(super.ref);
  int starts = 0;
  @override
  Future<void> start() async => starts++;
}

class _FakeClipboard extends ClipboardService {
  _FakeClipboard(super.ref);
  int starts = 0;
  @override
  void startMonitoring() => starts++;
}

ProviderContainer _container() => ProviderContainer(
  overrides: [
    appWarmupProvider.overrideWith(
      (ref) => AppWarmupNotifier(ref, autoStart: false),
    ),
    dependencyBootstrapProvider.overrideWith(
      (ref) => DependencyBootstrapNotifier(
        DependencyBootstrapService(),
        autoStart: false,
      ),
    ),
    localServerServiceProvider.overrideWith(_FakeServer.new),
    clipboardServiceProvider.overrideWith(_FakeClipboard.new),
  ],
);

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
      final container = _container();
      final notifier = container.read(appWarmupProvider.notifier);
      notifier.continueAnyway();
      final state = container.read(appWarmupProvider);
      expect(state.isCompleted, isTrue);
      expect(state.canContinueAnyway, isFalse);
    });

    test(
      'continueAnyway after a failed setup still starts the app services',
      () async {
        final container = _container();
        addTearDown(container.dispose);

        container.read(appWarmupProvider.notifier).continueAnyway();
        await Future<void>.delayed(Duration.zero);

        // Otherwise the UI stays blocked (frozen tickers, ignored links) and
        // the extension server and clipboard monitor never start.
        expect(container.read(dependencyBootstrapProvider).blocksUi, isFalse);
        expect(
          (container.read(localServerServiceProvider) as _FakeServer).starts,
          1,
        );
      },
    );
  });
}
