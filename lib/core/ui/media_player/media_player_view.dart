import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../design_system/foundation/typography.dart';
import 'media_player_provider.dart';
import 'player_controls.dart';

/// Full-screen overlay media player with glassmorphism controls
class MediaPlayerView extends ConsumerStatefulWidget {
  const MediaPlayerView({super.key});

  @override
  ConsumerState<MediaPlayerView> createState() => _MediaPlayerViewState();
}

class _MediaPlayerViewState extends ConsumerState<MediaPlayerView> {
  late final VideoController _videoController;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    final player = ref.read(mediaPlayerProvider.notifier).player;
    _videoController = VideoController(player!);
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(mediaPlayerProvider);

    if (!playerState.isOpen) return const SizedBox.shrink();

    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          // Video Surface
          Positioned.fill(
            child: Video(
              controller: _videoController,
              controls: NoVideoControls,
            ),
          ),

          // Tap overlay to toggle controls
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Controls overlay
          if (_showControls) ...[
            // Top bar — file name + close button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _getFileName(playerState.currentFile ?? ''),
                              style: AppTypography.label.copyWith(
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              ref.read(mediaPlayerProvider.notifier).close();
                            },
                            icon: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: PlayerControls(
                playerState: playerState,
                currentFile: playerState.currentFile,
                onPlayPause: () {
                  ref.read(mediaPlayerProvider.notifier).togglePlayPause();
                },
                onSeekStart: () {
                  ref.read(mediaPlayerProvider.notifier).startSeeking();
                },
                onSeekPreview: (position) {
                  ref.read(mediaPlayerProvider.notifier).seekPreview(position);
                },
                onSeek: (position) {
                  ref.read(mediaPlayerProvider.notifier).seek(position);
                },
                onVolumeChange: (volume) {
                  ref.read(mediaPlayerProvider.notifier).setVolume(volume);
                },
                onSpeedChange: (speed) {
                  ref
                      .read(mediaPlayerProvider.notifier)
                      .setPlaybackSpeed(speed);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getFileName(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? 'Unknown' : parts.last;
  }
}
