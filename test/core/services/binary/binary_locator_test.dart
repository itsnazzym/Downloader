import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/services/binary/binary_locator.dart';
import 'package:modern_downloader/core/services/binary/process_runner.dart';
import 'package:path/path.dart' as p;

class _CountingProcessRunner extends ProcessRunner {
  int calls = 0;
  final List<String> executables = [];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    calls++;
    executables.add(executable);
    return ProcessResult(0, 1, '', 'not found');
  }
}

void main() {
  late Directory tmp;

  setUp(() async {
    BinaryLocator.clearResolvedPathCache();
    tmp = await Directory.systemTemp.createTemp('binary-locator-');
  });

  tearDown(() async {
    BinaryLocator.clearResolvedPathCache();
    try {
      await tmp.delete(recursive: true);
    } catch (_) {
      // Best-effort temp cleanup; leftover dirs are harmless.
    }
  });

  test('file present returns path with zero Process.run', () async {
    final exeName = BinaryLocator.executableFileName(BinaryLocator.ytDlpName);
    final exe = File(p.join(tmp.path, exeName));
    await exe.writeAsBytes(const [0]);

    final processes = _CountingProcessRunner();
    var diskCalls = 0;
    final locator = BinaryLocator(
      processRunner: processes,
      resolveAppBin: () async => tmp,
      fileExists: (path) async {
        diskCalls++;
        return path == exe.path;
      },
    );

    final found = await locator.findYtDlp();

    expect(found, exe.path);
    expect(processes.calls, 0);
    expect(diskCalls, greaterThan(0));
  });

  test('missing optional gobird does not PATH spawn', () async {
    final processes = _CountingProcessRunner();
    final locator = BinaryLocator(
      processRunner: processes,
      resolveAppBin: () async => tmp,
      fileExists: (path) async => false,
    );

    final found = await locator.findGobird();

    expect(found, isNull);
    expect(processes.calls, 0);
    expect(processes.executables, isEmpty);
  });

  test('cache hit skips disk and process', () async {
    final exeName = BinaryLocator.executableFileName(BinaryLocator.ytDlpName);
    final exe = File(p.join(tmp.path, exeName));
    await exe.writeAsBytes(const [0]);

    final processes = _CountingProcessRunner();
    var diskCalls = 0;
    Future<bool> exists(String path) async {
      diskCalls++;
      return path == exe.path;
    }

    final first = BinaryLocator(
      processRunner: processes,
      resolveAppBin: () async => tmp,
      fileExists: exists,
    );
    expect(await first.findYtDlp(), exe.path);
    final diskAfterFirst = diskCalls;
    expect(diskAfterFirst, greaterThan(0));
    expect(processes.calls, 0);

    final second = BinaryLocator(
      processRunner: processes,
      resolveAppBin: () async => tmp,
      fileExists: exists,
    );
    expect(await second.findYtDlp(), exe.path);
    expect(diskCalls, diskAfterFirst);
    expect(processes.calls, 0);
  });
}
