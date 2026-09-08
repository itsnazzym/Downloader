import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/theme/app_typography.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/add_download_dialog.dart';

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

  String _getPlatformLabel(String url) {
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
    return 'Lien média';
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
    showDialog(
      context: context,
      builder: (context) => AddDownloadDialog(initialUrl: url),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformInfo.isMobile || !_isVisible || _detectedUrl == null) {
      return const SizedBox.shrink();
    }

    final colors = AppColors.of(context);
    final platform = _getPlatformLabel(_detectedUrl!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.primary.withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Text(
                platform,
                style: AppTypography.mono.copyWith(
                  color: colors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _detectedUrl!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: _openDownloadDialog,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Télécharger',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              color: colors.textSecondary,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: _dismiss,
            ),
          ],
        ),
      ),
    );
  }
}
