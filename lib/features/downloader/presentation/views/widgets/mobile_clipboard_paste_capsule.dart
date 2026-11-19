import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:modern_downloader/core/ui/mobile/oled/oled_kit.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/mobile/mobile_add_download_sheet.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

/// Floating smart clipboard capsule for Android & mobile.
/// Automatically detects media links in the clipboard and offers a 1-tap download flow.
class MobileClipboardPasteCapsule extends ConsumerStatefulWidget {
  const MobileClipboardPasteCapsule({super.key});

  @override
  ConsumerState<MobileClipboardPasteCapsule> createState() =>
      _MobileClipboardPasteCapsuleState();
}

class _MobileClipboardPasteCapsuleState
    extends ConsumerState<MobileClipboardPasteCapsule>
    with WidgetsBindingObserver {
  String? _detectedUrl;
  static String? _dismissedUrl;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (PlatformInfo.isMobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && PlatformInfo.isMobile) {
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return;

      if (!_isValidMediaUrl(text)) return;
      if (text == _dismissedUrl) return;

      // Check if URL is already downloading or in list
      final downloads = ref.read(downloadListProvider).valueOrNull ?? [];
      final alreadyAdded = downloads.any((d) => d.request.url == text);
      if (alreadyAdded) return;

      if (mounted && text != _detectedUrl) {
        setState(() {
          _detectedUrl = text;
          _isVisible = true;
        });
      }
    } catch (_) {
      // Ignore clipboard access errors
    }
  }

  bool _isValidMediaUrl(String text) {
    final uri = Uri.tryParse(text);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return false;
    }
    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('twitter.com') ||
        host.contains('x.com') ||
        host.contains('tiktok.com') ||
        host.contains('instagram.com') ||
        host.contains('reddit.com') ||
        host.contains('facebook.com') ||
        host.contains('fb.watch') ||
        host.contains('vimeo.com') ||
        host.contains('twitch.tv') ||
        host.contains('soundcloud.com') ||
        uri.path.endsWith('.mp4') ||
        uri.path.endsWith('.mkv') ||
        uri.path.endsWith('.mp3') ||
        uri.path.endsWith('.webm');
  }

  String _getPlatformLabel(AppLocalizations l10n, String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      return 'YouTube';
    }
    if (host.contains('twitter.com') || host.contains('x.com')) {
      return 'X / Twitter';
    }
    if (host.contains('tiktok.com')) return 'TikTok';
    if (host.contains('instagram.com')) return 'Instagram';
    if (host.contains('reddit.com')) return 'Reddit';
    if (host.contains('vimeo.com')) return 'Vimeo';
    if (host.contains('soundcloud.com')) return 'SoundCloud';
    return l10n.clipboardCapsuleMediaLink;
  }

  void _dismiss() {
    HapticFeedback.lightImpact();
    setState(() {
      _isVisible = false;
      _dismissedUrl = _detectedUrl;
    });
  }

  void _openDownloadDialog() {
    final url = _detectedUrl;
    if (url == null) return;
    HapticFeedback.mediumImpact();
    _dismiss();
    unawaited(MobileAddDownloadSheet.show(context, initialUrl: url));
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformInfo.isMobile || !_isVisible || _detectedUrl == null) {
      return const SizedBox.shrink();
    }

    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final platform = _getPlatformLabel(l10n, _detectedUrl!);
    final host = Uri.tryParse(_detectedUrl!)?.host.replaceFirst('www.', '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: OledCard(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        child: Row(
          children: [
            Icon(Icons.content_paste_go_rounded, size: 18, color: t.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.clipboardCapsuleCopied(platform),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OledText.ui(
                      context,
                      size: 13,
                      weight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    host ?? _detectedUrl!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OledText.ui(context, size: 12, color: t.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OledButton(
              label: l10n.clipboardCapsuleDownload,
              onPressed: _openDownloadDialog,
              expand: false,
              height: 40,
            ),
            OledIconButton(
              icon: Icons.close_rounded,
              tooltip: l10n.clipboardCapsuleDismiss,
              outlined: false,
              color: t.ink2,
              onPressed: _dismiss,
            ),
          ],
        ),
      ),
    );
  }
}
