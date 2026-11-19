import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/android/android_engine_bridge.dart';
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
/// remote thumbnail addresses were in the app's own data and are gone. This
/// rebuilds one lazily, per row shown, so nothing stalls at startup.
final videoThumbnailProvider = FutureProvider.family<String?, String>((
  ref,
  videoPath,
) async {
  if (!Platform.isAndroid) return null;
  final out = File(
    thumbnailCachePath((await getTemporaryDirectory()).path, videoPath),
  );
  if (out.existsSync() && out.lengthSync() > 0) return out.path;
  await out.parent.create(recursive: true);
  final ok = await AndroidEngineBridge.instance.getVideoThumbnail(
    videoPath,
    out.path,
  );
  return ok ? out.path : null;
});
