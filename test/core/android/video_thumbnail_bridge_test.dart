import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/android/android_engine_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/thumb');

  AndroidEngineBridge bridge() => AndroidEngineBridge(
    methodChannel: channel,
    eventChannel: const EventChannel('test/thumbEvents'),
  );

  void answer(Object? value) => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => value);

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'the native side answers with the written path: that is a success',
    () async {
      // It used to be read as a bool, which threw for every successful call.
      answer('/cache/video_thumbs/a.jpg');
      expect(
        await bridge().getVideoThumbnail('/v.mp4', '/cache/a.jpg'),
        isTrue,
      );
    },
  );

  test('a null answer means no frame could be taken', () async {
    answer(null);
    expect(await bridge().getVideoThumbnail('/v.mp4', '/cache/a.jpg'), isFalse);
  });
}
