import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/download/tiktok_video_url.dart';
import '../../../../core/logger/logger_service.dart';
import '../../../../core/services/binary/binary_locator.dart';
import '../../../../core/services/binary/process_runner.dart';
import '../../../../core/services/title_cleaner_service.dart';
import '../../domain/entities/download_request.dart';

/// A TikTok photo slideshow as its web page describes it.
class TikTokPhotoPost {
  const TikTokPhotoPost({
    required this.id,
    required this.images,
    this.musicUrl,
    this.description = '',
    this.author,
    this.width,
    this.height,
  });

  final String id;
  final List<String> images;
  final String? musicUrl;
  final String description;
  final String? author;
  final int? width;
  final int? height;

  /// Reads the post from the page's rehydration JSON; null when the page has
  /// no photo post (a video, an error page, a changed layout).
  static TikTokPhotoPost? parse(String html, String id) {
    final match = RegExp(
      r'<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__"[^>]*>(.*?)</script>',
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return null;
    try {
      final data = jsonDecode(match.group(1)!) as Map<String, dynamic>;
      final item =
          (((data['__DEFAULT_SCOPE__'] as Map?)?['webapp.video-detail']
                      as Map?)?['itemInfo']
                  as Map?)?['itemStruct']
              as Map?;
      final images = ((item?['imagePost'] as Map?)?['images'] as List?) ?? [];
      final urls = [
        for (final image in images)
          if ((((image as Map)['imageURL'] as Map?)?['urlList'] as List?)
                  ?.isNotEmpty ??
              false)
            ((image['imageURL'] as Map)['urlList'] as List).first.toString(),
      ];
      if (urls.isEmpty) return null;
      final first = images.first as Map;
      final music = (item?['music'] as Map?)?['playUrl']?.toString() ?? '';
      return TikTokPhotoPost(
        id: id,
        images: urls,
        musicUrl: music.isEmpty ? null : music,
        description: item?['desc']?.toString() ?? '',
        author: (item?['author'] as Map?)?['uniqueId']?.toString(),
        width: (first['imageWidth'] as num?)?.toInt(),
        height: (first['imageHeight'] as num?)?.toInt(),
      );
    } catch (e) {
      LoggerService.w('TikTok photo post: unreadable page data: $e');
      return null;
    }
  }
}

/// Downloads a TikTok photo slideshow (yt-dlp finds no video format there)
/// and turns it into one MP4, the way TikTok plays it: each image for
/// [secondsPerImage] seconds, with the post's music when it has one.
class TikTokPhotoPostSource {
  TikTokPhotoPostSource({
    BinaryLocator? binaryLocator,
    ProcessRunner? processRunner,
    Future<String?> Function(Uri url)? fetchText,
    Future<void> Function(Uri url, File target)? fetchFile,
  }) : _binaryLocator = binaryLocator ?? BinaryLocator(),
       _processRunner = processRunner ?? ProcessRunner(),
       _fetchText = fetchText ?? _httpText,
       _fetchFile = fetchFile ?? _httpFile;

  final BinaryLocator _binaryLocator;
  final ProcessRunner _processRunner;
  final Future<String?> Function(Uri url) _fetchText;
  final Future<void> Function(Uri url, File target) _fetchFile;

