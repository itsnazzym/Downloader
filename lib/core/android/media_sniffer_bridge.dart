import 'package:flutter/services.dart';
import 'package:modern_downloader/core/android/android_engine_bridge.dart';
import 'package:modern_downloader/core/android/netscape_cookie_codec.dart';
import 'package:modern_downloader/core/logger/logger_service.dart';
import 'package:modern_downloader/features/browser/sniff/sniffed_media.dart';

/// Android only: reads the media addresses the in-app browser's page loaded
/// (see `SnifferPlugin.kt`).
class MediaSnifferBridge {
  MediaSnifferBridge({MethodChannel? channel, AndroidEngineBridge? engine})
    : _channel =
          channel ??
          const MethodChannel('com.downloader.modern_downloader/sniffer'),
      _engine = engine;

  final MethodChannel _channel;
  final AndroidEngineBridge? _engine;

  AndroidEngineBridge get _bridge => _engine ?? AndroidEngineBridge.instance;

  /// Starts recording for the WebView with this plugin identifier.
  Future<bool> attach(int webViewIdentifier) async {
    try {
      return await _channel.invokeMethod<bool>('attach', {
            'id': webViewIdentifier,
          }) ??
          false;
    } on PlatformException catch (e) {
      LoggerService.w('Sniffer attach failed: $e');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Everything seen since the page started loading, best first.
  Future<List<SniffedMedia>> streams() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('streams');
      if (raw == null) return const [];
      return SniffedMediaFilter.rank([
        for (final e in raw)
          if (e is Map) SniffedMedia.fromMap(e),
      ]);
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } on PlatformException {
      // Nothing to clear.
    } on MissingPluginException {
      // Not on Android.
    }
  }

  /// The browser session as a cookies.txt body covering the page and the
  /// stream hosts: CDNs often sit on another domain than the page.
  Future<String?> sessionCookies(SniffedMedia media) async {
    final bodies = <String>[];
    for (final url in [media.page, media.url]) {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.host.isEmpty) continue;
      final header = await _bridge.webViewCookies(url);
      if (header == null || header.trim().isEmpty) continue;
      bodies.add(
        NetscapeCookieCodec.fromHeader(host: uri.host, header: header.trim()),
      );
    }
    if (bodies.isEmpty) return null;
    return SniffedMediaFilter.mergeNetscape(bodies);
  }
}
