import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/download_file_cleanup.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('download-file-cleanup-');
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  test('deletes media, sidecar thumbs, and temp fragments', () async {
    final media = File('${tmp.path}/clip.mp4');
    final thumb = File('${tmp.path}/clip.jpg');
    final part = File('${tmp.path}/clip.mp4.part');
    final keep = File('${tmp.path}/other.mp4');
    await media.writeAsBytes(const [1, 2, 3]);
    await thumb.writeAsBytes(const [4, 5]);
    await part.writeAsBytes(const [6]);
    await keep.writeAsBytes(const [7, 8]);

    await DownloadFileCleanup.deleteMediaAndSidecars(media.path);

    expect(await media.exists(), isFalse);
    expect(await thumb.exists(), isFalse);
    expect(await part.exists(), isFalse);
    expect(await keep.exists(), isTrue);
  });

  test('swallows missing files without throwing', () async {
    await DownloadFileCleanup.deleteMediaAndSidecars(
      '${tmp.path}/does-not-exist.mp4',
    );
  });
}
