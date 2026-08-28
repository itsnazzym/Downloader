import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logger/logger_service.dart';
import '../providers/settings_provider.dart';

// Provider for easy access
final clipboardServiceProvider = Provider<ClipboardService>((ref) {
  return ClipboardService(ref);
});

class ClipboardService {
  final Ref _ref;
  Timer? _timer;
  String? _lastContent;
  bool _started = false;
  bool _listeningToSettings = false;

  final _controller = StreamController<String>.broadcast();
  Stream<String> get clipboardStream => _controller.stream;

  ClipboardService(this._ref);

  @visibleForTesting
  bool get isTimerActive => _timer != null && _timer!.isActive;

  void startMonitoring() async {
    _started = true;
    _ensureSettingsListener();

    // Initialize with current content to avoid immediate notification on startup
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null) {
        _lastContent = data.text!.trim();
      }
    } catch (_) {
      // Ignore platform channel errors during bootstrap
    }

    if (!_started) return;
    _syncTimerWithSetting();
  }

  void stopMonitoring() {
    _started = false;
    _stopTimer();
    LoggerService.i('Clipboard monitoring stopped');
  }

  void _ensureSettingsListener() {
    if (_listeningToSettings) return;
    _listeningToSettings = true;
    _ref.listen<bool>(
      settingsProvider.select((s) => s.clipboardMonitorEnabled),
      (previous, next) {
        if (!_started) return;
        if (previous == next) return;
        _syncTimerWithSetting();
      },
    );
  }

  void _syncTimerWithSetting() {
    if (!_started) {
      _stopTimer();
      return;
    }

    final enabled = _ref.read(settingsProvider).clipboardMonitorEnabled;
    if (enabled) {
      if (_timer != null && _timer!.isActive) return;
      _timer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _checkClipboard(),
      );
      LoggerService.i('Clipboard monitoring started');
      return;
    }

    final wasRunning = _timer != null;
    _stopTimer();
    if (wasRunning) {
      LoggerService.i('Clipboard monitoring stopped');
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkClipboard() async {
    // Check if monitoring is enabled in settings
    final enabled = _ref.read(settingsProvider).clipboardMonitorEnabled;
    if (!enabled) return;

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data == null || data.text == null) return;

      final content = data.text!.trim();

      // Optimization: Don't re-process the same content
      if (content == _lastContent) return;
      _lastContent = content;

      if (_isValidUrl(content)) {
        LoggerService.debug('Clipboard match found: $content');
        _controller.add(content);
      }
    } catch (e) {
      // Ignore platform channel errors
    }
  }

  bool _isValidUrl(String text) {
    if (text.isEmpty) return false;

    // Basic supported domains check
    final supported = [
      'youtube.com',
      'youtu.be',
      'twitter.com',
      'x.com',
      'instagram.com',
      'twitch.tv',
      'tiktok.com',
      'kick.com',
      'vimeo.com',
      'dailymotion.com',
      'facebook.com',
      'reddit.com',
      'soundcloud.com',
    ];

    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      return false;
    }

    return supported.any((domain) => text.contains(domain));
  }
}
