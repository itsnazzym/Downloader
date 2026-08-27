import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Modern Downloader'**
  String get appTitle;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @plugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get plugins;

  /// No description provided for @newDownload.
  ///
  /// In en, this message translates to:
  /// **'New Download'**
  String get newDownload;

  /// No description provided for @pasteUrl.
  ///
  /// In en, this message translates to:
  /// **'Paste URL here'**
  String get pasteUrl;

  /// No description provided for @startDownload.
  ///
  /// In en, this message translates to:
  /// **'Start Download'**
  String get startDownload;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open File'**
  String get openFile;

  /// No description provided for @openFolder.
  ///
  /// In en, this message translates to:
  /// **'Open Folder'**
  String get openFolder;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get deselectAll;

  /// No description provided for @statusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get statusQueued;

  /// No description provided for @statusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get statusDownloading;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @statusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get statusCanceled;

  /// No description provided for @statusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get statusPaused;

  /// No description provided for @statusExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting'**
  String get statusExtracting;

  /// No description provided for @statusDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get statusDuplicate;

  /// No description provided for @sidebarAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get sidebarAll;

  /// No description provided for @sidebarActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get sidebarActive;

  /// No description provided for @sidebarCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get sidebarCompleted;

  /// No description provided for @sidebarFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get sidebarFailed;

  /// No description provided for @sidebarBySource.
  ///
  /// In en, this message translates to:
  /// **'By Source'**
  String get sidebarBySource;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get settingsOutput;

  /// No description provided for @settingsAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsAdvanced;

  /// No description provided for @settingsPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get settingsPerformance;

  /// No description provided for @settingsSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsSystem;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsPlugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get settingsPlugins;

  /// No description provided for @audioOnly.
  ///
  /// In en, this message translates to:
  /// **'Audio Only'**
  String get audioOnly;

  /// No description provided for @audioOnlyDesc.
  ///
  /// In en, this message translates to:
  /// **'Extract audio only (MP3) from videos'**
  String get audioOnlyDesc;

  /// No description provided for @autoStart.
  ///
  /// In en, this message translates to:
  /// **'Auto-Start'**
  String get autoStart;

  /// No description provided for @autoStartDesc.
  ///
  /// In en, this message translates to:
  /// **'Start downloads immediately when added'**
  String get autoStartDesc;

  /// No description provided for @preferredQuality.
  ///
  /// In en, this message translates to:
  /// **'Preferred Quality'**
  String get preferredQuality;

  /// No description provided for @maxConcurrent.
  ///
  /// In en, this message translates to:
  /// **'Max Concurrent Downloads'**
  String get maxConcurrent;

  /// No description provided for @outputFolder.
  ///
  /// In en, this message translates to:
  /// **'Output Folder'**
  String get outputFolder;

  /// No description provided for @chooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose Folder'**
  String get chooseFolder;

  /// No description provided for @useCookies.
  ///
  /// In en, this message translates to:
  /// **'Use Browser Cookies'**
  String get useCookies;

  /// No description provided for @useCookiesDesc.
  ///
  /// In en, this message translates to:
  /// **'Use cookies from your browser for authentication'**
  String get useCookiesDesc;

  /// No description provided for @useProxy.
  ///
  /// In en, this message translates to:
  /// **'Use Proxy'**
  String get useProxy;

  /// No description provided for @useProxyDesc.
  ///
  /// In en, this message translates to:
  /// **'Route downloads through a proxy server'**
  String get useProxyDesc;

  /// No description provided for @minimizeToTray.
  ///
  /// In en, this message translates to:
  /// **'Minimize to Tray'**
  String get minimizeToTray;

  /// No description provided for @minimizeToTrayDesc.
  ///
  /// In en, this message translates to:
  /// **'Minimize to system tray instead of closing'**
  String get minimizeToTrayDesc;

  /// No description provided for @autoStartApp.
  ///
  /// In en, this message translates to:
  /// **'Start with Windows'**
  String get autoStartApp;

  /// No description provided for @autoStartAppDesc.
  ///
  /// In en, this message translates to:
  /// **'Launch app on system startup'**
  String get autoStartAppDesc;

  /// No description provided for @autoUpdateYtDlp.
  ///
  /// In en, this message translates to:
  /// **'Auto-update yt-dlp'**
  String get autoUpdateYtDlp;

  /// No description provided for @autoUpdateYtDlpDesc.
  ///
  /// In en, this message translates to:
  /// **'Check for yt-dlp updates on startup'**
  String get autoUpdateYtDlpDesc;

  /// No description provided for @showNotifications.
  ///
  /// In en, this message translates to:
  /// **'Show Notifications'**
  String get showNotifications;

  /// No description provided for @showNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Desktop notifications for downloads'**
  String get showNotificationsDesc;

  /// No description provided for @clipboardMonitor.
  ///
  /// In en, this message translates to:
  /// **'Clipboard Monitor'**
  String get clipboardMonitor;

  /// No description provided for @clipboardMonitorDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect URLs from clipboard'**
  String get clipboardMonitorDesc;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language'**
  String get languageDesc;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose application theme'**
  String get themeDesc;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get accentColor;

  /// No description provided for @accentColorDesc.
  ///
  /// In en, this message translates to:
  /// **'Customize the accent color'**
  String get accentColorDesc;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @systemMode.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemMode;

  /// No description provided for @totalDownloads.
  ///
  /// In en, this message translates to:
  /// **'Total Downloads'**
  String get totalDownloads;

  /// No description provided for @downloadsToday.
  ///
  /// In en, this message translates to:
  /// **'Downloads Today'**
  String get downloadsToday;

  /// No description provided for @totalData.
  ///
  /// In en, this message translates to:
  /// **'Total Data'**
  String get totalData;

  /// No description provided for @freeSpace.
  ///
  /// In en, this message translates to:
  /// **'Free Space'**
  String get freeSpace;

  /// No description provided for @last7Days.
  ///
  /// In en, this message translates to:
  /// **'Activity (Last 7 Days)'**
  String get last7Days;

  /// No description provided for @sourceDistribution.
  ///
  /// In en, this message translates to:
  /// **'Source Distribution'**
  String get sourceDistribution;

  /// No description provided for @keyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get keyboardShortcuts;

  /// No description provided for @newDownloadShortcut.
  ///
  /// In en, this message translates to:
  /// **'New Download'**
  String get newDownloadShortcut;

  /// No description provided for @settingsShortcut.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get settingsShortcut;

  /// No description provided for @dashboardShortcut.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardShortcut;

  /// No description provided for @minimizeShortcut.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimizeShortcut;

  /// No description provided for @inspector.
  ///
  /// In en, this message translates to:
  /// **'Inspector'**
  String get inspector;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @selectDownload.
  ///
  /// In en, this message translates to:
  /// **'Select a download'**
  String get selectDownload;

  /// No description provided for @checkDependencies.
  ///
  /// In en, this message translates to:
  /// **'Check Dependencies'**
  String get checkDependencies;

  /// No description provided for @checkDependenciesDesc.
  ///
  /// In en, this message translates to:
  /// **'Check yt-dlp, ffmpeg & aria2c status'**
  String get checkDependenciesDesc;

  /// No description provided for @verifyingBinaries.
  ///
  /// In en, this message translates to:
  /// **'Verifying binaries...'**
  String get verifyingBinaries;

  /// No description provided for @dependenciesVerified.
  ///
  /// In en, this message translates to:
  /// **'Dependencies verified'**
  String get dependenciesVerified;

  /// No description provided for @organizeLibrary.
  ///
  /// In en, this message translates to:
  /// **'Organize Library'**
  String get organizeLibrary;

  /// No description provided for @organizeLibraryDesc.
  ///
  /// In en, this message translates to:
  /// **'Sort files by source, move thumbnails, cleanup temp files'**
  String get organizeLibraryDesc;

  /// No description provided for @organizationComplete.
  ///
  /// In en, this message translates to:
  /// **'Organization Complete'**
  String get organizationComplete;

  /// No description provided for @filesMoved.
  ///
  /// In en, this message translates to:
  /// **'Files moved: {count}'**
  String filesMoved(int count);

  /// No description provided for @filesDeleted.
  ///
  /// In en, this message translates to:
  /// **'Temp files deleted: {count}'**
  String filesDeleted(int count);

  /// No description provided for @noPluginsInstalled.
  ///
  /// In en, this message translates to:
  /// **'No plugins installed'**
  String get noPluginsInstalled;

  /// No description provided for @pluginEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get pluginEnabled;

  /// No description provided for @pluginDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get pluginDisabled;

  /// No description provided for @builtIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get builtIn;

  /// No description provided for @mediaPlayer.
  ///
  /// In en, this message translates to:
  /// **'Media Player'**
  String get mediaPlayer;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback Speed'**
  String get playbackSpeed;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @librarySection.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get librarySection;

  /// No description provided for @sourcesSection.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sourcesSection;

  /// No description provided for @mainPage.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get mainPage;

  /// No description provided for @allDownloads.
  ///
  /// In en, this message translates to:
  /// **'All downloads'**
  String get allDownloads;

  /// No description provided for @downloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Download started'**
  String get downloadStarted;

  /// No description provided for @videosDownloadingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} videos downloading'**
  String videosDownloadingCount(int count);

  /// No description provided for @videoDownloadingSingular.
  ///
  /// In en, this message translates to:
  /// **'1 video downloading'**
  String get videoDownloadingSingular;

  /// No description provided for @expandDownloadingVideos.
  ///
  /// In en, this message translates to:
  /// **'Show downloading videos'**
  String get expandDownloadingVideos;

  /// No description provided for @collapseDownloadingVideos.
  ///
  /// In en, this message translates to:
  /// **'Hide downloading videos'**
  String get collapseDownloadingVideos;

  /// No description provided for @moreDownloadingVideos.
  ///
  /// In en, this message translates to:
  /// **'+{count}'**
  String moreDownloadingVideos(int count);

  /// No description provided for @searchDownloads.
  ///
  /// In en, this message translates to:
  /// **'Search downloads...'**
  String get searchDownloads;

  /// No description provided for @clearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove all completed, failed, and canceled downloads? Active downloads will remain.'**
  String get clearHistoryConfirm;

  /// No description provided for @refreshLibrary.
  ///
  /// In en, this message translates to:
  /// **'Refresh library'**
  String get refreshLibrary;

  /// No description provided for @yourListIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your download list is empty.'**
  String get yourListIsEmpty;

  /// No description provided for @sortAndView.
  ///
  /// In en, this message translates to:
  /// **'Sort & View'**
  String get sortAndView;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @sortDateNewest.
  ///
  /// In en, this message translates to:
  /// **'Date (newest)'**
  String get sortDateNewest;

  /// No description provided for @sortDateOldest.
  ///
  /// In en, this message translates to:
  /// **'Date (oldest)'**
  String get sortDateOldest;

  /// No description provided for @sortNameAsc.
  ///
  /// In en, this message translates to:
  /// **'Name (A-Z)'**
  String get sortNameAsc;

  /// No description provided for @sortSizeLargest.
  ///
  /// In en, this message translates to:
  /// **'Size (largest)'**
  String get sortSizeLargest;

  /// No description provided for @viewMode.
  ///
  /// In en, this message translates to:
  /// **'View mode'**
  String get viewMode;

  /// No description provided for @viewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get viewList;

  /// No description provided for @viewDetailed.
  ///
  /// In en, this message translates to:
  /// **'Detailed'**
  String get viewDetailed;

  /// No description provided for @playlistDetected.
  ///
  /// In en, this message translates to:
  /// **'Playlist detected ({count} videos)'**
  String playlistDetected(int count);

  /// No description provided for @downloadSelected.
  ///
  /// In en, this message translates to:
  /// **'Download selected ({count})'**
  String downloadSelected(int count);

  /// No description provided for @startedCountDownloads.
  ///
  /// In en, this message translates to:
  /// **'Started {count} downloads'**
  String startedCountDownloads(int count);

  /// No description provided for @downloadFolder.
  ///
  /// In en, this message translates to:
  /// **'Download folder'**
  String get downloadFolder;

  /// No description provided for @selectFolder.
  ///
  /// In en, this message translates to:
  /// **'Select folder...'**
  String get selectFolder;

  /// No description provided for @organizeBySite.
  ///
  /// In en, this message translates to:
  /// **'Organize by site'**
  String get organizeBySite;

  /// No description provided for @organizeBySiteDesc.
  ///
  /// In en, this message translates to:
  /// **'Create subfolders like Downloads/YouTube/'**
  String get organizeBySiteDesc;

  /// No description provided for @formatLabel.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get formatLabel;

  /// No description provided for @adultSites.
  ///
  /// In en, this message translates to:
  /// **'Adult sites'**
  String get adultSites;

  /// No description provided for @adultSitesDesc.
  ///
  /// In en, this message translates to:
  /// **'Enable support for age-restricted content'**
  String get adultSitesDesc;

  /// No description provided for @doNotDisturb.
  ///
  /// In en, this message translates to:
  /// **'Do not disturb'**
  String get doNotDisturb;

  /// No description provided for @doNotDisturbDesc.
  ///
  /// In en, this message translates to:
  /// **'Silence all app and extension notifications'**
  String get doNotDisturbDesc;

  /// No description provided for @cookiesFromBrowser.
  ///
  /// In en, this message translates to:
  /// **'Cookies from browser'**
  String get cookiesFromBrowser;

  /// No description provided for @extensionApiToken.
  ///
  /// In en, this message translates to:
  /// **'Extension API token'**
  String get extensionApiToken;

  /// No description provided for @localServerPort.
  ///
  /// In en, this message translates to:
  /// **'Local server port'**
  String get localServerPort;

  /// No description provided for @backupHistory.
  ///
  /// In en, this message translates to:
  /// **'Backup history'**
  String get backupHistory;

  /// No description provided for @restoreHistory.
  ///
  /// In en, this message translates to:
  /// **'Restore history'**
  String get restoreHistory;

  /// No description provided for @restoreHistoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Import downloads from a backup file'**
  String get restoreHistoryDesc;

  /// No description provided for @cookiesFile.
  ///
  /// In en, this message translates to:
  /// **'Cookies file'**
  String get cookiesFile;

  /// No description provided for @simultaneousDownloads.
  ///
  /// In en, this message translates to:
  /// **'Simultaneous downloads'**
  String get simultaneousDownloads;

  /// No description provided for @simultaneousDownloadsDesc.
  ///
  /// In en, this message translates to:
  /// **'Max active downloads at once'**
  String get simultaneousDownloadsDesc;

  /// No description provided for @threadsPerDownload.
  ///
  /// In en, this message translates to:
  /// **'Threads per download'**
  String get threadsPerDownload;

  /// No description provided for @threadsPerDownloadDesc.
  ///
  /// In en, this message translates to:
  /// **'Parallel connections (fragments) per file'**
  String get threadsPerDownloadDesc;

  /// No description provided for @maxSpeedMode.
  ///
  /// In en, this message translates to:
  /// **'Max speed mode'**
  String get maxSpeedMode;

  /// No description provided for @maxSpeedModeDesc.
  ///
  /// In en, this message translates to:
  /// **'64 parallel connections, larger buffers, fast remux (no re-encode)'**
  String get maxSpeedModeDesc;

  /// No description provided for @libraryManagement.
  ///
  /// In en, this message translates to:
  /// **'Library management'**
  String get libraryManagement;

  /// No description provided for @smartOrganization.
  ///
  /// In en, this message translates to:
  /// **'Smart organization'**
  String get smartOrganization;

  /// No description provided for @smartOrganizationDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage auto-sort rules and smart guessing'**
  String get smartOrganizationDesc;

  /// No description provided for @outputFolderNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Output folder not configured'**
  String get outputFolderNotConfigured;

  /// No description provided for @pluginsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Plugins extend the functionality of Modern Downloader'**
  String get pluginsEmptyHint;

  /// No description provided for @statusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get statusProcessing;

  /// No description provided for @statsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track your download activity and storage usage'**
  String get statsSubtitle;

  /// No description provided for @statsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get statsToday;

  /// No description provided for @downloadActivity.
  ///
  /// In en, this message translates to:
  /// **'Download Activity'**
  String get downloadActivity;

  /// No description provided for @last7DaysShort.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get last7DaysShort;

  /// No description provided for @sourcesChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sourcesChartTitle;

  /// No description provided for @sourcesByPlatform.
  ///
  /// In en, this message translates to:
  /// **'By platform'**
  String get sourcesByPlatform;

  /// No description provided for @shortcutsQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get shortcutsQuickActions;

  /// No description provided for @noDownloadHistory.
  ///
  /// In en, this message translates to:
  /// **'No download history yet'**
  String get noDownloadHistory;

  /// No description provided for @noSourceData.
  ///
  /// In en, this message translates to:
  /// **'No source data yet'**
  String get noSourceData;

  /// No description provided for @chartDownloadsTooltip.
  ///
  /// In en, this message translates to:
  /// **'{count} downloads\n{bytes}'**
  String chartDownloadsTooltip(int count, String bytes);

  /// No description provided for @currentAccent.
  ///
  /// In en, this message translates to:
  /// **'Current Accent'**
  String get currentAccent;

  /// No description provided for @dataAndHistory.
  ///
  /// In en, this message translates to:
  /// **'Data & History'**
  String get dataAndHistory;

  /// No description provided for @exportHistoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Export your download history to a JSON file'**
  String get exportHistoryDesc;

  /// No description provided for @saveHistoryBackup.
  ///
  /// In en, this message translates to:
  /// **'Save History Backup'**
  String get saveHistoryBackup;

  /// No description provided for @tokenCopied.
  ///
  /// In en, this message translates to:
  /// **'Token copied'**
  String get tokenCopied;

  /// No description provided for @tokenCopiedHint.
  ///
  /// In en, this message translates to:
  /// **'Token copied. Paste it in the browser extension.'**
  String get tokenCopiedHint;

  /// No description provided for @copyToken.
  ///
  /// In en, this message translates to:
  /// **'Copy token'**
  String get copyToken;

  /// No description provided for @portSavedRestart.
  ///
  /// In en, this message translates to:
  /// **'Port saved. Restart the app to apply.'**
  String get portSavedRestart;

  /// No description provided for @historyExported.
  ///
  /// In en, this message translates to:
  /// **'History exported successfully'**
  String get historyExported;

  /// No description provided for @historyRestored.
  ///
  /// In en, this message translates to:
  /// **'History restored successfully'**
  String get historyRestored;

  /// No description provided for @generatedOnFirstLaunch.
  ///
  /// In en, this message translates to:
  /// **'Generated on first launch'**
  String get generatedOnFirstLaunch;

  /// No description provided for @serverPortRestartHint.
  ///
  /// In en, this message translates to:
  /// **'Restart the app after changing. Current: {port}'**
  String serverPortRestartHint(int port);

  /// No description provided for @torBypassDesc.
  ///
  /// In en, this message translates to:
  /// **'Bypass geo-blocks via Tor (127.0.0.1:9050)'**
  String get torBypassDesc;

  /// No description provided for @selectCookiesFile.
  ///
  /// In en, this message translates to:
  /// **'Select cookies.txt'**
  String get selectCookiesFile;

  /// No description provided for @clearCookies.
  ///
  /// In en, this message translates to:
  /// **'Clear cookies'**
  String get clearCookies;

  /// No description provided for @selectQuality.
  ///
  /// In en, this message translates to:
  /// **'Select Quality'**
  String get selectQuality;

  /// No description provided for @unknownSize.
  ///
  /// In en, this message translates to:
  /// **'Unknown size'**
  String get unknownSize;

  /// No description provided for @bestQuality.
  ///
  /// In en, this message translates to:
  /// **'Best Quality'**
  String get bestQuality;

  /// No description provided for @noLogsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No logs available'**
  String get noLogsAvailable;

  /// No description provided for @dropLinksHere.
  ///
  /// In en, this message translates to:
  /// **'Drop links or files here'**
  String get dropLinksHere;

  /// No description provided for @dropLinksHint.
  ///
  /// In en, this message translates to:
  /// **'They will be added to your download queue'**
  String get dropLinksHint;

  /// No description provided for @retryDownload.
  ///
  /// In en, this message translates to:
  /// **'Retry Download'**
  String get retryDownload;

  /// No description provided for @restartDownload.
  ///
  /// In en, this message translates to:
  /// **'Restart download'**
  String get restartDownload;

  /// No description provided for @copyUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get copyUrl;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @urlLabel.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get urlLabel;

  /// No description provided for @pleaseEnterUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a URL'**
  String get pleaseEnterUrl;

  /// No description provided for @enterValidUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid http(s) URL'**
  String get enterValidUrl;

  /// No description provided for @cookiesNoneDefault.
  ///
  /// In en, this message translates to:
  /// **'None (Default)'**
  String get cookiesNoneDefault;

  /// No description provided for @failedFetchQuality.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch quality options'**
  String get failedFetchQuality;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @inspectorId.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get inspectorId;

  /// No description provided for @storageUsage.
  ///
  /// In en, this message translates to:
  /// **'Storage Usage'**
  String get storageUsage;

  /// No description provided for @storageInfoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Storage info unavailable'**
  String get storageInfoUnavailable;

  /// No description provided for @storageUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get storageUsed;

  /// No description provided for @storageFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get storageFree;

  /// No description provided for @storageTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total: {size}'**
  String storageTotalLabel(String size);

  /// No description provided for @startingOrganization.
  ///
  /// In en, this message translates to:
  /// **'Starting organization...'**
  String get startingOrganization;

  /// No description provided for @organizationFailed.
  ///
  /// In en, this message translates to:
  /// **'Organization failed: {error}'**
  String organizationFailed(String error);

  /// No description provided for @thumbnailsOrganized.
  ///
  /// In en, this message translates to:
  /// **'Thumbnails organized: {count}'**
  String thumbnailsOrganized(int count);

  /// No description provided for @foldersCreated.
  ///
  /// In en, this message translates to:
  /// **'Folders created: {count}'**
  String foldersCreated(int count);

  /// No description provided for @emptyFoldersDeleted.
  ///
  /// In en, this message translates to:
  /// **'Empty folders deleted: {count}'**
  String emptyFoldersDeleted(int count);

  /// No description provided for @organizationErrors.
  ///
  /// In en, this message translates to:
  /// **'{count} errors occurred'**
  String organizationErrors(int count);

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @editRule.
  ///
  /// In en, this message translates to:
  /// **'Edit Rule'**
  String get editRule;

  /// No description provided for @newRule.
  ///
  /// In en, this message translates to:
  /// **'New Rule'**
  String get newRule;

  /// No description provided for @patternKeywordOrRegex.
  ///
  /// In en, this message translates to:
  /// **'Pattern (Keyword or Regex)'**
  String get patternKeywordOrRegex;

  /// No description provided for @regexpPattern.
  ///
  /// In en, this message translates to:
  /// **'RegExp pattern'**
  String get regexpPattern;

  /// No description provided for @containsText.
  ///
  /// In en, this message translates to:
  /// **'Contains text'**
  String get containsText;

  /// No description provided for @isRegex.
  ///
  /// In en, this message translates to:
  /// **'Is Regex'**
  String get isRegex;

  /// No description provided for @targetSubfolder.
  ///
  /// In en, this message translates to:
  /// **'Target Subfolder'**
  String get targetSubfolder;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @downloadModel.
  ///
  /// In en, this message translates to:
  /// **'Download Model'**
  String get downloadModel;

  /// No description provided for @selectPopularModel.
  ///
  /// In en, this message translates to:
  /// **'Select a popular model to pull:'**
  String get selectPopularModel;

  /// No description provided for @ollamaPullNote.
  ///
  /// In en, this message translates to:
  /// **'Note: This requires a fast internet connection. Check Ollama logs for progress.'**
  String get ollamaPullNote;

  /// No description provided for @smartGuessTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Guess (AI Curator)'**
  String get smartGuessTitle;

  /// No description provided for @smartGuessDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically categorize files based on common patterns or Local AI.'**
  String get smartGuessDesc;

  /// No description provided for @aiMode.
  ///
  /// In en, this message translates to:
  /// **'AI Mode'**
  String get aiMode;

  /// No description provided for @aiModeOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline (Heuristic - Fast)'**
  String get aiModeOffline;

  /// No description provided for @aiModeOllama.
  ///
  /// In en, this message translates to:
  /// **'Ollama / LocalAI'**
  String get aiModeOllama;

  /// No description provided for @ollamaApiUrl.
  ///
  /// In en, this message translates to:
  /// **'Ollama API URL'**
  String get ollamaApiUrl;

  /// No description provided for @modelName.
  ///
  /// In en, this message translates to:
  /// **'Model Name'**
  String get modelName;

  /// No description provided for @selectOrTypeModel.
  ///
  /// In en, this message translates to:
  /// **'Select from list or type manually'**
  String get selectOrTypeModel;

  /// No description provided for @refreshModels.
  ///
  /// In en, this message translates to:
  /// **'Refresh Models'**
  String get refreshModels;

  /// No description provided for @customRules.
  ///
  /// In en, this message translates to:
  /// **'Custom Rules'**
  String get customRules;

  /// No description provided for @addRule.
  ///
  /// In en, this message translates to:
  /// **'Add Rule'**
  String get addRule;

  /// No description provided for @noRulesDefined.
  ///
  /// In en, this message translates to:
  /// **'No rules defined. Add one using the + button.'**
  String get noRulesDefined;

  /// No description provided for @organizeExistingFiles.
  ///
  /// In en, this message translates to:
  /// **'Organize Existing Files'**
  String get organizeExistingFiles;

  /// No description provided for @organizeExistingFilesDesc.
  ///
  /// In en, this message translates to:
  /// **'Scan a folder and organize files using current rules/AI.'**
  String get organizeExistingFilesDesc;

  /// No description provided for @ollamaMustRun.
  ///
  /// In en, this message translates to:
  /// **'Make sure Ollama is running (`ollama serve`).'**
  String get ollamaMustRun;

  /// No description provided for @requestingOllamaPull.
  ///
  /// In en, this message translates to:
  /// **'Requesting Ollama to pull {model}... This may take a while.'**
  String requestingOllamaPull(String model);

  /// No description provided for @organizationCompleteDetail.
  ///
  /// In en, this message translates to:
  /// **'Organization complete. Scanned {scanned} files, moved {moved}.'**
  String organizationCompleteDetail(int scanned, int moved);

  /// No description provided for @toolsSection.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get toolsSection;

  /// No description provided for @configurePlugin.
  ///
  /// In en, this message translates to:
  /// **'Configure Plugin'**
  String get configurePlugin;

  /// No description provided for @pluginError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String pluginError(String error);

  /// No description provided for @setupPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing download tools…'**
  String get setupPreparing;

  /// No description provided for @setupCheckingTools.
  ///
  /// In en, this message translates to:
  /// **'Checking installed tools'**
  String get setupCheckingTools;

  /// No description provided for @setupDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading {name}…'**
  String setupDownloading(String name);

  /// No description provided for @setupExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting {name}…'**
  String setupExtracting(String name);

  /// No description provided for @setupVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying {name}…'**
  String setupVerifying(String name);

  /// No description provided for @setupUpdatingYtDlp.
  ///
  /// In en, this message translates to:
  /// **'Updating yt-dlp…'**
  String get setupUpdatingYtDlp;

  /// No description provided for @setupReady.
  ///
  /// In en, this message translates to:
  /// **'All tools are ready'**
  String get setupReady;

  /// No description provided for @setupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not install every tool'**
  String get setupFailed;

  /// No description provided for @setupRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get setupRetry;

  /// No description provided for @setupContinueAnyway.
  ///
  /// In en, this message translates to:
  /// **'Continue anyway'**
  String get setupContinueAnyway;

  /// No description provided for @setupDownloadPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String setupDownloadPercent(int percent);

  /// No description provided for @previewSetup.
  ///
  /// In en, this message translates to:
  /// **'Show setup screen (temporary)'**
  String get previewSetup;

  /// No description provided for @previewSetupDesc.
  ///
  /// In en, this message translates to:
  /// **'Replay the full-screen tools check and install overlay'**
  String get previewSetupDesc;

  /// No description provided for @pluginsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get pluginsSectionTitle;

  /// No description provided for @pluginsSectionHint.
  ///
  /// In en, this message translates to:
  /// **'In-app modules such as Auto Rename and Smart Organizer.'**
  String get pluginsSectionHint;

  /// No description provided for @browserExtensionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Browser extension'**
  String get browserExtensionsTitle;

  /// No description provided for @browserExtensionsHint.
  ///
  /// In en, this message translates to:
  /// **'Send links from the browser to the app. One click prepares the extension and opens the browser page.'**
  String get browserExtensionsHint;

  /// No description provided for @chromeExtensionTitle.
  ///
  /// In en, this message translates to:
  /// **'Chrome / Edge / Brave'**
  String get chromeExtensionTitle;

  /// No description provided for @chromeExtensionSteps.
  ///
  /// In en, this message translates to:
  /// **'1. Click Install. 2. Turn on Developer mode. 3. Load unpacked, then Ctrl+V to paste the path.'**
  String get chromeExtensionSteps;

  /// No description provided for @firefoxExtensionTitle.
  ///
  /// In en, this message translates to:
  /// **'Firefox'**
  String get firefoxExtensionTitle;

  /// No description provided for @firefoxExtensionSteps.
  ///
  /// In en, this message translates to:
  /// **'Install opens the signed XPI from GitHub. If Firefox blocks it, use Manual install (about:debugging).'**
  String get firefoxExtensionSteps;

  /// No description provided for @installInChrome.
  ///
  /// In en, this message translates to:
  /// **'Install in Chrome'**
  String get installInChrome;

  /// No description provided for @installInFirefox.
  ///
  /// In en, this message translates to:
  /// **'Install in Firefox'**
  String get installInFirefox;

  /// No description provided for @downloadExtensionZip.
  ///
  /// In en, this message translates to:
  /// **'Download ZIP'**
  String get downloadExtensionZip;

  /// No description provided for @firefoxManualInstall.
  ///
  /// In en, this message translates to:
  /// **'Manual install'**
  String get firefoxManualInstall;

  /// No description provided for @extensionDownloading.
  ///
  /// In en, this message translates to:
  /// **'Preparing extension…'**
  String get extensionDownloading;

  /// No description provided for @extensionDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Check your connection and try again.'**
  String get extensionDownloadFailed;

  /// No description provided for @extensionInstallGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Extension installation'**
  String get extensionInstallGuideTitle;

  /// No description provided for @extensionInstallInProgress.
  ///
  /// In en, this message translates to:
  /// **'Do not close this window until the download finishes.'**
  String get extensionInstallInProgress;

  /// No description provided for @extensionInstallClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get extensionInstallClose;

  /// No description provided for @extensionInstallRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get extensionInstallRetry;

  /// No description provided for @extensionStepDownload.
  ///
  /// In en, this message translates to:
  /// **'Download extension files'**
  String get extensionStepDownload;

  /// No description provided for @extensionStepDownloadZip.
  ///
  /// In en, this message translates to:
  /// **'Download ZIP to Downloads'**
  String get extensionStepDownloadZip;

  /// No description provided for @extensionStepCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy install path to clipboard'**
  String get extensionStepCopyPath;

  /// No description provided for @extensionStepOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open browser install page'**
  String get extensionStepOpenBrowser;

  /// No description provided for @extensionStepLaunchFirefox.
  ///
  /// In en, this message translates to:
  /// **'Launch Firefox installer'**
  String get extensionStepLaunchFirefox;

  /// No description provided for @extensionStepReadyChrome.
  ///
  /// In en, this message translates to:
  /// **'Ready! One-time setup: in Chrome turn on Developer mode, click Load unpacked, then Ctrl+V to paste the path.'**
  String get extensionStepReadyChrome;

  /// No description provided for @extensionStepReadyZip.
  ///
  /// In en, this message translates to:
  /// **'ZIP saved. Extract it if needed, or use Install in Chrome for automatic setup.'**
  String get extensionStepReadyZip;

  /// No description provided for @extensionStepReadyFirefox.
  ///
  /// In en, this message translates to:
  /// **'Ready! In about:debugging, click Load Temporary Add-on and select manifest.json (path already copied).'**
  String get extensionStepReadyFirefox;

  /// No description provided for @extensionStepReadyFirefoxXpi.
  ///
  /// In en, this message translates to:
  /// **'Ready! Confirm the add-on install prompt in Firefox; once accepted, it survives browser restarts. Then paste the API token in the extension popup.'**
  String get extensionStepReadyFirefoxXpi;

  /// No description provided for @extensionStepFirefoxFallback.
  ///
  /// In en, this message translates to:
  /// **'Could not open XPI directly — using manual install page.'**
  String get extensionStepFirefoxFallback;

  /// No description provided for @extensionStepSkippedBrowser.
  ///
  /// In en, this message translates to:
  /// **'Skipped — Firefox opened the installer directly.'**
  String get extensionStepSkippedBrowser;

  /// No description provided for @chromeInstallStarted.
  ///
  /// In en, this message translates to:
  /// **'Path copied. In Chrome: Developer mode → Load unpacked → Ctrl+V.'**
  String get chromeInstallStarted;

  /// No description provided for @firefoxInstallStarted.
  ///
  /// In en, this message translates to:
  /// **'Firefox will install the add-on. If blocked, use Manual install.'**
  String get firefoxInstallStarted;

  /// No description provided for @extensionPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied: {path}'**
  String extensionPathCopied(String path);

  /// No description provided for @extensionInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser. Try Download ZIP instead.'**
  String get extensionInstallFailed;

  /// No description provided for @extractingTitle.
  ///
  /// In en, this message translates to:
  /// **'Extracting title...'**
  String get extractingTitle;

  /// No description provided for @extractingSource.
  ///
  /// In en, this message translates to:
  /// **'Extracting source...'**
  String get extractingSource;

  /// No description provided for @extractingSize.
  ///
  /// In en, this message translates to:
  /// **'Extracting size...'**
  String get extractingSize;

  /// No description provided for @unknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Unknown title'**
  String get unknownTitle;

  /// No description provided for @collapseSidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get collapseSidebar;

  /// No description provided for @expandSidebar.
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar'**
  String get expandSidebar;

  /// No description provided for @collapseInspector.
  ///
  /// In en, this message translates to:
  /// **'Collapse inspector'**
  String get collapseInspector;

  /// No description provided for @expandInspector.
  ///
  /// In en, this message translates to:
  /// **'Expand inspector'**
  String get expandInspector;

  /// No description provided for @experimentalXFeedSection.
  ///
  /// In en, this message translates to:
  /// **'Experimental X Feed'**
  String get experimentalXFeedSection;

  /// No description provided for @experimentalXFeedGobird.
  ///
  /// In en, this message translates to:
  /// **'Use gobird (experimental)'**
  String get experimentalXFeedGobird;

  /// No description provided for @experimentalXFeedGobirdDesc.
  ///
  /// In en, this message translates to:
  /// **'Read-only home feed via bundled gobird. Off by default. Violates X Terms of Service and may risk account suspension.'**
  String get experimentalXFeedGobirdDesc;

  /// No description provided for @experimentalXFeedWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: gobird uses unofficial private X APIs. You accept all risk. Local DOM feed remains the default fallback.'**
  String get experimentalXFeedWarning;

  /// No description provided for @experimentalXFeedConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable experimental gobird?'**
  String get experimentalXFeedConsentTitle;

  /// No description provided for @experimentalXFeedConsentBody.
  ///
  /// In en, this message translates to:
  /// **'gobird uses unofficial X APIs, may break without notice, and can lead to account suspension or ban. Cookies stay on this PC. Continue only if you accept these risks.'**
  String get experimentalXFeedConsentBody;

  /// No description provided for @experimentalXFeedConsentConfirm.
  ///
  /// In en, this message translates to:
  /// **'I understand — enable'**
  String get experimentalXFeedConsentConfirm;

  /// No description provided for @gobirdBrowser.
  ///
  /// In en, this message translates to:
  /// **'gobird browser session'**
  String get gobirdBrowser;

  /// No description provided for @gobirdBrowserDesc.
  ///
  /// In en, this message translates to:
  /// **'Browser logged into X.com for cookie extraction (Chrome or Firefox)'**
  String get gobirdBrowserDesc;

  /// No description provided for @gobirdBinaryStatus.
  ///
  /// In en, this message translates to:
  /// **'gobird binary'**
  String get gobirdBinaryStatus;

  /// No description provided for @gobirdBinaryFound.
  ///
  /// In en, this message translates to:
  /// **'Found: {version}'**
  String gobirdBinaryFound(String version);

  /// No description provided for @gobirdBinaryMissing.
  ///
  /// In en, this message translates to:
  /// **'Not bundled — experimental engine unavailable'**
  String get gobirdBinaryMissing;

  /// No description provided for @gobirdDisableNow.
  ///
  /// In en, this message translates to:
  /// **'Disable gobird now'**
  String get gobirdDisableNow;

  /// No description provided for @playerPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get playerPrevious;

  /// No description provided for @playerNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get playerNext;

  /// No description provided for @duplicatesSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count} duplicates skipped'**
  String duplicatesSkipped(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
