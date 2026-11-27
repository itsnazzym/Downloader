import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/services/extension_queue_contract.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/entities/download_request.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';

DownloadItem _item(String id, DownloadStatus status) => DownloadItem(
  id: id,
  request: DownloadRequest(url: 'https://example.com/$id'),
  status: status,
);

void main() {
  test('message types match the extension contract', () {
    expect(ExtensionQueueContract.snapshotRequest, 'QUEUE_SNAPSHOT_REQUEST');
    expect(ExtensionQueueContract.snapshot, 'QUEUE_SNAPSHOT');
    expect(ExtensionQueueContract.command, 'DOWNLOAD_COMMAND');
    expect(ExtensionQueueContract.commandResult, 'DOWNLOAD_COMMAND_RESULT');
  });

  test('each command is allowed only for the statuses that fit it', () {
    const allowed = <String, Set<DownloadStatus>>{
      'pause': {
        DownloadStatus.extracting,
        DownloadStatus.downloading,
        DownloadStatus.processing,
      },
      'resume': {DownloadStatus.paused},
      'cancel': {
        DownloadStatus.queued,
        DownloadStatus.extracting,
        DownloadStatus.downloading,
        DownloadStatus.processing,
        DownloadStatus.paused,
      },
      'retry': {DownloadStatus.failed, DownloadStatus.canceled},
    };
    for (final entry in allowed.entries) {
      for (final status in DownloadStatus.values) {
        expect(
          ExtensionQueueContract.allows(entry.key, status),
          entry.value.contains(status),
          reason: '${entry.key} on ${status.name}',
        );
      }
    }
    expect(
      ExtensionQueueContract.allows('explode', DownloadStatus.failed),
      isFalse,
    );
  });

  test('cancel_all targets exactly the queued and running statuses', () {
    expect(
      DownloadStatus.values.where(ExtensionQueueContract.isActive).toSet(),
      {
        DownloadStatus.queued,
        DownloadStatus.extracting,
        DownloadStatus.downloading,
        DownloadStatus.processing,
      },
    );
  });

  test('id commands with an id are valid', () {
    for (final name in ['cancel', 'pause', 'resume', 'retry']) {
      expect(
        ExtensionQueueContract.validateCommand({'command': name, 'id': 'a'}),
        isNull,
        reason: name,
      );
    }
  });

  test('cancel_all needs no id', () {
    expect(
      ExtensionQueueContract.validateCommand({'command': 'cancel_all'}),
      isNull,
    );
  });

  test('unknown or malformed command is rejected', () {
    for (final data in <Map<String, dynamic>>[
      {'command': 'explode', 'id': 'a'},
      {'id': 'a'},
      {'command': 3, 'id': 'a'},
    ]) {
      expect(ExtensionQueueContract.validateCommand(data), 'unknown_command');
    }
  });

  test('missing, empty or non-string id is rejected', () {
    for (final data in <Map<String, dynamic>>[
      {'command': 'cancel'},
      {'command': 'pause', 'id': ''},
      {'command': 'retry', 'id': 7},
    ]) {
      expect(ExtensionQueueContract.validateCommand(data), 'missing_id');
    }
  });

  test('the snapshot keeps the activity and only the 50 latest finished', () {
    final all = [
      for (var i = 0; i < 70; i++)
        _item(
          'done$i',
          i.isEven ? DownloadStatus.completed : DownloadStatus.duplicate,
        ),
      for (final s in DownloadStatus.values)
        if (s != DownloadStatus.completed && s != DownloadStatus.duplicate)
          _item(s.name, s),
      _item('done70', DownloadStatus.completed),
    ];
    final ids = ExtensionQueueContract.snapshotItems(
      all,
    ).map((i) => i.id).toList();
    final finished = [for (var i = 21; i <= 70; i++) 'done$i'];
    expect(ids.where((id) => id.startsWith('done')), finished);
    expect(ids.where((id) => !id.startsWith('done')), [
      'queued',
      'extracting',
      'downloading',
      'processing',
      'failed',
      'canceled',
      'paused',
    ]);
    // Order of the desktop list is kept.
    expect(ids.indexOf('queued'), lessThan(ids.indexOf('done70')));
  });

  test('a short history is sent whole', () {
    final all = [
      _item('a', DownloadStatus.completed),
      _item('b', DownloadStatus.downloading),
    ];
    expect(ExtensionQueueContract.snapshotItems(all), all);
  });
}
