import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../logger/logger_service.dart';
import '../services/binary/binary_locator.dart';
import '../services/binary/process_runner.dart';
import 'dependency_catalog.dart';
import 'zip_binary_extractor.dart';

enum SetupStep {
  checking,
  downloading,
  extracting,
  verifying,
  updating,
  ready,
  failed,
}

class DependencyBootstrapProgress {
  const DependencyBootstrapProgress({
    required this.step,
    required this.toolName,
    this.fraction,
    this.detail,
    this.errors = const [],
    this.readyTools = const [],
  });

  final SetupStep step;
  final String toolName;
  final double? fraction;
  final String? detail;
  final List<String> errors;
  final List<String> readyTools;
}

class DependencyBootstrapService {
  DependencyBootstrapService({
    BinaryLocator? locator,
    HttpClient Function()? httpClientFactory,
    ProcessRunner? processRunner,
  }) : _locator = locator ?? BinaryLocator(),
       _httpClientFactory = httpClientFactory ?? (() => HttpClient()),
       _processRunner = processRunner;

  final BinaryLocator _locator;
  final HttpClient Function() _httpClientFactory;
  final ProcessRunner? _processRunner;

  static const _userAgent = 'ModernDownloader/1.0.3 (Windows; bootstrap)';

  Future<void> ensureReady({
    required void Function(DependencyBootstrapProgress progress) onProgress,
    bool checkOptionalGobird = false,
  }) async {
    LoggerService.i('Checking required download tools');
    if (!Platform.isWindows) {
      onProgress(
        const DependencyBootstrapProgress(step: SetupStep.ready, toolName: ''),
      );
      return;
    }

    final ready = <String>[];
    final errors = <String>[];
    final binDir = await BinaryLocator.resolveAppBinDirectory();

    await _emitProgress(
      onProgress,
      DependencyBootstrapProgress(
        step: SetupStep.checking,
        toolName: '',
        readyTools: List<String>.from(ready),
      ),
    );

    final requiredChecks = await Future.wait(
      DependencyCatalog.windowsRequired.map((pkg) async {
        try {
          final missing = await _missingExecutables(pkg);
          return (pkg: pkg, missing: missing, error: null);
        } catch (e) {
          LoggerService.e('Failed to check ${pkg.displayName}', e);
          return (pkg: pkg, missing: pkg.executableNames, error: e);
        }
      }),
    );

    for (final result in requiredChecks) {
      final pkg = result.pkg;
      if (result.error != null) {
        errors.add('${pkg.displayName}: ${result.error}');
        await _emitProgress(
          onProgress,
          DependencyBootstrapProgress(
            step: SetupStep.checking,
            toolName: pkg.displayName,
            readyTools: List<String>.from(ready),
            errors: List<String>.from(errors),
          ),
        );
        continue;
      }
      if (result.missing.isEmpty) {
        ready.addAll(pkg.executableNames);
        await _emitProgress(
          onProgress,
          DependencyBootstrapProgress(
            step: SetupStep.checking,
            toolName: pkg.displayName,
            readyTools: List<String>.from(ready),
          ),
        );
      }
    }

    for (final result in requiredChecks) {
      if (result.missing.isEmpty || result.error != null) {
        continue;
      }
      final pkg = result.pkg;
      await _emitProgress(
        onProgress,
        DependencyBootstrapProgress(
          step: SetupStep.checking,
          toolName: pkg.displayName,
          readyTools: List<String>.from(ready),
        ),
      );

      try {
        await _installPackage(
          pkg: pkg,
          binDir: binDir,
          onProgress: onProgress,
          readyTools: ready,
        );

        final stillMissing = await _missingExecutables(pkg);
        if (stillMissing.isEmpty) {
          ready.addAll(pkg.executableNames);
          await _emitProgress(
            onProgress,
            DependencyBootstrapProgress(
              step: SetupStep.checking,
              toolName: pkg.displayName,
              readyTools: List<String>.from(ready),
            ),
          );
        } else {
          errors.add(
            '${pkg.displayName}: missing ${stillMissing.join(', ')} after install',
          );
        }
      } catch (e) {
        LoggerService.e('Failed to install ${pkg.displayName}', e);
        errors.add('${pkg.displayName}: $e');
      }
    }

    if (checkOptionalGobird) {
      for (final pkg in DependencyCatalog.windowsOptional) {
        await _emitProgress(
          onProgress,
          DependencyBootstrapProgress(
            step: SetupStep.checking,
            toolName: pkg.displayName,
            readyTools: List<String>.from(ready),
          ),
        );

        try {
          final missing = await _missingExecutables(
            pkg,
            allowOptionalPathProbe: true,
          );
          if (missing.isEmpty) {
            ready.addAll(pkg.executableNames);
            await _emitProgress(
              onProgress,
              DependencyBootstrapProgress(
                step: SetupStep.checking,
                toolName: pkg.displayName,
                readyTools: List<String>.from(ready),
              ),
            );
          } else {
            LoggerService.w(
              'Optional dependency ${pkg.displayName} is unavailable: '
              '${missing.join(', ')}',
            );
          }
        } catch (e) {
          LoggerService.w(
            'Optional dependency ${pkg.displayName} check failed: $e',
          );
        }
      }
    }

    if (errors.isEmpty) {
      onProgress(
        DependencyBootstrapProgress(
          step: SetupStep.ready,
          toolName: '',
          readyTools: ready,
        ),
      );
      return;
    }

    onProgress(
      DependencyBootstrapProgress(
        step: SetupStep.failed,
        toolName: '',
        errors: errors,
        readyTools: ready,
      ),
    );
  }

