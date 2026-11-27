import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/android/android_engine_bridge.dart';
import 'package:tapload/core/services/binary/service_providers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where the preview of [videoPath] is cached inside [cacheDir].
String thumbnailCachePath(String cacheDir, String videoPath) => p.join(
  cacheDir,
  'video_thumbs',
  '${md5.convert(utf8.encode(videoPath))}.jpg',
);

/// A preview taken from the video file itself, for rows that have none.
///
/// After a reinstall the library is rebuilt from the files on disk: the
/// remote thumbnail addresses were in the app's own data and are gone; and
/// signed CDN addresses (TikTok) expire. This rebuilds one lazily, per row
/// shown, so nothing stalls at startup: Android's engine on phones, ffmpeg on
/// desktop.
final videoThumbnailProvider = FutureProvider.family<String?, String>((
  ref,
  videoPath,
) async {
  final desktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  if (!Platform.isAndroid && !desktop) return null;
  final out = File(
    thumbnailCachePath((await getTemporaryDirectory()).path, videoPath),
  );
  if (out.existsSync() && out.lengthSync() > 0) return out.path;
  if (!File(videoPath).existsSync()) return null;
  await out.parent.create(recursive: true);
  if (Platform.isAndroid) {
    final ok = await AndroidEngineBridge.instance.getVideoThumbnail(
      videoPath,
      out.path,
    );
    return ok ? out.path : null;
  }
  final ffmpeg = await ref.read(binaryLocatorProvider).findFfmpeg();
  if (ffmpeg == null) return null;
  return _ffmpegSlots.run(() async {
    // One second in skips black first frames; very short clips use frame 0.
    for (final at in const ['1', '0']) {
      final result = await Process.run(ffmpeg, [
        '-y',
        '-loglevel',
        'error',
        '-ss',
        at,
        '-i',
        videoPath,
        '-frames:v',
        '1',
        '-vf',
        'scale=360:-2',
        out.path,
      ]);
      if (result.exitCode == 0 && out.existsSync() && out.lengthSync() > 0) {
        return out.path;
      }
    }
    return null;
  });
});

/// At most two ffmpeg extractions at once, however many tiles ask.
final _ffmpegSlots = ThumbnailSlots(2);

/// Runs tasks with at most a fixed number in flight, the rest in turn.
@visibleForTesting
class ThumbnailSlots {
  ThumbnailSlots(this._free);

  int _free;
  final _waiting = <Completer<void>>[];

  Future<T> run<T>(Future<T> Function() task) async {
    if (_free > 0) {
      _free--;
    } else {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    try {
      return await task();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      } else {
        _free++;
      }
    }
  }
}
