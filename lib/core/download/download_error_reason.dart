/// The readable cause of a failed download: yt-dlp's `ERROR:` line (else the
/// first line), without the exit-code lead-in, the level, the
/// `[extractor] id:` tag, the "Unable to download…:" lead-in and the
/// "please report this issue" tail. Empty when there is nothing to say.
String downloadErrorReason(String? raw) {
  final exitCode = RegExp(
    r'^yt-dlp exited with code -?\d+\.?\s*(Error:\s*)?',
    caseSensitive: false,
  );
  final lines = [
    for (final l in (raw ?? '').split(RegExp(r'\r?\n')))
      if (l.trim().replaceFirst(exitCode, '').isNotEmpty)
        l.trim().replaceFirst(exitCode, ''),
  ];
  if (lines.isEmpty) return '';
  final line = lines.firstWhere(
    (l) => l.toUpperCase().startsWith('ERROR'),
    orElse: () => lines.first,
  );
  return line
      .replaceFirst(
        RegExp(r'^(ERROR|WARNING)\s*[:\-]\s*', caseSensitive: false),
        '',
      )
      .replaceFirst(RegExp(r'^\[[^\]]+\]\s*([\w.\-]+:\s+)?'), '')
      .replaceFirst(
        RegExp(r'^Unable to (download|extract)( [\w ]+?)?:\s*',
            caseSensitive: false),
        '',
      )
      .replaceFirst(
        RegExp(r'[;.]?\s*please report this issue.*$', caseSensitive: false),
        '',
      )
      .replaceFirst(RegExp(r'\s*\(caused by .*\)$', caseSensitive: false), '')
      .trim();
}
