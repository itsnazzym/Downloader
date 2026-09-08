import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:ui';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

class VideoPreviewWidget extends StatefulWidget {
  final String filePath;
  final String? thumbnailUrl;
  final VoidCallback? onFullscreen;

  const VideoPreviewWidget({
    super.key,
    required this.filePath,
    this.thumbnailUrl,
    this.onFullscreen,
  });

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isHovering = false;
  bool _userActivated = false;
  bool _isMuted = true;
  bool _isInitialized = false;
  bool _hasError = false;
  DateTime? _lastSeekTime;
  bool _isDragging = false;
  int _initToken = 0;

  bool get _shouldPlay => _isHovering || _userActivated;

  Future<void> _initializeController() async {
    final token = ++_initToken;
    final file = File(widget.filePath);
    try {
      if (!await file.exists()) {
        if (!mounted || token != _initToken || !_shouldPlay) return;
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
        return;
      }
    } catch (e) {
      debugPrint("Error checking video file: $e");
      if (!mounted || token != _initToken || !_shouldPlay) return;
      setState(() {
        _hasError = true;
        _isInitialized = false;
      });
      return;
    }

    try {
      final player = Player();
      final videoController = VideoController(
        player,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
          hwdec: 'auto-copy',
        ),
      );

      await player.setVolume(_isMuted ? 0.0 : 100.0);
      await player.setPlaylistMode(PlaylistMode.loop);

      _positionSub = player.stream.position.listen((pos) {
        if (mounted && !_isDragging) {
          setState(() => _position = pos);
        }
      });
      _durationSub = player.stream.duration.listen((dur) {
        if (mounted) {
          setState(() => _duration = dur);
        }
      });

      await player.open(Media(file.path), play: true);

      if (!mounted || token != _initToken || !_shouldPlay) {
        await _disposePlayer(player);
        return;
      }

      _player = player;
      _videoController = videoController;
      setState(() {
        _isInitialized = true;
        _hasError = false;
      });
    } catch (e) {
      debugPrint("Error initializing media_kit player: $e");
      if (!mounted || token != _initToken || !_shouldPlay) return;
      setState(() {
        _hasError = true;
        _isInitialized = false;
        _player = null;
        _videoController = null;
      });
    }
  }

  Future<void> _disposePlayer(Player? player) async {
    if (player == null) return;
    try {
      await player.dispose();
    } catch (e) {
      debugPrint("Error disposing media_kit player: $e");
    }
  }

  void _unmountPlayer({bool notify = true}) {
    _initToken++;
    _positionSub?.cancel();
    _durationSub?.cancel();
    final player = _player;
    _player = null;
    _videoController = null;
    _isInitialized = false;
    _isDragging = false;
    _position = Duration.zero;
    _duration = Duration.zero;

    if (player != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_disposePlayer(player));
      });
    }
    if (notify && mounted) setState(() {});
  }

  void _onHoverEnter() {
    if (_isHovering) return;
    setState(() => _isHovering = true);
    _initializeController();
  }

  void _onHoverExit() {
    if (!_isHovering) return;
    setState(() => _isHovering = false);
    _unmountPlayer();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _player?.setVolume(_isMuted ? 0.0 : 100.0);
    });
  }

  @override
  void didUpdateWidget(VideoPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _unmountPlayer(notify: false);
      if (_isHovering) {
        _initializeController();
      }
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    final player = _player;
    _player = null;
    _videoController = null;
    if (player != null) {
      unawaited(_disposePlayer(player));
    }
    super.dispose();
  }

  Widget _buildThumbnailBackground(BuildContext context) {
    final url = widget.thumbnailUrl!;
    final isNetworkUrl =
        url.startsWith('http://') || url.startsWith('https://');

    Widget imageWidget;
    if (isNetworkUrl) {
      imageWidget = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => _placeholderIcon(context),
      );
    } else {
      String decodedPath = url;
      try {
        decodedPath = Uri.decodeFull(url);
      } catch (_) {}
      final file = File(decodedPath);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, _, _) => _placeholderIcon(context),
        );
      } else {
        imageWidget = _placeholderIcon(context);
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(opacity: 0.85, child: imageWidget),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.6),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholderIcon(BuildContext context) {
    return Center(
      child: Icon(
        Icons.movie_creation_outlined,
        size: 48,
        color: AppColors.of(context).textSecondary,
      ),
    );
  }

  Widget _buildErrorPreview(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.of(context).error, width: 1.5),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded, color: AppColors.of(context).error, size: 36),
            const Gap(8),
            Text(
              l10n.error,
              style: TextStyle(color: AppColors.of(context).textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoController = _videoController;
    final showPlayer = _shouldPlay && _isInitialized && videoController != null;

    return GestureDetector(
      onTap: () {
        if (!showPlayer) {
          if (widget.onFullscreen != null) {
            widget.onFullscreen!();
          } else {
            setState(() => _userActivated = true);
            _initializeController();
          }
        }
      },
      child: MouseRegion(
        onEnter: (_) => _onHoverEnter(),
        onExit: (_) => _onHoverExit(),
        child: _shouldPlay && _hasError
            ? _buildErrorPreview(context)
            : _buildPreview(context),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final videoController = _videoController;
    final showPlayer = _shouldPlay && _isInitialized && videoController != null;

    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.of(context).primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.of(context).primary.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Thumbnail when not hovering/playing
          if (widget.thumbnailUrl != null && !showPlayer)
            Positioned.fill(child: _buildThumbnailBackground(context)),

          if (!showPlayer)
            Center(
              child: IconButton(
                iconSize: 52,
                tooltip: 'Lire la vidéo',
                icon: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.of(context).primary.withValues(alpha: 0.8),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.of(context).primary,
                    size: 36,
                  ),
                ),
                onPressed: () {
                  if (widget.onFullscreen != null) {
                    widget.onFullscreen!();
                  } else {
                    setState(() => _userActivated = true);
                    _initializeController();
                  }
                },
              ),
            ),

          // Video rendered via media_kit libmpv texture
          if (showPlayer)
            ExcludeSemantics(
              child: SizedBox.expand(
                child: Video(
                  controller: videoController,
                  controls: NoVideoControls,
                  fit: BoxFit.contain,
                ),
              ),
            ),

          // Controls Overlay (Scrubber & Mute)
          if (showPlayer)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: 300.ms,
                opacity: _isHovering ? 1.0 : 0.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Scrubber Bar
                      GestureDetector(
                        onPanStart: (_) {
                          setState(() => _isDragging = true);
                          _player?.pause();
                        },
                        onPanEnd: (_) {
                          setState(() => _isDragging = false);
                          if (_isHovering) _player?.play();
                        },
                        onTapDown: (details) => _handleSeek(details.localPosition.dx, context),
                        onPanUpdate: (details) => _handleSeek(details.localPosition.dx, context),
                        child: Container(
                          height: 20,
                          width: double.infinity,
                          color: Colors.transparent,
                          alignment: Alignment.center,
                          child: Container(
                            height: _isDragging ? 6 : 3,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.of(context).primary,
                                  borderRadius: BorderRadius.circular(3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.of(context).primary.withValues(
                                        alpha: _isDragging ? 0.8 : 0.5,
                                      ),
                                      blurRadius: _isDragging ? 8 : 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontFamily: 'JetBrains Mono',
                            ),
                          ),
                          const Spacer(),
                          // Volume / Mute Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _toggleMute,
                              borderRadius: BorderRadius.circular(8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    color: Colors.black.withValues(alpha: 0.35),
                                    child: Icon(
                                      _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Gap(8),
                          // Fullscreen Button
                          if (widget.onFullscreen != null)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: widget.onFullscreen,
                                borderRadius: BorderRadius.circular(8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      color: Colors.black.withValues(alpha: 0.35),
                                      child: const Icon(
                                        Icons.fullscreen_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_isHovering && !_isInitialized)
            Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.of(context).primary),
              ),
            ),

          if (!_isHovering)
            IgnorePointer(
              child: Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.white.withValues(alpha: 0.5),
                size: 54,
              ).animate().scale(
                delay: 100.ms,
                duration: 400.ms,
                curve: Curves.easeOutBack,
              ),
            ),
        ],
      ),
    );
  }

  void _handleSeek(double localX, BuildContext context) {
    if (_player == null || !_isInitialized || _duration.inMilliseconds <= 0) return;

    final now = DateTime.now();
    if (_lastSeekTime != null &&
        now.difference(_lastSeekTime!) < const Duration(milliseconds: 60)) {
      return;
    }
    _lastSeekTime = now;

    final box = context.findRenderObject() as RenderBox;
    final width = box.size.width;
    if (width <= 0) return;

    final double relative = localX / width;
    final targetMs = (_duration.inMilliseconds * relative.clamp(0.0, 1.0)).toInt();
    _player?.seek(Duration(milliseconds: targetMs));
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
