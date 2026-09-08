import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_video_cache_provider.dart';
import 'package:modern_downloader/features/archive/presentation/views/widgets/tiktok_video_card_player.dart';

class TikTokFeedView extends ConsumerStatefulWidget {
  final List<TikTokArchiveItem> videos;

  const TikTokFeedView({super.key, required this.videos});

  @override
  ConsumerState<TikTokFeedView> createState() => _TikTokFeedViewState();
}

class _TikTokFeedViewState extends ConsumerState<TikTokFeedView> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.videos.isNotEmpty) {
        ref.read(tiktokPreloadControllerProvider).preloadAround(
          widget.videos,
          _currentPage,
          lookAhead: 3,
        );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final total = widget.videos.length;

    if (total == 0) {
      return Center(
        child: Text(
          'Aucune vidéo à afficher',
          style: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
      );
    }

    if (_currentPage >= total && total > 0) {
      _currentPage = total - 1;
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown && _currentPage < total - 1) {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
            );
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp && _currentPage > 0) {
            _pageController.previousPage(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
            );
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (idx) {
          setState(() => _currentPage = idx);
          ref.read(tiktokPreloadControllerProvider).preloadAround(
            widget.videos,
            idx,
            lookAhead: 3,
          );
        },
        itemCount: total,
        itemBuilder: (context, index) {
          final item = widget.videos[index];
          return _buildTikTokPage(item, colors, index, total);
        },
      ),
    );
  }

  Widget _buildTikTokPage(TikTokArchiveItem item, AppColors colors, int index, int total) {
    final y = item.date.year;
    final m = item.date.month.toString().padLeft(2, '0');
    final d = item.date.day.toString().padLeft(2, '0');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.borderSubtle),
            boxShadow: colors.tintedShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Main Video Area: Native Accelerated Player with Lazy Load & Preload
              TikTokVideoCardPlayer(
                video: item,
                isActive: index == _currentPage,
                onNext: index < total - 1
                    ? () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        )
                    : null,
                onPrevious: index > 0
                    ? () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        )
                    : null,
              ),

              // Bottom gradient scrim for high readability over video
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 140,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Metadata Overlay
              Positioned(
                left: 18,
                bottom: 20,
                right: 70,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.collectionName != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_rounded, size: 14, color: colors.primary),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                item.collectionName!,
                                style: AppTypography.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.primary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Text(
                          'Ajouté le $y-$m-$d',
                          style: AppTypography.mono.copyWith(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (item.isFavorite)
                          const Icon(Icons.bookmark_rounded, size: 16, color: Color(0xFFFE2C55)),
                        if (item.isLiked)
                          const Icon(Icons.favorite_rounded, size: 16, color: Color(0xFFE91E63)),
                      ],
                    ),
                  ],
                ),
              ),

              // Right Floating Actions Column (TikTok style!)
              Positioned(
                right: 14,
                bottom: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Index Counter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.background.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${index + 1}\n$total',
                        textAlign: TextAlign.center,
                        style: AppTypography.mono.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Download Button
                    IconButton.filled(
                      onPressed: () async {
                        _showNotice('Téléchargement lancé : ${item.id}');
                        await ref.read(tikTokArchiveProvider.notifier).downloadBatch([item], limit: 1);
                      },
                      icon: const Icon(Icons.download_rounded, size: 22),
                      tooltip: 'Télécharger cette vidéo',
                      style: IconButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Copy Link Button
                    IconButton.filledTonal(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: item.url));
                        _showNotice('Lien copié');
                      },
                      icon: const Icon(Icons.link_rounded, size: 20),
                      tooltip: 'Copier le lien',
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Open Browser Button
                    IconButton.filledTonal(
                      onPressed: () => _openUrl(item.url),
                      icon: const Icon(Icons.open_in_new_rounded, size: 20),
                      tooltip: 'Ouvrir dans le navigateur',
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Next Arrow Hint
                    if (index < total - 1)
                      IconButton(
                        onPressed: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        ),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                        tooltip: 'Suivant (Flèche Bas)',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
