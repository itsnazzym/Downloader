<div align="center">

<img src="extension/chrome/icons/icon128.png" alt="Modern Downloader" width="88" style="border-radius: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.3);" />

# Modern Downloader

**Le téléchargeur multimédia universel, privé et ultra-rapide pour Windows et Android.**  
*High-performance, privacy-first media downloader, TikTok archives hub & LAN transfer.*

<br />

[![Télécharger Setup Windows](https://img.shields.io/badge/Windows-Installer%20(.exe)-0078D4?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/itsnazzym/Downloader/releases)
[![Télécharger Android APK](https://img.shields.io/badge/Android-APK%20(ARM64)-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/itsnazzym/Downloader/releases)
[![Extension Navigateur](https://img.shields.io/badge/Extension-Chrome%20%7C%20Firefox-F97316?style=for-the-badge&logo=googlechrome&logoColor=white)](#-extensions-navigateur-universelles-v2115)
[![GitHub Releases](https://img.shields.io/badge/Releases-v1.0.8-6366F1?style=for-the-badge&logo=github&logoColor=white)](https://github.com/itsnazzym/Downloader/releases)

<br />

[![CI](https://img.shields.io/github/actions/workflow/status/itsnazzym/Downloader/ci.yml?branch=main&style=flat-square&label=Build%20CI)](https://github.com/itsnazzym/Downloader/actions)
[![License MIT](https://img.shields.io/badge/License-MIT-10B981?style=flat-square)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.44.8-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Extension Version](https://img.shields.io/badge/Extension-v2.1.15-EC4899?style=flat-square)](extension_version.json)
[![Architecture](https://img.shields.io/badge/Design-Shadcn%20Black-09090B?style=flat-square)](lib/core/ui/setup/app_launch_overlay.dart)

</div>

---

## ⚡ Pourquoi Modern Downloader ?

Modern Downloader réinvente la gestion de vos médias hors-ligne : finis les sites publicitaires lents, les convertisseurs douteux et les doublons de transfert. Conçu avec une interface sombre épurée **Shadcn UI**, il combine un moteur de capture surpuissant, une extension navigateur non-intrusive et un hub d'archives unique.

```
┌─────────────────┐      ┌───────────────────────────┐      ┌──────────────────┐
│  Navigateur     │ ───► │  Modern Downloader (App)  │ ───► │  Smartphones &   │
│  Extension MV3  │      │  Moteur yt-dlp + aria2c   │      │  PC (LocalSend)  │
│  Sniffer réseau │      │  Hub Archives TikTok      │      │  Synchro SHA-256 │
└─────────────────┘      └───────────────────────────┘      └──────────────────┘
```

---

## 🌟 Piliers & Fonctionnalités

### 1. ⚡ Moteur Universel Tout-Terrain
- **1 800+ plateformes prises en charge** via `yt-dlp`, `gallery-dl` et moteur direct.
- Capture automatique de tous les flux web : **HLS (`.m3u8`)**, **DASH (`.mpd`)**, MP4, WebM et audio MP3.
- Vitesse maximale avec accélération multi-segments **aria2c** et remux **FFmpeg** sans perte.

### 2. 🧩 Extension Navigateur Universelle (`v2.1.15`)
- **Boutons discrets au survol (*hover-only*)** : zéro encombrement visuel sur les flux denses (YouTube, Kick, TikTok, Spankbang, X).
- **Localisation dans la page (*Click-to-locate*)** : cliquez sur un titre dans le panneau latéral pour faire défiler instantanément la page jusqu'à la vidéo avec un halo lumineux.
- **Sniffer réseau & pont WebSocket** : envoi direct des flux vers l'application desktop en 1 clic via `127.0.0.1:6969`.
- **100 % conforme Manifest V3** : zéro script inline, zéro télémétrie, compatible Chrome, Brave, Edge et Firefox.

### 3. 📦 Hub « Archives & Imports » (TikTok Collections & Catalog)
- **Indexation colossale** : importez vos archives officielles TikTok (19 000+ vidéos indexées instantanément).
- **Synchronisation récursive & exacte** : synchronise vos vraies playlists depuis TikTok Web sans restriction de pagination.
- **Heuristique d'ancrage chronologique strict** : comble automatiquement les collections incomplètes selon la fenêtre temporelle exacte des vidéos vérifiées, avec bouton de réinitialisation sécurisé.
- **4 modes de visionnage & tri immersifs** :
  - 📁 **Dossiers réels** : par collections et créateurs.
  - 📱 **Feed vidéo TikTok** : scroll vertical infini plein écran avec préchargement intelligent.
  - 🔀 **Mode Tinder (Swipe)** : triez vos favoris par balayage gauche/droite.
  - 📊 **Grille filtrée** : recherche par mot-clé, année et téléchargement groupé.

### 4. 📡 Transfert Réseau Local (LAN Sync) & Mémoire Intelligente
- Compatible avec le protocole standard **LocalSend v2**.
- **Mémoire intelligente SHA-256** : synchronisation incrémentale n'envoyant **que les nouvelles vidéos**, sans jamais renvoyer les fichiers déjà reçus par votre téléphone.
- Découverte automatique mDNS et compression ZIP en tâche de fond (*isolate* non-bloquant).

### 5. 🖤 Démarrage Black Minimalist (Shadcn UI)
- Écran de lancement noir obsidienne (`#000000` / `#09090b`) avec carte épurée et checklist système dynamique.
- **Barre de progression animée avec onde de brillance intérieure (*Interior Shimmer Wave*)** et compteur monospace (`JetBrains Mono`).
- **Préchauffage réel sans aucun lag** : le moteur multimédia, les services réseau et l'indexation sont préchauffés avant l'affichage du dashboard.

---

## 📥 Téléchargement & Installation

| Système / Cible | Type d'installation | Lien de téléchargement |
|---|---|---|
| **Windows 10 / 11** | Installeur complet (Setup `.exe`) | [Télécharger le Setup](https://github.com/itsnazzym/Downloader/releases) |
| **Windows (Portable)** | Archive ZIP autonome sans installation | [Télécharger le ZIP Portable](https://github.com/itsnazzym/Downloader/releases) |
| **Android (64-bit)** | Fichier APK (`arm64-v8a`) | [Télécharger l'APK](https://github.com/itsnazzym/Downloader/releases) |
| **Chrome / Brave / Edge** | Extension MV3 décompressée | [Dossier `extension/chrome/`](extension/chrome) |
| **Firefox** | Fichier `.xpi` signé AMO | [Télécharger le `.xpi`](https://github.com/itsnazzym/Downloader/releases) |

> [!TIP]
> **Sur Windows** : Les binaires `yt-dlp`, `ffmpeg` et `aria2c` sont automatiquement configurés et mis à jour au démarrage de l'application.

---

## 📱 Utilisation Mobile (Android)

1. **Partage en 1 clic** : Depuis n'importe quelle application (YouTube, TikTok, X, Instagram), appuyez sur **Partager** → **Modern Downloader**. Le téléchargement démarre immédiatement en tâche de fond.
2. **Transfert PC ⇄ Mobile** : Recevez des dossiers complets depuis votre PC sans câble via le menu **Transfert**.
3. **Dossier de stockage** : Les fichiers sont enregistrés dans `Download/ModernDownloader/`.

---

## 💻 Pour les Développeurs

```bash
# 1. Cloner le projet
git clone https://github.com/itsnazzym/Downloader.git
cd Downloader

# 2. Installer les dépendances Dart/Flutter
flutter pub get

# 3. Compiler l'extension navigateur (Chrome & Firefox)
dart run tool/build_extension.dart

# 4. Lancer l'application desktop
flutter run -d windows

# 5. Compiler les binaires de production
flutter build windows --release                              # Desktop Windows
flutter build apk --target-platform android-arm64 --release   # Android APK ARM64
powershell -File tool/package_windows.ps1                    # Installeur Inno Setup
```

---

## 🔒 Confidentialité & Sécurité

- **100 % Local** : Le serveur interne est lié strictement à `127.0.0.1` et n'est pas exposé sur Internet.
- **Zéro Télémétrie** : Aucun pistage, aucune publicité, aucun traqueur externe.
- **Isolation des Cookies** : Vos sessions de navigation restent strictement sur votre machine locale.
- **Politique de confidentialité** : Consultez [extension/privacy.md](extension/privacy.md).

---

<div align="center">

**Modern Downloader** • *Créé avec passion par [itsnazzym](https://github.com/itsnazzym)*  
Licence [MIT](LICENSE)

</div>
