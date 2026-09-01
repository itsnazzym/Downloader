import 'dart:async';
import 'dart:io';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import '../../platform/platform_info.dart';

/// State for the integrated media player
class MediaPlayerState {
  final bool isOpen;
  final String? currentFile;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double volume;
  final double playbackSpeed;
  final bool isSurfaceReady;
  final bool didComplete;

  const MediaPlayerState({
    this.isOpen = false,
    this.currentFile,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.isSurfaceReady = false,
    this.didComplete = false,
  });

  MediaPlayerState copyWith({
    bool? isOpen,
    String? currentFile,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? volume,
    double? playbackSpeed,
    bool? isSurfaceReady,
    bool? didComplete,
  }) {
    return MediaPlayerState(
      isOpen: isOpen ?? this.isOpen,
      currentFile: currentFile ?? this.currentFile,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isSurfaceReady: isSurfaceReady ?? this.isSurfaceReady,
      didComplete: didComplete ?? this.didComplete,
    );
  }
}

/// Manages the media player lifecycle using media_kit
class MediaPlayerNotifier extends StateNotifier<MediaPlayerState> {
  Player? _player;
  VideoController? _videoController;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Kept as a mutable field (not in immutable state) to avoid
  /// copyWith null issues when streams fire rapidly.
  bool _isSeeking = false;
  bool get isSeeking => _isSeeking;

  DateTime? _lastPositionUiUpdate;
  bool _opening = false;

  /// Set [testMode] to true in unit tests to skip native Player creation.
  MediaPlayerNotifier({bool testMode = false})
    : _testMode = testMode,
      super(const MediaPlayerState());

  final bool _testMode;

  Player? get player {
    _ensurePlayer();
    return _player;
  }

  VideoController? get videoController {
    _ensurePlayer();
    return _videoController;
  }

