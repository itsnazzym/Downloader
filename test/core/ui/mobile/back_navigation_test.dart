import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/ui/mobile/back_navigation.dart';

void main() {
  group('mobileBackTarget', () {
    test('library root has no target: the exit flow takes over', () {
      expect(mobileBackTarget('/'), isNull);
    });

    test('settings sub-pages go back to the settings hub', () {
      expect(mobileBackTarget('/settings/general'), '/settings');
      expect(mobileBackTarget('/settings/plugins'), '/settings');
    });

    test('every other screen goes back to the library', () {
      for (final path in ['/settings', '/browse', '/transfer', '/stats']) {
        expect(mobileBackTarget(path), '/', reason: path);
      }
    });
  });

  group('DoubleBackExit', () {
    final t0 = DateTime(2026, 11, 19, 12);

    test('the first press only warns', () {
      expect(DoubleBackExit().press(t0), isFalse);
    });

    test('a second press inside the window confirms the exit', () {
      final exit = DoubleBackExit();
      exit.press(t0);
      expect(exit.press(t0.add(const Duration(milliseconds: 1500))), isTrue);
    });

    test('a second press after the window starts over', () {
      final exit = DoubleBackExit();
      exit.press(t0);
      expect(exit.press(t0.add(const Duration(seconds: 3))), isFalse);
      expect(exit.press(t0.add(const Duration(seconds: 4))), isTrue);
    });

    test('a confirmed exit resets the counter', () {
      final exit = DoubleBackExit();
      exit.press(t0);
      exit.press(t0.add(const Duration(milliseconds: 500)));
      expect(exit.press(t0.add(const Duration(seconds: 1))), isFalse);
    });
  });

  group('BackInterceptors', () {
    test(
      'the most recent handler is asked first and can stop the chain',
      () async {
        final interceptors = BackInterceptors();
        final asked = <String>[];
        interceptors.register(() {
          asked.add('page');
          return false;
        });
        interceptors.register(() {
          asked.add('sheet');
          return true;
        });
        expect(await interceptors.handle(), isTrue);
        expect(asked, ['sheet']);
      },
    );

    test('falls through to older handlers, then to the shell', () async {
      final interceptors = BackInterceptors();
      final asked = <String>[];
      interceptors.register(() {
        asked.add('a');
        return false;
      });
      interceptors.register(() {
        asked.add('b');
        return false;
      });
      expect(await interceptors.handle(), isFalse);
      expect(asked, ['b', 'a']);
    });

    test('an unregistered handler is no longer asked', () async {
      final interceptors = BackInterceptors();
      var calls = 0;
      final remove = interceptors.register(() {
        calls++;
        return true;
      });
      remove();
      expect(await interceptors.handle(), isFalse);
      expect(calls, 0);
    });
  });
}
