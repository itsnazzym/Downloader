// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'TapLoad';

  @override
  String get downloads => 'التنزيلات';

  @override
  String get statistics => 'الإحصائيات';

  @override
  String get settings => 'الإعدادات';

  @override
  String get appearance => 'المظهر';

  @override
  String get plugins => 'الإضافات';

  @override
  String get newDownload => 'تنزيل جديد';

  @override
  String get pasteUrl => 'الصق الرابط هنا';

  @override
  String get xCdnUrlRejected =>
      'الصق رابط التغريدة (x.com/.../status/...) وليس ملف الفيديو.';

  @override
  String get unsupportedDownloadUrl =>
      'هذه الصفحة ليست فيديو قابل للتنزيل (دعوة أو موقع غير مدعوم).';

  @override
  String get startDownload => 'بدء التنزيل';

  @override
  String get cancel => 'إلغاء';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get delete => 'حذف';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get resume => 'استئناف';

  @override
  String get openFile => 'فتح الملف';

  @override
  String get openFolder => 'فتح المجلد';

  @override
  String get clearHistory => 'مسح السجل';

  @override
  String get selectAll => 'تحديد الكل';

  @override
  String get deselectAll => 'إلغاء تحديد الكل';

  @override
  String get statusQueued => 'في الانتظار';

  @override
  String get statusDownloading => 'جاري التنزيل';

  @override
  String get statusCompleted => 'مكتمل';

  @override
  String get statusFailed => 'فشل';

  @override
  String get statusCanceled => 'تم الإلغاء';

  @override
  String get statusPaused => 'متوقف مؤقتاً';

  @override
  String get statusExtracting => 'جاري الاستخراج';

  @override
  String get statusDuplicate => 'مكرر';

  @override
  String get sidebarAll => 'الكل';

  @override
  String get sidebarActive => 'النشطة';

  @override
  String get sidebarCompleted => 'المكتملة';

  @override
  String get sidebarFailed => 'الفاشلة';

  @override
  String get sidebarBySource => 'حسب المصدر';

  @override
  String get settingsGeneral => 'عام';

  @override
  String get settingsOutput => 'الإخراج';

  @override
  String get settingsAdvanced => 'متقدم';

  @override
  String get settingsPerformance => 'الأداء';

  @override
  String get settingsSystem => 'النظام';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsPlugins => 'الإضافات';

  @override
  String get audioOnly => 'صوت فقط';

  @override
  String get audioOnlyDesc => 'استخراج الصوت فقط (MP3) من الفيديوهات';

  @override
  String get autoStart => 'بدء تلقائي';

  @override
  String get autoStartDesc => 'بدء التنزيلات فوراً عند إضافتها';

  @override
  String get preferredQuality => 'الجودة المفضلة';

  @override
  String get maxConcurrent => 'الحد الأقصى للتنزيلات المتزامنة';

  @override
  String get outputFolder => 'مجلد الإخراج';

  @override
  String get chooseFolder => 'اختيار مجلد';

  @override
  String get useCookies => 'استخدام ملفات تعريف الارتباط';

  @override
  String get useCookiesDesc =>
      'استخدام ملفات تعريف الارتباط من المتصفح للمصادقة';

  @override
  String get useProxy => 'استخدام وكيل';

  @override
  String get useProxyDesc => 'توجيه التنزيلات عبر خادم وكيل';

  @override
  String get minimizeToTray => 'تصغير إلى شريط المهام';

  @override
  String get minimizeToTrayDesc => 'تصغير إلى شريط النظام بدلاً من الإغلاق';

  @override
  String get autoStartApp => 'بدء مع ويندوز';

  @override
  String get autoStartAppDesc => 'تشغيل التطبيق عند بدء النظام';

  @override
  String get autoUpdateYtDlp => 'تحديث تلقائي yt-dlp';

  @override
  String get autoUpdateYtDlpDesc => 'التحقق من تحديثات yt-dlp عند بدء التشغيل';

  @override
  String get showNotifications => 'الإشعارات';

  @override
  String get showNotificationsDesc => 'إشعارات سطح المكتب للتنزيلات';

  @override
  String get clipboardMonitor => 'مراقبة الحافظة';

  @override
  String get clipboardMonitorDesc => 'الكشف التلقائي عن الروابط من الحافظة';

  @override
  String get language => 'اللغة';

  @override
  String get languageDesc => 'اختر لغتك المفضلة';

  @override
  String get theme => 'السمة';

  @override
  String get themeDesc => 'اختيار سمة التطبيق';

  @override
  String get accentColor => 'لون التمييز';

  @override
  String get accentColorDesc => 'تخصيص لون التمييز';

  @override
  String get darkMode => 'الوضع الداكن';

  @override
  String get lightMode => 'الوضع الفاتح';

  @override
  String get systemMode => 'النظام';

  @override
  String get totalDownloads => 'إجمالي التنزيلات';

  @override
  String get downloadsToday => 'تنزيلات اليوم';

  @override
  String get totalData => 'إجمالي البيانات';

  @override
  String get freeSpace => 'المساحة المتاحة';

  @override
  String get last7Days => 'النشاط (آخر 7 أيام)';

  @override
  String get sourceDistribution => 'توزيع المصادر';

  @override
  String get keyboardShortcuts => 'اختصارات لوحة المفاتيح';

  @override
  String get newDownloadShortcut => 'تنزيل جديد';

  @override
  String get settingsShortcut => 'فتح الإعدادات';

  @override
  String get dashboardShortcut => 'لوحة المعلومات';

  @override
  String get minimizeShortcut => 'تصغير';

  @override
  String get inspector => 'المفتش';

  @override
  String get title => 'العنوان';

  @override
  String get status => 'الحالة';

  @override
  String get progress => 'التقدم';

  @override
  String get logs => 'السجلات';

  @override
  String get selectDownload => 'اختر تنزيلاً';

  @override
  String get checkDependencies => 'فحص المتطلبات';

  @override
  String get checkDependenciesDesc => 'فحص حالة yt-dlp و ffmpeg و aria2c';

  @override
  String get verifyingBinaries => 'جاري التحقق من الملفات...';

  @override
  String get dependenciesVerified => 'تم التحقق من المتطلبات';

  @override
  String get organizeLibrary => 'تنظيم المكتبة';

  @override
  String get organizeLibraryDesc =>
      'ترتيب الملفات حسب المصدر، نقل الصور المصغرة، تنظيف الملفات المؤقتة';

  @override
  String get organizationComplete => 'اكتمل التنظيم';

  @override
  String filesMoved(int count) {
    return 'الملفات المنقولة: $count';
  }

  @override
  String filesDeleted(int count) {
    return 'الملفات المؤقتة المحذوفة: $count';
  }

  @override
  String get noPluginsInstalled => 'لا توجد إضافات مثبتة';

  @override
  String get pluginEnabled => 'مفعّلة';

  @override
  String get pluginDisabled => 'معطّلة';

  @override
  String get builtIn => 'مدمجة';

  @override
  String get mediaPlayer => 'مشغل الوسائط';

  @override
  String get playbackSpeed => 'سرعة التشغيل';

  @override
  String get volume => 'مستوى الصوت';

  @override
  String get ok => 'موافق';

  @override
  String get confirm => 'تأكيد';

  @override
  String get close => 'إغلاق';

  @override
  String get save => 'حفظ';

  @override
  String get back => 'رجوع';

  @override
  String get search => 'بحث';

  @override
  String get noResults => 'لم يتم العثور على نتائج';

  @override
  String get loading => 'جاري التحميل...';

  @override
  String get error => 'خطأ';

  @override
  String get success => 'نجاح';

  @override
  String get warning => 'تحذير';

  @override
  String get librarySection => 'المكتبة';

  @override
  String get sourcesSection => 'المصادر';

  @override
  String get mainPage => 'الرئيسية';

  @override
  String get allDownloads => 'كل التنزيلات';

  @override
  String get downloadStarted => 'بدأ التنزيل';

  @override
  String videosDownloadingCount(int count) {
    return '$count فيديوهات قيد التنزيل';
  }

  @override
  String get videoDownloadingSingular => 'فيديو واحد قيد التنزيل';

  @override
  String get expandDownloadingVideos => 'إظهار الفيديوهات قيد التنزيل';

  @override
  String get collapseDownloadingVideos => 'إخفاء الفيديوهات قيد التنزيل';

  @override
  String moreDownloadingVideos(int count) {
    return '+$count';
  }

  @override
  String get searchDownloads => 'تصفية العناوين أو الروابط';

  @override
  String get searchClear => 'مسح البحث';

  @override
  String searchMatchCount(int visible, int total) {
    return '$visible / $total';
  }

  @override
  String get clearHistoryConfirm =>
      'هل تريد حذف التنزيلات المكتملة والفاشلة والملغاة؟ ستبقى التنزيلات النشطة.';

  @override
  String get refreshLibrary => 'تحديث المكتبة';

  @override
  String get yourListIsEmpty => 'قائمة التنزيلات فارغة.';

  @override
  String get sortAndView => 'الترتيب والعرض';

  @override
  String get sortBy => 'ترتيب حسب';

  @override
  String get sortDateNewest => 'التاريخ (الأحدث)';

  @override
  String get sortDateOldest => 'التاريخ (الأقدم)';

  @override
  String get sortNameAsc => 'الاسم (أ-ي)';

  @override
  String get sortSizeLargest => 'الحجم (الأكبر)';

  @override
  String get sortVideoCount => 'عدد الفيديوهات';

  @override
  String get viewMode => 'وضع العرض';

  @override
  String get viewList => 'قائمة';

  @override
  String get viewDetailed => 'مفصل';

  @override
  String get viewFolders => 'مجلدات';

  @override
  String get folderUnknownCreator => 'غير معروف';

  @override
  String get folderBack => 'العودة إلى المجلدات';

  @override
  String get folderOpenHint => 'فتح المجلد';

  @override
  String folderVideoCount(int count) {
    return '$count فيديو';
  }

  @override
  String playlistDetected(int count) {
    return 'تم اكتشاف قائمة تشغيل ($count فيديو)';
  }

  @override
  String downloadSelected(int count) {
    return 'تنزيل المحدد ($count)';
  }

  @override
  String startedCountDownloads(int count) {
    return 'بدأ $count تنزيلات';
  }

  @override
  String get downloadFolder => 'مجلد التنزيل';

  @override
  String get selectFolder => 'اختر مجلداً...';

  @override
  String get organizeBySite => 'تنظيم حسب الموقع';

  @override
  String get organizeBySiteDesc => 'إنشاء مجلدات فرعية مثل Downloads/YouTube/';

  @override
  String get organizeByCreator => 'تنظيم حسب المنشئ';

  @override
  String get organizeByCreatorDesc =>
      'إنشاء مجلدات فرعية لكل حساب (مثل TikTok/userxxx/)';

  @override
  String get formatLabel => 'الصيغة';

  @override
  String get adultSites => 'مواقع للبالغين';

  @override
  String get adultSitesDesc => 'تفعيل المحتوى المقيد بالعمر';

  @override
  String get doNotDisturb => 'عدم الإزعاج';

  @override
  String get doNotDisturbDesc => 'كتم إشعارات التطبيق والإضافة';

  @override
  String get cookiesFromBrowser => 'ملفات تعريف الارتباط من المتصفح';

  @override
  String get extensionApiToken => 'رمز API للإضافة';

  @override
  String get localServerPort => 'منفذ الخادم المحلي';

  @override
  String get backupHistory => 'نسخ السجل احتياطياً';

  @override
  String get restoreHistory => 'استعادة السجل';

  @override
  String get restoreHistoryDesc => 'استيراد التنزيلات من ملف نسخ احتياطي';

  @override
  String get cookiesFile => 'ملف ملفات تعريف الارتباط';

  @override
  String get simultaneousDownloads => 'التنزيلات المتزامنة';

  @override
  String get simultaneousDownloadsDesc => 'الحد الأقصى للتنزيلات النشطة';

  @override
  String get threadsPerDownload => 'المسارات لكل تنزيل';

  @override
  String get threadsPerDownloadDesc => 'الاتصالات المتوازية لكل ملف';

  @override
  String get maxSpeedMode => 'وضع السرعة القصوى';

  @override
  String get maxSpeedModeDesc => '64 اتصالاً متوازياً، مخازن أكبر، remux سريع';

  @override
  String get libraryManagement => 'إدارة المكتبة';

  @override
  String get smartOrganization => 'تنظيم ذكي';

  @override
  String get smartOrganizationDesc => 'قواعد الفرز التلقائي والتخمين الذكي';

  @override
  String get outputFolderNotConfigured => 'مجلد الإخراج غير مهيأ';

  @override
  String get pluginsEmptyHint => 'تضيف الإضافات وظائف إلى TapLoad';

  @override
  String get statusProcessing => 'معالجة';

  @override
  String get statsSubtitle => 'تتبع نشاط التنزيل واستخدام التخزين';

  @override
  String get statsToday => 'اليوم';

  @override
  String get downloadActivity => 'نشاط التنزيل';

  @override
  String get last7DaysShort => 'آخر 7 أيام';

  @override
  String get sourcesChartTitle => 'المصادر';

  @override
  String get sourcesByPlatform => 'حسب المنصة';

  @override
  String get shortcutsQuickActions => 'إجراءات سريعة';

  @override
  String get noDownloadHistory => 'لا يوجد سجل تنزيلات بعد';

  @override
  String get noSourceData => 'لا توجد بيانات مصادر';

  @override
  String chartDownloadsTooltip(int count, String bytes) {
    return '$count تنزيلات\n$bytes';
  }

  @override
  String get currentAccent => 'اللون الحالي';

  @override
  String get dataAndHistory => 'البيانات والسجل';

  @override
  String get exportHistoryDesc => 'تصدير سجل التنزيلات إلى ملف JSON';

  @override
  String get saveHistoryBackup => 'حفظ نسخة السجل';

  @override
  String get tokenCopied => 'تم نسخ الرمز';

  @override
  String get tokenCopiedHint => 'تم نسخ الرمز. الصقه في إضافة المتصفح.';

  @override
  String get copyToken => 'نسخ الرمز';

  @override
  String get portSavedRestart => 'تم حفظ المنفذ. أعد تشغيل التطبيق للتطبيق.';

  @override
  String get historyExported => 'تم تصدير السجل بنجاح';

  @override
  String get historyRestored => 'تمت استعادة السجل بنجاح';

  @override
  String get generatedOnFirstLaunch => 'يُنشأ عند أول تشغيل';

  @override
  String serverPortRestartHint(int port) {
    return 'أعد تشغيل التطبيق بعد التغيير. الحالي: $port';
  }

  @override
  String get torBypassDesc =>
      'شغّل Tor في الخلفية ومرّر التنزيلات عبره (127.0.0.1:9050)';

  @override
  String get torProxyStarting => 'جارٍ تشغيل Tor…';

  @override
  String get torProxyReady => 'Tor جاهز على 127.0.0.1:9050';

  @override
  String get torProxyExisting => 'وكيل Tor يعمل بالفعل على 127.0.0.1:9050';

  @override
  String get torProxyStopped => 'Tor متوقف';

  @override
  String get torProxyFailed => 'Tor غير متاح';

  @override
  String get selectCookiesFile => 'اختر cookies.txt';

  @override
  String get clearCookies => 'مسح ملفات تعريف الارتباط';

  @override
  String get selectQuality => 'اختر الجودة';

  @override
  String get unknownSize => 'حجم غير معروف';

  @override
  String get bestQuality => 'أفضل جودة';

  @override
  String get noLogsAvailable => 'لا توجد سجلات';

  @override
  String get dropLinksHere => 'أسقط الروابط أو الملفات هنا';

  @override
  String get dropLinksHint => 'ستُضاف إلى قائمة التنزيل';

  @override
  String get retryDownload => 'إعادة التنزيل';

  @override
  String get restartDownload => 'إعادة تشغيل التنزيل';

  @override
  String get copyUrl => 'نسخ الرابط';

  @override
  String get remove => 'إزالة';

  @override
  String get urlLabel => 'الرابط';

  @override
  String get pleaseEnterUrl => 'يرجى إدخال رابط';

  @override
  String get enterValidUrl => 'أدخل رابط http(s) صالحاً';

  @override
  String get cookiesNoneDefault => 'بدون (افتراضي)';

  @override
  String get failedFetchQuality => 'تعذر جلب خيارات الجودة';

  @override
  String get unknown => 'غير معروف';

  @override
  String get inspectorId => 'المعرف';

  @override
  String get storageUsage => 'استخدام التخزين';

  @override
  String get storageInfoUnavailable => 'معلومات التخزين غير متاحة';

  @override
  String get storageUsed => 'مستخدم';

  @override
  String get storageFree => 'متاح';

  @override
  String storageTotalLabel(String size) {
    return 'الإجمالي: $size';
  }

  @override
  String get storageFolder => 'المجلد';

  @override
  String get storageOtherUsed => 'مستخدم آخر';

  @override
  String storageFolderOfUsed(String percent) {
    return '$percent% من المستخدم';
  }

  @override
  String storageFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملفات',
      one: 'ملف واحد',
      zero: '0 ملف',
    );
    return '$_temp0';
  }

  @override
  String get storageTypeVideo => 'فيديو';

  @override
  String get storageTypeAudio => 'صوت';

  @override
  String get storageTypeOther => 'أخرى';

  @override
  String get storageTopSubfolders => 'أكبر المجلدات';

  @override
  String get storageScanInProgress => 'جارٍ تحليل المجلد...';

  @override
  String storageLastScanned(String time) {
    return 'تم التحليل الساعة $time';
  }

  @override
  String get storageScanCached => 'مخزّن مؤقتاً';

  @override
  String get storageScanError => 'تعذر قراءة هذا المجلد';

  @override
  String get startingOrganization => 'بدء التنظيم...';

  @override
  String organizationFailed(String error) {
    return 'فشل التنظيم: $error';
  }

  @override
  String thumbnailsOrganized(int count) {
    return 'الصور المصغرة المنظمة: $count';
  }

  @override
  String foldersCreated(int count) {
    return 'المجلدات المنشأة: $count';
  }

  @override
  String emptyFoldersDeleted(int count) {
    return 'المجلدات الفارغة المحذوفة: $count';
  }

  @override
  String organizationErrors(int count) {
    return 'حدثت $count أخطاء';
  }

  @override
  String get nameLabel => 'الاسم';

  @override
  String get editRule => 'تعديل القاعدة';

  @override
  String get newRule => 'قاعدة جديدة';

  @override
  String get patternKeywordOrRegex => 'النمط (كلمة أو تعبير نمطي)';

  @override
  String get regexpPattern => 'نمط RegExp';

  @override
  String get containsText => 'يحتوي النص';

  @override
  String get isRegex => 'تعبير نمطي';

  @override
  String get targetSubfolder => 'المجلد الفرعي الهدف';

  @override
  String get active => 'نشط';

  @override
  String get downloadModel => 'تنزيل نموذج';

  @override
  String get selectPopularModel => 'اختر نموذجاً شائعاً:';

  @override
  String get ollamaPullNote =>
      'ملاحظة: يلزم اتصال سريع. راجع سجلات Ollama للمتابعة.';

  @override
  String get smartGuessTitle => 'تخمين ذكي (الذكاء الاصطناعي)';

  @override
  String get smartGuessDesc =>
      'يصنّف الملفات تلقائياً حسب الأنماط أو الذكاء الاصطناعي المحلي.';

  @override
  String get aiMode => 'وضع الذكاء الاصطناعي';

  @override
  String get aiModeOffline => 'دون اتصال (سريع)';

  @override
  String get aiModeOllama => 'Ollama / LocalAI';

  @override
  String get ollamaApiUrl => 'عنوان API لـ Ollama';

  @override
  String get modelName => 'اسم النموذج';

  @override
  String get selectOrTypeModel => 'اختر من القائمة أو اكتب يدوياً';

  @override
  String get refreshModels => 'تحديث النماذج';

  @override
  String get customRules => 'قواعد مخصصة';

  @override
  String get addRule => 'إضافة قاعدة';

  @override
  String get noRulesDefined => 'لا توجد قواعد. أضف واحدة بزر +.';

  @override
  String get organizeExistingFiles => 'تنظيم الملفات الحالية';

  @override
  String get organizeExistingFilesDesc =>
      'افحص مجلداً ونظّم الملفات بالقواعد أو الذكاء الاصطناعي.';

  @override
  String get ollamaMustRun => 'تأكد من تشغيل Ollama (`ollama serve`).';

  @override
  String requestingOllamaPull(String model) {
    return 'جاري سحب النموذج $model عبر Ollama... قد يستغرق ذلك وقتاً.';
  }

  @override
  String organizationCompleteDetail(int scanned, int moved) {
    return 'اكتمل التنظيم. تم فحص $scanned ملفاً ونقل $moved.';
  }

  @override
  String get toolsSection => 'أدوات';

  @override
  String get configurePlugin => 'إعداد الإضافة';

  @override
  String pluginError(String error) {
    return 'خطأ: $error';
  }

  @override
  String get setupPreparing => 'جارٍ تجهيز أدوات التنزيل…';

  @override
  String get setupCheckingTools => 'التحقق من الأدوات المثبتة';

  @override
  String setupDownloading(String name) {
    return 'جارٍ تنزيل $name…';
  }

  @override
  String setupExtracting(String name) {
    return 'جارٍ استخراج $name…';
  }

  @override
  String setupVerifying(String name) {
    return 'جارٍ التحقق من $name…';
  }

  @override
  String get setupUpdatingYtDlp => 'جارٍ تحديث yt-dlp…';

  @override
  String get setupReady => 'كل الأدوات جاهزة';

  @override
  String get setupFailed => 'تعذر تثبيت كل الأدوات';

  @override
  String get setupRetry => 'إعادة المحاولة';

  @override
  String get setupContinueAnyway => 'المتابعة على أي حال';

  @override
  String setupDownloadPercent(int percent) {
    return '$percent%';
  }

  @override
  String get previewSetup => 'التحقق من أدوات التنزيل وإصلاحها';

  @override
  String get previewSetupDesc =>
      'يعيد فحص yt-dlp وffmpeg وaria2c ويثبّت ما ينقص';

  @override
  String get pluginsSectionTitle => 'إضافات سير التنزيل';

  @override
  String get pluginsSectionHint =>
      'تضيف هذه الإضافات إجراءات قبل التنزيل أو بعد اكتماله.';

  @override
  String get browserExtensionsTitle => 'إضافة المتصفح';

  @override
  String get browserExtensionsHint =>
      'أرسل الروابط من المتصفح إلى التطبيق. نقرة واحدة تجهّز الإضافة وتفتح صفحة المتصفح.';

  @override
  String get chromeExtensionTitle => 'Chrome / Edge / Brave';

  @override
  String get chromeExtensionSteps =>
      '1. انقر تثبيت. 2. فعّل وضع المطوّر. 3. تحميل غير مضغوط ثم Ctrl+V للصق المسار.';

  @override
  String get firefoxExtensionTitle => 'Firefox';

  @override
  String get firefoxExtensionSteps =>
      'التثبيت يفتح XPI من GitHub. إذا منع Firefox ذلك، استخدم التثبيت اليدوي (about:debugging).';

  @override
  String get installInChrome => 'تثبيت في Chrome';

  @override
  String get installInFirefox => 'تثبيت في Firefox';

  @override
  String get downloadExtensionZip => 'تنزيل ZIP';

  @override
  String get firefoxManualInstall => 'تثبيت يدوي';

  @override
  String get extensionDownloading => 'جاري تحضير الإضافة…';

  @override
  String get extensionDownloadFailed =>
      'فشل التنزيل. تحقق من الاتصال وحاول مجددا.';

  @override
  String get extensionInstallGuideTitle => 'تثبيت الإضافة';

  @override
  String get extensionInstallInProgress =>
      'لا تغلق هذه النافذة قبل انتهاء التنزيل.';

  @override
  String get extensionInstallClose => 'إغلاق';

  @override
  String get extensionInstallRetry => 'إعادة المحاولة';

  @override
  String get extensionStepDownload => 'تنزيل ملفات الإضافة';

  @override
  String get extensionStepDownloadZip => 'تنزيل ZIP إلى مجلد التنزيلات';

  @override
  String get extensionStepCopyPath => 'نسخ مسار التثبيت';

  @override
  String get extensionStepOpenBrowser => 'فتح صفحة التثبيت في المتصفح';

  @override
  String get extensionStepLaunchFirefox => 'تشغيل مثبت Firefox';

  @override
  String get extensionStepReadyChrome =>
      'جاهز! إعداد لمرة واحدة: في Chrome، وضع المطوّر → تحميل غير مضغوط → Ctrl+V.';

  @override
  String get extensionStepReadyZip =>
      'تم حفظ ZIP. فكّه إذا لزم، أو استخدم التثبيت في Chrome للإعداد التلقائي.';

  @override
  String get extensionStepReadyFirefox =>
      'جاهز! في about:debugging، حمّل manifest.json (المسار منسوخ).';

  @override
  String get extensionStepReadyFirefoxXpi =>
      'جاهز! أكّد تثبيت الإضافة في Firefox؛ وبعد قبولها ستبقى بعد إعادة تشغيل المتصفح. ثم الصق رمز API في الإضافة.';

  @override
  String get extensionStepFirefoxFallback =>
      'تعذر فتح XPI — فتح صفحة التثبيت اليدوي.';

  @override
  String get extensionStepSkippedBrowser =>
      'تم التخطي — Firefox فتح المثبت مباشرة.';

  @override
  String get chromeInstallStarted =>
      'تم نسخ المسار. في Chrome: وضع المطوّر → تحميل غير مضغوط → Ctrl+V.';

  @override
  String get firefoxInstallStarted =>
      'سيثبت Firefox الإضافة. إذا تم الحظر، استخدم التثبيت اليدوي.';

  @override
  String extensionPathCopied(String path) {
    return 'تم نسخ المسار: $path';
  }

  @override
  String get extensionInstallFailed => 'تعذر فتح المتصفح. جرّب تنزيل ZIP.';

  @override
  String get extractingTitle => 'جارٍ استخراج العنوان...';

  @override
  String get extractingSource => 'جارٍ استخراج المصدر...';

  @override
  String get extractingSize => 'جارٍ استخراج الحجم...';

  @override
  String get unknownTitle => 'عنوان غير معروف';

  @override
  String get collapseSidebar => 'طي الشريط الجانبي';

  @override
  String get expandSidebar => 'توسيع الشريط الجانبي';

  @override
  String get collapseInspector => 'طي المفتش';

  @override
  String get expandInspector => 'توسيع المفتش';

  @override
  String get experimentalXFeedSection => 'خلاصة X التجريبية';

  @override
  String get experimentalXFeedGobird => 'استخدام gobird (تجريبي)';

  @override
  String get experimentalXFeedGobirdDesc =>
      'خلاصة الصفحة الرئيسية للقراءة فقط عبر gobird المضمّن. معطّل افتراضيًا. يخالف شروط خدمة X وقد يعرّض الحساب للإيقاف.';

  @override
  String get experimentalXFeedWarning =>
      'تحذير: يستخدم gobird واجهات X خاصة غير رسمية. أنت تتحمّل كل المخاطر. تبقى خلاصة DOM المحلية هي الاحتياطي الافتراضي.';

  @override
  String get experimentalXFeedConsentTitle => 'تفعيل gobird التجريبي؟';

  @override
  String get experimentalXFeedConsentBody =>
      'يستخدم gobird واجهات X غير رسمية، وقد يتوقف دون إشعار، وقد يؤدي إلى إيقاف أو حظر الحساب. تبقى ملفات تعريف الارتباط على هذا الجهاز. تابع فقط إذا قبلت هذه المخاطر.';

  @override
  String get experimentalXFeedConsentConfirm => 'أفهم — تفعيل';

  @override
  String get gobirdBrowser => 'جلسة متصفح gobird';

  @override
  String get gobirdBrowserDesc =>
      'المتصفح المسجّل في X.com لاستخراج ملفات تعريف الارتباط (Chrome أو Firefox)';

  @override
  String get gobirdBinaryStatus => 'ثنائي gobird';

  @override
  String gobirdBinaryFound(String version) {
    return 'موجود: $version';
  }

  @override
  String get gobirdBinaryMissing => 'غير مضمّن — المحرك التجريبي غير متاح';

  @override
  String get gobirdDisableNow => 'إيقاف gobird الآن';

  @override
  String get playerPrevious => 'السابق';

  @override
  String get playerNext => 'التالي';

  @override
  String duplicatesSkipped(int count) {
    return 'تم تخطي $count من العناصر المكررة';
  }

  @override
  String get trayShow => 'إظهار';

  @override
  String get trayExit => 'خروج';

  @override
  String get needTweetLink => 'يلزم رابط التغريدة';

  @override
  String get openFullscreen => 'فتح بملء الشاشة';

  @override
  String get previewUnavailable => 'المعاينة غير متاحة';

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
  String get qualityManual => 'يدوي';

  @override
  String get qualityManualPlus => 'يدوي+';

  @override
  String get notificationDownloadCompleted => 'اكتمل التنزيل';

  @override
  String get notificationDownloadFailed => 'فشل التنزيل';

  @override
  String get notificationLinkDetected => 'تم اكتشاف رابط';

  @override
  String notificationLinkDetectedBody(String url) {
    return 'انقر للتنزيل: $url';
  }

  @override
  String get notificationLinksQueuedTitle => 'روابط في قائمة الانتظار';

  @override
  String notificationLinksQueuedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count روابط في قائمة الانتظار',
      one: 'رابط واحد في قائمة الانتظار',
    );
    return '$_temp0';
  }

  @override
  String get notificationExtensionConnected => 'تم توصيل الإضافة';

  @override
  String get notificationExtensionConnectedBody =>
      'تم توصيل إضافة المتصفح بنجاح.';

  @override
  String get notificationBatchComplete => 'اكتمل التنزيل المجمع';

  @override
  String notificationBatchCompleteBody(int count, String totalSize) {
    return 'اكتمل $count من التنزيلات — $totalSize إجماليًا';
  }

  @override
  String get notificationYtDlpUpdated => 'تم تحديث yt-dlp';

  @override
  String notificationYtDlpUpdatedBody(String version) {
    return 'تم التحديث إلى $version';
  }

  @override
  String get browseX => 'تصفح X';

  @override
  String get browseXHint => 'سجّل الدخول إن لزم، ثم اضغط تنزيل على أي فيديو.';

  @override
  String get mobileLibrary => 'المكتبة';

  @override
  String get shareDownloadStarted => 'بدأ التنزيل من المشاركة';

  @override
  String get transferTitle => 'نقل';

  @override
  String get transferSubtitle => 'نفس Wi-Fi. امسح رمز QR أو اضغط على جهاز.';

  @override
  String get transferPortBusy =>
      'المنفذ 53317 مشغول. رمز QR يعمل؛ قد يفشل LocalSend نحو هذا الجهاز.';

  @override
  String get transferMe => 'هذا الجهاز';

  @override
  String get transferDevices => 'الأجهزة';

  @override
  String get transferPayload => 'ما الذي يُرسل';

  @override
  String get transferSearchCreator => 'ابحث عن منشئ…';

  @override
  String get transferEntireLibrary => 'المكتبة بالكامل';

  @override
  String get transferClearSelection => 'مسح';

  @override
  String transferSelectedFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجلدات',
      one: '$count مجلد',
    );
    return '$_temp0';
  }

  @override
  String get transferNoCreatorMatch => 'لا نتيجة';

  @override
  String get transferNoDevices => 'لا جهاز بعد — امسح رمز QR على الهاتف.';

  @override
  String get transferWaitingNetwork => 'بانتظار عنوان الشبكة…';

  @override
  String get transferKnown => 'جهاز معروف';

  @override
  String get transferSend => 'إرسال';

  @override
  String get transferOtherFolder => 'مجلد آخر…';

  @override
  String get transferSending => 'جارٍ الإرسال…';

  @override
  String get transferPreparing => 'جارٍ تجهيز الملفات…';

  @override
  String get transferCompressing => 'جارٍ إنشاء أرشيف ZIP…';

  @override
  String get transferWaitingPeer => 'في انتظار قبول LocalSend…';

  @override
  String get transferNeedPayload => 'اختر منشئًا أو المكتبة بالكامل أولًا.';

  @override
  String get transferErrorHttp =>
      'تعذر الوصول للهاتف. نفس Wi-Fi ووضع استقبال LocalSend.';

  @override
  String get transferErrorBusy => 'الهاتف مشغول بنقل آخر.';

  @override
  String get transferErrorRejected => 'رفض الهاتف النقل.';

  @override
  String get transferDone => 'تم الإرسال.';

  @override
  String get transferIncomingTitle => 'نقل وارد';

  @override
  String transferIncomingBody(String alias, int count, String size) {
    return '$alias يريد إرسال $count ملفات ($size)';
  }

  @override
  String get transferAccept => 'قبول';

  @override
  String get transferReject => 'رفض';

  @override
  String get transferPeerPinTitle => 'رمز الجهاز';

  @override
  String get transferPeerPinHint => 'الرمز الظاهر على الجهاز الآخر';

  @override
  String get transferTabSend => 'إرسال';

  @override
  String get transferTabReceive => 'استقبال';

  @override
  String get transferDirectIpTitle => 'الاتصال عبر IP';

  @override
  String get transferDirectIpHint => 'مثال: 192.168.1.122';

  @override
  String get transferDirectIpAction => 'اتصال';

  @override
  String get transferScanSubnet => 'مسح الشبكة';

  @override
  String get transferScanningSubnet => 'جاري المسح…';

  @override
  String get transferRetry => 'إعادة المحاولة';

  @override
  String get transferCancel => 'إلغاء';

  @override
  String get transferDirectBrowserUrl => 'رابط المتصفح';

  @override
  String get transferCopyLink => 'نسخ الرابط';

  @override
  String get transferCopied => 'تم النسخ!';

  @override
  String get transferListeningOn => 'جاهز على الشبكة';

  @override
  String transferVideosFound(int count) {
    return '$count موجودة';
  }

  @override
  String transferAlreadyTransferred(int count) {
    return '$count تم نقلها مسبقاً';
  }

  @override
  String transferNewVideos(int count) {
    return '$count جديدة';
  }

  @override
  String transferSendNewOnly(int count) {
    return 'إرسال $count فيديو جديد';
  }

  @override
  String transferSendAll(int count) {
    return 'إرسال الكل ($count)';
  }

  @override
  String get transferOnlyNewToggle => 'إرسال الفيديوهات الجديدة فقط';

  @override
  String transferFolderBreakdown(int newCount, int alreadyCount) {
    return '$newCount جديدة • $alreadyCount منقولة';
  }

  @override
  String get transferForgetDeviceHistory => 'نسيان سجل هذا الجهاز';

  @override
  String get transferHistoryCleared => 'تم مسح سجل النقل';

  @override
  String get onboardingStart => 'ابدأ';

  @override
  String get onboardingNext => 'التالي';

  @override
  String get onboardingDone => 'تم';

  @override
  String get onboardingSkipStep => 'تخطي';

  @override
  String get onboardingSkipAll => 'تخطي الجولة';

  @override
  String get onboardingReplay => 'إعادة الجولة';

  @override
  String get onboardingReplayDesc => 'عرض الجولة مرة أخرى';

  @override
  String get onboardingWelcomeTitle => 'جولة سريعة';

  @override
  String get onboardingWelcomeBody =>
      'نظرة قصيرة على الشاشات الرئيسية. يمكنك التخطي في أي وقت.';

  @override
  String get onboardingNewDownloadTitle => 'تنزيل جديد';

  @override
  String get onboardingNewDownloadBody =>
      'الصق رابطاً أو أرسله من إضافة المتصفح.';

  @override
  String get onboardingLibraryTitle => 'المكتبة';

  @override
  String get onboardingLibraryBody =>
      'صفّ التنزيلات حسب النشط أو المكتمل أو الفاشل.';

  @override
  String get onboardingTopBarTitle => 'شريط الأدوات';

  @override
  String get onboardingTopBarBody =>
      'ابحث وأوقف الطابور وأعد المحاولات الفاشلة.';

  @override
  String get onboardingFoldersTitle => 'مجلدات المنشئين';

  @override
  String get onboardingFoldersBody =>
      'تُجمّع التنزيلات حسب القناة. بدّل القائمة أو المجلدات ثم رتّب.';

  @override
  String get onboardingTransferTitle => 'النقل';

  @override
  String get onboardingTransferBody =>
      'اختر المجلدات وامسح رمز QR ثم اقبل على الجهاز الآخر.';

  @override
  String get onboardingStatsTitle => 'الإحصاءات';

  @override
  String get onboardingStatsBody => 'الإجماليات ومساحة القرص وسجل التنزيلات.';

  @override
  String get onboardingOutputTitle => 'مجلد الإخراج';

  @override
  String get onboardingOutputBody => 'اختر مكان حفظ الملفات.';

  @override
  String get onboardingExtensionTitle => 'إضافة المتصفح';

  @override
  String get onboardingExtensionBody =>
      'ثبّت إضافة كروم أو فايرفوكس لإرسال الروابط إلى هنا.';

  @override
  String get onboardingReadyTitle => 'جاهز';

  @override
  String get onboardingReadyBody => 'أعد الجولة من الإعدادات > عام.';

  @override
  String get pluginFeaturesTitle => 'ميزات التطبيق';

  @override
  String get pluginFeaturesHint =>
      'فعّل الشاشات والأدوات التي تستخدمها فقط. تعطيل الميزة لا يحذفها ولا يحذف بياناتها.';

  @override
  String get pluginRequired => 'أساسي';

  @override
  String get pluginActivate => 'تفعيل الميزة';

  @override
  String get pluginOpen => 'فتح الميزة';

  @override
  String get pluginInactiveTitle => 'الميزة معطّلة';

  @override
  String get pluginInactiveBody =>
      'لا تزال الميزة متاحة وبياناتها محفوظة. يمكنك إعادة تفعيلها من إعدادات الإضافات.';

  @override
  String get pluginManage => 'إدارة الإضافات';

  @override
  String get pluginWebRequest =>
      'طلب موقع TapLoad هذه الميزة. أكّد هنا لإضافتها إلى واجهتك.';

  @override
  String get pluginExternalHint =>
      'تُثبّت هذه الإضافة في المتصفح. اتبع خطوات الإعداد الموجودة أدناه.';

  @override
  String get addSheetTitle => 'تنزيل جديد';

  @override
  String addSheetPasteCopiedLink(String url) {
    return 'لصق الرابط المنسوخ: $url';
  }

  @override
  String get addSheetModeVideo => 'فيديو';

  @override
  String get addSheetModeAudioOnly => 'صوت فقط';

  @override
  String get addSheetBrowserSession => 'جلسة المتصفح';

  @override
  String get addSheetQualityChosen => 'الجودة المختارة';

  @override
  String addSheetQualityChosenWithSize(String size) {
    return 'الجودة المختارة، $size';
  }

  @override
  String get addSheetStarting => 'جارٍ البدء…';

  @override
  String get addSheetDownload => 'تنزيل';

  @override
  String get addSheetPreviewUnavailable =>
      'المعاينة غير متاحة. قد ينجح التنزيل مع ذلك.';

  @override
  String get addSheetAnalyzing => 'جارٍ تحليل الرابط…';

  @override
  String get addSheetUrlHint => 'الصق رابط الفيديو أو الوسائط';

  @override
  String get addSheetValidLink => 'رابط صالح';

  @override
  String get addSheetClear => 'مسح';

  @override
  String get addSheetPaste => 'لصق';

  @override
  String get addSheetInvalidUrl => 'يرجى إدخال رابط صالح.';

  @override
  String get addSheetUnsupportedUrl => 'الرابط غير مدعوم أو النطاق مقيّد.';

  @override
  String addSheetError(String error) {
    return 'خطأ: $error';
  }

  @override
  String get addSheetDetailBest => 'أعلى دقة متاحة';

  @override
  String get addSheetDetail1080 => 'دقة عالية';

  @override
  String get addSheetDetail720 => 'متوازن';

  @override
  String get addSheetDetail480 => 'موفّر للبيانات';

  @override
  String get addSheetDetailAudio => 'صوت مستخرج بأفضل جودة متاحة';

  @override
  String get addSheetReadoutMax => 'الأقصى';

  @override
  String get addSheetUntitledMedia => 'وسائط بلا عنوان';

  @override
  String get sizeUnitKb => 'ك.ب';

  @override
  String get sizeUnitMb => 'م.ب';

  @override
  String get sizeUnitGb => 'ج.ب';

  @override
  String get archiveMobileTitle => 'أرشيف تيك توك';

  @override
  String get archiveMobileFilters => 'عوامل التصفية';

  @override
  String get archiveMobileReset => 'إعادة تعيين';

  @override
  String get archiveMobileType => 'النوع';

  @override
  String get archiveMobileFilterAll => 'الكل';

  @override
  String get archiveMobileFilterFavorites => 'المفضلة';

  @override
  String get archiveMobileFilterLikes => 'الإعجابات';

  @override
  String get archiveMobileYear => 'السنة';

  @override
  String get archiveMobileAllYears => 'الكل';

  @override
  String get archiveMobileApplyFilters => 'تطبيق عوامل التصفية';

  @override
  String get archiveMobileBackToVideos => 'العودة إلى الفيديوهات';

  @override
  String get archiveMobileDownload => 'تنزيل';

  @override
  String get archiveMobileBatchStarted => 'بدأ تنزيل الدفعة';

  @override
  String get archiveMobileSyncTooltip => 'استيراد أو مزامنة';

  @override
  String get archiveMobileBackToLibrary => 'العودة إلى المكتبة';

  @override
  String get archiveMobileBatchRunning => 'تنزيل الدفعة قيد التنفيذ';

  @override
  String archiveMobileSkippedVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فيديو متجاوز',
      many: '$count فيديو متجاوز',
      few: '$count فيديوهات متجاوزة',
      two: 'فيديوان متجاوزان',
      one: 'فيديو واحد متجاوز',
      zero: '$count فيديو متجاوز',
    );
    return '$_temp0';
  }

  @override
  String get archiveMobileStopBatch => 'إيقاف الدفعة';

  @override
  String get archiveMobileSyncingCollections => 'مزامنة المجموعات';

  @override
  String get archiveMobileSyncWaiting =>
      'في انتظار استجابة المتصفح. أبقِ صفحة تيك توك مفتوحة.';

  @override
  String get archiveMobileChipAll => 'الكل';

  @override
  String get archiveMobileSearchHint => 'ابحث عن فيديو أو مجموعة';

  @override
  String get archiveMobileClearSearch => 'مسح البحث';

  @override
  String archiveMobileVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فيديو',
      many: '$count فيديو',
      few: '$count فيديوهات',
      two: 'فيديوان',
      one: 'فيديو واحد',
      zero: '$count فيديو',
    );
    return '$_temp0';
  }

  @override
  String get archiveMobileClearSelection => 'مسح التحديد';

  @override
  String get archiveMobileSelectAll => 'تحديد الكل';

  @override
  String get archiveMobileManageCollections => 'إدارة المجموعات';

  @override
  String get archiveMobilePlayFullscreen => 'تشغيل الفيديوهات بملء الشاشة';

  @override
  String get archiveMobileNoVideos => 'لم يتم العثور على أي فيديو';

  @override
  String get archiveMobileVideoAdded => 'تمت إضافة الفيديو إلى قائمة التنزيل.';

  @override
  String archiveMobileTileLabel(String date) {
    return 'فيديو $date';
  }

  @override
  String get archiveMobileProgress => 'التقدم';

  @override
  String archiveMobileSelectedLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'محدد',
      one: 'محدد',
    );
    return '$_temp0';
  }

  @override
  String get statsMobileBackToLibrary => 'العودة إلى المكتبة';

  @override
  String get statsMobileTotalSinceInstall => 'إجمالي ما تم تنزيله منذ التثبيت';

  @override
  String get statsMobileActivity => 'النشاط';

  @override
  String get statsMobileLast12Weeks => 'آخر 12 أسبوعًا';

  @override
  String get statsMobileLess => 'أقل';

  @override
  String get statsMobileMore => 'أكثر';

  @override
  String get statsMobileBySource => 'التنزيلات حسب المصدر';

  @override
  String statsMobileDownloadsSummary(int total, int today) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total تنزيل',
      many: '$total تنزيلًا',
      few: '$total تنزيلات',
      two: 'تنزيلان',
      one: 'تنزيل واحد',
      zero: '$total تنزيل',
    );
    return '$_temp0، $today اليوم';
  }

  @override
  String get statsMobileHeatmapLabel => 'خريطة حرارية للتنزيلات اليومية';

  @override
  String get statsMobileOthers => 'أخرى';

  @override
  String get statsMobileUnitB => 'بايت';

  @override
  String get statsMobileUnitKB => 'ك.ب';

  @override
  String get statsMobileUnitMB => 'م.ب';

  @override
  String get statsMobileUnitGB => 'ج.ب';

  @override
  String get statsMobileUnitTB => 'ت.ب';

  @override
  String get settingsHubEngine => 'محرك yt-dlp';

  @override
  String get settingsHubUnavailable => 'غير متاح';

  @override
  String get settingsHubChecking => 'جارٍ التحقق…';

  @override
  String get settingsHubCheckUpdates => 'التحقق من التحديثات';

  @override
  String get settingsHubAutoUpdate => 'التحديث التلقائي';

  @override
  String get settingsHubChannel => 'قناة التحديث';

  @override
  String get settingsHubChannelNightly => 'ليلي';

  @override
  String get settingsHubChannelStable => 'مستقر';

  @override
  String get settingsHubUpdateFailed => 'تعذّر التحقق، حاول لاحقًا.';

  @override
  String get settingsHubUpToDate => 'yt-dlp محدّث بالفعل';

  @override
  String get settingsHubUpdated => 'تم تحديث yt-dlp';

  @override
  String settingsHubUpdateError(String error) {
    return 'خطأ في التحديث: $error';
  }

  @override
  String get settingsHubParallel => 'التنزيلات المتوازية';

  @override
  String get settingsHubParallelHint => 'سرعة أكبر وحرارة أعلى';

  @override
  String get settingsHubStorage => 'التخزين';

  @override
  String settingsHubStorageFree(String free, String total) {
    return '$free متاح من $total';
  }

  @override
  String get settingsHubWifiOnly => 'الواي فاي فقط';

  @override
  String get settingsHubWifiOnlyHint => 'عدم بدء أي تنزيل عبر بيانات الجوال';

  @override
  String get detailsWifiOnlyHeadline =>
      'خيار الواي فاي فقط مفعّل: اتصل بالواي فاي ثم أعد المحاولة';

  @override
  String get detailsStatusFailed => 'فشل';

  @override
  String get detailsStatusDownloading => 'جارٍ التنزيل';

  @override
  String get detailsStatusExtracting => 'جارٍ تحليل الرابط';

  @override
  String get detailsStatusDuplicate => 'مضاف مسبقًا';

  @override
  String get detailsDiagnostic => 'التشخيص';

  @override
  String get detailsStepResolve => 'تحليل الرابط';

  @override
  String get detailsStepReadPage => 'قراءة الصفحة';

  @override
  String get detailsStepExtractFormats => 'استخراج الصيغ';

  @override
  String get detailsStepDownload => 'التنزيل';

  @override
  String get detailsStepMerge => 'دمج الصوت والفيديو';

  @override
  String get detailsStepFailMerge => 'فشل تجميع الملف';

  @override
  String get detailsStepFailTransfer => 'تم قطع النقل';

  @override
  String get detailsStepFailNoMedia => 'لا توجد وسائط متاحة';

  @override
  String detailsEngineUpdated(String status) {
    return 'تم تحديث المحرك: $status';
  }

  @override
  String detailsYtDlpUpdateSuccess(String status) {
    return 'نجح تحديث yt-dlp: $status';
  }

  @override
  String detailsEngineUpdateError(String error) {
    return 'حدث خطأ أثناء التحديث: $error';
  }

  @override
  String get detailsLinkCopied => 'تم نسخ الرابط إلى الحافظة';

  @override
  String get detailsShare => 'مشاركة';

  @override
  String get detailsOpenWith => 'فتح باستخدام';

  @override
  String get detailsCopyLink => 'نسخ الرابط';

  @override
  String get detailsRestart => 'إعادة البدء';

  @override
  String get detailsPlayVideo => 'تشغيل الفيديو';

  @override
  String get detailsInfoTitle => 'المعلومات';

  @override
  String get detailsInfoSource => 'المصدر';

  @override
  String get detailsInfoSize => 'الحجم';

  @override
  String get detailsInfoFile => 'الملف';

  @override
  String get detailsInfoId => 'المعرّف';

  @override
  String get detailsUpdatingEngine => 'جارٍ تحديث المحرك…';

  @override
  String get detailsRepairAuto => 'إصلاح تلقائي';

  @override
  String get detailsSignInBrowser => 'تسجيل الدخول في المتصفح';

  @override
  String get detailsAgeSolutions => 'عرض الحلول (+18)';

  @override
  String get detailsTechnicalDetails => 'التفاصيل التقنية';

  @override
  String get detailsNoLogs => 'لا يوجد سجل متاح.';

  @override
  String get detailsCopyLogs => 'نسخ السجلات';

  @override
  String get detailsLogsCopied => 'تم نسخ السجلات';

  @override
  String get detailsHeadlineAgeVerification => 'التحقق من العمر مطلوب';

  @override
  String detailsHeadlineHostRefused(String host) {
    return 'رفض $host الطلب';
  }

  @override
  String get detailsHeadlineTooManyRequests => 'طلبات كثيرة جدًا، الوصول مقيّد';

  @override
  String get detailsHeadlinePrivateVideo => 'فيديو خاص أو محذوف';

  @override
  String get detailsHeadlineGeoBlocked => 'المحتوى محظور في بلدك';

  @override
  String get detailsHeadlineCopyright => 'تمت إزالته بسبب حقوق النشر';

  @override
  String get detailsHeadlineSuspended => 'الحساب أو المحتوى معلّق';

  @override
  String get detailsHeadlineNoMedia => 'لا توجد وسائط في هذا الرابط';

  @override
  String get detailsHeadlineUnsupportedUrl => 'الرابط غير مدعوم';

  @override
  String get detailsHeadlineUnavailable => 'المحتوى غير متاح';

  @override
  String get detailsHeadlineLiveOffline => 'البث المباشر غير متصل';

  @override
  String get detailsHeadlineAntiBot => 'تم اكتشاف حماية ضد الروبوتات';

  @override
  String get detailsHeadlineNoFormats => 'لا توجد صيغة متاحة';

  @override
  String get detailsHeadlineLoginRequired => 'تسجيل الدخول مطلوب';

  @override
  String get detailsHeadlineNetwork => 'مشكلة في الشبكة';

  @override
  String get detailsHeadlineFailed => 'فشل التنزيل';

  @override
  String downloadCardDeleteConfirm(String title) {
    return 'هل تريد حذف \"$title\"؟';
  }

  @override
  String get downloadCardAgeVerification => 'التحقق من العمر (+18)، عرض الحلول';

  @override
  String get fileDeletedFromDisk =>
      'سيُحذف الملف من القرص نهائيًا. لا يمكن التراجع عن ذلك.';

  @override
  String downloadCardFailedMeta(String source) {
    return '$source، فشل. عرض التشخيص';
  }

  @override
  String downloadCardQueuePosition(int position) {
    return 'الموضع $position في قائمة الانتظار';
  }

  @override
  String downloadCardSizeOf(String done, String total) {
    return '$done من $total';
  }

  @override
  String get libraryHeaderArchive => 'أرشيف TikTok';

  @override
  String get libraryHeaderFailed => 'الفاشلة';

  @override
  String get libraryHeaderFolders => 'المجلدات';

  @override
  String libraryHeaderMoreActive(int count) {
    return '+$count قيد التنفيذ';
  }

  @override
  String get libraryHeaderLiveSpeed => 'السرعة المباشرة';

  @override
  String libraryHeaderRemaining(String eta) {
    return 'المتبقي $eta';
  }

  @override
  String get libraryHeaderUnitGBps => 'جيجابايت/ث';

  @override
  String get libraryHeaderUnitMBps => 'ميجابايت/ث';

  @override
  String get libraryHeaderUnitKBps => 'كيلوبايت/ث';

  @override
  String get libraryHeaderUnitBps => 'بايت/ث';

  @override
  String clipboardCapsuleCopied(String platform) {
    return 'تم نسخ الرابط، $platform';
  }

  @override
  String get clipboardCapsuleMediaLink => 'رابط وسائط';

  @override
  String get clipboardCapsuleDownload => 'تنزيل';

  @override
  String get clipboardCapsuleDismiss => 'تجاهل';

  @override
  String get shellTabLibrary => 'المكتبة';

  @override
  String get shellTabBrowse => 'تصفح';

  @override
  String get shellTabSend => 'إرسال';

  @override
  String get shellTabSettings => 'الإعدادات';

  @override
  String get browserMobileTitle => 'المتصفح';

  @override
  String get browserMobileBack => 'السابق';

  @override
  String get browserMobileForward => 'التالي';

  @override
  String get browserMobileReload => 'إعادة التحميل';

  @override
  String get browserMobileReadyToDownload => 'الصفحة جاهزة للتنزيل';

  @override
  String get browserMobileDownload => 'تنزيل';

  @override
  String get oledKitStepperLess => 'أقل';

  @override
  String get oledKitStepperMore => 'أكثر';

  @override
  String oledKitFragmentsReceived(int done, int total) {
    return 'تم استلام $done من $total جزءًا';
  }

  @override
  String get settingsTilesNotFound => 'غير موجود';

  @override
  String get settingsOutputChangeFolderTitle => 'تغيير المجلد';

  @override
  String get settingsOutputChangeFolderBody =>
      'هل تريد نقل جميع مقاطع الفيديو والصور المصغرة الحالية تلقائيًا إلى هذا المجلد الجديد؟';

  @override
  String get settingsOutputChangeFolderOnly => 'تغيير المجلد فقط';

  @override
  String get settingsOutputMigrateFiles => 'نقل الملفات';

  @override
  String get settingsOutputMigrateLibraryTitle => 'نقل المكتبة';

  @override
  String get settingsOutputMigrateLibraryDesc =>
      'نقل جميع مقاطع الفيديو والصور المصغرة إلى قرص أو مجلد آخر';

  @override
  String get settingsOutputReorganizeTitle =>
      'إعادة تنظيم مقاطع الفيديو الحالية';

  @override
  String get settingsOutputReorganizeDesc =>
      'ترتيب مقاطع الفيديو التي تم تنزيلها في مجلدات فرعية حسب صانع المحتوى (مع محاكاة)';

  @override
  String get settingsSmartRecommendedRules => 'القواعد الموصى بها';

  @override
  String settingsSystemYtDlpUpdated(String result) {
    return 'تم تحديث yt-dlp: $result';
  }

  @override
  String settingsSystemUpdateError(String error) {
    return 'خطأ في التحديث: $error';
  }

  @override
  String get settingsSystemUpdateEngineTitle => 'تحديث محرك yt-dlp';

  @override
  String get settingsSystemUpdateEngineDownloading =>
      'جارٍ تنزيل أحدث إصدار (nightly)...';

  @override
  String get settingsSystemUpdateEngineDesc =>
      'التحقق من أحدث إصدار من yt-dlp وتثبيته';

  @override
  String transferMobileAddFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إضافة $count مجلدات',
      two: 'إضافة مجلدين',
      one: 'إضافة مجلد واحد',
    );
    return '$_temp0';
  }

  @override
  String get transferMobileBroadcastDone => 'تم بث إشارة الاكتشاف على الشبكة';

  @override
  String get transferMobileBroadcastTooltip => 'بث إعلان على الشبكة';

  @override
  String transferMobileBytesOf(String done, String total) {
    return '$done من $total';
  }

  @override
  String get transferMobileCheckAll => 'تحديد الكل';

  @override
  String get transferMobileUncheckAll => 'إلغاء تحديد الكل';

  @override
  String get transferMobileClearList => 'مسح القائمة';

  @override
  String transferMobileCreatorCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صنّاع محتوى',
      two: 'صانعا محتوى',
      one: 'صانع محتوى واحد',
    );
    return '$_temp0';
  }

  @override
  String get transferMobileDemoNoFiles =>
      'وضع العرض التجريبي: لا يمكن الوصول إلى أي ملف شخصي.';

  @override
  String get transferMobileDemoSendSimulated =>
      'وضع العرض التجريبي: إرسال محاكى، لم يُنقل أي ملف.';

  @override
  String get transferMobileDeviceNotFound =>
      'لم يتم العثور على جهاز في هذا العنوان.';

  @override
  String transferMobileDeviceUnreachable(String address) {
    return 'تعذّر الوصول إلى الجهاز ($address)';
  }

  @override
  String get transferMobileDiagBusy => 'الجهاز المستقبِل مشغول بنقل آخر.';

  @override
  String get transferMobileDiagChecksumMismatch =>
      'خطأ في سلامة البيانات (عدم تطابق المجموع الاختباري).';

  @override
  String get transferMobileDiagCommunication => 'خطأ في الاتصال بالجهاز.';

  @override
  String get transferMobileDiagConnectionRefused =>
      'تم رفض الاتصال. افتح LocalSend على الجهاز المستقبِل وفعّل وضع الاستقبال.';

  @override
  String get transferMobileDiagPinRequired => 'الجهاز المستقبِل يتطلب رمز PIN.';

  @override
  String get transferMobileDiagRejected =>
      'رفض المستخدم النقل على الجهاز المستقبِل.';

  @override
  String get transferMobileDiagTimeout =>
      'انتهت مهلة الاتصال. تأكد من أن الجهاز المستقبِل يعمل وأنه على شبكة Wi-Fi نفسها.';

  @override
  String get transferMobileDiagUnreachable =>
      'تأكد من أن LocalSend مفتوح على هذا الجهاز وأنه على شبكة Wi-Fi نفسها.';

  @override
  String transferMobileFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
    );
    return '$_temp0';
  }

  @override
  String transferMobileFolderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجلدات',
      two: 'مجلدان',
      one: 'مجلد واحد',
    );
    return '$_temp0';
  }

  @override
  String transferMobileFolderPickError(String error) {
    return 'خطأ في اختيار المجلد: $error';
  }

  @override
  String get transferMobileFoldersAction => 'المجلدات...';

  @override
  String get transferMobileVideosAction => 'مقاطع الفيديو...';

  @override
  String get transferMobileHeaderReceiving => 'الاستقبال';

  @override
  String get transferMobileHeaderSending => 'الإرسال';

  @override
  String get transferMobileIpAddress => 'عنوان IP';

  @override
  String get transferMobileKindDesktop => 'حاسوب';

  @override
  String get transferMobileKindHeadless => 'بدون شاشة';

  @override
  String get transferMobileKindMobile => 'هاتف';

  @override
  String get transferMobileKindServer => 'خادم';

  @override
  String get transferMobileKindWeb => 'متصفح';

  @override
  String transferMobileLibraryNewOfTotal(
    String library,
    int newest,
    int found,
  ) {
    return '$library ($newest جديد / $found)';
  }

  @override
  String get transferMobileMarkKnown => 'وضع علامة كجهاز معروف';

  @override
  String get transferMobileUnmarkKnown => 'إزالة من الأجهزة المعروفة';

  @override
  String transferMobileMediaCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملفات وسائط',
      two: 'ملفا وسائط',
      one: 'ملف وسائط واحد',
    );
    return '$_temp0';
  }

  @override
  String get transferMobileMediaFallback => 'وسائط';

  @override
  String transferMobileMediaSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحديد $count ملفات وسائط',
      two: 'تم تحديد ملفي وسائط',
      one: 'تم تحديد ملف وسائط واحد',
    );
    return '$_temp0';
  }

  @override
  String transferMobileNameNewCount(String name, int newest) {
    return '$name ($newest جديد)';
  }

  @override
  String transferMobileNearbyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أجهزة قريبة',
      two: 'جهازان قريبان',
      one: 'جهاز واحد قريب',
      zero: 'لا توجد أجهزة قريبة',
    );
    return '$_temp0';
  }

  @override
  String transferMobileNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فيديوهات جديدة',
      two: 'فيديوان جديدان',
      one: 'فيديو جديد واحد',
    );
    return '$_temp0';
  }

  @override
  String get transferMobileNoDataSent => 'لم تُرسل أي بيانات';

  @override
  String get transferMobileNoFolderMatch => 'لا يوجد مجلد مطابق';

  @override
  String get transferMobilePeerPinExplain =>
      'يحمي هذا الجهاز المستقبِل عمليات الاستقبال برمز PIN محدد في إعدادات LocalSend الخاصة به.\n\nأدخل رمز PIN المضبوط على هاتفك (أو عطّل خيار PIN في إعدادات هاتفك للإرسال بدون رمز).';

  @override
  String transferMobilePeerPinRequired(String alias) {
    return 'رمز PIN مطلوب من $alias';
  }

  @override
  String get transferMobilePinExample => 'مثال: 1234';

  @override
  String get transferMobilePinLabel => 'رمز PIN الأمني';

  @override
  String transferMobilePortAltActive(int port) {
    return 'المنفذ 53317 مشغول. المنفذ البديل $port نشط.';
  }

  @override
  String get transferMobilePortDefault => 'المنفذ (الافتراضي: 53317)';

  @override
  String get transferMobileQrHide => 'إخفاء رمز QR';

  @override
  String get transferMobileQrShow => 'إظهار رمز QR';

  @override
  String get transferMobileQrShowMobileToMobile =>
      'إظهار رمز QR (من هاتف إلى هاتف)';

  @override
  String get transferMobileReadyToReceive => 'جاهز للاستقبال';

  @override
  String get transferMobileReceiveFiles => 'استقبال الملفات';

  @override
  String get transferMobileRefresh => 'تحديث';

  @override
  String get transferMobileRefreshSearch => 'تحديث البحث';

  @override
  String transferMobileScanFolders(int scanned, int total, int videos) {
    String _temp0 = intl.Intl.pluralLogic(
      videos,
      locale: localeName,
      other: '$videos فيديوهات',
      two: 'فيديوان',
      one: 'فيديو واحد',
    );
    return 'المجلدات $scanned / $total ($_temp0)...';
  }

  @override
  String transferMobileScanVideosFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم العثور على $count فيديوهات...',
      two: 'تم العثور على فيديوين...',
      one: 'تم العثور على فيديو واحد...',
    );
    return '$_temp0';
  }

  @override
  String get transferMobileSearchDemoMedia => 'ابحث عن ملف وسائط تجريبي...';

  @override
  String transferMobileSelectedOfTotal(int selected, int total) {
    return '$selected/$total محددة';
  }

  @override
  String get transferMobileShowPinQr => 'إظهار رمز PIN ورمز QR الخاصين بي';

  @override
  String get transferMobileSimulation => 'محاكاة';

  @override
  String get transferMobileSubfoldersFilter => 'تصفية المجلدات الفرعية...';

  @override
  String transferMobileSubfoldersFoundIn(String name) {
    return 'المجلدات الموجودة في $name';
  }

  @override
  String get transferMobileSubfoldersTitle => 'اختيار المجلدات';

  @override
  String get transferMobileUpToDate => 'محدّث';

  @override
  String transferMobileUpToDateCount(int count) {
    return 'محدّث ($count)';
  }

  @override
  String transferMobileVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فيديوهات',
      two: 'فيديوان',
      one: 'فيديو واحد',
    );
    return '$_temp0';
  }

  @override
  String transferMobileVideosZipped(int count) {
    return '$count فيديوهات (مجمّعة في ZIP)';
  }

  @override
  String get transferMobileVisibleOnLan => 'مرئي على الشبكة المحلية';

  @override
  String get transferMobileVisibleOnWifi => 'مرئي على شبكة Wi-Fi المحلية';

  @override
  String get transferMobileZipActive => 'ZIP مفعّل';

  @override
  String get transferMobileZipArchive => 'أرشفة بصيغة ZIP';

  @override
  String get transferMobileZipEnabled => 'أرشيف ZIP: مفعّل';

  @override
  String get transferMobileZipHintLarge =>
      'ZIP مفعّل. مع المجلدات الكبيرة، يؤدي تعطيل ZIP إلى تسريع الإرسال المباشر إلى المعرض.';

  @override
  String get transferMobileZipHintMulti =>
      'عدة ملفات إلى أرشيف ZIP واحد (بدون ضغط، مقاطع الفيديو مضغوطة أصلًا)';

  @override
  String get transferMobileZipHintOff =>
      'تُرسل الملفات كما هي إلى LocalSend (مباشرة إلى المعرض)';

  @override
  String get transferMobileZipTooltip =>
      'تجميع عدة ملفات في أرشيف ZIP واحد (نسخ، بدون ضغط)';

  @override
  String get detailsStepFailMetered => 'يتم استخدام بيانات الجوال';

  @override
  String get archiveMobileCollectionLiked => 'الفيديوهات المعجب بها';

  @override
  String get archiveMobileCollectionUnsortedFavorites => 'المفضلة غير المصنفة';

  @override
  String get browserSniffTitle => 'الوسائط المكتشفة';

  @override
  String get browserSniffHint =>
      'ما حمّلته هذه الصفحة. اختيار أحدها يحمّله بجلسة متصفحك.';

  @override
  String browserSniffCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم اكتشاف $count وسائط',
      two: 'تم اكتشاف وسيطين',
      one: 'تم اكتشاف وسيط واحد',
    );
    return '$_temp0';
  }

  @override
  String get browserSniffOpen => 'التدفقات';

  @override
  String get browserSniffKindHls => 'تدفق HLS';

  @override
  String get browserSniffKindDash => 'تدفق DASH';

  @override
  String get browserSniffKindVideo => 'ملف فيديو';

  @override
  String get browserSniffKindAudio => 'ملف صوتي';

  @override
  String get browserSniffDrmNote =>
      'يتم اكتشاف المحتوى المحمي (DRM) لكن لا يمكن تنزيله.';

  @override
  String get backAgainToExit => 'اضغط رجوع مرة أخرى للخروج';

  @override
  String get archiveHubImport => 'استيراد ملف TikTok';

  @override
  String get archiveHubImportHint => 'اختر ملف JSON المُصدَّر من TikTok.';

  @override
  String get archiveHubPick => 'اختيار ملف';

  @override
  String get archiveHubOpen => 'فتح المكتبة';

  @override
  String archiveHubCollections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجموعات',
      two: 'مجموعتان',
      one: 'مجموعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get archiveHubLoading => 'جارٍ فهرسة مكتبتك…';

  @override
  String get launchWordmark => 'TapLoad';

  @override
  String get launchContinueAnyway => 'المتابعة على أي حال';

  @override
  String get onbSkip => 'تخطي';

  @override
  String get onbNext => 'التالي';

  @override
  String get onbStart => 'ابدأ';

  @override
  String get onbPage1Title => 'الصق رابطًا.\nوانتهى الأمر.';

  @override
  String get onbPage1Body => 'شارك من أي تطبيق، أو المس + لإضافة تنزيل.';

  @override
  String get onbPage2Title => 'تصفّح.\nونحن نكتشف.';

  @override
  String get onbPage2Body =>
      'افتح موقعًا في تبويب الويب. تظهر الوسائط التي يشغّلها جاهزة للحفظ.';

  @override
  String get onbPage3Title => 'مكتبتك،\nبدون إنترنت.';

  @override
  String get onbPage3Body => 'كل شيء مخزّن على هاتفك ويعمل بدون اتصال.';

  @override
  String get onbPage4Title => 'كل شيء جاهز.';

  @override
  String get onbPage4Body => 'شارك رابطًا مع التطبيق، أو المس + للبدء.';

  @override
  String onbPageLabel(int current, int total) {
    return 'الصفحة $current من $total';
  }

  @override
  String etaSeconds(int seconds) {
    return '$seconds ث';
  }

  @override
  String etaMinutesSeconds(int minutes, int seconds) {
    return '$minutes د $seconds ث';
  }

  @override
  String etaHoursMinutes(int hours, int minutes) {
    return '$hours س $minutes د';
  }

  @override
  String get archiveCollSearch => 'ابحث عن مجموعة';

  @override
  String get archiveCollEmpty => 'لم يتم العثور على مجموعة';

  @override
  String get archiveCollShowVideos => 'عرض الفيديوهات';

  @override
  String archiveCollDownloadAll(int count) {
    return 'تنزيل الكل ($count)';
  }

  @override
  String get archiveCollReset => 'إزالة الفيديوهات من هذه المجموعة';

  @override
  String get archiveCollResetTitle => 'إعادة تعيين المجموعة';

  @override
  String archiveCollResetBody(int count, String name) {
    return 'إزالة $count فيديو من «$name»؟ تبقى الفيديوهات ومجموعاتها الأخرى.';
  }

  @override
  String get archiveCollResetConfirm => 'إزالة';

  @override
  String archiveCollResetDone(String name) {
    return 'تم إفراغ «$name»';
  }

  @override
  String get archiveCollDelete => 'حذف المجموعة';

  @override
  String archiveCollDeleteBody(int count, String name) {
    return 'حذف «$name» نهائيًا؟ تبقى فيديوهاتها ($count) على جهازك لكنها تغادر هذا المجلد.';
  }

  @override
  String get archiveCollDeleteConfirm => 'حذف';

  @override
  String archiveCollDeleteDone(String name) {
    return 'تم حذف «$name»';
  }

  @override
  String get archiveCollClear => 'إعادة تعيين الأرشيف بالكامل';

  @override
  String get archiveCollClearBody =>
      'حذف كل المجموعات والتصنيفات واستيراد TikTok المحلي؟ تبقى الفيديوهات التي تم تنزيلها.';

  @override
  String get archiveCollClearConfirm => 'حذف الكل';

  @override
  String get archiveCollClearDone => 'تمت إعادة تعيين أرشيف TikTok';

  @override
  String get libraryPhaseAnalyzing => 'جارٍ تحليل الرابط…';

  @override
  String get libraryPhaseConnecting => 'جارٍ الاتصال بالخادم…';

  @override
  String get libraryPhaseFinalizing => 'جارٍ إنهاء الملف…';

  @override
  String get libraryDoneTitle => 'اكتمل';

  @override
  String get libraryDoneAverage => 'في المتوسط';

  @override
  String libraryDoneSummary(String size, String time) {
    return '$size خلال $time';
  }

  @override
  String get alreadyTitle => 'موجود بالفعل في مكتبتك';

  @override
  String alreadyBody(String title) {
    return '«$title» تم تنزيله من قبل، لذلك لم يُنقل شيء. افتحه أو استبدله بنسخة جديدة.';
  }

  @override
  String get alreadyOpen => 'فتح';

  @override
  String get alreadyReplace => 'تنزيل مرة أخرى';

  @override
  String get alreadyDismiss => 'إغلاق';

  @override
  String get sortFieldDate => 'التاريخ';

  @override
  String get sortFieldName => 'الاسم';

  @override
  String get sortFieldSize => 'الحجم';

  @override
  String get moreActions => 'مزيد من الإجراءات';

  @override
  String get retryFailedAction => 'إعادة محاولة الفاشلة';

  @override
  String retryingFailed(int count) {
    return 'إعادة محاولة $count من التنزيلات الفاشلة';
  }

  @override
  String get pauseActiveAction => 'إيقاف التنزيلات النشطة مؤقتًا';

  @override
  String get pauseActiveTooltip => 'إيقاف كل التنزيلات النشطة مؤقتًا';

  @override
  String get activeDownloadsPaused => 'تم إيقاف التنزيلات النشطة مؤقتًا';

  @override
  String get startQueueAction => 'بدء قائمة الانتظار';

  @override
  String get startQueueTooltip => 'بدء التنزيلات المنتظرة والمتوقفة والفاشلة';

  @override
  String get queueStarted => 'بدأت قائمة الانتظار';

  @override
  String get clearCompletedAction => 'مسح المكتملة';

  @override
  String get clearCompletedDone => 'تم حذف التنزيلات المكتملة';

  @override
  String get clearFailedAction => 'مسح الفاشلة';

  @override
  String get clearFailedDone => 'تم مسح التنزيلات الفاشلة';

  @override
  String get reduceEffects => 'تقليل المؤثرات المرئية';

  @override
  String get reduceEffectsDesc =>
      'يعطّل التمويه والرسوم المتحركة في الخلفية. أكثر سلاسة على الأجهزة المتواضعة.';

  @override
  String get emptyLibraryHint => 'اضغط Ctrl+N والصق رابط فيديو.';

  @override
  String get clearSearchAndFilters => 'مسح البحث والمرشحات';

  @override
  String get inspectorPlayMedia => 'تشغيل الوسائط';

  @override
  String get inspectorSourceUrl => 'رابط المصدر';

  @override
  String get inspectorLocalFile => 'الملف المحلي';

  @override
  String get urlCopied => 'تم نسخ الرابط إلى الحافظة';

  @override
  String get showInFolder => 'إظهار في المجلد';

  @override
  String get detailsAction => 'التفاصيل';

  @override
  String failedRetryBadge(int count) {
    return '$count فاشلة · إعادة المحاولة';
  }

  @override
  String retryAllFailedTooltip(int count) {
    return 'إعادة محاولة كل التنزيلات الفاشلة ($count)';
  }

  @override
  String get ageCheckRequired => 'مطلوب التحقق من العمر (+18)';

  @override
  String get ageCheckSeeSolutions => 'عرض الحلول (+18)';

  @override
  String clearCompletedConfirm(int count) {
    return 'حذف $count من التنزيلات المكتملة؟';
  }

  @override
  String get filesDeletedFromDisk =>
      'ستُحذف ملفاتها من القرص نهائيًا. لا يمكن التراجع عن ذلك.';

  @override
  String get archivePurgeSelect => 'تحديد';

  @override
  String get archivePurgeSelectTooltip => 'حدد مجموعات لحذف فيديوهاتها';

  @override
  String archivePurgeSelectedCount(int count) {
    return '$count محددة';
  }

  @override
  String get archivePurgeAction => 'حذف فيديوهاتها';

  @override
  String get archivePurgeMenu => 'حذف الفيديوهات المنزّلة';

  @override
  String archivePurgeTitle(int count) {
    return 'حذف فيديوهات $count من المجموعات؟';
  }

  @override
  String archivePurgeBody(int videos, int files) {
    return 'ستخرج $videos فيديو من الأرشيف وستُحذف $files ملفات منزّلة نهائيًا من القرص. وستُزال المجموعات.';
  }

  @override
  String archivePurgeKept(int count) {
    return 'سيتم الاحتفاظ بـ $count فيديو موجودة أيضًا في مجموعة تحتفظ بها.';
  }

  @override
  String archivePurgeDone(int files, int videos) {
    return 'حُذفت $files ملفات وأُزيلت $videos فيديو';
  }

  @override
  String archiveVideoTitle(String date) {
    return 'فيديو بتاريخ $date';
  }

  @override
  String get settingsToolsSection => 'الأدوات';

  @override
  String get transferAddressTooltip =>
      'عنوانك على شبكة Wi-Fi هذه: تتصل به الأجهزة الأخرى';

  @override
  String get designHeroTitle => 'ماذا\nسنحمّل؟';

  @override
  String get designPasteHint =>
      'الصق رابط YouTube أو TikTok أو Instagram أو X…';

  @override
  String get designDownload => 'تحميل';

  @override
  String get designClipboardFound => 'تم العثور على رابط في الحافظة';

  @override
  String designTodayCaption(String size) {
    return 'تنزيلات · $size';
  }

  @override
  String get designInProgress => 'قيد التنزيل';

  @override
  String get designPauseAll => 'إيقاف الكل مؤقتًا';

  @override
  String get designResumeAll => 'استئناف الكل';

  @override
  String designRemaining(String eta) {
    return 'متبقٍ $eta';
  }

  @override
  String get designQueue => 'قائمة الانتظار';

  @override
  String get designSeeAll => 'عرض الكل';

  @override
  String designStorageDrive(String drive) {
    return 'التخزين · $drive';
  }

  @override
  String designFree(String size) {
    return '$size متاحة';
  }

  @override
  String get designFilterAll => 'الكل';

  @override
  String get designFilterVideo => 'فيديو';

  @override
  String get designFilterAudio => 'صوت';

  @override
  String get designFilterImages => 'صور';

  @override
  String get designFailed => 'فشل';

  @override
  String get designNothingActive => 'لا يوجد تنزيل الآن. الصق رابطًا للبدء.';

  @override
  String get designQueueEmpty => 'لا شيء في الانتظار';

  @override
  String get designLibraryEmpty => 'مكتبتك فارغة حاليًا.';

  @override
  String get designArchivesTab => 'الأرشيف';

  @override
  String get nocturneGreetingMorning => 'صباح الخير';

  @override
  String get nocturneGreetingAfternoon => 'طاب يومك';

  @override
  String get nocturneGreetingEvening => 'مساء الخير';

  @override
  String nocturneActiveTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تنزيل جارٍ',
      many: '$count تنزيلًا جاريًا',
      few: '$count تنزيلات جارية',
      two: 'تنزيلان جاريان',
      one: 'تنزيل واحد جارٍ',
      zero: 'لا توجد تنزيلات جارية',
    );
    return '$_temp0';
  }

  @override
  String get nocturneNext => 'التالي';

  @override
  String get nocturneRecent => 'آخر التنزيلات';

  @override
  String nocturneSizeOf(String done, String total) {
    return '$done من $total';
  }

  @override
  String get nocturneStatsTitle => 'نشاطك';

  @override
  String get nocturneStatDownloads => 'التنزيلات';

  @override
  String get nocturneStatVolume => 'الحجم المُنزَّل';

  @override
  String nocturneLastDays(int count) {
    return 'آخر $count يومًا';
  }

  @override
  String get nocturnePerDay => 'التنزيلات في اليوم';

  @override
  String nocturneDaysShort(int count) {
    return '$count ي';
  }

  @override
  String nocturneDaysAgo(int count) {
    return 'قبل $count يومًا';
  }

  @override
  String get nocturneToday => 'اليوم';

  @override
  String get nocturneBySource => 'حسب المصدر';

  @override
  String get nocturneByFormat => 'حسب الصيغة';

  @override
  String get nocturneChange => 'تغيير';

  @override
  String get nocturneFileLayout => 'ترتيب الملفات';

  @override
  String get nocturneTokenSite => 'الموقع';

  @override
  String get nocturneTokenCreator => 'المنشئ';

  @override
  String get nocturneTokenTitle => 'العنوان';

  @override
  String get nocturneAppearanceDesc => 'اختر تصميم TapLoad.';

  @override
  String get nocturneToolsDesc => 'الأدوات التي تُجري التنزيلات.';

  @override
  String get nocturneDecrease => 'إنقاص';

  @override
  String get nocturneIncrease => 'زيادة';

  @override
  String get nocturneArchiveEyebrow => 'أرشيف محلي · TikTok';

  @override
  String nocturneWordVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فيديوهات',
      one: 'فيديو',
    );
    return '$_temp0';
  }

  @override
  String nocturneWordCollections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مجموعات',
      one: 'مجموعة',
    );
    return '$_temp0';
  }

  @override
  String nocturneWordFavorites(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مفضلات',
      one: 'مفضلة',
    );
    return '$_temp0';
  }

  @override
  String get nocturneSync => 'مزامنة';

  @override
  String get nocturneSyncing => 'جارٍ المزامنة…';

  @override
  String nocturneStopBatch(int done, int total) {
    return 'إيقاف · $done/$total';
  }

  @override
  String get nocturneDownloadAll => 'تنزيل الكل';

  @override
  String get nocturneTabVideos => 'الفيديوهات';

  @override
  String get nocturneTabCollections => 'المجموعات';

  @override
  String get nocturneTabFavorites => 'المفضلة';

  @override
  String get nocturneImport => 'استيراد';

  @override
  String get nocturneArchiveSearch => 'ابحث عن فيديو أو مجموعة…';

  @override
  String get nocturneClear => 'مسح';

  @override
  String nocturneCountVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فيديو',
      one: 'فيديو واحد',
    );
    return '$_temp0';
  }

  @override
  String get nocturneSelectAll => 'تحديد الكل';

  @override
  String nocturneSelectedClear(int count) {
    return '$count محددة · مسح';
  }

  @override
  String get nocturneDownloadSelection => 'تنزيل المحدد';

  @override
  String get nocturneQueued => 'أُضيفت الفيديوهات إلى قائمة التنزيل.';

  @override
  String nocturneBatchSkipped(int done, int total, int skipped) {
    return '$done / $total ($skipped متجاهلة)';
  }

  @override
  String get nocturneNoMatch => 'لا يوجد فيديو يطابق عوامل التصفية';

  @override
  String get nocturneResetFilters => 'إعادة ضبط عوامل التصفية';

  @override
  String get nocturneFilters => 'عوامل التصفية';

  @override
  String get nocturneTransferEyebrow => 'شبكة Wi-Fi محلية';

  @override
  String get nocturneTransferTitle => 'أرسل إلى هاتفك';

  @override
  String get nocturneAllOptions => 'كل الخيارات';

  @override
  String get nocturneSimpleView => 'عرض مبسّط';

  @override
  String get nocturneQrCaption => 'رمز QR';

  @override
  String get nocturneScanTitle => 'افتح TapLoad على هاتفك وامسح الرمز';

  @override
  String get nocturnePinLabel => 'رمز PIN';

  @override
  String get nocturneAddressLabel => 'العنوان';

  @override
  String get nocturneOnNetwork => 'على شبكة Wi-Fi هذه';

  @override
  String get nocturneNoTransfer => 'لا يوجد إرسال جارٍ';

  @override
  String get nocturneFilesToSend => 'الملفات المراد إرسالها';

  @override
  String get nocturneAddFolder => 'مجلد…';

  @override
  String get nocturneAddFiles => 'ملفات…';

  @override
  String get nocturneTotalSelected => 'إجمالي المحدد';

  @override
  String get nocturneZip => 'ضغط بصيغة ZIP';

  @override
  String nocturneSendTo(String name) {
    return 'إرسال إلى $name';
  }

  @override
  String get nocturneRefreshDevices => 'البحث عن الأجهزة';

  @override
  String get nocturneClassicView => 'العرض الكلاسيكي';

  @override
  String get nocturneCardsView => 'عرض البطاقات';

  @override
  String get nocturneDone => 'إنهاء';

  @override
  String get nocturnePurgeHint =>
      'تُحفظ الفيديوهات المشتركة مع مجموعة محتفَظ بها.';

  @override
  String get nocturneAllDownloaded => 'تم تنزيل الكل';

  @override
  String nocturnePartDownloaded(int percent) {
    return 'تم تنزيل $percent٪';
  }

  @override
  String studioItems(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString عنصر',
      many: '$countString عنصرًا',
      few: '$countString عناصر',
      two: 'عنصران',
      one: 'عنصر واحد',
      zero: 'لا عناصر',
    );
    return '$_temp0';
  }

  @override
  String studioLiveCount(int count) {
    return '$count قيد التنزيل';
  }

  @override
  String get studioPasteLink => 'الصق رابطًا';

  @override
  String get studioColState => 'الحالة';

  @override
  String get studioAutoStart => 'البدء تلقائيًا';

  @override
  String get studioChange => 'تغيير';

  @override
  String get studioTools => 'أدوات التنزيل';

  @override
  String get studioChecking => 'جارٍ التحقق…';

  @override
  String get studioReplay => 'إعادة';

  @override
  String get studioDecrease => 'إنقاص';

  @override
  String get studioIncrease => 'زيادة';

  @override
  String get studioStatsSubtitle => 'ما نزّلته، ومن أين، ولمن.';

  @override
  String get studioStorage => 'التخزين';

  @override
  String get studioChartTitle7 => 'التنزيلات · آخر 7 أيام';

  @override
  String get studioChartTitle30 => 'التنزيلات · آخر 30 يومًا';

  @override
  String get studioDays7 => '7 أيام';

  @override
  String get studioDays30 => '30 يومًا';

  @override
  String studioDaysAgo(int count) {
    return 'قبل $count يومًا';
  }

  @override
  String get studioToday => 'اليوم';

  @override
  String get studioBySource => 'حسب المصدر';

  @override
  String get studioByFormat => 'حسب الصيغة';

  @override
  String get studioTopCreators => 'أبرز صنّاع المحتوى';

  @override
  String get studioPeriod => 'الفترة';

  @override
  String get studioTransferSubtitle =>
      'أرسل ملفاتك إلى هاتفك عبر شبكة Wi-Fi المحلية، بلا كابل ولا سحابة.';

  @override
  String get studioScanTitle => 'افتح TapLoad على هاتفك وامسح الرمز.';

  @override
  String get studioQrCode => 'رمز QR';

  @override
  String get studioPin => 'رمز PIN';

  @override
  String get studioAddress => 'العنوان';

  @override
  String get studioFilesToSend => 'ملفات للإرسال';

  @override
  String get studioSelection => 'التحديد';

  @override
  String get studioZip => 'ضغط بصيغة ZIP';

  @override
  String get studioTarget => 'المستلم';

  @override
  String get studioChoose => 'اختيار';

  @override
  String get studioAllOptions => 'كل الخيارات';

  @override
  String get studioSimpleView => 'العرض البسيط';

  @override
  String get studioTransferIssue => 'واجه النقل مشكلة.';

  @override
  String get studioArchiveCap => 'أرشيف محلي · TikTok';

  @override
  String get studioArchiveTitle => 'أرشيفي';

  @override
  String get studioSync => 'مزامنة';

  @override
  String get studioDownloadAll => 'تنزيل الكل';

  @override
  String studioDownloadAllConfirm(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'ستُضاف $countString من مقاطع الفيديو غير المنزّلة بعد إلى قائمة الانتظار.';
  }

  @override
  String get studioVideos => 'الفيديوهات';

  @override
  String get studioCollections => 'المجموعات';

  @override
  String get studioVideosUnit => 'فيديو';

  @override
  String get studioCollectionsUnit => 'مجموعة';

  @override
  String get studioFavoritesUnit => 'مفضلة';

  @override
  String get studioDone => 'تم';

  @override
  String get studioPurgeNote =>
      'تُحفظ مقاطع الفيديو المشتركة مع مجموعة محفوظة.';

  @override
  String get studioAllDownloaded => 'تم تنزيل الكل';

  @override
  String get studioPartDownloaded => 'تم تنزيله';

  @override
  String get studioToDownload => 'للتنزيل';

  @override
  String get terminalCommandHint => 'الصق رابطًا';

  @override
  String get terminalEnterKey => 'Enter';

  @override
  String get terminalEnterDownload => 'تنزيل';

  @override
  String get terminalHelp => 'مساعدة';

  @override
  String get terminalAll => 'الكل';

  @override
  String get terminalActive => 'جارية';

  @override
  String get terminalDone => 'مكتملة';

  @override
  String get terminalFailed => 'فاشلة';

  @override
  String terminalDesignLine(String id) {
    return 'التصميم $id';
  }

  @override
  String terminalActiveCount(int count) {
    return '$count نشطة';
  }

  @override
  String terminalQueuedCount(int count) {
    return '$count في الانتظار';
  }

  @override
  String terminalDownloadsCount(int count) {
    return '$count تنزيلات';
  }

  @override
  String get terminalLocalArchive => 'أرشيف محلي';

  @override
  String terminalVideosCount(int count) {
    return '$count فيديو';
  }

  @override
  String terminalCollectionsCount(int count) {
    return '$count مجموعات';
  }

  @override
  String get terminalLocalWifi => 'Wi-Fi محلي';

  @override
  String get terminalSending => 'جارٍ الإرسال';

  @override
  String get terminalKeyFilters => 'تصفية المكتبة';

  @override
  String get terminalKeyTools => 'الإحصائيات، النقل، الأرشيف';

  @override
  String get terminalKeySearch => 'بحث';

  @override
  String get terminalFlagLive => '--live';

  @override
  String get terminalFlagRecent => '--recent';

  @override
  String get terminalColState => 'الحالة';

  @override
  String get terminalColTitle => 'العنوان';

  @override
  String get terminalColSource => 'المصدر';

  @override
  String get terminalColFormat => 'الصيغة';

  @override
  String get terminalStateOk => 'تم';

  @override
  String get terminalStateErr => 'خطأ';

  @override
  String get terminalStateWait => 'انتظار';

  @override
  String get terminalStateRun => 'تشغيل';

  @override
  String get terminalFlagSummary => '--summary';

  @override
  String get terminalKpiDownloads => 'التنزيلات';

  @override
  String get terminalKpiStorage => 'التخزين';

  @override
  String get terminalKpiToday => 'اليوم';

  @override
  String get terminalKpiFree => 'المساحة_الحرة';

  @override
  String get terminalPeriod => 'الفترة';

  @override
  String get terminalPeriod7 => '7 أيام';

  @override
  String get terminalPeriod30 => '30 يومًا';

  @override
  String get terminalPeriod12 => '12 شهرًا';

  @override
  String get terminalFlagPeriod => '--period';

  @override
  String get terminalPerDay => 'التنزيلات يوميًا';

  @override
  String get terminalPerMonth => 'التنزيلات شهريًا';

  @override
  String terminalLastDays(int count) {
    return 'آخر $count يومًا';
  }

  @override
  String terminalLastMonths(int count) {
    return 'آخر $count شهرًا';
  }

  @override
  String terminalDaysAgo(int count) {
    return 'ي-$count';
  }

  @override
  String get terminalToday => 'اليوم';

  @override
  String terminalMonthsAgo(int count) {
    return 'ش-$count';
  }

  @override
  String get terminalThisMonth => 'هذا الشهر';

  @override
  String get terminalFlagBySource => '--by source';

  @override
  String get terminalFlagByFormat => '--by format';

  @override
  String get terminalFlagTopCreators => '--top creators';

  @override
  String get terminalSections => 'الأقسام';

  @override
  String get terminalSection => 'قسم';

  @override
  String get terminalFlagEdit => '--edit';

  @override
  String get terminalChangeFolder => 'تغيير المجلد';

  @override
  String get terminalAdjust => 'ضبط';

  @override
  String get terminalCheckTools => 'فحص الأدوات';

  @override
  String get terminalToolOk => 'جاهز';

  @override
  String get terminalToolChecking => 'جارٍ الفحص…';

  @override
  String get terminalToolMissing => 'مفقود';

  @override
  String get terminalToolUnchecked => 'لم يُفحص';

  @override
  String get terminalConfigComment => 'إعدادات tapload · تُعدَّل مباشرة';

  @override
  String get terminalCfgAudioOnly => 'صوت_فقط';

  @override
  String get terminalCfgAutoStart => 'بدء_تلقائي';

  @override
  String get terminalCfgQuality => 'الجودة_المفضلة';

  @override
  String get terminalCfgFolder => 'المجلد';

  @override
  String get terminalCfgDesign => 'التصميم';

  @override
  String get terminalCfgConcurrent => 'تنزيلات_متزامنة';

  @override
  String get terminalCfgReduceEffects => 'تقليل_المؤثرات';

  @override
  String get terminalChange => 'تغيير';

  @override
  String get terminalFlagArchive => '--archive';

  @override
  String get terminalTabVideos => 'فيديوهات';

  @override
  String get terminalTabCollections => 'مجموعات';

  @override
  String get terminalTabFavorites => 'المفضلة';

  @override
  String get terminalTabLikes => 'الإعجابات';

  @override
  String get terminalFinish => 'إنهاء';

  @override
  String get terminalFlagCollections => '--collections';

  @override
  String get terminalFlagVideos => '--videos';

  @override
  String terminalSuggestions(int count) {
    return '$count اقتراحات تصنيف';
  }

  @override
  String get terminalReview => 'مراجعة';

  @override
  String get terminalPurgeNote => 'تُحفظ الفيديوهات المشتركة مع مجموعة محفوظة';

  @override
  String get terminalSelection => 'تحديد';

  @override
  String get terminalRightClick => 'نقر يمين';

  @override
  String get terminalActions => 'إجراءات';

  @override
  String terminalDownloadedOf(int done, int total) {
    return 'تم تنزيل $done / $total فيديو';
  }

  @override
  String get terminalDownloadAll => 'تنزيل الكل';

  @override
  String get terminalAllDownloaded => 'تم تنزيل الكل';

  @override
  String terminalDownloadedPct(int percent) {
    return 'تم تنزيل $percent%';
  }

  @override
  String get terminalToDownload => 'للتنزيل';

  @override
  String terminalVidCount(int count) {
    return '$count فيديو';
  }

  @override
  String get terminalAllCollections => 'كل المجموعات';

  @override
  String terminalDownloadSelection(int count) {
    return 'تنزيل المحدد ($count)';
  }

  @override
  String get terminalCopyLink => 'نسخ الرابط';

  @override
  String get terminalOpenBrowser => 'فتح في المتصفح';

  @override
  String terminalApply(int count) {
    return 'تطبيق ($count)';
  }

  @override
  String get terminalFlagWifi => '--wifi';

  @override
  String get terminalFlagSelect => '--select';

  @override
  String get terminalFlagStatus => '--status';

  @override
  String get terminalFlagPeers => '--devices';

  @override
  String get terminalPin => 'رمز PIN';

  @override
  String get terminalAddress => 'العنوان';

  @override
  String get terminalScanHint => 'افتح TapLoad على هاتفك وامسح الرمز';

  @override
  String get terminalDevice => 'الجهاز';

  @override
  String get terminalOnline => 'متصل';

  @override
  String get terminalBroadcast => 'إعلان';

  @override
  String get terminalCheckAll => 'تحديد الكل';

  @override
  String get terminalAddFiles => 'إضافة';

  @override
  String get terminalClearPayload => 'إفراغ';

  @override
  String get terminalZipKey => 'ضغط_zip';

  @override
  String get terminalOnlyNewKey => 'الجديدة_فقط';

  @override
  String get terminalTotal => 'المجموع';

  @override
  String get terminalNoTransfer => 'لا يوجد إرسال جارٍ';

  @override
  String get pastilleGreetingMorning => 'صباح الخير';

  @override
  String get pastilleGreetingEvening => 'مساء الخير';

  @override
  String pastilleHomeBusy(String greeting) {
    return '$greeting، كل شيء يعمل.';
  }

  @override
  String pastilleHomeIdle(String greeting) {
    return '$greeting، كل شيء هادئ.';
  }

  @override
  String pastilleOneOf(int index, int total) {
    return '$index من $total';
  }

  @override
  String get pastilleQuickLink => 'رابط سريع';

  @override
  String pastilleClipboard(String url) {
    return 'الحافظة: $url';
  }

  @override
  String get pastilleAdded => 'أُضيف ✓';

  @override
  String get pastilleSpeed => 'السرعة';

  @override
  String get pastilleStorage => 'التخزين';

  @override
  String pastilleActivity(String month) {
    return 'النشاط · $month';
  }

  @override
  String pastilleTodayCount(int count) {
    return '$count اليوم';
  }

  @override
  String get pastilleThisMonth => 'هذا الشهر';

  @override
  String pastilleNext(String title) {
    return 'التالي: $title';
  }

  @override
  String get pastilleRecent => 'الأحدث';

  @override
  String pastilleTotal(int count) {
    return '$count إجمالاً';
  }

  @override
  String get pastilleAllLibrary => 'المكتبة كاملة';

  @override
  String get pastilleNothingYet => 'لا شيء مكتمل بعد';

  @override
  String get pastilleLibraryTitle => 'مكتبتك كاملة.';

  @override
  String get pastilleStatsTitle => 'نشاطك، في نقاط.';

  @override
  String get pastilleDownloads => 'التنزيلات';

  @override
  String get pastilleSinceStart => 'منذ البداية';

  @override
  String get pastilleVolume => 'الحجم';

  @override
  String get pastilleDownloadedTotal => 'تم تنزيلها إجمالاً';

  @override
  String get pastilleLast7 => 'آخر 7 أيام';

  @override
  String get pastilleLast30 => 'آخر 30 يومًا';

  @override
  String get pastilleDownloadsWord => 'تنزيلات';

  @override
  String pastilleChartTitle(String period) {
    return 'التنزيلات · $period';
  }

  @override
  String get pastillePeriod7 => '7 أيام';

  @override
  String get pastillePeriod30 => '30 يومًا';

  @override
  String pastilleDaysAgo(int days) {
    return 'ي-$days';
  }

  @override
  String get pastilleTodayShort => 'اليوم';

  @override
  String get pastilleByFormat => 'حسب الصيغة';

  @override
  String get pastilleBySource => 'حسب المصدر';

  @override
  String get pastilleSettingsEyebrow => 'الإعدادات';

  @override
  String get pastilleMoreSettings => 'إعدادات أخرى';

  @override
  String get pastilleChange => 'تغيير';

  @override
  String get pastilleAppDesign => 'تصميم التطبيق';

  @override
  String get pastilleConcurrentLess => 'تنزيل متزامن أقل';

  @override
  String get pastilleConcurrentMore => 'تنزيل متزامن إضافي';

  @override
  String get pastilleReduceEffects => 'تقليل التأثيرات';

  @override
  String get pastilleSystemTools => 'النظام · الأدوات';

  @override
  String get pastilleToolReady => 'جاهز';

  @override
  String get pastilleToolChecking => 'جارٍ التحقق…';

  @override
  String get pastilleToolUnchecked => 'لم يتم التحقق';

  @override
  String get pastilleRepair => 'تحقق وأصلح';

  @override
  String get pastilleArchiveEyebrow => 'أرشيف TikTok';

  @override
  String get pastilleArchiveTitle => 'أرشيفك، مرتب.';

  @override
  String get pastilleSync => 'مزامنة';

  @override
  String get pastilleDownloadAll => 'تنزيل الكل';

  @override
  String pastilleBatchStop(int done, int total) {
    return '$done / $total · إيقاف';
  }

  @override
  String get pastilleDemoDownload => 'وضع العرض: تنزيل محاكى.';

  @override
  String get pastilleArchiveVideos => 'الفيديوهات';

  @override
  String get pastilleArchiveCollections => 'المجموعات';

  @override
  String get pastilleArchiveFavorites => 'المفضلة';

  @override
  String get pastilleDone => 'إنهاء';

  @override
  String get pastilleMoreActions => 'إجراءات أخرى';

  @override
  String get pastilleDetailedView => 'عرض مفصل للمجموعات';

  @override
  String get pastilleInArchive => 'في الأرشيف';

  @override
  String get pastilleByTheme => 'مرتبة حسب الموضوع';

  @override
  String get pastilleKeptOnTikTok => 'محفوظة على TikTok';

  @override
  String get pastilleVideosLabel => 'فيديو في الأرشيف';

  @override
  String get pastilleFavoritesLabel => 'مفضلة';

  @override
  String get pastilleVideosText =>
      'كل فيديوهات أرشيفك مرتبة حسب المجموعة. افتح تبويب المجموعات لتختار ما تحتفظ به على هذا الحاسوب.';

  @override
  String get pastilleFavoritesText =>
      'الفيديوهات التي أضفتها إلى المفضلة على TikTok. «تنزيل الكل» يجلبها مع بقية الأرشيف.';

  @override
  String get pastilleLocalArchive => 'الأرشيف المحلي';

  @override
  String pastilleLikes(int count) {
    return '$count إعجاب';
  }

  @override
  String get pastilleSharedKept => 'الفيديوهات المشتركة مع مجموعة محفوظة تبقى.';

  @override
  String get pastilleNoCollections => 'لم يتم العثور على مجموعات';

  @override
  String get pastilleAllDownloaded => 'تم تنزيل الكل';

  @override
  String pastillePercentDownloaded(int percent) {
    return 'تم تنزيل $percent٪';
  }

  @override
  String get pastilleToDownload => 'للتنزيل';

  @override
  String get pastilleVideosWord => 'فيديو';

  @override
  String get pastilleOneDotTen => 'نقطة = 10 فيديوهات';

  @override
  String get pastilleSeeCollections => 'عرض المجموعات';

  @override
  String get pastilleArchiveSearch => 'ابحث عن فيديو أو مجموعة…';

  @override
  String pastilleVideoCount(int count) {
    return '$count فيديو';
  }

  @override
  String get pastilleSelectAll => 'تحديد الكل';

  @override
  String pastilleClearSelection(int count) {
    return '$count محدد · مسح';
  }

  @override
  String pastilleBatchProgress(int done, int total) {
    return 'قيد التنفيذ ($done/$total)';
  }

  @override
  String get pastilleDownloadSelection => 'تنزيل المحدد';

  @override
  String get pastilleQueued => 'أُضيفت الفيديوهات إلى قائمة التنزيل.';

  @override
  String get pastilleNoVideoMatch => 'لا يوجد فيديو يطابق عوامل التصفية';

  @override
  String get pastilleResetFilters => 'إعادة ضبط عوامل التصفية';

  @override
  String get pastilleTransferEyebrow => 'النقل عبر شبكة Wi-Fi المحلية';

  @override
  String get pastilleTransferTitle => 'أرسل إلى هاتفك.';

  @override
  String get pastilleConnection => 'الاتصال';

  @override
  String get pastilleQrCode => 'رمز QR';

  @override
  String get pastillePinCode => 'رمز PIN';

  @override
  String get pastilleScanHint => 'افتح TapLoad على هاتفك وامسح الرمز.';

  @override
  String get pastilleTransferInFlight => 'نقل جارٍ';

  @override
  String pastilleTo(String name) {
    return 'إلى $name';
  }

  @override
  String get pastilleLocalWifi => 'Wi-Fi محلي';

  @override
  String get pastilleNoTransfer => 'لا يوجد نقل جارٍ';

  @override
  String get pastilleConnectedDevice => 'الجهاز المتصل';

  @override
  String get pastilleConnected => 'متصل';

  @override
  String get pastilleNoDevice => 'لم يتم اختيار جهاز';

  @override
  String get pastilleFilesToSend => 'ملفات للإرسال';

  @override
  String get pastilleCreator => 'منشئ';

  @override
  String get pastilleFolder => 'مجلد';

  @override
  String get pastilleFile => 'ملف';

  @override
  String get pastilleAddFiles => 'إضافة ملفات';

  @override
  String get pastilleAddFolder => 'إضافة مجلد';

  @override
  String get pastilleSelection => 'التحديد';

  @override
  String get pastilleZip => 'ضغط بصيغة ZIP';

  @override
  String get pastilleMoreOptions => 'خيارات أخرى';

  @override
  String get porcelaineSpace => 'المساحة';

  @override
  String get porcelaineSettingsTab => 'الإعدادات';

  @override
  String get porcelaineEdit => 'تعديل';

  @override
  String get porcelaineDone => 'تم';

  @override
  String get porcelaineReset => 'إعادة التعيين';

  @override
  String get porcelaineAddWidget => 'إضافة أداة';

  @override
  String get porcelaineGoodMorning => 'مرحبًا.';

  @override
  String get porcelaineGoodEvening => 'مساء الخير.';

  @override
  String get porcelaineIdle => 'لا شيء قيد التنزيل';

  @override
  String porcelaineActiveNow(int count, String speed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تنزيل جارٍ',
      few: '$count تنزيلات جارية',
      two: 'تنزيلان جاريان',
      one: 'تنزيل واحد جارٍ',
    );
    return '$_temp0، $speed';
  }

  @override
  String get porcelaineEditHint =>
      'اسحب بطاقة لنقلها · اسحب الزاوية لتغيير حجمها';

  @override
  String get porcelaineQuickLink => 'رابط سريع';

  @override
  String get porcelaineSpeed => 'السرعة';

  @override
  String get porcelaineStorage => 'التخزين';

  @override
  String get porcelaineRecent => 'الأحدث';

  @override
  String get porcelaineDescActive => 'تقدّم ما يجري تنزيله.';

  @override
  String get porcelaineDescPaste => 'الصق وابدأ بنقرة واحدة.';

  @override
  String get porcelaineDescSpeed => 'السرعة المباشرة وسجلّها.';

  @override
  String get porcelaineDescStorage => 'المساحة الحرة وما يملؤها.';

  @override
  String get porcelaineDescRecent => 'أحدث تنزيلاتك.';

  @override
  String get porcelaineDescQueue => 'ما سيبدأ بعد ذلك.';

  @override
  String get porcelaineSizeSmall => 'صغير';

  @override
  String get porcelaineSizeMedium => 'متوسط';

  @override
  String get porcelaineSizeLarge => 'كبير';

  @override
  String get porcelaineSizeSmallShort => 'ص';

  @override
  String get porcelaineSizeMediumShort => 'م';

  @override
  String get porcelaineSizeLargeShort => 'ك';

  @override
  String porcelaineSizeLabel(String size) {
    return 'الحجم $size';
  }

  @override
  String get porcelaineMoveBack => 'نقل إلى الخلف';

  @override
  String get porcelaineMoveForward => 'نقل إلى الأمام';

  @override
  String porcelaineRemoveWidget(String name) {
    return 'إزالة أداة $name';
  }

  @override
  String porcelaineWidgetOptions(String name) {
    return 'خيارات أداة $name';
  }

  @override
  String get porcelaineResizeHint => 'اسحب لتغيير الحجم';

  @override
  String porcelaineRemoved(String name) {
    return 'تمت إزالة «$name»';
  }

  @override
  String get porcelaineCatalogHint => 'تُضاف في نهاية مساحتك بحجمها المقترح.';

  @override
  String get porcelaineAlreadyThere => 'موجودة في مساحتك';

  @override
  String porcelaineAddAt(String size) {
    return 'إضافة · $size';
  }

  @override
  String get porcelaineEmptyTitle => 'مساحتك فارغة';

  @override
  String get porcelaineEmptyBody =>
      'أضف الأدوات التي تحتاجها: التقدّم، الرابط السريع، السرعة، التخزين…';

  @override
  String get porcelainePaste => 'لصق';

  @override
  String get porcelainePasteAndDownload => 'لصق وتنزيل';

  @override
  String get porcelainePasteHint => 'الصق رابطًا…';

  @override
  String get porcelaineAdded => 'تمت الإضافة ✓';

  @override
  String get porcelaineAddedShort => 'أُضيف';

  @override
  String porcelaineClipboard(String url) {
    return 'الحافظة: $url';
  }

  @override
  String get porcelaineClipboardTitle => 'رابط في الحافظة';

  @override
  String get porcelaineClipboardNone => 'لا يوجد رابط في الحافظة';

  @override
  String get porcelaineFormatAuto => 'تلقائي';

  @override
  String get porcelaineFormatAudio => 'صوت فقط';

  @override
  String get porcelaineMoreOptions => 'خيارات أخرى…';

  @override
  String porcelaineSpeedNow(String unit) {
    return '$unit الآن';
  }

  @override
  String get porcelainePeak => 'الذروة';

  @override
  String get porcelaineAverage => 'المتوسط';

  @override
  String porcelaineFreeUnit(String unit) {
    return '$unit متاحة';
  }

  @override
  String get porcelaineHeaviest => 'الأكبر حجمًا';

  @override
  String get porcelaineFreeUp => 'تحرير مساحة';

  @override
  String get porcelaineWholeLibrary => 'المكتبة كاملة';

  @override
  String get porcelaineWaiting => 'في الانتظار';

  @override
  String get porcelaineStatsDownloads => 'التنزيلات';

  @override
  String get porcelaineStatsVolume => 'الحجم المُنزَّل';

  @override
  String get porcelaineStatsDownloadsUnit => 'تنزيلات';

  @override
  String porcelaineStatsChartTitle(String period) {
    return 'التنزيلات · $period';
  }

  @override
  String get porcelaineLast30Days => 'آخر 30 يومًا';

  @override
  String porcelaineDaysShort(int days) {
    return '$days ي';
  }

  @override
  String porcelaineDaysAgo(int days) {
    return 'قبل $days ي';
  }

  @override
  String get porcelaineTodayAxis => 'اليوم';

  @override
  String get porcelaineBySource => 'حسب المصدر';

  @override
  String get porcelaineByFormat => 'حسب الصيغة';

  @override
  String get porcelaineTopCreators => 'أبرز المبدعين';

  @override
  String get porcelaineSettingsGeneralDesc => 'سلوك TapLoad اليومي.';

  @override
  String get porcelaineAutoStart => 'البدء تلقائيًا';

  @override
  String get porcelaineChange => 'تغيير';

  @override
  String get porcelaineParallelDownloads => 'التنزيلات المتزامنة';

  @override
  String get porcelaineOneLess => 'واحد أقل';

  @override
  String get porcelaineOneMore => 'واحد أكثر';

  @override
  String get porcelaineReduceEffects => 'تقليل المؤثرات';

  @override
  String get porcelaineReduceEffectsHint =>
      'رسوم متحركة أقل، مفيد على حاسوب متواضع.';

  @override
  String porcelaineDesignActive(String name) {
    return '$name مُفعَّل';
  }

  @override
  String get porcelaineToolReady => 'جاهز';

  @override
  String get porcelaineToolChecking => 'جارٍ التحقق…';

  @override
  String get porcelaineToolUnchecked => 'لم يُتحقق منه';

  @override
  String get porcelaineTransferTitle => 'إلى هاتفك';

  @override
  String get porcelaineTransferSubtitle =>
      'عبر شبكة Wi-Fi المحلية، بلا كابل ولا سحابة.';

  @override
  String get porcelaineSimpleView => 'العرض البسيط';

  @override
  String get porcelaineConnection => 'الاتصال';

  @override
  String get porcelaineScanTitle => 'افتح TapLoad على هاتفك وامسح الرمز';

  @override
  String get porcelaineScanHint => 'أو أدخل الرمز والعنوان يدويًا.';

  @override
  String get porcelaineQrCode => 'رمز QR';

  @override
  String get porcelainePinCode => 'رمز PIN';

  @override
  String get porcelaineAddress => 'العنوان';

  @override
  String get porcelaineConnectedDevice => 'الجهاز المتصل';

  @override
  String get porcelaineConnected => 'متصل';

  @override
  String get porcelaineTransferInProgress => 'نقل جارٍ';

  @override
  String porcelaineToDevice(String name) {
    return 'إلى $name';
  }

  @override
  String get porcelaineFilesToSend => 'الملفات المراد إرسالها';

  @override
  String porcelaineVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فيديو',
      few: '$count فيديوهات',
      two: 'فيديوهان',
      one: 'فيديو واحد',
    );
    return '$_temp0';
  }

  @override
  String get porcelaineCompressZip => 'ضغط بصيغة ZIP';

  @override
  String get porcelaineSelectedTotal => 'إجمالي المحدد';

  @override
  String get porcelaineNearbyDevices => 'الأجهزة القريبة';

  @override
  String get porcelaineRecipient => 'المستلم';

  @override
  String get porcelaineSearchDevices => 'بحث';

  @override
  String get porcelaineAllTransferTools => 'كل الأدوات';

  @override
  String get porcelaineLocalArchive => 'أرشيف محلي';

  @override
  String get porcelaineArchiveVideos => 'فيديو';

  @override
  String get porcelaineArchiveCollections => 'مجموعة';

  @override
  String get porcelaineArchiveFavorites => 'مفضلة';

  @override
  String get porcelaineArchiveVideosTab => 'الفيديوهات';

  @override
  String get porcelaineArchiveCollectionsTab => 'المجموعات';

  @override
  String get porcelaineArchiveFavoritesTab => 'المفضلة';

  @override
  String get porcelaineArchiveKeptHint =>
      'تُحفظ الفيديوهات المشتركة مع مجموعة محتفَظ بها.';

  @override
  String get porcelaineSync => 'مزامنة';

  @override
  String porcelaineDownloadSelection(int count) {
    return 'تنزيل ($count)';
  }

  @override
  String get porcelaineDownloadSelectionNone => 'تنزيل المحدد';

  @override
  String get porcelaineSelectFirst => 'حدد فيديوهات في القائمة أولًا.';

  @override
  String get signalStatsVolume => 'الحجم المُنزَّل';

  @override
  String signalStatsLastDays(int count) {
    return 'آخر $count يومًا';
  }

  @override
  String signalStatsPeriodDays(int count) {
    return '$count ي';
  }

  @override
  String signalStatsDaysAgo(int count) {
    return 'قبل $count يومًا';
  }

  @override
  String get signalStatsTodayAxis => 'اليوم';

  @override
  String get signalStatsByFormat => 'حسب الصيغة';

  @override
  String get signalStatsInVideo => 'فيديو';

  @override
  String get signalStatsTopCreators => 'أبرز صنّاع المحتوى';

  @override
  String get signalStatsNoCreators => 'لا يوجد صنّاع محتوى بعد.';

  @override
  String get signalSettingsGeneralHint => 'ما يفعله TapLoad افتراضيًا.';

  @override
  String get signalSettingsChange => 'تغيير';

  @override
  String get signalSettingsDesignTitle => 'المظهر · التصميم';

  @override
  String signalSettingsCurrentDesign(String name) {
    return 'الحالي: $name';
  }

  @override
  String get signalSettingsToolsTitle => 'النظام · الأدوات';

  @override
  String get signalSettingsLess => 'واحد أقل';

  @override
  String get signalSettingsMore => 'واحد أكثر';

  @override
  String get signalArchiveLocal => 'أرشيف محلي';

  @override
  String signalArchiveDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تنزيل $count فيديو',
      many: 'تم تنزيل $count فيديو',
      few: 'تم تنزيل $count فيديوهات',
      two: 'تم تنزيل فيديوين',
      one: 'تم تنزيل فيديو واحد',
      zero: 'لم يُنزَّل شيء بعد',
    );
    return '$_temp0';
  }

  @override
  String get signalArchiveVideosTab => 'الفيديوهات';

  @override
  String get signalArchiveCollectionsTab => 'المجموعات';

  @override
  String get signalArchiveSync => 'مزامنة';

  @override
  String get signalArchiveDownloadAll => 'تنزيل الكل';

  @override
  String signalArchiveConfirmAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تنزيل $count فيديو؟',
      many: 'تنزيل $count فيديو؟',
      few: 'تنزيل $count فيديوهات؟',
      two: 'تنزيل فيديوين؟',
      one: 'تنزيل فيديو واحد؟',
    );
    return '$_temp0';
  }

  @override
  String get signalArchiveConfirmAllBody =>
      'تنضم الفيديوهات غير المُنزَّلة بعد إلى قائمة الانتظار.';

  @override
  String get signalArchiveAllDone => 'تم تنزيل الكل';

  @override
  String get signalArchiveNotDownloaded => 'غير مُنزَّلة';

  @override
  String get signalArchiveSharedKept =>
      'تبقى الفيديوهات المشتركة مع مجموعة محفوظة.';

  @override
  String get signalArchiveCardView => 'العودة إلى البطاقات';

  @override
  String get signalArchiveDownloadSelection => 'تنزيل المحدد';

  @override
  String get signalTransferWifi => 'على شبكة Wi-Fi المحلية';

  @override
  String get signalTransferTitle => 'الإرسال إلى الهاتف';

  @override
  String get signalTransferScanHint => 'افتح TapLoad على هاتفك وامسح الرمز.';

  @override
  String get signalTransferCode => 'أو أدخل الرمز';

  @override
  String get signalTransferTarget => 'الوجهة';

  @override
  String get signalTransferReachable => 'متاح';

  @override
  String get signalTransferFiles => 'الملفات المراد إرسالها';

  @override
  String get signalTransferTotal => 'إجمالي المحدد';

  @override
  String get signalTransferInProgress => 'نقل جارٍ';

  @override
  String signalTransferTo(String name) {
    return 'إلى $name';
  }

  @override
  String get signalTransferPickDevice => 'اختر الجهاز من قائمة الأجهزة.';

  @override
  String porcelaineSelectedCollections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجموعة محددة',
      few: '$count مجموعات محددة',
      two: 'مجموعتان محددتان',
      one: 'مجموعة واحدة محددة',
      zero: 'لا شيء محدد',
    );
    return '$_temp0';
  }

  @override
  String get porcelaineNotDownloadedYet => 'لم تُنزَّل بعد';

  @override
  String get pastilleEmptyTitle => 'لا شيء هنا بعد.';

  @override
  String get pastilleEmptyBody =>
      'الصق رابطًا من YouTube أو TikTok أو Instagram أو X: كل تنزيل يملأ هذه الشبكة، نقطة بعد نقطة.';

  @override
  String pastilleNoResultsTitle(String query) {
    return 'لا نتائج لـ «$query»';
  }

  @override
  String get pastilleNoResultsFilters => 'لا يوجد تنزيل يطابق هذه الفلاتر';

  @override
  String get pastilleNoResultsBody => 'تحقّق من الإملاء أو وسّع الفلاتر.';

  @override
  String get pastilleLoadErrorTitle => 'تعذّر تحميل المكتبة.';

  @override
  String get pastilleLoadErrorBody =>
      'ملفاتك ما زالت على القرص. حاول مجددًا بعد قليل.';

  @override
  String pastilleRetryFailed(int count) {
    return 'إعادة المحاولة للفاشلة ($count)';
  }

  @override
  String get pastilleLoading => 'جارٍ تحميل المكتبة…';

  @override
  String get pastilleFinished => 'اكتمل';

  @override
  String pastilleFailedIdle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فشل $count تنزيلًا',
      few: 'فشلت $count تنزيلات',
      two: 'فشل تنزيلان',
      one: 'فشل تنزيل واحد',
    );
    return '$_temp0';
  }

  @override
  String get pastilleStatsEmptyTitle => 'لا نقاط بعد.';

  @override
  String get pastilleStatsEmptyBody =>
      'كل تنزيل مكتمل يضيف عمودًا هنا، يومًا بعد يوم.';
}
