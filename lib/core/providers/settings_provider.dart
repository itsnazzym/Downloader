import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../theme/theme_presets.dart';

/// App Settings State
class AppSettings {
  final bool audioOnly;
  final bool autoStart;
  final int maxConcurrent;
  final String outputFolder;
  final String preferredQuality;
  final String outputFormat; // mp4, mkv, webm
  final String audioFormat; // mp3, aac, opus
  final bool embedThumbnail;
  final bool embedSubtitles;

  final int concurrentFragments; // Threads per download
  final bool maxSpeedMode; // Saturate bandwidth: 64 native fragments + remux

  // Site-specific settings
  final bool twitterIncludeReplies;
  final bool twitchDownloadChat;
  final String twitchQuality;
  final bool adultSitesEnabled;
  final String cookiesFilePath; // Path to cookies.txt for protected sites
  final bool useTorProxy; // Use Tor SOCKS5 proxy (127.0.0.1:9050)

  final bool clipboardMonitorEnabled;
  final bool minimizeToTray;
  final int serverPort;
  final String apiToken;

  final String themeMode; // 'system', 'light', 'dark'
  final bool doNotDisturb; // Stop Windows/Extension notifications

  final String cookieBrowser; // 'firefox', 'chrome', 'edge', etc.
  final bool organizeBySite; // Create subfolders per site
  final bool autoUpdateYtDlp; // Auto-update yt-dlp on startup
  final String locale; // 'en', 'fr', 'ar'
  final String
  themePreset; // 'midnight', 'ios', 'ocean', 'sunset', 'forest', 'neon', 'monochrome'
  final int customAccentColor; // ARGB int for custom accent

  /// Experimental: use bundled gobird for X feed (OFF by default).
  final bool experimentalXFeedGobirdEnabled;

  /// Browser session gobird should read cookies from (`chrome` | `firefox`).
  final String gobirdBrowser;

  const AppSettings({
    this.themeMode = 'system',
    this.audioOnly = false,
    this.autoStart = true,
    this.maxConcurrent = 3,
    this.concurrentFragments = 16, // Default to 16 threads
    this.maxSpeedMode = false,
    this.outputFolder = '',
    this.preferredQuality = 'best',
    this.outputFormat = 'mp4', // Default to MP4 for max compatibility
    this.audioFormat = 'mp3',
    this.embedThumbnail = true,
    this.embedSubtitles = false,
    this.twitterIncludeReplies = false,
    this.twitchDownloadChat = false,
    this.twitchQuality = '1080p60',
    this.adultSitesEnabled = false,
    this.cookiesFilePath = '',
    this.useTorProxy = false,
    this.clipboardMonitorEnabled = true,
    this.minimizeToTray = false,
    this.serverPort = 6969,
    this.apiToken = '',
    this.doNotDisturb = false,
    this.cookieBrowser = 'firefox',
    this.organizeBySite = false,
    this.autoUpdateYtDlp = true,
    this.locale = 'en',
    this.themePreset = 'midnight',
    this.customAccentColor = 0xFF0D9488,
    this.experimentalXFeedGobirdEnabled = false,
    this.gobirdBrowser = 'chrome',
  });

