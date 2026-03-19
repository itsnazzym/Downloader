import 'dart:io';

import 'package:path/path.dart' as p;

import '../../logger/logger_service.dart';
import '../../services/metadata_extractor_service.dart';
import '../../../services/binary_locator.dart';
import '../plugin_interface.dart';

class ThumbnailSheetPlugin extends DownloaderPlugin {
  ThumbnailSheetPlugin(this._binaryLocator);

  final BinaryLocator _binaryLocator;

  @override
  String get id => 'builtin_thumbnail_sheet';

  @override
  String get name => 'Thumbnail Sheet';

  @override
  String get version => '1.0.0';

  @override
  bool get enabledByDefault => false;

  @override
  String get description =>
      'Generates a contact sheet image from the downloaded video for quick visual review.';

  @override
  String get iconName => 'grid_view';

  @override
  Future<PluginModificationResult?> onDownloadComplete(
    PluginDownloadEvent event,
  ) async {
    final filePath = event.filePath;
    if (filePath == null || filePath.isEmpty) {
      return null;
    }

    final ffmpegPath = await _binaryLocator.findFfmpeg();
    if (ffmpegPath == null || !await File(filePath).exists()) {
      return null;
    }

    final metadata = await MetadataExtractorService(
      _binaryLocator,
    ).extract(filePath);
    final duration = metadata?.durationSeconds ?? 0;
    final interval = duration <= 0 ? 10 : (duration / 12).clamp(1, 300).round();
    final outputPath = '${p.withoutExtension(filePath)}.sheet.jpg';

    final args = [
      '-y',
      '-i',
      filePath,
      '-vf',
      'fps=1/$interval,scale=320:-1,tile=4x3',
      '-frames:v',
      '1',
      outputPath,
    ];

    final result = await Process.run(ffmpegPath, args, runInShell: true);
    if (result.exitCode != 0) {
      LoggerService.w(
        '[ThumbnailSheet] Failed to generate sheet for $filePath: ${result.stderr}',
      );
      return null;
    }

    return null;
  }
}
