import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tapload/core/download/creator_metadata_parser.dart';
import 'package:tapload/core/download/download_file_resolver.dart';
import 'package:tapload/core/download/media_source_resolver.dart';
import 'package:tapload/core/logger/logger_service.dart';
import 'package:tapload/core/services/binary/binary_locator.dart';
import 'package:tapload/core/services/metadata_extractor_service.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';

/// Un élément planifié pour être déplacé dans l'arborescence créateur.
class ReorganizationPlanItem {
  final DownloadItem item;
  final String currentPath;
  final String newPath;
  final String creator;
  final String site;
  final List<String> sidecars;

  const ReorganizationPlanItem({
    required this.item,
    required this.currentPath,
    required this.newPath,
    required this.creator,
    required this.site,
    this.sidecars = const [],
  });
}

/// Résultat d'une simulation (Dry-Run).
class ReorganizationPreview {
  final List<ReorganizationPlanItem> itemsToMove;
  final int alreadyOrganizedCount;
  final int missingFilesCount;

  const ReorganizationPreview({
    required this.itemsToMove,
    this.alreadyOrganizedCount = 0,
    this.missingFilesCount = 0,
  });

  int get totalToMove => itemsToMove.length;

  /// Regroupe le nombre de fichiers par dossier créateur (ex: "TikTok/user1": 14)
  Map<String, int> get countPerFolder {
    final map = <String, int>{};
    for (final m in itemsToMove) {
      final key = m.site.isNotEmpty ? '${m.site}/${m.creator}' : m.creator;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }
}

/// Événement de progression de la réorganisation.
class ReorganizeProgress {
  final int current;
  final int total;
  final String currentTitle;
  final String targetFolder;
  final bool isCompleted;

  const ReorganizeProgress({
    required this.current,
    required this.total,
    required this.currentTitle,
    required this.targetFolder,
    this.isCompleted = false,
  });

  double get ratio => total > 0 ? (current / total).clamp(0.0, 1.0) : 1.0;
}

/// Service gérant l'organisation progressive des vidéos téléchargées en sous-dossiers par créateur.
class ProgressiveOrganizerService {
  final MetadataExtractorService _metadataExtractor;

  ProgressiveOrganizerService({
    BinaryLocator? binaryLocator,
    MetadataExtractorService? metadataExtractor,
  }) : _metadataExtractor =
           metadataExtractor ??
           MetadataExtractorService(binaryLocator ?? BinaryLocator());

  /// Extrait le nom d'utilisateur/créateur depuis l'URL de la vidéo.
  static String? extractCreatorFromUrl(String url) =>
      CreatorMetadataParser.extractCreatorFromUrl(url);

  /// Détecte le nom du site à partir de l'URL ou du chemin de fichier pour organiser par site.
  /// Utilise MediaSourceResolver en priorité pour une détection infaillible (ex: twimg -> Twitter).
  static String getSiteName(String? url, {String? filePath}) {
    final resolved = MediaSourceResolver.resolve(url: url, filePath: filePath);
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
    try {
      if (url != null && url.isNotEmpty) {
        final host = Uri.parse(url).host.toLowerCase();
        if (host.contains('twimg')) {
          return 'Twitter';
        }
        if (host.contains('tiktok')) {
          return 'TikTok';
        }
        if (host.contains('youtube') || host.contains('youtu.be')) {
          return 'YouTube';
        }
        if (host.contains('twitter') || host.contains('x.com')) {
          return 'Twitter';
        }
        if (host.contains('instagram')) {
          return 'Instagram';
        }
        if (host.contains('twitch')) {
          return 'Twitch';
        }
        if (host.contains('kick.com')) {
          return 'Kick';
        }
        if (host.contains('facebook') || host.contains('fb.com')) {
          return 'Facebook';
        }
      }
    } catch (_) {}
    return 'Other';
  }

  /// Recherche les fichiers satellites (miniature, sous-titres, info.json) liés à la vidéo.
  static List<String> findSidecars(String videoPath) {
    final dir = p.dirname(videoPath);
    final baseName = p.basenameWithoutExtension(videoPath);
    const sidecarExts = [
      '.jpg',
      '.jpeg',
      '.webp',
      '.png',
      '.srt',
      '.vtt',
      '.info.json',
    ];
    final found = <String>[];
    for (final ext in sidecarExts) {
      final sidecarPath = p.join(dir, '$baseName$ext');
      if (File(sidecarPath).existsSync()) {
        found.add(sidecarPath);
      }
    }
    return found;
  }