  void _ensurePlayer() {
    if (_testMode || _player != null) return;
    _player = Player();
    _videoController = VideoController(
      _player!,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
        // copy-back so Flutter's texture always receives frames on Windows
        hwdec: 'auto-copy',
      ),
    );
    _setupListeners();
  }

  void _setupListeners() {
    final player = _player;
    if (player == null) return;

    _subscriptions.add(
      player.stream.playing.listen((playing) {
        if (mounted) state = state.copyWith(isPlaying: playing);
      }),
    );
    _subscriptions.add(
      player.stream.position.listen((position) {
        if (!mounted || _isSeeking) return;

        final now = DateTime.now();
        if (_lastPositionUiUpdate != null &&
            now.difference(_lastPositionUiUpdate!) <
                const Duration(milliseconds: 250)) {
          return;
        }
        _lastPositionUiUpdate = now;
        state = state.copyWith(position: position);
      }),
    );
    _subscriptions.add(
      player.stream.duration.listen((duration) {
        if (mounted) state = state.copyWith(duration: duration);
      }),
    );
    _subscriptions.add(
      player.stream.volume.listen((volume) {
        if (mounted) state = state.copyWith(volume: volume / 100.0);
      }),
    );
    _subscriptions.add(
      player.stream.rate.listen((rate) {
        if (mounted) state = state.copyWith(playbackSpeed: rate);
      }),
    );
    _subscriptions.add(
      player.stream.completed.listen((completed) {
        if (mounted && completed) {
          state = state.copyWith(isPlaying: false, didComplete: true);
        }
      }),
    );
  }

  Future<void> _waitFrames(int count) async {
    for (var i = 0; i < count; i++) {
      final frame = Completer<void>();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!frame.isCompleted) frame.complete();
      });
      await frame.future;
    }
  }

  /// Open a file for playback. Texture must exist before decode starts,
  /// and native fullscreen must happen only after the first frame.
  Future<void> openFile(String filePath) async {
    if (!File(filePath).existsSync()) return;
    if (_opening) return;
    _opening = true;

    try {
      _ensurePlayer();
      final controller = _videoController;
      final player = _player;
      if (player == null) return;

      // 1. Mount the Video widget at the current window size (not exclusive
      //    fullscreen yet — HWND resize before first frame = black texture).
      state = state.copyWith(
        isOpen: true,
        currentFile: filePath,
        isSurfaceReady: false,
        position: Duration.zero,
        duration: Duration.zero,
        isPlaying: false,
        didComplete: false,
      );

      if (controller != null) {
        try {
          await controller.platform.future.timeout(const Duration(seconds: 5));
        } on TimeoutException {
          debugPrint('media_kit: texture attach timed out');
        }
      }

      await _waitFrames(2);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 2. Start decode only after the Flutter Texture is in the tree.
      await player.open(Media(filePath));

      if (controller != null) {
        try {
          await controller.waitUntilFirstFrameRendered.timeout(
            const Duration(seconds: 4),
          );
          if (mounted) {
            state = state.copyWith(isSurfaceReady: true);
          }
        } on TimeoutException {
          if (mounted) {
            state = state.copyWith(isSurfaceReady: true);
          }
        }
      } else if (mounted) {
        state = state.copyWith(isSurfaceReady: true);
      }

      // 3. Exclusive fullscreen after a visible frame, then force a redraw
      //    so D3D survives the HWND resize.
      if (PlatformInfo.isDesktop) {
        await windowManager.setFullScreen(true);
      }
      await Future<void>.delayed(const Duration(milliseconds: 180));
      try {
        final pos = player.state.position;
        await player.seek(pos);
      } catch (_) {}
    } catch (e, st) {
      debugPrint('MediaPlayerNotifier.openFile failed: $e\n$st');
    } finally {
      _opening = false;
    }
  }

  /// Switch to another file while staying in exclusive fullscreen.
  ///
  /// Reuses the mounted [Player] and does **not** call [windowManager.setFullScreen].
  Future<void> switchFile(String filePath) async {
    if (_opening) return;
    if (!_testMode && !File(filePath).existsSync()) return;
    _opening = true;

    try {
      if (_testMode) {
        if (mounted) {
          state = state.copyWith(
            isOpen: true,
            currentFile: filePath,
            position: Duration.zero,
            duration: Duration.zero,
            isPlaying: false,
            didComplete: false,
            isSurfaceReady: true,
          );
        }
        return;
      }

      _ensurePlayer();
      final player = _player;
      if (player == null) return;

      if (mounted) {
        state = state.copyWith(
          currentFile: filePath,
          position: Duration.zero,
          duration: Duration.zero,
          isPlaying: false,
          didComplete: false,
        );
      }

      await player.open(Media(filePath));
    } catch (e, st) {
      debugPrint('MediaPlayerNotifier.switchFile failed: $e\n$st');
    } finally {
      _opening = false;
    }
  }

  /// Close the player — exits fullscreen
  Future<void> close() async {
    try {
      await _player?.pause();
      await _player?.stop();
    } catch (_) {}
    try {
      if (PlatformInfo.isDesktop) {
        await windowManager.setFullScreen(false);
      }
    } catch (_) {}
    if (mounted) {
      state = const MediaPlayerState();
    }
    _lastPositionUiUpdate = null;
  }

  /// Test-only: simulate end-of-track without a native player.
  void simulateCompleted() {
    if (!_testMode || !mounted) return;
    state = state.copyWith(isPlaying: false, didComplete: true);
  }

  void togglePlayPause() {
    _player?.playOrPause();
  }

  void skipBy(Duration delta) {
    final player = _player;
    if (player == null) return;
    final duration = player.state.duration;
    var next = player.state.position + delta;
    if (next < Duration.zero) next = Duration.zero;
    if (duration > Duration.zero && next > duration) next = duration;
    seek(next);
  }

  /// Called when user starts dragging the seek bar
  void startSeeking() {
    _isSeeking = true;
  }

  /// Called while user drags — just updates the displayed position
  void seekPreview(Duration position) {
    state = state.copyWith(position: position);
  }

  /// Called when user releases the seek bar — actually seeks the player
  void seek(Duration position) {
    _player?.seek(position);
    _isSeeking = false;
    _lastPositionUiUpdate = null;
    state = state.copyWith(position: position);
  }

  void setVolume(double volume) {
    _player?.setVolume(volume * 100.0);
  }

  void setPlaybackSpeed(double speed) {
    _player?.setRate(speed);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();

    try {
      _player?.stop();
      _player?.dispose();
    } catch (_) {
      // media_kit native cleanup can race during hot restart — safe to ignore
    }
    _videoController = null;
    _player = null;
    super.dispose();
  }
}

final mediaPlayerProvider =
    StateNotifierProvider<MediaPlayerNotifier, MediaPlayerState>((ref) {
      return MediaPlayerNotifier();
    });
