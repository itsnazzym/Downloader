import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/designs/nocturne/nocturne_states.dart';

void main() {
  test('keeps only the readable reason of a yt-dlp error', () {
    expect(
      nocturneErrorReason('ERROR: Unable to download: HTTP Error 403: Forbidden'),
      'HTTP Error 403: Forbidden',
    );
    expect(
      nocturneErrorReason('\nERROR: [youtube] dQw4w9WgXcQ: Video unavailable\nmore'),
      'Video unavailable',
    );
    expect(nocturneErrorReason('Disk full'), 'Disk full');
    expect(nocturneErrorReason(null), '');
  });
}
