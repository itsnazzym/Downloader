// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Modern Downloader';

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
  String get searchDownloads => 'Search downloads...';

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
  String get viewMode => 'View mode';

  @override
  String get viewList => 'List';

  @override
  String get viewDetailed => 'Detailed';

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
  String get pluginsEmptyHint =>
      'Plugins extend the functionality of Modern Downloader';

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
  String get torBypassDesc => 'Bypass geo-blocks via Tor (127.0.0.1:9050)';

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
  String get previewSetup => 'Show setup screen (temporary)';

  @override
  String get previewSetupDesc =>
      'Replay the full-screen tools check and install overlay';

  @override
  String get pluginsSectionTitle => 'Plugins';

  @override
  String get pluginsSectionHint =>
      'In-app modules such as Auto Rename and Smart Organizer.';

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
}
