# Vérification backend, téléchargement et features — plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prouver, sur Windows et sur Android, que le moteur de téléchargement, le serveur local, le transfert LAN, l'archive TikTok et l'extension fonctionnent vraiment, et combler les trous de tests qui empêchent de le savoir.

**Architecture:** Trois niveaux. 1) La suite automatique existante (491 tests) reste la base. 2) Des tests « live » marqués `@Tags(['live'])`, exclus par défaut, lancent le vrai `bin/yt-dlp.exe` et de vraies sockets. 3) Un passage sur émulateur Android (AVD `ComiX_Design`) avec l'APK de la branche, piloté par `adb`. Chaque tâche finit par un rapport dans `docs/verification/2026-11-19-report.md`.

**Tech Stack:** Flutter 3.50 (`C:\Users\entre\dev-tools\flutter`), Dart test tags, `bin/yt-dlp.exe`, `bin/ffmpeg.exe`, `bin/aria2c.exe`, youtubedl-android 0.18.1, Android SDK 37 + `adb`, Node pour l'extension.

**Spec:** Demande utilisateur du 2026-11-19 : « côté backend, serveur, fonctions, téléchargement, features, est-ce que tout fonctionne ? » Branche `feature/android-oled-redesign`.

## Global Constraints

- Chaque commande Flutter : `$env:PATH = "C:\Users\entre\dev-tools\flutter\bin;$env:PATH"`, puis `git checkout pubspec.lock` après tout `flutter pub get`.
- Aucun changement de comportement du code de production sauf pour corriger un défaut prouvé par un test qui échoue.
- URL publique de test pour les téléchargements réels : `https://www.youtube.com/watch?v=BaW_jenozKc` (vidéo de test officielle de yt-dlp, ~10 s). Aucune autre URL, aucun compte, aucun cookie personnel.
- Les tests live écrivent uniquement dans un dossier temporaire créé par le test et le suppriment à la fin.
- `flutter test` sans option doit rester vert et ne doit pas lancer les tests live (`dart_test.yaml` : `tags: live: skip: "live"` , lancés avec `--run-skipped -t live`).
- Rien n'est poussé. Un commit par tâche, sur la branche courante.

## Review Focus

