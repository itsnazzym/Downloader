import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/ui/widgets/toast/toast_service.dart';

void main() {
  test('toast provider keeps at most 3 visible toasts', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(toastProvider.notifier);
    for (var i = 0; i < 8; i++) {
      notifier.show(title: 'Toast $i', duration: const Duration(seconds: 30));
    }

    final visible = container.read(toastProvider);
    expect(visible.length, ToastNotifier.maxVisibleToasts);
    expect(visible.map((t) => t.title).toList(), [
      'Toast 5',
      'Toast 6',
      'Toast 7',
    ]);
  });
}
