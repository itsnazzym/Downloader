import 'package:flutter_riverpod/flutter_riverpod.dart';

class LaunchData {
  final String url;
  final String? cookies;
  final String? userAgent;
  final bool isAudioOnly;
  final bool shouldAutoStart;
  final bool isPlaylist;
  final String? cookieBrowser;
  final String? preferredQuality;

  LaunchData({
    required this.url,
    this.cookies,
    this.userAgent,
    this.isAudioOnly = false,
    this.shouldAutoStart = false,
    this.isPlaylist = false,
    this.cookieBrowser,
    this.preferredQuality,
  });

  factory LaunchData.fromUrl(String url, {bool shouldAutoStart = false}) {
    return LaunchData(url: url, shouldAutoStart: shouldAutoStart);
  }
}

/// Holds the data that triggered the app launch or a remote request.
final launchDataProvider = StateProvider<LaunchData?>((ref) => null);

/// Deprecated: all launch paths now write [launchDataProvider].
final launchUrlProvider = StateProvider<String?>((ref) => null);
