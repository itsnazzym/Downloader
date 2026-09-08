import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_video_cache_provider.dart';

class TikTokVideoCardPlayer extends ConsumerStatefulWidget {
  final TikTokArchiveItem video;
  final bool isActive;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const TikTokVideoCardPlayer({
    super.key,
    required this.video,
    required this.isActive,
    this.onNext,
    this.onPrevious,
  });

  @override
  ConsumerState<TikTokVideoCardPlayer> createState() => _TikTokVideoCardPlayerState();
}

class _TikTokVideoCardPlayerState extends ConsumerState<TikTokVideoCardPlayer> {
  Player? _player;
  VideoController? _controller;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool _isPlaying = false;
  bool _showActionIcon = false;
  IconData _actionIcon = Icons.play_arrow_rounded;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _loadedPath;

  @override
  void initState() {
    super.initState();
    _requestPlaybackIfNeeded();
  }

  void _requestPlaybackIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(tiktokPreloadControllerProvider).requestVideo(
        widget.video.id,
        highPriority: widget.isActive,
      );
    });
  }

  void _initPlayer(String filePath) {
    if (_loadedPath == filePath && _player != null) {
      if (widget.isActive && !_isPlaying) {
        _player?.play();
      }
      return;
    }

    _disposePlayer();

    final isMuted = ref.read(tiktokMutedProvider);
    final player = Player();
    final controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
        hwdec: 'auto-copy',
      ),
    );

    _player = player;
    _controller = controller;
    _loadedPath = filePath;

    _subscriptions.add(player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    }));

    _subscriptions.add(player.stream.position.listen((pos) {
      if (mounted) setState(() => _position = pos);
    }));

    _subscriptions.add(player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    }));

    player.setPlaylistMode(PlaylistMode.loop);
    player.setVolume(isMuted ? 0.0 : 100.0);
    player.open(Media(filePath), play: widget.isActive);
  }

  void _disposePlayer() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    _player?.dispose();
    _player = null;
    _controller = null;
    _loadedPath = null;
  }

  @override
  void didUpdateWidget(covariant TikTokVideoCardPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.video.id != oldWidget.video.id) {
      _disposePlayer();
      _requestPlaybackIfNeeded();
    } else if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (_player != null) {
          _player?.play();
        } else {
          _requestPlaybackIfNeeded();
        }
      } else {
        _player?.pause();
      }
    }
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  void _togglePlayPause() {
    final player = _player;
    if (player == null) return;

    if (_isPlaying) {
      player.pause();
      _showTransientIcon(Icons.pause_rounded);
    } else {
      player.play();
      _showTransientIcon(Icons.play_arrow_rounded);
    }
  }

  void _showTransientIcon(IconData icon) {
    setState(() {
      _actionIcon = icon;
      _showActionIcon = true;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _showActionIcon = false);
      }
    });
  }

  void _toggleMute() {
    final currentlyMuted = ref.read(tiktokMutedProvider);
    final nextMuted = !currentlyMuted;
    ref.read(tiktokMutedProvider.notifier).state = nextMuted;
    _player?.setVolume(nextMuted ? 0.0 : 100.0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final videoStateAsync = ref.watch(tiktokVideoStateProvider(widget.video.id));
    final isMuted = ref.watch(tiktokMutedProvider);

    // Sync volume when muted state changes globally
    if (_player != null) {
      _player?.setVolume(isMuted ? 0.0 : 100.0);
    }

    return videoStateAsync.when(
      data: (state) {
        if (state.isReady && state.localPath != null) {
          if (_loadedPath != state.localPath || _player == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _initPlayer(state.localPath!);
            });
          }
          return _buildVideoPlayer(colors, isMuted);
        }

        if (state.isUnavailable) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.isActive && widget.onNext != null) {
              widget.onNext!();
            }
          });
          return const SizedBox.shrink();
        }

        return _buildLoadingCard(colors, state.progress);
      },
      loading: () => _buildLoadingCard(colors, 0.1),
      error: (e, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.isActive && widget.onNext != null) {
            widget.onNext!();
          }
        });
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildVideoPlayer(AppColors colors, bool isMuted) {
    final controller = _controller;
    if (controller == null) {
      return _buildLoadingCard(colors, 0.9);
    }

    final progressRatio = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: _togglePlayPause,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Native Accelerated Video Surface
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Video(
              controller: controller,
              fit: BoxFit.contain,
              controls: NoVideoControls,
            ),
          ),

          // Mute / Unmute Button (Top Right)
          Positioned(
            top: 14,
            right: 14,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: _toggleMute,
                tooltip: isMuted ? 'Activer le son' : 'Couper le son',
                icon: Icon(
                  isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          // Action feedback overlay (Play / Pause splash)
          if (_showActionIcon)
            Center(
              child: AnimatedOpacity(
                opacity: _showActionIcon ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _actionIcon,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
            ),

          // Paused Indicator Badge (if not playing)
          if (!_isPlaying && !_showActionIcon)
            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),

          // Scrubber / Progress Bar at bottom edge
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: colors.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: colors.primary,
              ),
              child: Slider(
                value: progressRatio,
                onChanged: (val) {
                  final targetMs = (_duration.inMilliseconds * val).toInt();
                  _player?.seek(Duration(milliseconds: targetMs));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(AppColors colors, double progress) {
    final pct = (progress * 100).toInt();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: progress > 0.05 ? progress : null,
                    strokeWidth: 3.5,
                    color: colors.primary,
                    backgroundColor: colors.borderSubtle,
                  ),
                ),
                Icon(
                  Icons.file_download_rounded,
                  size: 28,
                  color: colors.primary,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              progress > 0.05
                  ? 'Téléchargement de la vidéo ($pct%)'
                  : 'Préchargement en arrière-plan...',
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Stockage local pour une lecture fluide sans latence',
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
