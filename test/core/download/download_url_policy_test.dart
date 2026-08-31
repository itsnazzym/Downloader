import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/download_url_policy.dart';

void main() {
  group('DownloadUrlPolicy.isAllowed', () {
    test('allows X/Twitter status permalinks', () {
      expect(
        DownloadUrlPolicy.isAllowed('https://x.com/alice/status/2093058718350893415'),
        isTrue,
      );
      expect(
        DownloadUrlPolicy.isAllowed(
          'https://twitter.com/i/status/2091798624661602420',
        ),
        isTrue,
      );
    });

    test('allows known video hosts', () {
      expect(
        DownloadUrlPolicy.isAllowed('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        isTrue,
      );
      expect(
        DownloadUrlPolicy.isAllowed('https://www.tiktok.com/@u/video/1'),
        isTrue,
      );
    });

    test('rejects Discord invites and other external links', () {
      expect(
        DownloadUrlPolicy.isAllowed('https://discord.com/invite/JoinForbidden'),
        isFalse,
      );
      expect(
        DownloadUrlPolicy.isAllowed('https://example.com/video.mp4'),
        isFalse,
      );
    });

    test('rejects bare X CDN URLs without a status permalink', () {
      expect(
        DownloadUrlPolicy.isAllowed(
          'https://video.twimg.com/ext_tw_video/1891234567890123456/pu/vid/720x1280/x.mp4',
        ),
        isFalse,
      );
    });
  });
}
