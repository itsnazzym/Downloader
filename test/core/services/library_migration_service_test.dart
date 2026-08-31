import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/services/library_migration_service.dart';
import 'package:modern_downloader/features/downloader/data/datasources/persistence_service.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:path/path.dart' as p;

class FakePersistenceService extends PersistenceService {
  List<DownloadItem> downloads = [];

  @override
  Future<List<DownloadItem>> loadDownloads() async => List.from(downloads);

  @override
  Future<void> saveDownloads(List<DownloadItem> items) async {
    downloads = List.from(items);
  }
}

void main() {
  late Directory tempDir;
  late Directory sourceDir;
  late Directory targetDir;
  late FakePersistenceService persistence;
  late LibraryMigrationService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('md_migration_test_');
    sourceDir = Directory(p.join(tempDir.path, 'source'))..createSync(recursive: true);
    targetDir = Directory(p.join(tempDir.path, 'target'))..createSync(recursive: true);

    persistence = FakePersistenceService();
    service = LibraryMigrationService(persistence);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('migrates video files, thumbnails, and updates persistence', () async {
    // Create source video and thumbnail
    final sourceTwitterDir = Directory(p.join(sourceDir.path, 'Twitter'))..createSync(recursive: true);
    final videoFile = File(p.join(sourceTwitterDir.path, 'clip [12345].mp4'))..writeAsStringSync('dummy video content');
    
    final sourceThumbDir = Directory(p.join(sourceDir.path, 'Thumbnails'))..createSync(recursive: true);
    final thumbFile = File(p.join(sourceThumbDir.path, 'clip [12345].jpg'))..writeAsStringSync('dummy thumb content');

    final item = DownloadItem(
      id: 'test-1',
      request: DownloadRequest(url: 'https://x.com/user/status/12345', outputFolder: sourceDir.path),
      status: DownloadStatus.completed,
      filePath: videoFile.path,
      thumbnailUrl: thumbFile.path,
      title: 'clip',
    );

    final failedItem = DownloadItem(
      id: 'test-2',
      request: DownloadRequest(url: 'https://x.com/user/status/67890', outputFolder: sourceDir.path),
      status: DownloadStatus.failed,
      error: 'Low Disk Space: 1.6 GB free',
      title: 'failed clip',
    );

    persistence.downloads = [item, failedItem];

    final result = await service.migrateLibrary(
      newOutputFolder: targetDir.path,
      deleteSourceFiles: true,
    );

    expect(result.videosMoved, 1);
    expect(result.thumbnailsMoved, 1);
    expect(result.errorsCount, 0);

    // Verify files on target
    final targetVideo = File(p.join(targetDir.path, 'Twitter', 'clip [12345].mp4'));
    final targetThumb = File(p.join(targetDir.path, 'Thumbnails', 'clip [12345].jpg'));

    expect(targetVideo.existsSync(), isTrue);
    expect(targetThumb.existsSync(), isTrue);

    // Verify source files deleted
    expect(videoFile.existsSync(), isFalse);
    expect(thumbFile.existsSync(), isFalse);

    // Verify updated items in persistence
    final updated = persistence.downloads;
    expect(updated[0].filePath, targetVideo.path);
    expect(updated[0].thumbnailUrl, targetThumb.path);
    expect(updated[0].request.outputFolder, targetDir.path);

    // Verify failed item unblocked to queued
    expect(updated[1].status, DownloadStatus.queued);
    expect(updated[1].error, isNull);
    expect(updated[1].request.outputFolder, targetDir.path);
  });
}