  AppSettings copyWith({
    String? themeMode,
    bool? audioOnly,
    bool? autoStart,
    int? maxConcurrent,
    int? concurrentFragments,
    bool? maxSpeedMode,
    String? outputFolder,
    String? preferredQuality,
    String? outputFormat,
    String? audioFormat,
    bool? embedThumbnail,
    bool? embedSubtitles,
    bool? twitterIncludeReplies,
    bool? twitchDownloadChat,
    String? twitchQuality,
    bool? adultSitesEnabled,
    String? cookiesFilePath,
    bool? useTorProxy,
    bool? clipboardMonitorEnabled,
    bool? minimizeToTray,
    int? serverPort,
    String? apiToken,
    bool? doNotDisturb,
    String? cookieBrowser,
    bool? organizeBySite,
    bool? autoUpdateYtDlp,
    String? locale,
    String? themePreset,
    int? customAccentColor,
    bool? experimentalXFeedGobirdEnabled,
    String? gobirdBrowser,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      audioOnly: audioOnly ?? this.audioOnly,
      autoStart: autoStart ?? this.autoStart,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
      concurrentFragments: concurrentFragments ?? this.concurrentFragments,
      maxSpeedMode: maxSpeedMode ?? this.maxSpeedMode,
      outputFolder: outputFolder ?? this.outputFolder,
      preferredQuality: preferredQuality ?? this.preferredQuality,
      outputFormat: outputFormat ?? this.outputFormat,
      audioFormat: audioFormat ?? this.audioFormat,
      embedThumbnail: embedThumbnail ?? this.embedThumbnail,
      embedSubtitles: embedSubtitles ?? this.embedSubtitles,
      twitterIncludeReplies:
          twitterIncludeReplies ?? this.twitterIncludeReplies,
      twitchDownloadChat: twitchDownloadChat ?? this.twitchDownloadChat,
      twitchQuality: twitchQuality ?? this.twitchQuality,
      adultSitesEnabled: adultSitesEnabled ?? this.adultSitesEnabled,
      cookiesFilePath: cookiesFilePath ?? this.cookiesFilePath,
      useTorProxy: useTorProxy ?? this.useTorProxy,
      clipboardMonitorEnabled:
          clipboardMonitorEnabled ?? this.clipboardMonitorEnabled,
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      serverPort: serverPort ?? this.serverPort,
      apiToken: apiToken ?? this.apiToken,
      doNotDisturb: doNotDisturb ?? this.doNotDisturb,
      cookieBrowser: cookieBrowser ?? this.cookieBrowser,
      organizeBySite: organizeBySite ?? this.organizeBySite,
      autoUpdateYtDlp: autoUpdateYtDlp ?? this.autoUpdateYtDlp,
      locale: locale ?? this.locale,
      themePreset: themePreset ?? this.themePreset,
      customAccentColor: customAccentColor ?? this.customAccentColor,
      experimentalXFeedGobirdEnabled:
          experimentalXFeedGobirdEnabled ?? this.experimentalXFeedGobirdEnabled,
      gobirdBrowser: gobirdBrowser ?? this.gobirdBrowser,
    );
  }
}

// Keys
const _kThemeMode = 'theme_mode';
const _kAudioOnly = 'audio_only';
const _kAutoStart = 'auto_start';
const _kMaxConcurrent = 'max_concurrent';
const _kConcurrentFragments = 'concurrent_fragments';
const _kMaxSpeedMode = 'max_speed_mode';
const _kOutputFolder = 'output_folder';
const _kPreferredQuality = 'preferred_quality';
const _kOutputFormat = 'output_format';
const _kAudioFormat = 'audio_format';
const _kEmbedThumbnail = 'embed_thumbnail';
const _kEmbedSubtitles = 'embed_subtitles';
const _kTwitterIncludeReplies = 'twitter_include_replies';
const _kTwitchDownloadChat = 'twitch_download_chat';
const _kTwitchQuality = 'twitch_quality';
const _kAdultSitesEnabled = 'adult_sites_enabled';
const _kCookiesFilePath = 'cookies_file_path';
const _kUseTorProxy = 'use_tor_proxy';
const _kClipboardMonitorEnabled = 'clipboard_monitor_enabled';
const _kMinimizeToTray = 'minimize_to_tray';
const _kServerPort = 'server_port';
const _kApiToken = 'api_token';
const _kDND = 'do_not_disturb';
const _kCookieBrowser = 'cookie_browser';
const _kOrganizeBySite = 'organize_by_site';
const _kAutoUpdateYtDlp = 'auto_update_ytdlp';
const _kLocale = 'locale';
const _kThemePreset = 'theme_preset';
const _kCustomAccentColor = 'custom_accent_color';
const _kExperimentalXFeedGobirdEnabled = 'experimental_x_feed_gobird_enabled';
const _kGobirdBrowser = 'gobird_browser';

/// Global SharedPreferences instance holder
SharedPreferences? _prefsInstance;

void initPrefs(SharedPreferences prefs) {
  _prefsInstance = prefs;
}

SharedPreferences get prefs {
  if (_prefsInstance == null) {
    throw StateError(
      'SharedPreferences not initialized. Call initPrefs() in main.',
    );
  }
  return _prefsInstance!;
}

