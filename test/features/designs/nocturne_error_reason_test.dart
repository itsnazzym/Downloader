import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/features/designs/shared/design_data.dart';

void main() {
  test('keeps only the readable reason of a yt-dlp error', () {
    expect(
      downloadErrorReason('ERROR: Unable to download: HTTP Error 403: Forbidden'),
      'HTTP Error 403: Forbidden',
    );
    expect(
      downloadErrorReason('\nERROR: [youtube] dQw4w9WgXcQ: Video unavailable\nmore'),
      'Video unavailable',
    );
    expect(downloadErrorReason('Disk full'), 'Disk full');
    expect(downloadErrorReason(null), '');
  });
}
