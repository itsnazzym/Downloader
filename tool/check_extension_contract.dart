import 'dart:io';

/// Verifies extension JS contracts and that packaged copies match shared/.
///
/// Usage:
///   dart run tool/check_extension_contract.dart
Future<void> main(List<String> args) async {
  final root = Directory.current;
  var failed = false;

  void fail(String message) {
    stderr.writeln(message);
    failed = true;
  }

  final connection = File('${root.path}/extension/shared/connection.js');
  if (!connection.existsSync()) {
    fail('Missing extension/shared/connection.js');
  } else {
    final source = await connection.readAsString();
    const requiredTokens = [
      "type: 'HELLO'",
      "type: 'DOWNLOAD'",
      "type: 'PING'",
      "type: 'HEARTBEAT_COOKIES'",
      "error: 'unsupported_url'",
      "error: 'need_tweet_url'",
    ];
    for (final token in requiredTokens) {
      if (!source.contains(token)) {
        fail('connection.js missing expected token: $token');
      }
    }
  }

  for (final name in ['url_policy.js', 'badge.js']) {
    final file = File('${root.path}/extension/shared/$name');
    if (!file.existsSync()) {
      fail('Missing extension/shared/$name');
    }
  }

  const packaged = [
    'connection.js',
    'content.js',
    'url_policy.js',
    'badge.js',
    'popup.js',
    'feed_panel.js',
  ];
  for (final browser in ['chrome', 'firefox']) {
    for (final name in packaged) {
      final shared = File('${root.path}/extension/shared/$name');
      final copy = File('${root.path}/extension/$browser/$name');
      if (!shared.existsSync() || !copy.existsSync()) {
        fail('Missing $name in shared or $browser');
        continue;
      }
      if (await shared.readAsString() != await copy.readAsString()) {
        fail(
          'extension/$browser/$name is out of date. Run: dart run tool/build_extension.dart',
        );
      }
    }
  }

  if (failed) {
    exitCode = 1;
    return;
  }
  stdout.writeln('Extension contract and packaged copies OK');
}
