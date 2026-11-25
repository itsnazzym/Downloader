import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/utils/browser_launch.dart';

void main() {
  test('a URL with & reaches the browser whole, with no shell', () {
    const url = 'https://www.youtube.com/watch?v=abc&list=PL1&calc';
    final command = windowsBrowserCommand(url)!;

    // cmd.exe would run "calc" as a second command and cut the URL at "&".
    expect(command.executable, isNot('cmd'));
    expect(command.arguments, contains(url));
  });

  test('only http and https URLs are opened', () {
    expect(windowsBrowserCommand(r'file:///C:/Windows/System32/calc.exe'), isNull);
    expect(windowsBrowserCommand('not a url'), isNull);
    expect(windowsBrowserCommand('https://example.com/a'), isNotNull);
  });
}
