// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Modern Downloader';

  @override
  String get downloads => 'Téléchargements';

  @override
  String get statistics => 'Statistiques';

  @override
  String get settings => 'Paramètres';

  @override
  String get appearance => 'Apparence';

  @override
  String get plugins => 'Plugins';

  @override
  String get newDownload => 'Nouveau téléchargement';

  @override
  String get pasteUrl => 'Collez l\'URL ici';

  @override
  String get xCdnUrlRejected =>
      'Collez le lien du tweet (x.com/.../status/...), pas le fichier vidéo.';

  @override
  String get startDownload => 'Démarrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get retry => 'Réessayer';

  @override
  String get delete => 'Supprimer';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Reprendre';

  @override
  String get openFile => 'Ouvrir le fichier';

  @override
  String get openFolder => 'Ouvrir le dossier';

  @override
  String get clearHistory => 'Effacer l\'historique';

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get deselectAll => 'Tout désélectionner';

  @override
  String get statusQueued => 'En attente';

  @override
  String get statusDownloading => 'En cours';

  @override
  String get statusCompleted => 'Terminé';

  @override
  String get statusFailed => 'Échoué';

  @override
  String get statusCanceled => 'Annulé';

  @override
  String get statusPaused => 'En pause';

  @override
  String get statusExtracting => 'Extraction';

  @override
  String get statusDuplicate => 'Doublon';

  @override
  String get sidebarAll => 'Tous';

  @override
  String get sidebarActive => 'Actifs';

  @override
  String get sidebarCompleted => 'Terminés';

  @override
  String get sidebarFailed => 'Échoués';

  @override
  String get sidebarBySource => 'Par source';

  @override
  String get settingsGeneral => 'Général';

  @override
  String get settingsOutput => 'Sortie';

  @override
  String get settingsAdvanced => 'Avancé';

  @override
  String get settingsPerformance => 'Performance';

  @override
  String get settingsSystem => 'Système';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsPlugins => 'Plugins';

  @override
  String get audioOnly => 'Audio uniquement';

  @override
  String get audioOnlyDesc => 'Extraire l\'audio uniquement (MP3) des vidéos';

  @override
  String get autoStart => 'Démarrage auto';

  @override
  String get autoStartDesc => 'Démarrer les téléchargements immédiatement';

  @override
  String get preferredQuality => 'Qualité préférée';

  @override
  String get maxConcurrent => 'Téléchargements simultanés max';

  @override
  String get outputFolder => 'Dossier de sortie';

  @override
  String get chooseFolder => 'Choisir un dossier';

  @override
  String get useCookies => 'Utiliser les cookies';

  @override
  String get useCookiesDesc =>
      'Utiliser les cookies du navigateur pour l\'authentification';

  @override
  String get useProxy => 'Utiliser un proxy';

  @override
  String get useProxyDesc => 'Passer les téléchargements par un serveur proxy';

  @override
  String get minimizeToTray => 'Réduire dans la barre';

  @override
  String get minimizeToTrayDesc =>
      'Réduire dans la barre système au lieu de fermer';

  @override
  String get autoStartApp => 'Démarrer avec Windows';

  @override
  String get autoStartAppDesc =>
      'Lancer l\'application au démarrage du système';

  @override
  String get autoUpdateYtDlp => 'Mise à jour auto de yt-dlp';

  @override
  String get autoUpdateYtDlpDesc =>
      'Vérifier les mises à jour de yt-dlp au démarrage';

  @override
  String get showNotifications => 'Notifications';

  @override
  String get showNotificationsDesc =>
      'Notifications de bureau pour les téléchargements';

  @override
  String get clipboardMonitor => 'Surveillance du presse-papiers';

  @override
  String get clipboardMonitorDesc =>
      'Détecter automatiquement les URL du presse-papiers';

  @override
  String get language => 'Langue';

  @override
  String get languageDesc => 'Choisir votre langue préférée';

  @override
  String get theme => 'Thème';

  @override
  String get themeDesc => 'Choisir le thème de l\'application';

  @override
  String get accentColor => 'Couleur d\'accent';

  @override
  String get accentColorDesc => 'Personnaliser la couleur d\'accent';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get lightMode => 'Mode clair';

  @override
  String get systemMode => 'Système';

  @override
  String get totalDownloads => 'Total téléchargements';

  @override
  String get downloadsToday => 'Aujourd\'hui';

  @override
  String get totalData => 'Données totales';

  @override
  String get freeSpace => 'Espace libre';

  @override
  String get last7Days => 'Activité (7 derniers jours)';

  @override
  String get sourceDistribution => 'Répartition par source';

  @override
  String get keyboardShortcuts => 'Raccourcis clavier';

  @override
  String get newDownloadShortcut => 'Nouveau téléchargement';

  @override
  String get settingsShortcut => 'Ouvrir les paramètres';

  @override
  String get dashboardShortcut => 'Tableau de bord';

  @override
  String get minimizeShortcut => 'Réduire';

  @override
  String get inspector => 'Inspecteur';

  @override
  String get title => 'Titre';

  @override
  String get status => 'Statut';

  @override
  String get progress => 'Progression';

  @override
  String get logs => 'Journaux';

  @override
  String get selectDownload => 'Sélectionner un téléchargement';

  @override
  String get checkDependencies => 'Vérifier les dépendances';

  @override
  String get checkDependenciesDesc =>
      'Vérifier l\'état de yt-dlp, ffmpeg et aria2c';

  @override
  String get verifyingBinaries => 'Vérification des binaires...';

  @override
  String get dependenciesVerified => 'Dépendances vérifiées';

  @override
  String get organizeLibrary => 'Organiser la bibliothèque';

  @override
  String get organizeLibraryDesc =>
      'Trier les fichiers par source, organiser les miniatures, nettoyer les fichiers temporaires';

  @override
  String get organizationComplete => 'Organisation terminée';

  @override
  String filesMoved(int count) {
    return 'Fichiers déplacés : $count';
  }

  @override
  String filesDeleted(int count) {
    return 'Fichiers temp supprimés : $count';
  }

  @override
  String get noPluginsInstalled => 'Aucun plugin installé';

  @override
  String get pluginEnabled => 'Activée';

  @override
  String get pluginDisabled => 'Désactivée';

  @override
  String get builtIn => 'Intégrée';

  @override
  String get mediaPlayer => 'Lecteur multimédia';

  @override
  String get playbackSpeed => 'Vitesse de lecture';

  @override
  String get volume => 'Volume';

  @override
  String get ok => 'OK';

  @override
  String get confirm => 'Confirmer';

  @override
  String get close => 'Fermer';

  @override
  String get save => 'Enregistrer';

  @override
  String get back => 'Retour';

  @override
  String get search => 'Rechercher';

  @override
  String get noResults => 'Aucun résultat trouvé';

  @override
  String get loading => 'Chargement...';

  @override
  String get error => 'Erreur';

  @override
  String get success => 'Succès';

  @override
  String get warning => 'Attention';

  @override
  String get librarySection => 'Bibliothèque';

  @override
  String get sourcesSection => 'Sources';

  @override
  String get mainPage => 'Accueil';

  @override
  String get allDownloads => 'Tous les téléchargements';

  @override
  String get downloadStarted => 'Téléchargement lancé';

  @override
  String videosDownloadingCount(int count) {
    return '$count vidéos se téléchargent';
  }

  @override
  String get videoDownloadingSingular => '1 vidéo se télécharge';

  @override
  String get expandDownloadingVideos => 'Afficher les vidéos en cours';

  @override
  String get collapseDownloadingVideos => 'Masquer les vidéos en cours';

  @override
  String moreDownloadingVideos(int count) {
    return '+$count';
  }

  @override
  String get searchDownloads => 'Rechercher des téléchargements...';

  @override
  String get clearHistoryConfirm =>
      'Supprimer les téléchargements terminés, échoués et annulés ? Les téléchargements actifs restent.';

  @override
  String get refreshLibrary => 'Actualiser la bibliothèque';

  @override
  String get yourListIsEmpty => 'Votre liste de téléchargements est vide.';

  @override
  String get sortAndView => 'Tri et affichage';

  @override
  String get sortBy => 'Trier par';

  @override
  String get sortDateNewest => 'Date (plus récent)';

  @override
  String get sortDateOldest => 'Date (plus ancien)';

  @override
  String get sortNameAsc => 'Nom (A-Z)';

  @override
  String get sortSizeLargest => 'Taille (plus grand)';

  @override
  String get viewMode => 'Mode d\'affichage';

  @override
  String get viewList => 'Liste';

  @override
  String get viewDetailed => 'Détaillé';

  @override
  String playlistDetected(int count) {
    return 'Playlist détectée ($count vidéos)';
  }

  @override
  String downloadSelected(int count) {
    return 'Télécharger la sélection ($count)';
  }

  @override
  String startedCountDownloads(int count) {
    return '$count téléchargements lancés';
  }

  @override
  String get downloadFolder => 'Dossier de téléchargement';

  @override
  String get selectFolder => 'Choisir un dossier...';

  @override
  String get organizeBySite => 'Organiser par site';

  @override
  String get organizeBySiteDesc =>
      'Créer des sous-dossiers comme Téléchargements/YouTube/';

  @override
  String get formatLabel => 'Format';

  @override
  String get adultSites => 'Sites pour adultes';

  @override
  String get adultSitesDesc => 'Activer le contenu soumis à restriction d\'âge';

  @override
  String get doNotDisturb => 'Ne pas déranger';

  @override
  String get doNotDisturbDesc =>
      'Couper les notifications de l\'app et de l\'extension';

  @override
  String get cookiesFromBrowser => 'Cookies du navigateur';

  @override
  String get extensionApiToken => 'Jeton API de l\'extension';

  @override
  String get localServerPort => 'Port du serveur local';

  @override
  String get backupHistory => 'Sauvegarder l\'historique';

  @override
  String get restoreHistory => 'Restaurer l\'historique';

  @override
  String get restoreHistoryDesc =>
      'Importer les téléchargements depuis une sauvegarde';

  @override
  String get cookiesFile => 'Fichier de cookies';

  @override
  String get simultaneousDownloads => 'Téléchargements simultanés';

  @override
  String get simultaneousDownloadsDesc =>
      'Nombre max de téléchargements actifs';

  @override
  String get threadsPerDownload => 'Threads par téléchargement';

  @override
  String get threadsPerDownloadDesc =>
      'Connexions parallèles (fragments) par fichier';

  @override
  String get maxSpeedMode => 'Mode vitesse max';

  @override
  String get maxSpeedModeDesc =>
      '64 connexions parallèles, buffers larges, remux rapide (sans réencodage)';

  @override
  String get libraryManagement => 'Gestion de la bibliothèque';

  @override
  String get smartOrganization => 'Organisation intelligente';

  @override
  String get smartOrganizationDesc =>
      'Règles de tri automatique et détection intelligente';

  @override
  String get outputFolderNotConfigured => 'Dossier de sortie non configuré';

  @override
  String get pluginsEmptyHint =>
      'Les plugins étendent les fonctionnalités de Modern Downloader';

  @override
  String get statusProcessing => 'Traitement';

  @override
  String get statsSubtitle =>
      'Suivez votre activité de téléchargement et l\'espace disque';

  @override
  String get statsToday => 'Aujourd\'hui';

  @override
  String get downloadActivity => 'Activité de téléchargement';

  @override
  String get last7DaysShort => '7 derniers jours';

  @override
  String get sourcesChartTitle => 'Sources';

  @override
  String get sourcesByPlatform => 'Par plateforme';

  @override
  String get shortcutsQuickActions => 'Actions rapides';

  @override
  String get noDownloadHistory => 'Aucun historique de téléchargement';

  @override
  String get noSourceData => 'Aucune donnée de source';

  @override
  String chartDownloadsTooltip(int count, String bytes) {
    return '$count téléchargements\n$bytes';
  }

  @override
  String get currentAccent => 'Accent actuel';

  @override
  String get dataAndHistory => 'Données et historique';

  @override
  String get exportHistoryDesc =>
      'Exporter l\'historique des téléchargements en JSON';

  @override
  String get saveHistoryBackup => 'Enregistrer la sauvegarde';

  @override
  String get tokenCopied => 'Jeton copié';

  @override
  String get tokenCopiedHint =>
      'Jeton copié. Collez-le dans l\'extension du navigateur.';

  @override
  String get copyToken => 'Copier le jeton';

  @override
  String get portSavedRestart =>
      'Port enregistré. Redémarrez l\'application pour l\'appliquer.';

  @override
  String get historyExported => 'Historique exporté avec succès';

  @override
  String get historyRestored => 'Historique restauré avec succès';

  @override
  String get generatedOnFirstLaunch => 'Généré au premier lancement';

  @override
  String serverPortRestartHint(int port) {
    return 'Redémarrez l\'application après modification. Actuel : $port';
  }

  @override
  String get torBypassDesc =>
      'Contourner les blocages géo via Tor (127.0.0.1:9050)';

  @override
  String get selectCookiesFile => 'Choisir cookies.txt';

  @override
  String get clearCookies => 'Effacer les cookies';

  @override
  String get selectQuality => 'Choisir la qualité';

  @override
  String get unknownSize => 'Taille inconnue';

  @override
  String get bestQuality => 'Meilleure qualité';

  @override
  String get noLogsAvailable => 'Aucun journal disponible';

  @override
  String get dropLinksHere => 'Déposez des liens ou des fichiers ici';

  @override
  String get dropLinksHint => 'Ils seront ajoutés à la file de téléchargement';

  @override
  String get retryDownload => 'Réessayer le téléchargement';

  @override
  String get restartDownload => 'Relancer le téléchargement';

  @override
  String get copyUrl => 'Copier l\'URL';

  @override
  String get remove => 'Retirer';

  @override
  String get urlLabel => 'URL';

  @override
  String get pleaseEnterUrl => 'Veuillez saisir une URL';

  @override
  String get enterValidUrl => 'Saisissez une URL http(s) valide';

  @override
  String get cookiesNoneDefault => 'Aucun (par défaut)';

  @override
  String get failedFetchQuality => 'Impossible de récupérer les qualités';

  @override
  String get unknown => 'Inconnu';

  @override
  String get inspectorId => 'ID';

  @override
  String get storageUsage => 'Utilisation du stockage';

  @override
  String get storageInfoUnavailable => 'Infos de stockage indisponibles';

  @override
  String get storageUsed => 'Utilisé';

  @override
  String get storageFree => 'Libre';

  @override
  String storageTotalLabel(String size) {
    return 'Total : $size';
  }

  @override
  String get storageFolder => 'Dossier';

  @override
  String get storageOtherUsed => 'Autre utilisé';

  @override
  String storageFolderOfUsed(String percent) {
    return '$percent% de l\'espace utilisé';
  }

  @override
  String storageFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '1 fichier',
      zero: '0 fichier',
    );
    return '$_temp0';
  }

  @override
  String get storageTypeVideo => 'Vidéo';

  @override
  String get storageTypeAudio => 'Audio';

  @override
  String get storageTypeOther => 'Autre';

  @override
  String get storageTopSubfolders => 'Plus gros dossiers';

  @override
  String get storageScanInProgress => 'Analyse du dossier...';

  @override
  String storageLastScanned(String time) {
    return 'Analysé à $time';
  }

  @override
  String get storageScanCached => 'Données en cache';

  @override
  String get storageScanError => 'Impossible d\'analyser ce dossier';

  @override
  String get startingOrganization => 'Organisation en cours...';

  @override
  String organizationFailed(String error) {
    return 'Organisation échouée : $error';
  }

  @override
  String thumbnailsOrganized(int count) {
    return 'Miniatures organisées : $count';
  }

  @override
  String foldersCreated(int count) {
    return 'Dossiers créés : $count';
  }

  @override
  String emptyFoldersDeleted(int count) {
    return 'Dossiers vides supprimés : $count';
  }

  @override
  String organizationErrors(int count) {
    return '$count erreurs';
  }

  @override
  String get nameLabel => 'Nom';

  @override
  String get editRule => 'Modifier la règle';

  @override
  String get newRule => 'Nouvelle règle';

  @override
  String get patternKeywordOrRegex => 'Motif (mot-clé ou regex)';

  @override
  String get regexpPattern => 'Motif RegExp';

  @override
  String get containsText => 'Contient le texte';

  @override
  String get isRegex => 'Est une regex';

  @override
  String get targetSubfolder => 'Sous-dossier cible';

  @override
  String get active => 'Active';

  @override
  String get downloadModel => 'Télécharger un modèle';

  @override
  String get selectPopularModel => 'Choisissez un modèle populaire :';

  @override
  String get ollamaPullNote =>
      'Note : une connexion rapide est requise. Consultez les logs Ollama pour le suivi.';

  @override
  String get smartGuessTitle => 'Détection intelligente (IA)';

  @override
  String get smartGuessDesc =>
      'Catégorise automatiquement les fichiers via des motifs ou une IA locale.';

  @override
  String get aiMode => 'Mode IA';

  @override
  String get aiModeOffline => 'Hors ligne (heuristique — rapide)';

  @override
  String get aiModeOllama => 'Ollama / LocalAI';

  @override
  String get ollamaApiUrl => 'URL de l\'API Ollama';

  @override
  String get modelName => 'Nom du modèle';

  @override
  String get selectOrTypeModel =>
      'Choisir dans la liste ou saisir manuellement';

  @override
  String get refreshModels => 'Actualiser les modèles';

  @override
  String get customRules => 'Règles personnalisées';

  @override
  String get addRule => 'Ajouter une règle';

  @override
  String get noRulesDefined => 'Aucune règle. Ajoutez-en une avec le bouton +.';

  @override
  String get organizeExistingFiles => 'Organiser les fichiers existants';

  @override
  String get organizeExistingFilesDesc =>
      'Analyser un dossier et classer les fichiers avec les règles / l\'IA.';

  @override
  String get ollamaMustRun => 'Vérifiez qu\'Ollama tourne (`ollama serve`).';

  @override
  String requestingOllamaPull(String model) {
    return 'Téléchargement du modèle $model via Ollama... Cela peut prendre du temps.';
  }

  @override
  String organizationCompleteDetail(int scanned, int moved) {
    return 'Organisation terminée. $scanned fichiers analysés, $moved déplacés.';
  }

  @override
  String get toolsSection => 'Outils';

  @override
  String get configurePlugin => 'Configurer le plugin';

  @override
  String pluginError(String error) {
    return 'Erreur : $error';
  }

  @override
  String get setupPreparing => 'Préparation des outils de téléchargement…';

  @override
  String get setupCheckingTools => 'Vérification des outils installés';

  @override
  String setupDownloading(String name) {
    return 'Téléchargement de $name…';
  }

  @override
  String setupExtracting(String name) {
    return 'Extraction de $name…';
  }

  @override
  String setupVerifying(String name) {
    return 'Vérification de $name…';
  }

  @override
  String get setupUpdatingYtDlp => 'Mise à jour de yt-dlp…';

  @override
  String get setupReady => 'Tous les outils sont prêts';

  @override
  String get setupFailed => 'Impossible d\'installer tous les outils';

  @override
  String get setupRetry => 'Réessayer';

  @override
  String get setupContinueAnyway => 'Continuer quand même';

  @override
  String setupDownloadPercent(int percent) {
    return '$percent%';
  }

  @override
  String get previewSetup => 'Voir l\'écran de setup (temporaire)';

  @override
  String get previewSetupDesc =>
      'Relancer la vérification et l\'installation des outils en plein écran';

  @override
  String get pluginsSectionTitle => 'Plugins';

  @override
  String get pluginsSectionHint =>
      'Modules intégrés à l\'application, comme Auto Rename et Smart Organizer.';

  @override
  String get browserExtensionsTitle => 'Extension navigateur';

  @override
  String get browserExtensionsHint =>
      'Envoie les liens depuis le navigateur vers l\'app. Un clic prépare l\'extension et ouvre la page du navigateur.';

  @override
  String get chromeExtensionTitle => 'Chrome / Edge / Brave';

  @override
  String get chromeExtensionSteps =>
      '1. Cliquez Installer. 2. Mode développeur. 3. Charger l\'extension non empaquetée, puis Ctrl+V pour coller le chemin.';

  @override
  String get firefoxExtensionTitle => 'Firefox';

  @override
  String get firefoxExtensionSteps =>
      'Installer ouvre le XPI signé depuis GitHub. Si Firefox bloque, utilisez Installation manuelle (about:debugging).';

  @override
  String get installInChrome => 'Installer dans Chrome';

  @override
  String get installInFirefox => 'Installer dans Firefox';

  @override
  String get downloadExtensionZip => 'Télécharger ZIP';

  @override
  String get firefoxManualInstall => 'Installation manuelle';

  @override
  String get extensionDownloading => 'Préparation de l\'extension…';

  @override
  String get extensionDownloadFailed =>
      'Échec du téléchargement. Vérifiez la connexion et réessayez.';

  @override
  String get extensionInstallGuideTitle => 'Installation de l\'extension';

  @override
  String get extensionInstallInProgress =>
      'Ne fermez pas cette fenêtre avant la fin du téléchargement.';

  @override
  String get extensionInstallClose => 'Fermer';

  @override
  String get extensionInstallRetry => 'Réessayer';

  @override
  String get extensionStepDownload =>
      'Télécharger les fichiers de l\'extension';

  @override
  String get extensionStepDownloadZip =>
      'Télécharger le ZIP dans Téléchargements';

  @override
  String get extensionStepCopyPath => 'Copier le chemin dans le presse-papier';

  @override
  String get extensionStepOpenBrowser =>
      'Ouvrir la page d\'installation du navigateur';

  @override
  String get extensionStepLaunchFirefox => 'Lancer l\'installateur Firefox';

  @override
  String get extensionStepReadyChrome =>
      'Prêt ! Configuration unique : dans Chrome, mode développeur, Charger l\'extension non empaquetée, puis Ctrl+V.';

  @override
  String get extensionStepReadyZip =>
      'ZIP enregistré. Extrayez-le si besoin, ou utilisez Installer dans Chrome pour la configuration auto.';

  @override
  String get extensionStepReadyFirefox =>
      'Prêt ! Dans about:debugging, chargez le module temporaire → manifest.json (chemin déjà copié).';

  @override
  String get extensionStepReadyFirefoxXpi =>
      'Prêt ! Confirmez l\'installation dans Firefox ; une fois acceptée, l\'extension reste active après redémarrage. Collez ensuite le jeton API dans l\'extension.';

  @override
  String get extensionStepFirefoxFallback =>
      'XPI non ouvert directement — ouverture de la page d\'installation manuelle.';

  @override
  String get extensionStepSkippedBrowser =>
      'Ignoré — Firefox a ouvert l\'installateur directement.';

  @override
  String get chromeInstallStarted =>
      'Chemin copié. Dans Chrome : mode développeur → Charger non empaquetée → Ctrl+V.';

  @override
  String get firefoxInstallStarted =>
      'Firefox va installer l\'extension. Si bloqué, utilisez Installation manuelle.';

  @override
  String extensionPathCopied(String path) {
    return 'Chemin copié : $path';
  }

  @override
  String get extensionInstallFailed =>
      'Impossible d\'ouvrir le navigateur. Essayez Télécharger ZIP.';

  @override
  String get extractingTitle => 'Extraction du titre...';

  @override
  String get extractingSource => 'Extraction de la source...';

  @override
  String get extractingSize => 'Extraction de la taille...';

  @override
  String get unknownTitle => 'Titre inconnu';

  @override
  String get collapseSidebar => 'Réduire la barre latérale';

  @override
  String get expandSidebar => 'Agrandir la barre latérale';

  @override
  String get collapseInspector => 'Réduire l\'inspecteur';

  @override
  String get expandInspector => 'Agrandir l\'inspecteur';

  @override
  String get experimentalXFeedSection => 'X Feed expérimental';

  @override
  String get experimentalXFeedGobird => 'Utiliser gobird (expérimental)';

  @override
  String get experimentalXFeedGobirdDesc =>
      'Fil d\'accueil en lecture seule via gobird embarqué. Désactivé par défaut. Contrevient aux Conditions d\'utilisation de X et peut entraîner une suspension de compte.';

  @override
  String get experimentalXFeedWarning =>
      'Avertissement : gobird utilise des API privées non officielles de X. Vous assumez tous les risques. Le fil DOM local reste le fallback par défaut.';

  @override
  String get experimentalXFeedConsentTitle => 'Activer gobird expérimental ?';

  @override
  String get experimentalXFeedConsentBody =>
      'gobird utilise des API X non officielles, peut cesser de fonctionner sans préavis et peut entraîner une suspension ou un bannissement. Les cookies restent sur ce PC. Continuez uniquement si vous acceptez ces risques.';

  @override
  String get experimentalXFeedConsentConfirm => 'Je comprends — activer';

  @override
  String get gobirdBrowser => 'Session navigateur gobird';

  @override
  String get gobirdBrowserDesc =>
      'Navigateur connecté à X.com pour l\'extraction de cookies (Chrome ou Firefox)';

  @override
  String get gobirdBinaryStatus => 'Binaire gobird';

  @override
  String gobirdBinaryFound(String version) {
    return 'Trouvé : $version';
  }

  @override
  String get gobirdBinaryMissing =>
      'Non embarqué — moteur expérimental indisponible';

  @override
  String get gobirdDisableNow => 'Désactiver gobird maintenant';

  @override
  String get playerPrevious => 'Précédent';

  @override
  String get playerNext => 'Suivant';

  @override
  String duplicatesSkipped(int count) {
    return '$count doublons ignorés';
  }
}
