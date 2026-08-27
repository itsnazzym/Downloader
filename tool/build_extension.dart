import 'dart:convert';
import 'dart:io';

/// Copies `extension/shared/` into browser-specific packages and writes manifests.
///
/// Usage: `dart run tool/build_extension.dart`
Future<void> main(List<String> args) async {
  final root = Directory.current;
  final shared = Directory('${root.path}/extension/shared');
  if (!shared.existsSync()) {
    stderr.writeln('Missing extension/shared — run from repo root.');
    exitCode = 1;
    return;
  }

  for (final browser in ['chrome', 'firefox']) {
    final out = Directory('${root.path}/extension/$browser');
    out.createSync(recursive: true);

    final commonFiles = [
      'browser_api.js',
      'connection.js',
      'content.js',
      'popup.js',
      'popup.html',
      'popup.css',
      'feed_panel.js',
      'feed_panel.html',
      'feed_panel.css',
    ];

    for (final name in commonFiles) {
      final src = File('${shared.path}/$name');
      if (!src.existsSync()) {
        stderr.writeln('Missing shared file: $name');
        exitCode = 1;
        return;
      }
      await src.copy('${out.path}/$name');
    }

    if (browser == 'chrome') {
      await File(
        '${shared.path}/sw_shell.js',
      ).copy('${out.path}/background.js');
      await File(
        '${shared.path}/offscreen.html',
      ).copy('${out.path}/offscreen.html');
      await File(
        '${shared.path}/connection.js',
      ).copy('${out.path}/connection.js');
    } else {
      // Firefox runs the connection client directly as the background script.
      await File(
        '${shared.path}/connection.js',
      ).copy('${out.path}/background.js');
    }

    final localeSrc = Directory('${shared.path}/_locales');
    if (localeSrc.existsSync()) {
      await _copyDir(localeSrc, Directory('${out.path}/_locales'));
    }

    final iconsOut = Directory('${out.path}/icons');
    iconsOut.createSync(recursive: true);
    final iconSrcDir = Directory('${shared.path}/icons');
    if (iconSrcDir.existsSync()) {
      for (final entity in iconSrcDir.listSync()) {
        if (entity is File) {
          await entity.copy('${iconsOut.path}/${entity.uri.pathSegments.last}');
        }
      }
    }

    final manifestName = browser == 'chrome'
        ? 'manifest.chrome.json'
        : 'manifest.firefox.json';
    final manifestSrc = File('${shared.path}/$manifestName');
    final manifestJson =
        jsonDecode(await manifestSrc.readAsString()) as Map<String, dynamic>;
    const encoder = JsonEncoder.withIndent('    ');
    await File(
      '${out.path}/manifest.json',
    ).writeAsString('${encoder.convert(manifestJson)}\n');

    stdout.writeln('Built extension/$browser');
  }

  final firefoxManifest =
      jsonDecode(
            await File('${shared.path}/manifest.firefox.json').readAsString(),
          )
          as Map<String, dynamic>;
  final version = firefoxManifest['version'] as String? ?? '2.1.0';
  final tag = 'v$version';
  final versionFile = File('${root.path}/extension_version.json');
  await versionFile.writeAsString(
    const JsonEncoder.withIndent('    ').convert({
          'addons': {
            'moderndownloader@extension.addon': {
              'updates': [
                {
                  'version': version,
                  'update_link':
                      'https://github.com/Mizaruta/Downloader/releases/download/$tag/modern_downloader_firefox.xpi',
                },
              ],
            },
          },
        }) +
        '\n',
  );
  stdout.writeln('Updated extension_version.json → $version');
}

Future<void> _copyDir(Directory src, Directory dest) async {
  if (dest.existsSync()) {
    dest.deleteSync(recursive: true);
  }
  dest.createSync(recursive: true);
  await for (final entity in src.list(recursive: true)) {
    final relative = entity.path.substring(src.path.length + 1);
    final targetPath = '${dest.path}${Platform.pathSeparator}$relative';
    if (entity is Directory) {
      Directory(targetPath).createSync(recursive: true);
    } else if (entity is File) {
      File(targetPath).parent.createSync(recursive: true);
      await entity.copy(targetPath);
    }
  }
}
