/// Official Windows x64 downloads for tools the downloader needs.
class DependencyPackage {
  const DependencyPackage({
    required this.id,
    required this.displayName,
    required this.downloadUrl,
    required this.kind,
    required this.executableNames,
    required this.versionArgs,
    this.optional = false,
  });

  final String id;
  final String displayName;
  final String downloadUrl;
  final DependencyKind kind;
  final List<String> executableNames;
  final Map<String, String> versionArgs;
  final bool optional;
}

enum DependencyKind { executable, zip }

class DependencyCatalog {
  const DependencyCatalog._();

  static const List<DependencyPackage> windowsRequired = [
    DependencyPackage(
      id: 'yt-dlp',
      displayName: 'yt-dlp',
      downloadUrl:
          'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe',
      kind: DependencyKind.executable,
      executableNames: ['yt-dlp.exe'],
      versionArgs: {'yt-dlp.exe': '--version'},
    ),
    DependencyPackage(
      id: 'ffmpeg',
      displayName: 'FFmpeg',
      downloadUrl:
          'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip',
      kind: DependencyKind.zip,
      executableNames: ['ffmpeg.exe', 'ffprobe.exe'],
      versionArgs: {'ffmpeg.exe': '-version', 'ffprobe.exe': '-version'},
    ),
    DependencyPackage(
      id: 'aria2c',
      displayName: 'aria2c',
      downloadUrl:
          'https://github.com/aria2/aria2/releases/download/release-1.37.0/aria2-1.37.0-win-64bit-build1.zip',
      kind: DependencyKind.zip,
      executableNames: ['aria2c.exe'],
      versionArgs: {'aria2c.exe': '--version'},
    ),
  ];

  /// Optional tools are shown and staged when available, but do not block the
  /// downloader from starting. gobird is opt-in from Advanced Settings.
  static const List<DependencyPackage> windowsOptional = [
    DependencyPackage(
      id: 'gobird',
      displayName: 'gobird',
      downloadUrl:
          'https://github.com/mudrii/gobird/releases/download/26.05.13/gobird_26.05.13_windows_amd64.zip',
      kind: DependencyKind.zip,
      executableNames: ['gobird.exe'],
      versionArgs: {'gobird.exe': '--help'},
      optional: true,
    ),
  ];

  static List<String> allExecutableNames() {
    return [for (final pkg in windowsRequired) ...pkg.executableNames];
  }

  static List<String> allSetupExecutableNames() {
    return [
      ...allExecutableNames(),
      for (final pkg in windowsOptional) ...pkg.executableNames,
    ];
  }

  static bool isOptionalExecutable(String executableName) {
    return windowsOptional.any(
      (pkg) => pkg.executableNames.any(
        (name) => name.toLowerCase() == executableName.toLowerCase(),
      ),
    );
  }
}
