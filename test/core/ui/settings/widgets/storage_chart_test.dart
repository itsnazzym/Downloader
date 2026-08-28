import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

void main() {
  test('storage folder l10n keys are generated', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.storageFolder, 'Folder');
    expect(en.storageOtherUsed, 'Other used');
    expect(en.storageFolderOfUsed('12.5'), '12.5% of used');
    expect(en.storageFileCount(0), '0 files');
    expect(en.storageFileCount(1), '1 file');
    expect(en.storageFileCount(3), '3 files');
    expect(en.storageScanError, 'Could not read this folder');
    expect(en.storageLastScanned('14:05'), 'Scanned at 14:05');
    expect(en.storageScanCached, 'Cached');
    expect(en.storageScanInProgress, 'Scanning folder...');
  });
}
