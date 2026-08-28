# Taille du dossier cible sur la carte Storage Usage

- Date: 2026-08-28
- Statut: approuvée
- Surface: carte **Utilisation du stockage** de l'écran Réglages > Sortie
- Fichiers principaux: `lib/core/ui/settings/widgets/storage_chart.dart`, nouveau `FolderSizeService`

## Objectif

La carte Storage Usage montre l'espace **utilisé** et **libre** du volume qui contient le dossier de sortie. Elle ne dit pas combien pèse ce dossier.

Cette spec ajoute, sur la même carte, la taille **récursive sur disque** du dossier de téléchargement effectif, à côté de l'utilisé / libre du volume. L'utilisateur voit ce que le dossier cible occupe, le reste du volume, et l'espace libre.

## Hors périmètre

- Ne pas remplacer ni supprimer les stats de volume (total, utilisé, libre). Elles restent la source du donut de disque.
- Ne pas persister le cache sur disque. Cache mémoire uniquement, perdu à la fermeture du processus.
- Ne pas réutiliser `DiskSpaceService` (espace libre système, TTL 30 s, PowerShell). Autre responsabilité.
- Ne pas limiter le total aux fichiers suivis par la bibliothèque. La métrique est le dossier sur disque, pas la base interne.
- Ne pas mettre à jour le total en direct pendant un téléchargement. Un appui sur Actualiser suffit.
- Ne pas ajouter de page, de tuile, ni de navigation vers l'Explorateur.
- Ne pas afficher plus de 3 sous-dossiers, ni un arbre complet.
- Ne pas scanner un disque au hasard si le dossier de sortie est vide.

## UX

### Chemin cible

`StorageChart` reçoit le **chemin effectif**, pas la chaîne brute des réglages.

Résolution, dans `output_settings_view.dart`, via `DownloadPathResolver.resolve`:

1. Si `settings.outputFolder` est non vide après trim: ce chemin.
2. Sinon: `%USERPROFILE%\Downloads` (`userProfile` + `\Downloads`).
3. `itemFolders` est toujours `[]` depuis cet écran: on ne prend pas le dossier d'un téléchargement existant.

Si `USERPROFILE` est absent, le chemin est vide: dossier traité comme manquant (0 octet, 0 fichier). Le graphique de volume garde son repli actuel (premier volume si le chemin ne correspond pas).

### Structure de la carte (layout B)

Titre inchangé: `storageUsage`. À droite du titre: caption d'état de scan, puis le bouton Actualiser existant.

Rangée principale: donut à gauche, légende à droite.

Sous cette rangée, un **bloc dossier compact**:

1. Taille du dossier + part de l'espace **utilisé** du volume (clé `storageFolderOfUsed`).
2. Nombre de fichiers (`storageFileCount`).
3. Barre horizontale vidéo / audio / autre (hauteur 8 px, largeur du bloc, `borderRadius` 4).
4. Top 3 des sous-dossiers (basename + taille), section masquée s'il n'y en a aucun.

Couleurs de la barre de types: vidéo `AppColors.info`, audio `AppColors.accent`, autre `AppColors.textDisabled`. Une catégorie à 0 octet n'a pas de segment. Si les trois sont à 0: piste unique `border` (8 px).

### Donut à 3 segments

Parts calculées sur la **capacité totale du volume**:

| Segment | Valeur | Couleur | Libellé |
| --- | --- | --- | --- |
| Dossier | `min(tailleDossier, espaceUtilise)` | `AppColors.warning` | `storageFolder` |
| Autre utilisé | `espaceUtilise - min(tailleDossier, espaceUtilise)` | `AppColors.primary` (bleu Utilisé actuel) | `storageOtherUsed` |
| Libre | espace libre | `AppColors.success` (vert actuel) | `storageFree` |

`AppColors.warning` est l'accent distinct: ce n'est pas le bleu `primary` de l'utilisé, ni le vert `success` du libre. `AppColors.accent` n'est pas utilisé sur le donut (trop proche de `primary` sur certains presets).

Règles pie:

