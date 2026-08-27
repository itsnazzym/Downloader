class DownloadRequest {
  final String url;
  final String? outputFolder;
  final bool audioOnly;
  final String? customFilename;
  final String? rawCookies; // Added field for extension/manual cookies

  // Format settings
  final String preferredQuality;
  final String outputFormat; // mp4, mkv, webm
  final String audioFormat; // mp3, aac, opus
  final bool embedThumbnail;
  final bool embedSubtitles;
  final String? videoFormatId; // Specific yt-dlp format code

  // Platform-specific
  final bool twitterIncludeReplies;
  final bool twitchDownloadChat;
  final String twitchQuality;

  // Cookies for protected sites
  final String? cookiesFilePath;

  // Proxy settings
  final bool useTorProxy;
  final int concurrentFragments;
  final bool maxSpeedMode;

  final String? cookieBrowser;
  final bool organizeBySite;
  final String? userAgent;

  // Direct Stream Override (Bypassing fetch)
  final String? forceStreamUrl;
  final String? forceThumbnailUrl; // Added

  const DownloadRequest({
    required this.url,
    this.outputFolder,
    this.audioOnly = false,
    this.customFilename,
    this.preferredQuality = 'best',
    this.outputFormat = 'mp4',
    this.audioFormat = 'mp3',
    this.embedThumbnail = true,
    this.embedSubtitles = false,
    this.twitterIncludeReplies = false,
    this.twitchDownloadChat = false,
    this.twitchQuality = '1080p60',
    this.cookiesFilePath,
    this.useTorProxy = false,
    this.concurrentFragments = 16,
    this.maxSpeedMode = false,
    this.videoFormatId,
    this.forceStreamUrl,
    this.forceThumbnailUrl,
    this.rawCookies,
    this.cookieBrowser,
    this.organizeBySite = false,
    this.userAgent,
  });

  DownloadRequest copyWith({
    String? url,
    String? outputFolder,
    bool? audioOnly,
    String? customFilename,
    String? preferredQuality,
    String? outputFormat,
    String? audioFormat,
    bool? embedThumbnail,
    bool? embedSubtitles,
    bool? twitterIncludeReplies,
    bool? twitchDownloadChat,
    String? twitchQuality,
    String? cookiesFilePath,
    bool? useTorProxy,
    int? concurrentFragments,
    bool? maxSpeedMode,
    String? videoFormatId,
    String? forceStreamUrl,
    String? forceThumbnailUrl, // Added param
    String? rawCookies,
    bool clearRawCookies = false,
    String? cookieBrowser,
    bool? organizeBySite,
    String? userAgent,
  }) {
    return DownloadRequest(
      url: url ?? this.url,
      outputFolder: outputFolder ?? this.outputFolder,
      audioOnly: audioOnly ?? this.audioOnly,
      customFilename: customFilename ?? this.customFilename,
      preferredQuality: preferredQuality ?? this.preferredQuality,
      outputFormat: outputFormat ?? this.outputFormat,
      audioFormat: audioFormat ?? this.audioFormat,
      embedThumbnail: embedThumbnail ?? this.embedThumbnail,
      embedSubtitles: embedSubtitles ?? this.embedSubtitles,
      twitterIncludeReplies:
          twitterIncludeReplies ?? this.twitterIncludeReplies,
      twitchDownloadChat: twitchDownloadChat ?? this.twitchDownloadChat,
      twitchQuality: twitchQuality ?? this.twitchQuality,
      cookiesFilePath: cookiesFilePath ?? this.cookiesFilePath,
      useTorProxy: useTorProxy ?? this.useTorProxy,
      concurrentFragments: concurrentFragments ?? this.concurrentFragments,
      maxSpeedMode: maxSpeedMode ?? this.maxSpeedMode,
      videoFormatId: videoFormatId ?? this.videoFormatId,
      forceStreamUrl: forceStreamUrl ?? this.forceStreamUrl,
      forceThumbnailUrl: forceThumbnailUrl ?? this.forceThumbnailUrl, // Added
      rawCookies: clearRawCookies ? null : (rawCookies ?? this.rawCookies),
      cookieBrowser: cookieBrowser ?? this.cookieBrowser,
      organizeBySite: organizeBySite ?? this.organizeBySite,
      userAgent: userAgent ?? this.userAgent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'outputFolder': outputFolder,
      'audioOnly': audioOnly,
      'customFilename': customFilename,
      'preferredQuality': preferredQuality,
      'outputFormat': outputFormat,
      'audioFormat': audioFormat,
      'embedThumbnail': embedThumbnail,
      'embedSubtitles': embedSubtitles,
      'twitterIncludeReplies': twitterIncludeReplies,
      'twitchDownloadChat': twitchDownloadChat,
      'twitchQuality': twitchQuality,
      'cookiesFilePath': cookiesFilePath,
      'useTorProxy': useTorProxy,
      'concurrentFragments': concurrentFragments,
      'maxSpeedMode': maxSpeedMode,
      'videoFormatId': videoFormatId,
      'forceStreamUrl': forceStreamUrl,
      'forceThumbnailUrl': forceThumbnailUrl, // Added
      'rawCookies': rawCookies,
      'cookieBrowser': cookieBrowser,
      'organizeBySite': organizeBySite,
      'userAgent': userAgent,
    };
  }

  factory DownloadRequest.fromJson(Map<String, dynamic> json) {
    return DownloadRequest(
      url: json['url'] as String,
      outputFolder: json['outputFolder'] as String?,
      audioOnly: json['audioOnly'] as bool? ?? false,
      customFilename: json['customFilename'] as String?,
      preferredQuality: json['preferredQuality'] as String? ?? 'best',
      outputFormat: json['outputFormat'] as String? ?? 'mp4',
      audioFormat: json['audioFormat'] as String? ?? 'mp3',
      embedThumbnail: json['embedThumbnail'] as bool? ?? true,
      embedSubtitles: json['embedSubtitles'] as bool? ?? false,
      twitterIncludeReplies: json['twitterIncludeReplies'] as bool? ?? false,
      twitchDownloadChat: json['twitchDownloadChat'] as bool? ?? false,
      twitchQuality: json['twitchQuality'] as String? ?? '1080p60',
      cookiesFilePath: json['cookiesFilePath'] as String?,
      useTorProxy: json['useTorProxy'] as bool? ?? false,
      concurrentFragments: json['concurrentFragments'] as int? ?? 16,
      maxSpeedMode: json['maxSpeedMode'] as bool? ?? false,
      videoFormatId: json['videoFormatId'] as String?,
      forceStreamUrl: json['forceStreamUrl'] as String?,
      forceThumbnailUrl: json['forceThumbnailUrl'] as String?, // Added
      rawCookies: json['rawCookies'] as String?,
      cookieBrowser: json['cookieBrowser'] as String?,
      organizeBySite: json['organizeBySite'] as bool? ?? false,
      userAgent: json['userAgent'] as String?,
    );
  }
}
