# Plan: Age Verification Detection & Interactive Help Dialog

## Context & Problem
Sites with adult age verification (+18 years) like xHamster, Pornhub, etc. block video streams when accessed without cookies or from regions with strict age verification laws (such as France / Arcom). `yt-dlp` returns `No video formats found`, which displays `Aucun format vidéo accessible. Le site a peut-être changé sa structure ou bloque l'accès sans cookies/navigateur.`.
The user wants an interactive prompt/dialog to detect age verification failures and provide actionable solutions (integrated in-app browser on mobile, Tor proxy on desktop, cookie browser configuration, and retry).

---

## Architecture & Implementation Steps

### Phase 1: Detection Logic
- In `lib/core/download/download_status_guard.dart`:
  - Add `isAgeVerificationFailure({required String? error, required String url})`
  - Targets `AgeRestrictedException` messages and `NoVideoFormatsException` / no format errors on adult sites (`xhamster`, `pornhub`, `xnxx`, `xvideos`, `spankbang`, etc.).

### Phase 2: In-App Browser Routing Enhancement
- In `lib/features/browser/x_browser_view.dart`:
  - Support `initialUrl` parameter so the user can open the exact video URL directly.
- In `lib/core/router/app_router.dart`:
  - Pass `state.extra as String?` to `XBrowserView(initialUrl: initialUrl)`.

### Phase 3: Interactive Help Dialog Component
- Create `lib/features/downloader/presentation/views/dialogs/age_verification_help_dialog.dart`:
  - Adaptive UI (Mobile & Desktop).
  - Explains the origin of the block (+18 age gate / regional Arcom restriction).
  - Action 1: "Ouvrir dans le navigateur intégré" (Mobile: opens in-app WebView to validate cookies; Desktop: opens browser).
  - Action 2: "Contourner avec le Proxy Tor" (Desktop only: toggles Tor and retries).
  - Action 3: "Configurer le navigateur de cookies" (Desktop: dropdown / quick select).
  - Action 4: "Réessayer le téléchargement".

### Phase 4: UI Integration Across Mobile and Desktop
- In `lib/features/downloader/presentation/widgets/mobile_download_card.dart`:
  - Add an interactive amber alert pill when age verification failure is detected ("Vérification d'âge détectée — Voir les solutions").
- In `lib/features/downloader/presentation/views/mobile/mobile_download_details_sheet.dart`:
  - Add dedicated Age Verification banner and button.
- In `lib/features/downloader/presentation/widgets/download_item_card.dart` & `download_card.dart`:
  - Add an interactive badge/button on failed cards for desktop.
- In `lib/features/downloader/presentation/views/inspector/download_inspector.dart`:
  - Add "Résoudre la vérification d'âge" button in error panel.

### Phase 5: Verification & Testing
- Run `flutter analyze` on modified files.
- Verify tests pass.