- Une part a **0 octet** n'est pas dessinée. Si un snapshot dossier existe, la légende garde les 3 lignes (`0 B` / `0.0%` pour une part nulle).
- Sans snapshot dossier (première charge sans cache, ou erreur sans cache): donut **2 parts** Utilisé (`primary`, tout l'espace utilisé) + Libre. Légende **2 lignes** (`storageUsed` existant + `storageFree`). Pas de ligne Dossier.
- Si la taille scannée dépasse l'espace utilisé: le donut cale le segment Dossier sur l'utilisé; Autre utilisé = 0 (part omise). La légende Dossier affiche la taille **scannée réelle**.

### Pourcentages

- Une décimale, comme aujourd'hui: `toStringAsFixed(1)` (séparateur point, identique au donut actuel).
- **Sur le donut et dans la légende**, chaque part **dessinée** affiche son % du **volume total**.
- La légende est la source des **tailles en octets** (`FormatUtils.formatBytes`). Le donut n'affiche pas les octets.
- Seuil part trop mince: **part < 5.0% du volume total**. Pour cette part, le % est dessiné **hors de l'anneau**: `titlePositionPercentageOffset` = `1.4`. Les parts >= 5.0% gardent `0.5` (texte dans l'anneau). Couleur du % extérieur: `textPrimary`. Couleur du % intérieur: blanc.
- Si plusieurs parts sont < 5.0%, chacune sort de l'anneau.
- La part de l'espace **utilisé** (taille dossier / utilisé) n'apparaît que dans le bloc détails. Si utilisé = 0: afficher `0.0%`, pas de division par zéro.

### États

**Disque.** Spinner plein-carte **uniquement** tant que le volume n'est pas connu (comportement actuel). Dès que le volume est prêt, donut + légende s'affichent même si le dossier n'est pas prêt.

**Dossier, pas de cache.** Skeleton dans le bloc détails (1 ligne taille, 1 barre, 3 lignes) jusqu'au premier résultat. Caption: `storageScanInProgress`. Pas de spinner plein-carte pour le dossier.

**Dossier, cache présent et âge < 10 minutes, même chemin.** Chiffres tout de suite. Caption: `storageLastScanned` avec l'heure locale `HH:mm` de `scannedAt`. Pas de rescan automatique.

**Dossier, cache présent et âge >= 10 minutes.** Cache affiché tout de suite. Rescan en arrière-plan. Pendant ce rescan: chiffres conservés, spinner **sur le bouton Actualiser**, caption `storageScanCached`.

**Changement de chemin.** Vider l'état dossier du widget. Ne jamais afficher les chiffres de l'ancien chemin. `peek` puis TTL sur le **nouveau** chemin uniquement.

**Actualiser.** Toujours forcé: rescan volume **et** rescan dossier (`force: true`), ignore le TTL. Si un scan dossier est déjà en vol pour cette clé, ne pas empiler d'isolat: rejoindre ce `Future`. Le volume est relancé tout de suite.

**Dossier manquant** (chemin résolu, `Directory` inexistant): succès, pas une erreur. 0 octet, 0 fichier, top 3 masqué, barre de types vide (piste `border`). Donut volume affiché. Caption: `storageLastScanned`.

**Dossier vide existant:** mêmes chiffres que manquant. Caption: `storageLastScanned`.

**Erreur / accès refusé, sans cache:** donut 2 parts Utilisé / Libre. Bloc dossier: uniquement `storageScanError`. Actualiser pour réessayer. Pas d'exception jusqu'au framework.

**Erreur / accès refusé, avec cache:** garder donut 3 parts et les chiffres du cache. Caption: `storageScanError` (à la place de `storageLastScanned` / `storageScanCached`). Actualiser pour réessayer.

**Téléchargements en cours:** les totaux peuvent changer entre deux scans. Pas de suivi live. Actualiser suffit.

## Architecture et flux de données

### `FolderSizeService` (nouveau)

Fichier: `lib/core/services/folder_size_service.dart`.

Ne pas étendre `DiskSpaceService`. Ne pas y appeler PowerShell.

```dart
class FolderSizeSnapshot {
  final String path;
  final int totalBytes;
  final int fileCount;
  final List<FolderSizeEntry> topSubfolders; // 0 a 3
  final int videoBytes;
  final int audioBytes;
  final int otherBytes;
  final DateTime scannedAt;
}

class FolderSizeEntry {
  final String name; // basename uniquement
  final int bytes;
}

sealed class FolderSizeResult {}
class FolderSizeOk extends FolderSizeResult {
  FolderSizeOk(this.snapshot);
  final FolderSizeSnapshot snapshot;
}
class FolderSizeError extends FolderSizeResult {
  FolderSizeError(this.path);
  final String path;
}

typedef FolderScanner = Future<FolderSizeSnapshot> Function(String path);
```

