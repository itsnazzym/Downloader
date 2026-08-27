class TempFileCleanup {
  static final RegExp _fragmentSuffix = RegExp(r'\.f\d+$');

  static bool isFragmentOrTemp(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.part') ||
        lower.endsWith('.ytdl') ||
        lower.endsWith('.aria2') ||
        lower.endsWith('.temp') ||
        _fragmentSuffix.hasMatch(lower);
  }
}
