import 'dart:async';

/// Caps parallel `yt-dlp --dump-json` metadata probes.
///
/// Extra callers wait in FIFO order instead of being skipped.
class MetadataProbeLimiter {
  MetadataProbeLimiter({this.maxParallel = 2});

  final int maxParallel;
  int _inFlight = 0;
  final List<Completer<void>> _waiters = <Completer<void>>[];

  int get inFlight => _inFlight;
  int get waiting => _waiters.length;

  /// Returns true if a probe slot was taken immediately. Caller must [release].
  bool tryAcquire() {
    if (_inFlight >= maxParallel) {
      return false;
    }
    _inFlight++;
    return true;
  }

  /// Waits for a free slot, then occupies it. Caller must [release].
  Future<void> acquire() async {
    if (tryAcquire()) return;
    final waiter = Completer<void>();
    _waiters.add(waiter);
    await waiter.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      final next = _waiters.removeAt(0);
      if (!next.isCompleted) {
        next.complete();
      }
      return;
    }
    if (_inFlight > 0) {
      _inFlight--;
    }
  }

  void reset() {
    _inFlight = 0;
    for (final waiter in _waiters) {
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
    _waiters.clear();
  }
}

/// Thrown when a metadata probe is skipped because too many are already running.
///
/// Kept for compatibility. New code should [MetadataProbeLimiter.acquire] and wait.
class MetadataProbeLimitException implements Exception {
  const MetadataProbeLimitException();

  @override
  String toString() => 'MetadataProbeLimitException';
}