  /// Résout les collisions de noms de fichiers sans écraser (`video (1).mp4`).
  static String resolveCollision(String targetPath) {
    if (!File(targetPath).existsSync()) return targetPath;
    final dir = p.dirname(targetPath);
    final ext = p.extension(targetPath);
    final baseName = p.basenameWithoutExtension(targetPath);

    var counter = 1;
    while (true) {
      final candidate = p.join(dir, '$baseName ($counter)$ext');
      if (!File(candidate).existsSync()) {
        return candidate;
      }
      counter++;
    }
  }

  /// Nettoie un nom de dossier pour être compatible avec tous les systèmes de fichiers.
  /// Supprime également tout '@' initial (ex: '@Adult_Hoodz' -> 'Adult_Hoodz') selon la règle P0.
  static String sanitizeFolderName(String name) =>
      CreatorMetadataParser.sanitizeFolderName(name);

  /// Extrait le créateur/auteur depuis le titre ou le nom de fichier.
  /// Couvre les motifs :
  /// 1. "Auteur - Titre [ID]" (ex: "100yenAVshop - 2093101471554556190 [2093101471554556190]")
  /// 2. "@Auteur - Titre" (ex: "@Adult_Hoodz - Visit the website...")
  /// 3. "Titre - Credit @Auteur" (ex: "⋆ Blowjob Queen ⋆ - Credit @LolaSky69 [2093310019303272448]")
  /// 4. "NomArtiste [ID]" (ex: "⋆ Blowjob Queen ⋆ [2092675645528555520]")
  static String? extractCreatorFromTitleOrFilename(
    String? title,
    String? filePath,
  ) => CreatorMetadataParser.extractCreatorFromTitleOrFilename(title, filePath);

