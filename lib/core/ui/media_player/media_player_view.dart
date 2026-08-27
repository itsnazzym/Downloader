import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import '../../design_system/foundation/typography.dart';
import 'media_player_provider.dart';
import 'media_playlist.dart';
import 'player_controls.dart';

/// Full-screen overlay media player with iOS-style chrome.
class MediaPlayerView extends ConsumerStatefulWidget {
  const MediaPlayerView({super.key});

  @override
  ConsumerState<MediaPlayerView> createState() => _MediaPlayerViewState();
}

class _MediaPlayerViewState extends ConsumerState<MediaPlayerView> {
  static const _hudIdleHideDelay = Duration(seconds: 2);
  static const _pointerMoveThreshold = 1.0;

  bool _showControls = true;
  Timer? _hideTimer;
  Offset? _lastPointerPosition;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hudIdleHideDelay, () {
      if (!mounted || !_showControls) return;
      setState(() => _showControls = false);
    });
  }

  /// Cursor/rebuilds synthesize hover at the same point and would keep the HUD
  /// forever if every event restarted the idle timer.
  void _onPointerMoved(Offset position) {
    final last = _lastPointerPosition;
    if (last != null &&
        (last.dx - position.dx).abs() < _pointerMoveThreshold &&
        (last.dy - position.dy).abs() < _pointerMoveThreshold) {
      return;
    }
    _lastPointerPosition = position;
    _revealControls();
  }

  void _revealControls({bool toggle = false}) {
    if (toggle) {
      setState(() => _showControls = !_showControls);
      if (!_showControls) {
        _hideTimer?.cancel();
        return;
      }
    } else if (!_showControls) {
      setState(() => _showControls = true);
    }
    _scheduleHide();
  }

  String _fileName(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? 'Unknown' : parts.last;
  }

  Future<void> _skipPlaylist(int delta) async {
    await ref.read(mediaPlaylistControllerProvider).skipBy(delta);
    _revealControls();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(mediaPlayerProvider.select((s) => s.isOpen), (
      previous,
      next,
    ) {
      if (next && previous != true) {
        _lastPointerPosition = null;
        if (!_showControls) {
          setState(() => _showControls = true);
        }
        _scheduleHide();
      } else if (!next) {
        _hideTimer?.cancel();
        _lastPointerPosition = null;
        _showControls = true;
      }
    });

    ref.listen<bool>(mediaPlayerProvider.select((s) => s.isPlaying), (
      previous,
      next,
    ) {
      if (next) {
        _revealControls();
      }
    });

    ref.listen<bool>(mediaPlayerProvider.select((s) => s.didComplete), (
      previous,
      next,
    ) {
      if (next && previous != true) {
        unawaited(_skipPlaylist(1));
      }
    });

    final isOpen = ref.watch(mediaPlayerProvider.select((s) => s.isOpen));
    final controller = ref.read(mediaPlayerProvider.notifier).videoController;

    if (!isOpen || controller == null) {
      return const SizedBox.shrink();
    }

    final fileName = ref.read(mediaPlayerProvider).currentFile ?? '';
    final playlist = ref.watch(mediaPlaylistProvider);
    final currentFile = ref.watch(
      mediaPlayerProvider.select((s) => s.currentFile),
    );
    var trackIndex = -1;
    if (currentFile != null && playlist.isNotEmpty) {
      trackIndex = playlist.indexWhere((e) => e.filePath == currentFile);
    }
    final counterText = playlist.isEmpty || trackIndex < 0
        ? null
        : '${trackIndex + 1} / ${playlist.length}';

    final l10n = context.l10n;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          ref.read(mediaPlayerProvider.notifier).close();
        },
        const SingleActivator(LogicalKeyboardKey.space): () {
          ref.read(mediaPlayerProvider.notifier).togglePlayPause();
          _revealControls();
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          ref
              .read(mediaPlayerProvider.notifier)
              .skipBy(const Duration(seconds: 10));
          _revealControls();
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          ref
              .read(mediaPlayerProvider.notifier)
              .skipBy(const Duration(seconds: -10));
          _revealControls();
        },
        const SingleActivator(LogicalKeyboardKey.pageDown): () {
          unawaited(_skipPlaylist(1));
        },
        const SingleActivator(LogicalKeyboardKey.keyN): () {
          unawaited(_skipPlaylist(1));
        },
        const SingleActivator(LogicalKeyboardKey.mediaTrackNext): () {
          unawaited(_skipPlaylist(1));
        },
        const SingleActivator(LogicalKeyboardKey.pageUp): () {
          unawaited(_skipPlaylist(-1));
        },
        const SingleActivator(LogicalKeyboardKey.keyP): () {
          unawaited(_skipPlaylist(-1));
        },
        const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): () {
          unawaited(_skipPlaylist(-1));
        },
      },
      child: Focus(
        autofocus: true,
        focusNode: _focusNode,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerHover: (event) => _onPointerMoved(event.position),
          onPointerMove: (event) => _onPointerMoved(event.position),
          child: MouseRegion(
            cursor: _showControls
                ? SystemMouseCursors.basic
                : SystemMouseCursors.none,
            child: Material(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ExcludeSemantics(
                    child: Video(
                      controller: controller,
                      controls: NoVideoControls,
                      fill: Colors.black,
                      wakelock: false,
                      pauseUponEnteringBackgroundMode: false,
                    ),
                  ),
                  const _FirstFrameScrim(),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _revealControls(toggle: true),
                      onDoubleTapDown: (details) {
                        final width = MediaQuery.sizeOf(context).width;
                        final notifier = ref.read(mediaPlayerProvider.notifier);
                        if (details.localPosition.dx < width / 2) {
                          notifier.skipBy(const Duration(seconds: -10));
                        } else {
                          notifier.skipBy(const Duration(seconds: 10));
                        }
                        _revealControls();
                      },
                      child: const ColoredBox(color: Colors.transparent),
                    ),
                  ),
                  IgnorePointer(
                    ignoring: !_showControls,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: _showControls ? 1 : 0,
                      child: Stack(
                        children: [
                          const Positioned.fill(child: _PlayerScrim()),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: _TopBar(
                              title: _fileName(fileName),
                              counterText: counterText,
                              onClose: () {
                                ref.read(mediaPlayerProvider.notifier).close();
                              },
                            ),
                          ),
                          Align(
                            alignment: Alignment.center,
                            child: _CenterTransport(
                              previousTooltip: l10n.playerPrevious,
                              nextTooltip: l10n.playerNext,
                              onPrevious: () {
                                unawaited(_skipPlaylist(-1));
                              },
                              onPlayPause: () {
                                ref
                                    .read(mediaPlayerProvider.notifier)
                                    .togglePlayPause();
                                _revealControls();
                              },
                              onSkipBack: () {
                                ref
                                    .read(mediaPlayerProvider.notifier)
                                    .skipBy(const Duration(seconds: -10));
                                _revealControls();
                              },
                              onSkipForward: () {
                                ref
                                    .read(mediaPlayerProvider.notifier)
                                    .skipBy(const Duration(seconds: 10));
                                _revealControls();
                              },
                              onNext: () {
                                unawaited(_skipPlaylist(1));
                              },
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: PlayerControls(
                              onInteraction: _revealControls,
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
        ),
      ),
    );
  }
}

class _FirstFrameScrim extends ConsumerWidget {
  const _FirstFrameScrim();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(
      mediaPlayerProvider.select((s) => s.isSurfaceReady),
    );
    if (ready) return const SizedBox.shrink();
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _PlayerScrim extends StatelessWidget {
  const _PlayerScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.55),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.72),
            ],
            stops: const [0.0, 0.22, 0.62, 1.0],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String? counterText;
  final VoidCallback onClose;

  const _TopBar({required this.title, required this.onClose, this.counterText});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(
          children: [
            _GlassIconButton(icon: Icons.close_rounded, onTap: onClose),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 46,
              child: counterText == null
                  ? const SizedBox.shrink()
                  : Text(
                      counterText!,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      style: AppTypography.label.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterTransport extends ConsumerWidget {
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  final VoidCallback onNext;
  final String previousTooltip;
  final String nextTooltip;

  const _CenterTransport({
    required this.onPrevious,
    required this.onPlayPause,
    required this.onSkipBack,
    required this.onSkipForward,
    required this.onNext,
    required this.previousTooltip,
    required this.nextTooltip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(mediaPlayerProvider.select((s) => s.isPlaying));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TransportButton(
          icon: Icons.skip_previous_rounded,
          size: 36,
          tooltip: previousTooltip,
          onTap: onPrevious,
        ),
        const SizedBox(width: 28),
        _TransportButton(
          icon: Icons.replay_10_rounded,
          size: 36,
          onTap: onSkipBack,
        ),
        const SizedBox(width: 36),
        _PlayPauseButton(isPlaying: isPlaying, onTap: onPlayPause),
        const SizedBox(width: 36),
        _TransportButton(
          icon: Icons.forward_10_rounded,
          size: 36,
          onTap: onSkipForward,
        ),
        const SizedBox(width: 28),
        _TransportButton(
          icon: Icons.skip_next_rounded,
          size: 36,
          tooltip: nextTooltip,
          onTap: onNext,
        ),
      ],
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayPauseButton({required this.isPlaying, required this.onTap});

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovering ? 1.06 : 1,
          duration: const Duration(milliseconds: 160),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha: _hovering ? 0.22 : 0.16,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  widget.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransportButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final String? tooltip;

  const _TransportButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.tooltip,
  });

  @override
  State<_TransportButton> createState() => _TransportButtonState();
}

class _TransportButtonState extends State<_TransportButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: _hovering ? 1 : 0.86,
          child: Icon(widget.icon, color: Colors.white, size: widget.size),
        ),
      ),
    );

    if (widget.tooltip == null || widget.tooltip!.isEmpty) {
      return button;
    }
    return Tooltip(message: widget.tooltip!, child: button);
  }
}

class _GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: _hovering ? 0.22 : 0.14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Icon(widget.icon, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}
