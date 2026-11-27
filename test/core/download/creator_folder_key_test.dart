import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/download/creator_folder_key.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/entities/download_request.dart';
import 'package:tapload/features/downloader/presentation/models/creator_folder.dart';

DownloadItem _item({
  required String id,
  required String url,
  String? title,
  String? thumbnailUrl,
  String? filePath,
}) {
  return DownloadItem(
    id: id,
    request: DownloadRequest(url: url),
    title: title,
    thumbnailUrl: thumbnailUrl,
    filePath: filePath,
  );
}

void main() {
  group('CreatorFolderKey', () {
    test('groups TikTok URL handles case-insensitively', () {
      final a = CreatorFolderKey.of(
        url: 'https://www.tiktok.com/@Adult_Hoodz/video/1',
      );
      final b = CreatorFolderKey.of(
        url: 'https://www.tiktok.com/@adult_hoodz/video/2',
      );
      expect(a.key, 'adult_hoodz');
      expect(a.handle, 'Adult_Hoodz');
      expect(a.key, b.key);
      expect(a.isUnknown, isFalse);
    });

    test('falls back to title when URL has no handle', () {
      final identity = CreatorFolderKey.of(
        url: 'https://www.youtube.com/watch?v=abc',
        title: 'Veritasium - something [abc]',
      );
      expect(identity.key, 'veritasium');
      expect(identity.handle, 'Veritasium');
    });

    test('unknown bucket when nothing can be parsed', () {
      final identity = CreatorFolderKey.of(
        url: 'https://example.com/video/1',
        title: 'clip',
      );
      expect(identity.isUnknown, isTrue);
      expect(identity.key, CreatorIdentity.unknownKey);
    });
  });

  group('CreatorFolderGrouper', () {
    test('merges same creator and keeps four peek thumbnails', () {
      final folders = CreatorFolderGrouper.fromItems([
        _item(
          id: 'a',
          url: 'https://www.tiktok.com/@neo/video/1',
          thumbnailUrl: 'https://cdn.example/1.jpg',
        ),
        _item(
          id: 'b',
          url: 'https://www.tiktok.com/@neo/video/2',
          thumbnailUrl: 'https://cdn.example/2.jpg',
        ),
        _item(id: 'c', url: 'https://www.tiktok.com/@neo/video/3'),
        _item(
          id: 'd',
          url: 'https://www.tiktok.com/@other/video/4',
          thumbnailUrl: 'https://cdn.example/4.jpg',
        ),
        _item(
          id: 'e',
          url: 'https://www.tiktok.com/@neo/video/5',
          thumbnailUrl: 'https://cdn.example/5.jpg',
        ),
        _item(
          id: 'f',
          url: 'https://www.tiktok.com/@neo/video/6',
          thumbnailUrl: 'https://cdn.example/6.jpg',
        ),
      ]);

      expect(folders.length, 2);
      final neo = folders.firstWhere((f) => f.key == 'neo');
      expect(neo.count, 5);
      expect(neo.overflowCount, 1);
      expect(neo.previewUrls.length, 4);
      expect(neo.itemIds, ['a', 'b', 'c', 'e', 'f']);
    });

    test('sorts by video count descending then name', () {
      final folders = CreatorFolderGrouper.fromItems([
        _item(id: 'z', url: 'https://example.com/x', title: 'clip'),
        _item(id: 'b1', url: 'https://x.com/zeta/status/1'),
        _item(id: 'b2', url: 'https://x.com/zeta/status/2'),
        _item(id: 'a', url: 'https://x.com/alpha/status/1'),
      ], order: CreatorFolderOrder.countDesc);
      expect(folders.map((f) => f.key).toList(), [
        'zeta',
        CreatorIdentity.unknownKey,
        'alpha',
      ]);
    });

    test('sorts by video count ascending', () {
      final folders = CreatorFolderGrouper.fromItems([
        _item(id: 'b1', url: 'https://x.com/zeta/status/1'),
        _item(id: 'b2', url: 'https://x.com/zeta/status/2'),
        _item(id: 'a', url: 'https://x.com/alpha/status/1'),
      ], order: CreatorFolderOrder.countAsc);
      expect(folders.map((f) => f.key).toList(), ['alpha', 'zeta']);
    });

    test('sorts unknown last and named folders A-Z', () {
      final folders = CreatorFolderGrouper.fromItems([
        _item(id: 'z', url: 'https://example.com/x', title: 'clip'),
        _item(id: 'b', url: 'https://x.com/zeta/status/1'),
        _item(id: 'a', url: 'https://x.com/alpha/status/1'),
      ]);
      expect(folders.map((f) => f.key).toList(), [
        'alpha',
        'zeta',
        CreatorIdentity.unknownKey,
      ]);
    });
  });
}
