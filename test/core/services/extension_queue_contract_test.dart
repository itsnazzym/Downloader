import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/services/extension_queue_contract.dart';

void main() {
  test('message types match the extension contract', () {
    expect(ExtensionQueueContract.snapshotRequest, 'QUEUE_SNAPSHOT_REQUEST');
    expect(ExtensionQueueContract.snapshot, 'QUEUE_SNAPSHOT');
    expect(ExtensionQueueContract.command, 'DOWNLOAD_COMMAND');
    expect(ExtensionQueueContract.commandResult, 'DOWNLOAD_COMMAND_RESULT');
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
}
