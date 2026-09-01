import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/download_request_factory.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';

void main() {
  test('DownloadRequestFactory copies settings and applies overrides', () {
    const settings = AppSettings(
      outputFolder: r'C:\Videos',
      audioOnly: false,
      preferredQuality: 'best',
      outputFormat: 'mp4',
      cookieBrowser: 'firefox',
      organizeBySite: true,
    );

    final request = DownloadRequestFactory.fromSettings(
      settings: settings,
      url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      audioOnly: true,
      preferredQuality: '1080p',
      rawCookies: 'auth_token\tvalue',
    );

    expect(request.url, contains('youtube.com'));
    expect(request.outputFolder, r'C:\Videos');
    expect(request.audioOnly, isTrue);
    expect(request.preferredQuality, '1080p');
    expect(request.cookieBrowser, 'firefox');
    expect(request.organizeBySite, isTrue);
    expect(request.rawCookies, 'auth_token\tvalue');
  });
}
