import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/features/designs/shared/design_data.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/entities/download_request.dart';

void main() {
  test('reads the ERROR line of a real yt-dlp failure, not its warning', () {
    // Shape of the errors stored in the library after a TikTok failure.
    const notAvailable =
        'yt-dlp exited with code 1. Error: WARNING: [TikTok] 7670635041910754573: '
        'Failed to parse JSON (caused by JSONDecodeError("Expecting value")); '
        'trying with webpage\n'
        'ERROR: [TikTok] 7670635041910754573: Video not available, status code '
        '10231; please report this issue on  https://github.com/yt-dlp/yt-dlp/'
        'issues?q= , filling out the appropriate issue template.\n';
    expect(
      downloadErrorReason(notAvailable),
      'Video not available, status code 10231',
    );
    expect(
      downloadErrorReason(
        'yt-dlp exited with code 1. Error: ERROR: [TikTok] 1: No video formats '
        'found!; please report this issue on github',
      ),
      'No video formats found!',
    );
    expect(downloadErrorReason('yt-dlp exited with code 2.'), '');
    expect(downloadErrorReason('Video is age restricted'), 'Video is age restricted');
  });

  test('a row without a title shows its link', () {
    const url = 'https://www.tiktokv.com/share/video/7670635041910754573/';
    DownloadItem item(String? title) =>
        DownloadItem(id: '1', request: const DownloadRequest(url: url), title: title);
    // Failed downloads are stored with an empty title.
    expect(titleOf(item('')), url);
    expect(titleOf(item(null)), url);
    expect(titleOf(item('  ')), url);
    expect(titleOf(item('havent posted in ages')), 'havent posted in ages');
  });
}
