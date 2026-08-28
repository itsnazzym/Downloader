import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/services/clipboard_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': ''};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<ProviderContainer> containerWithClipboard({
    required bool enabled,
  }) async {
    SharedPreferences.setMockInitialValues({
      'clipboard_monitor_enabled': enabled,
    });
    final prefsInstance = await SharedPreferences.getInstance();
    initPrefs(prefsInstance);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settleStart(ClipboardService service) async {
    service.startMonitoring();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('does not start a timer when clipboard monitoring is disabled', () async {
    final container = await containerWithClipboard(enabled: false);
    final service = container.read(clipboardServiceProvider);

    await settleStart(service);

    expect(service.isTimerActive, isFalse);
  });

  test('starts a timer when clipboard monitoring is enabled', () async {
    final container = await containerWithClipboard(enabled: true);
    final service = container.read(clipboardServiceProvider);

    await settleStart(service);

    expect(service.isTimerActive, isTrue);
  });

  test('starts and stops the timer when the setting is toggled', () async {
    final container = await containerWithClipboard(enabled: false);
    final service = container.read(clipboardServiceProvider);

    await settleStart(service);
    expect(service.isTimerActive, isFalse);

    container.read(settingsProvider.notifier).setClipboardMonitorEnabled(true);
    expect(service.isTimerActive, isTrue);

    container.read(settingsProvider.notifier).setClipboardMonitorEnabled(false);
    expect(service.isTimerActive, isFalse);
  });
}
