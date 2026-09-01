import 'dart:convert';
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
    return await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: false,
      environment: environment,
      includeParentEnvironment: true,
    );
  }

  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    LoggerService.debug('Running process: $executable ${arguments.join(' ')}');
    if (PlatformInfo.isAndroid &&
        AndroidEngineBridge.isEngineBinary(executable)) {
      return AndroidEngineBridge.instance.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
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
}
