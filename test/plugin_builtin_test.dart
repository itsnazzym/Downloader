import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/plugins/builtin/duplicate_guard_plugin.dart';
import 'package:modern_downloader/core/plugins/builtin/storage_cleaner_plugin.dart';
import 'package:modern_downloader/core/plugins/plugin_interface.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';

void main() {
  group('DuplicateGuardPlugin', () {
    test('blocks a duplicate URL already present in downloads', () async {
      final plugin = DuplicateGuardPlugin();

      final result = await plugin.onBeforeDownload(
        PluginDownloadEvent(
          downloadId: 'new',
          url: 'https://x.com/some/status/123',
          request: const DownloadRequest(url: 'https://x.com/some/status/123'),
          source: 'Twitter',
          existingDownloads: const [
            PluginDownloadSnapshot(
              downloadId: 'existing',
              url: 'https://x.com/some/status/123',
              status: 'completed',
              filePath: 'C:\\videos\\tweet.mp4',
              title: 'Tweet 123',
            ),
          ],
        ),
      );

      expect(result?.shouldCancel, isTrue);
      expect(result?.isDuplicate, isTrue);
      expect(result?.existingFilePath, 'C:\\videos\\tweet.mp4');
    });

    test(
      'blocks a duplicate file already found on disk by metadata id',
      () async {
        final plugin = DuplicateGuardPlugin();
        final tempDir = await Directory.systemTemp.createTemp('md-dup-guard-');
        final existingFile = File(
          '${tempDir.path}${Platform.pathSeparator}Video [abc123].mp4',
        );
        await existingFile.writeAsString('video');

        final result = await plugin.onBeforeDownload(
          PluginDownloadEvent(
            downloadId: 'new',
            url: 'https://youtube.com/watch?v=abc123',
            request: const DownloadRequest(
              url: 'https://youtube.com/watch?v=abc123',
            ),
            source: 'YouTube',
            outputDirectory: tempDir.path,
            sourceMetadata: const {'id': 'abc123'},
          ),
        );

        expect(result?.shouldCancel, isTrue);
        expect(result?.existingFilePath, existingFile.path);

        await tempDir.delete(recursive: true);
      },
    );
  });

  group('StorageCleanerPlugin', () {
    test('removes matching temp artifacts after completion', () async {
      final plugin = StorageCleanerPlugin();
      final tempDir = await Directory.systemTemp.createTemp(
        'md-storage-cleaner-',
      );
      final finalFile = File(
        '${tempDir.path}${Platform.pathSeparator}Sample Video.mp4',
      );
      final tempArtifact = File(
        '${tempDir.path}${Platform.pathSeparator}Sample Video.part',
      );

      await finalFile.writeAsString('done');
      await tempArtifact.writeAsString('temp');

      await plugin.onDownloadComplete(
        PluginDownloadEvent(
          downloadId: 'done',
          url: 'https://example.com/video',
          request: const DownloadRequest(url: 'https://example.com/video'),
          filePath: finalFile.path,
          title: 'Sample Video',
          source: 'Other',
          outputDirectory: tempDir.path,
        ),
      );

      expect(await tempArtifact.exists(), isFalse);

      await tempDir.delete(recursive: true);
    });
  });
}
