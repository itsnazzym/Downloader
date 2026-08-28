import 'dart:async';

/// Runs async operations one at a time so overlapping awaits cannot stampede
/// shared resources (queue persistence, slot processing).
class AsyncSerializer {
  Future<void> _tail = Future<void>.value();

  /// Enqueues [action] behind any in-flight work and returns its result.
  Future<T> run<T>(Future<T> Function() action) {
    final done = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        final result = await action();
        if (!done.isCompleted) {
          done.complete(result);
        }
      } catch (e, st) {
        if (!done.isCompleted) {
          done.completeError(e, st);
        }
      }
    });
    return done.future;
  }
}
