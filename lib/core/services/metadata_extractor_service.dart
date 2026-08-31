import 'dart:convert';
import 'dart:io';
import 'binary/binary_locator.dart';
import '../logger/logger_service.dart';

class VideoMetadata {
  final int durationSeconds;
  final int? width;
  final int? height;
  final String? title;
  final String? artist;
  final String? comment;
  final String? sourceUrl;

  VideoMetadata({
    required this.durationSeconds,
    this.width,
    this.height,
    this.title,
    this.artist,
    this.comment,
    this.sourceUrl,
  });

  @override
  String toString() {
    return 'VideoMetadata(duration: $durationSeconds, size: ${width}x$height, title: $title)';
  }
}

class MetadataExtractorService {
  final BinaryLocator _binaryLocator;

  MetadataExtractorService(this._binaryLocator);

  Future<VideoMetadata?> extract(String filePath) async {
    final ffprobePath = await _binaryLocator.findFfprobe();
    if (ffprobePath == null) {
      LoggerService.w('ffprobe not found, skipping metadata extraction');
      return null;
    }

    try {
      final result = await Process.run(ffprobePath, [
        '-v',
        'quiet',
        '-print_format',
        'json',
        '-show_format',
        '-show_streams',
        filePath,
      ]);

      if (result.exitCode != 0) {
        LoggerService.e('ffprobe failed for $filePath: ${result.stderr}');
        return null;
      }

      final json = jsonDecode(result.stdout.toString());
      final format = json['format'];
      final streams = (json['streams'] as List?) ?? [];
      final videoStream = streams.firstWhere(
        (s) => s['codec_type'] == 'video',
        orElse: () => null,
      );

      final duration = double.tryParse(format['duration'] ?? '0') ?? 0;
      final tags = format['tags'] as Map<String, dynamic>?;

      String? sourceUrl;
      // Try to find source URL in tags
      if (tags != null) {
        // yt-dlp often stores source in 'comment' or 'purl' or 'PURL' or 'description'
        if (tags['comment'] != null &&
            tags['comment'].toString().startsWith('http')) {
          sourceUrl = tags['comment'].toString();
        } else if (tags['description'] != null &&
            tags['description'].toString().startsWith('http')) {
          sourceUrl = tags['description'].toString();
        } else if (tags['purl'] != null) {
          sourceUrl = tags['purl'].toString();
        } else if (tags['PURL'] != null) {
          sourceUrl = tags['PURL'].toString();
        } else if (tags['url'] != null &&
            tags['url'].toString().startsWith('http')) {
          sourceUrl = tags['url'].toString();
        } else if (tags['artist'] != null &&
            tags['artist'].toString().startsWith('http')) {
          sourceUrl = tags['artist'].toString();
        }
      }

      return VideoMetadata(
        durationSeconds: duration.toInt(),
        width: videoStream != null ? videoStream['width'] : null,
        height: videoStream != null ? videoStream['height'] : null,
        title: tags?['title'],
        artist: tags?['artist'],
        comment: tags?['comment'],
        sourceUrl: sourceUrl,
      );
    } catch (e) {
      LoggerService.e('Error parsing metadata for $filePath', e);
      return null;
    }
  }
}
