import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsNotifier> notifier([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  initPrefs(await SharedPreferences.getInstance());
  return SettingsNotifier();
}

void main() {
  test('defaults: nightly channel, Wi-Fi only off', () async {
    final n = await notifier();
    expect(n.state.ytDlpChannel, 'nightly');
    expect(n.state.wifiOnly, isFalse);
  });

  test('setYtDlpChannel persists and only accepts nightly or stable', () async {
    final n = await notifier();
    n.setYtDlpChannel('stable');
    expect(n.state.ytDlpChannel, 'stable');
    expect(
      (await SharedPreferences.getInstance()).getString('ytdlp_channel'),
      'stable',
    );

    n.setYtDlpChannel('anything-else');
    expect(n.state.ytDlpChannel, 'nightly');
  });

  test('setWifiOnly persists', () async {
    final n = await notifier();
    n.setWifiOnly(true);
    expect(n.state.wifiOnly, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool('wifi_only'),
      isTrue,
    );
  });

  test('a stored stable channel and Wi-Fi only are restored', () async {
    final n = await notifier({'ytdlp_channel': 'stable', 'wifi_only': true});
    expect(n.state.ytDlpChannel, 'stable');
    expect(n.state.wifiOnly, isTrue);
  });

  test('an unknown stored channel falls back to nightly', () async {
    final n = await notifier({'ytdlp_channel': 'master'});
    expect(n.state.ytDlpChannel, 'nightly');
  });
}
