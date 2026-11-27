import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/core/security/extension_origin.dart';
import 'package:tapload/core/security/paired_browsers.dart';
import 'package:tapload/core/ui/settings/widgets/paired_browsers_panel.dart';
import 'package:tapload/l10n/app_localizations.dart';

const _a = 'chrome-extension://abcdefghijklmnopabcdefghijklmnop';
const _b = 'moz-extension://11111111-2222-3333-4444-555555555555';

void main() {
  late PairedBrowsersStore store;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    initPrefs(p);
    store = PairedBrowsersStore(p);
    container = ProviderContainer(
      overrides: [pairedBrowsersProvider.overrideWith((_) => store)],
    );
    addTearDown(container.dispose);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: PairedBrowsersPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pairTwo(WidgetTester tester) => tester.runAsync(() async {
    await store.pair(origin: _a, label: 'Chrome');
    await store.pair(origin: _b, label: 'Firefox');
  });

  Future<void> confirmRevoke(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Révoquer'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty list shows the help text', (tester) async {
    await pump(tester);
    expect(find.textContaining('Aucun navigateur appairé'), findsOneWidget);
    expect(find.text('Révoquer tout'), findsNothing);
  });

  testWidgets('lists browsers, revokes one only after confirmation', (
    tester,
  ) async {
    await pairTwo(tester);
    await pump(tester);
    expect(find.text('Chrome'), findsOneWidget);
    expect(find.text('Firefox'), findsOneWidget);
    await tester.tap(find.text('Révoquer').first);
    await tester.pumpAndSettle();
    expect(store.state.browsers, hasLength(2));
    await confirmRevoke(tester);
    expect(store.state.browsers.map((b) => b.label), ['Firefox']);
  });

  testWidgets('each Révoquer button names its browser for screen readers', (
    tester,
  ) async {
    await pairTwo(tester);
    await pump(tester);
    expect(find.byTooltip('Révoquer Chrome'), findsOneWidget);
    expect(find.byTooltip('Révoquer Firefox'), findsOneWidget);
  });

  testWidgets('an unknown browser is named in the UI language', (tester) async {
    await tester.runAsync(
      () => store.pair(origin: _a, label: ExtensionOrigin.unknownBrowser),
    );
    await pump(tester);
    expect(find.text('Navigateur'), findsOneWidget);
    expect(find.byTooltip('Révoquer Navigateur'), findsOneWidget);
  });

  testWidgets('Révoquer tout', (tester) async {
    await pairTwo(tester);
    await pump(tester);
    await tester.tap(find.text('Révoquer tout'));
    await tester.pumpAndSettle();
    await confirmRevoke(tester);
    expect(store.state.browsers, isEmpty);
  });

  testWidgets('blocked origin can be unblocked', (tester) async {
    await tester.runAsync(() => store.block(_a));
    await pump(tester);
    expect(find.text('Origines bloquées'), findsOneWidget);
    expect(
      find.byTooltip('Débloquer ${PairedBrowsersPanel.shortOrigin(_a)}'),
      findsOneWidget,
    );
    await tester.tap(find.text('Débloquer'));
    await tester.pumpAndSettle();
    expect(store.state.blockedOrigins, isEmpty);
  });

  testWidgets('manual token is under Avancé and copyable', (tester) async {
    final token = container.read(settingsProvider).apiToken;
    String? copied;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await pump(tester);
    expect(find.text(token), findsNothing);
    await tester.tap(find.text('Avancé : jeton manuel'));
    await tester.pumpAndSettle();
    expect(find.text(token), findsOneWidget);
    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();
    expect(copied, token);
    await tester.pump(const Duration(seconds: 10));
  });
}
