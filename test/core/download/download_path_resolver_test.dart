import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/download_path_resolver.dart';

void main() {
  group('DownloadPathResolver.resolve', () {
    test('prefers the settings output folder', () {
      expect(
        DownloadPathResolver.resolve(
          settingsOutputFolder: r'D:\Media',
          itemFolders: [r'C:\Videos\VOILA'],
          userProfile: r'C:\Users\me',
        ),
        r'D:\Media',
      );
    });

    test('falls back to user Downloads, never VOILA', () {
      expect(
        DownloadPathResolver.resolve(
          settingsOutputFolder: '',
          itemFolders: const [],
          userProfile: r'C:\Users\me',
        ),
        r'C:\Users\me\Downloads',
      );
    });

    test('returns null when folder is empty, itemFolders is empty, and userProfile is missing', () {
      expect(
        DownloadPathResolver.resolve(
          settingsOutputFolder: '  ',
          itemFolders: const [],
          userProfile: null,
        ),
        isNull,
      );
    });

    test('uses user Downloads when output folder is empty and itemFolders is empty', () {
      expect(
        DownloadPathResolver.resolve(
          settingsOutputFolder: '',
          itemFolders: const [],
          userProfile: r'C:\Users\me',
        ),
        r'C:\Users\me\Downloads',
      );
    });
  });
}
