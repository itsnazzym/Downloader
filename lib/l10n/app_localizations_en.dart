// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TapLoad';

  @override
  String get downloads => 'Downloads';

  @override
  String get statistics => 'Statistics';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get plugins => 'Plugins';

  @override
  String get newDownload => 'New Download';

  @override
  String get pasteUrl => 'Paste URL here';

  @override
  String get xCdnUrlRejected =>
      'Paste the tweet link (x.com/.../status/...), not the video file.';

  @override
  String get unsupportedDownloadUrl =>
      'This page is not a downloadable video (invite or unsupported site).';

  @override
  String get startDownload => 'Start Download';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get delete => 'Delete';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get openFile => 'Open File';

  @override
  String get openFolder => 'Open Folder';

  @override
  String get clearHistory => 'Clear History';

  @override
  String get selectAll => 'Select All';

  @override
  String get deselectAll => 'Deselect All';

  @override
  String get statusQueued => 'Queued';

  @override
  String get statusDownloading => 'Downloading';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusCanceled => 'Canceled';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusExtracting => 'Extracting';

  @override
  String get statusDuplicate => 'Duplicate';

  @override
  String get sidebarAll => 'All';

  @override
  String get sidebarActive => 'Active';

  @override
  String get sidebarCompleted => 'Completed';

  @override
  String get sidebarFailed => 'Failed';

  @override
  String get sidebarBySource => 'By Source';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsOutput => 'Output';

  @override
  String get settingsAdvanced => 'Advanced';

  @override
  String get settingsPerformance => 'Performance';

  @override
  String get settingsSystem => 'System';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsPlugins => 'Plugins';

  @override
  String get audioOnly => 'Audio Only';

  @override
  String get audioOnlyDesc => 'Extract audio only (MP3) from videos';

  @override
  String get autoStart => 'Auto-Start';

  @override
  String get autoStartDesc => 'Start downloads immediately when added';

  @override
  String get preferredQuality => 'Preferred Quality';

  @override
  String get maxConcurrent => 'Max Concurrent Downloads';

  @override
  String get outputFolder => 'Output Folder';

  @override
  String get chooseFolder => 'Choose Folder';

  @override
  String get useCookies => 'Use Browser Cookies';

  @override
  String get useCookiesDesc =>
      'Use cookies from your browser for authentication';

  @override
  String get useProxy => 'Use Proxy';

  @override
  String get useProxyDesc => 'Route downloads through a proxy server';

  @override
  String get minimizeToTray => 'Minimize to Tray';

  @override
  String get minimizeToTrayDesc => 'Minimize to system tray instead of closing';

  @override
  String get autoStartApp => 'Start with Windows';

  @override
  String get autoStartAppDesc => 'Launch app on system startup';

  @override
  String get autoUpdateYtDlp => 'Auto-update yt-dlp';

  @override
  String get autoUpdateYtDlpDesc => 'Check for yt-dlp updates on startup';

  @override
  String get showNotifications => 'Show Notifications';

  @override
  String get showNotificationsDesc => 'Desktop notifications for downloads';

  @override
  String get clipboardMonitor => 'Clipboard Monitor';

  @override
  String get clipboardMonitorDesc => 'Auto-detect URLs from clipboard';

  @override
  String get language => 'Language';

  @override
  String get languageDesc => 'Choose your preferred language';

  @override
  String get theme => 'Theme';

  @override
  String get themeDesc => 'Choose application theme';

  @override
  String get accentColor => 'Accent Color';

  @override
  String get accentColorDesc => 'Customize the accent color';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get systemMode => 'System';

  @override
  String get totalDownloads => 'Total Downloads';

  @override
  String get downloadsToday => 'Downloads Today';

  @override
  String get totalData => 'Total Data';

  @override
  String get freeSpace => 'Free Space';

  @override
  String get last7Days => 'Activity (Last 7 Days)';

  @override
  String get sourceDistribution => 'Source Distribution';

  @override
  String get keyboardShortcuts => 'Keyboard Shortcuts';

  @override
  String get newDownloadShortcut => 'New Download';

  @override
  String get settingsShortcut => 'Open Settings';

  @override
  String get dashboardShortcut => 'Dashboard';

  @override
  String get minimizeShortcut => 'Minimize';

  @override
  String get inspector => 'Inspector';

  @override
  String get title => 'Title';

  @override
  String get status => 'Status';

  @override
  String get progress => 'Progress';

  @override
  String get logs => 'Logs';

  @override
  String get selectDownload => 'Select a download';

  @override
  String get checkDependencies => 'Check Dependencies';

  @override
  String get checkDependenciesDesc => 'Check yt-dlp, ffmpeg & aria2c status';

  @override
  String get verifyingBinaries => 'Verifying binaries...';

  @override
  String get dependenciesVerified => 'Dependencies verified';

  @override
  String get organizeLibrary => 'Organize Library';

  @override
  String get organizeLibraryDesc =>
      'Sort files by source, move thumbnails, cleanup temp files';

  @override
  String get organizationComplete => 'Organization Complete';

  @override
  String filesMoved(int count) {
    return 'Files moved: $count';
  }

  @override
  String filesDeleted(int count) {
    return 'Temp files deleted: $count';
  }

  @override
  String get noPluginsInstalled => 'No plugins installed';

  @override
  String get pluginEnabled => 'Enabled';

  @override
  String get pluginDisabled => 'Disabled';

  @override
  String get builtIn => 'Built-in';

  @override
  String get mediaPlayer => 'Media Player';

  @override
  String get playbackSpeed => 'Playback Speed';

  @override
  String get volume => 'Volume';

  @override
  String get ok => 'OK';

  @override
  String get confirm => 'Confirm';

  @override
  String get close => 'Close';

  @override
  String get save => 'Save';

  @override
  String get back => 'Back';

  @override
  String get search => 'Search';

  @override
  String get noResults => 'No results found';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get warning => 'Warning';

  @override
  String get librarySection => 'Library';

  @override
  String get sourcesSection => 'Sources';

  @override
  String get mainPage => 'Home';

  @override
  String get allDownloads => 'All downloads';

  @override
  String get downloadStarted => 'Download started';

  @override
  String videosDownloadingCount(int count) {
    return '$count videos downloading';
  }

  @override
  String get videoDownloadingSingular => '1 video downloading';

  @override
  String get expandDownloadingVideos => 'Show downloading videos';

  @override
  String get collapseDownloadingVideos => 'Hide downloading videos';

  @override
  String moreDownloadingVideos(int count) {
    return '+$count';
  }

  @override
  String get searchDownloads => 'Filter titles or URLs';

  @override
  String get searchClear => 'Clear search';

  @override
  String searchMatchCount(int visible, int total) {
    return '$visible / $total';
  }

  @override
  String get clearHistoryConfirm =>
      'Remove all completed, failed, and canceled downloads? Active downloads will remain.';

  @override
  String get refreshLibrary => 'Refresh library';

  @override
  String get yourListIsEmpty => 'Your download list is empty.';

  @override
  String get sortAndView => 'Sort & View';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortDateNewest => 'Date (newest)';

  @override
  String get sortDateOldest => 'Date (oldest)';

  @override
  String get sortNameAsc => 'Name (A-Z)';

  @override
  String get sortSizeLargest => 'Size (largest)';

  @override
  String get sortVideoCount => 'Video count';

  @override
  String get viewMode => 'View mode';

  @override
  String get viewList => 'List';

  @override
  String get viewDetailed => 'Detailed';

  @override
  String get viewFolders => 'Folders';

  @override
  String get folderUnknownCreator => 'Unknown';

  @override
  String get folderBack => 'Back to folders';

  @override
  String get folderOpenHint => 'Open folder';

  @override
  String folderVideoCount(int count) {
    return '$count videos';
  }

  @override
  String playlistDetected(int count) {
    return 'Playlist detected ($count videos)';
  }

  @override
  String downloadSelected(int count) {
    return 'Download selected ($count)';
  }

  @override
  String startedCountDownloads(int count) {
    return 'Started $count downloads';
  }

  @override
  String get downloadFolder => 'Download folder';

  @override
  String get selectFolder => 'Select folder...';

  @override
  String get organizeBySite => 'Organize by site';

  @override
  String get organizeBySiteDesc => 'Create subfolders like Downloads/YouTube/';

  @override
  String get organizeByCreator => 'Organize by creator';

  @override
  String get organizeByCreatorDesc =>
      'Create subfolders per account (e.g. TikTok/userxxx/, YouTube/channel/)';

  @override
  String get formatLabel => 'Format';

  @override
  String get adultSites => 'Adult sites';

  @override
  String get adultSitesDesc => 'Enable support for age-restricted content';

  @override
  String get doNotDisturb => 'Do not disturb';

  @override
  String get doNotDisturbDesc => 'Silence all app and extension notifications';

  @override
  String get cookiesFromBrowser => 'Cookies from browser';

  @override
  String get extensionApiToken => 'Extension API token';

  @override
  String get localServerPort => 'Local server port';

  @override
  String get backupHistory => 'Backup history';

  @override
  String get restoreHistory => 'Restore history';

  @override
  String get restoreHistoryDesc => 'Import downloads from a backup file';

  @override
  String get cookiesFile => 'Cookies file';

  @override
  String get simultaneousDownloads => 'Simultaneous downloads';

  @override
  String get simultaneousDownloadsDesc => 'Max active downloads at once';

  @override
  String get threadsPerDownload => 'Threads per download';

  @override
  String get threadsPerDownloadDesc =>
      'Parallel connections (fragments) per file';

  @override
  String get maxSpeedMode => 'Max speed mode';

  @override
  String get maxSpeedModeDesc =>
      '64 parallel connections, larger buffers, fast remux (no re-encode)';

  @override
  String get libraryManagement => 'Library management';

  @override
  String get smartOrganization => 'Smart organization';

  @override
  String get smartOrganizationDesc =>
      'Manage auto-sort rules and smart guessing';

  @override
  String get outputFolderNotConfigured => 'Output folder not configured';

  @override
  String get pluginsEmptyHint => 'Plugins extend the functionality of TapLoad';

  @override
  String get statusProcessing => 'Processing';

  @override
  String get statsSubtitle => 'Track your download activity and storage usage';

  @override
  String get statsToday => 'Today';

  @override
  String get downloadActivity => 'Download Activity';

  @override
  String get last7DaysShort => 'Last 7 days';

  @override
  String get sourcesChartTitle => 'Sources';

  @override
  String get sourcesByPlatform => 'By platform';

  @override
  String get shortcutsQuickActions => 'Quick actions';

  @override
  String get noDownloadHistory => 'No download history yet';

  @override
  String get noSourceData => 'No source data yet';

  @override
  String chartDownloadsTooltip(int count, String bytes) {
    return '$count downloads\n$bytes';
  }

  @override
  String get currentAccent => 'Current Accent';

  @override
  String get dataAndHistory => 'Data & History';

  @override
  String get exportHistoryDesc => 'Export your download history to a JSON file';

  @override
  String get saveHistoryBackup => 'Save History Backup';

  @override
  String get tokenCopied => 'Token copied';

  @override
  String get tokenCopiedHint =>
      'Token copied. Paste it in the browser extension.';

  @override
  String get copyToken => 'Copy token';

  @override
  String get portSavedRestart => 'Port saved. Restart the app to apply.';

  @override
  String get historyExported => 'History exported successfully';

  @override
  String get historyRestored => 'History restored successfully';

  @override
  String get generatedOnFirstLaunch => 'Generated on first launch';

  @override
  String serverPortRestartHint(int port) {
    return 'Restart the app after changing. Current: $port';
  }

  @override
  String get torBypassDesc =>
      'Start Tor in the background and route downloads through it (127.0.0.1:9050)';

  @override
  String get torProxyStarting => 'Starting Tor…';

  @override
  String get torProxyReady => 'Tor is ready at 127.0.0.1:9050';

  @override
  String get torProxyExisting =>
      'A Tor proxy is already running at 127.0.0.1:9050';

  @override
  String get torProxyStopped => 'Tor is stopped';

  @override
  String get torProxyFailed => 'Tor is unavailable';

  @override
  String get selectCookiesFile => 'Select cookies.txt';

  @override
  String get clearCookies => 'Clear cookies';

  @override
  String get selectQuality => 'Select Quality';

  @override
  String get unknownSize => 'Unknown size';

  @override
  String get bestQuality => 'Best Quality';

  @override
  String get noLogsAvailable => 'No logs available';

  @override
  String get dropLinksHere => 'Drop links or files here';

  @override
  String get dropLinksHint => 'They will be added to your download queue';

  @override
  String get retryDownload => 'Retry Download';

  @override
  String get restartDownload => 'Restart download';

  @override
  String get copyUrl => 'Copy URL';

  @override
  String get remove => 'Remove';

  @override
  String get urlLabel => 'URL';

  @override
  String get pleaseEnterUrl => 'Please enter a URL';

  @override
  String get enterValidUrl => 'Enter a valid http(s) URL';

  @override
  String get cookiesNoneDefault => 'None (Default)';

  @override
  String get failedFetchQuality => 'Failed to fetch quality options';

  @override
  String get unknown => 'Unknown';

  @override
  String get inspectorId => 'ID';

  @override
  String get storageUsage => 'Storage Usage';

  @override
  String get storageInfoUnavailable => 'Storage info unavailable';

  @override
  String get storageUsed => 'Used';

  @override
  String get storageFree => 'Free';

  @override
  String storageTotalLabel(String size) {
    return 'Total: $size';
  }

  @override
  String get storageFolder => 'Folder';

  @override
  String get storageOtherUsed => 'Other used';

  @override
  String storageFolderOfUsed(String percent) {
    return '$percent% of used';
  }

  @override
  String storageFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
      zero: '0 files',
    );
    return '$_temp0';
  }

  @override
  String get storageTypeVideo => 'Video';

  @override
  String get storageTypeAudio => 'Audio';

  @override
  String get storageTypeOther => 'Other';

  @override
  String get storageTopSubfolders => 'Largest folders';

  @override
  String get storageScanInProgress => 'Scanning folder...';

  @override
  String storageLastScanned(String time) {
    return 'Scanned at $time';
  }

  @override
  String get storageScanCached => 'Cached';

  @override
  String get storageScanError => 'Could not read this folder';

  @override
  String get startingOrganization => 'Starting organization...';

  @override
  String organizationFailed(String error) {
    return 'Organization failed: $error';
  }

  @override
  String thumbnailsOrganized(int count) {
    return 'Thumbnails organized: $count';
  }

  @override
  String foldersCreated(int count) {
    return 'Folders created: $count';
  }

  @override
  String emptyFoldersDeleted(int count) {
    return 'Empty folders deleted: $count';
  }

  @override
  String organizationErrors(int count) {
    return '$count errors occurred';
  }

  @override
  String get nameLabel => 'Name';

  @override
  String get editRule => 'Edit Rule';

  @override
  String get newRule => 'New Rule';

  @override
  String get patternKeywordOrRegex => 'Pattern (Keyword or Regex)';

  @override
  String get regexpPattern => 'RegExp pattern';

  @override
  String get containsText => 'Contains text';

  @override
  String get isRegex => 'Is Regex';

  @override
  String get targetSubfolder => 'Target Subfolder';

  @override
  String get active => 'Active';

  @override
  String get downloadModel => 'Download Model';

  @override
  String get selectPopularModel => 'Select a popular model to pull:';

  @override
  String get ollamaPullNote =>
      'Note: This requires a fast internet connection. Check Ollama logs for progress.';

  @override
  String get smartGuessTitle => 'Smart Guess (AI Curator)';

  @override
  String get smartGuessDesc =>
      'Automatically categorize files based on common patterns or Local AI.';

  @override
  String get aiMode => 'AI Mode';

  @override
  String get aiModeOffline => 'Offline (Heuristic - Fast)';

  @override
  String get aiModeOllama => 'Ollama / LocalAI';

  @override
  String get ollamaApiUrl => 'Ollama API URL';

  @override
  String get modelName => 'Model Name';

  @override
  String get selectOrTypeModel => 'Select from list or type manually';

  @override
  String get refreshModels => 'Refresh Models';

  @override
  String get customRules => 'Custom Rules';

  @override
  String get addRule => 'Add Rule';

  @override
  String get noRulesDefined => 'No rules defined. Add one using the + button.';

  @override
  String get organizeExistingFiles => 'Organize Existing Files';

  @override
  String get organizeExistingFilesDesc =>
      'Scan a folder and organize files using current rules/AI.';

  @override
  String get ollamaMustRun => 'Make sure Ollama is running (`ollama serve`).';

  @override
  String requestingOllamaPull(String model) {
    return 'Requesting Ollama to pull $model... This may take a while.';
  }

  @override
  String organizationCompleteDetail(int scanned, int moved) {
    return 'Organization complete. Scanned $scanned files, moved $moved.';
  }

  @override
  String get toolsSection => 'Tools';

  @override
  String get configurePlugin => 'Configure Plugin';

  @override
  String pluginError(String error) {
    return 'Error: $error';
  }

  @override
  String get setupPreparing => 'Preparing download tools…';

  @override
  String get setupCheckingTools => 'Checking installed tools';

  @override
  String setupDownloading(String name) {
    return 'Downloading $name…';
  }

  @override
  String setupExtracting(String name) {
    return 'Extracting $name…';
  }

  @override
  String setupVerifying(String name) {
    return 'Verifying $name…';
  }

  @override
  String get setupUpdatingYtDlp => 'Updating yt-dlp…';

  @override
  String get setupReady => 'All tools are ready';

  @override
  String get setupFailed => 'Could not install every tool';

  @override
  String get setupRetry => 'Retry';

  @override
  String get setupContinueAnyway => 'Continue anyway';

  @override
  String setupDownloadPercent(int percent) {
    return '$percent%';
  }

  @override
  String get previewSetup => 'Check and repair the download tools';

  @override
  String get previewSetupDesc =>
      'Re-checks yt-dlp, ffmpeg and aria2c and reinstalls what is missing';

  @override
  String get pluginsSectionTitle => 'Download workflow plugins';

  @override
  String get pluginsSectionHint =>
      'These plugins add actions before or after a download completes.';

  @override
  String get browserExtensionsTitle => 'Browser extension';

  @override
  String get browserExtensionsHint =>
      'Send links from the browser to the app. One click prepares the extension and opens the browser page.';

  @override
  String get chromeExtensionTitle => 'Chrome / Edge / Brave';

  @override
  String get chromeExtensionSteps =>
      '1. Click Install. 2. Turn on Developer mode. 3. Load unpacked, then Ctrl+V to paste the path.';

  @override
  String get firefoxExtensionTitle => 'Firefox';

  @override
  String get firefoxExtensionSteps =>
      'Install opens the signed XPI from GitHub. If Firefox blocks it, use Manual install (about:debugging).';

  @override
  String get installInChrome => 'Install in Chrome';

  @override
  String get installInFirefox => 'Install in Firefox';

  @override
  String get downloadExtensionZip => 'Download ZIP';

  @override
  String get firefoxManualInstall => 'Manual install';

  @override
  String get extensionDownloading => 'Preparing extension…';

  @override
  String get extensionDownloadFailed =>
      'Download failed. Check your connection and try again.';

  @override
  String get extensionInstallGuideTitle => 'Extension installation';

  @override
  String get extensionInstallInProgress =>
      'Do not close this window until the download finishes.';

  @override
  String get extensionInstallClose => 'Close';

  @override
  String get extensionInstallRetry => 'Retry';

  @override
  String get extensionStepDownload => 'Download extension files';

  @override
  String get extensionStepDownloadZip => 'Download ZIP to Downloads';

  @override
  String get extensionStepCopyPath => 'Copy install path to clipboard';

  @override
  String get extensionStepOpenBrowser => 'Open browser install page';

  @override
  String get extensionStepLaunchFirefox => 'Launch Firefox installer';

  @override
  String get extensionStepReadyChrome =>
      'Ready! One-time setup: in Chrome turn on Developer mode, click Load unpacked, then Ctrl+V to paste the path.';

  @override
  String get extensionStepReadyZip =>
      'ZIP saved. Extract it if needed, or use Install in Chrome for automatic setup.';

  @override
  String get extensionStepReadyFirefox =>
      'Ready! In about:debugging, click Load Temporary Add-on and select manifest.json (path already copied).';

  @override
  String get extensionStepReadyFirefoxXpi =>
      'Ready! Confirm the add-on install prompt in Firefox; once accepted, it survives browser restarts. Then paste the API token in the extension popup.';

  @override
  String get extensionStepFirefoxFallback =>
      'Could not open XPI directly — using manual install page.';

  @override
  String get extensionStepSkippedBrowser =>
      'Skipped — Firefox opened the installer directly.';

  @override
  String get chromeInstallStarted =>
      'Path copied. In Chrome: Developer mode → Load unpacked → Ctrl+V.';

  @override
  String get firefoxInstallStarted =>
      'Firefox will install the add-on. If blocked, use Manual install.';

  @override
  String extensionPathCopied(String path) {
    return 'Path copied: $path';
  }

  @override
  String get extensionInstallFailed =>
      'Could not open the browser. Try Download ZIP instead.';

  @override
  String get extractingTitle => 'Extracting title...';

  @override
  String get extractingSource => 'Extracting source...';

  @override
  String get extractingSize => 'Extracting size...';

  @override
  String get unknownTitle => 'Unknown title';

  @override
  String get collapseSidebar => 'Collapse sidebar';

  @override
  String get expandSidebar => 'Expand sidebar';

  @override
  String get collapseInspector => 'Collapse inspector';

  @override
  String get expandInspector => 'Expand inspector';

  @override
  String get experimentalXFeedSection => 'Experimental X Feed';

  @override
  String get experimentalXFeedGobird => 'Use gobird (experimental)';

  @override
  String get experimentalXFeedGobirdDesc =>
      'Read-only home feed via bundled gobird. Off by default. Violates X Terms of Service and may risk account suspension.';

  @override
  String get experimentalXFeedWarning =>
      'Warning: gobird uses unofficial private X APIs. You accept all risk. Local DOM feed remains the default fallback.';

  @override
  String get experimentalXFeedConsentTitle => 'Enable experimental gobird?';

  @override
  String get experimentalXFeedConsentBody =>
      'gobird uses unofficial X APIs, may break without notice, and can lead to account suspension or ban. Cookies stay on this PC. Continue only if you accept these risks.';

  @override
  String get experimentalXFeedConsentConfirm => 'I understand — enable';

  @override
  String get gobirdBrowser => 'gobird browser session';

  @override
  String get gobirdBrowserDesc =>
      'Browser logged into X.com for cookie extraction (Chrome or Firefox)';

  @override
  String get gobirdBinaryStatus => 'gobird binary';

  @override
  String gobirdBinaryFound(String version) {
    return 'Found: $version';
  }

  @override
  String get gobirdBinaryMissing =>
      'Not bundled — experimental engine unavailable';

  @override
  String get gobirdDisableNow => 'Disable gobird now';

  @override
  String get playerPrevious => 'Previous';

  @override
  String get playerNext => 'Next';

  @override
  String duplicatesSkipped(int count) {
    return '$count duplicates skipped';
  }

  @override
  String get trayShow => 'Show';

  @override
  String get trayExit => 'Exit';

  @override
  String get needTweetLink => 'Need tweet link';

  @override
  String get openFullscreen => 'Open fullscreen';

  @override
  String get previewUnavailable => 'Preview unavailable';

  @override
  String get sourceYouTube => 'YouTube';

  @override
  String get sourceInstagram => 'Instagram';

  @override
  String get sourceTwitter => 'Twitter';

  @override
  String get sourceTwitch => 'Twitch';

  @override
  String get sourceKick => 'Kick';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'العربية';

  @override
  String get qualityManual => 'Manual';

  @override
  String get qualityManualPlus => 'Manual+';

  @override
  String get notificationDownloadCompleted => 'Download Completed';

  @override
  String get notificationDownloadFailed => 'Download Failed';

  @override
  String get notificationLinkDetected => 'Link Detected';

  @override
  String notificationLinkDetectedBody(String url) {
    return 'Click to download: $url';
  }

  @override
  String get notificationLinksQueuedTitle => 'Links queued';

  @override
  String notificationLinksQueuedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links queued',
      one: '$count link queued',
    );
    return '$_temp0';
  }

  @override
  String get notificationExtensionConnected => 'Extension Connected';

  @override
  String get notificationExtensionConnectedBody =>
      'Browser extension successfully connected.';

  @override
  String get notificationBatchComplete => 'Batch Download Complete';

  @override
  String notificationBatchCompleteBody(int count, String totalSize) {
    return '$count downloads finished — $totalSize total';
  }

  @override
  String get notificationYtDlpUpdated => 'yt-dlp Updated';

  @override
  String notificationYtDlpUpdatedBody(String version) {
    return 'Updated to $version';
  }

  @override
  String get browseX => 'Browse X';

  @override
  String get browseXHint =>
      'Sign in if needed, then tap Download on any video.';

  @override
  String get mobileLibrary => 'Library';

  @override
  String get shareDownloadStarted => 'Download started from share';

  @override
  String get transferTitle => 'Transfer';

  @override
  String get transferSubtitle => 'Same Wi-Fi. Scan the QR or tap a device.';

  @override
  String get transferPortBusy =>
      'Port 53317 is taken. QR still works; LocalSend inbound on this PC may fail.';

  @override
  String get transferMe => 'This PC';

  @override
  String get transferDevices => 'Devices';

  @override
  String get transferPayload => 'What to send';

  @override
  String get transferSearchCreator => 'Search a creator…';

  @override
  String get transferEntireLibrary => 'Entire library';

  @override
  String get transferClearSelection => 'Clear';

  @override
  String transferSelectedFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count folders',
      one: '$count folder',
    );
    return '$_temp0';
  }

  @override
  String get transferNoCreatorMatch => 'No creator matches';

  @override
  String get transferNoDevices => 'No device yet — scan the QR on your phone.';

  @override
  String get transferWaitingNetwork => 'Waiting for a LAN address…';

  @override
  String get transferKnown => 'Known device';

  @override
  String get transferSend => 'Send';

  @override
  String get transferOtherFolder => 'Another folder…';

  @override
  String get transferSending => 'Sending…';

  @override
  String get transferPreparing => 'Preparing files…';

  @override
  String get transferCompressing => 'Creating ZIP archive…';

  @override
  String get transferWaitingPeer => 'Waiting for LocalSend to accept…';

  @override
  String get transferNeedPayload => 'Pick a creator or Entire library first.';

  @override
  String get transferErrorHttp =>
      'Can\'t reach the phone. Same Wi-Fi, LocalSend Receive on, encryption on. If it asks for a PIN, enter it.';

  @override
  String get transferErrorBusy => 'The phone is busy with another transfer.';

  @override
  String get transferErrorRejected => 'The phone refused the transfer.';

  @override
  String get transferDone => 'Sent.';

  @override
  String get transferIncomingTitle => 'Incoming transfer';

  @override
  String transferIncomingBody(String alias, int count, String size) {
    return '$alias wants to send $count files ($size)';
  }

  @override
  String get transferAccept => 'Accept';

  @override
  String get transferReject => 'Decline';

  @override
  String get transferPeerPinTitle => 'Device PIN';

  @override
  String get transferPeerPinHint => 'PIN shown on the other device';

  @override
  String get transferTabSend => 'Send';

  @override
  String get transferTabReceive => 'Receive';

  @override
  String get transferDirectIpTitle => 'Direct IP Connection';

  @override
  String get transferDirectIpHint => 'E.g. 192.168.1.122';

  @override
  String get transferDirectIpAction => 'Connect';

  @override
  String get transferScanSubnet => 'Scan network';

  @override
  String get transferScanningSubnet => 'Scanning subnet…';

  @override
  String get transferRetry => 'Retry';

  @override
  String get transferCancel => 'Cancel';

  @override
  String get transferDirectBrowserUrl => 'Web browser link';

  @override
  String get transferCopyLink => 'Copy link';

  @override
  String get transferCopied => 'Copied!';

  @override
  String get transferListeningOn => 'Listening on network';

  @override
  String transferVideosFound(int count) {
    return '$count found';
  }

  @override
  String transferAlreadyTransferred(int count) {
    return '$count already transferred';
  }

  @override
  String transferNewVideos(int count) {
    return '$count new';
  }

  @override
  String transferSendNewOnly(int count) {
    return 'Send $count new videos';
  }

  @override
  String transferSendAll(int count) {
    return 'Send all ($count)';
  }

  @override
  String get transferOnlyNewToggle => 'Send new videos only';

  @override
  String transferFolderBreakdown(int newCount, int alreadyCount) {
    return '$newCount new • $alreadyCount transferred';
  }

  @override
  String get transferForgetDeviceHistory => 'Forget history for this device';

  @override
  String get transferHistoryCleared => 'Transfer history cleared';

  @override
  String get onboardingStart => 'Start';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingDone => 'Done';

  @override
  String get onboardingSkipStep => 'Skip';

  @override
  String get onboardingSkipAll => 'Skip tour';

  @override
  String get onboardingReplay => 'Replay tour';

  @override
  String get onboardingReplayDesc => 'Show the tour again';

  @override
  String get onboardingWelcomeTitle => 'Quick tour';

  @override
  String get onboardingWelcomeBody =>
      'A short walk through the main screens. Skip anytime.';

  @override
  String get onboardingNewDownloadTitle => 'New download';

  @override
  String get onboardingNewDownloadBody =>
      'Paste a URL or send one from the browser extension.';

  @override
  String get onboardingLibraryTitle => 'Library';

  @override
  String get onboardingLibraryBody =>
      'Filter downloads by active, done, or failed.';

  @override
  String get onboardingTopBarTitle => 'Toolbar';

  @override
  String get onboardingTopBarBody =>
      'Search, pause the queue, and retry failed downloads.';

  @override
  String get onboardingFoldersTitle => 'Creator folders';

  @override
  String get onboardingFoldersBody =>
      'Downloads are grouped by channel. Switch list or folders, then sort.';

  @override
  String get onboardingTransferTitle => 'Transfer';

  @override
  String get onboardingTransferBody =>
      'Pick folders, scan the QR, then accept on the other device.';

  @override
  String get onboardingStatsTitle => 'Stats';

  @override
  String get onboardingStatsBody => 'Totals, disk space, and download history.';

  @override
  String get onboardingOutputTitle => 'Output folder';

  @override
  String get onboardingOutputBody => 'Choose where files are saved.';

  @override
  String get onboardingExtensionTitle => 'Browser extension';

  @override
  String get onboardingExtensionBody =>
      'Install the Chrome or Firefox extension to send links here.';

  @override
  String get onboardingReadyTitle => 'Ready';

  @override
  String get onboardingReadyBody => 'Replay the tour from Settings > General.';

  @override
  String get pluginFeaturesTitle => 'App features';

  @override
  String get pluginFeaturesHint =>
      'Turn on only the screens and tools you use. Disabling a feature keeps its code and data intact.';

  @override
  String get pluginRequired => 'Essential';

  @override
  String get pluginActivate => 'Enable feature';

  @override
  String get pluginOpen => 'Open feature';

  @override
  String get pluginInactiveTitle => 'Feature is disabled';

  @override
  String get pluginInactiveBody =>
      'The feature is still available and its data is untouched. You can turn it back on in plugin settings.';

  @override
  String get pluginManage => 'Manage plugins';

  @override
  String get pluginWebRequest =>
      'TapLoad’s website requested this feature. Confirm here to add it to your interface.';

  @override
  String get pluginExternalHint =>
      'This extension is installed in your browser. Use the existing setup steps below.';

  @override
  String get addSheetTitle => 'New download';

  @override
  String addSheetPasteCopiedLink(String url) {
    return 'Paste copied link: $url';
  }

  @override
  String get addSheetModeVideo => 'Video';

  @override
  String get addSheetModeAudioOnly => 'Audio only';

  @override
  String get addSheetBrowserSession => 'Browser session';

  @override
  String get addSheetQualityChosen => 'Selected quality';

  @override
  String addSheetQualityChosenWithSize(String size) {
    return 'Selected quality, $size';
  }

  @override
  String get addSheetStarting => 'Starting…';

  @override
  String get addSheetDownload => 'Download';

  @override
  String get addSheetPreviewUnavailable =>
      'Preview unavailable. The download may still work.';

  @override
  String get addSheetAnalyzing => 'Analyzing link…';

  @override
  String get addSheetUrlHint => 'Paste the video or media link';

  @override
  String get addSheetValidLink => 'Valid link';

  @override
  String get addSheetClear => 'Clear';

  @override
  String get addSheetPaste => 'Paste';

  @override
  String get addSheetInvalidUrl => 'Please enter a valid URL.';

  @override
  String get addSheetUnsupportedUrl => 'Unsupported URL or restricted domain.';

  @override
  String addSheetError(String error) {
    return 'Error: $error';
  }

  @override
  String get addSheetDetailBest => 'Maximum resolution available';

  @override
  String get addSheetDetail1080 => 'High definition';

  @override
  String get addSheetDetail720 => 'Balanced';

  @override
  String get addSheetDetail480 => 'Data saver';

  @override
  String get addSheetDetailAudio => 'Extracted audio, best quality available';

  @override
  String get addSheetReadoutMax => 'Max';

  @override
  String get addSheetUntitledMedia => 'Untitled media';

  @override
  String get sizeUnitKb => 'KB';

  @override
  String get sizeUnitMb => 'MB';

  @override
  String get sizeUnitGb => 'GB';

  @override
  String get archiveMobileTitle => 'TikTok archive';

  @override
  String get archiveMobileFilters => 'Filters';

  @override
  String get archiveMobileReset => 'Reset';

  @override
  String get archiveMobileType => 'Type';

  @override
  String get archiveMobileFilterAll => 'All';

  @override
  String get archiveMobileFilterFavorites => 'Favorites';

  @override
  String get archiveMobileFilterLikes => 'Likes';

  @override
  String get archiveMobileYear => 'Year';

  @override
  String get archiveMobileAllYears => 'All';

  @override
  String get archiveMobileApplyFilters => 'Apply filters';

  @override
  String get archiveMobileBackToVideos => 'Back to videos';

  @override
  String get archiveMobileDownload => 'Download';

  @override
  String get archiveMobileBatchStarted => 'Batch download started';

  @override
  String get archiveMobileSyncTooltip => 'Import or sync';

  @override
  String get archiveMobileBackToLibrary => 'Back to library';

  @override
  String get archiveMobileBatchRunning => 'Batch download in progress';

  @override
  String archiveMobileSkippedVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos skipped',
      one: '$count video skipped',
    );
    return '$_temp0';
  }

  @override
  String get archiveMobileStopBatch => 'Stop batch';

  @override
  String get archiveMobileSyncingCollections => 'Syncing collections';

  @override
  String get archiveMobileSyncWaiting =>
      'Waiting for the browser\'s response. Keep a TikTok page open.';

  @override
  String get archiveMobileChipAll => 'All';

  @override
  String get archiveMobileSearchHint => 'Search for a video or a collection';

  @override
  String get archiveMobileClearSearch => 'Clear search';

  @override
  String archiveMobileVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '$count video',
    );
    return '$_temp0';
  }

  @override
  String get archiveMobileClearSelection => 'Clear selection';

  @override
  String get archiveMobileSelectAll => 'Select all';

  @override
  String get archiveMobileManageCollections => 'Manage collections';

  @override
  String get archiveMobilePlayFullscreen => 'Play videos full screen';

  @override
  String get archiveMobileNoVideos => 'No videos found';

  @override
  String get archiveMobileVideoAdded => 'Video added to the download queue.';

  @override
  String archiveMobileTileLabel(String date) {
    return 'Video $date';
  }

  @override
  String get archiveMobileProgress => 'Progress';

  @override
  String archiveMobileSelectedLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'selected',
      one: 'selected',
    );
    return '$_temp0';
  }

  @override
  String get statsMobileBackToLibrary => 'Back to library';

  @override
  String get statsMobileTotalSinceInstall =>
      'Total downloaded since installation';

  @override
  String get statsMobileActivity => 'Activity';

  @override
  String get statsMobileLast12Weeks => 'Last 12 weeks';

  @override
  String get statsMobileLess => 'Less';

  @override
  String get statsMobileMore => 'More';

  @override
  String get statsMobileBySource => 'Downloads by source';

  @override
  String statsMobileDownloadsSummary(int total, int today) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total downloads',
      one: '$total download',
    );
    return '$_temp0, $today today';
  }

  @override
  String get statsMobileHeatmapLabel => 'Heatmap of downloads per day';

  @override
  String get statsMobileOthers => 'Others';

  @override
  String get statsMobileUnitB => 'B';

  @override
  String get statsMobileUnitKB => 'KB';

  @override
  String get statsMobileUnitMB => 'MB';

  @override
  String get statsMobileUnitGB => 'GB';

  @override
  String get statsMobileUnitTB => 'TB';

  @override
  String get settingsHubEngine => 'yt-dlp engine';

  @override
  String get settingsHubUnavailable => 'Unavailable';

  @override
  String get settingsHubChecking => 'Checking…';

  @override
  String get settingsHubCheckUpdates => 'Check for updates';

  @override
  String get settingsHubAutoUpdate => 'Automatic update';

  @override
  String get settingsHubChannel => 'Update channel';

  @override
  String get settingsHubChannelNightly => 'Nightly';

  @override
  String get settingsHubChannelStable => 'Stable';

  @override
  String get settingsHubUpdateFailed => 'Check failed, try again later.';

  @override
  String get settingsHubUpToDate => 'yt-dlp is up to date';

  @override
  String get settingsHubUpdated => 'yt-dlp updated';

  @override
  String settingsHubUpdateError(String error) {
    return 'Update error: $error';
  }

  @override
  String get settingsHubParallel => 'Parallel downloads';

  @override
  String get settingsHubParallelHint => 'More speed, more heat';

  @override
  String get settingsHubStorage => 'Storage';

  @override
  String settingsHubStorageFree(String free, String total) {
    return '$free free of $total';
  }

  @override
  String get settingsHubWifiOnly => 'Wi-Fi only';

  @override
  String get settingsHubWifiOnlyHint => 'Never start a download on mobile data';

  @override
  String get detailsWifiOnlyHeadline =>
      'Wi-Fi only is on: connect to Wi-Fi, then retry';

  @override
  String get detailsStatusFailed => 'Failed';

  @override
  String get detailsStatusDownloading => 'Downloading';

  @override
  String get detailsStatusExtracting => 'Analyzing link';

  @override
  String get detailsStatusDuplicate => 'Already added';

  @override
  String get detailsDiagnostic => 'Diagnostic';

  @override
  String get detailsStepResolve => 'Resolving link';

  @override
  String get detailsStepReadPage => 'Reading page';

  @override
  String get detailsStepExtractFormats => 'Extracting formats';

  @override
  String get detailsStepDownload => 'Downloading';

  @override
  String get detailsStepMerge => 'Merging audio and video';

  @override
  String get detailsStepFailMerge => 'Merging the file failed';

  @override
  String get detailsStepFailTransfer => 'The transfer was interrupted';

  @override
  String get detailsStepFailNoMedia => 'No accessible media';

  @override
  String detailsEngineUpdated(String status) {
    return 'Engine updated: $status';
  }

  @override
  String detailsYtDlpUpdateSuccess(String status) {
    return 'yt-dlp update succeeded: $status';
  }

  @override
  String detailsEngineUpdateError(String error) {
    return 'Error during update: $error';
  }

  @override
  String get detailsLinkCopied => 'Link copied to clipboard';

  @override
  String get detailsShare => 'Share';

  @override
  String get detailsOpenWith => 'Open with';

  @override
  String get detailsCopyLink => 'Copy link';

  @override
  String get detailsRestart => 'Start over';

  @override
  String get detailsPlayVideo => 'Play video';

  @override
  String get detailsInfoTitle => 'Information';

  @override
  String get detailsInfoSource => 'Source';

  @override
  String get detailsInfoSize => 'Size';

  @override
  String get detailsInfoFile => 'File';

  @override
  String get detailsInfoId => 'Identifier';

  @override
  String get detailsUpdatingEngine => 'Updating engine…';

  @override
  String get detailsRepairAuto => 'Repair automatically';

  @override
  String get detailsSignInBrowser => 'Sign in in the browser';

  @override
  String get detailsAgeSolutions => 'See solutions (18+)';

  @override
  String get detailsTechnicalDetails => 'Technical details';

  @override
  String get detailsNoLogs => 'No logs available.';

  @override
  String get detailsCopyLogs => 'Copy logs';

  @override
  String get detailsLogsCopied => 'Logs copied';

  @override
  String get detailsHeadlineAgeVerification => 'Age verification required';

  @override
  String detailsHeadlineHostRefused(String host) {
    return '$host refused the request';
  }

  @override
  String get detailsHeadlineTooManyRequests =>
      'Too many requests, access limited';

  @override
  String get detailsHeadlinePrivateVideo => 'Private or removed video';

  @override
  String get detailsHeadlineGeoBlocked => 'Content blocked in your country';

  @override
  String get detailsHeadlineCopyright => 'Removed for copyright';

  @override
  String get detailsHeadlineSuspended => 'Account or content suspended';

  @override
  String get detailsHeadlineNoMedia => 'No media in this link';

  @override
  String get detailsHeadlineUnsupportedUrl => 'Link not supported';

  @override
  String get detailsHeadlineUnavailable => 'Content unavailable';

  @override
  String get detailsHeadlineLiveOffline => 'The live stream is offline';

  @override
  String get detailsHeadlineAntiBot => 'Anti-bot protection detected';

  @override
  String get detailsHeadlineNoFormats => 'No accessible format';

  @override
  String get detailsHeadlineLoginRequired => 'Sign-in required';

  @override
  String get detailsHeadlineNetwork => 'Network problem';

  @override
  String get detailsHeadlineFailed => 'The download failed';

  @override
  String downloadCardDeleteConfirm(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get downloadCardAgeVerification =>
      'Age verification (18+), see solutions';

  @override
  String get fileDeletedFromDisk =>
      'The file will be deleted from your disk. This can\'t be undone.';

  @override
  String downloadCardFailedMeta(String source) {
    return '$source, failed. See diagnostic';
  }

  @override
  String downloadCardQueuePosition(int position) {
    return 'Position $position in queue';
  }

  @override
  String downloadCardSizeOf(String done, String total) {
    return '$done of $total';
  }

  @override
  String get libraryHeaderArchive => 'TikTok archive';

  @override
  String get libraryHeaderFailed => 'Failed';

  @override
  String get libraryHeaderFolders => 'Folders';

  @override
  String libraryHeaderMoreActive(int count) {
    return '+$count in progress';
  }

  @override
  String get libraryHeaderLiveSpeed => 'Live speed';

  @override
  String libraryHeaderRemaining(String eta) {
    return '$eta left';
  }

  @override
  String get libraryHeaderUnitGBps => 'GB/s';

  @override
  String get libraryHeaderUnitMBps => 'MB/s';

  @override
  String get libraryHeaderUnitKBps => 'KB/s';

  @override
  String get libraryHeaderUnitBps => 'B/s';

  @override
  String clipboardCapsuleCopied(String platform) {
    return 'Link copied, $platform';
  }

  @override
  String get clipboardCapsuleMediaLink => 'Media link';

  @override
  String get clipboardCapsuleDownload => 'Download';

  @override
  String get clipboardCapsuleDismiss => 'Dismiss';

  @override
  String get shellTabLibrary => 'Library';

  @override
  String get shellTabBrowse => 'Browse';

  @override
  String get shellTabSend => 'Send';

  @override
  String get shellTabSettings => 'Settings';

  @override
  String get browserMobileTitle => 'Browser';

  @override
  String get browserMobileBack => 'Back';

  @override
  String get browserMobileForward => 'Forward';

  @override
  String get browserMobileReload => 'Reload';

  @override
  String get browserMobileReadyToDownload => 'Page ready to download';

  @override
  String get browserMobileDownload => 'Download';

  @override
  String get oledKitStepperLess => 'Less';

  @override
  String get oledKitStepperMore => 'More';

  @override
  String oledKitFragmentsReceived(int done, int total) {
    return '$done of $total fragments received';
  }

  @override
  String get settingsTilesNotFound => 'Not found';

  @override
  String get settingsOutputChangeFolderTitle => 'Change folder';

  @override
  String get settingsOutputChangeFolderBody =>
      'Do you want to automatically migrate all your existing videos and thumbnails to this new folder?';

  @override
  String get settingsOutputChangeFolderOnly => 'Only change the folder';

  @override
  String get settingsOutputMigrateFiles => 'Migrate files';

  @override
  String get settingsOutputMigrateLibraryTitle => 'Migrate library';

  @override
  String get settingsOutputMigrateLibraryDesc =>
      'Move all videos and thumbnails to another drive or folder';

  @override
  String get settingsOutputReorganizeTitle => 'Reorganize existing videos';

  @override
  String get settingsOutputReorganizeDesc =>
      'Sort already downloaded videos into subfolders by creator (with preview)';

  @override
  String get settingsSmartRecommendedRules => 'Recommended rules';

  @override
  String settingsSystemYtDlpUpdated(String result) {
    return 'yt-dlp updated: $result';
  }

  @override
  String settingsSystemUpdateError(String error) {
    return 'Update error: $error';
  }

  @override
  String get settingsSystemUpdateEngineTitle => 'Update the yt-dlp engine';

  @override
  String get settingsSystemUpdateEngineDownloading =>
      'Downloading the latest version (nightly)...';

  @override
  String get settingsSystemUpdateEngineDesc =>
      'Check for and install the latest version of yt-dlp';

  @override
  String transferMobileAddFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count folders',
      one: 'Add $count folder',
    );
    return '$_temp0';
  }

  @override
  String get transferMobileBroadcastDone =>
      'Discovery signal broadcast on the network';

  @override
  String get transferMobileBroadcastTooltip =>
      'Broadcast a network announcement';

  @override
  String transferMobileBytesOf(String done, String total) {
    return '$done of $total';
  }

  @override
  String get transferMobileCheckAll => 'Select all';

  @override
  String get transferMobileUncheckAll => 'Deselect all';

  @override
  String get transferMobileClearList => 'Clear list';

  @override
  String transferMobileCreatorCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count creators',
      one: '$count creator',
    );
    return '$_temp0';
  }

  @override
  String get transferMobileDemoNoFiles =>
      'Demo mode: no personal files accessible.';

  @override
  String get transferMobileDemoSendSimulated =>
      'Demo mode: simulated send, no file transmitted.';

  @override
  String get transferMobileDeviceNotFound => 'No device found at this address.';

  @override
  String transferMobileDeviceUnreachable(String address) {
    return 'Device unreachable ($address)';
  }

  @override
  String get transferMobileDiagBusy =>
      'The receiving device is already busy with another transfer.';

  @override
  String get transferMobileDiagChecksumMismatch =>
      'Data integrity error (checksum mismatch).';

  @override
  String get transferMobileDiagCommunication =>
      'Error communicating with the device.';

  @override
  String get transferMobileDiagConnectionRefused =>
      'Connection refused. Open LocalSend on the receiving device and turn on Receive mode.';

  @override
  String get transferMobileDiagPinRequired =>
      'PIN required by the receiving device.';

  @override
  String get transferMobileDiagRejected =>
      'Transfer declined by the user on the receiving device.';

  @override
  String get transferMobileDiagTimeout =>
      'Connection timed out. Check that the receiving device is on and on the same Wi-Fi.';

  @override
  String get transferMobileDiagUnreachable =>
      'Check that LocalSend is open on that device, on the same Wi-Fi network.';

  @override
  String transferMobileFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '$count file',
    );
    return '$_temp0';
  }

  @override
  String transferMobileFolderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count folders',
      one: '$count folder',
    );
    return '$_temp0';
  }

  @override
  String transferMobileFolderPickError(String error) {
    return 'Folder selection error: $error';
  }

  @override
  String get transferMobileFoldersAction => 'Folders…';

  @override
  String get transferMobileVideosAction => 'Videos…';

  @override
  String get transferMobileHeaderReceiving => 'Receiving';

  @override
  String get transferMobileHeaderSending => 'Sending';

  @override
  String get transferMobileIpAddress => 'IP address';

  @override
  String get transferMobileKindDesktop => 'Computer';

  @override
  String get transferMobileKindHeadless => 'Headless';

  @override
  String get transferMobileKindMobile => 'Mobile';

  @override
  String get transferMobileKindServer => 'Server';

  @override
  String get transferMobileKindWeb => 'Browser';

  @override
  String transferMobileLibraryNewOfTotal(
    String library,
    int newest,
    int found,
  ) {
    return '$library ($newest new / $found)';
  }

  @override
  String get transferMobileMarkKnown => 'Mark as known device';

  @override
  String get transferMobileUnmarkKnown => 'Remove from known devices';

  @override
  String transferMobileMediaCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count media items',
      one: '$count media item',
    );
    return '$_temp0';
  }

  @override
  String get transferMobileMediaFallback => 'Media';

  @override
  String transferMobileMediaSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count media items selected',
      one: '$count media item selected',
    );
    return '$_temp0';
  }

  @override
  String transferMobileNameNewCount(String name, int newest) {
    return '$name ($newest new)';
  }

  @override
  String transferMobileNearbyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nearby devices',
      one: '$count nearby device',
      zero: 'No nearby devices',
    );
    return '$_temp0';
  }

  @override
  String transferMobileNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new videos',
      one: '$count new video',
    );
    return '$_temp0';
  }

  @override
  String get transferMobileNoDataSent => 'no data sent';

  @override
  String get transferMobileNoFolderMatch => 'No folder matches';

  @override
  String get transferMobilePeerPinExplain =>
      'This receiving device protects incoming transfers with a PIN set in its LocalSend settings.\n\nEnter the PIN configured on your phone (or turn off the PIN option in the settings of your phone to send without a code).';

  @override
  String transferMobilePeerPinRequired(String alias) {
    return 'PIN required by $alias';
  }

  @override
  String get transferMobilePinExample => 'E.g. 1234';

  @override
  String get transferMobilePinLabel => 'Security PIN';

  @override
  String transferMobilePortAltActive(int port) {
    return 'Port 53317 is busy. Alternate port $port is active.';
  }

  @override
  String get transferMobilePortDefault => 'Port (default: 53317)';

  @override
  String get transferMobileQrHide => 'Hide QR code';

  @override
  String get transferMobileQrShow => 'Show QR code';

  @override
  String get transferMobileQrShowMobileToMobile =>
      'Show QR code (phone to phone)';

  @override
  String get transferMobileReadyToReceive => 'Ready to receive';

  @override
  String get transferMobileReceiveFiles => 'Receive files';

  @override
  String get transferMobileRefresh => 'Refresh';

  @override
  String get transferMobileRefreshSearch => 'Refresh search';

  @override
  String transferMobileScanFolders(int scanned, int total, int videos) {
    String _temp0 = intl.Intl.pluralLogic(
      videos,
      locale: localeName,
      other: '$videos videos',
      one: '$videos video',
    );
    return 'Folders $scanned / $total ($_temp0)…';
  }

  @override
  String transferMobileScanVideosFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos found…',
      one: '$count video found…',
    );
    return '$_temp0';
  }

  @override
  String get transferMobileSearchDemoMedia => 'Search a demo media item…';

  @override
  String transferMobileSelectedOfTotal(int selected, int total) {
    return '$selected/$total selected';
  }

  @override
  String get transferMobileShowPinQr => 'Show my PIN and QR code';

  @override
  String get transferMobileSimulation => 'simulation';

  @override
  String get transferMobileSubfoldersFilter => 'Filter subfolders…';

  @override
  String transferMobileSubfoldersFoundIn(String name) {
    return 'Folders found in $name';
  }

  @override
  String get transferMobileSubfoldersTitle => 'Select folders';

  @override
  String get transferMobileUpToDate => 'Up to date';

  @override
  String transferMobileUpToDateCount(int count) {
    return 'Up to date ($count)';
  }

  @override
  String transferMobileVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '$count video',
    );
    return '$_temp0';
  }

  @override
  String transferMobileVideosZipped(int count) {
    return '$count videos (bundled in a ZIP)';
  }

  @override
  String get transferMobileVisibleOnLan => 'Visible on the local network';

  @override
  String get transferMobileVisibleOnWifi => 'Visible on the local Wi-Fi';

  @override
  String get transferMobileZipActive => 'ZIP on';

  @override
  String get transferMobileZipArchive => 'Archive as ZIP';

  @override
  String get transferMobileZipEnabled => 'ZIP archive: On';

  @override
  String get transferMobileZipHintLarge =>
      'ZIP is on. For large folders, turning ZIP off speeds up direct sending to the gallery.';

  @override
  String get transferMobileZipHintMulti =>
      'Several files → one ZIP archive (no compression, videos are already compressed)';

  @override
  String get transferMobileZipHintOff =>
      'Files are sent as they are to LocalSend (straight into the gallery)';

  @override
  String get transferMobileZipTooltip =>
      'Bundle several files into a ZIP archive (copy, no compression)';

  @override
  String get detailsStepFailMetered => 'Mobile data in use';

  @override
  String get archiveMobileCollectionLiked => 'Liked videos';

  @override
  String get archiveMobileCollectionUnsortedFavorites => 'Unsorted favorites';

  @override
  String get browserSniffTitle => 'Detected media';

  @override
  String get browserSniffHint =>
      'What this page loaded. Picking one downloads it with your browser session.';

  @override
  String browserSniffCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count media detected',
      one: '1 media detected',
    );
    return '$_temp0';
  }

  @override
  String get browserSniffOpen => 'Streams';

  @override
  String get browserSniffKindHls => 'HLS stream';

  @override
  String get browserSniffKindDash => 'DASH stream';

  @override
  String get browserSniffKindVideo => 'Video file';

  @override
  String get browserSniffKindAudio => 'Audio file';

  @override
  String get browserSniffDrmNote =>
      'Protected (DRM) content is detected but cannot be downloaded.';

  @override
  String get backAgainToExit => 'Press back again to exit';

  @override
  String get archiveHubImport => 'Import your TikTok export';

  @override
  String get archiveHubImportHint => 'Pick the JSON file exported from TikTok.';

  @override
  String get archiveHubPick => 'Choose a file';

  @override
  String get archiveHubOpen => 'Open library';

  @override
  String archiveHubCollections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collections',
      one: '$count collection',
    );
    return '$_temp0';
  }

  @override
  String get archiveHubLoading => 'Indexing your library…';

  @override
  String get launchWordmark => 'TapLoad';

  @override
  String get launchContinueAnyway => 'Continue anyway';

  @override
  String get onbSkip => 'Skip';

  @override
  String get onbNext => 'Next';

  @override
  String get onbStart => 'Get started';

  @override
  String get onbPage1Title => 'Paste a link.\nDone.';

  @override
  String get onbPage1Body => 'Share from any app, or tap + to add a download.';

  @override
  String get onbPage2Title => 'Browse.\nWe detect.';

  @override
  String get onbPage2Body =>
      'Open a site in the Web tab. The media it plays shows up, ready to save.';

  @override
  String get onbPage3Title => 'Your library,\noffline.';

  @override
  String get onbPage3Body =>
      'Everything is stored on your phone and plays without a connection.';

  @override
  String get onbPage4Title => 'You\'re set.';

  @override
  String get onbPage4Body => 'Share a link to the app, or tap + to start.';

  @override
  String onbPageLabel(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String etaSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String etaMinutesSeconds(int minutes, int seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String etaHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get archiveCollSearch => 'Search a collection';

  @override
  String get archiveCollEmpty => 'No collection found';

  @override
  String get archiveCollShowVideos => 'View videos';

  @override
  String archiveCollDownloadAll(int count) {
    return 'Download all ($count)';
  }

  @override
  String get archiveCollReset => 'Remove the videos from this collection';

  @override
  String get archiveCollResetTitle => 'Reset the collection';

  @override
  String archiveCollResetBody(int count, String name) {
    return 'Remove the $count videos from “$name”? The videos and their other collections are kept.';
  }

  @override
  String get archiveCollResetConfirm => 'Remove';

  @override
  String archiveCollResetDone(String name) {
    return '“$name” emptied';
  }

  @override
  String get archiveCollDelete => 'Delete the collection';

  @override
  String archiveCollDeleteBody(int count, String name) {
    return 'Permanently delete “$name”? Its $count videos stay on your device but leave this folder.';
  }

  @override
  String get archiveCollDeleteConfirm => 'Delete';

  @override
  String archiveCollDeleteDone(String name) {
    return '“$name” deleted';
  }

  @override
  String get archiveCollClear => 'Reset the whole archive';

  @override
  String get archiveCollClearBody =>
      'Delete all collections, rankings and the local TikTok import? Videos already downloaded are kept.';

  @override
  String get archiveCollClearConfirm => 'Delete everything';

  @override
  String get archiveCollClearDone => 'TikTok archive reset';

  @override
  String get libraryPhaseAnalyzing => 'Analyzing the link…';

  @override
  String get libraryPhaseConnecting => 'Connecting to the server…';

  @override
  String get libraryPhaseFinalizing => 'Finalizing the file…';

  @override
  String get libraryDoneTitle => 'Done';

  @override
  String get libraryDoneAverage => 'on average';

  @override
  String libraryDoneSummary(String size, String time) {
    return '$size in $time';
  }

  @override
  String get alreadyTitle => 'Already in your library';

  @override
  String alreadyBody(String title) {
    return '“$title” was already downloaded, so nothing was transferred. Open it, or replace it with a fresh copy.';
  }

  @override
  String get alreadyOpen => 'Open';

  @override
  String get alreadyReplace => 'Download again';

  @override
  String get alreadyDismiss => 'Close';

  @override
  String get sortFieldDate => 'Date';

  @override
  String get sortFieldName => 'Name';

  @override
  String get sortFieldSize => 'Size';

  @override
  String get moreActions => 'More actions';

  @override
  String get retryFailedAction => 'Retry failed';

  @override
  String retryingFailed(int count) {
    return 'Retrying $count failed download(s)';
  }

  @override
  String get pauseActiveAction => 'Pause active downloads';

  @override
  String get pauseActiveTooltip => 'Pause all active downloads';

  @override
  String get activeDownloadsPaused => 'Active downloads paused';

  @override
  String get startQueueAction => 'Start the queue';

  @override
  String get startQueueTooltip =>
      'Start all waiting, paused and failed downloads';

  @override
  String get queueStarted => 'Queue started';

  @override
  String get clearCompletedAction => 'Clear completed';

  @override
  String get clearCompletedDone => 'Completed downloads deleted';

  @override
  String get clearFailedAction => 'Clear failed';

  @override
  String get clearFailedDone => 'Failed downloads cleared';

  @override
  String get reduceEffects => 'Reduce visual effects';

  @override
  String get reduceEffectsDesc =>
      'Turns off blur and background animations. Smoother on modest PCs.';

  @override
  String get emptyLibraryHint => 'Press Ctrl+N and paste a video link.';

  @override
  String get clearSearchAndFilters => 'Clear search and filters';

  @override
  String get inspectorPlayMedia => 'Play media';

  @override
  String get inspectorSourceUrl => 'Source URL';

  @override
  String get inspectorLocalFile => 'Local file';

  @override
  String get urlCopied => 'URL copied to the clipboard';

  @override
  String get showInFolder => 'Show in folder';

  @override
  String get detailsAction => 'Details';

  @override
  String failedRetryBadge(int count) {
    return '$count failed · Retry';
  }

  @override
  String retryAllFailedTooltip(int count) {
    return 'Retry all failed downloads ($count)';
  }

  @override
  String get ageCheckRequired => 'Age verification required (18+)';

  @override
  String get ageCheckSeeSolutions => 'See solutions (18+)';

  @override
  String clearCompletedConfirm(int count) {
    return 'Delete $count completed download(s)?';
  }

  @override
  String get filesDeletedFromDisk =>
      'Their files will be deleted from your disk. This can\'t be undone.';

  @override
  String get archivePurgeSelect => 'Select';

  @override
  String get archivePurgeSelectTooltip =>
      'Select collections to delete their videos';

  @override
  String archivePurgeSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get archivePurgeAction => 'Delete their videos';

  @override
  String get archivePurgeMenu => 'Delete the downloaded videos';

  @override
  String archivePurgeTitle(int count) {
    return 'Delete the videos of $count collection(s)?';
  }

  @override
  String archivePurgeBody(int videos, int files) {
    return '$videos videos leave the archive and $files downloaded files are permanently deleted from your disk. The collections are removed.';
  }

  @override
  String archivePurgeKept(int count) {
    return '$count videos that are also in a collection you keep are kept.';
  }

  @override
  String archivePurgeDone(int files, int videos) {
    return '$files files deleted, $videos videos removed';
  }

  @override
  String archiveVideoTitle(String date) {
    return 'Video from $date';
  }

  @override
  String get settingsToolsSection => 'Tools';

  @override
  String get transferAddressTooltip =>
      'Your address on this Wi-Fi: other devices connect to it';

  @override
  String get designHeroTitle => 'What are we\ndownloading?';

  @override
  String get designPasteHint => 'Paste a YouTube, TikTok, Instagram, X… link';

  @override
  String get designDownload => 'Download';

  @override
  String get designClipboardFound => 'Link found in the clipboard';

  @override
  String designTodayCaption(String size) {
    return 'downloads · $size';
  }

  @override
  String get designInProgress => 'In progress';

  @override
  String get designPauseAll => 'Pause all';

  @override
  String get designResumeAll => 'Resume all';

  @override
  String designRemaining(String eta) {
    return '$eta left';
  }

  @override
  String get designQueue => 'Queue';

  @override
  String get designSeeAll => 'See all';

  @override
  String designStorageDrive(String drive) {
    return 'Storage · $drive';
  }

  @override
  String designFree(String size) {
    return '$size free';
  }

  @override
  String get designFilterAll => 'All';

  @override
  String get designFilterVideo => 'Video';

  @override
  String get designFilterAudio => 'Audio';

  @override
  String get designFilterImages => 'Images';

  @override
  String get designFailed => 'Failed';

  @override
  String get designNothingActive =>
      'Nothing is downloading. Paste a link to start.';

  @override
  String get designQueueEmpty => 'Nothing waiting';

  @override
  String get designLibraryEmpty => 'Your library is empty for now.';

  @override
  String get designArchivesTab => 'Archives';

  @override
  String get nocturneGreetingMorning => 'Good morning';

  @override
  String get nocturneGreetingAfternoon => 'Good afternoon';

  @override
  String get nocturneGreetingEvening => 'Good evening';

  @override
  String nocturneActiveTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads in progress',
      one: '1 download in progress',
      zero: 'No downloads in progress',
    );
    return '$_temp0';
  }

  @override
  String get nocturneNext => 'Up next';

  @override
  String get nocturneRecent => 'Latest downloads';

  @override
  String nocturneSizeOf(String done, String total) {
    return '$done of $total';
  }

  @override
  String get nocturneStatsTitle => 'Your activity';

  @override
  String get nocturneStatDownloads => 'Downloads';

  @override
  String get nocturneStatVolume => 'Downloaded volume';

  @override
  String nocturneLastDays(int count) {
    return 'Last $count days';
  }

  @override
  String get nocturnePerDay => 'Downloads per day';

  @override
  String nocturneDaysShort(int count) {
    return '$count d';
  }

  @override
  String nocturneDaysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get nocturneToday => 'today';

  @override
  String get nocturneBySource => 'By source';

  @override
  String get nocturneByFormat => 'By format';
}
