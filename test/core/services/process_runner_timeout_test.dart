import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/services/binary/process_runner.dart';

void main() {
  test(
    'a hung process is killed when the timeout expires',
    () async {
      final watch = Stopwatch()..start();
      await expectLater(
        ProcessRunner().run(
          'ping',
          ['-n', '30', '127.0.0.1'],
          timeout: const Duration(seconds: 1),
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
    },
    skip: !Platform.isWindows,
  );

  test('a quick process still returns its output', () async {
    final result = await ProcessRunner().run(
      Platform.isWindows ? 'cmd' : 'echo',
      Platform.isWindows ? ['/c', 'echo', 'hi'] : ['hi'],
      timeout: const Duration(seconds: 20),
    );
    expect(result.exitCode, 0);
    expect(result.stdout.toString().trim(), 'hi');
  });
}
