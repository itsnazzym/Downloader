import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:modern_downloader/core/utils/browser_launch.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/android/android_engine_bridge.dart';
import 'package:modern_downloader/core/android/media_sniffer_bridge.dart';
import 'package:modern_downloader/core/android/netscape_cookie_codec.dart';
import 'package:modern_downloader/core/android/overlay_download_message.dart';
import 'package:modern_downloader/core/download/download_url_policy.dart';
import 'package:modern_downloader/core/download/x_download_url.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/components/app_toast.dart';
import 'package:modern_downloader/core/ui/mobile/back_navigation.dart';
import 'package:modern_downloader/core/ui/mobile/oled/oled_kit.dart';
import 'package:modern_downloader/features/browser/sniff/sniffed_media.dart';
import 'package:modern_downloader/features/browser/sniff/sniffed_media_sheet.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/add_download_dialog.dart';
import 'package:modern_downloader/features/downloader/presentation/views/mobile/mobile_add_download_sheet.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:go_router/go_router.dart';

class XBrowserView extends ConsumerStatefulWidget {
  const XBrowserView({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  ConsumerState<XBrowserView> createState() => _XBrowserViewState();
}

class _XBrowserViewState extends ConsumerState<XBrowserView> {
  WebViewController? _controller;
  late final TextEditingController _urlController;
  var _loading = true;
  var _overlayJs = '';
  String _pageUrl = '';
  String? _pageTitle;

  // Media the page loaded, read from the native WebView client (Android).
  final _sniffer = MediaSnifferBridge();
  List<SniffedMedia> _sniffed = const [];
  Timer? _sniffTimer;
  VoidCallback? _unregisterBack;

  /// Back steps through the page history before leaving the tab.
  Future<bool> _goBackInPage() async {
    final controller = _controller;
    if (controller == null) return false;
    if (!await controller.canGoBack()) return false;
    await controller.goBack();
    return true;
  }

  @override
  void initState() {
    super.initState();
    _unregisterBack = ref
        .read(backInterceptorsProvider)
        .register(_goBackInPage);
    final startUrl = widget.initialUrl?.trim().isNotEmpty == true
        ? widget.initialUrl!.trim()
        : 'https://x.com';
    _urlController = TextEditingController(text: startUrl);
    if (PlatformInfo.isMobile) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel(
          'MDAndroid',
          onMessageReceived: _onOverlayMessage,
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              _urlController.text = url;
              if (mounted) {
                setState(() {
                  _loading = true;
                  _pageUrl = url;
                  _sniffed = const [];
                });
              }
            },
            onPageFinished: (url) {
              _urlController.text = url;
              if (mounted) {
                setState(() {
                  _loading = false;
                  _pageUrl = url;
                });
              }
              unawaited(_injectOverlay());
              unawaited(_readPageTitle());
            },
          ),
        );
      unawaited(_bootstrap());
      if (Platform.isAndroid) {
        _sniffTimer = Timer.periodic(
          const Duration(milliseconds: 1500),
          (_) => unawaited(_pollSniffer()),
        );
      }
    } else {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(XBrowserView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUrl != null &&
        widget.initialUrl != oldWidget.initialUrl &&
        widget.initialUrl!.trim().isNotEmpty) {
      final uri = Uri.tryParse(widget.initialUrl!.trim());
      if (uri != null) {
        _urlController.text = widget.initialUrl!.trim();
        _controller?.loadRequest(uri);
      }
    }
  }

  Future<void> _bootstrap() async {
    if (_controller == null) return;
    try {
      _overlayJs = await rootBundle.loadString('assets/android/x_overlay.js');
    } catch (_) {
      _overlayJs = '';
    }
    final target = widget.initialUrl?.trim().isNotEmpty == true
        ? widget.initialUrl!.trim()
        : 'https://x.com';
    final targetUri = Uri.tryParse(target) ?? Uri.parse('https://x.com');
    await _controller?.loadRequest(targetUri);
  }

  Future<void> _readPageTitle() async {
    try {
      final title = await _controller?.getTitle();
      if (mounted) setState(() => _pageTitle = title);
    } catch (_) {}
  }

