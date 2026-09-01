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
  ///
  /// If [isCancelled] becomes true while waiting, throws
  /// [MetadataProbeCancelledException] without taking a slot.
  Future<void> acquire({bool Function()? isCancelled}) async {
    if (_cancelled(isCancelled)) {
      throw const MetadataProbeCancelledException();
    }
    if (tryAcquire()) return;
    final waiter = Completer<void>();
    _waiters.add(waiter);
    if (isCancelled == null) {
      await waiter.future;
      return;
    }
    while (!waiter.isCompleted) {
      if (_cancelled(isCancelled)) {
        _waiters.remove(waiter);
        throw const MetadataProbeCancelledException();
      }
      try {
        await waiter.future.timeout(const Duration(milliseconds: 50));
      } on TimeoutException {
        // Poll [isCancelled] again.
      }
    }
  }

  static bool _cancelled(bool Function()? isCancelled) {
    return isCancelled != null && isCancelled();
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
        waiter.completeError(const MetadataProbeCancelledException());
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

/// Thrown when a waiting or in-flight metadata probe is cancelled.
class MetadataProbeCancelledException implements Exception {
  const MetadataProbeCancelledException();

  @override
  String toString() => 'MetadataProbeCancelledException';
}
