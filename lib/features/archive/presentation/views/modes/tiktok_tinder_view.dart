import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_video_cache_provider.dart';
import 'package:modern_downloader/features/archive/presentation/views/widgets/tiktok_video_card_player.dart';

class TikTokTinderView extends ConsumerStatefulWidget {
  final List<TikTokArchiveItem> videos;

  const TikTokTinderView({super.key, required this.videos});

  @override
  ConsumerState<TikTokTinderView> createState() => _TikTokTinderViewState();
}

class _TikTokTinderViewState extends ConsumerState<TikTokTinderView> {
  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;
  final List<int> _history = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.videos.isNotEmpty) {
        ref.read(tiktokPreloadControllerProvider).preloadAround(
          widget.videos,
          _currentIndex,
          lookAhead: 3,
        );
      }
    });
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

  void _swipeRight() {
    if (_currentIndex >= widget.videos.length) return;
    final item = widget.videos[_currentIndex];
    final notifier = ref.read(tikTokArchiveProvider.notifier);

    _showNotice('Téléchargement lancé : ${item.id}');
    notifier.downloadBatch([item], limit: 1);

    _history.add(_currentIndex);
    setState(() {
      _currentIndex++;
      _dragOffset = Offset.zero;
    });
    ref.read(tiktokPreloadControllerProvider).preloadAround(
      widget.videos,
      _currentIndex,
      lookAhead: 3,
    );
  }

  void _swipeLeft() {
    if (_currentIndex >= widget.videos.length) return;
    _history.add(_currentIndex);
    setState(() {
      _currentIndex++;
      _dragOffset = Offset.zero;
    });
    ref.read(tiktokPreloadControllerProvider).preloadAround(
      widget.videos,
      _currentIndex,
      lookAhead: 3,
    );
  }

  void _undo() {
    if (_history.isNotEmpty) {
      setState(() {
        _currentIndex = _history.removeLast();
        _dragOffset = Offset.zero;
      });
    }
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

    if (_currentIndex >= total) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Vous avez parcouru toutes les vidéos !',
              style: AppTypography.h2.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => setState(() => _currentIndex = 0),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Recommencer'),
            ),
          ],
        ),
      );
    }

    final currentVideo = widget.videos[_currentIndex];
    final nextVideo = _currentIndex + 1 < total ? widget.videos[_currentIndex + 1] : null;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = math.min(screenWidth * 0.85, 420.0);
    final cardHeight = math.min(MediaQuery.sizeOf(context).height * 0.65, 540.0);

    final rotationAngle = (_dragOffset.dx / cardWidth) * (math.pi / 12);
    final isSwipingRight = _dragOffset.dx > 40;
    final isSwipingLeft = _dragOffset.dx < -40;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _swipeLeft();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _swipeRight();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          // Top Progress Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Mode Tinder : Vidéo ${_currentIndex + 1} / $total',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  'Gauche = Passer | Droite = Télécharger',
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: colors.textDisabled,
                  ),
                ),
              ],
            ),
          ),

          // Tinder Stack Area
          Expanded(
            child: Center(
              child: SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background Next Card
                    if (nextVideo != null)
                      Transform.scale(
                        scale: 0.94,
                        child: _buildCardContent(nextVideo, colors, isTopCard: false),
                      ),

                    // Top Draggable Card
                    GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _dragOffset += details.delta;
                        });
                      },
                      onPanEnd: (details) {
                        if (_dragOffset.dx > 100) {
                          _swipeRight();
                        } else if (_dragOffset.dx < -100) {
                          _swipeLeft();
                        } else {
                          setState(() => _dragOffset = Offset.zero);
                        }
                      },
                      child: Transform.translate(
                        offset: _dragOffset,
                        child: Transform.rotate(
                          angle: rotationAngle,
                          child: Stack(
                            children: [
                              _buildCardContent(currentVideo, colors, isTopCard: true),

                              // Green LIKE / DOWNLOAD Stamp
                              if (isSwipingRight)
                                Positioned(
                                  top: 30,
                                  left: 30,
                                  child: Transform.rotate(
                                    angle: -math.pi / 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.greenAccent, width: 3),
                                        borderRadius: BorderRadius.circular(10),
                                        color: Colors.black.withValues(alpha: 0.6),
                                      ),
                                      child: const Text(
                                        'TÉLÉCHARGER',
                                        style: TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              // Red NOPE / PASS Stamp
                              if (isSwipingLeft)
                                Positioned(
                                  top: 30,
                                  right: 30,
                                  child: Transform.rotate(
                                    angle: math.pi / 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.redAccent, width: 3),
                                        borderRadius: BorderRadius.circular(10),
                                        color: Colors.black.withValues(alpha: 0.6),
                                      ),
                                      child: const Text(
                                        'PASSER',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Dock
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Undo Button
                IconButton.filledTonal(
                  onPressed: _history.isNotEmpty ? _undo : null,
                  icon: const Icon(Icons.undo_rounded, size: 22),
                  tooltip: 'Annuler (Précédent)',
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(width: 20),

                // Pass Button (Swipe Left)
                IconButton.filled(
                  onPressed: _swipeLeft,
                  icon: const Icon(Icons.close_rounded, size: 28),
                  tooltip: 'Passer (Flèche Gauche)',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(18),
                  ),
                ),
                const SizedBox(width: 20),

                // Download Button (Swipe Right)
                IconButton.filled(
                  onPressed: _swipeRight,
                  icon: const Icon(Icons.download_rounded, size: 28),
                  tooltip: 'Télécharger (Flèche Droite)',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.greenAccent[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(18),
                  ),
                ),
                const SizedBox(width: 20),

                // Open in browser button
                IconButton.filledTonal(
                  onPressed: () => _openUrl(currentVideo.url),
                  icon: const Icon(Icons.open_in_new_rounded, size: 22),
                  tooltip: 'Ouvrir sur TikTok',
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent(TikTokArchiveItem item, AppColors colors, {required bool isTopCard}) {
    final y = item.date.year;
    final m = item.date.month.toString().padLeft(2, '0');
    final d = item.date.day.toString().padLeft(2, '0');

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTopCard ? colors.border : colors.borderSubtle,
          width: 1.5,
        ),
        boxShadow: colors.tintedShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Video Graphic Area
            Expanded(
              child: Container(
                color: colors.background,
                child: isTopCard
                    ? TikTokVideoCardPlayer(
                        video: item,
                        isActive: true,
                        onNext: _swipeLeft,
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.play_circle_fill_rounded,
                            size: 80,
                            color: colors.textDisabled.withValues(alpha: 0.3),
                          ),
                          Positioned(
                            top: 14,
                            left: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: colors.surface.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: colors.borderSubtle),
                              ),
                              child: Text(
                                '$y-$m-$d',
                                style: AppTypography.mono.copyWith(fontSize: 11),
                              ),
                            ),
                          ),
                          if (item.collectionName != null)
                            Positioned(
                              top: 14,
                              right: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: colors.primary.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.folder_rounded, size: 12, color: colors.primary),
                                    const SizedBox(width: 4),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 160),
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
                            ),
                        ],
                      ),
              ),
            ),

            // Bottom Information Area
            Container(
              padding: const EdgeInsets.all(16),
              color: colors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'TikTok ID: ${item.id}',
                        style: AppTypography.mono.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (item.isFavorite) ...[
                        const Icon(Icons.bookmark_rounded, size: 18, color: Color(0xFFFE2C55)),
                        const SizedBox(width: 4),
                      ],
                      if (item.isLiked) ...[
                        const Icon(Icons.favorite_rounded, size: 18, color: Color(0xFFE91E63)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.url,
                    style: AppTypography.caption.copyWith(color: colors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
