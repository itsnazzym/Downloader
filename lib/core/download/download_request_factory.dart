import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';

/// Builds a [DownloadRequest] from app settings plus optional per-call overrides.
class DownloadRequestFactory {
  DownloadRequestFactory._();

  static DownloadRequest fromSettings({
    required AppSettings settings,
    required String url,
    String? cookiesFilePath,
    String? rawCookies,
    String? userAgent,
    String? videoFormatId,
    String? cookieBrowser,
    bool? organizeBySite,
    bool? audioOnly,
    String? preferredQuality,
  }) {
    return DownloadRequest(
      url: url,
      outputFolder: settings.outputFolder.isNotEmpty
          ? settings.outputFolder
          : null,
      audioOnly: audioOnly ?? settings.audioOnly,
      preferredQuality: preferredQuality ?? settings.preferredQuality,
      outputFormat: settings.outputFormat,
      audioFormat: settings.audioFormat,
      embedThumbnail: settings.embedThumbnail,
      embedSubtitles: settings.embedSubtitles,
      twitterIncludeReplies: settings.twitterIncludeReplies,
      twitchDownloadChat: settings.twitchDownloadChat,
      twitchQuality: settings.twitchQuality,
      cookiesFilePath: cookiesFilePath,
      useTorProxy: settings.useTorProxy,
      concurrentFragments: settings.concurrentFragments,
      maxSpeedMode: settings.maxSpeedMode,
      rawCookies: rawCookies,
      videoFormatId: videoFormatId,
      cookieBrowser: cookieBrowser ?? settings.cookieBrowser,
      organizeBySite: organizeBySite ?? settings.organizeBySite,
      userAgent: userAgent,
    );
  }
}
