import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/services/heartbeat_cookie_locator.dart';

void main() {
  test('finds the cookie file of the host or a parent domain', () async {
    final file = File(
      '${Directory.systemTemp.path}/heartbeat_cookies_taploadtest.example.txt',
    );
    await file.writeAsString('# Netscape HTTP Cookie File\n');
    addTearDown(() => file.delete());

    expect(
      await HeartbeatCookieLocator.pathForUrl(
        'https://www.taploadtest.example/watch?v=1',
      ),
      isNotNull,
    );
    expect(
      await HeartbeatCookieLocator.pathForUrl('https://taploadtest.example/'),
      isNotNull,
    );
    expect(
      await HeartbeatCookieLocator.pathForUrl(
        'https://nottaploadtest.example/',
      ),
      isNull,
    );
  });
}
