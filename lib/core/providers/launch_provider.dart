import 'package:flutter_riverpod/flutter_riverpod.dart';

class LaunchData {
  final String url;
  final String? cookies;
  final String? userAgent;
  final bool isAudioOnly;
  final bool shouldAutoStart;
  final bool isPlaylist;
  final String? cookieBrowser;

  LaunchData({
    required this.url,
    this.cookies,
    this.userAgent,
    this.isAudioOnly = false,
    this.shouldAutoStart = false,
    this.isPlaylist = false,
    this.cookieBrowser,
  });

  factory LaunchData.dialog(
    String url, {
    String? cookies,
    String? userAgent,
    bool isAudioOnly = false,
    bool isPlaylist = false,
    String? cookieBrowser,
  }) {
    return LaunchData(
      url: url,
      cookies: cookies,
      userAgent: userAgent,
      isAudioOnly: isAudioOnly,
      shouldAutoStart: false,
      isPlaylist: isPlaylist,
      cookieBrowser: cookieBrowser,
    );
  }

  factory LaunchData.autoStart(
    String url, {
    String? cookies,
    String? userAgent,
    bool isAudioOnly = false,
    bool isPlaylist = false,
    String? cookieBrowser,
  }) {
    return LaunchData(
      url: url,
      cookies: cookies,
      userAgent: userAgent,
      isAudioOnly: isAudioOnly,
      shouldAutoStart: true,
      isPlaylist: isPlaylist,
      cookieBrowser: cookieBrowser,
    );
  }
}

/// Holds the data that triggered the app launch or a remote request.
final launchDataProvider = StateProvider<LaunchData?>((ref) => null);

// Keep this for backward compatibility if needed, or deprecate
final launchUrlProvider = StateProvider<String?>((ref) => null);
