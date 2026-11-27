import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/android/android_engine_bridge.dart';

const _methodChannel = MethodChannel('test/engine');
const _eventChannel = EventChannel('test/engineEvents');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  Object? Function(MethodCall call)? respond;

  setUp(() {
    calls.clear();
    respond = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_methodChannel, (call) async {
          calls.add(call);
          return respond?.call(call);
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          _eventChannel,
          MockStreamHandler.inline(onListen: (_, _) {}),
        );
  });

  AndroidEngineBridge bridge() => AndroidEngineBridge(
    methodChannel: _methodChannel,
    eventChannel: _eventChannel,
  );

  test('ensureInitialized calls init once', () async {
    final b = bridge();
    await b.ensureInitialized();
    await b.ensureInitialized();
    expect(calls.where((c) => c.method == 'init'), hasLength(1));
  });

  test('getYtDlpVersion returns the native string', () async {
    respond = (_) => '2026.10.01';
    expect(await bridge().getYtDlpVersion(), '2026.10.01');
    expect(calls.single.method, 'version');
  });

  test('getYtDlpVersion falls back to unknown on a native error', () async {
    respond = (_) => throw PlatformException(code: 'x');
    expect(await bridge().getYtDlpVersion(), 'unknown');
  });

  test('updateYtDlp maps a PlatformException to the failure text', () async {
    respond = (_) => throw PlatformException(code: 'x');
    expect(await bridge().updateYtDlp(), 'Update check failed');
  });

  test('updateYtDlp returns the native result', () async {
    respond = (_) => 'Updated to 2026.10.02';
    expect(await bridge().updateYtDlp(), 'Updated to 2026.10.02');
  });

  test('webViewCookies sends the url and returns the header', () async {
    respond = (_) => 'a=1; b=2';
    final cookies = await bridge().webViewCookies('https://x.com/a');
    expect(cookies, 'a=1; b=2');
    expect(calls.single.arguments, {'url': 'https://x.com/a'});
  });

  test('diskSpace returns total and free bytes, or null on error', () async {
    respond = (_) => {
      'total': 64 * 1024 * 1024 * 1024,
      'free': 10 * 1024 * 1024,
    };
    final space = await bridge().diskSpace();
    expect(space?.total, 64 * 1024 * 1024 * 1024);
    expect(space?.free, 10 * 1024 * 1024);

    respond = (_) => throw PlatformException(code: 'disk_space');
    expect(await bridge().diskSpace(), isNull);
  });

  test('isMeteredNetwork reads the native answer, false on error', () async {
    respond = (_) => true;
    expect(await bridge().isMeteredNetwork(), isTrue);
    expect(calls.single.method, 'isMetered');

    respond = (_) => throw PlatformException(code: 'metered');
    expect(await bridge().isMeteredNetwork(), isFalse);
  });

  test('init and updateYtDlp pass the update channel', () async {
    final b = bridge();
    await b.ensureInitialized(autoUpdate: false, channel: 'stable');
    expect(calls.single.arguments, {'autoUpdate': false, 'channel': 'stable'});

    calls.clear();
    await b.updateYtDlp(channel: 'stable');
    expect(calls.single.method, 'updateYtDlp');
    expect(calls.single.arguments, {'channel': 'stable'});
  });

  test('defaultOutputDir treats blank as missing', () async {
    respond = (_) => '  ';
    expect(await bridge().defaultOutputDir(), isNull);
  });

  test('every method the Dart bridge invokes exists in EnginePlugin.kt', () {
    final dart = File(
      'lib/core/android/android_engine_bridge.dart',
    ).readAsStringSync();
    final kotlin = File(
      'android/app/src/main/kotlin/com/downloader/tapload/EnginePlugin.kt',
    ).readAsStringSync();

    final invoked = RegExp(
      r"invokeMethod[^(]*\(\s*'([A-Za-z]+)'",
    ).allMatches(dart).map((m) => m.group(1)!).toSet();
    final handled = RegExp(
      r'"([A-Za-z]+)"\s*->',
    ).allMatches(kotlin).map((m) => m.group(1)!).toSet();

    expect(invoked, containsAll(['init', 'run', 'start', 'kill']));
    expect(invoked.difference(handled), isEmpty);
  });
}
