import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/android/android_engine_bridge.dart';
import 'package:modern_downloader/core/android/netscape_cookie_codec.dart';
import 'package:modern_downloader/core/android/overlay_download_message.dart';
import 'package:modern_downloader/core/download/x_download_url.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:webview_flutter/webview_flutter.dart';

class XBrowserView extends ConsumerStatefulWidget {
  const XBrowserView({super.key});

  @override
  ConsumerState<XBrowserView> createState() => _XBrowserViewState();
}

class _XBrowserViewState extends ConsumerState<XBrowserView> {
  late final WebViewController _controller;
  late final TextEditingController _urlController;
  var _loading = true;
  var _overlayJs = '';

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: 'https://x.com');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel('MDAndroid', onMessageReceived: _onOverlayMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _urlController.text = url;
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (url) {
            _urlController.text = url;
            if (mounted) setState(() => _loading = false);
            unawaited(_injectOverlay());
          },
        ),
      );
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      _overlayJs = await rootBundle.loadString('assets/android/x_overlay.js');
    } catch (_) {
      _overlayJs = '';
    }
    await _controller.loadRequest(Uri.parse('https://x.com'));
  }

  Future<void> _injectOverlay() async {
    if (_overlayJs.isEmpty) return;
    try {
      await _controller.runJavaScript(_overlayJs);
    } catch (_) {}
  }

  Future<void> _onOverlayMessage(JavaScriptMessage message) async {
    try {
      final decoded = jsonDecode(message.message);
      final parsed = OverlayDownloadMessage.tryParse(decoded);
      if (parsed == null) return;
      final resolved = XDownloadUrl.resolveForDownload(
        parsed.url,
        parsed.pageUrl,
      );
      if (resolved == null) return;

      final cookies = await _cookiesFor(resolved);
      unawaited(
        ref
            .read(downloadListProvider.notifier)
            .startDownload(
              resolved,
              rawCookies: cookies,
              audioOnly: parsed.isAudioOnly ? true : null,
              preferredQuality: parsed.preferredQuality,
            ),
      );

      final ackId = parsed.id;
      if (ackId != null && ackId.isNotEmpty) {
        final js =
            '(function(){var cb=window.__MD_ACKS&&window.__MD_ACKS["$ackId"];'
            'if(cb){cb({ok:true});delete window.__MD_ACKS["$ackId"];}})();';
        await _controller.runJavaScript(js);
      }
    } catch (_) {}
  }

  Future<String?> _cookiesFor(String url) async {
    try {
      final header = await AndroidEngineBridge.instance.webViewCookies(url);
      if (header == null || header.trim().isEmpty) return null;
      final host = Uri.tryParse(url)?.host ?? 'x.com';
      return NetscapeCookieCodec.fromHeader(host: host, header: header);
    } catch (_) {
      return null;
    }
  }

  Future<void> _submitUrl() async {
    var raw = _urlController.text.trim();
    if (raw.isEmpty) return;
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'https://$raw';
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await _controller.loadRequest(uri);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Column(
      children: [
        Material(
          color: colors.surface.withValues(alpha: 0.92),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => _controller.goBack(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      IconButton(
                        tooltip: 'Forward',
                        onPressed: () => _controller.goForward(),
                        icon: const Icon(Icons.arrow_forward),
                      ),
                      IconButton(
                        tooltip: 'X.com',
                        onPressed: () {
                          _controller.loadRequest(Uri.parse('https://x.com'));
                        },
                        icon: const Icon(Icons.home_outlined),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'x.com',
                            filled: true,
                            fillColor: colors.background.withValues(alpha: 0.6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => _submitUrl(),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _controller.reload(),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.browseXHint,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
              ],
            ),
          ),
        ),
        Expanded(child: WebViewWidget(controller: _controller)),
      ],
    );
  }
}
