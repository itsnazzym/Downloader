import 'dart:async';

/// One extension DOWNLOAD payload buffered for a short coalescing window.
class ExtensionDownloadIngest {
  const ExtensionDownloadIngest({
    required this.url,
    this.cookies,
    this.userAgent,
    this.isAudioOnly = false,
    this.isPlaylist = false,
    this.cookieBrowser,
    this.preferredQuality,
  });

  final String url;
  final String? cookies;
  final String? userAgent;
  final bool isAudioOnly;
  final bool isPlaylist;
  final String? cookieBrowser;
  final String? preferredQuality;
}

/// Buffers extension DOWNLOAD URLs for ~80–150ms, then flushes once.
class ExtensionDownloadBatcher {
  ExtensionDownloadBatcher({
    this.debounce = const Duration(milliseconds: 120),
    required this.onFlush,
    Timer Function(Duration duration, void Function() callback)? startTimer,
  }) : _startTimer = startTimer ?? Timer.new;

  final Duration debounce;
  final void Function(List<ExtensionDownloadIngest> batch) onFlush;
  final Timer Function(Duration duration, void Function() callback) _startTimer;

  final List<ExtensionDownloadIngest> _buffer = <ExtensionDownloadIngest>[];
  Timer? _timer;
  int _flushCount = 0;

  int get flushCount => _flushCount;
  int get pendingCount => _buffer.length;
  bool get isScheduled => _timer != null && _timer!.isActive;

  void add(ExtensionDownloadIngest item) {
    _buffer.add(item);
    if (_timer != null && _timer!.isActive) {
      return;
    }
    _timer = _startTimer(debounce, flush);
  }

  /// Flushes the current buffer immediately (also used by tests).
  void flush() {
    _timer?.cancel();
    _timer = null;
    if (_buffer.isEmpty) {
      return;
    }
    final batch = List<ExtensionDownloadIngest>.from(_buffer);
    _buffer.clear();
    _flushCount++;
    try {
      onFlush(batch);
    } catch (_) {
      // Caller/onFlush is responsible for its own error handling.
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _buffer.clear();
  }
}
