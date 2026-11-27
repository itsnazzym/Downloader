import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/launch/protocol_url_parser.dart';

void main() {
  group('ProtocolUrlParser.extractMediaUrl', () {
    test('reads url query from tapload://open?url=', () {
      const uri =
          'tapload://open?url=https://www.youtube.com/watch?v=abc123';
      expect(
        ProtocolUrlParser.extractMediaUrl(uri),
        'https://www.youtube.com/watch?v=abc123',
      );
    });

    test('returns null when url query is missing', () {
      expect(
        ProtocolUrlParser.extractMediaUrl('tapload://open'),
        isNull,
      );
    });

    test('returns null for garbage input', () {
      expect(ProtocolUrlParser.extractMediaUrl('not a uri :::'), isNull);
    });
  });

  group('ProtocolUrlParser schemes', () {
    test('accepts tapload:// and the legacy moderndownloader:// scheme', () {
      expect(ProtocolUrlParser.extractPluginId('tapload://plugin/x_browser'),
          'x_browser');
      expect(
          ProtocolUrlParser.extractPluginId(
              'moderndownloader://plugin/x_browser'),
          'x_browser');
      expect(ProtocolUrlParser.isProtocolUrl('app.exe moderndownloader://open'),
          isTrue);
      expect(ProtocolUrlParser.isProtocolUrl('https://example.com'), isFalse);
    });

    test('rejects any other scheme', () {
      expect(ProtocolUrlParser.extractPluginId('other://plugin/x_browser'),
          isNull);
    });
  });
}
