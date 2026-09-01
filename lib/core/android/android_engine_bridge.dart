import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../logger/logger_service.dart';
import '../services/binary/bridged_process.dart';

/// Method/Event channel to the Android yt-dlp + FFmpeg + aria2c engine.
class AndroidEngineBridge {
  AndroidEngineBridge({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methods =
           methodChannel ??
           const MethodChannel('com.downloader.modern_downloader/engine'),
       _events =
           eventChannel ??
           const EventChannel('com.downloader.modern_downloader/engineEvents');

  static final AndroidEngineBridge instance = AndroidEngineBridge();

  final MethodChannel _methods;
  final EventChannel _events;

  bool _listening = false;
  bool _initialized = false;
  final _stdout = <String, StreamController<List<int>>>{};
  final _stderr = <String, StreamController<List<int>>>{};
  final _exits = <String, Completer<int>>{};

  static bool isEngineBinary(String executable) {
    final name = p.basename(executable).toLowerCase();
    return name == 'yt-dlp' ||
        name == 'yt-dlp.exe' ||
        name == 'ffmpeg' ||
        name == 'ffmpeg.exe' ||
        name == 'ffprobe' ||
        name == 'ffprobe.exe' ||
        name.startsWith('aria2');
  }

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _ensureEventListener();
    try {
      await _methods.invokeMethod<void>('init');
      _initialized = true;
    } on PlatformException catch (e) {
      LoggerService.e('Android engine init failed', e);
      rethrow;
    }
  }

  Future<String?> defaultOutputDir() async {
    try {
      final path = await _methods.invokeMethod<String>('defaultOutputDir');
      if (path == null || path.trim().isEmpty) return null;
      return path;
    } on PlatformException catch (e) {
      LoggerService.w('defaultOutputDir failed: $e');
      return null;
    }
  }

  Future<String?> webViewCookies(String url) async {
    try {
      return await _methods.invokeMethod<String>('webViewCookies', {
        'url': url,
      });
    } on PlatformException catch (e) {
      LoggerService.w('webViewCookies failed: $e');
      return null;
    }
  }

  Future<String> updateYtDlp() async {
    try {
      final result = await _methods.invokeMethod<String>('updateYtDlp');
      return result ?? 'updated';
    } on PlatformException catch (e) {
      LoggerService.w('Android yt-dlp update failed: $e');
      return 'Update check failed';
    }
  }

  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    await ensureInitialized();
    try {
      final raw = await _methods.invokeMethod<Map<Object?, Object?>>('run', {
        'executable': p.basename(executable),
        'arguments': arguments,
        'workingDirectory': workingDirectory,
        'environment': environment,
      });
      final map = raw ?? const <Object?, Object?>{};
      return ProcessResult(
        map['pid'] as int? ?? 0,
        map['exitCode'] as int? ?? 1,
        map['stdout']?.toString() ?? '',
        map['stderr']?.toString() ?? '',
      );
    } on PlatformException catch (e) {
      return ProcessResult(0, 1, '', e.message ?? e.toString());
    }
  }

  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    await ensureInitialized();
    _ensureEventListener();
    final processId =
        'p${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(1 << 20)}';
    final stdout = StreamController<List<int>>();
    final stderr = StreamController<List<int>>();
    final exit = Completer<int>();
    _stdout[processId] = stdout;
    _stderr[processId] = stderr;
    _exits[processId] = exit;

    try {
      await _methods.invokeMethod<void>('start', {
        'processId': processId,
        'executable': p.basename(executable),
        'arguments': arguments,
        'workingDirectory': workingDirectory,
        'environment': environment,
      });
    } catch (e) {
      _completeExit(processId, 1);
      stderr.add(utf8.encode('$e'));
      rethrow;
    }

    return BridgedProcess(
      pid: processId.hashCode & 0x7fffffff,
      stdout: stdout.stream,
      stderr: stderr.stream,
      exitCode: exit.future,
      onKill: () {
        unawaited(
          _methods.invokeMethod<void>('kill', {'processId': processId}),
        );
        _completeExit(processId, -1);
        return true;
      },
    );
  }

  void _ensureEventListener() {
    if (_listening) return;
    _listening = true;
    _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object e) {
        LoggerService.w('Android engine event error: $e');
      },
    );
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final processId = event['processId']?.toString();
    if (processId == null || processId.isEmpty) return;
    final stream = event['stream']?.toString();
    if (stream == 'stdout') {
      final data = event['data']?.toString() ?? '';
      _stdout[processId]?.add(utf8.encode('$data\n'));
      return;
    }
    if (stream == 'stderr') {
      final data = event['data']?.toString() ?? '';
      _stderr[processId]?.add(utf8.encode('$data\n'));
      return;
    }
    if (stream == 'exit') {
      final code = event['code'];
      final exitCode = code is int ? code : int.tryParse('$code') ?? 1;
      _completeExit(processId, exitCode);
    }
  }

  void _completeExit(String processId, int code) {
    final exit = _exits.remove(processId);
    if (exit != null && !exit.isCompleted) {
      exit.complete(code);
    }
    unawaited(_stdout.remove(processId)?.close());
    unawaited(_stderr.remove(processId)?.close());
  }
}
