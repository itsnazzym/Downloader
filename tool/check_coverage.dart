import 'dart:io';

/// Fails if lcov line coverage is below [--min] (default 20).
///
/// Usage:
///   dart run tool/check_coverage.dart
///   dart run tool/check_coverage.dart --min 20 coverage/lcov.info
void main(List<String> args) {
  var minPct = 20.0;
  var path = 'coverage/lcov.info';

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--min') {
      if (i + 1 >= args.length) {
        stderr.writeln('Missing value for --min');
        exitCode = 1;
        return;
      }
      minPct = double.tryParse(args[++i]) ?? -1;
      if (minPct < 0) {
        stderr.writeln('Invalid --min value');
        exitCode = 1;
        return;
      }
    } else if (arg.startsWith('-')) {
      stderr.writeln('Unknown flag: $arg');
      exitCode = 1;
      return;
    } else {
      path = arg;
    }
  }

  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Missing $path — run flutter test --coverage first.');
    exitCode = 1;
    return;
  }

  var found = 0;
  var hit = 0;
  try {
    for (final line in file.readAsLinesSync()) {
      if (!line.startsWith('DA:')) continue;
      final comma = line.indexOf(',');
      if (comma < 0 || comma + 1 >= line.length) continue;
      final execCount = int.tryParse(line.substring(comma + 1).trim());
      if (execCount == null) continue;
      found++;
      if (execCount > 0) hit++;
    }
  } on FileSystemException catch (e) {
    stderr.writeln('Failed to read $path: $e');
    exitCode = 1;
    return;
  }

  if (found == 0) {
    stderr.writeln('No DA records in $path');
    exitCode = 1;
    return;
  }

  final pct = 100.0 * hit / found;
  stdout.writeln(
    'Line coverage: ${pct.toStringAsFixed(2)}% ($hit/$found) — min ${minPct.toStringAsFixed(0)}%',
  );
  if (pct < minPct) {
    stderr.writeln(
      'Coverage ${pct.toStringAsFixed(2)}% is below ${minPct.toStringAsFixed(0)}%',
    );
    exitCode = 1;
  }
}