1. Le binaire yt-dlp de `bin/` est périmé : YouTube refuse l'extraction → le test live doit afficher la version et l'erreur yt-dlp, pas un simple « failed ».
2. Pas de réseau : les tests live doivent sauter proprement (`markTestSkipped`) au lieu d'échouer après 2 minutes.
3. Le serveur local reçoit une requête sans jeton : il doit répondre 401, jamais lancer de téléchargement (déjà couvert par `local_server_auth_test.dart`, à relancer en Task 1).
4. Sur Android, le premier lancement (`init`) dézippe Python/yt-dlp : le premier téléchargement lancé avant la fin de `init` doit attendre, pas échouer — vérifié en Task 5 étape 4.
5. Un partage Android (intent `SEND`) avec du texte autour du lien (« Regarde ça https://… ») doit extraire l'URL — vérifié en Task 5 étape 5.

---

### Task 1: Base automatique et contrat de l'extension

**Files:**
- Create: `dart_test.yaml`
- Create: `docs/verification/2026-11-19-report.md`

**Interfaces:**
- Produces: tag `live` utilisable par les Tasks 2–4 ; section « Base » du rapport.

- [ ] **Step 1: Créer `dart_test.yaml`**

```yaml
tags:
  live:
    skip: "Test live : lancer avec --run-skipped -t live"
    timeout: 3m
```

- [ ] **Step 2: Lancer la suite complète avec couverture**

Run: `flutter test --coverage --reporter=compact`
Expected: `All tests passed!` (≥ 491 tests), aucun test live exécuté.

- [ ] **Step 3: Vérifier le seuil de couverture de la CI**

Run: `dart run tool/check_coverage.dart --min 30 coverage/lcov.info`
Expected: code de sortie 0.

- [ ] **Step 4: Vérifier le formatage comme la CI**

Run: `dart format --output=none --set-exit-if-changed lib/ test/ tool/`
Expected: code 0. Sinon lancer `dart format lib/ test/ tool/` et l'inclure dans le commit.

- [ ] **Step 5: Construire et valider l'extension**

Run: `dart run tool/build_extension.dart` puis `dart run tool/check_extension_contract.dart`
Expected: les deux sortent en code 0 ; le contrat liste les mêmes messages que `lib/core/services/local_server_service.dart`.

- [ ] **Step 6: Écrire la section « Base » du rapport** (nombre de tests, couverture %, extension OK/KO) et commit

```bash
git add dart_test.yaml docs/verification/2026-11-19-report.md
git commit -m "test: tag live tests and record verification baseline"
```

### Task 2: Téléchargement réel sur Windows (yt-dlp, ffmpeg, aria2c)

**Files:**
- Create: `test/live/desktop_download_live_test.dart`

**Interfaces:**
- Consumes: `YtDlpSource(BinaryLocator, ProcessRunner)` (`lib/features/downloader/data/sources/yt_dlp_source.dart:33`), `fetchMetadata(String url, {String? cookies, ...}) -> Future<Map<String, dynamic>>`, `download(String id, DownloadRequest request) -> Stream<DownloadProgressEvent>` (champs `progress`, `step`, `filePath`). Construire la source comme le fait `lib/features/downloader/data/downloader_data_providers.dart:18`.

- [ ] **Step 1: Écrire les tests, tous `@Tags(['live'])`**

- `binaries are present and runnable` : `bin/yt-dlp.exe --version`, `bin/ffmpeg.exe -version`, `bin/aria2c.exe --version` renvoient chacun le code 0 ; imprimer la version de yt-dlp.
- `fetchMetadata returns formats for the yt-dlp test video` : `metadata['id'] == 'BaW_jenozKc'`, `(metadata['formats'] as List).isNotEmpty`, `metadata['duration'] is num`.
- `download writes a playable file` : la dernière `DownloadProgressEvent` a `progress == 1.0` et un `filePath` qui existe, de taille > 100 Ko ; `ffprobe` sur ce fichier renvoie le code 0.
- `audio only produces an mp3` : `DownloadRequest(url:…, audioOnly: true)` → fichier se terminant par `.mp3`.
- Chaque test commence par une résolution DNS de `www.youtube.com` ; en cas d'échec, `markTestSkipped('pas de réseau')`.

- [ ] **Step 2: Lancer**

Run: `flutter test test/live/desktop_download_live_test.dart --run-skipped -t live`
Expected: 4 tests PASS. Si un test échoue, noter la sortie yt-dlp exacte dans le rapport et passer en Task 2b (ci-dessous) avant de continuer.

- [ ] **Step 3 (Task 2b, seulement en cas d'échec):** reproduire l'erreur en ligne de commande avec `bin/yt-dlp.exe -v <URL>`, écrire un test unitaire non-live qui fige le défaut côté Dart (parsing, arguments), corriger, relancer Step 2.

- [ ] **Step 4: Compléter le rapport (section « Windows ») et commit**

```bash
git add test/live/desktop_download_live_test.dart docs/verification/2026-11-19-report.md
git commit -m "test: live desktop download smoke test"
```

### Task 3: Serveur local et transfert LAN en vrai réseau local

**Files:**
- Create: `test/live/local_services_live_test.dart`

**Interfaces:**
- Consumes: `LocalServerService` (`lib/core/services/local_server_service.dart`, route `/status` ligne 151) et `TransferLanServer` + `LocalSendClient` (`lib/features/transfer/data/`). Reprendre la construction utilisée dans `test/core/services/local_server_service_test.dart` et `test/features/transfer/transfer_lan_server_test.dart`.

- [ ] **Step 1: Écrire les tests `@Tags(['live'])`**

- `status answers on 127.0.0.1 with the token` : `GET http://127.0.0.1:<port>/status` avec le jeton → 200 et corps JSON contenant la version de l'app.
- `status refuses a missing token` : même requête sans jeton → 401.
- `localsend round trip on loopback` : démarrer `TransferLanServer` sur un port libre, envoyer un fichier de 5 Mo avec `LocalSendClient` vers `127.0.0.1`, comparer le hash SHA-256 du fichier reçu à l'original.

- [ ] **Step 2: Lancer**

Run: `flutter test test/live/local_services_live_test.dart --run-skipped -t live`
Expected: 3 PASS.

- [ ] **Step 3: Rapport (section « Serveur et transfert ») et commit**

```bash
git add test/live/local_services_live_test.dart docs/verification/2026-11-19-report.md
git commit -m "test: live loopback checks for local server and LAN transfer"
```

### Task 4: Pont Android côté Dart

**Files:**
- Create: `test/core/android/android_engine_bridge_test.dart`

**Interfaces:**
- Consumes: canal `MethodChannel('com.downloader.modern_downloader/engine')` et les méthodes `ensureInitialized`, `getYtDlpVersion`, `updateYtDlp`, `run`, `start`, `webViewCookies` de `lib/core/android/android_engine_bridge.dart` ; noms de méthodes Kotlin `init`, `version`, `updateYtDlp`, `run`, `start`, `kill`, `webViewCookies` (`EnginePlugin.kt:43-282`).

- [ ] **Step 1: Écrire les tests (non-live, canal simulé avec `TestDefaultBinaryMessengerBinding`)**

- `ensureInitialized calls init once` : deux appels → un seul `init` reçu.
- `version returns the native string` : le simulateur renvoie `'2026.10.01'` → `getYtDlpVersion()` renvoie `'2026.10.01'`.
- `updateYtDlp maps PlatformException to the failure text` : le simulateur lève `PlatformException(code: 'x')` → `'Update check failed'` (texte comparé dans `settings_hub_view.dart`).
- `every Dart method name exists in EnginePlugin.kt` : lire `android/app/src/main/kotlin/com/downloader/modern_downloader/EnginePlugin.kt`, extraire les `"nom" ->`, et vérifier que chaque nom invoqué par le pont Dart y figure.

- [ ] **Step 2: Lancer**

Run: `flutter test test/core/android/android_engine_bridge_test.dart`
Expected: 4 PASS. Un nom absent du Kotlin est un défaut réel : le corriger côté Dart ou Kotlin selon l'usage, puis relancer.

- [ ] **Step 3: Commit**

```bash
git add test/core/android/android_engine_bridge_test.dart
git commit -m "test: cover the Android engine bridge contract"
```

### Task 5: APK et parcours réels sur émulateur Android

**Files:**
- Modify: `docs/verification/2026-11-19-report.md` (section « Android »)
- Create: `build/verification/android/*.png` (captures, non commitées)

- [ ] **Step 1: Construire l'APK**

Run: `flutter build apk --debug`
Expected: `√ Built build\app\outputs\flutter-apk\app-debug.apk`.

- [ ] **Step 2: Démarrer l'émulateur et installer**

Run: `emulator -avd ComiX_Design -no-snapshot-save` (en arrière-plan), attendre `adb wait-for-device` et `adb shell getprop sys.boot_completed` = `1`, puis `adb install -r build\app\outputs\flutter-apk\app-debug.apk`.
Expected: `Success`.

- [ ] **Step 3: Premier lancement**

Run: `adb shell monkey -p com.downloader.modern_downloader 1` puis `adb logcat -d | Select-String "flutter|EnginePlugin"` après 60 s.
Expected: aucune exception ; capture `01_launch.png` (`adb exec-out screencap -p`) montrant la bibliothèque OLED.

- [ ] **Step 4: Téléchargement via la feuille d'ajout**

Ouvrir « + », coller l'URL de test, attendre l'aperçu (titre, durée, taille), lancer. Expected : la ligne passe à « Terminé » ; `adb shell ls` du dossier par défaut (`defaultOutputDir`) montre un `.mp4` > 100 Ko. Captures `02_preview.png`, `03_done.png`.

- [ ] **Step 5: Téléchargement via le partage Android**

Run: `adb shell am start -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT "Regarde ça https://www.youtube.com/watch?v=BaW_jenozKc" -n com.downloader.modern_downloader/.MainActivity`
Expected: un nouveau téléchargement apparaît dans la bibliothèque.

- [ ] **Step 6: Réglages et moteur**

Ouvrir Réglages. Expected : la carte « Moteur yt-dlp » affiche une version ; « Vérifier les mises à jour » renvoie un toast de succès ou « Vérification impossible » (pas de plantage). Capture `04_engine.png`.

- [ ] **Step 7: Navigateur, archive, transfert, stats**

- Web : ouvrir `https://x.com` puis une page de tweet vidéo publique ; la barre « Page prête à télécharger » apparaît.
- Archive TikTok : l'écran s'ouvre sans erreur avec un catalogue vide.
- Envoi : le radar démarre, l'adresse IP de l'émulateur s'affiche.
- Stats : les chiffres reflètent les téléchargements des étapes 4–5.
Captures `05_browser.png` à `08_stats.png`.

- [ ] **Step 8: Rapport (section « Android ») et commit**

```bash
git add docs/verification/2026-11-19-report.md
git commit -m "docs: record Android emulator verification"
```

### Task 6: Synthèse

- [ ] **Step 1:** Compléter l'en-tête du rapport avec un tableau « Fonction / Windows / Android / Preuve » couvrant : métadonnées, téléchargement vidéo, audio seul, serveur local, extension, transfert LAN, partage Android, mise à jour du moteur, navigateur, archive TikTok, statistiques. Chaque case : OK, KO (avec erreur) ou Non testé (avec raison).
- [ ] **Step 2:** Lancer une dernière fois `flutter analyze --no-pub` et `flutter test` ; noter les résultats.
- [ ] **Step 3: Commit**

```bash
git add docs/verification/2026-11-19-report.md
git commit -m "docs: backend verification summary"
```
