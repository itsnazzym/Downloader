# Plan de Refonte Mobile Android & Correction Moteur yt-dlp

## Objectif
Transformer l'expérience Android de TapLoad en une application mobile native, fluide et ergonomique, avec des composants UI dédiés au tactile et un backend moteur optimisé pour Android résolvant l'erreur d'extraction vidéo (impersonation / aucun format) vue sur la capture d'écran.

---

### Phase 1 : Backend & Moteur de Téléchargement Android
- [x] **1.1 Injection d'en-têtes mobiles & contournement anti-bot (`yt_dlp_source.dart`)**
  - Configurer un User-Agent navigateur moderne (`Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 ... Chrome/130.0.0.0 Mobile Safari/537.36`) et un `Referer` par défaut pour Android et les sites protégés (XHamster, Twitter, etc.).
  - Assurer la conversion des cookies WebView en format Netscape (`.txt`) et les injecter via `--cookies <file>` lors de l'extraction de métadonnées ET du téléchargement.
- [x] **1.2 Moteur natif & Canal de mise à jour (`EnginePlugin.kt` & `AndroidEngineBridge.dart`)**
  - Prendre en charge le canal `YoutubeDL.UpdateChannel.NIGHTLY` lors des mises à jour pour obtenir les derniers extracteurs corrigés.
  - Exposer une méthode de mise à jour manuelle et de vérification de version accessible depuis l'UI mobile.
- [x] **1.3 Diagnostic et catégorisation intelligente des erreurs (`yt_dlp_exception.dart`)**
  - Détecter les erreurs courantes (impersonation manquante, formats indisponibles, Cloudflare/bot block, cookies nécessaires).
  - Fournir des messages d'aide clairs en français et des solutions suggérées au lieu de dumps bruts de terminal.

---

### Phase 2 : Composants UI Mobile Dédiés
- [x] **2.1 `MobileDownloadCard` (Composant de carte pour smartphone)**
  - Carte tactile moderne avec cible de toucher >= 48px.
  - Miniature 16:9 avec badge d'état élégant (téléchargement, terminé, erreur).
  - Barre de progression intégrée et vitesse/taille lisibles d'un coup d'œil.
  - Actions rapides tactiles (Lecture, Réessayer, Supprimer).
- [x] **2.2 `MobileDownloadDetailsSheet` (Feuille de détails mobile remplaçant l'inspecteur desktop)**
  - Remplace le `DownloadInspector` desktop sur mobile par un BottomSheet Material 3 adapté aux pouces.
  - Aperçu vidéo grand format / lecteur intégré.
  - Encart d'erreur didactique avec conseils ("Mettre à jour le moteur", "Ouvrir dans le navigateur pour valider les cookies", "Réessayer").
  - Section "Logs techniques" repliable pour consulter les détails bruts sans encombrer l'écran.
  - Boutons d'action : Partager (via Intent Android natif), Ouvrir avec, Copier lien, Supprimer, Réessayer.
- [x] **2.3 `MobileAddDownloadSheet` (Feuille d'ajout mobile)**
  - Remplacement du dialogue de bureau par une feuille coulissante mobile ergonomique.
  - Détection automatique du lien dans le presse-papier avec bouton de collage rapide.
- [x] **2.4 Résolution du chevauchement du FAB dans `MobileAppShell`**
  - Rétracter ou masquer le FAB flottant lorsque des modales/feuilles sont ouvertes ou lors des interactions pour éliminer tout chevauchement.

---

### Phase 3 : Intégration & Paramètres
- [x] **3.1 Intégration dans `DownloadRowHost` et `DownloadView`**
  - Brancher `MobileDownloadCard` sur mobile et `DownloadCard`/`DownloadItemCard` sur desktop.
  - Ouvrir `MobileDownloadDetailsSheet` lors du clic sur mobile.
- [x] **3.2 Bouton de mise à jour du moteur dans les Paramètres & Feuille d'erreur**
  - Permettre à l'utilisateur de lancer une mise à jour immédiate de yt-dlp en un tap.

---

### Phase 4 : Vérification & Tests
- [x] **4.1 Tests unitaires et tests de widgets**
  - Vérifier la détection et les arguments de cookies/headers dans `yt_dlp_source_test.dart`.
  - Vérifier la compilation et l'analyse statique (`flutter analyze`).
