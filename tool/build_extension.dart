import 'dart:convert';
import 'dart:io';

import 'addon_version.dart';

/// Copies `extension/shared/` into browser-specific packages and writes manifests.
///
/// Usage:
/// `dart run tool/build_extension.dart`
/// `dart run tool/build_extension.dart --bump-patch --release-tag v1.0.6`
/// `dart run tool/build_extension.dart --print-next-version`
Future<void> main(List<String> args) async {
  final root = Directory.current;
  final shared = Directory('${root.path}/extension/shared');
  if (!shared.existsSync()) {
    stderr.writeln('Missing extension/shared — run from repo root.');
    exitCode = 1;
    return;
  }

  final firefoxSrc = File('${shared.path}/manifest.firefox.json');
  final currentVersion = _readVersion(await firefoxSrc.readAsString());

  if (args.contains('--print-next-version')) {
    final next = incrementAddonVersion(currentVersion);
    stdout.writeln(next);
    agentDebugLog(
      hypothesisId: 'D',
      location: 'tool/build_extension.dart:print-next-version',
      message: 'Computed next AMO add-on version',
      data: {'current': currentVersion, 'next': next},
    );
    return;
  }

  String? releaseTag;
  final tagIdx = args.indexOf('--release-tag');
  if (tagIdx >= 0 && tagIdx + 1 < args.length) {
    releaseTag = args[tagIdx + 1];
  }

  var version = currentVersion;
  if (args.contains('--bump-patch')) {
    version = incrementAddonVersion(currentVersion);
    await _writeSharedVersions(shared, version);
    stdout.writeln('Bumped add-on version $currentVersion → $version');
    agentDebugLog(
      hypothesisId: 'D',
      location: 'tool/build_extension.dart:bump-patch',
      message: 'Bumped add-on version to avoid AMO conflict',
      data: {'from': currentVersion, 'to': version, 'releaseTag': releaseTag},
    );
  }

  for (final browser in ['chrome', 'firefox']) {
    final out = Directory('${root.path}/extension/$browser');
    out.createSync(recursive: true);

    final commonFiles = [
      'browser_api.js',
      'url_policy.js',
      'badge.js',
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

  final tag = (releaseTag != null && releaseTag.isNotEmpty)
      ? releaseTag
      : 'v$version';
  final versionFile = File('${root.path}/extension_version.json');
  final updateManifest = const JsonEncoder.withIndent('    ').convert({
    'addons': {
      'moderndownloader@extension.addon': {
        'updates': [
          {
            'version': version,
            'update_link':
                'https://github.com/${_githubRepo()}/releases/download/$tag/modern_downloader_firefox.xpi',
          },
        ],
      },
    },
  });
  await versionFile.writeAsString('$updateManifest\n');
  stdout.writeln('Updated extension_version.json → $version (tag $tag)');
  agentDebugLog(
    hypothesisId: 'D',
    location: 'tool/build_extension.dart:write-update-manifest',
    message: 'Wrote Firefox update manifest',
    data: {'addonVersion': version, 'githubTag': tag},
  );
}

String _githubRepo() {
  final fromEnv = Platform.environment['GITHUB_REPOSITORY'];
  if (fromEnv != null && fromEnv.contains('/')) return fromEnv;
  return 'itsnazzym/Downloader';
}

String _readVersion(String source) {
  final json = jsonDecode(source);
  if (json is! Map) {
    throw const FormatException('Manifest is not a JSON object');
  }
  final version = json['version'];
  if (version is! String || version.isEmpty) {
    throw const FormatException('Manifest is missing version');
  }
  return version;
}

Future<void> _writeSharedVersions(Directory shared, String version) async {
  for (final name in ['manifest.chrome.json', 'manifest.firefox.json']) {
    final file = File('${shared.path}/$name');
    final updated = replaceManifestVersion(await file.readAsString(), version);
    await file.writeAsString(updated);
  }
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
