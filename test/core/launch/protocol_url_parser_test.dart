import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/launch/protocol_url_parser.dart';

void main() {
  group('ProtocolUrlParser.extractMediaUrl', () {
    test('reads url query from moderndownloader://open?url=', () {
      const uri =
          'moderndownloader://open?url=https://www.youtube.com/watch?v=abc123';
      expect(
        ProtocolUrlParser.extractMediaUrl(uri),
        'https://www.youtube.com/watch?v=abc123',
      );
    });

    test('returns null when url query is missing', () {
      expect(
        ProtocolUrlParser.extractMediaUrl('moderndownloader://open'),
        isNull,
      );
    });

    test('returns null for garbage input', () {
      expect(ProtocolUrlParser.extractMediaUrl('not a uri :::'), isNull);
    });
  });
}