  static const secondsPerImage = 3;
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  /// Writes the slideshow into [folder] (under the creator's subfolder when
  /// [DownloadRequest.organizeByCreator]) and returns the file and its title.
  Future<({String filePath, String title})> download(
    DownloadRequest request,
    String folder,
  ) async {
    final id = TikTokVideoUrl.extractVideoId(request.url);
    if (id == null) throw Exception('No TikTok post ID in ${request.url}');
    final html = await _fetchText(
      Uri.parse('https://www.tiktok.com/@_/video/$id'),
    );
    final post = html == null ? null : TikTokPhotoPost.parse(html, id);
    if (post == null) {
      throw Exception('TikTok photo post $id: no images on its page');
    }
    final ffmpeg = await _binaryLocator.findFfmpeg();
    if (ffmpeg == null) throw Exception('ffmpeg not found');

    final work = await Directory.systemTemp.createTemp('md_photo_${id}_');
    try {
      final images = <File>[];
      for (var i = 0; i < post.images.length; i++) {
        final file = File(p.join(work.path, 'img$i.jpg'));
        await _fetchFile(Uri.parse(post.images[i]), file);
        images.add(file);
      }
      File? music;
      if (post.musicUrl != null) {
        try {
          music = File(p.join(work.path, 'music.mp3'));
          await _fetchFile(Uri.parse(post.musicUrl!), music);
        } catch (e) {
          // A slideshow without its music is still worth keeping.
          LoggerService.w('TikTok photo post $id: no music ($e)');
          music = null;
        }
      }

      final title = post.description.trim().isEmpty
          ? 'TikTok photo $id'
          : post.description.trim();
      var outDir = folder;
      if (request.organizeByCreator) {
        outDir = p.join(folder, post.author ?? 'Inconnu');
      }
      await Directory(outDir).create(recursive: true);
      final out = p.join(
        outDir,
        '${TitleCleanerService.filenameStem(title)} [$id].mp4',
      );

      final args = slideshowArgs(
        images: [for (final f in images) f.path],
        music: music?.path,
        width: post.width,
        height: post.height,
        output: out,
      );
      var result = await _processRunner.run(
        ffmpeg,
        args,
        timeout: const Duration(minutes: 3),
      );
      if (result.exitCode != 0) {
        // Some ffmpeg builds (Android) lack libx264: MPEG-4 Part 2 plays too.
        result = await _processRunner.run(
          ffmpeg,
          slideshowArgs(
            images: [for (final f in images) f.path],
            music: music?.path,
            width: post.width,
            height: post.height,
            output: out,
            h264: false,
          ),
          timeout: const Duration(minutes: 3),
        );
      }
      if (result.exitCode != 0 || !await File(out).exists()) {
        throw Exception('ffmpeg could not build the slideshow: '
            '${result.stderr.toString().trim()}');
      }
      return (filePath: out, title: title);
    } finally {
      try {
        await work.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// ffmpeg arguments: every image fitted (letterboxed) into the first
  /// image's even-sized frame, shown [secondsPerImage] s, music cut to fit.
  static List<String> slideshowArgs({
    required List<String> images,
    required String output,
    String? music,
    int? width,
    int? height,
    bool h264 = true,
  }) {
    int even(int? v, int fallback) => ((v ?? fallback) ~/ 2) * 2;
    final w = even(width, 1080);
    final h = even(height, 1920);
    final args = <String>['-hide_banner', '-loglevel', 'error', '-y'];
    for (final image in images) {
      args.addAll(['-loop', '1', '-t', '$secondsPerImage', '-i', image]);
    }
    if (music != null) args.addAll(['-i', music]);
    final filter = StringBuffer();
    for (var i = 0; i < images.length; i++) {
      filter.write(
        '[$i:v]scale=$w:$h:force_original_aspect_ratio=decrease,'
        'pad=$w:$h:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p[v$i];',
      );
    }
    for (var i = 0; i < images.length; i++) {
      filter.write('[v$i]');
    }
    filter.write('concat=n=${images.length}:v=1:a=0,fps=30[out]');
    args.addAll(['-filter_complex', filter.toString(), '-map', '[out]']);
    if (music != null) args.addAll(['-map', '${images.length}:a', '-c:a', 'aac']);
    args.addAll(
      h264
          ? ['-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20']
          : ['-c:v', 'mpeg4', '-q:v', '3'],
    );
    args.addAll([
      '-movflags',
      '+faststart',
      '-t',
      '${images.length * secondsPerImage}',
      output,
    ]);
    return args;
  }

  static Future<String?> _httpText(Uri url) async {
    final client = HttpClient()..userAgent = _userAgent;
    try {
      final request = await client
          .getUrl(url)
          .timeout(const Duration(seconds: 15));
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != 200) return null;
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> _httpFile(Uri url, File target) async {
    final client = HttpClient()..userAgent = _userAgent;
    try {
      final request = await client
          .getUrl(url)
          .timeout(const Duration(seconds: 15));
      request.headers.set('Referer', 'https://www.tiktok.com/');
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: url);
      }
      await response.pipe(target.openWrite());
    } finally {
      client.close(force: true);
    }
  }
}
