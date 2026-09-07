import 'package:path/path.dart' as p;

class TransferPathGuard {
  const TransferPathGuard._();

  static final _absoluteWin = RegExp(r'^[a-zA-Z]:');
  static final _illegal = RegExp(r'[<>:"|?*\x00-\x1F]');

  /// Returns a posix relative path, or null if [fileName] is unsafe.
  static String? relativePathOrNull(String fileName) {
    var name = fileName.trim().replaceAll('\\', '/');
    if (name.isEmpty) return null;
    if (name.startsWith('/') || _absoluteWin.hasMatch(name)) return null;
    if (name.contains('\x00')) return null;

    final parts = name.split('/');
    final kept = <String>[];
    for (final part in parts) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') return null;
      if (part == 'library-manifest.json' && kept.isEmpty) {
        kept.add(part);
        continue;
      }
      final cleaned = part.replaceAll(_illegal, '_');
      if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return null;
      kept.add(cleaned);
    }
    if (kept.isEmpty) return null;
    return kept.join('/');
  }

  /// Resolves [fileName] under [rootPath]. Returns null if it would escape.
  static String? resolveUnderRoot(String rootPath, String fileName) {
    final relative = relativePathOrNull(fileName);
    if (relative == null) return null;
    final root = p.normalize(rootPath);
    final resolved = p.normalize(p.join(root, relative));
    if (resolved == root) return null;
    if (!p.isWithin(root, resolved)) return null;
    return resolved;
  }
}
