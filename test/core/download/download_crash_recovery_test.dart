import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/download_crash_recovery.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

DownloadItem _item(DownloadStatus status) {
  return DownloadItem(
    id: 'id-$status',
    request: const DownloadRequest(url: 'https://example.com/v'),
    status: status,
    progress: 0.4,
    speed: '1MiB/s',
    eta: '00:10',
  );
}

void main() {
  group('DownloadCrashRecovery', () {
    test('maps in-flight statuses to queued so they can resume', () {
      expect(
        DownloadCrashRecovery.recoverStatus(DownloadStatus.downloading),
        DownloadStatus.queued,
      );
      expect(
        DownloadCrashRecovery.recoverStatus(DownloadStatus.extracting),
        DownloadStatus.queued,
      );
      expect(
        DownloadCrashRecovery.recoverStatus(DownloadStatus.processing),
        DownloadStatus.queued,
      );
    });

    test('keeps user-paused and terminal statuses unchanged', () {
      expect(
        DownloadCrashRecovery.recoverStatus(DownloadStatus.paused),
        DownloadStatus.paused,
      );
      expect(
        DownloadCrashRecovery.recoverStatus(DownloadStatus.completed),
        DownloadStatus.completed,
      );
      expect(
        DownloadCrashRecovery.recoverStatus(DownloadStatus.failed),
        DownloadStatus.failed,
      );
      expect(
        DownloadCrashRecovery.recoverStatus(DownloadStatus.canceled),
        DownloadStatus.canceled,
      );
    });

    test('clears live progress fields on recovered items', () {
      final recovered = DownloadCrashRecovery.recoverItem(
        _item(DownloadStatus.downloading),
      );
      expect(recovered.status, DownloadStatus.queued);
      expect(recovered.speed, isEmpty);
      expect(recovered.eta, isEmpty);
      expect(recovered.request.url, 'https://example.com/v');
    });

    test('does not clone items that were not interrupted', () {
      final paused = _item(DownloadStatus.paused);
      expect(
        identical(DownloadCrashRecovery.recoverItem(paused), paused),
        isTrue,
      );
    });
  });
}