  Future<void> updateYtDlpInBackground() async {
    await _updateYtDlp();
  }

  Future<void> _emitProgress(
    void Function(DependencyBootstrapProgress progress) onProgress,
    DependencyBootstrapProgress progress,
  ) async {
    onProgress(progress);
    await Future<void>.delayed(Duration.zero);
  }

  Future<List<String>> _missingExecutables(
    DependencyPackage pkg, {
    bool allowOptionalPathProbe = false,
  }) async {
    final results = await Future.wait(
      pkg.executableNames.map((name) async {
        try {
          final finder = _finderFor(
            name,
            allowOptionalPathProbe: allowOptionalPathProbe,
          );
          final path = await finder();
          return path == null ? name : null;
        } catch (e) {
          LoggerService.w('Lookup failed for $name: $e');
          return name;
        }
      }),
    );
    return [
      for (final name in results)
        if (name != null) name,
    ];
  }

  Future<String?> Function() _finderFor(
    String executableName, {
    bool allowOptionalPathProbe = false,
  }) {
    final lower = executableName.toLowerCase();
    if (lower.startsWith('yt-dlp')) return _locator.findYtDlp;
    if (lower.startsWith('ffmpeg')) return _locator.findFfmpeg;
    if (lower.startsWith('ffprobe')) return _locator.findFfprobe;
    if (lower.startsWith('aria2')) return _locator.findAria2c;
    if (lower.startsWith('gobird')) {
      return () => _locator.findGobird(allowPathProbe: allowOptionalPathProbe);
    }
    return () async => null;
  }

