import 'dart:async';

import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

/// UI / WebSocket progress coalescing interval.
const Duration kProgressThrottleInterval = Duration(milliseconds: 250);

/// Statuses that should flush immediately (not coalesced with progress ticks).
bool isImmediateFlushStatus(DownloadStatus status) {
  switch (status) {
    case DownloadStatus.completed:
    case DownloadStatus.failed:
    case DownloadStatus.canceled:
    case DownloadStatus.duplicate:
    case DownloadStatus.paused:
    case DownloadStatus.queued:
      return true;
    case DownloadStatus.downloading:
    case DownloadStatus.extracting:
    case DownloadStatus.processing:
      return false;
  }
}

/// Statuses that should rebuild library stats (terminal only).
bool isStatsRebuildStatus(DownloadStatus status) {
  switch (status) {
    case DownloadStatus.completed:
    case DownloadStatus.failed:
    case DownloadStatus.canceled:
    case DownloadStatus.duplicate:
      return true;
    case DownloadStatus.paused:
    case DownloadStatus.queued:
    case DownloadStatus.downloading:
    case DownloadStatus.extracting:
    case DownloadStatus.processing:
      return false;
  }
}

/// Trailing-edge coalescing throttle: many [schedule] calls → one [onFlush].
class CoalescingThrottle {
  CoalescingThrottle({
    this.interval = kProgressThrottleInterval,
    required this.onFlush,
    Timer Function(Duration duration, void Function() callback)? startTimer,
  }) : _startTimer = startTimer ?? Timer.new;

  final Duration interval;
  final void Function() onFlush;
  final Timer Function(Duration duration, void Function() callback) _startTimer;
  Timer? _timer;
  int _scheduleCount = 0;
  int _flushCount = 0;

  int get scheduleCount => _scheduleCount;
  int get flushCount => _flushCount;
  bool get isScheduled => _timer != null && _timer!.isActive;

  void schedule() {
    _scheduleCount++;
    if (_timer != null && _timer!.isActive) {
      return;
    }
    _timer = _startTimer(interval, () {
      _timer = null;
      _flushCount++;
      onFlush();
    });
  }

  void flushNow() {
    _timer?.cancel();
    _timer = null;
    _flushCount++;
    onFlush();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Drops WebSocket PROGRESS payloads unless percent/status changed and the
/// throttle interval has elapsed. Terminal statuses always send.
class ProgressBroadcastFilter {
  ProgressBroadcastFilter({
    this.interval = kProgressThrottleInterval,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration interval;
  final DateTime Function() _clock;
  final Map<String, DateTime> _lastSentAt = <String, DateTime>{};
  final Map<String, String> _lastKey = <String, String>{};

  bool shouldSend({
    required String id,
    required DownloadStatus status,
    required double progress,
  }) {
    try {
      if (isImmediateFlushStatus(status)) {
        _lastKey.remove(id);
        _lastSentAt.remove(id);
        return true;
      }
      final percent = (progress * 100).floor().clamp(0, 100);
      final key = '${status.index}:$percent';
      final now = _clock();
      if (_lastKey[id] == key) {
        return false;
      }
      final last = _lastSentAt[id];
      if (last != null && now.difference(last) < interval) {
        return false;
      }
      _lastKey[id] = key;
      _lastSentAt[id] = now;
      return true;
    } catch (_) {
      return true;
    }
  }
}