  /// A page worth offering for download: a real address on a supported site
  /// that is not just the site's home page.
  bool _isCapturable(String url, {required bool includeAdult}) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    if (uri.path.isEmpty || uri.path == '/') return false;
    return DownloadUrlPolicy.isAllowed(url, includeAdult: includeAdult);
  }

  Future<void> _pollSniffer() async {
    final platform = _controller?.platform;
    if (!mounted || platform is! AndroidWebViewController) return;
    // Idempotent: also re-wraps the client if the plugin replaced it.
    if (!await _sniffer.attach(platform.webViewIdentifier)) return;
    final list = await _sniffer.streams();
    if (!mounted) return;
    final changed =
        list.length != _sniffed.length ||
        (list.isNotEmpty && list.first.url != _sniffed.first.url);
    if (changed) setState(() => _sniffed = list);
  }

  Future<void> _downloadSniffed(SniffedMedia media) async {
    final l10n = context.l10n;
    final page = media.page.isNotEmpty ? media.page : _pageUrl;
    final cookies = await _sniffer.sessionCookies(media);
    final title = (_pageTitle ?? '').trim();
    final stem = TitleCleanerService.filenameStem(
      title.isEmpty ? media.host : title,
    );
    final tag = media.url.hashCode.toRadixString(36);
    if (!mounted) return;
    await ref
        .read(downloadListProvider.notifier)
        .startDownload(
          page,
          forceStreamUrl: media.url,
          customFilename: '$stem [$tag].%(ext)s',
          rawCookies: cookies,
          userAgent: (media.userAgent ?? '').isEmpty ? null : media.userAgent,
          audioOnly: media.kind == SniffedKind.audio ? true : null,
        );
    if (mounted) AppToast.showSuccess(context, l10n.downloadStarted);
  }

  Future<void> _captureCurrentPage() async {
    final url = _pageUrl;
    if (url.isEmpty) return;
    final cookies = await _cookiesFor(url);
    if (!mounted) return;
    await MobileAddDownloadSheet.show(
      context,
      initialUrl: url,
      initialCookies: cookies,
    );
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
      await openInBrowser(url);
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
    _sniffTimer?.cancel();
    _unregisterBack?.call();
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
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    // Material's default; the theme's
                                    // headlineSmall is 20 px for dialogs.
                                    fontSize: 24,
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
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText:
                                  'Collez n’importe quel lien web ou flux vidéo (1 800+ sites pris en charge)...',
                              hintStyle: TextStyle(
                                color: colors.textSecondary.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.link_rounded,
                                color: colors.primary,
                                size: 20,
                              ),
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) {
                                _openAddDownloadDialog(val.trim());
                              }
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
                          label: const Text(
                            'Télécharger',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
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
    final t = OledTokens.of(context);
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.browserMobileTitle,
                          style: OledText.title(context),
                        ),
                      ),
                      OledIconButton(
                        tooltip: l10n.browserMobileBack,
                        outlined: false,
                        onPressed: () => controller.goBack(),
                        icon: Icons.arrow_back_rounded,
                      ),
                      OledIconButton(
                        tooltip: l10n.browserMobileForward,
                        outlined: false,
                        onPressed: () => controller.goForward(),
                        icon: Icons.arrow_forward_rounded,
                      ),
                      OledIconButton(
                        tooltip: 'X.com',
                        outlined: false,
                        onPressed: () {
                          controller.loadRequest(Uri.parse('https://x.com'));
                        },
                        icon: Icons.home_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.only(left: 16, right: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: t.lineStrong),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: t.ink2,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _urlController,
                              style: OledText.ui(context, size: 15),
                              cursorColor: t.ink,
                              maxLines: 1,
                              decoration: InputDecoration(
                                isDense: true,
                                filled: false,
                                hintText: 'x.com, instagram, tiktok...',
                                hintStyle: OledText.ui(
                                  context,
                                  size: 15,
                                  color: t.ink3,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (_) => _submitUrl(),
                            ),
                          ),
                          OledIconButton(
                            tooltip: l10n.browserMobileReload,
                            outlined: false,
                            onPressed: () => controller.reload(),
                            icon: Icons.refresh_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 2,
                    child: _loading
                        ? LinearProgressIndicator(
                            minHeight: 2,
                            backgroundColor: t.line,
                            valueColor: AlwaysStoppedAnimation<Color>(t.ink),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildMobileQuickChip('X.com', 'https://x.com'),
                        const SizedBox(width: 8),
                        _buildMobileQuickChip(
                          'Instagram',
                          'https://www.instagram.com/reels/',
                        ),
                        const SizedBox(width: 8),
                        _buildMobileQuickChip(
                          'TikTok',
                          'https://www.tiktok.com',
                        ),
                        const SizedBox(width: 8),
                        _buildMobileQuickChip(
                          'Shorts',
                          'https://www.youtube.com/shorts',
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
                    child: Text(
                      l10n.browseXHint,
                      style: OledText.ui(context, size: 12, color: t.ink2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.line)),
              ),
              child: WebViewWidget(controller: controller),
            ),
          ),
          if (_sniffed.isNotEmpty ||
              _isCapturable(
                _pageUrl,
                includeAdult: ref.watch(settingsProvider).adultSitesEnabled,
              ))
            _buildCaptureBar(context, t),
        ],
      ),
    );
  }

  Widget _buildCaptureBar(BuildContext context, OledTokens t) {
    final l10n = context.l10n;
    final host = Uri.tryParse(_pageUrl)?.host.replaceFirst('www.', '') ?? '';
    final title = (_pageTitle ?? '').trim();
    final capturable = _isCapturable(
      _pageUrl,
      includeAdult: ref.watch(settingsProvider).adultSitesEnabled,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 14, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _sniffed.isNotEmpty
                        ? l10n.browserSniffCount(_sniffed.length)
                        : l10n.browserMobileReadyToDownload,
                    style: OledText.ui(context, size: 12, color: t.ink2),
                  ),
                  Text(
                    title.isEmpty ? host : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OledText.ui(
                      context,
                      size: 14,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (_sniffed.isNotEmpty)
              OledButton(
                label: l10n.browserSniffOpen,
                filled: !capturable,
                onPressed: () => SniffedMediaSheet.show(
                  context,
                  items: _sniffed,
                  onPick: (m) => unawaited(_downloadSniffed(m)),
                ),
                expand: false,
                height: 44,
              ),
            if (_sniffed.isNotEmpty && capturable) const SizedBox(width: 8),
            if (capturable)
              OledButton(
                label: l10n.browserMobileDownload,
                onPressed: _captureCurrentPage,
                expand: false,
                height: 44,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileQuickChip(String label, String url) {
    return OledChip(
      label: label,
      selected: false,
      onTap: () {
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
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
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
          Icon(Icons.extension_outlined, color: colors.primary, size: 28),
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
