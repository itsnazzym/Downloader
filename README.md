<div align="center">

<img src="extension/chrome/icons/icon128.png" alt="Modern Downloader" width="96" style="border-radius: 22px; box-shadow: 0 12px 36px rgba(0,0,0,0.45);" />

# Modern Downloader

**Le téléchargeur multimédia universel, privé et ultra-rapide pour Windows et Android.**  
*High-performance, privacy-first media downloader, TikTok archives hub, Tor anonymity & instant LAN transfer.*

<br />

[![Télécharger Setup Windows](https://img.shields.io/badge/Windows-Installer%20(.exe)-0078D4?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/itsnazzym/Downloader/releases)
[![Télécharger Windows Portable](https://img.shields.io/badge/Windows-Portable%20(.zip)-475569?style=for-the-badge&logo=windows-terminal&logoColor=white)](https://github.com/itsnazzym/Downloader/releases)
[![Télécharger Android APK](https://img.shields.io/badge/Android-APK%20(ARM64)-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/itsnazzym/Downloader/releases)
[![Extension Navigateur](https://img.shields.io/badge/Extension-Chrome%20%7C%20Firefox%20(v2.1.30)-F97316?style=for-the-badge&logo=googlechrome&logoColor=white)](#-extension-navigateur-universelle-v2130)
[![GitHub Releases](https://img.shields.io/github/v/release/itsnazzym/Downloader?style=for-the-badge&logo=github&logoColor=white)](https://github.com/itsnazzym/Downloader/releases)

<br />

[![CI](https://img.shields.io/github/actions/workflow/status/itsnazzym/Downloader/ci.yml?branch=main&style=flat-square&label=Build%20CI)](https://github.com/itsnazzym/Downloader/actions)
[![License MIT](https://img.shields.io/badge/License-MIT-10B981?style=flat-square)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.44.8-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12.2-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev)
[![Extension Version](https://img.shields.io/badge/Extension-v2.1.30-EC4899?style=flat-square)](extension_version.json)
[![Design System](https://img.shields.io/badge/UI-Shadcn%20Obsidian%20Black-09090B?style=flat-square)](DESIGN.md)

</div>

---

## ⚡ Pourquoi Modern Downloader ?

**Modern Downloader** réinvente la capture et la gestion de vos médias hors-ligne : finis les sites publicitaires lents, les convertisseurs douteux, les vidéos saccadées et les doublons de transfert. 

Bâti sur une interface épurée **Shadcn Dark** (`#000000` / `#09090b`), il combine la puissance de moteurs CLI éprouvés (`yt-dlp`, `gallery-dl`, `aria2c`, `ffmpeg`), un proxy Tor intégré pour contourner les censures, une extension navigateur ultra-légère et un protocole de transfert réseau local haute fidélité.

```
┌─────────────────────────────────┐        ┌────────────────────────────────────────────────────────┐        ┌────────────────────────────┐
│      Navigateur Web (MV3)       │        │              Modern Downloader (Desktop/App)           │        │   Smartphones & Autres PC  │
│  • Chrome / Brave / Edge        │ ─────► │  • Moteur yt-dlp + aria2c + FFmpeg (1 800+ sites)     │ ─────► │  • Standard LocalSend v2   │
│  • Firefox (XPI signé)          │        │  • Hub Archives & Collections TikTok réconciliées      │        │  • Streaming SHA-256 direct│
│  • Sniffer réseau HLS/DASH/MP4  │ 127.0.0.1 │ • Anonymat Tor Expert Bundle anti-blocage           │  LAN   │  • Mémoire anti-doublons   │
│  • Boutons discrets au survol   │ :6969  │  • Architecture modulaire de plugins à la demande      │        │  • Zéro gel à la prépa     │
└─────────────────────────────────┘        └────────────────────────────────────────────────────────┘        └────────────────────────────┘
```

---

## 🌟 Piliers & Fonctionnalités Clés

### 1. ⚡ Moteur de Téléchargement Multi-Sources & Accélération
- **1 800+ plateformes prises en charge** via `yt-dlp`, `gallery-dl` et extracteurs natifs.
- Capture automatique de tous les flux : **HLS (`.m3u8`)**, **DASH (`.mpd`)**, vidéos MP4/WebM et pistes audio haute fidélité (MP3, M4A, FLAC).
- **Vitesse décuplée** grâce à l'accélération multi-segments via **aria2c** et remuxage **FFmpeg** sans réencodage inutile.
- **Organisation progressive** : classement intelligent automatique par créateur, date et service.

### 2. 🧅 Contournement de Censure & Proxy Tor Intégré
- **Tor Expert Bundle intégré** : démarrage et gestion transparente d'un démon Tor local (`127.0.0.1:9050`).
- Contournement des restrictions géographiques, des bridages d'opérateurs ou des blocages réseau sans configuration fastidieuse.
- Bascule dynamique activable selon le type de domaine ou sur demande globale.

### 3. 🧩 Extension Navigateur Universelle (`v2.1.30`)
- **Boutons discrets au survol (*Hover-only*)** : zéro encombrement visuel sur les flux denses (YouTube, Kick, TikTok, X/Twitter, Instagram, etc.).
- **Panneau latéral & Pop-up avec *Click-to-locate*** : cliquez sur un élément capturé pour faire défiler instantanément la page jusqu'à la vidéo avec halo lumineux.
- **Pont WebSocket temps réel** : communication locale ultra-réactive avec l'application de bureau via `127.0.0.1:6969`.
- **100 % conforme Manifest V3** : zéro script inline, zéro télémétrie, compatible Chrome, Brave, Edge et Firefox.

### 4. 📦 Hub « Archives & Collections » TikTok
- **Indexation colossale** : importez vos archives officielles TikTok (testé sur 19 000+ vidéos indexées instantanément).
- **Synchronisation récursive & réconciliation exacte** : synchronise vos vraies playlists depuis TikTok Web via WebSocket (`TikTokCollectionReconciliationService`) sans restriction de pagination.
- **Lecteur vidéo vertical immersif** : feed vertical plein écran avec défilement fluide et préchargement intelligent (`TikTokVideoCacheService`).
- **Gestionnaire & Filtres avancés** : recherche instantanée par créateur, date, tags, et téléchargement groupé d'un clic.

### 5. 📡 Transfert Réseau Local (LAN Sync) & Streaming SHA-256
- Conforme au standard ouvert **LocalSend v2** (compatible smartphones Android/iOS et PC).
- **Zéro blocage de préparation** : calcul SHA-256 réalisé **en flux direct à la volée** lors de l'envoi HTTP, éliminant totalement les temps d'attente initiaux sur des milliers de fichiers.
- **Scan de dossiers ultra-réactif** : retour visuel en temps réel du nombre de dossiers analysés et estimation immédiate de la taille globale.
- **Mémoire intelligente incrémentale (`SendMemoryStore`)** : sauvegarde au fil de l'eau de chaque fichier expédié avec succès pour ne jamais renvoyer un doublon.

### 6. 🔌 Système de Plugins & Modules à la Carte
- **Architecture modulaire découplée** : chaque grande fonctionnalité (Navigateur X, Hub TikTok, Statistiques, Transfert, etc.) est gérée comme un plugin activable ou désactivable.
- **Gating de routes dynamique** : aucune allocation mémoire ou processus en tâche de fond inutile si le module correspondant n'est pas activé.
- **Catalogue centralisé vérifié** ([`site/plugin-catalog.json`](site/plugin-catalog.json)).

### 7. 🖤 Interface Minimaliste Obsidian (Shadcn UI)
- Thème sombre profond (`#000000` / `#09090b`), bordures ultra-fines (`#27272a`), typographies modernes et dock flottant réactif.
- **Démarrage sans freeze (*AppLaunchOverlay*)** : checklist visuelle de préchauffage avec onde lumineuse dynamique (*Interior Shimmer Wave*) et initialisation asynchrone des services.

---

## 📥 Téléchargements & Versions

| Plateforme / Cible | Format | Description | Lien |
|---|---|---|---|
| **Windows 10 / 11** | **Setup `.exe`** | Installeur Inno Setup complet avec intégration système | [Télécharger le Setup](https://github.com/itsnazzym/Downloader/releases) |
| **Windows 10 / 11** | **Portable `.zip`** | Version autonome prête à l'emploi (binaires CLI & extensions inclus) | [Télécharger le ZIP Portable](https://github.com/itsnazzym/Downloader/releases) |
| **Android (64-bit)** | **APK (`arm64-v8a`)** | Application mobile avec intégration native du menu Partager | [Télécharger l'APK](https://github.com/itsnazzym/Downloader/releases) |
| **Chrome / Brave / Edge** | **Dossier MV3 / ZIP** | Extension navigateur v2.1.30 | [Dossier `extension/chrome/`](extension/chrome) |
| **Firefox** | **Fichier `.xpi`** | Extension signée Mozilla Add-ons (AMO) | [Télécharger le `.xpi`](https://github.com/itsnazzym/Downloader/releases) |

> [!TIP]
> **Sur Windows** : Les utilitaires `yt-dlp`, `ffmpeg`, `ffprobe`, `aria2c`, `gobird` et le bundle Tor sont configurés et vérifiés automatiquement lors du premier lancement.
> Les empreintes cryptographiques de chaque build sont publiées dans [`release/SHA256SUMS.txt`](release/SHA256SUMS.txt).

---

## 📱 Utilisation Mobile (Android)

1. **Partage en 1 clic** : Depuis n'importe quelle application (YouTube, TikTok, Instagram, X/Twitter, etc.), touchez **Partager** → **Modern Downloader**. La vidéo est capturée immédiatement en tâche de fond.
2. **Transfert Direct PC ⇄ Téléphone** : Transférez des dossiers entiers de médias depuis votre ordinateur sans câble USB via l'onglet **Transfert**.
3. **Répertoire par défaut** : Les vidéos et audios sont enregistrés proprement dans le dossier public `Download/ModernDownloader/`.

---

## 💻 Guide Développeur & Compilation

### Prérequis
- [Flutter SDK](https://flutter.dev) (version `3.44.8` ou supérieure) & Dart SDK (`^3.10.7`)
- Visual Studio 2022 avec la charge de travail *Desktop development with C++* (pour Windows)
- PowerShell 7+ (recommandé pour les scripts de packaging)
- Android : construire avec Flutter `3.44.x` (Gradle 8.13, AGP 8.11). Les Flutter plus récents (3.50 et suivants) exigent Gradle 9 et ne construisent pas encore ce projet.
- YouTube (Windows) : yt-dlp utilise un runtime JavaScript (`deno` ou `node`) quand il est installé ; sans lui, l'extraction fonctionne mais certains formats peuvent manquer.

### Démarrage Rapide

```bash
# 1. Cloner le dépôt
git clone https://github.com/itsnazzym/Downloader.git
cd Downloader

# 2. Installer les dépendances
flutter pub get

# 3. Compiler les extensions de navigateur (Chrome & Firefox v2.1.30)
dart run tool/build_extension.dart

# 4. Lancer l'application de développement sous Windows
flutter run -d windows
```

### Scripts de Packaging & Déploiement

```powershell
# Compiler l'exécutable autonome portable Windows uniquement (avec binaires intégrés)
powershell -ExecutionPolicy Bypass -File tool/package_windows.ps1 -PortableOnly

# Compiler l'installeur complet Inno Setup (.exe) + archive portable
powershell -ExecutionPolicy Bypass -File tool/package_windows.ps1

# Compiler l'APK Android ARM64 de production
flutter build apk --target-platform android-arm64 --release

# Vérifier la qualité du code et exécuter la suite de tests
flutter analyze
flutter test
```

---

## 🔒 Confidentialité & Sécurité

- **Serveur local isolé** : Le serveur interne d'écoute de l'extension est strictement lié à `127.0.0.1` et n'est jamais accessible depuis le réseau public.
- **Zéro Télémétrie, Zéro Pisteurs** : Aucun traqueur, aucune publicité, aucune collecte de données analytiques.
- **Cookies & Sessions sécurisés** : L'accès aux cookies de session (pour les vidéos nécessitant une authentification) s'effectue localement et de manière transparente.
- **Politique de confidentialité complète** : Consultez [`extension/privacy.md`](extension/privacy.md).

---

<div align="center">

**Modern Downloader** • Développé avec passion par [itsnazzym](https://github.com/itsnazzym)  
Distribué sous licence libre [MIT](LICENSE).

</div>