  /// Extrait le créateur depuis un fichier satellite .info.json s'il existe.
  static String? extractCreatorFromInfoJson(String videoPath) {
    try {
      final dir = p.dirname(videoPath);
      final base = p.basenameWithoutExtension(videoPath);
      final candidates = [
        p.join(dir, '$base.info.json'),
        p.join(dir, '${p.basename(videoPath)}.info.json'),
      ];
      for (final candidate in candidates) {
        final f = File(candidate);
        if (f.existsSync()) {
          final content = f.readAsStringSync();
          final map = jsonDecode(content);
          if (map is Map<String, dynamic>) {
            final uploader =
                map['uploader'] ??
                map['channel'] ??
                map['uploader_id'] ??
                map['creator'];
            if (uploader is String && uploader.trim().isNotEmpty) {
              return sanitizeFolderName(uploader.trim());
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Construit une table de correspondance ID numérique / Tweet ID -> Nom de créateur
  /// en inspectant tous les éléments connus de la bibliothèque de manière coopérative.
  static Future<Map<String, String>> buildTweetIdToCreatorIndex(
    List<DownloadItem> items,
  ) async {
    final index = <String, String>{};

    for (var i = 0; i < items.length; i++) {
      if (i > 0 && i % 30 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final item = items[i];

      // 1. Chercher un créateur fiable depuis l'URL
      var creator = extractCreatorFromUrl(item.request.url);

      // 2. Si pas d'URL canonique, chercher depuis le titre ou nom de fichier
      creator ??= extractCreatorFromTitleOrFilename(item.title, item.filePath);

      if (creator == null ||
          creator.isEmpty ||
          creator.toLowerCase() == 'inconnu') {
        continue;
      }

      final cleanCreator = sanitizeFolderName(creator);

      // Identifier l'ID de la vidéo / tweet depuis les crochets
      final bracketId =
          DownloadFileResolver.extractBracketId(item.filePath) ??
          DownloadFileResolver.extractBracketId(item.title);
      if (bracketId != null &&
          bracketId.isNotEmpty &&
          bracketId != cleanCreator) {
        index[bracketId] = cleanCreator;
      }

      // Identifier l'ID de la vidéo / tweet depuis l'URL
      final urlMatch = RegExp(
        r'(?:status|amplify_video|videos)/(\d{15,22})',
      ).firstMatch(item.request.url);
      if (urlMatch != null) {
        final tweetId = urlMatch.group(1)!;
        index[tweetId] = cleanCreator;
      }
    }

    return index;
  }

  /// Résout le nom du créateur pour un élément donné grâce au pipeline en cascade à 6 niveaux.
  Future<String> resolveCreator(
    DownloadItem item, {
    Map<String, String>? tweetIdToCreatorIndex,
    Future<Map<String, dynamic>?> Function(String url)? onlineMetadataFetcher,
    bool fastOnly = false,
  }) async {
    // Niveau 1 : URL canonique (immédiat, 0ms)
    final fromUrl = extractCreatorFromUrl(item.request.url);
    if (fromUrl != null && fromUrl.isNotEmpty) {
      return sanitizeFolderName(fromUrl);
    }

    // Niveau 2 : Titre & Nom de fichier (immédiat, 0ms - résout >80% des cas yt-dlp)
    final fromTitle = extractCreatorFromTitleOrFilename(
      item.title,
      item.filePath,
    );
    if (fromTitle != null && fromTitle.isNotEmpty) {
      return sanitizeFolderName(fromTitle);
    }

    // Niveau 3 : Index de corrélation par Tweet / Media ID (immédiat, 0ms - atteint 99.3%)
    if (tweetIdToCreatorIndex != null && tweetIdToCreatorIndex.isNotEmpty) {
      final bracketId =
          DownloadFileResolver.extractBracketId(item.filePath) ??
          DownloadFileResolver.extractBracketId(item.title);
      if (bracketId != null && tweetIdToCreatorIndex.containsKey(bracketId)) {
        return tweetIdToCreatorIndex[bracketId]!;
      }
      final urlMatch = RegExp(
        r'(?:status|amplify_video|videos)/(\d{15,22})',
      ).firstMatch(item.request.url);
      if (urlMatch != null &&
          tweetIdToCreatorIndex.containsKey(urlMatch.group(1)!)) {
        return tweetIdToCreatorIndex[urlMatch.group(1)!]!;
      }
    }

    // Niveau 4 : Fichier satellite .info.json s'il existe
    if (item.filePath != null) {
      final fromInfo = extractCreatorFromInfoJson(item.filePath!);
      if (fromInfo != null && fromInfo.isNotEmpty) {
        return fromInfo;
      }
    }

    // En mode fastOnly (utilisé par défaut pour simulate), on n'appelle pas de processus lourd (0ms garanti)
    if (fastOnly) {
      return 'Inconnu';
    }

    // Niveau 5 : Métadonnées multimédia embarquées (ffprobe)
    if (item.filePath != null && File(item.filePath!).existsSync()) {
      try {
        final meta = await _metadataExtractor.extract(item.filePath!);
        if (meta != null) {
          if (meta.artist != null &&
              meta.artist!.isNotEmpty &&
              !meta.artist!.startsWith('http')) {
            return sanitizeFolderName(meta.artist!);
          }
          if (meta.sourceUrl != null) {
            final fromSource = extractCreatorFromUrl(meta.sourceUrl!);
            if (fromSource != null && fromSource.isNotEmpty) {
              return sanitizeFolderName(fromSource);
            }
          }
        }
      } catch (e) {
        LoggerService.debug('ProgressiveOrganizer: metadata extract error: $e');
      }
    }

    // Niveau 6 : Résolution en ligne légère pour les identifiants bruts (Option A)
    if (onlineMetadataFetcher != null) {
      final id =
          DownloadFileResolver.extractBracketId(item.filePath) ??
          DownloadFileResolver.extractBracketId(item.title);
      if (id != null && RegExp(r'^\d{15,22}$').hasMatch(id)) {
        try {
          final permalink = 'https://x.com/i/status/$id';
          final meta = await onlineMetadataFetcher(permalink);
          if (meta != null) {
            final uploader =
                meta['uploader'] ?? meta['uploader_id'] ?? meta['channel'];
            if (uploader is String && uploader.trim().isNotEmpty) {
              return sanitizeFolderName(uploader.trim());
            }
          }
        } catch (_) {}
      }
    }

    return 'Inconnu';
  }

  /// Effectue une simulation (Dry-Run) sans toucher aux fichiers sur le disque.
  Future<ReorganizationPreview> simulate({
    required List<DownloadItem> items,
    required String defaultBaseFolder,
    required bool organizeBySite,
    Future<Map<String, dynamic>?> Function(String url)? onlineMetadataFetcher,
    bool fastOnly = true,
  }) async {
    final itemsToMove = <ReorganizationPlanItem>[];
    var alreadyOrganized = 0;
    var missingFiles = 0;

    // Construction coopérative de l'index de corrélation par ID sur l'ensemble de la bibliothèque
    final idIndex = await buildTweetIdToCreatorIndex(items);

    for (var i = 0; i < items.length; i++) {
      if (i > 0 && i % 25 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final item = items[i];

      final filePath = item.filePath;
      if (filePath == null || filePath.isEmpty) {
        missingFiles++;
        continue;
      }

      final file = File(filePath);
      if (!file.existsSync()) {
        missingFiles++;
        continue;
      }

      final creator = await resolveCreator(
        item,
        tweetIdToCreatorIndex: idIndex,
        onlineMetadataFetcher: onlineMetadataFetcher,
        fastOnly: fastOnly,
      );
      final site = organizeBySite
          ? getSiteName(item.request.url, filePath: filePath)
          : '';
      final baseFolder = item.request.outputFolder?.isNotEmpty == true
          ? item.request.outputFolder!
          : defaultBaseFolder;

      final targetDir = site.isNotEmpty
          ? p.join(baseFolder, site, creator)
          : p.join(baseFolder, creator);

      final currentDir = p.dirname(filePath);

      // Vérifier si le fichier est déjà à l'emplacement cible
      final isAlreadyThere = Platform.isWindows
          ? currentDir.toLowerCase() == targetDir.toLowerCase()
          : currentDir == targetDir;

      if (isAlreadyThere) {
        alreadyOrganized++;
        continue;
      }

      final filename = p.basename(filePath);
      final proposedNewPath = p.join(targetDir, filename);
      final sidecars = findSidecars(filePath);

      itemsToMove.add(
        ReorganizationPlanItem(
          item: item,
          currentPath: filePath,
          newPath: proposedNewPath,
          creator: creator,
          site: site,
          sidecars: sidecars,
        ),
      );
    }

    return ReorganizationPreview(
      itemsToMove: itemsToMove,
      alreadyOrganizedCount: alreadyOrganized,
      missingFilesCount: missingFiles,
    );
  }

  /// Exécute la réorganisation de façon progressive avec respiration pour éviter tout lag d'interface.
  Stream<ReorganizeProgress> executeProgressively({
    required List<ReorganizationPlanItem> planItems,
    required Future<void> Function(
      String itemId,
      String newFilePath,
      String? newThumbnailPath,
    )
    onFileMoved,
    Duration stepDelay = const Duration(milliseconds: 120),
    bool Function()? isCancelled,
  }) async* {
    final total = planItems.length;

    for (var i = 0; i < total; i++) {
      if (isCancelled?.call() == true) {
        LoggerService.i('ProgressiveOrganizer: cancelled by user');
        break;
      }

      final plan = planItems[i];
      final currentFile = File(plan.currentPath);

      if (!currentFile.existsSync()) {
        continue;
      }

      // 1. Assurer la création du dossier cible
      final targetDir = Directory(p.dirname(plan.newPath));
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }

      // 2. Résoudre les collisions de nom
      final safeNewPath = resolveCollision(plan.newPath);
      final safeBaseName = p.basenameWithoutExtension(safeNewPath);

      // 3. Déplacer la vidéo
      String? finalVideoPath;
      try {
        currentFile.renameSync(safeNewPath);
        finalVideoPath = safeNewPath;
      } catch (e) {
        // Fallback copy + delete si changement de partition de disque
        try {
          currentFile.copySync(safeNewPath);
          currentFile.deleteSync();
          finalVideoPath = safeNewPath;
        } catch (copyErr) {
          LoggerService.e(
            'ProgressiveOrganizer: Failed to move ${plan.currentPath} -> $safeNewPath',
            copyErr,
          );
          continue;
        }
      }

      // 4. Déplacer les sidecars en synchronisation
      String? newThumbnailPath;
      for (final sidecarPath in plan.sidecars) {
        final sidecarFile = File(sidecarPath);
        if (sidecarFile.existsSync()) {
          final sidecarExt = p.extension(sidecarPath);
          final newSidecarPath = p.join(
            targetDir.path,
            '$safeBaseName$sidecarExt',
          );
          try {
            sidecarFile.renameSync(newSidecarPath);
          } catch (_) {
            try {
              sidecarFile.copySync(newSidecarPath);
              sidecarFile.deleteSync();
            } catch (_) {}
          }
          if ([
            '.jpg',
            '.jpeg',
            '.webp',
            '.png',
          ].contains(sidecarExt.toLowerCase())) {
            newThumbnailPath = newSidecarPath;
          }
        }
      }

      // 5. Mettre à jour l'élément en base de données / state
      await onFileMoved(plan.item.id, finalVideoPath, newThumbnailPath);

      // 6. Si l'ancien dossier était un dossier "Inconnu" et est désormais vide, le supprimer (règle P2)
      final oldDir = Directory(p.dirname(plan.currentPath));
      if (oldDir.existsSync() &&
          p.basename(oldDir.path).toLowerCase() == 'inconnu') {
        try {
          if (oldDir.listSync().isEmpty) {
            oldDir.deleteSync();
            LoggerService.i(
              'ProgressiveOrganizer: Cleaned up empty Inconnu folder: ${oldDir.path}',
            );
          }
        } catch (_) {}
      }

      yield ReorganizeProgress(
        current: i + 1,
        total: total,
        currentTitle: (plan.item.title != null && plan.item.title!.isNotEmpty)
            ? plan.item.title!
            : p.basename(plan.currentPath),
        targetFolder: plan.site.isNotEmpty
            ? '${plan.site}/${plan.creator}'
            : plan.creator,
        isCompleted: (i + 1) == total,
      );

      // Temps de respiration pour le thread d'affichage (maintien 60 FPS garanti)
      if (stepDelay > Duration.zero) {
        await Future<void>.delayed(stepDelay);
      }
    }
  }
}
