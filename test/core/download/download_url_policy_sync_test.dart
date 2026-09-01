import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/download_url_policy.dart';

Set<String> _jsStringList(String source, String varName) {
  final match = RegExp('var $varName = \\[([\\s\\S]*?)\\];').firstMatch(source);
  expect(match, isNotNull, reason: 'Missing JS list $varName');
  return RegExp(
    r"'([^']+)'",
  ).allMatches(match!.group(1)!).map((m) => m.group(1)!).toSet();
}

void main() {
  test('JS download allowlists match DownloadUrlPolicy', () {
    final js = File('extension/shared/url_policy.js').readAsStringSync();
    expect(
      _jsStringList(js, 'ALLOWED_DOWNLOAD_DOMAINS'),
      DownloadUrlPolicy.allowedDomains,
    );
    expect(_jsStringList(js, 'ADULT_DOMAINS'), DownloadUrlPolicy.adultDomains);
  });
}