API:

- `FolderSizeService({FolderScanner? scanner, DateTime Function()? clock})`
- Production: `scanner` = `compute` sur une fonction top-level; `clock` = `DateTime.now`
- `FolderSizeSnapshot? peek(String path)` - lecture cache, aucun I/O, renvoie aussi un cache périmé
- `Future<FolderSizeResult> getSize(String path, {bool force = false})`
- TTL: `static const cacheTtl = Duration(minutes: 10)`
- Cache: `Map<String, FolderSizeSnapshot>` mémoire. Clé : chemin Windows normalisé (`/` -> `\`, trim, minuscule)
- `getSize(force: false)`: si cache d'âge `< 10 min` -> `FolderSizeOk` sans isolat. Sinon: scan, puis mise à jour du cache en cas de succès
- `getSize(force: true)`: toujours scanner (ou rejoindre le scan en vol de cette clé)
- Un scan en vol par clé: les appels suivants pour la même clé attendent le même `Future`
- `resetCache()` (tests): vide cache et futurs en vol
- Dossier inexistant: `FolderSizeOk`, compteurs à 0, `topSubfolders` vide, `scannedAt` = `clock()`
- Échec isolat / IO / accès sur la **racine**: `FolderSizeError`. Un sous-dossier inaccessible est ignoré, le scan continue
- Échec: ne pas écraser un cache précédent pour cette clé

### Métrique du scan

`Directory.list(recursive: true, followLinks: false)`.

Inclus dans `totalBytes` et `fileCount`: fichiers à la racine et dans les sous-dossiers, y compris partiels (`.part`, `.ytdl`, `.aria2`, fragments), miniatures, et tout autre fichier.

Exclus: les répertoires (la taille est la somme des fichiers), les liens et junctions (pas de suivi).

`fileCount` = nombre de fichiers, pas de dossiers.

### Types (video / audio / autre)

Classification par **extension finale** du nom, minuscule. Réutiliser `DownloadFileResolver`, ne pas dupliquer les listes:

- vidéo: `DownloadFileResolver.videoExtensions` (`.mp4`, `.mkv`, `.webm`, `.mov`, `.avi`, `.m4v`, `.flv`, `.3gp`)
- audio: `DownloadFileResolver.audioExtensions` (`.mp3`, `.aac`, `.opus`, `.m4a`, `.ogg`, `.flac`, `.wav`, `.wma`)
- autre: tout le reste, y compris `.part`, `.jpg`, `.webp`, `.json`

`video.mp4.part` -> autre. `videoBytes + audioBytes + otherBytes == totalBytes`.

### Top 3 sous-dossiers

Enfants **directs** du dossier cible qui sont des répertoires (liens exclus). Taille = somme récursive des fichiers de cet enfant. Tri: octets décroissants, puis nom croissant. Au plus 3. Moins de 3: afficher ceux qui existent. Zéro: masquer le bloc.

### Flux widget

`StorageChart` accepte:

- `FolderSizeService folderSizeService` (défaut: instance de production)
- `Future<DiskChartData> Function(String path)? loadDisk` (défaut: scan `DiskSpace()` actuel)

`DiskChartData`: `totalBytes`, `freeBytes`.

À `initState` et si `widget.path` change:

1. Lancer `loadDisk` (ou scan volume actuel).
2. Oublier l'état dossier local si le chemin a changé.
3. `peek(path)`: si non null, afficher ce snapshot tout de suite (même périmé).
4. Si peek est null **ou** `clock() - scannedAt >= 10 min`: appeler `getSize(path, force: false)` et appliquer le `FolderSizeResult`.

Actualiser: `loadDisk` + `getSize(path, force: true)` en parallèle.

Pendant un `getSize` alors qu'un snapshot local existe: ne pas remettre le skeleton; spinner sur Actualiser; caption `storageScanCached` jusqu'au retour (rescan auto ou Actualiser).

### Formatage

Remplacer `_formatBytes` dans `storage_chart.dart` par `FormatUtils.formatBytes`. Convertir les doubles volume avec `.round()` avant l'appel.

## Gestion d'erreurs

| Cas | Donut volume | Bloc dossier | Caption / action |
| --- | --- | --- | --- |
| Volume indisponible | `storageInfoUnavailable` | non rendu | Actualiser relance les deux |
| Volume OK, pas de peek, scan en cours | 2 parts Utilisé / Libre | skeleton | `storageScanInProgress` |
| Volume OK, cache frais | 3 parts (0 omises) | chiffres | `storageLastScanned` |
| Volume OK, cache périmé, rescan | 3 parts sur cache | chiffres cache | spinner Actualiser + `storageScanCached` |
| Dossier manquant / vide | 2 parts (Dossier = 0 omis) | 0 B, 0 fichier, pas de top 3 | `storageLastScanned` |
| Erreur sans cache | 2 parts Utilisé / Libre | `storageScanError` | Actualiser |
| Erreur avec cache | 3 parts sur cache | chiffres cache | `storageScanError` |
| Exception inattendue | try/catch autour volume + dossier | identique erreur sans cache si pas de snapshot | `debugPrint`, pas de rethrow |

Le widget ne propage aucune exception dossier jusqu'au framework.

## Fichiers à modifier

| Fichier | Rôle |
| --- | --- |
| `lib/core/services/folder_size_service.dart` | **nouveau** - isolat, cache 10 min, peek / getSize / resetCache |
| `lib/core/ui/settings/widgets/storage_chart.dart` | donut 3 parts, % interne/externe, bloc détails, états, `FormatUtils` |
| `lib/core/ui/settings/output_settings_view.dart` | chemin effectif (`DownloadPathResolver`, `itemFolders: []`) |
| `lib/l10n/app_en.arb` | clés ci-dessous |
| `lib/l10n/app_fr.arb` | idem |
| `lib/l10n/app_ar.arb` | idem |
| `test/core/services/folder_size_service_test.dart` | **nouveau** |
| `test/core/ui/settings/widgets/storage_chart_test.dart` | **nouveau** |

Fichiers `app_localizations*.dart`: `flutter gen-l10n`, pas d'édition manuelle.

Ne pas toucher: `disk_space_service.dart`, écran stats, bibliothèque, file de téléchargements.

### Clés l10n à ajouter

| Clé | en | fr |
| --- | --- | --- |
| `storageFolder` | Folder | Dossier |
| `storageOtherUsed` | Other used | Autre utilisé |
| `storageFolderOfUsed` | `{percent}% of used` | `{percent}% de l'espace utilisé` |
| `storageFileCount` | ICU: `=0` `0 files`, `=1` `1 file`, `other` `{count} files` | ICU: `=0` `0 fichier`, `=1` `1 fichier`, `other` `{count} fichiers` |
| `storageTypeVideo` | Video | Vidéo |
| `storageTypeAudio` | Audio | Audio |
| `storageTypeOther` | Other | Autre |
| `storageTopSubfolders` | Largest folders | Plus gros dossiers |
| `storageScanInProgress` | Scanning folder... | Analyse du dossier... |
| `storageLastScanned` | Scanned at {time} | Analysé à {time} |
| `storageScanCached` | Cached | Données en cache |
| `storageScanError` | Could not read this folder | Impossible d'analyser ce dossier |

Arabe: les mêmes clés dans `app_ar.arb`, sens équivalent. Aucune chaîne en dur dans le widget.

## Tests

### Service (`folder_size_service_test.dart`)

Arbre temporaire réel (`Directory.systemTemp`) pour les tests 1-7, scanner de production (fonction d'isolat appelée en direct, sans `compute`, pour rester déterministe).

1. **Somme récursive:** un fichier à la racine + un fichier dans un sous-dossier; `totalBytes` = somme des longueurs; `fileCount` = 2.
2. **Partiels et miniatures inclus:** `.part` et `.jpg` dans `totalBytes`, `fileCount` et `otherBytes`.
3. **Types:** `.mp4` -> `videoBytes`; `.mp3` -> `audioBytes`; `.part` -> `otherBytes`; somme = total.
4. **Top sous-dossiers:** 4 enfants directs; garder les 3 plus lourds; égalité de taille: nom croissant.
5. **TTL 10 min:** avec `clock` fake, second `getSize` sans force ne rappelle pas le scanner si l'âge est strictement inférieur à 10 min. Avancer `clock` de `Duration(minutes: 10)` (âge `>= 10 min`): le scanner est rappelé.
6. **Changement de chemin:** résultat de `pathA` jamais renvoyé pour `pathB`. `peek(pathB)` est null tant que `pathB` n'a pas été scanné.
7. **Dossier manquant:** `FolderSizeOk`, 0 partout.
8. **Racine inaccessible:** `scanner` injecté qui lance `PathAccessException`; `getSize` -> `FolderSizeError`. Un cache précédent pour cette clé n'est pas effacé.

Compteur d'appels: wrapper autour du scanner pour les tests 5 et 8.

### Widget (`storage_chart_test.dart`)

`FolderSizeService` fake (ou scanner fake) + `loadDisk` fake. Pas de `DiskSpace` réel.

1. **3 segments:** volume 100, libre 40, dossier 10 -> Dossier 10, Autre 50, Libre 40. Trois `PieChartSectionData` de valeur > 0. Légende: trois % et trois tailles.
2. **% hors anneau:** dossier = 2% du total. Section Dossier: `titlePositionPercentageOffset > 1`. Sections >= 5.0%: offset `<= 1`.
3. **Chargement:** `getSize` inachevé, `peek` null, `loadDisk` déjà résolu -> skeleton dossier, légende Utilisé / Libre visible.
4. **Erreur:** `FolderSizeError`, pas de peek -> texte `storageScanError`, donut 2 parts, `findsOneWidget` sur la carte.
5. **Vide / manquant:** snapshot 0 -> `storageFileCount` à 0, pas de `storageTopSubfolders`, donut sans part Dossier.

## Journal de décisions

1. **Métrique:** taille récursive sur disque du dossier cible (fichiers, sous-dossiers, partiels, miniatures). Pas les seuls fichiers de la bibliothèque.
2. **Détails:** taille dossier + part de l'utilisé du volume; nombre de fichiers; top 3 sous-dossiers; ventilation vidéo / audio / autre; état de scan (en cours, dernière analyse, cache).
3. **Déclenchement:** cache affiché à l'ouverture; rescan auto si cache >= **10 minutes** ou si le chemin a changé; le bouton Actualiser force toujours volume + dossier.
4. **Layout B:** donut 3 parts Dossier (`warning`) / Autre utilisé (`primary`) / Libre (`success`). % sur le donut et dans la légende. Part < 5.0%: % hors anneau. Octets dans la légende seulement. Détails compacts sous la rangée. Caption de scan à côté d'Actualiser.
5. **Chargement:** stats volume dès que le volume est connu; skeleton dossier tant que ni peek ni résultat. Cache présent: chiffres conservés pendant un rescan (spinner sur Actualiser).
6. **Dossier de sortie vide:** scanner `%USERPROFILE%\Downloads` via `DownloadPathResolver` (`itemFolders: []`), pas le premier volume de `DiskSpace`.
7. **Dossier manquant:** 0 octet, 0 fichier, pas de sous-dossiers; le graphique de volume s'affiche.
8. **Erreur / accès refusé:** graphique volume conservé; message court (`storageScanError`); nouvel essai via Actualiser; pas de crash.
9. **Téléchargements en cours:** totaux potentiellement en retard; pas de suivi live; Actualiser suffit.
10. **Architecture:** `FolderSizeService` neuf (isolat, cache mémoire par chemin). Ne pas réutiliser `DiskSpaceService`. Toucher `storage_chart.dart`, le service, l10n en/fr/ar, et `output_settings_view.dart` pour le chemin effectif. `FormatUtils.formatBytes` à la place de `_formatBytes`.
11. **Tests:** service (somme, types, top 3, TTL 10 min, invalidation par chemin) et widget (3 parts, % extérieur, chargement / erreur / vide).
12. **Risque:** faible. UI réversible sur la carte réglages. Risque principal: coût du scan sur un gros dossier, mitigé par isolat + cache 10 min.

## Risque

Faible. Changement confiné à une carte de réglages, sans impact sur la file d'attente ni la bibliothèque.

Mitigations: isolat, cache 10 min, `peek` pour le premier paint, sous-dossiers illisibles ignorés, try/catch autour du service.

Réversibilité: retirer le bloc détails et revenir au donut 2 parts, sans migration (aucun cache disque).
