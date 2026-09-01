import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../logger/logger_service.dart';
import 'share_url_extractor.dart';

/// Receives `ACTION_SEND` / `ACTION_VIEW` payloads from the Android share sheet.
class AndroidShareService {
  AndroidShareService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methods =
           methodChannel ??
           const MethodChannel('com.downloader.modern_downloader/share'),
       _events =
           eventChannel ??
           const EventChannel('com.downloader.modern_downloader/shareEvents');

  static final AndroidShareService instance = AndroidShareService();

  final MethodChannel _methods;
  final EventChannel _events;
  final _controller = StreamController<String>.broadcast();
  StreamSubscription<dynamic>? _sub;
  bool _listening = false;

  Stream<String> get urlStream => _controller.stream;

  void start() {
    if (!Platform.isAndroid || _listening) return;
    _listening = true;
    _sub = _events.receiveBroadcastStream().listen(
      (event) {
        final url = ShareUrlExtractor.extract(event?.toString());
        if (url != null) _controller.add(url);
      },
      onError: (Object e) {
        LoggerService.w('Share event error: $e');
      },
    );
    unawaited(_consumeInitial());
  }

  Future<String?> peekInitialUrl() async {
    if (!Platform.isAndroid) return null;
    try {
      final raw = await _methods.invokeMethod<String>('takeInitialSharedText');
      return ShareUrlExtractor.extract(raw);
    } on PlatformException catch (e) {
      LoggerService.w('takeInitialSharedText failed: $e');
      return null;
    }
  }

  Future<void> _consumeInitial() async {
    final url = await peekInitialUrl();
    if (url != null) _controller.add(url);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _listening = false;
  }
}
