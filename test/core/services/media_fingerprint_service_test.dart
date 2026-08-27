import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/services/media_fingerprint_service.dart';
import 'package:modern_downloader/features/downloader/data/datasources/persistence_service.dart';

class _InMemoryPersistenceService extends PersistenceService {
  Map<String, dynamic>? index;

  @override
  Future<Map<String, dynamic>?> loadMediaFingerprintIndex() async => index;

  @override
  Future<void> saveMediaFingerprintIndex(Map<String, dynamic> value) async {
    index = Map<String, dynamic>.from(value);
  }
}

void main() {
  late Directory temporaryDirectory;
  late _InMemoryPersistenceService persistenceService;
  late MediaFingerprintService fingerprintService;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'media_fingerprint_service_test_',
    );
    persistenceService = _InMemoryPersistenceService();
    fingerprintService = MediaFingerprintService(persistenceService);
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'reports an exact duplicate while keeping the indexed original',
    () async {
      final original = File('${temporaryDirectory.path}/original.mp4');
      final candidate = File('${temporaryDirectory.path}/candidate.mp4');
      await original.writeAsBytes(<int>[1, 2, 3, 4]);
      await candidate.writeAsBytes(<int>[1, 2, 3, 4]);

      expect(
        await fingerprintService.findDuplicateOrRegister(original.path),
        isNull,
      );
      final match = await fingerprintService.findDuplicateOrRegister(
        candidate.path,
      );

      expect(match?.originalPath, original.path);
      expect(await original.exists(), isTrue);
      expect(await candidate.exists(), isTrue);
    },
  );

  test('keeps same-sized files with different bytes', () async {
    final first = File('${temporaryDirectory.path}/first.mp4');
    final second = File('${temporaryDirectory.path}/second.mp4');
    await first.writeAsBytes(<int>[1, 2, 3, 4]);
    await second.writeAsBytes(<int>[4, 3, 2, 1]);

    expect(
      await fingerprintService.findDuplicateOrRegister(first.path),
      isNull,
    );
    expect(
      await fingerprintService.findDuplicateOrRegister(second.path),
      isNull,
    );
    expect(await first.exists(), isTrue);
    expect(await second.exists(), isTrue);
  });

  test('does not delete indexed files when a candidate is missing', () async {
    final original = File('${temporaryDirectory.path}/original.mp4');
    final missing = File('${temporaryDirectory.path}/missing.mp4');
    await original.writeAsBytes(<int>[1, 2, 3, 4]);
    await fingerprintService.findDuplicateOrRegister(original.path);

    await expectLater(
      fingerprintService.findDuplicateOrRegister(missing.path),
      throwsA(isA<FileSystemException>()),
    );
    expect(await original.exists(), isTrue);
  });
}
