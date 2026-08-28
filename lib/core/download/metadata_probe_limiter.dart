/// Caps parallel `yt-dlp --dump-json` metadata probes.
class MetadataProbeLimiter {
  MetadataProbeLimiter({this.maxParallel = 2});

  final int maxParallel;
  int _inFlight = 0;

  int get inFlight => _inFlight;

  /// Returns true if a probe slot was taken. Caller must [release].
  bool tryAcquire() {
    if (_inFlight >= maxParallel) {
      return false;
    }
    _inFlight++;
    return true;
  }

  void release() {
    if (_inFlight > 0) {
      _inFlight--;
    }
  }

  void reset() {
    _inFlight = 0;
  }
}

/// Thrown when a metadata probe is skipped because too many are already running.
class MetadataProbeLimitException implements Exception {
  const MetadataProbeLimitException();

  @override
  String toString() => 'MetadataProbeLimitException';
}
