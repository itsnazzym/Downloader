import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import '../../logger/logger_service.dart';
import '../../android/android_engine_bridge.dart';
import '../../platform/platform_info.dart';

class ProcessRunner {
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    LoggerService.debug('Starting process: $executable ${arguments.join(' ')}');
    if (PlatformInfo.isAndroid &&
        AndroidEngineBridge.isEngineBinary(executable)) {
      return AndroidEngineBridge.instance.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
      );
    }
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: false,
      environment: environment,
      includeParentEnvironment: true,
    );

    if (Platform.isWindows) {
      _setBelowNormalPriority(process.pid);
    }

    return process;
  }

  /// With [timeout], a process still running when it expires is killed with
  /// its whole tree and a [TimeoutException] is thrown (a hung yt-dlp probe
  /// otherwise held its slot, and blocked every new download, forever).
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    LoggerService.debug('Running process: $executable ${arguments.join(' ')}');
    if (PlatformInfo.isAndroid &&
        AndroidEngineBridge.isEngineBinary(executable) &&
        timeout == null) {
      return AndroidEngineBridge.instance.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
      );
    }
    if (timeout != null) {
      return _runWithTimeout(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        timeout: timeout,
      );
    }
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: false,
      environment: environment,
      includeParentEnvironment: true,
      stdoutEncoding: null, // Get raw bytes
      stderrEncoding: null, // Get raw bytes
    );

    return ProcessResult(
      result.pid,
      result.exitCode,
      utf8.decode(result.stdout as List<int>, allowMalformed: true),
      utf8.decode(result.stderr as List<int>, allowMalformed: true),
    );
  }

  Future<ProcessResult> _runWithTimeout(
    String executable,
    List<String> arguments, {
    required Duration timeout,
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    // Through [start], so the Android engine gets the same timeout and kill.
    final process = await start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    // Drain both pipes while waiting, or a chatty child blocks on a full pipe.
    final stdout = process.stdout.fold<List<int>>([], (a, b) => a..addAll(b));
    final stderr = process.stderr.fold<List<int>>([], (a, b) => a..addAll(b));
    final int exitCode;
    try {
      exitCode = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      LoggerService.w('Process timed out after $timeout: $executable');
      await kill(process);
      rethrow;
    }
    return ProcessResult(
      process.pid,
      exitCode,
      utf8.decode(await stdout, allowMalformed: true),
      utf8.decode(await stderr, allowMalformed: true),
    );
  }

  Future<void> kill(Process process) async {
    if (Platform.isWindows) {
      // Use taskkill to kill the process tree (/T) forcefully (/F)
      try {
        await Process.run('taskkill', [
          '/F',
          '/T',
          '/PID',
          process.pid.toString(),
        ]);
        LoggerService.debug('Killed process tree for PID: ${process.pid}');
      } catch (e) {
        LoggerService.w('Failed to kill process tree: $e');
        process.kill(); // Fallback
      }
    } else {
      process.kill();
    }
  }

  static void _setBelowNormalPriority(int pid) {
    if (!Platform.isWindows) return;
    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final openProcess = kernel32
          .lookupFunction<
            IntPtr Function(Uint32, Int32, Uint32),
            int Function(int, int, int)
          >('OpenProcess');
      final setPriorityClass = kernel32
          .lookupFunction<
            Int32 Function(IntPtr, Uint32),
            int Function(int, int)
          >('SetPriorityClass');
      final closeHandle = kernel32
          .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
            'CloseHandle',
          );

      const processSetInformation = 0x0200;
      const belowNormalPriorityClass = 0x00004000;

      final handle = openProcess(processSetInformation, 0, pid);
      if (handle != 0) {
        setPriorityClass(handle, belowNormalPriorityClass);
        closeHandle(handle);
        LoggerService.debug('Set BELOW_NORMAL_PRIORITY_CLASS for PID $pid');
      }
    } catch (e) {
      LoggerService.debug('Failed to set process priority for PID $pid: $e');
    }
  }
}