/// Settings Notifier with persistence
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    state = AppSettings(
      themeMode: prefs.getString(_kThemeMode) ?? 'system',
      audioOnly: prefs.getBool(_kAudioOnly) ?? false,
      autoStart: prefs.getBool(_kAutoStart) ?? true,
      maxConcurrent: prefs.getInt(_kMaxConcurrent) ?? 3,
      concurrentFragments: prefs.getInt(_kConcurrentFragments) ?? 16,
      maxSpeedMode: prefs.getBool(_kMaxSpeedMode) ?? false,
      outputFolder: prefs.getString(_kOutputFolder) ?? '',
      preferredQuality: prefs.getString(_kPreferredQuality) ?? 'best',
      outputFormat: prefs.getString(_kOutputFormat) ?? 'mp4',
      audioFormat: prefs.getString(_kAudioFormat) ?? 'mp3',
      embedThumbnail: prefs.getBool(_kEmbedThumbnail) ?? true,
      embedSubtitles: prefs.getBool(_kEmbedSubtitles) ?? false,
      twitterIncludeReplies: prefs.getBool(_kTwitterIncludeReplies) ?? false,
      twitchDownloadChat: prefs.getBool(_kTwitchDownloadChat) ?? false,
      twitchQuality: prefs.getString(_kTwitchQuality) ?? '1080p60',
      adultSitesEnabled: prefs.getBool(_kAdultSitesEnabled) ?? false,
      cookiesFilePath: prefs.getString(_kCookiesFilePath) ?? '',
      useTorProxy: prefs.getBool(_kUseTorProxy) ?? false,
      clipboardMonitorEnabled: prefs.getBool(_kClipboardMonitorEnabled) ?? true,
      minimizeToTray: prefs.getBool(_kMinimizeToTray) ?? false,
      serverPort: prefs.getInt(_kServerPort) ?? 6969,
      apiToken: prefs.getString(_kApiToken) ?? Uuid().v4(),
      doNotDisturb: prefs.getBool(_kDND) ?? false,
      cookieBrowser: prefs.getString(_kCookieBrowser) ?? 'firefox',
      organizeBySite: prefs.getBool(_kOrganizeBySite) ?? false,
      autoUpdateYtDlp: prefs.getBool(_kAutoUpdateYtDlp) ?? true,
      locale: prefs.getString(_kLocale) ?? 'en',
      themePreset: prefs.getString(_kThemePreset) ?? 'midnight',
      customAccentColor: prefs.getInt(_kCustomAccentColor) ?? 0xFF0D9488,
      experimentalXFeedGobirdEnabled:
          prefs.getBool(_kExperimentalXFeedGobirdEnabled) ?? false,
      gobirdBrowser: _normalizeGobirdBrowser(
        prefs.getString(_kGobirdBrowser) ?? 'chrome',
      ),
    );
    // Ensure token is saved if it was generated
    if (prefs.getString(_kApiToken) == null) {
      prefs.setString(_kApiToken, state.apiToken);
    }
  }

  void setThemeMode(String value) {
    state = state.copyWith(themeMode: value);
    prefs.setString(_kThemeMode, value);
  }

  void setAudioOnly(bool value) {
    state = state.copyWith(audioOnly: value);
    prefs.setBool(_kAudioOnly, value);
  }

  void setAutoStart(bool value) {
    state = state.copyWith(autoStart: value);
    prefs.setBool(_kAutoStart, value);
  }

  void setMaxConcurrent(int value) {
    state = state.copyWith(maxConcurrent: value);
    prefs.setInt(_kMaxConcurrent, value);
  }

  void setConcurrentFragments(int value) {
    state = state.copyWith(concurrentFragments: value);
    prefs.setInt(_kConcurrentFragments, value);
  }

  void setMaxSpeedMode(bool value) {
    state = state.copyWith(maxSpeedMode: value);
    prefs.setBool(_kMaxSpeedMode, value);
    if (value && state.concurrentFragments < 64) {
      setConcurrentFragments(64);
    }
  }

  void setOutputFolder(String value) {
    state = state.copyWith(outputFolder: value);
    prefs.setString(_kOutputFolder, value);
  }

  void setPreferredQuality(String value) {
    state = state.copyWith(preferredQuality: value);
    prefs.setString(_kPreferredQuality, value);
  }

  void setOutputFormat(String value) {
    state = state.copyWith(outputFormat: value);
    prefs.setString(_kOutputFormat, value);
  }

  void setAudioFormat(String value) {
    state = state.copyWith(audioFormat: value);
    prefs.setString(_kAudioFormat, value);
  }

  void setEmbedThumbnail(bool value) {
    state = state.copyWith(embedThumbnail: value);
    prefs.setBool(_kEmbedThumbnail, value);
  }

  void setEmbedSubtitles(bool value) {
    state = state.copyWith(embedSubtitles: value);
    prefs.setBool(_kEmbedSubtitles, value);
  }

  void setTwitterIncludeReplies(bool value) {
    state = state.copyWith(twitterIncludeReplies: value);
    prefs.setBool(_kTwitterIncludeReplies, value);
  }

  void setTwitchDownloadChat(bool value) {
    state = state.copyWith(twitchDownloadChat: value);
    prefs.setBool(_kTwitchDownloadChat, value);
  }

  void setTwitchQuality(String value) {
    state = state.copyWith(twitchQuality: value);
    prefs.setString(_kTwitchQuality, value);
  }

  void setAdultSitesEnabled(bool value) {
    state = state.copyWith(adultSitesEnabled: value);
    prefs.setBool(_kAdultSitesEnabled, value);
  }

  void setCookiesFilePath(String value) {
    if (state.cookiesFilePath == value) return;
    state = state.copyWith(cookiesFilePath: value);
    prefs.setString(_kCookiesFilePath, value);
  }

  void setUseTorProxy(bool value) {
    state = state.copyWith(useTorProxy: value);
    prefs.setBool(_kUseTorProxy, value);
  }

  void clearCookies() {
    state = state.copyWith(cookiesFilePath: '');
    prefs.remove(_kCookiesFilePath);
  }

  void setClipboardMonitorEnabled(bool value) {
    state = state.copyWith(clipboardMonitorEnabled: value);
    prefs.setBool(_kClipboardMonitorEnabled, value);
  }

  void setMinimizeToTray(bool value) {
    state = state.copyWith(minimizeToTray: value);
    prefs.setBool(_kMinimizeToTray, value);
  }

  void setDoNotDisturb(bool value) {
    state = state.copyWith(doNotDisturb: value);
    prefs.setBool(_kDND, value);
  }

  void setCookieBrowser(String value) {
    state = state.copyWith(cookieBrowser: value);
    prefs.setString(_kCookieBrowser, value);
  }

  void setServerPort(int value) {
    state = state.copyWith(serverPort: value);
    prefs.setInt(_kServerPort, value);
  }

  void setOrganizeBySite(bool value) {
    state = state.copyWith(organizeBySite: value);
    prefs.setBool(_kOrganizeBySite, value);
  }

  void setAutoUpdateYtDlp(bool value) {
    state = state.copyWith(autoUpdateYtDlp: value);
    prefs.setBool(_kAutoUpdateYtDlp, value);
  }

  void setLocale(String value) {
    state = state.copyWith(locale: value);
    prefs.setString(_kLocale, value);
  }

  void setThemePreset(String value) {
    final preset = ThemePresets.getById(value);
    state = state.copyWith(
      themePreset: value,
      customAccentColor: preset.primary.toARGB32(),
    );
    prefs.setString(_kThemePreset, value);
    prefs.setInt(_kCustomAccentColor, preset.primary.toARGB32());
  }

  void setCustomAccentColor(int value) {
    state = state.copyWith(customAccentColor: value);
    prefs.setInt(_kCustomAccentColor, value);
  }

  void setExperimentalXFeedGobirdEnabled(bool value) {
    state = state.copyWith(experimentalXFeedGobirdEnabled: value);
    prefs.setBool(_kExperimentalXFeedGobirdEnabled, value);
  }

  void setGobirdBrowser(String value) {
    final normalized = _normalizeGobirdBrowser(value);
    state = state.copyWith(gobirdBrowser: normalized);
    prefs.setString(_kGobirdBrowser, normalized);
  }

  static String _normalizeGobirdBrowser(String value) {
    final lower = value.trim().toLowerCase();
    if (lower == 'firefox') return 'firefox';
    return 'chrome';
  }
}

/// Global settings provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  return SettingsNotifier();
});
