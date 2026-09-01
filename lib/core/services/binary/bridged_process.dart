import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// [Process] backed by a native Android engine (youtubedl-android) instead of
/// a POSIX executable.
class BridgedProcess implements Process {
  BridgedProcess({
    required this.pid,
    required Stream<List<int>> stdout,
    required Stream<List<int>> stderr,
    required Future<int> exitCode,
    required bool Function() onKill,
  }) : _stdout = stdout,
       _stderr = stderr,
       _exitCode = exitCode,
       _onKill = onKill;

  @override
  final int pid;

  final Stream<List<int>> _stdout;
  final Stream<List<int>> _stderr;
  final Future<int> _exitCode;
  final bool Function() _onKill;
  final StreamController<List<int>> _stdinController =
      StreamController<List<int>>();

  @override
  Stream<List<int>> get stdout => _stdout;

  @override
  Stream<List<int>> get stderr => _stderr;

  @override
  IOSink get stdin => IOSink(_stdinController.sink, encoding: utf8);

  @override
  Future<int> get exitCode => _exitCode;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    try {
      unawaited(_stdinController.close());
    } catch (_) {}
    return _onKill();
  }
}
