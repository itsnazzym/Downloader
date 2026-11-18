import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/launch/protocol_url_parser.dart';
import 'package:modern_downloader/core/plugins/feature_activation.dart';
import 'package:modern_downloader/core/plugins/feature_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FeatureCatalog catalog;

  setUpAll(() {
    catalog = FeatureCatalog.decode(
      File('site/plugin-catalog.json').readAsStringSync(),
    );
  });

  group('FeatureCatalog', () {
    test('loads all catalog items and keeps module routes allowlisted', () {
      expect(catalog.plugins, hasLength(9));
      expect(
        catalog.modules.map((plugin) => plugin.id),
        contains('core_downloads'),
      );
      expect(catalog.byId['x_browser']?.route, '/browse');
      expect(catalog.externalExtensions, hasLength(2));
    });

    test(
      'rejects duplicate IDs and module routes without compiled screens',
      () {
        final source = File('site/plugin-catalog.json').readAsStringSync();
        final duplicate = source.replaceFirst(
          '"id": "chrome_extension"',
          '"id": "x_browser"',
        );
        expect(() => FeatureCatalog.decode(duplicate), throwsFormatException);

        final unregisteredRoute = source.replaceFirst(
          '"route": "/browse"',
          '"route": "/arbitrary-code"',
        );
        expect(
          () => FeatureCatalog.decode(unregisteredRoute),
          throwsFormatException,
        );
      },
    );
  });

  group('feature preference migration', () {
    test('fresh preferences enable only the essential downloader', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await migrateFeaturePluginPreferences(preferences, catalog);

      final activation = FeatureActivationController(
        preferences: preferences,
        catalog: catalog,
      );
      expect(activation.state.isEnabledById('core_downloads'), isTrue);
      expect(activation.state.isEnabledById('x_browser'), isFalse);
      expect(
        preferences.getBool('plugin_enabled_builtin_auto_rename'),
        isFalse,
      );
      activation.dispose();
    });

    test(
      'existing preferences are retained and old plugins stay available',
      () async {
        SharedPreferences.setMockInitialValues({
          'api_token': 'existing-profile',
          'plugin_enabled_builtin_auto_rename': false,
        });
        final preferences = await SharedPreferences.getInstance();
        await migrateFeaturePluginPreferences(preferences, catalog);

        final activation = FeatureActivationController(
          preferences: preferences,
          catalog: catalog,
        );
        expect(activation.state.isEnabledById('x_browser'), isTrue);
        expect(activation.state.isEnabledById('statistics'), isTrue);
        expect(
          preferences.getBool('plugin_enabled_builtin_auto_rename'),
          isFalse,
        );
        expect(
          preferences.getBool('plugin_enabled_builtin_smart_organizer'),
          isTrue,
        );
        activation.dispose();
      },
    );

    test(
      'activation is persisted and core downloads cannot be disabled',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        await migrateFeaturePluginPreferences(preferences, catalog);
        final activation = FeatureActivationController(
          preferences: preferences,
          catalog: catalog,
        );

        await activation.setEnabled('x_browser', true);
        await activation.setEnabled('core_downloads', false);

        expect(activation.state.isEnabledById('x_browser'), isTrue);
        expect(preferences.getBool('feature_enabled_x_browser'), isTrue);
        expect(activation.state.isEnabledById('core_downloads'), isTrue);
        activation.dispose();
      },
    );
  });

  group('website app links', () {
    test('accepts only a single well-formed app catalog ID', () {
      expect(
        ProtocolUrlParser.extractPluginId(
          'moderndownloader://plugin/x_browser',
        ),
        'x_browser',
      );
      expect(
        ProtocolUrlParser.extractPluginId(
          'moderndownloader://plugin/x_browser?enable=true',
        ),
        isNull,
      );
      expect(
        ProtocolUrlParser.extractPluginId('https://plugin/x_browser'),
        isNull,
      );
      expect(
        ProtocolUrlParser.extractPluginId(
          'moderndownloader://plugin/x_browser/extra',
        ),
        isNull,
      );
      expect(
        ProtocolUrlParser.extractPluginId(
          'moderndownloader://plugin/../../settings',
        ),
        isNull,
      );
    });
  });
}
