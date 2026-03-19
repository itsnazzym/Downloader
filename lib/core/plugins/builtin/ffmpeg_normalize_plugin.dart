import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../logger/logger_service.dart';
import '../../../services/binary_locator.dart';
import '../plugin_interface.dart';

class FfmpegNormalizePlugin extends DownloaderPlugin {
  FfmpegNormalizePlugin(this._binaryLocator);

  final BinaryLocator _binaryLocator;

  @override
  String get id => 'builtin_ffmpeg_normalize';

  @override
  String get name => 'FFmpeg Normalize';

  @override
  String get version => '1.0.0';

  @override
  bool get enabledByDefault => false;

  @override
  String get description =>
      'Normalizes finished videos to MP4 with H.264 video and AAC audio for maximum playback compatibility.';

  @override
  String get iconName => 'movie_filter';

  @override
  Future<PluginModificationResult?> onDownloadComplete(
    PluginDownloadEvent event,
  ) async {
    final inputPath = event.filePath;
    if (inputPath == null || inputPath.isEmpty) {
      return null;
    }

    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      return null;
    }

    final ffmpegPath = await _binaryLocator.findFfmpeg();
    final ffprobePath = await _binaryLocator.findFfprobe();
    if (ffmpegPath == null || ffprobePath == null) {
      LoggerService.w('[FFmpegNormalize] Missing ffmpeg or ffprobe');
      return null;
    }

    final probe = await _probeFile(ffprobePath, inputPath);
    if (probe == null || !_needsNormalization(inputPath, probe)) {
      return null;
    }

    final parent = p.dirname(inputPath);
    final basename = p.basenameWithoutExtension(inputPath);
    final finalPath = p.join(parent, '$basename.mp4');
    final tempPath = finalPath == inputPath
        ? p.join(parent, '$basename.normalized.mp4')
        : finalPath;

    final args = [
      '-y',
      '-i',
      inputPath,
      '-map',
      '0:v:0',
      '-map',
      '0:a?',
      '-c:v',
      'libx264',
      '-preset',
      'fast',
      '-crf',
      '20',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      '-movflags',
      '+faststart',
      tempPath,
    ];

    final result = await Process.run(ffmpegPath, args, runInShell: true);
    if (result.exitCode != 0 || !await File(tempPath).exists()) {
      LoggerService.w(
        '[FFmpegNormalize] ffmpeg failed for $inputPath: ${result.stderr}',
      );
      return null;
    }

    if (tempPath != inputPath) {
      try {
        if (await inputFile.exists()) {
          await inputFile.delete();
        }
        if (tempPath != finalPath) {
          await File(tempPath).rename(finalPath);
        }
      } catch (e) {
        LoggerService.e(
          '[FFmpegNormalize] Failed to finalize normalized file',
          e,
        );
        return null;
      }
    }

    return PluginModificationResult(newFilePath: finalPath);
  }

  Future<Map<String, dynamic>?> _probeFile(
    String ffprobePath,
    String inputPath,
  ) async {
    final result = await Process.run(ffprobePath, [
      '-v',
      'quiet',
      '-print_format',
      'json',
      '-show_format',
      '-show_streams',
      inputPath,
    ], runInShell: true);

    if (result.exitCode != 0) {
      return null;
    }

    try {
      return jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  bool _needsNormalization(String inputPath, Map<String, dynamic> probe) {
    if (p.extension(inputPath).toLowerCase() != '.mp4') {
      return true;
    }

    final streams = (probe['streams'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final videoStream = streams.cast<Map<String, dynamic>?>().firstWhere(
      (stream) => stream?['codec_type'] == 'video',
      orElse: () => null,
    );
    final audioStream = streams.cast<Map<String, dynamic>?>().firstWhere(
      (stream) => stream?['codec_type'] == 'audio',
      orElse: () => null,
    );

    final videoCodec = videoStream?['codec_name']?.toString().toLowerCase();
    final audioCodec = audioStream?['codec_name']?.toString().toLowerCase();

    final videoOk = videoCodec == 'h264';
    final audioOk =
        audioCodec == null ||
        audioCodec == 'aac' ||
        audioCodec == 'mp4a' ||
        audioCodec == 'alac';

    return !videoOk || !audioOk;
  }
}
