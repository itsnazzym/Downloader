import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/features/downloader/data/datasources/persistence_service.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/entities/download_request.dart';

void main() {
  test('serializes a large download history outside the UI isolate', () async {
    final downloads = List<DownloadItem>.generate(
      2500,
      (index) => DownloadItem(
        id: 'item-$index',
        request: DownloadRequest(url: 'https://example.com/watch/$index'),
        title: 'Downloaded video $index',
        totalSize: '1 GB',
      ),
    );

    final encoded = await encodeDownloadsInBackground(downloads);
    final decoded = jsonDecode(encoded) as List<dynamic>;

    expect(decoded, hasLength(2500));
  });
}
