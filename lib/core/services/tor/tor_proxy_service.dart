import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../download/tor_proxy_guard.dart';
import '../../logger/logger_service.dart';
import '../../providers/settings_provider.dart';

enum TorRuntimeStatus { disabled, starting, ready, failed }

class TorRuntimeState {
  const TorRuntimeState({
    this.status = TorRuntimeStatus.disabled,
    this.usingExistingService = false,
    this.message,
  });

  final TorRuntimeStatus status;
  final bool usingExistingService;
  final String? message;

  bool get isReady => status == TorRuntimeStatus.ready;
}

/// Starts and owns the bundled Tor process when the setting is enabled.
/// Existing SOCKS services on 127.0.0.1:9050 are used but never stopped here.
class TorProxyService extends StateNotifier<TorRuntimeState> {
  TorProxyService() : super(const TorRuntimeState());

  static const _startupTimeout = Duration(minutes: 4);
  static const _bootstrapMarker = 'Bootstrapped 100%';

  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  Completer<void>? _bootstrapCompleter;
  final List<String> _recentOutput = [];
  int _generation = 0;
  bool _shuttingDown = false;

  Future<void> setEnabled(bool enabled) async {
    final generation = ++_generation;
    if (!enabled) {
      await _stopOwnedProcess();
      if (generation == _generation && !_shuttingDown) {
        state = const TorRuntimeState();
      }
      return;
    }

    if (state.status == TorRuntimeStatus.starting || state.isReady) return;
    state = const TorRuntimeState(status: TorRuntimeStatus.starting);
    _recentOutput.clear();

    try {
      if (await TorProxyGuard.isTorListening(
        TorProxyGuard.host,
        TorProxyGuard.port,
        const Duration(seconds: 2),
      )) {
        if (generation == _generation) {
          state = const TorRuntimeState(
            status: TorRuntimeStatus.ready,
            usingExistingService: true,
          );
        }
        return;
      }

      if (!Platform.isWindows) {
        throw StateError(
          'Automatic Tor is included for Windows. No SOCKS service is available at ${TorProxyGuard.host}:${TorProxyGuard.port}.',
        );
      }

      final bundleRoot = await _findBundleRoot();
      if (bundleRoot == null) {
        throw StateError(
          'The bundled Tor files are missing. Reinstall the app with its Tor bundle.',
        );
      }

      final torHome = await _prepareTorHome();
      final configFile = await _writeTorConfig(bundleRoot, torHome);
      if (generation != _generation || _shuttingDown) return;

      final executable = p.join(bundleRoot, 'tor', 'tor.exe');
      LoggerService.i('Starting bundled Tor from $executable');
      final process = await Process.start(
        executable,
        ['-f', configFile.path],
        workingDirectory: p.join(bundleRoot, 'tor'),
        runInShell: false,
        mode: ProcessStartMode.normal,
      );
      if (generation != _generation || _shuttingDown) {
        process.kill();
        return;
      }

      _process = process;
      _bootstrapCompleter = Completer<void>();
      _stdoutSubscription = process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(_handleTorOutput);
      _stderrSubscription = process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(_handleTorOutput);
      unawaited(_watchProcessExit(process, generation));

      await _bootstrapCompleter!.future.timeout(_startupTimeout);
      if (generation == _generation && !_shuttingDown) {
        state = const TorRuntimeState(status: TorRuntimeStatus.ready);
        LoggerService.i('Tor bootstrap completed; SOCKS proxy is ready');
      }
    } on Object catch (error) {
      if (generation == _generation && !_shuttingDown) {
        final lastLine = _recentOutput.isEmpty ? null : _recentOutput.last;
        state = TorRuntimeState(
          status: TorRuntimeStatus.failed,
          message: _userFacingError(error, lastLine),
        );
        LoggerService.e('Could not start Tor proxy', error);
      }
      await _stopOwnedProcess();
    }
  }

  Future<void> shutdown() async {
    _shuttingDown = true;
    ++_generation;
    await _stopOwnedProcess();
  }

  void _handleTorOutput(String line) {
    if (line.trim().isEmpty) return;
    LoggerService.debug('Tor: $line');
    _recentOutput.add(line.trim());
    if (_recentOutput.length > 30) _recentOutput.removeAt(0);
    if (line.contains(_bootstrapMarker) &&
        !(_bootstrapCompleter?.isCompleted ?? true)) {
      _bootstrapCompleter!.complete();
    }
  }

