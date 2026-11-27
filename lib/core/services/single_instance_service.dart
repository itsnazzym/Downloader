import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../bootstrap/app_bootstrap.dart';
import '../launch/protocol_url_parser.dart';
import '../logger/logger_service.dart';
import 'windows_desktop_window_probe.dart';

class SingleInstanceDependencies {
  const SingleInstanceDependencies({
    required this.bind,
    required this.notifyPrimary,
    required this.hasVisiblePeerWindow,
    required this.stalePeerPid,
    required this.terminatePid,
    this.isOwnProcess = _assumeOwnProcess,
    this.currentPid,
  });

  static bool _assumeOwnProcess(int processId) => true;

  final Future<ServerSocket> Function() bind;
  final Future<void> Function(String payload) notifyPrimary;
  final bool Function() hasVisiblePeerWindow;
  final Future<int?> Function() stalePeerPid;
  final bool Function(int processId) terminatePid;

  /// Whether [processId] runs this app's executable. The port may be held by
  /// an unrelated program: that one must never be killed.
  final bool Function(int processId) isOwnProcess;
  final int? currentPid;

  factory SingleInstanceDependencies.production({
    int port = SingleInstanceService.port,
  }) {
    return SingleInstanceDependencies(
      bind: () => ServerSocket.bind(InternetAddress.loopbackIPv4, port),
      notifyPrimary: (payload) async {
        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(seconds: 1),
        );
        try {
          client.write(payload);
          await client.flush();
        } finally {
          await client.close();
        }
      },
      hasVisiblePeerWindow: () {
        if (!Platform.isWindows) return true;
        return WindowsDesktopWindowProbe.hasOtherAppWindow(currentPid: pid);
      },
      stalePeerPid: () => WindowsDesktopWindowProbe.listenerPidOnPort(port),
      terminatePid: WindowsDesktopWindowProbe.terminatePid,
      isOwnProcess: _runsThisExecutable,
      currentPid: pid,
    );
  }
}

/// Compares the image name of [processId] (from `tasklist`) with ours.
bool _runsThisExecutable(int processId) {
  if (!Platform.isWindows) return false;
  try {
    final result = Process.runSync('tasklist', [
      '/FI',
      'PID eq $processId',
      '/FO',
      'CSV',
      '/NH',
    ]);
    final image = result.stdout.toString().split(',').first.replaceAll('"', '');
    final own = Platform.resolvedExecutable.split(RegExp(r'[\\/]')).last;
    return image.trim().toLowerCase() == own.toLowerCase();
  } catch (_) {
    return false;
  }
}

class SingleInstanceService {
  static const int port = 61425;
  static ServerSocket? _server;

  @visibleForTesting
  static Future<void> resetForTest() async {
    await _server?.close();
    _server = null;
  }

  /// Initializes the single instance check.
  /// If an instance is already running *and visible on this desktop*, sends
  /// [args] to it and returns true (this instance should exit).
  /// A listener on another Win32 desktop is treated as stale and reclaimed.
  static Future<bool> check(
    List<String> args,
    ProviderContainer container, {
    SingleInstanceDependencies? dependencies,
  }) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return false;
    }
    final deps = dependencies ?? SingleInstanceDependencies.production();
    try {
      _server = await deps.bind();
      _attachListener(container);
      return false;
    } catch (e) {
      debugPrint('Another instance is running, sending args...');
      try {
        await deps.notifyPrimary(args.join(' '));
        if (deps.hasVisiblePeerWindow()) {
          return true;
        }
        LoggerService.w(
          'Primary instance has no window on this desktop; reclaiming single-instance port',
        );
        final stalePid = await deps.stalePeerPid();
        final selfPid = deps.currentPid ?? pid;
        if (stalePid != null && stalePid != selfPid) {
          if (!deps.isOwnProcess(stalePid)) {
            LoggerService.w(
              'Port $port is held by another program (PID $stalePid); '
              'starting without single-instance hand-off',
            );
            return false;
          }
          deps.terminatePid(stalePid);
        }
        _server = await _rebind(deps);
        if (_server != null) {
          _attachListener(container);
          LoggerService.i('Reclaimed single-instance port $port');
          return false;
        }
        return true;
      } catch (sendError) {
        debugPrint('Failed to send args to primary instance: $sendError');
        return false;
      }
    }
  }

  static Future<ServerSocket?> _rebind(SingleInstanceDependencies deps) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        return await deps.bind();
      } catch (_) {
        await Future<void>.delayed(Duration(milliseconds: 80 * (attempt + 1)));
      }
    }
    return null;
  }

  static void _attachListener(ProviderContainer container) {
    _server!.listen((client) {
      client.cast<List<int>>().transform(utf8.decoder).listen((data) {
        debugPrint('Received data from secondary instance: $data');
        _handleReceivedData(data, container);
      });
    });
  }

  static Future<void> _handleReceivedData(
    String data,
    ProviderContainer container,
  ) async {
    if (ProtocolUrlParser.isProtocolUrl(data)) {
      final parts = data.split(' ');
      final protocolUrl = parts.firstWhere(
        (p) => ProtocolUrlParser.isProtocolUrl(p),
        orElse: () => '',
      );

      if (protocolUrl.isNotEmpty) {
        final handled = AppBootstrap.dispatchProtocolUrl(
          protocolUrl,
          container,
        );
        if (handled) {
          try {
            await windowManager.show();
            if (await windowManager.isMinimized()) {
              await windowManager.restore();
            }
            await windowManager.focus();
          } catch (e) {
            debugPrint('Failed to focus window: $e');
          }
        }
      }
    } else {
      try {
        await windowManager.show();
        if (await windowManager.isMinimized()) {
          await windowManager.restore();
        }
        await windowManager.focus();
      } catch (e) {
        debugPrint('Failed to focus window: $e');
      }
    }
  }
}
