import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapload/core/security/extension_origin.dart';
import 'package:tapload/core/security/paired_browsers.dart';
import 'package:tapload/core/security/pairing_coordinator.dart';
import 'package:tapload/core/ui/pairing/pairing_invite_dialog.dart';
import 'package:tapload/core/ui/settings/widgets/paired_browsers_panel.dart';
import 'package:tapload/l10n/app_localizations.dart';

const _origin = 'chrome-extension://abcdefghijklmnopabcdefghijklmnop';
const _other = 'moz-extension://11111111-2222-3333-4444-555555555555';

class _FakeTimer implements Timer {
  _FakeTimer(this.callback);
  final void Function() callback;
  var cancelled = false;
  void fire() => callback();
  @override
  void cancel() => cancelled = true;
  @override
  bool get isActive => !cancelled;
  @override
  int get tick => 0;
}

void main() {
  late PairingCoordinator coordinator;
  late List<_FakeTimer> timers;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    timers = [];
    coordinator = PairingCoordinator(
      PairedBrowsersStore(prefs, random: Random(1)),
      random: Random(3),
      schedule: (_, cb) {
        final t = _FakeTimer(cb);
        timers.add(t);
        return t;
      },
    );
  });

  late Future<void> invite;

  Future<void> open(WidgetTester tester, PairingRequest request) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pairingCoordinatorProvider.overrideWith((_) => coordinator),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () =>
                  invite = showPairingInvite(context, ref, request),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows browser, origin and spaced code', (tester) async {
    final s = coordinator.submit(origin: _origin, label: 'Chrome');
    await open(tester, s.request!);
    final code = s.request!.code.split('').join(' ');
    expect(
      find.text('Une extension de Chrome demande à contrôler TapLoad'),
      findsOneWidget,
    );
    expect(find.text(code), findsOneWidget);
    // Another extension in the same browser gets the same title: only its
    // origin tells them apart.
    final origin = tester.widget<Text>(
      find.text(PairedBrowsersPanel.shortOrigin(_origin)),
    );
    expect(origin.textDirection, TextDirection.ltr);
    expect(origin.style?.fontFamily, 'monospace');
  });

  testWidgets('an unknown browser is named in the UI language', (tester) async {
    final s = coordinator.submit(
      origin: _origin,
      label: ExtensionOrigin.unknownBrowser,
    );
    await open(tester, s.request!);
    expect(
      find.text('Une extension de Navigateur demande à contrôler TapLoad'),
      findsOneWidget,
    );
  });

  testWidgets('expiry with another dialog above closes only the invite', (
    tester,
  ) async {
    final s = coordinator.submit(origin: _origin, label: 'Chrome');
    await open(tester, s.request!);
    var done = false;
    unawaited(invite.then((_) => done = true));
    unawaited(
      showDialog<void>(
        context: tester.element(find.text('open')),
        builder: (_) => const AlertDialog(content: Text('other')),
      ),
    );
    await tester.pumpAndSettle();

    timers.single.fire();
    await tester.pumpAndSettle();
    expect(find.text('other'), findsOneWidget);
    expect(find.text('Autoriser'), findsNothing);
    expect(done, isTrue, reason: 'showPairingInvite must return');
    expect(await s.outcome, isA<PairingExpired>());
  });

  testWidgets('Autoriser approves the request id', (tester) async {
    final s = coordinator.submit(origin: _origin, label: 'Chrome');
    await open(tester, s.request!);
    await tester.tap(find.text('Autoriser'));
    await tester.pumpAndSettle();
    expect(await s.outcome, isA<PairingApproved>());
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Refuser denies', (tester) async {
    final s = coordinator.submit(origin: _origin, label: 'Chrome');
    await open(tester, s.request!);
    await tester.tap(find.text('Refuser'));
    await tester.pumpAndSettle();
    expect(await s.outcome, isA<PairingDenied>());
  });

  testWidgets('Toujours refuser blocks the origin', (tester) async {
    final s = coordinator.submit(origin: _origin, label: 'Chrome');
    await open(tester, s.request!);
    await tester.tap(find.text('Toujours refuser'));
    await tester.pumpAndSettle();
    expect(await s.outcome, isA<PairingDenied>());
    expect(
      coordinator.submit(origin: _origin, label: 'x').refusal,
      PairingRefusal.blocked,
    );
  });

  testWidgets('dismissing the dialog denies', (tester) async {
    final s = coordinator.submit(origin: _origin, label: 'Chrome');
    await open(tester, s.request!);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(await s.outcome, isA<PairingDenied>());
  });

  testWidgets('expiry closes the dialog', (tester) async {
    final s = coordinator.submit(origin: _origin, label: 'Chrome');
    await open(tester, s.request!);
    timers.single.fire();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(await s.outcome, isA<PairingExpired>());
  });

  testWidgets('a second origin is refused busy, no second dialog', (
    tester,
  ) async {
    final s = coordinator.submit(origin: _origin, label: 'Chrome');
    await open(tester, s.request!);
    expect(
      coordinator.submit(origin: _other, label: 'Firefox').refusal,
      PairingRefusal.busy,
    );
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
