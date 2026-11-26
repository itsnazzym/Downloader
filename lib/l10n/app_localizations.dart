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
  /// **'TapLoad'**
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

  /// No description provided for @xCdnUrlRejected.
  ///
  /// In en, this message translates to:
  /// **'Paste the tweet link (x.com/.../status/...), not the video file.'**
  String get xCdnUrlRejected;

  /// No description provided for @unsupportedDownloadUrl.
  ///
  /// In en, this message translates to:
  /// **'This page is not a downloadable video (invite or unsupported site).'**
  String get unsupportedDownloadUrl;

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
  /// **'Filter titles or URLs'**
  String get searchDownloads;

  /// No description provided for @searchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get searchClear;

  /// No description provided for @searchMatchCount.
  ///
  /// In en, this message translates to:
  /// **'{visible} / {total}'**
  String searchMatchCount(int visible, int total);

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

  /// No description provided for @sortVideoCount.
  ///
  /// In en, this message translates to:
  /// **'Video count'**
  String get sortVideoCount;

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

  /// No description provided for @viewFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get viewFolders;

  /// No description provided for @folderUnknownCreator.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get folderUnknownCreator;

  /// No description provided for @folderBack.
  ///
  /// In en, this message translates to:
  /// **'Back to folders'**
  String get folderBack;

  /// No description provided for @folderOpenHint.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get folderOpenHint;

  /// No description provided for @folderVideoCount.
  ///
  /// In en, this message translates to:
  /// **'{count} videos'**
  String folderVideoCount(int count);

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

  /// No description provided for @organizeByCreator.
  ///
  /// In en, this message translates to:
  /// **'Organize by creator'**
  String get organizeByCreator;

  /// No description provided for @organizeByCreatorDesc.
  ///
  /// In en, this message translates to:
  /// **'Create subfolders per account (e.g. TikTok/userxxx/, YouTube/channel/)'**
  String get organizeByCreatorDesc;

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
  /// **'Plugins extend the functionality of TapLoad'**
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
  /// **'Start Tor in the background and route downloads through it (127.0.0.1:9050)'**
  String get torBypassDesc;

  /// No description provided for @torProxyStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting Tor…'**
  String get torProxyStarting;

  /// No description provided for @torProxyReady.
  ///
  /// In en, this message translates to:
  /// **'Tor is ready at 127.0.0.1:9050'**
  String get torProxyReady;

  /// No description provided for @torProxyExisting.
  ///
  /// In en, this message translates to:
  /// **'A Tor proxy is already running at 127.0.0.1:9050'**
  String get torProxyExisting;

  /// No description provided for @torProxyStopped.
  ///
  /// In en, this message translates to:
  /// **'Tor is stopped'**
  String get torProxyStopped;

  /// No description provided for @torProxyFailed.
  ///
  /// In en, this message translates to:
  /// **'Tor is unavailable'**
  String get torProxyFailed;

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

  /// No description provided for @storageFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get storageFolder;

  /// No description provided for @storageOtherUsed.
  ///
  /// In en, this message translates to:
  /// **'Other used'**
  String get storageOtherUsed;

  /// No description provided for @storageFolderOfUsed.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of used'**
  String storageFolderOfUsed(String percent);

  /// No description provided for @storageFileCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 files} =1{1 file} other{{count} files}}'**
  String storageFileCount(int count);

  /// No description provided for @storageTypeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get storageTypeVideo;

  /// No description provided for @storageTypeAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get storageTypeAudio;

  /// No description provided for @storageTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get storageTypeOther;

  /// No description provided for @storageTopSubfolders.
  ///
  /// In en, this message translates to:
  /// **'Largest folders'**
  String get storageTopSubfolders;

  /// No description provided for @storageScanInProgress.
  ///
  /// In en, this message translates to:
  /// **'Scanning folder...'**
  String get storageScanInProgress;

  /// No description provided for @storageLastScanned.
  ///
  /// In en, this message translates to:
  /// **'Scanned at {time}'**
  String storageLastScanned(String time);

  /// No description provided for @storageScanCached.
  ///
  /// In en, this message translates to:
  /// **'Cached'**
  String get storageScanCached;

  /// No description provided for @storageScanError.
  ///
  /// In en, this message translates to:
  /// **'Could not read this folder'**
  String get storageScanError;

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
  /// **'Check and repair the download tools'**
  String get previewSetup;

  /// No description provided for @previewSetupDesc.
  ///
  /// In en, this message translates to:
  /// **'Re-checks yt-dlp, ffmpeg and aria2c and reinstalls what is missing'**
  String get previewSetupDesc;

  /// No description provided for @pluginsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Download workflow plugins'**
  String get pluginsSectionTitle;

  /// No description provided for @pluginsSectionHint.
  ///
  /// In en, this message translates to:
  /// **'These plugins add actions before or after a download completes.'**
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

  /// No description provided for @trayShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get trayShow;

  /// No description provided for @trayExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get trayExit;

  /// No description provided for @needTweetLink.
  ///
  /// In en, this message translates to:
  /// **'Need tweet link'**
  String get needTweetLink;

  /// No description provided for @openFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Open fullscreen'**
  String get openFullscreen;

  /// No description provided for @previewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview unavailable'**
  String get previewUnavailable;

  /// No description provided for @sourceYouTube.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get sourceYouTube;

  /// No description provided for @sourceInstagram.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get sourceInstagram;

  /// No description provided for @sourceTwitter.
  ///
  /// In en, this message translates to:
  /// **'Twitter'**
  String get sourceTwitter;

  /// No description provided for @sourceTwitch.
  ///
  /// In en, this message translates to:
  /// **'Twitch'**
  String get sourceTwitch;

  /// No description provided for @sourceKick.
  ///
  /// In en, this message translates to:
  /// **'Kick'**
  String get sourceKick;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @qualityManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get qualityManual;

  /// No description provided for @qualityManualPlus.
  ///
  /// In en, this message translates to:
  /// **'Manual+'**
  String get qualityManualPlus;

  /// No description provided for @notificationDownloadCompleted.
  ///
  /// In en, this message translates to:
  /// **'Download Completed'**
  String get notificationDownloadCompleted;

  /// No description provided for @notificationDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download Failed'**
  String get notificationDownloadFailed;

  /// No description provided for @notificationLinkDetected.
  ///
  /// In en, this message translates to:
  /// **'Link Detected'**
  String get notificationLinkDetected;

  /// No description provided for @notificationLinkDetectedBody.
  ///
  /// In en, this message translates to:
  /// **'Click to download: {url}'**
  String notificationLinkDetectedBody(String url);

  /// No description provided for @notificationLinksQueuedTitle.
  ///
  /// In en, this message translates to:
  /// **'Links queued'**
  String get notificationLinksQueuedTitle;

  /// No description provided for @notificationLinksQueuedBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} link queued} other{{count} links queued}}'**
  String notificationLinksQueuedBody(int count);

  /// No description provided for @notificationExtensionConnected.
  ///
  /// In en, this message translates to:
  /// **'Extension Connected'**
  String get notificationExtensionConnected;

  /// No description provided for @notificationExtensionConnectedBody.
  ///
  /// In en, this message translates to:
  /// **'Browser extension successfully connected.'**
  String get notificationExtensionConnectedBody;

  /// No description provided for @notificationBatchComplete.
  ///
  /// In en, this message translates to:
  /// **'Batch Download Complete'**
  String get notificationBatchComplete;

  /// No description provided for @notificationBatchCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'{count} downloads finished — {totalSize} total'**
  String notificationBatchCompleteBody(int count, String totalSize);

  /// No description provided for @notificationYtDlpUpdated.
  ///
  /// In en, this message translates to:
  /// **'yt-dlp Updated'**
  String get notificationYtDlpUpdated;

  /// No description provided for @notificationYtDlpUpdatedBody.
  ///
  /// In en, this message translates to:
  /// **'Updated to {version}'**
  String notificationYtDlpUpdatedBody(String version);

  /// No description provided for @browseX.
  ///
  /// In en, this message translates to:
  /// **'Browse X'**
  String get browseX;

  /// No description provided for @browseXHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in if needed, then tap Download on any video.'**
  String get browseXHint;

  /// No description provided for @mobileLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get mobileLibrary;

  /// No description provided for @shareDownloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Download started from share'**
  String get shareDownloadStarted;

  /// No description provided for @transferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferTitle;

  /// No description provided for @transferSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Same Wi-Fi. Scan the QR or tap a device.'**
  String get transferSubtitle;

  /// No description provided for @transferPortBusy.
  ///
  /// In en, this message translates to:
  /// **'Port 53317 is taken. QR still works; LocalSend inbound on this PC may fail.'**
  String get transferPortBusy;

  /// No description provided for @transferMe.
  ///
  /// In en, this message translates to:
  /// **'This PC'**
  String get transferMe;

  /// No description provided for @transferDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get transferDevices;

  /// No description provided for @transferPayload.
  ///
  /// In en, this message translates to:
  /// **'What to send'**
  String get transferPayload;

  /// No description provided for @transferSearchCreator.
  ///
  /// In en, this message translates to:
  /// **'Search a creator…'**
  String get transferSearchCreator;

  /// No description provided for @transferEntireLibrary.
  ///
  /// In en, this message translates to:
  /// **'Entire library'**
  String get transferEntireLibrary;

  /// No description provided for @transferClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get transferClearSelection;

  /// No description provided for @transferSelectedFolders.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} folder} other{{count} folders}}'**
  String transferSelectedFolders(int count);

  /// No description provided for @transferNoCreatorMatch.
  ///
  /// In en, this message translates to:
  /// **'No creator matches'**
  String get transferNoCreatorMatch;

  /// No description provided for @transferNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No device yet — scan the QR on your phone.'**
  String get transferNoDevices;

  /// No description provided for @transferWaitingNetwork.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a LAN address…'**
  String get transferWaitingNetwork;

  /// No description provided for @transferKnown.
  ///
  /// In en, this message translates to:
  /// **'Known device'**
  String get transferKnown;

  /// No description provided for @transferSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get transferSend;

  /// No description provided for @transferOtherFolder.
  ///
  /// In en, this message translates to:
  /// **'Another folder…'**
  String get transferOtherFolder;

  /// No description provided for @transferSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get transferSending;

  /// No description provided for @transferPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing files…'**
  String get transferPreparing;

  /// No description provided for @transferCompressing.
  ///
  /// In en, this message translates to:
  /// **'Creating ZIP archive…'**
  String get transferCompressing;

  /// No description provided for @transferWaitingPeer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for LocalSend to accept…'**
  String get transferWaitingPeer;

  /// No description provided for @transferNeedPayload.
  ///
  /// In en, this message translates to:
  /// **'Pick a creator or Entire library first.'**
  String get transferNeedPayload;

  /// No description provided for @transferErrorHttp.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the phone. Same Wi-Fi, LocalSend Receive on, encryption on. If it asks for a PIN, enter it.'**
  String get transferErrorHttp;

  /// No description provided for @transferErrorBusy.
  ///
  /// In en, this message translates to:
  /// **'The phone is busy with another transfer.'**
  String get transferErrorBusy;

  /// No description provided for @transferErrorRejected.
  ///
  /// In en, this message translates to:
  /// **'The phone refused the transfer.'**
  String get transferErrorRejected;

  /// No description provided for @transferDone.
  ///
  /// In en, this message translates to:
  /// **'Sent.'**
  String get transferDone;

  /// No description provided for @transferIncomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Incoming transfer'**
  String get transferIncomingTitle;

  /// No description provided for @transferIncomingBody.
  ///
  /// In en, this message translates to:
  /// **'{alias} wants to send {count} files ({size})'**
  String transferIncomingBody(String alias, int count, String size);

  /// No description provided for @transferAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get transferAccept;

  /// No description provided for @transferReject.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get transferReject;

  /// No description provided for @transferPeerPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Device PIN'**
  String get transferPeerPinTitle;

  /// No description provided for @transferPeerPinHint.
  ///
  /// In en, this message translates to:
  /// **'PIN shown on the other device'**
  String get transferPeerPinHint;

  /// No description provided for @transferTabSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get transferTabSend;

  /// No description provided for @transferTabReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get transferTabReceive;

  /// No description provided for @transferDirectIpTitle.
  ///
  /// In en, this message translates to:
  /// **'Direct IP Connection'**
  String get transferDirectIpTitle;

  /// No description provided for @transferDirectIpHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. 192.168.1.122'**
  String get transferDirectIpHint;

  /// No description provided for @transferDirectIpAction.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get transferDirectIpAction;

  /// No description provided for @transferScanSubnet.
  ///
  /// In en, this message translates to:
  /// **'Scan network'**
  String get transferScanSubnet;

  /// No description provided for @transferScanningSubnet.
  ///
  /// In en, this message translates to:
  /// **'Scanning subnet…'**
  String get transferScanningSubnet;

  /// No description provided for @transferRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get transferRetry;

  /// No description provided for @transferCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get transferCancel;

  /// No description provided for @transferDirectBrowserUrl.
  ///
  /// In en, this message translates to:
  /// **'Web browser link'**
  String get transferDirectBrowserUrl;

  /// No description provided for @transferCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get transferCopyLink;

  /// No description provided for @transferCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied!'**
  String get transferCopied;

  /// No description provided for @transferListeningOn.
  ///
  /// In en, this message translates to:
  /// **'Listening on network'**
  String get transferListeningOn;

  /// No description provided for @transferVideosFound.
  ///
  /// In en, this message translates to:
  /// **'{count} found'**
  String transferVideosFound(int count);

  /// No description provided for @transferAlreadyTransferred.
  ///
  /// In en, this message translates to:
  /// **'{count} already transferred'**
  String transferAlreadyTransferred(int count);

  /// No description provided for @transferNewVideos.
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String transferNewVideos(int count);

  /// No description provided for @transferSendNewOnly.
  ///
  /// In en, this message translates to:
  /// **'Send {count} new videos'**
  String transferSendNewOnly(int count);

  /// No description provided for @transferSendAll.
  ///
  /// In en, this message translates to:
  /// **'Send all ({count})'**
  String transferSendAll(int count);

  /// No description provided for @transferOnlyNewToggle.
  ///
  /// In en, this message translates to:
  /// **'Send new videos only'**
  String get transferOnlyNewToggle;

  /// No description provided for @transferFolderBreakdown.
  ///
  /// In en, this message translates to:
  /// **'{newCount} new • {alreadyCount} transferred'**
  String transferFolderBreakdown(int newCount, int alreadyCount);

  /// No description provided for @transferForgetDeviceHistory.
  ///
  /// In en, this message translates to:
  /// **'Forget history for this device'**
  String get transferForgetDeviceHistory;

  /// No description provided for @transferHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'Transfer history cleared'**
  String get transferHistoryCleared;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get onboardingStart;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get onboardingDone;

  /// No description provided for @onboardingSkipStep.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkipStep;

  /// No description provided for @onboardingSkipAll.
  ///
  /// In en, this message translates to:
  /// **'Skip tour'**
  String get onboardingSkipAll;

  /// No description provided for @onboardingReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay tour'**
  String get onboardingReplay;

  /// No description provided for @onboardingReplayDesc.
  ///
  /// In en, this message translates to:
  /// **'Show the tour again'**
  String get onboardingReplayDesc;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick tour'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'A short walk through the main screens. Skip anytime.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingNewDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'New download'**
  String get onboardingNewDownloadTitle;

  /// No description provided for @onboardingNewDownloadBody.
  ///
  /// In en, this message translates to:
  /// **'Paste a URL or send one from the browser extension.'**
  String get onboardingNewDownloadBody;

  /// No description provided for @onboardingLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get onboardingLibraryTitle;

  /// No description provided for @onboardingLibraryBody.
  ///
  /// In en, this message translates to:
  /// **'Filter downloads by active, done, or failed.'**
  String get onboardingLibraryBody;

  /// No description provided for @onboardingTopBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Toolbar'**
  String get onboardingTopBarTitle;

  /// No description provided for @onboardingTopBarBody.
  ///
  /// In en, this message translates to:
  /// **'Search, pause the queue, and retry failed downloads.'**
  String get onboardingTopBarBody;

  /// No description provided for @onboardingFoldersTitle.
  ///
  /// In en, this message translates to:
  /// **'Creator folders'**
  String get onboardingFoldersTitle;

  /// No description provided for @onboardingFoldersBody.
  ///
  /// In en, this message translates to:
  /// **'Downloads are grouped by channel. Switch list or folders, then sort.'**
  String get onboardingFoldersBody;

  /// No description provided for @onboardingTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get onboardingTransferTitle;

  /// No description provided for @onboardingTransferBody.
  ///
  /// In en, this message translates to:
  /// **'Pick folders, scan the QR, then accept on the other device.'**
  String get onboardingTransferBody;

  /// No description provided for @onboardingStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get onboardingStatsTitle;

  /// No description provided for @onboardingStatsBody.
  ///
  /// In en, this message translates to:
  /// **'Totals, disk space, and download history.'**
  String get onboardingStatsBody;

  /// No description provided for @onboardingOutputTitle.
  ///
  /// In en, this message translates to:
  /// **'Output folder'**
  String get onboardingOutputTitle;

  /// No description provided for @onboardingOutputBody.
  ///
  /// In en, this message translates to:
  /// **'Choose where files are saved.'**
  String get onboardingOutputBody;

  /// No description provided for @onboardingExtensionTitle.
  ///
  /// In en, this message translates to:
  /// **'Browser extension'**
  String get onboardingExtensionTitle;

  /// No description provided for @onboardingExtensionBody.
  ///
  /// In en, this message translates to:
  /// **'Install the Chrome or Firefox extension to send links here.'**
  String get onboardingExtensionBody;

  /// No description provided for @onboardingReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get onboardingReadyTitle;

  /// No description provided for @onboardingReadyBody.
  ///
  /// In en, this message translates to:
  /// **'Replay the tour from Settings > General.'**
  String get onboardingReadyBody;

  /// No description provided for @pluginFeaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'App features'**
  String get pluginFeaturesTitle;

  /// No description provided for @pluginFeaturesHint.
  ///
  /// In en, this message translates to:
  /// **'Turn on only the screens and tools you use. Disabling a feature keeps its code and data intact.'**
  String get pluginFeaturesHint;

  /// No description provided for @pluginRequired.
  ///
  /// In en, this message translates to:
  /// **'Essential'**
  String get pluginRequired;

  /// No description provided for @pluginActivate.
  ///
  /// In en, this message translates to:
  /// **'Enable feature'**
  String get pluginActivate;

  /// No description provided for @pluginOpen.
  ///
  /// In en, this message translates to:
  /// **'Open feature'**
  String get pluginOpen;

  /// No description provided for @pluginInactiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Feature is disabled'**
  String get pluginInactiveTitle;

  /// No description provided for @pluginInactiveBody.
  ///
  /// In en, this message translates to:
  /// **'The feature is still available and its data is untouched. You can turn it back on in plugin settings.'**
  String get pluginInactiveBody;

  /// No description provided for @pluginManage.
  ///
  /// In en, this message translates to:
  /// **'Manage plugins'**
  String get pluginManage;

  /// No description provided for @pluginWebRequest.
  ///
  /// In en, this message translates to:
  /// **'TapLoad’s website requested this feature. Confirm here to add it to your interface.'**
  String get pluginWebRequest;

  /// No description provided for @pluginExternalHint.
  ///
  /// In en, this message translates to:
  /// **'This extension is installed in your browser. Use the existing setup steps below.'**
  String get pluginExternalHint;

  /// No description provided for @addSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'New download'**
  String get addSheetTitle;

  /// No description provided for @addSheetPasteCopiedLink.
  ///
  /// In en, this message translates to:
  /// **'Paste copied link: {url}'**
  String addSheetPasteCopiedLink(String url);

  /// No description provided for @addSheetModeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get addSheetModeVideo;

  /// No description provided for @addSheetModeAudioOnly.
  ///
  /// In en, this message translates to:
  /// **'Audio only'**
  String get addSheetModeAudioOnly;

  /// No description provided for @addSheetBrowserSession.
  ///
  /// In en, this message translates to:
  /// **'Browser session'**
  String get addSheetBrowserSession;

  /// No description provided for @addSheetQualityChosen.
  ///
  /// In en, this message translates to:
  /// **'Selected quality'**
  String get addSheetQualityChosen;

  /// No description provided for @addSheetQualityChosenWithSize.
  ///
  /// In en, this message translates to:
  /// **'Selected quality, {size}'**
  String addSheetQualityChosenWithSize(String size);

  /// No description provided for @addSheetStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get addSheetStarting;

  /// No description provided for @addSheetDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get addSheetDownload;

  /// No description provided for @addSheetPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview unavailable. The download may still work.'**
  String get addSheetPreviewUnavailable;

  /// No description provided for @addSheetAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing link…'**
  String get addSheetAnalyzing;

  /// No description provided for @addSheetUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the video or media link'**
  String get addSheetUrlHint;

  /// No description provided for @addSheetValidLink.
  ///
  /// In en, this message translates to:
  /// **'Valid link'**
  String get addSheetValidLink;

  /// No description provided for @addSheetClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get addSheetClear;

  /// No description provided for @addSheetPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get addSheetPaste;

  /// No description provided for @addSheetInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid URL.'**
  String get addSheetInvalidUrl;

  /// No description provided for @addSheetUnsupportedUrl.
  ///
  /// In en, this message translates to:
  /// **'Unsupported URL or restricted domain.'**
  String get addSheetUnsupportedUrl;

  /// No description provided for @addSheetError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String addSheetError(String error);

  /// No description provided for @addSheetDetailBest.
  ///
  /// In en, this message translates to:
  /// **'Maximum resolution available'**
  String get addSheetDetailBest;

  /// No description provided for @addSheetDetail1080.
  ///
  /// In en, this message translates to:
  /// **'High definition'**
  String get addSheetDetail1080;

  /// No description provided for @addSheetDetail720.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get addSheetDetail720;

  /// No description provided for @addSheetDetail480.
  ///
  /// In en, this message translates to:
  /// **'Data saver'**
  String get addSheetDetail480;

  /// No description provided for @addSheetDetailAudio.
  ///
  /// In en, this message translates to:
  /// **'Extracted audio, best quality available'**
  String get addSheetDetailAudio;

  /// No description provided for @addSheetReadoutMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get addSheetReadoutMax;

  /// No description provided for @addSheetUntitledMedia.
  ///
  /// In en, this message translates to:
  /// **'Untitled media'**
  String get addSheetUntitledMedia;

  /// No description provided for @sizeUnitKb.
  ///
  /// In en, this message translates to:
  /// **'KB'**
  String get sizeUnitKb;

  /// No description provided for @sizeUnitMb.
  ///
  /// In en, this message translates to:
  /// **'MB'**
  String get sizeUnitMb;

  /// No description provided for @sizeUnitGb.
  ///
  /// In en, this message translates to:
  /// **'GB'**
  String get sizeUnitGb;

  /// No description provided for @archiveMobileTitle.
  ///
  /// In en, this message translates to:
  /// **'TikTok archive'**
  String get archiveMobileTitle;

  /// No description provided for @archiveMobileFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get archiveMobileFilters;

  /// No description provided for @archiveMobileReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get archiveMobileReset;

  /// No description provided for @archiveMobileType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get archiveMobileType;

  /// No description provided for @archiveMobileFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get archiveMobileFilterAll;

  /// No description provided for @archiveMobileFilterFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get archiveMobileFilterFavorites;

  /// No description provided for @archiveMobileFilterLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get archiveMobileFilterLikes;

  /// No description provided for @archiveMobileYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get archiveMobileYear;

  /// No description provided for @archiveMobileAllYears.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get archiveMobileAllYears;

  /// No description provided for @archiveMobileApplyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get archiveMobileApplyFilters;

  /// No description provided for @archiveMobileBackToVideos.
  ///
  /// In en, this message translates to:
  /// **'Back to videos'**
  String get archiveMobileBackToVideos;

  /// No description provided for @archiveMobileDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get archiveMobileDownload;

  /// No description provided for @archiveMobileBatchStarted.
  ///
  /// In en, this message translates to:
  /// **'Batch download started'**
  String get archiveMobileBatchStarted;

  /// No description provided for @archiveMobileSyncTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import or sync'**
  String get archiveMobileSyncTooltip;

  /// No description provided for @archiveMobileBackToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Back to library'**
  String get archiveMobileBackToLibrary;

  /// No description provided for @archiveMobileBatchRunning.
  ///
  /// In en, this message translates to:
  /// **'Batch download in progress'**
  String get archiveMobileBatchRunning;

  /// No description provided for @archiveMobileSkippedVideos.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} video skipped} other{{count} videos skipped}}'**
  String archiveMobileSkippedVideos(int count);

  /// No description provided for @archiveMobileStopBatch.
  ///
  /// In en, this message translates to:
  /// **'Stop batch'**
  String get archiveMobileStopBatch;

  /// No description provided for @archiveMobileSyncingCollections.
  ///
  /// In en, this message translates to:
  /// **'Syncing collections'**
  String get archiveMobileSyncingCollections;

  /// No description provided for @archiveMobileSyncWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the browser\'s response. Keep a TikTok page open.'**
  String get archiveMobileSyncWaiting;

  /// No description provided for @archiveMobileChipAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get archiveMobileChipAll;

  /// No description provided for @archiveMobileSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for a video or a collection'**
  String get archiveMobileSearchHint;

  /// No description provided for @archiveMobileClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get archiveMobileClearSearch;

  /// No description provided for @archiveMobileVideoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} video} other{{count} videos}}'**
  String archiveMobileVideoCount(int count);

  /// No description provided for @archiveMobileClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get archiveMobileClearSelection;

  /// No description provided for @archiveMobileSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get archiveMobileSelectAll;

  /// No description provided for @archiveMobileManageCollections.
  ///
  /// In en, this message translates to:
  /// **'Manage collections'**
  String get archiveMobileManageCollections;

  /// No description provided for @archiveMobilePlayFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Play videos full screen'**
  String get archiveMobilePlayFullscreen;

  /// No description provided for @archiveMobileNoVideos.
  ///
  /// In en, this message translates to:
  /// **'No videos found'**
  String get archiveMobileNoVideos;

  /// No description provided for @archiveMobileVideoAdded.
  ///
  /// In en, this message translates to:
  /// **'Video added to the download queue.'**
  String get archiveMobileVideoAdded;

  /// No description provided for @archiveMobileTileLabel.
  ///
  /// In en, this message translates to:
  /// **'Video {date}'**
  String archiveMobileTileLabel(String date);

  /// No description provided for @archiveMobileProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get archiveMobileProgress;

  /// No description provided for @archiveMobileSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{selected} other{selected}}'**
  String archiveMobileSelectedLabel(int count);

  /// No description provided for @statsMobileBackToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Back to library'**
  String get statsMobileBackToLibrary;

  /// No description provided for @statsMobileTotalSinceInstall.
  ///
  /// In en, this message translates to:
  /// **'Total downloaded since installation'**
  String get statsMobileTotalSinceInstall;

  /// No description provided for @statsMobileActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get statsMobileActivity;

  /// No description provided for @statsMobileLast12Weeks.
  ///
  /// In en, this message translates to:
  /// **'Last 12 weeks'**
  String get statsMobileLast12Weeks;

  /// No description provided for @statsMobileLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get statsMobileLess;

  /// No description provided for @statsMobileMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get statsMobileMore;

  /// No description provided for @statsMobileBySource.
  ///
  /// In en, this message translates to:
  /// **'Downloads by source'**
  String get statsMobileBySource;

  /// No description provided for @statsMobileDownloadsSummary.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, one{{total} download} other{{total} downloads}}, {today} today'**
  String statsMobileDownloadsSummary(int total, int today);

  /// No description provided for @statsMobileHeatmapLabel.
  ///
  /// In en, this message translates to:
  /// **'Heatmap of downloads per day'**
  String get statsMobileHeatmapLabel;

  /// No description provided for @statsMobileOthers.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get statsMobileOthers;

  /// No description provided for @statsMobileUnitB.
  ///
  /// In en, this message translates to:
  /// **'B'**
  String get statsMobileUnitB;

  /// No description provided for @statsMobileUnitKB.
  ///
  /// In en, this message translates to:
  /// **'KB'**
  String get statsMobileUnitKB;

  /// No description provided for @statsMobileUnitMB.
  ///
  /// In en, this message translates to:
  /// **'MB'**
  String get statsMobileUnitMB;

  /// No description provided for @statsMobileUnitGB.
  ///
  /// In en, this message translates to:
  /// **'GB'**
  String get statsMobileUnitGB;

  /// No description provided for @statsMobileUnitTB.
  ///
  /// In en, this message translates to:
  /// **'TB'**
  String get statsMobileUnitTB;

  /// No description provided for @settingsHubEngine.
  ///
  /// In en, this message translates to:
  /// **'yt-dlp engine'**
  String get settingsHubEngine;

  /// No description provided for @settingsHubUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get settingsHubUnavailable;

  /// No description provided for @settingsHubChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get settingsHubChecking;

  /// No description provided for @settingsHubCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get settingsHubCheckUpdates;

  /// No description provided for @settingsHubAutoUpdate.
  ///
  /// In en, this message translates to:
  /// **'Automatic update'**
  String get settingsHubAutoUpdate;

  /// No description provided for @settingsHubChannel.
  ///
  /// In en, this message translates to:
  /// **'Update channel'**
  String get settingsHubChannel;

  /// No description provided for @settingsHubChannelNightly.
  ///
  /// In en, this message translates to:
  /// **'Nightly'**
  String get settingsHubChannelNightly;

  /// No description provided for @settingsHubChannelStable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get settingsHubChannelStable;

  /// No description provided for @settingsHubUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Check failed, try again later.'**
  String get settingsHubUpdateFailed;

  /// No description provided for @settingsHubUpToDate.
  ///
  /// In en, this message translates to:
  /// **'yt-dlp is up to date'**
  String get settingsHubUpToDate;

  /// No description provided for @settingsHubUpdated.
  ///
  /// In en, this message translates to:
  /// **'yt-dlp updated'**
  String get settingsHubUpdated;

  /// No description provided for @settingsHubUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Update error: {error}'**
  String settingsHubUpdateError(String error);

  /// No description provided for @settingsHubParallel.
  ///
  /// In en, this message translates to:
  /// **'Parallel downloads'**
  String get settingsHubParallel;

  /// No description provided for @settingsHubParallelHint.
  ///
  /// In en, this message translates to:
  /// **'More speed, more heat'**
  String get settingsHubParallelHint;

  /// No description provided for @settingsHubStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsHubStorage;

  /// No description provided for @settingsHubStorageFree.
  ///
  /// In en, this message translates to:
  /// **'{free} free of {total}'**
  String settingsHubStorageFree(String free, String total);

  /// No description provided for @settingsHubWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi only'**
  String get settingsHubWifiOnly;

  /// No description provided for @settingsHubWifiOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Never start a download on mobile data'**
  String get settingsHubWifiOnlyHint;

  /// No description provided for @detailsWifiOnlyHeadline.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi only is on: connect to Wi-Fi, then retry'**
  String get detailsWifiOnlyHeadline;

  /// No description provided for @detailsStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get detailsStatusFailed;

  /// No description provided for @detailsStatusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get detailsStatusDownloading;

  /// No description provided for @detailsStatusExtracting.
  ///
  /// In en, this message translates to:
  /// **'Analyzing link'**
  String get detailsStatusExtracting;

  /// No description provided for @detailsStatusDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Already added'**
  String get detailsStatusDuplicate;

  /// No description provided for @detailsDiagnostic.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic'**
  String get detailsDiagnostic;

  /// No description provided for @detailsStepResolve.
  ///
  /// In en, this message translates to:
  /// **'Resolving link'**
  String get detailsStepResolve;

  /// No description provided for @detailsStepReadPage.
  ///
  /// In en, this message translates to:
  /// **'Reading page'**
  String get detailsStepReadPage;

  /// No description provided for @detailsStepExtractFormats.
  ///
  /// In en, this message translates to:
  /// **'Extracting formats'**
  String get detailsStepExtractFormats;

  /// No description provided for @detailsStepDownload.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get detailsStepDownload;

  /// No description provided for @detailsStepMerge.
  ///
  /// In en, this message translates to:
  /// **'Merging audio and video'**
  String get detailsStepMerge;

  /// No description provided for @detailsStepFailMerge.
  ///
  /// In en, this message translates to:
  /// **'Merging the file failed'**
  String get detailsStepFailMerge;

  /// No description provided for @detailsStepFailTransfer.
  ///
  /// In en, this message translates to:
  /// **'The transfer was interrupted'**
  String get detailsStepFailTransfer;

  /// No description provided for @detailsStepFailNoMedia.
  ///
  /// In en, this message translates to:
  /// **'No accessible media'**
  String get detailsStepFailNoMedia;

  /// No description provided for @detailsEngineUpdated.
  ///
  /// In en, this message translates to:
  /// **'Engine updated: {status}'**
  String detailsEngineUpdated(String status);

  /// No description provided for @detailsYtDlpUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'yt-dlp update succeeded: {status}'**
  String detailsYtDlpUpdateSuccess(String status);

  /// No description provided for @detailsEngineUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Error during update: {error}'**
  String detailsEngineUpdateError(String error);

  /// No description provided for @detailsLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get detailsLinkCopied;

  /// No description provided for @detailsShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get detailsShare;

  /// No description provided for @detailsOpenWith.
  ///
  /// In en, this message translates to:
  /// **'Open with'**
  String get detailsOpenWith;

  /// No description provided for @detailsCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get detailsCopyLink;

  /// No description provided for @detailsRestart.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get detailsRestart;

  /// No description provided for @detailsPlayVideo.
  ///
  /// In en, this message translates to:
  /// **'Play video'**
  String get detailsPlayVideo;

  /// No description provided for @detailsInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get detailsInfoTitle;

  /// No description provided for @detailsInfoSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get detailsInfoSource;

  /// No description provided for @detailsInfoSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get detailsInfoSize;

  /// No description provided for @detailsInfoFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get detailsInfoFile;

  /// No description provided for @detailsInfoId.
  ///
  /// In en, this message translates to:
  /// **'Identifier'**
  String get detailsInfoId;

  /// No description provided for @detailsUpdatingEngine.
  ///
  /// In en, this message translates to:
  /// **'Updating engine…'**
  String get detailsUpdatingEngine;

  /// No description provided for @detailsRepairAuto.
  ///
  /// In en, this message translates to:
  /// **'Repair automatically'**
  String get detailsRepairAuto;

  /// No description provided for @detailsSignInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Sign in in the browser'**
  String get detailsSignInBrowser;

  /// No description provided for @detailsAgeSolutions.
  ///
  /// In en, this message translates to:
  /// **'See solutions (18+)'**
  String get detailsAgeSolutions;

  /// No description provided for @detailsTechnicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get detailsTechnicalDetails;

  /// No description provided for @detailsNoLogs.
  ///
  /// In en, this message translates to:
  /// **'No logs available.'**
  String get detailsNoLogs;

  /// No description provided for @detailsCopyLogs.
  ///
  /// In en, this message translates to:
  /// **'Copy logs'**
  String get detailsCopyLogs;

  /// No description provided for @detailsLogsCopied.
  ///
  /// In en, this message translates to:
  /// **'Logs copied'**
  String get detailsLogsCopied;

  /// No description provided for @detailsHeadlineAgeVerification.
  ///
  /// In en, this message translates to:
  /// **'Age verification required'**
  String get detailsHeadlineAgeVerification;

  /// No description provided for @detailsHeadlineHostRefused.
  ///
  /// In en, this message translates to:
  /// **'{host} refused the request'**
  String detailsHeadlineHostRefused(String host);

  /// No description provided for @detailsHeadlineTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many requests, access limited'**
  String get detailsHeadlineTooManyRequests;

  /// No description provided for @detailsHeadlinePrivateVideo.
  ///
  /// In en, this message translates to:
  /// **'Private or removed video'**
  String get detailsHeadlinePrivateVideo;

  /// No description provided for @detailsHeadlineGeoBlocked.
  ///
  /// In en, this message translates to:
  /// **'Content blocked in your country'**
  String get detailsHeadlineGeoBlocked;

  /// No description provided for @detailsHeadlineCopyright.
  ///
  /// In en, this message translates to:
  /// **'Removed for copyright'**
  String get detailsHeadlineCopyright;

  /// No description provided for @detailsHeadlineSuspended.
  ///
  /// In en, this message translates to:
  /// **'Account or content suspended'**
  String get detailsHeadlineSuspended;

  /// No description provided for @detailsHeadlineNoMedia.
  ///
  /// In en, this message translates to:
  /// **'No media in this link'**
  String get detailsHeadlineNoMedia;

  /// No description provided for @detailsHeadlineUnsupportedUrl.
  ///
  /// In en, this message translates to:
  /// **'Link not supported'**
  String get detailsHeadlineUnsupportedUrl;

  /// No description provided for @detailsHeadlineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Content unavailable'**
  String get detailsHeadlineUnavailable;

  /// No description provided for @detailsHeadlineLiveOffline.
  ///
  /// In en, this message translates to:
  /// **'The live stream is offline'**
  String get detailsHeadlineLiveOffline;

  /// No description provided for @detailsHeadlineAntiBot.
  ///
  /// In en, this message translates to:
  /// **'Anti-bot protection detected'**
  String get detailsHeadlineAntiBot;

  /// No description provided for @detailsHeadlineNoFormats.
  ///
  /// In en, this message translates to:
  /// **'No accessible format'**
  String get detailsHeadlineNoFormats;

  /// No description provided for @detailsHeadlineLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign-in required'**
  String get detailsHeadlineLoginRequired;

  /// No description provided for @detailsHeadlineNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network problem'**
  String get detailsHeadlineNetwork;

  /// No description provided for @detailsHeadlineFailed.
  ///
  /// In en, this message translates to:
  /// **'The download failed'**
  String get detailsHeadlineFailed;

  /// No description provided for @downloadCardDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String downloadCardDeleteConfirm(String title);

  /// No description provided for @downloadCardAgeVerification.
  ///
  /// In en, this message translates to:
  /// **'Age verification (18+), see solutions'**
  String get downloadCardAgeVerification;

  /// No description provided for @fileDeletedFromDisk.
  ///
  /// In en, this message translates to:
  /// **'The file will be deleted from your disk. This can\'t be undone.'**
  String get fileDeletedFromDisk;

  /// No description provided for @downloadCardFailedMeta.
  ///
  /// In en, this message translates to:
  /// **'{source}, failed. See diagnostic'**
  String downloadCardFailedMeta(String source);

  /// No description provided for @downloadCardQueuePosition.
  ///
  /// In en, this message translates to:
  /// **'Position {position} in queue'**
  String downloadCardQueuePosition(int position);

  /// No description provided for @downloadCardSizeOf.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String downloadCardSizeOf(String done, String total);

  /// No description provided for @libraryHeaderArchive.
  ///
  /// In en, this message translates to:
  /// **'TikTok archive'**
  String get libraryHeaderArchive;

  /// No description provided for @libraryHeaderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get libraryHeaderFailed;

  /// No description provided for @libraryHeaderFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get libraryHeaderFolders;

  /// No description provided for @libraryHeaderMoreActive.
  ///
  /// In en, this message translates to:
  /// **'+{count} in progress'**
  String libraryHeaderMoreActive(int count);

  /// No description provided for @libraryHeaderLiveSpeed.
  ///
  /// In en, this message translates to:
  /// **'Live speed'**
  String get libraryHeaderLiveSpeed;

  /// No description provided for @libraryHeaderRemaining.
  ///
  /// In en, this message translates to:
  /// **'{eta} left'**
  String libraryHeaderRemaining(String eta);

  /// No description provided for @libraryHeaderUnitGBps.
  ///
  /// In en, this message translates to:
  /// **'GB/s'**
  String get libraryHeaderUnitGBps;

  /// No description provided for @libraryHeaderUnitMBps.
  ///
  /// In en, this message translates to:
  /// **'MB/s'**
  String get libraryHeaderUnitMBps;

  /// No description provided for @libraryHeaderUnitKBps.
  ///
  /// In en, this message translates to:
  /// **'KB/s'**
  String get libraryHeaderUnitKBps;

  /// No description provided for @libraryHeaderUnitBps.
  ///
  /// In en, this message translates to:
  /// **'B/s'**
  String get libraryHeaderUnitBps;

  /// No description provided for @clipboardCapsuleCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied, {platform}'**
  String clipboardCapsuleCopied(String platform);

  /// No description provided for @clipboardCapsuleMediaLink.
  ///
  /// In en, this message translates to:
  /// **'Media link'**
  String get clipboardCapsuleMediaLink;

  /// No description provided for @clipboardCapsuleDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get clipboardCapsuleDownload;

  /// No description provided for @clipboardCapsuleDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get clipboardCapsuleDismiss;

  /// No description provided for @shellTabLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get shellTabLibrary;

  /// No description provided for @shellTabBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get shellTabBrowse;

  /// No description provided for @shellTabSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get shellTabSend;

  /// No description provided for @shellTabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get shellTabSettings;

  /// No description provided for @browserMobileTitle.
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get browserMobileTitle;

  /// No description provided for @browserMobileBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get browserMobileBack;

  /// No description provided for @browserMobileForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get browserMobileForward;

  /// No description provided for @browserMobileReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get browserMobileReload;

  /// No description provided for @browserMobileReadyToDownload.
  ///
  /// In en, this message translates to:
  /// **'Page ready to download'**
  String get browserMobileReadyToDownload;

  /// No description provided for @browserMobileDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get browserMobileDownload;

  /// No description provided for @oledKitStepperLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get oledKitStepperLess;

  /// No description provided for @oledKitStepperMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get oledKitStepperMore;

  /// No description provided for @oledKitFragmentsReceived.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} fragments received'**
  String oledKitFragmentsReceived(int done, int total);

  /// No description provided for @settingsTilesNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get settingsTilesNotFound;

  /// No description provided for @settingsOutputChangeFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Change folder'**
  String get settingsOutputChangeFolderTitle;

  /// No description provided for @settingsOutputChangeFolderBody.
  ///
  /// In en, this message translates to:
  /// **'Do you want to automatically migrate all your existing videos and thumbnails to this new folder?'**
  String get settingsOutputChangeFolderBody;

  /// No description provided for @settingsOutputChangeFolderOnly.
  ///
  /// In en, this message translates to:
  /// **'Only change the folder'**
  String get settingsOutputChangeFolderOnly;

  /// No description provided for @settingsOutputMigrateFiles.
  ///
  /// In en, this message translates to:
  /// **'Migrate files'**
  String get settingsOutputMigrateFiles;

  /// No description provided for @settingsOutputMigrateLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Migrate library'**
  String get settingsOutputMigrateLibraryTitle;

  /// No description provided for @settingsOutputMigrateLibraryDesc.
  ///
  /// In en, this message translates to:
  /// **'Move all videos and thumbnails to another drive or folder'**
  String get settingsOutputMigrateLibraryDesc;

  /// No description provided for @settingsOutputReorganizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Reorganize existing videos'**
  String get settingsOutputReorganizeTitle;

  /// No description provided for @settingsOutputReorganizeDesc.
  ///
  /// In en, this message translates to:
  /// **'Sort already downloaded videos into subfolders by creator (with preview)'**
  String get settingsOutputReorganizeDesc;

  /// No description provided for @settingsSmartRecommendedRules.
  ///
  /// In en, this message translates to:
  /// **'Recommended rules'**
  String get settingsSmartRecommendedRules;

  /// No description provided for @settingsSystemYtDlpUpdated.
  ///
  /// In en, this message translates to:
  /// **'yt-dlp updated: {result}'**
  String settingsSystemYtDlpUpdated(String result);

  /// No description provided for @settingsSystemUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Update error: {error}'**
  String settingsSystemUpdateError(String error);

  /// No description provided for @settingsSystemUpdateEngineTitle.
  ///
  /// In en, this message translates to:
  /// **'Update the yt-dlp engine'**
  String get settingsSystemUpdateEngineTitle;

  /// No description provided for @settingsSystemUpdateEngineDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading the latest version (nightly)...'**
  String get settingsSystemUpdateEngineDownloading;

  /// No description provided for @settingsSystemUpdateEngineDesc.
  ///
  /// In en, this message translates to:
  /// **'Check for and install the latest version of yt-dlp'**
  String get settingsSystemUpdateEngineDesc;

  /// No description provided for @transferMobileAddFolders.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Add {count} folder} other{Add {count} folders}}'**
  String transferMobileAddFolders(int count);

  /// No description provided for @transferMobileBroadcastDone.
  ///
  /// In en, this message translates to:
  /// **'Discovery signal broadcast on the network'**
  String get transferMobileBroadcastDone;

  /// No description provided for @transferMobileBroadcastTooltip.
  ///
  /// In en, this message translates to:
  /// **'Broadcast a network announcement'**
  String get transferMobileBroadcastTooltip;

  /// No description provided for @transferMobileBytesOf.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String transferMobileBytesOf(String done, String total);

  /// No description provided for @transferMobileCheckAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get transferMobileCheckAll;

  /// No description provided for @transferMobileUncheckAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get transferMobileUncheckAll;

  /// No description provided for @transferMobileClearList.
  ///
  /// In en, this message translates to:
  /// **'Clear list'**
  String get transferMobileClearList;

  /// No description provided for @transferMobileCreatorCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} creator} other{{count} creators}}'**
  String transferMobileCreatorCount(int count);

  /// No description provided for @transferMobileDemoNoFiles.
  ///
  /// In en, this message translates to:
  /// **'Demo mode: no personal files accessible.'**
  String get transferMobileDemoNoFiles;

  /// No description provided for @transferMobileDemoSendSimulated.
  ///
  /// In en, this message translates to:
  /// **'Demo mode: simulated send, no file transmitted.'**
  String get transferMobileDemoSendSimulated;

  /// No description provided for @transferMobileDeviceNotFound.
  ///
  /// In en, this message translates to:
  /// **'No device found at this address.'**
  String get transferMobileDeviceNotFound;

  /// No description provided for @transferMobileDeviceUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Device unreachable ({address})'**
  String transferMobileDeviceUnreachable(String address);

  /// No description provided for @transferMobileDiagBusy.
  ///
  /// In en, this message translates to:
  /// **'The receiving device is already busy with another transfer.'**
  String get transferMobileDiagBusy;

  /// No description provided for @transferMobileDiagChecksumMismatch.
  ///
  /// In en, this message translates to:
  /// **'Data integrity error (checksum mismatch).'**
  String get transferMobileDiagChecksumMismatch;

  /// No description provided for @transferMobileDiagCommunication.
  ///
  /// In en, this message translates to:
  /// **'Error communicating with the device.'**
  String get transferMobileDiagCommunication;

  /// No description provided for @transferMobileDiagConnectionRefused.
  ///
  /// In en, this message translates to:
  /// **'Connection refused. Open LocalSend on the receiving device and turn on Receive mode.'**
  String get transferMobileDiagConnectionRefused;

  /// No description provided for @transferMobileDiagPinRequired.
  ///
  /// In en, this message translates to:
  /// **'PIN required by the receiving device.'**
  String get transferMobileDiagPinRequired;

  /// No description provided for @transferMobileDiagRejected.
  ///
  /// In en, this message translates to:
  /// **'Transfer declined by the user on the receiving device.'**
  String get transferMobileDiagRejected;

  /// No description provided for @transferMobileDiagTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out. Check that the receiving device is on and on the same Wi-Fi.'**
  String get transferMobileDiagTimeout;

  /// No description provided for @transferMobileDiagUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Check that LocalSend is open on that device, on the same Wi-Fi network.'**
  String get transferMobileDiagUnreachable;

  /// No description provided for @transferMobileFileCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} file} other{{count} files}}'**
  String transferMobileFileCount(int count);

  /// No description provided for @transferMobileFolderCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} folder} other{{count} folders}}'**
  String transferMobileFolderCount(int count);

  /// No description provided for @transferMobileFolderPickError.
  ///
  /// In en, this message translates to:
  /// **'Folder selection error: {error}'**
  String transferMobileFolderPickError(String error);

  /// No description provided for @transferMobileFoldersAction.
  ///
  /// In en, this message translates to:
  /// **'Folders…'**
  String get transferMobileFoldersAction;

  /// No description provided for @transferMobileVideosAction.
  ///
  /// In en, this message translates to:
  /// **'Videos…'**
  String get transferMobileVideosAction;

  /// No description provided for @transferMobileHeaderReceiving.
  ///
  /// In en, this message translates to:
  /// **'Receiving'**
  String get transferMobileHeaderReceiving;

  /// No description provided for @transferMobileHeaderSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get transferMobileHeaderSending;

  /// No description provided for @transferMobileIpAddress.
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get transferMobileIpAddress;

  /// No description provided for @transferMobileKindDesktop.
  ///
  /// In en, this message translates to:
  /// **'Computer'**
  String get transferMobileKindDesktop;

  /// No description provided for @transferMobileKindHeadless.
  ///
  /// In en, this message translates to:
  /// **'Headless'**
  String get transferMobileKindHeadless;

  /// No description provided for @transferMobileKindMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get transferMobileKindMobile;

  /// No description provided for @transferMobileKindServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get transferMobileKindServer;

  /// No description provided for @transferMobileKindWeb.
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get transferMobileKindWeb;

  /// No description provided for @transferMobileLibraryNewOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{library} ({newest} new / {found})'**
  String transferMobileLibraryNewOfTotal(String library, int newest, int found);

  /// No description provided for @transferMobileMarkKnown.
  ///
  /// In en, this message translates to:
  /// **'Mark as known device'**
  String get transferMobileMarkKnown;

  /// No description provided for @transferMobileUnmarkKnown.
  ///
  /// In en, this message translates to:
  /// **'Remove from known devices'**
  String get transferMobileUnmarkKnown;

  /// No description provided for @transferMobileMediaCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} media item} other{{count} media items}}'**
  String transferMobileMediaCount(int count);

  /// No description provided for @transferMobileMediaFallback.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get transferMobileMediaFallback;

  /// No description provided for @transferMobileMediaSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} media item selected} other{{count} media items selected}}'**
  String transferMobileMediaSelected(int count);

  /// No description provided for @transferMobileNameNewCount.
  ///
  /// In en, this message translates to:
  /// **'{name} ({newest} new)'**
  String transferMobileNameNewCount(String name, int newest);

  /// No description provided for @transferMobileNearbyCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No nearby devices} one{{count} nearby device} other{{count} nearby devices}}'**
  String transferMobileNearbyCount(int count);

  /// No description provided for @transferMobileNewVideosCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} new video} other{{count} new videos}}'**
  String transferMobileNewVideosCount(int count);

  /// No description provided for @transferMobileNoDataSent.
  ///
  /// In en, this message translates to:
  /// **'no data sent'**
  String get transferMobileNoDataSent;

  /// No description provided for @transferMobileNoFolderMatch.
  ///
  /// In en, this message translates to:
  /// **'No folder matches'**
  String get transferMobileNoFolderMatch;

  /// No description provided for @transferMobilePeerPinExplain.
  ///
  /// In en, this message translates to:
  /// **'This receiving device protects incoming transfers with a PIN set in its LocalSend settings.\n\nEnter the PIN configured on your phone (or turn off the PIN option in the settings of your phone to send without a code).'**
  String get transferMobilePeerPinExplain;

  /// No description provided for @transferMobilePeerPinRequired.
  ///
  /// In en, this message translates to:
  /// **'PIN required by {alias}'**
  String transferMobilePeerPinRequired(String alias);

  /// No description provided for @transferMobilePinExample.
  ///
  /// In en, this message translates to:
  /// **'E.g. 1234'**
  String get transferMobilePinExample;

  /// No description provided for @transferMobilePinLabel.
  ///
  /// In en, this message translates to:
  /// **'Security PIN'**
  String get transferMobilePinLabel;

  /// No description provided for @transferMobilePortAltActive.
  ///
  /// In en, this message translates to:
  /// **'Port 53317 is busy. Alternate port {port} is active.'**
  String transferMobilePortAltActive(int port);

  /// No description provided for @transferMobilePortDefault.
  ///
  /// In en, this message translates to:
  /// **'Port (default: 53317)'**
  String get transferMobilePortDefault;

  /// No description provided for @transferMobileQrHide.
  ///
  /// In en, this message translates to:
  /// **'Hide QR code'**
  String get transferMobileQrHide;

  /// No description provided for @transferMobileQrShow.
  ///
  /// In en, this message translates to:
  /// **'Show QR code'**
  String get transferMobileQrShow;

  /// No description provided for @transferMobileQrShowMobileToMobile.
  ///
  /// In en, this message translates to:
  /// **'Show QR code (phone to phone)'**
  String get transferMobileQrShowMobileToMobile;

  /// No description provided for @transferMobileReadyToReceive.
  ///
  /// In en, this message translates to:
  /// **'Ready to receive'**
  String get transferMobileReadyToReceive;

  /// No description provided for @transferMobileReceiveFiles.
  ///
  /// In en, this message translates to:
  /// **'Receive files'**
  String get transferMobileReceiveFiles;

  /// No description provided for @transferMobileRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get transferMobileRefresh;

  /// No description provided for @transferMobileRefreshSearch.
  ///
  /// In en, this message translates to:
  /// **'Refresh search'**
  String get transferMobileRefreshSearch;

  /// No description provided for @transferMobileScanFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders {scanned} / {total} ({videos, plural, one{{videos} video} other{{videos} videos}})…'**
  String transferMobileScanFolders(int scanned, int total, int videos);

  /// No description provided for @transferMobileScanVideosFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} video found…} other{{count} videos found…}}'**
  String transferMobileScanVideosFound(int count);

  /// No description provided for @transferMobileSearchDemoMedia.
  ///
  /// In en, this message translates to:
  /// **'Search a demo media item…'**
  String get transferMobileSearchDemoMedia;

  /// No description provided for @transferMobileSelectedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{selected}/{total} selected'**
  String transferMobileSelectedOfTotal(int selected, int total);

  /// No description provided for @transferMobileShowPinQr.
  ///
  /// In en, this message translates to:
  /// **'Show my PIN and QR code'**
  String get transferMobileShowPinQr;

  /// No description provided for @transferMobileSimulation.
  ///
  /// In en, this message translates to:
  /// **'simulation'**
  String get transferMobileSimulation;

  /// No description provided for @transferMobileSubfoldersFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter subfolders…'**
  String get transferMobileSubfoldersFilter;

  /// No description provided for @transferMobileSubfoldersFoundIn.
  ///
  /// In en, this message translates to:
  /// **'Folders found in {name}'**
  String transferMobileSubfoldersFoundIn(String name);

  /// No description provided for @transferMobileSubfoldersTitle.
  ///
  /// In en, this message translates to:
  /// **'Select folders'**
  String get transferMobileSubfoldersTitle;

  /// No description provided for @transferMobileUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get transferMobileUpToDate;

  /// No description provided for @transferMobileUpToDateCount.
  ///
  /// In en, this message translates to:
  /// **'Up to date ({count})'**
  String transferMobileUpToDateCount(int count);

  /// No description provided for @transferMobileVideoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} video} other{{count} videos}}'**
  String transferMobileVideoCount(int count);

  /// No description provided for @transferMobileVideosZipped.
  ///
  /// In en, this message translates to:
  /// **'{count} videos (bundled in a ZIP)'**
  String transferMobileVideosZipped(int count);

  /// No description provided for @transferMobileVisibleOnLan.
  ///
  /// In en, this message translates to:
  /// **'Visible on the local network'**
  String get transferMobileVisibleOnLan;

  /// No description provided for @transferMobileVisibleOnWifi.
  ///
  /// In en, this message translates to:
  /// **'Visible on the local Wi-Fi'**
  String get transferMobileVisibleOnWifi;

  /// No description provided for @transferMobileZipActive.
  ///
  /// In en, this message translates to:
  /// **'ZIP on'**
  String get transferMobileZipActive;

  /// No description provided for @transferMobileZipArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive as ZIP'**
  String get transferMobileZipArchive;

  /// No description provided for @transferMobileZipEnabled.
  ///
  /// In en, this message translates to:
  /// **'ZIP archive: On'**
  String get transferMobileZipEnabled;

  /// No description provided for @transferMobileZipHintLarge.
  ///
  /// In en, this message translates to:
  /// **'ZIP is on. For large folders, turning ZIP off speeds up direct sending to the gallery.'**
  String get transferMobileZipHintLarge;

  /// No description provided for @transferMobileZipHintMulti.
  ///
  /// In en, this message translates to:
  /// **'Several files → one ZIP archive (no compression, videos are already compressed)'**
  String get transferMobileZipHintMulti;

  /// No description provided for @transferMobileZipHintOff.
  ///
  /// In en, this message translates to:
  /// **'Files are sent as they are to LocalSend (straight into the gallery)'**
  String get transferMobileZipHintOff;

  /// No description provided for @transferMobileZipTooltip.
  ///
  /// In en, this message translates to:
  /// **'Bundle several files into a ZIP archive (copy, no compression)'**
  String get transferMobileZipTooltip;

  /// No description provided for @detailsStepFailMetered.
  ///
  /// In en, this message translates to:
  /// **'Mobile data in use'**
  String get detailsStepFailMetered;

  /// No description provided for @archiveMobileCollectionLiked.
  ///
  /// In en, this message translates to:
  /// **'Liked videos'**
  String get archiveMobileCollectionLiked;

  /// No description provided for @archiveMobileCollectionUnsortedFavorites.
  ///
  /// In en, this message translates to:
  /// **'Unsorted favorites'**
  String get archiveMobileCollectionUnsortedFavorites;

  /// No description provided for @browserSniffTitle.
  ///
  /// In en, this message translates to:
  /// **'Detected media'**
  String get browserSniffTitle;

  /// No description provided for @browserSniffHint.
  ///
  /// In en, this message translates to:
  /// **'What this page loaded. Picking one downloads it with your browser session.'**
  String get browserSniffHint;

  /// No description provided for @browserSniffCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 media detected} other{{count} media detected}}'**
  String browserSniffCount(int count);

  /// No description provided for @browserSniffOpen.
  ///
  /// In en, this message translates to:
  /// **'Streams'**
  String get browserSniffOpen;

  /// No description provided for @browserSniffKindHls.
  ///
  /// In en, this message translates to:
  /// **'HLS stream'**
  String get browserSniffKindHls;

  /// No description provided for @browserSniffKindDash.
  ///
  /// In en, this message translates to:
  /// **'DASH stream'**
  String get browserSniffKindDash;

  /// No description provided for @browserSniffKindVideo.
  ///
  /// In en, this message translates to:
  /// **'Video file'**
  String get browserSniffKindVideo;

  /// No description provided for @browserSniffKindAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio file'**
  String get browserSniffKindAudio;

  /// No description provided for @browserSniffDrmNote.
  ///
  /// In en, this message translates to:
  /// **'Protected (DRM) content is detected but cannot be downloaded.'**
  String get browserSniffDrmNote;

  /// No description provided for @backAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get backAgainToExit;

  /// No description provided for @archiveHubImport.
  ///
  /// In en, this message translates to:
  /// **'Import your TikTok export'**
  String get archiveHubImport;

  /// No description provided for @archiveHubImportHint.
  ///
  /// In en, this message translates to:
  /// **'Pick the JSON file exported from TikTok.'**
  String get archiveHubImportHint;

  /// No description provided for @archiveHubPick.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get archiveHubPick;

  /// No description provided for @archiveHubOpen.
  ///
  /// In en, this message translates to:
  /// **'Open library'**
  String get archiveHubOpen;

  /// No description provided for @archiveHubCollections.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} collection} other{{count} collections}}'**
  String archiveHubCollections(int count);

  /// No description provided for @archiveHubLoading.
  ///
  /// In en, this message translates to:
  /// **'Indexing your library…'**
  String get archiveHubLoading;

  /// No description provided for @launchWordmark.
  ///
  /// In en, this message translates to:
  /// **'TapLoad'**
  String get launchWordmark;

  /// No description provided for @launchContinueAnyway.
  ///
  /// In en, this message translates to:
  /// **'Continue anyway'**
  String get launchContinueAnyway;

  /// No description provided for @onbSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onbSkip;

  /// No description provided for @onbNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onbNext;

  /// No description provided for @onbStart.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onbStart;

  /// No description provided for @onbPage1Title.
  ///
  /// In en, this message translates to:
  /// **'Paste a link.\nDone.'**
  String get onbPage1Title;

  /// No description provided for @onbPage1Body.
  ///
  /// In en, this message translates to:
  /// **'Share from any app, or tap + to add a download.'**
  String get onbPage1Body;

  /// No description provided for @onbPage2Title.
  ///
  /// In en, this message translates to:
  /// **'Browse.\nWe detect.'**
  String get onbPage2Title;

  /// No description provided for @onbPage2Body.
  ///
  /// In en, this message translates to:
  /// **'Open a site in the Web tab. The media it plays shows up, ready to save.'**
  String get onbPage2Body;

  /// No description provided for @onbPage3Title.
  ///
  /// In en, this message translates to:
  /// **'Your library,\noffline.'**
  String get onbPage3Title;

  /// No description provided for @onbPage3Body.
  ///
  /// In en, this message translates to:
  /// **'Everything is stored on your phone and plays without a connection.'**
  String get onbPage3Body;

  /// No description provided for @onbPage4Title.
  ///
  /// In en, this message translates to:
  /// **'You\'re set.'**
  String get onbPage4Title;

  /// No description provided for @onbPage4Body.
  ///
  /// In en, this message translates to:
  /// **'Share a link to the app, or tap + to start.'**
  String get onbPage4Body;

  /// No description provided for @onbPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String onbPageLabel(int current, int total);

  /// No description provided for @etaSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String etaSeconds(int seconds);

  /// No description provided for @etaMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min {seconds} s'**
  String etaMinutesSeconds(int minutes, int seconds);

  /// No description provided for @etaHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String etaHoursMinutes(int hours, int minutes);

  /// No description provided for @archiveCollSearch.
  ///
  /// In en, this message translates to:
  /// **'Search a collection'**
  String get archiveCollSearch;

  /// No description provided for @archiveCollEmpty.
  ///
  /// In en, this message translates to:
  /// **'No collection found'**
  String get archiveCollEmpty;

  /// No description provided for @archiveCollShowVideos.
  ///
  /// In en, this message translates to:
  /// **'View videos'**
  String get archiveCollShowVideos;

  /// No description provided for @archiveCollDownloadAll.
  ///
  /// In en, this message translates to:
  /// **'Download all ({count})'**
  String archiveCollDownloadAll(int count);

  /// No description provided for @archiveCollReset.
  ///
  /// In en, this message translates to:
  /// **'Remove the videos from this collection'**
  String get archiveCollReset;

  /// No description provided for @archiveCollResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset the collection'**
  String get archiveCollResetTitle;

  /// No description provided for @archiveCollResetBody.
  ///
  /// In en, this message translates to:
  /// **'Remove the {count} videos from “{name}”? The videos and their other collections are kept.'**
  String archiveCollResetBody(int count, String name);

  /// No description provided for @archiveCollResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get archiveCollResetConfirm;

  /// No description provided for @archiveCollResetDone.
  ///
  /// In en, this message translates to:
  /// **'“{name}” emptied'**
  String archiveCollResetDone(String name);

  /// No description provided for @archiveCollDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete the collection'**
  String get archiveCollDelete;

  /// No description provided for @archiveCollDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete “{name}”? Its {count} videos stay on your device but leave this folder.'**
  String archiveCollDeleteBody(int count, String name);

  /// No description provided for @archiveCollDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get archiveCollDeleteConfirm;

  /// No description provided for @archiveCollDeleteDone.
  ///
  /// In en, this message translates to:
  /// **'“{name}” deleted'**
  String archiveCollDeleteDone(String name);

  /// No description provided for @archiveCollClear.
  ///
  /// In en, this message translates to:
  /// **'Reset the whole archive'**
  String get archiveCollClear;

  /// No description provided for @archiveCollClearBody.
  ///
  /// In en, this message translates to:
  /// **'Delete all collections, rankings and the local TikTok import? Videos already downloaded are kept.'**
  String get archiveCollClearBody;

  /// No description provided for @archiveCollClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get archiveCollClearConfirm;

  /// No description provided for @archiveCollClearDone.
  ///
  /// In en, this message translates to:
  /// **'TikTok archive reset'**
  String get archiveCollClearDone;

  /// No description provided for @libraryPhaseAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing the link…'**
  String get libraryPhaseAnalyzing;

  /// No description provided for @libraryPhaseConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to the server…'**
  String get libraryPhaseConnecting;

  /// No description provided for @libraryPhaseFinalizing.
  ///
  /// In en, this message translates to:
  /// **'Finalizing the file…'**
  String get libraryPhaseFinalizing;

  /// No description provided for @libraryDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get libraryDoneTitle;

  /// No description provided for @libraryDoneAverage.
  ///
  /// In en, this message translates to:
  /// **'on average'**
  String get libraryDoneAverage;

  /// No description provided for @libraryDoneSummary.
  ///
  /// In en, this message translates to:
  /// **'{size} in {time}'**
  String libraryDoneSummary(String size, String time);

  /// No description provided for @alreadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Already in your library'**
  String get alreadyTitle;

  /// No description provided for @alreadyBody.
  ///
  /// In en, this message translates to:
  /// **'“{title}” was already downloaded, so nothing was transferred. Open it, or replace it with a fresh copy.'**
  String alreadyBody(String title);

  /// No description provided for @alreadyOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get alreadyOpen;

  /// No description provided for @alreadyReplace.
  ///
  /// In en, this message translates to:
  /// **'Download again'**
  String get alreadyReplace;

  /// No description provided for @alreadyDismiss.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get alreadyDismiss;

  /// No description provided for @sortFieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get sortFieldDate;

  /// No description provided for @sortFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortFieldName;

  /// No description provided for @sortFieldSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sortFieldSize;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @retryFailedAction.
  ///
  /// In en, this message translates to:
  /// **'Retry failed'**
  String get retryFailedAction;

  /// No description provided for @retryingFailed.
  ///
  /// In en, this message translates to:
  /// **'Retrying {count} failed download(s)'**
  String retryingFailed(int count);

  /// No description provided for @pauseActiveAction.
  ///
  /// In en, this message translates to:
  /// **'Pause active downloads'**
  String get pauseActiveAction;

  /// No description provided for @pauseActiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pause all active downloads'**
  String get pauseActiveTooltip;

  /// No description provided for @activeDownloadsPaused.
  ///
  /// In en, this message translates to:
  /// **'Active downloads paused'**
  String get activeDownloadsPaused;

  /// No description provided for @startQueueAction.
  ///
  /// In en, this message translates to:
  /// **'Start the queue'**
  String get startQueueAction;

  /// No description provided for @startQueueTooltip.
  ///
  /// In en, this message translates to:
  /// **'Start all waiting, paused and failed downloads'**
  String get startQueueTooltip;

  /// No description provided for @queueStarted.
  ///
  /// In en, this message translates to:
  /// **'Queue started'**
  String get queueStarted;

  /// No description provided for @clearCompletedAction.
  ///
  /// In en, this message translates to:
  /// **'Clear completed'**
  String get clearCompletedAction;

  /// No description provided for @clearCompletedDone.
  ///
  /// In en, this message translates to:
  /// **'Completed downloads deleted'**
  String get clearCompletedDone;

  /// No description provided for @clearFailedAction.
  ///
  /// In en, this message translates to:
  /// **'Clear failed'**
  String get clearFailedAction;

  /// No description provided for @clearFailedDone.
  ///
  /// In en, this message translates to:
  /// **'Failed downloads cleared'**
  String get clearFailedDone;

  /// No description provided for @reduceEffects.
  ///
  /// In en, this message translates to:
  /// **'Reduce visual effects'**
  String get reduceEffects;

  /// No description provided for @reduceEffectsDesc.
  ///
  /// In en, this message translates to:
  /// **'Turns off blur and background animations. Smoother on modest PCs.'**
  String get reduceEffectsDesc;

  /// No description provided for @emptyLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'Press Ctrl+N and paste a video link.'**
  String get emptyLibraryHint;

  /// No description provided for @clearSearchAndFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear search and filters'**
  String get clearSearchAndFilters;

  /// No description provided for @inspectorPlayMedia.
  ///
  /// In en, this message translates to:
  /// **'Play media'**
  String get inspectorPlayMedia;

  /// No description provided for @inspectorSourceUrl.
  ///
  /// In en, this message translates to:
  /// **'Source URL'**
  String get inspectorSourceUrl;

  /// No description provided for @inspectorLocalFile.
  ///
  /// In en, this message translates to:
  /// **'Local file'**
  String get inspectorLocalFile;

  /// No description provided for @urlCopied.
  ///
  /// In en, this message translates to:
  /// **'URL copied to the clipboard'**
  String get urlCopied;

  /// No description provided for @showInFolder.
  ///
  /// In en, this message translates to:
  /// **'Show in folder'**
  String get showInFolder;

  /// No description provided for @detailsAction.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get detailsAction;

  /// No description provided for @failedRetryBadge.
  ///
  /// In en, this message translates to:
  /// **'{count} failed · Retry'**
  String failedRetryBadge(int count);

  /// No description provided for @retryAllFailedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Retry all failed downloads ({count})'**
  String retryAllFailedTooltip(int count);

  /// No description provided for @ageCheckRequired.
  ///
  /// In en, this message translates to:
  /// **'Age verification required (18+)'**
  String get ageCheckRequired;

  /// No description provided for @ageCheckSeeSolutions.
  ///
  /// In en, this message translates to:
  /// **'See solutions (18+)'**
  String get ageCheckSeeSolutions;

  /// No description provided for @clearCompletedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} completed download(s)?'**
  String clearCompletedConfirm(int count);

  /// No description provided for @filesDeletedFromDisk.
  ///
  /// In en, this message translates to:
  /// **'Their files will be deleted from your disk. This can\'t be undone.'**
  String get filesDeletedFromDisk;

  /// No description provided for @archivePurgeSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get archivePurgeSelect;

  /// No description provided for @archivePurgeSelectTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select collections to delete their videos'**
  String get archivePurgeSelectTooltip;

  /// No description provided for @archivePurgeSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String archivePurgeSelectedCount(int count);

  /// No description provided for @archivePurgeAction.
  ///
  /// In en, this message translates to:
  /// **'Delete their videos'**
  String get archivePurgeAction;

  /// No description provided for @archivePurgeMenu.
  ///
  /// In en, this message translates to:
  /// **'Delete the downloaded videos'**
  String get archivePurgeMenu;

  /// No description provided for @archivePurgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the videos of {count} collection(s)?'**
  String archivePurgeTitle(int count);

  /// No description provided for @archivePurgeBody.
  ///
  /// In en, this message translates to:
  /// **'{videos} videos leave the archive and {files} downloaded files are permanently deleted from your disk. The collections are removed.'**
  String archivePurgeBody(int videos, int files);

  /// No description provided for @archivePurgeKept.
  ///
  /// In en, this message translates to:
  /// **'{count} videos that are also in a collection you keep are kept.'**
  String archivePurgeKept(int count);

  /// No description provided for @archivePurgeDone.
  ///
  /// In en, this message translates to:
  /// **'{files} files deleted, {videos} videos removed'**
  String archivePurgeDone(int files, int videos);

  /// No description provided for @archiveVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Video from {date}'**
  String archiveVideoTitle(String date);

  /// No description provided for @settingsToolsSection.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get settingsToolsSection;

  /// No description provided for @transferAddressTooltip.
  ///
  /// In en, this message translates to:
  /// **'Your address on this Wi-Fi: other devices connect to it'**
  String get transferAddressTooltip;

  /// No description provided for @designHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'What are we\ndownloading?'**
  String get designHeroTitle;

  /// No description provided for @designPasteHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a YouTube, TikTok, Instagram, X… link'**
  String get designPasteHint;

  /// No description provided for @designDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get designDownload;

  /// No description provided for @designClipboardFound.
  ///
  /// In en, this message translates to:
  /// **'Link found in the clipboard'**
  String get designClipboardFound;

  /// No description provided for @designTodayCaption.
  ///
  /// In en, this message translates to:
  /// **'downloads · {size}'**
  String designTodayCaption(String size);

  /// No description provided for @designInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get designInProgress;

  /// No description provided for @designPauseAll.
  ///
  /// In en, this message translates to:
  /// **'Pause all'**
  String get designPauseAll;

  /// No description provided for @designResumeAll.
  ///
  /// In en, this message translates to:
  /// **'Resume all'**
  String get designResumeAll;

  /// No description provided for @designRemaining.
  ///
  /// In en, this message translates to:
  /// **'{eta} left'**
  String designRemaining(String eta);

  /// No description provided for @designQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get designQueue;

  /// No description provided for @designSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get designSeeAll;

  /// No description provided for @designStorageDrive.
  ///
  /// In en, this message translates to:
  /// **'Storage · {drive}'**
  String designStorageDrive(String drive);

  /// No description provided for @designFree.
  ///
  /// In en, this message translates to:
  /// **'{size} free'**
  String designFree(String size);

  /// No description provided for @designFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get designFilterAll;

  /// No description provided for @designFilterVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get designFilterVideo;

  /// No description provided for @designFilterAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get designFilterAudio;

  /// No description provided for @designFilterImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get designFilterImages;

  /// No description provided for @designFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get designFailed;

  /// No description provided for @designNothingActive.
  ///
  /// In en, this message translates to:
  /// **'Nothing is downloading. Paste a link to start.'**
  String get designNothingActive;

  /// No description provided for @designQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting'**
  String get designQueueEmpty;

  /// No description provided for @designLibraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty for now.'**
  String get designLibraryEmpty;

  /// No description provided for @designArchivesTab.
  ///
  /// In en, this message translates to:
  /// **'Archives'**
  String get designArchivesTab;

  /// No description provided for @studioItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 items} =1{1 item} other{{count} items}}'**
  String studioItems(int count);

  /// No description provided for @studioLiveCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in progress'**
  String studioLiveCount(int count);

  /// No description provided for @studioPasteLink.
  ///
  /// In en, this message translates to:
  /// **'Paste a link'**
  String get studioPasteLink;

  /// No description provided for @studioColState.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get studioColState;

  /// No description provided for @studioAutoStart.
  ///
  /// In en, this message translates to:
  /// **'Start automatically'**
  String get studioAutoStart;

  /// No description provided for @studioChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get studioChange;

  /// No description provided for @studioTools.
  ///
  /// In en, this message translates to:
  /// **'Download tools'**
  String get studioTools;

  /// No description provided for @studioChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get studioChecking;

  /// No description provided for @studioReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get studioReplay;

  /// No description provided for @studioDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get studioDecrease;

  /// No description provided for @studioIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get studioIncrease;
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
