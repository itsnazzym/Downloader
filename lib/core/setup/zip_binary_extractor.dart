import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Pulls named executables out of a zip, regardless of nested folders.
class ZipBinaryExtractor {
  const ZipBinaryExtractor._();

  static Map<String, List<int>> extractExecutables(
    List<int> zipBytes,
    Set<String> wantedBasenames,
  ) {
    final wanted = {for (final name in wantedBasenames) name.toLowerCase()};
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final found = <String, List<int>>{};

    for (final file in archive) {
      if (!file.isFile) continue;
      final base = p.basename(file.name).toLowerCase();
      if (!wanted.contains(base)) continue;
      found[base] = List<int>.from(file.content);
    }

    return found;
  }
}
