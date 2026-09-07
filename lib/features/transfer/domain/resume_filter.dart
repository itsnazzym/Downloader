import 'transfer_models.dart';

class ExistingDestFile {
  const ExistingDestFile({required this.size, this.sha256});

  final int size;
  final String? sha256;
}

class ResumeFilter {
  const ResumeFilter._();

  /// Drops files already complete on the destination (sha256 if both known,
  /// otherwise size match).
  static List<TransferFile> pending({
    required List<TransferFile> files,
    required Map<String, ExistingDestFile> destByRelativePath,
  }) {
    final pending = <TransferFile>[];
    for (final file in files) {
      final existing = destByRelativePath[file.fileName];
      if (existing == null) {
        pending.add(file);
        continue;
      }
      if (file.sha256 != null &&
          existing.sha256 != null &&
          file.sha256 == existing.sha256) {
        continue;
      }
      if (file.sha256 == null &&
          existing.sha256 == null &&
          existing.size == file.size) {
        continue;
      }
      if (file.sha256 != null &&
          existing.sha256 == null &&
          existing.size == file.size) {
        continue;
      }
      pending.add(file);
    }
    return pending;
  }
}
