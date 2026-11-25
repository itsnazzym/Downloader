import 'dart:io';

/// The Windows command that opens [url] in the default browser, or null when
/// [url] is not http(s).
///
/// No shell: `cmd /c start "" <url>` re-parses `&`, `|` and `^` inside the URL,
/// so a link like `...watch?v=x&list=y` opened truncated, and a crafted link
/// could run a second command.
({String executable, List<String> arguments})? windowsBrowserCommand(
  String url,
) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return null;
  }
  return (
    executable: 'rundll32',
    arguments: ['url.dll,FileProtocolHandler', uri.toString()],
  );
}

/// Opens an http(s) [url] in the system browser. Returns false when the URL
/// is rejected or the launch fails.
Future<bool> openInBrowser(String url) async {
  try {
    if (Platform.isWindows) {
      final command = windowsBrowserCommand(url);
      if (command == null) return false;
      await Process.start(command.executable, command.arguments);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    } else {
      return false;
    }
    return true;
  } catch (_) {
    return false;
  }
}
