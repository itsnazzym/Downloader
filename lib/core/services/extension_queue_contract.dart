/// WebSocket contract for the extension's download queue: a snapshot request
/// and per-download commands (cancel, pause, resume, retry, cancel_all).
class ExtensionQueueContract {
  static const String snapshotRequest = 'QUEUE_SNAPSHOT_REQUEST';
  static const String snapshot = 'QUEUE_SNAPSHOT';
  static const String command = 'DOWNLOAD_COMMAND';
  static const String commandResult = 'DOWNLOAD_COMMAND_RESULT';

  static const Set<String> _idCommands = {'cancel', 'pause', 'resume', 'retry'};

  /// Returns an error code, or null when the command shape is valid.
  static String? validateCommand(Map<String, dynamic> data) {
    final name = data['command'];
    if (name == 'cancel_all') return null;
    if (name is! String || !_idCommands.contains(name)) {
      return 'unknown_command';
    }
    final id = data['id'];
    if (id is! String || id.isEmpty) return 'missing_id';
    return null;
  }
}
