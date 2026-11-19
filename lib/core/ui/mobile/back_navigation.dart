import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A screen that wants to consume the system Back button before the shell
/// navigates away (a web view with history, an inner sub-page...).
/// Return `true` when the press was handled.
typedef BackHandler = FutureOr<bool> Function();

/// Handlers registered by the screens currently on display. The most recently
/// registered one is asked first.
class BackInterceptors {
  final List<BackHandler> _handlers = [];

  /// Registers [handler]; call the returned function to remove it.
  VoidCallback register(BackHandler handler) {
    _handlers.add(handler);
    return () => _handlers.remove(handler);
  }

  Future<bool> handle() async {
    for (final handler in _handlers.reversed.toList()) {
      if (await handler()) return true;
    }
    return false;
  }
}

final backInterceptorsProvider = Provider<BackInterceptors>(
  (ref) => BackInterceptors(),
);

/// Where Back leads from [location] when no screen handled it, or `null` on
/// the library root (where the next step is the "press again to exit" flow).
String? mobileBackTarget(String location) {
  if (location == '/' || location.isEmpty) return null;
  if (location.startsWith('/settings/')) return '/settings';
  return '/';
}

/// Two Back presses within [window] confirm leaving the app.
class DoubleBackExit {
  DoubleBackExit({this.window = const Duration(seconds: 2)});

  final Duration window;
  DateTime? _last;

  /// Returns `true` when this press confirms the exit.
  bool press([DateTime? now]) {
    final at = now ?? DateTime.now();
    final last = _last;
    if (last != null && at.difference(last) <= window) {
      _last = null;
      return true;
    }
    _last = at;
    return false;
  }
}
