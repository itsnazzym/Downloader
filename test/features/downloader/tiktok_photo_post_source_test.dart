import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/services/binary/binary_locator.dart';
import 'package:modern_downloader/core/services/binary/process_runner.dart';
import 'package:modern_downloader/features/downloader/data/sources/tiktok_photo_post_source.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';

String _page({List<String> images = const ['https://cdn/a.jpg'], String? music}) {
  final data = {
    '__DEFAULT_SCOPE__': {
      'webapp.video-detail': {
        'statusCode': 0,
        'itemInfo': {
          'itemStruct': {
            'desc': 'Cheese tour #food',
            'author': {'uniqueId': 'chef'},
            'music': {'playUrl': ?music},
            'imagePost': {
              'images': [
                for (final url in images)
                  {
                    'imageURL': {
                      'urlList': [url, '$url?backup'],
                    },
                    'imageWidth': 1441,
                    'imageHeight': 1080,
                  },
              ],
            },
          },
        },
      },
    },
  };
  return '<html><script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" '
      'type="application/json">${jsonEncode(data)}</script></html>';
}

class _Ffmpeg extends BinaryLocator {
  @override
  Future<String?> findFfmpeg() async => 'ffmpeg';
}

/// Records ffmpeg calls and writes the output file; fails the first
/// [failures] calls like an ffmpeg build without libx264.
class _Runner extends ProcessRunner {
  _Runner({this.failures = 0});

  int failures;
  final calls = <List<String>>[];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    calls.add(arguments);
    if (failures > 0) {
      failures--;
      return ProcessResult(1, 1, '', 'Unknown encoder libx264');
    }
    await File(arguments.last).writeAsString('mp4');
    return ProcessResult(1, 0, '', '');
  }
}

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('photo_'));
  tearDown(() async => tmp.delete(recursive: true));

  test('parses images, music, author and size from the page', () {
    final post = TikTokPhotoPost.parse(
      _page(images: ['https://cdn/1.jpg', 'https://cdn/2.jpg'], music: 'm'),
      '7235285015339257089',
    )!;
    expect(post.images, ['https://cdn/1.jpg', 'https://cdn/2.jpg']);
    expect(post.musicUrl, 'm');
    expect(post.author, 'chef');
    expect(post.description, 'Cheese tour #food');
    expect(post.width, 1441);
  });

  test('a page without a photo post gives null', () {
    expect(TikTokPhotoPost.parse('<html></html>', '1'), isNull);
    expect(TikTokPhotoPost.parse(_page(images: const []), '1'), isNull);
  });

  test('slideshow: every image 3 s in an even frame, music mapped', () {
    final args = TikTokPhotoPostSource.slideshowArgs(
      images: ['a.jpg', 'b.jpg'],
      music: 'm.mp3',
      width: 1441,
      height: 1080,
      output: 'out.mp4',
    );
    final filter = args[args.indexOf('-filter_complex') + 1];
    expect(filter, contains('scale=1440:1080'));
    expect(filter, contains('concat=n=2'));
    expect(args, containsAllInOrder(['-map', '2:a']));
    expect(args, containsAllInOrder(['-t', '6', 'out.mp4']));
    expect(args, contains('libx264'));
  });

  test('downloads the post into the creator folder as one MP4', () async {
    final runner = _Runner(failures: 1);
    final fetched = <Uri>[];
    final source = TikTokPhotoPostSource(
      binaryLocator: _Ffmpeg(),
      processRunner: runner,
      fetchText: (_) async =>
          _page(images: ['https://cdn/1.jpg', 'https://cdn/2.jpg']),
      fetchFile: (url, file) async {
        fetched.add(url);
        await file.writeAsString('jpg');
      },
    );

    final result = await source.download(
      const DownloadRequest(
        url: 'https://www.tiktokv.com/share/video/7235285015339257089/',
        organizeByCreator: true,
      ),
      tmp.path,
    );

    expect(fetched, hasLength(2));
    expect(result.title, 'Cheese tour #food');
    expect(result.filePath, contains('chef'));
    expect(result.filePath, endsWith('[7235285015339257089].mp4'));
    expect(File(result.filePath).existsSync(), isTrue);
    // libx264 missing: the second try uses MPEG-4.
    expect(runner.calls, hasLength(2));
    expect(runner.calls.last, contains('mpeg4'));
  });

  test('a page without images fails instead of writing an empty video', () {
    final source = TikTokPhotoPostSource(
      binaryLocator: _Ffmpeg(),
      processRunner: _Runner(),
      fetchText: (_) async => '<html>blocked</html>',
      fetchFile: (_, _) async {},
    );
    expect(
      source.download(
        const DownloadRequest(
          url: 'https://www.tiktok.com/@a/photo/7235285015339257089',
        ),
        tmp.path,
      ),
      throwsException,
    );
  });
}