  Future<void> _installPackage({
    required DependencyPackage pkg,
    required Directory binDir,
    required void Function(DependencyBootstrapProgress progress) onProgress,
    required List<String> readyTools,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('md-setup-');
    try {
      final downloadName = pkg.kind == DependencyKind.zip
          ? '${pkg.id}.zip'
          : pkg.executableNames.first;
      final downloadFile = File(p.join(tempDir.path, downloadName));

      onProgress(
        DependencyBootstrapProgress(
          step: SetupStep.downloading,
          toolName: pkg.displayName,
          fraction: 0,
          readyTools: List<String>.from(readyTools),
        ),
      );

      await _download(Uri.parse(pkg.downloadUrl), downloadFile, (
        received,
        total,
      ) {
        onProgress(
          DependencyBootstrapProgress(
            step: SetupStep.downloading,
            toolName: pkg.displayName,
            fraction: total != null && total > 0 ? received / total : null,
            readyTools: List<String>.from(readyTools),
          ),
        );
      });

      if (pkg.kind == DependencyKind.executable) {
        final dest = File(p.join(binDir.path, pkg.executableNames.first));
        if (await dest.exists()) {
          await dest.delete();
        }
        await downloadFile.copy(dest.path);
      } else {
        onProgress(
          DependencyBootstrapProgress(
            step: SetupStep.extracting,
            toolName: pkg.displayName,
            readyTools: List<String>.from(readyTools),
          ),
        );
        final bytes = await downloadFile.readAsBytes();
        final wanted = pkg.executableNames.toSet();
        final extracted = await Isolate.run(
          () => ZipBinaryExtractor.extractExecutables(bytes, wanted),
        );
        for (final name in pkg.executableNames) {
          final payload = extracted[name.toLowerCase()];
          if (payload == null) {
            throw StateError('$name not found in archive');
          }
          final dest = File(p.join(binDir.path, name));
          if (await dest.exists()) {
            await dest.delete();
          }
          await dest.writeAsBytes(payload, flush: true);
        }
      }

      onProgress(
        DependencyBootstrapProgress(
          step: SetupStep.verifying,
          toolName: pkg.displayName,
          readyTools: List<String>.from(readyTools),
        ),
      );

      for (final name in pkg.executableNames) {
        final path = p.join(binDir.path, name);
        final arg = pkg.versionArgs[name] ?? '--version';
        final ok = await _verifyExecutable(path, arg);
        if (!ok) {
          throw StateError('$name did not run after install');
        }
      }
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> _download(
    Uri url,
    File dest,
    void Function(int received, int? total) onBytes,
  ) async {
    final client = _httpClientFactory();
    client.userAgent = _userAgent;
    client.connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(url);
      request.followRedirects = true;
      request.maxRedirects = 8;
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final response = await request.close().timeout(
        const Duration(minutes: 8),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode} for $url', uri: url);
      }
      final total = response.contentLength >= 0 ? response.contentLength : null;
      final sink = dest.openWrite();
      var received = 0;
      try {
        await for (final chunk in response) {
          received += chunk.length;
          sink.add(chunk);
          onBytes(received, total);
        }
      } finally {
        await sink.close();
      }
      if (received == 0) {
        throw StateError('Empty download from $url');
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _verifyExecutable(String path, String versionArg) async {
    try {
      final processRunner = _processRunner;
      if (processRunner != null) {
        final result = await processRunner
            .run(path, [versionArg])
            .timeout(const Duration(seconds: 20));
        return result.exitCode == 0;
      }
      final exitCode = await Isolate.run(() async {
        final result = await Process.run(path, [
          versionArg,
        ], runInShell: false).timeout(const Duration(seconds: 20));
        return result.exitCode;
      });
      return exitCode == 0;
    } catch (e) {
      LoggerService.w('Verify failed for $path: $e');
      return false;
    }
  }

  Future<void> _updateYtDlp() async {
    try {
      final ytDlpPath = await _locator.findYtDlp();
      if (ytDlpPath == null) return;
      final processRunner = _processRunner;
      if (processRunner != null) {
        await processRunner
            .run(ytDlpPath, ['--update'])
            .timeout(const Duration(seconds: 45));
        return;
      }
      await Process.run(ytDlpPath, [
        '--update',
      ], runInShell: false).timeout(const Duration(seconds: 45));
    } catch (e) {
      LoggerService.w('yt-dlp update skipped: $e');
    }
  }
}
