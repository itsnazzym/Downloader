import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../logger/logger_service.dart';
import '../../services/metadata_extractor_service.dart';
import '../../../services/binary_locator.dart';
import '../../../services/process_runner.dart';
import '../plugin_interface.dart';

class MetadataEnricherPlugin extends DownloaderPlugin {
  MetadataEnricherPlugin(this._binaryLocator, this._processRunner);

  final BinaryLocator _binaryLocator;
  final ProcessRunner _processRunner;

  @override
  String get id => 'builtin_metadata_enricher';

  @override
  String get name => 'Metadata Enricher';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Writes a sidecar .info.json file by combining ffprobe details with yt-dlp source metadata.';

  @override
  String get iconName => 'info_outline';

  @override
  Future<PluginModificationResult?> onDownloadComplete(
    PluginDownloadEvent event,
  ) async {
    final filePath = event.filePath;
    if (filePath == null || filePath.isEmpty) {
      return null;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    final ffprobeMetadata = await MetadataExtractorService(
      _binaryLocator,
    ).extract(filePath);
    final sourceMetadata =
        event.sourceMetadata ?? await _fetchYtDlpMetadata(event);

    final sidecarPath = '${p.withoutExtension(filePath)}.info.json';
    final payload = {
      'generatedAt': DateTime.now().toIso8601String(),
      'downloadId': event.downloadId,
      'source': event.source,
      'url': event.url,
      'title': event.title,
      'filePath': filePath,
      'fileName': p.basename(filePath),
      'ffprobe': ffprobeMetadata == null
          ? null
          : {
              'durationSeconds': ffprobeMetadata.durationSeconds,
              'width': ffprobeMetadata.width,
              'height': ffprobeMetadata.height,
              'videoCodec': ffprobeMetadata.videoCodec,
              'audioCodec': ffprobeMetadata.audioCodec,
              'container': ffprobeMetadata.container,
              'bitRate': ffprobeMetadata.bitRate,
              'title': ffprobeMetadata.title,
              'artist': ffprobeMetadata.artist,
              'comment': ffprobeMetadata.comment,
              'sourceUrl': ffprobeMetadata.sourceUrl,
            },
      'ytDlp': _sanitizeSourceMetadata(sourceMetadata),
    };

    await File(
      sidecarPath,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

    return null;
  }

  Future<Map<String, dynamic>?> _fetchYtDlpMetadata(
    PluginDownloadEvent event,
  ) async {
    final ytDlpPath = await _binaryLocator.findYtDlp();
    if (ytDlpPath == null) {
      return null;
    }

    final args = ['--dump-json', '--no-warnings', '--no-playlist', event.url];
    final request = event.request;

    if (request?.rawCookies != null && request!.rawCookies!.isNotEmpty) {
      args.addAll(['--add-header', 'Cookie:${request.rawCookies!}']);
    } else if (request?.cookiesFilePath != null &&
        request!.cookiesFilePath!.isNotEmpty) {
      args.addAll(['--cookies', request.cookiesFilePath!]);
    } else if (request?.cookieBrowser != null &&
        request!.cookieBrowser!.isNotEmpty) {
      args.addAll(['--cookies-from-browser', request.cookieBrowser!]);
    }

    final result = await _processRunner.run(ytDlpPath, args);
    if (result.exitCode != 0) {
      LoggerService.w(
        '[MetadataEnricher] yt-dlp metadata fetch failed: ${result.stderr}',
      );
      return null;
    }

    final stdout = result.stdout.toString().trim();
    if (stdout.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(stdout) as Map<String, dynamic>;
    } catch (e) {
      LoggerService.w('[MetadataEnricher] Failed to parse yt-dlp JSON: $e');
      return null;
    }
  }

  Map<String, dynamic>? _sanitizeSourceMetadata(
    Map<String, dynamic>? metadata,
  ) {
    if (metadata == null) {
      return null;
    }

    const keys = [
      'id',
      'title',
      'fulltitle',
      'uploader',
      'uploader_id',
      'channel',
      'channel_id',
      'extractor',
      'extractor_key',
      'webpage_url',
      'original_url',
      'thumbnail',
      'description',
      'duration',
      'upload_date',
      'release_date',
      'view_count',
      'like_count',
      'comment_count',
      'fps',
      'width',
      'height',
      'ext',
      'format',
      'format_id',
      'playlist',
      'playlist_index',
      'tags',
    ];

    return {
      for (final key in keys)
        if (metadata.containsKey(key) && metadata[key] != null)
          key: metadata[key],
    };
  }
}
