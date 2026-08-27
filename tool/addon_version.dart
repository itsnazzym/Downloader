/// Firefox/Chrome add-on version helpers (AMO rejects duplicate versions).
library;

import 'dart:convert';
import 'dart:io';

/// Increments the last numeric segment: `2.1.0` → `2.1.1`.
String incrementAddonVersion(String version) {
  final parts = version.trim().split('.');
  if (parts.isEmpty || parts.any((part) => int.tryParse(part) == null)) {
    throw FormatException('Invalid add-on version: $version');
  }
  final last = int.parse(parts.last) + 1;
  if (last > 65535) {
    throw FormatException('Add-on version segment overflow: $version');
  }
  parts[parts.length - 1] = '$last';
  return parts.join('.');
}

/// Replaces the first `"version": "..."` field in a manifest JSON string.
String replaceManifestVersion(String source, String version) {
  return source.replaceFirst(
    RegExp(r'"version"\s*:\s*"[^"]*"'),
    '"version": "$version"',
  );
}

void agentDebugLog({
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, Object?> data = const {},
  String runId = 'pre-fix',
}) {
  // #region agent log
  try {
    final payload = jsonEncode({
      'sessionId': 'd2dcc1',
      'runId': runId,
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    File(
      'debug-d2dcc1.log',
    ).writeAsStringSync('$payload\n', mode: FileMode.append);
  } catch (_) {}
  // #endregion
}
