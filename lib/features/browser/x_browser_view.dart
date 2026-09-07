import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/android/android_engine_bridge.dart';
import 'package:modern_downloader/core/android/netscape_cookie_codec.dart';
import 'package:modern_downloader/core/android/overlay_download_message.dart';
import 'package:modern_downloader/core/download/x_download_url.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/add_download_dialog.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:go_router/go_router.dart';

class XBrowserView extends ConsumerStatefulWidget {
  const XBrowserView({super.key});

  @override
  ConsumerState<XBrowserView> createState() => _XBrowserViewState();
}

class _XBrowserViewState extends ConsumerState<XBrowserView> {
  WebViewController? _controller;
  late final TextEditingController _urlController;
  var _loading = true;
  var _overlayJs = '';

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: 'https://x.com');
    if (PlatformInfo.isMobile) {
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
    } else {
      _loading = false;
    }
  }

  Future<void> _bootstrap() async {
    if (_controller == null) return;
    try {
      _overlayJs = await rootBundle.loadString('assets/android/x_overlay.js');
    } catch (_) {
      _overlayJs = '';
    }
    await _controller?.loadRequest(Uri.parse('https://x.com'));
  }

  Future<void> _injectOverlay() async {
    if (_overlayJs.isEmpty || _controller == null) return;
    try {
      await _controller?.runJavaScript(_overlayJs);
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
        await _controller?.runJavaScript(js);
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
    await _controller?.loadRequest(uri);
  }

  Future<void> _openExternalUrl(String url) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
    } catch (e) {
      debugPrint('Failed to open external url: $e');
    }
  }

  void _openAddDownloadDialog([String? initialUrl]) {
    showDialog(
      context: context,
      builder: (context) => AddDownloadDialog(initialUrl: initialUrl),
    );
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

    if (_controller == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.travel_explore_rounded,
                          size: 32,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hub Médias & Téléchargement Universel',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Moteur universel : compatible avec plus de 1 800 sites web (TikTok, Reels, Shorts, X, Reddit, Vimeo, Twitch, etc.) et flux directs. L’extension navigateur injecte automatiquement un bouton propre sans pub sur n’importe quel site.',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Collez n’importe quel lien web ou flux vidéo (1 800+ sites pris en charge)...',
                              hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.7), fontSize: 13),
                              prefixIcon: Icon(Icons.link_rounded, color: colors.primary, size: 20),
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) _openAddDownloadDialog(val.trim());
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () {
                            final val = _urlController.text.trim();
                            _openAddDownloadDialog(val.isNotEmpty ? val : null);
                          },
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Télécharger', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          tooltip: 'Ouvrir dans le navigateur',
                          onPressed: () {
                            final val = _urlController.text.trim();
                            if (val.isNotEmpty) _openExternalUrl(val);
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          style: IconButton.styleFrom(
                            backgroundColor: colors.surfaceHighlight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 620;
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isNarrow ? 1 : 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: isNarrow ? 2.3 : 1.95,
                        children: [
                          _buildSocialCard(
                            context: context,
                            colors: colors,
                            title: 'Instagram Reels',
                            subtitle: 'Reels, vidéos verticales & publications',
                            badge: 'Reels',
                            color: const Color(0xFFE1306C),
                            icon: Icons.camera_alt_outlined,
                            url: 'https://www.instagram.com/reels/',
                          ),
                          _buildSocialCard(
                            context: context,
                            colors: colors,
                            title: 'TikTok',
                            subtitle: 'Flux Pour Toi, tendances & créateurs',
                            badge: 'Trends',
                            color: const Color(0xFF00F2FE),
                            icon: Icons.music_note_outlined,
                            url: 'https://www.tiktok.com',
                          ),
                          _buildSocialCard(
                            context: context,
                            colors: colors,
                            title: 'YouTube Shorts',
                            subtitle: 'Shorts, extraits vidéo & chaînes',
                            badge: 'Shorts',
                            color: const Color(0xFFFF0000),
                            icon: Icons.play_circle_outline_rounded,
                            url: 'https://www.youtube.com/shorts',
                          ),
                          _buildSocialCard(
                            context: context,
                            colors: colors,
                            title: 'X (Twitter)',
                            subtitle: 'Fil d’actualités & vidéos d’articles',
                            badge: 'X',
                            color: const Color(0xFF1DA1F2),
                            icon: Icons.alternate_email_rounded,
                            url: 'https://x.com/home',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildExtensionTipCard(context, colors),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final controller = _controller!;
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
                        onPressed: () => controller.goBack(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      IconButton(
                        tooltip: 'Forward',
                        onPressed: () => controller.goForward(),
                        icon: const Icon(Icons.arrow_forward),
                      ),
                      IconButton(
                        tooltip: 'X.com',
                        onPressed: () {
                          controller.loadRequest(Uri.parse('https://x.com'));
                        },
                        icon: const Icon(Icons.home_outlined),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'x.com, instagram, tiktok...',
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
                        onPressed: () => controller.reload(),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      _buildMobileQuickChip('X.com', 'https://x.com', colors),
                      const SizedBox(width: 8),
                      _buildMobileQuickChip('Instagram', 'https://www.instagram.com/reels/', colors),
                      const SizedBox(width: 8),
                      _buildMobileQuickChip('TikTok', 'https://www.tiktok.com', colors),
                      const SizedBox(width: 8),
                      _buildMobileQuickChip('Shorts', 'https://www.youtube.com/shorts', colors),
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
        Expanded(child: WebViewWidget(controller: controller)),
      ],
    );
  }

  Widget _buildMobileQuickChip(String label, String url, AppColors colors) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      backgroundColor: colors.surfaceHighlight,
      side: BorderSide(color: colors.border.withValues(alpha: 0.5)),
      onPressed: () {
        _urlController.text = url;
        _controller?.loadRequest(Uri.parse(url));
      },
    );
  }

  Widget _buildSocialCard({
    required BuildContext context,
    required AppColors colors,
    required String title,
    required String subtitle,
    required String badge,
    required Color color,
    required IconData icon,
    required String url,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              subtitle,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _openExternalUrl(url),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 15),
                  label: const Text('Ouvrir', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    backgroundColor: colors.surfaceHighlight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Télécharger un lien',
                onPressed: () => _openAddDownloadDialog(),
                icon: const Icon(Icons.download_rounded, size: 16),
                style: IconButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.15),
                  foregroundColor: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtensionTipCard(BuildContext context, AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.extension_outlined,
            color: colors.primary,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Extension Navigateur Intégrée',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'L’extension Modern Downloader supprime toutes les publicités et place les boutons de téléchargement dans une zone protégée sur vos Reels & Shorts.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_outlined, size: 16),
            label: const Text('Accueil', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