  Future<void> _watchProcessExit(Process process, int generation) async {
    final exitCode = await process.exitCode;
    if (!identical(_process, process)) return;
    _process = null;
    final reason = 'Tor s’est arrêté (code $exitCode).';
    final bootstrap = _bootstrapCompleter;
    if (bootstrap != null && !bootstrap.isCompleted) {
      bootstrap.completeError(StateError(reason));
    }
    if (generation == _generation && !_shuttingDown) {
      state = TorRuntimeState(status: TorRuntimeStatus.failed, message: reason);
      LoggerService.w(reason);
    }
    await _cancelOutputSubscriptions();
  }

  Future<void> _stopOwnedProcess() async {
    final process = _process;
    _process = null;
    final bootstrap = _bootstrapCompleter;
    if (bootstrap != null && !bootstrap.isCompleted) {
      bootstrap.completeError(
        StateError('Tor was stopped before it was ready.'),
      );
    }
    if (process != null) {
      try {
        process.kill();
        await process.exitCode.timeout(const Duration(seconds: 5));
      } on Object catch (error) {
        LoggerService.w('Could not stop the bundled Tor process: $error');
      }
    }
    await _cancelOutputSubscriptions();
    _bootstrapCompleter = null;
  }

  Future<void> _cancelOutputSubscriptions() async {
    final stdoutSubscription = _stdoutSubscription;
    final stderrSubscription = _stderrSubscription;
    _stdoutSubscription = null;
    _stderrSubscription = null;
    await stdoutSubscription?.cancel();
    await stderrSubscription?.cancel();
  }

  Future<String?> _findBundleRoot() async {
    final executableDirectory = p.dirname(Platform.resolvedExecutable);
    final currentDirectory = Directory.current.path;
    final candidates = <String>[
      p.join(executableDirectory, 'bin', 'tor-bundle-expert'),
      p.join(executableDirectory, 'tor-bundle-expert'),
      p.join(currentDirectory, 'tor-bundle-expert'),
      p.join(currentDirectory, 'bin', 'tor-bundle-expert'),
      p.join(
        currentDirectory,
        'build',
        'windows',
        'x64',
        'runner',
        'Release',
        'bin',
        'tor-bundle-expert',
      ),
    ];
    for (final candidate in candidates) {
      if (await File(p.join(candidate, 'tor', 'tor.exe')).exists() &&
          await File(p.join(candidate, 'data', 'geoip')).exists() &&
          await File(p.join(candidate, 'data', 'geoip6')).exists()) {
        return candidate;
      }
    }
    return null;
  }

  Future<String> _prepareTorHome() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final torHome = Directory(p.join(supportDirectory.path, 'tor'));
    await Directory(p.join(torHome.path, 'data')).create(recursive: true);
    return torHome.path;
  }

  Future<File> _writeTorConfig(String bundleRoot, String torHome) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final configDirectory = Directory(p.join(supportDirectory.path, 'tor'));
    await configDirectory.create(recursive: true);
    final configFile = File(p.join(configDirectory.path, 'torrc'));

    String quotePath(String path) => '"${path.replaceAll('\\', '\\\\')}"';

    final lines = <String>[
      'ClientOnly 1',
      'SocksPort ${TorProxyGuard.host}:${TorProxyGuard.port}',
      'SafeSocks 1',
      'AvoidDiskWrites 1',
      'Log notice stdout',
      'DataDirectory ${quotePath(p.join(torHome, 'data'))}',
      'GeoIPFile ${quotePath(p.join(bundleRoot, 'data', 'geoip'))}',
      'GeoIPv6File ${quotePath(p.join(bundleRoot, 'data', 'geoip6'))}',
    ];
    await configFile.writeAsString('${lines.join('\n')}\n', flush: true);
    return configFile;
  }

  String _userFacingError(Object error, String? lastLine) {
    final detail = error.toString().replaceFirst('Bad state: ', '').trim();
    if (detail.contains('TimeoutException')) {
      return 'Tor n’a pas terminé sa connexion en 4 minutes. Vérifie la connexion Internet puis désactive et réactive l’option.';
    }
    if (detail.contains('missing')) return detail;
    if (lastLine != null && lastLine.isNotEmpty) return lastLine;
    return detail;
  }
}

final torProxyServiceProvider =
    StateNotifierProvider<TorProxyService, TorRuntimeState>((ref) {
      final service = TorProxyService();
      ref.listen<bool>(
        settingsProvider.select((settings) => settings.useTorProxy),
        (_, enabled) => unawaited(service.setEnabled(enabled)),
      );
      ref.onDispose(() => unawaited(service.shutdown()));
      unawaited(service.setEnabled(ref.read(settingsProvider).useTorProxy));
      return service;
    });
