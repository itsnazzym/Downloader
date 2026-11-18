import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_video_cache_provider.dart';
import 'package:modern_downloader/features/archive/presentation/views/widgets/tiktok_video_card_player.dart';

class TikTokFeedView extends ConsumerStatefulWidget {
  final List<TikTokArchiveItem> videos;
  final int initialIndex;
  final VoidCallback? onClose;

  const TikTokFeedView({
    super.key,
    required this.videos,
    this.initialIndex = 0,
    this.onClose,
  });

  @override
  ConsumerState<TikTokFeedView> createState() => _TikTokFeedViewState();
}

class _TikTokFeedViewState extends ConsumerState<TikTokFeedView> {
  late PageController _pageController;
  late int _currentPage;
  bool _wheelNavigationPending = false;
  DateTime _lastWheelNavigation = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex
        .clamp(0, widget.videos.isEmpty ? 0 : widget.videos.length - 1)
        .toInt();
    _pageController = PageController(initialPage: _currentPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.videos.isNotEmpty) {
        ref
            .read(tiktokPreloadControllerProvider)
            .preloadAround(widget.videos, _currentPage, lookAhead: 3);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleWheelSignal(PointerSignalEvent event, int total) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (
      resolvedEvent,
    ) {
      final delta = (resolvedEvent as PointerScrollEvent).scrollDelta.dy;
      final now = DateTime.now();
      if (delta == 0 ||
          _wheelNavigationPending ||
          now.difference(_lastWheelNavigation) <
              const Duration(milliseconds: 280) ||
          !_pageController.hasClients) {
        return;
      }

      final target = (_currentPage + (delta > 0 ? 1 : -1))
          .clamp(0, total - 1)
          .toInt();
      if (target == _currentPage) return;
      _lastWheelNavigation = now;
      _wheelNavigationPending = true;
      unawaited(
        _pageController
            .animateToPage(
              target,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
            )
            .whenComplete(() => _wheelNavigationPending = false),
      );
    });
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

    return Listener(
      onPointerSignal: (event) => _handleWheelSignal(event, total),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                _currentPage < total - 1) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
              );
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                _currentPage > 0) {
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
          physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
          onPageChanged: (idx) {
            setState(() => _currentPage = idx);
            ref
                .read(tiktokPreloadControllerProvider)
                .preloadAround(widget.videos, idx, lookAhead: 3);
          },
          itemCount: total,
          itemBuilder: (context, index) {
            final item = widget.videos[index];
            return _buildTikTokPage(item, colors, index, total);
          },
        ),
      ),
    );
  }

  Widget _buildTikTokPage(
    TikTokArchiveItem item,
    AppColors colors,
    int index,
    int total,
  ) {
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
                bottom: 48,
                right: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.collectionName != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder_rounded,
                              size: 14,
                              color: colors.primary,
                            ),
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
                          const Icon(
                            Icons.bookmark_rounded,
                            size: 16,
                            color: Color(0xFFFE2C55),
                          ),
                        if (item.isLiked)
                          const Icon(
                            Icons.favorite_rounded,
                            size: 16,
                            color: Color(0xFFE91E63),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              if (widget.onClose != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton.filledTonal(
                    tooltip: 'Fermer le lecteur',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.55),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
