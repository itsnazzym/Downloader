# Appairage automatique extension ↔ application — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** L'extension se connecte seule à l'application ; au premier contact l'utilisateur compare un code à 4 chiffres et clique « Autoriser » dans l'application ; ensuite plus aucune saisie de jeton.

**Architecture :** Côté Dart, une politique d'origine (refus des pages web), un magasin de navigateurs appairés (jetons hachés), un coordinateur de demandes d'appairage (code, limites, expiration) et une machine à états par socket dans `LocalServerService` ; l'approbation passe uniquement par un dialogue de l'application. Côté extension, un module JS pur `MDPairing` (état, délais de reconnexion) branché dans `connection.js` et le popup.

**Tech Stack :** Dart/Flutter, Riverpod, `shared_preferences`, `dart:io` WebSocket ; JavaScript sans build (MV3 Chrome + Firefox), `node:test`.

**Spec :** `docs/superpowers/specs/2026-11-27-extension-pairing-design.md` (lire aussi « Précisions après relecture » et « Décision de l'utilisateur : code à comparer »).

## Global Constraints

- Branche `feat/extension-pairing`, empilée sur `feat/extension-redesign` (PR de la refonte non fusionnée) ; une seule PR à la fin.
- Origines acceptées pour l'appairage : `chrome-extension://<id>` (Chrome, Edge, Brave, Opera, Vivaldi) et `moz-extension://<uuid>`. Une connexion dont l'`Origin` est présent et d'un autre type (`https://…`, `http://…`, `null`, `file://`) est refusée en HTTP 403 **avant** la mise à niveau WebSocket. Une connexion **sans** `Origin` n'est acceptée que si elle présente un jeton valide ; elle ne peut pas demander d'appairage. `/status` reste hors contrôle.
- Messages du protocole (noms exacts) : client → serveur `HELLO { token? }`, `PAIR_REQUEST { extensionVersion? }` ; serveur → client `AUTH_FAILED { reason: 'pairing_required' }`, `PAIR_PENDING { requestId, code, expiresInSeconds }`, `PAIR_OK { token }`, `PAIR_DENIED { retryAfterSeconds }`, `PAIR_EXPIRED`, `PAIR_PAUSED { retryAfterSeconds }`, `PAIR_BUSY`. Le libellé du navigateur est déduit côté serveur du `User-Agent` ; ce que le client déclare n'est jamais affiché comme fait.
- Jeton d'appairage : 256 bits (`Random.secure`), base64url sans remplissage, stocké **haché** (SHA-256 en hex) ; jamais journalisé ; comparaison à temps constant. Le jeton manuel historique (`settings.apiToken`) continue d'être accepté.
- Code de comparaison : 4 chiffres (`0000`–`9999`), généré par le serveur à chaque demande, affiché dans l'invite de l'application et renvoyé dans `PAIR_PENDING` pour affichage dans le popup ; jamais saisi. L'approbation n'est possible que par l'interface de l'application (jamais par un message WebSocket).
- Limites : une demande en attente à la fois ; 3 demandes par heure et par origine ; expiration 2 minutes ; pause de 10 minutes de l'origine après refus ou révocation ; « Toujours refuser » bloque l'origine jusqu'à déblocage dans les réglages ; `PAIR_PENDING` répété toutes les 10 s pendant l'attente ; fenêtre `PAIR_REQUEST` de 10 s après `AUTH_FAILED`.
- Reconnexion de l'extension tant que l'application est fermée : toutes les 3 s pendant 5 minutes puis toutes les 10 s.
- L'invite fait `windowManager.show()` + `focus()` même en mode « Ne pas déranger ». La notification « extension connectée » n'apparaît plus qu'à l'appairage et à la première connexion de chaque session de l'application.
- Textes en fr, en, ar (`lib/l10n/app_*.arb` puis `flutter gen-l10n` ; `extension/shared/_locales/*/messages.json`). Aucun jeton, code ou cookie dans les journaux.
- Les copies `extension/chrome` et `extension/firefox` sont générées (`dart run tool/build_extension.dart`, voir la gestion des versions dans `docs/…/task-16` : lancer avec `--release-tag v1.0.27`, la version reste 2.2.0) ; tout nouveau fichier de `extension/shared` est ajouté à `commonFiles` (`tool/build_extension.dart`), à `packaged` et à la liste d'existence de `tool/check_extension_contract.dart`, et chargé par `popup.html`/`feed_panel.html` ou le service worker ; les nouveaux messages sont ajoutés aux `requiredTokens` du contrat.
- flutter n'est pas dans le PATH : `C:\Users\entre\dev-tools\flutter\bin\flutter.bat` (dart : `…\bin\dart.bat`). Vérification de fin de tâche : tests ciblés, puis `flutter analyze --no-pub` (0 erreur, 0 avertissement dans les fichiers de la tâche ; les 338 infos existantes sont connues), `node --test "test/extension/*.cjs"` pour les tâches JS, `dart format` sur les fichiers modifiés. Pas de longs timers réels dans les tests (injecter l'horloge).
- Commits en anglais, trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Ne pas pousser ni fusionner sans demande de l'utilisateur.

## Review Focus

- Origine `https://evil.example`, `null`, `file://`, `chrome-extension://` mal formé, absente avec jeton invalide : jamais d'authentification ni d'invite.
- Un client local qui falsifie l'`Origin` d'une extension : il ne reçoit un jeton que si l'utilisateur clique « Autoriser » dans l'application, et un message WebSocket ne peut jamais approuver.
- Approbation après expiration ou refus, ou deux clics sur « Autoriser » : un seul jeton, ou aucun.
- Même origine qui se reconnecte (ou deux sockets) pendant l'attente : une seule demande, une seule invite, même code.
- Révocation puis reconnexion immédiate de l'extension : aucune invite avant la fin de la pause de 10 minutes ; les sockets du navigateur révoqué sont fermés tout de suite.
- Ancienne application (répond `AUTH_FAILED` nu puis ferme) avec la nouvelle extension : message « Mettez à jour l'application », pas de boucle de reconnexion rapide.
- Jeton manuel existant : continue de fonctionner sans appairage.

---

## Task 1 : Politique d'origine et refus des pages web

**Files:**
- Create: `lib/core/security/extension_origin.dart`, `test/core/security/extension_origin_test.dart`
- Modify: `lib/core/services/local_server_service.dart` (`_handleRequest`, journal de l'origine), `test/core/services/local_server_service_test.dart` (ou `local_server_ws_contract_test.dart`)

**Interfaces — Produces :**
```dart
class ExtensionOrigin {
  static bool isExtensionOrigin(String? origin);            // ^(chrome-extension|moz-extension)://[A-Za-z0-9-]{8,64}$ ; null/'' → false
  static String browserLabel(String? userAgent);            // 'Edge' (Edg/), 'Opera' (OPR/), 'Vivaldi', 'Firefox' (Firefox/), 'Chrome' (Chrome/), sinon 'Navigateur'
}
```
`LocalServerService` produit pour la suite : un champ `hasExtensionOrigin` par socket (connu dans `_handleWebSocket(socket, request)` via `request.headers.value('origin')`).

- [ ] **Step 1 : tests en échec** — `isExtensionOrigin`: `chrome-extension://abcdefghijklmnopabcdefghijklmnop` et `moz-extension://9a8b7c6d-1111-2222-3333-444455556666` → true ; `https://evil.example`, `http://127.0.0.1`, `null`, `''`, `file://`, `chrome-extension://`, `chrome-extension://../x`, `moz-extension://x y` → false ; `browserLabel` pour des UA Chrome/Edge/Firefox/Opera/inconnu. Test serveur : `WebSocket.connect(url, headers: {'Origin': 'https://evil.example'})` échoue (403) ; avec `Origin: chrome-extension://…` la mise à niveau réussit ; sans en-tête elle réussit (les tests existants restent valables).
- [ ] **Step 2 :** lancer → FAIL. **Step 3 :** implémenter ; dans `_handleRequest`, avant `WebSocketTransformer.upgrade`, refuser avec `statusCode = HttpStatus.forbidden` si un `Origin` est présent et n'est pas une origine d'extension ; journaliser (`LoggerService.i`) le schéma de l'origine acceptée (pas l'identifiant complet) pour la vérification manuelle Firefox.
- [ ] **Step 4 :** tests → PASS ; analyse ; **Step 5 : Commit** `feat(server): reject WebSocket connections from web page origins`

## Task 2 : Magasin des navigateurs appairés

**Files:**
- Create: `lib/core/security/paired_browsers.dart`, `test/core/security/paired_browsers_test.dart`

**Interfaces — Produces :**
```dart
class PairedBrowser { final String id; final String origin; final String label;
  final String tokenHash; final DateTime createdAt; final DateTime? lastSeenAt;
  Map<String,dynamic> toJson(); factory PairedBrowser.fromJson(Map<String,dynamic> j); }

class PairedBrowsersState { final List<PairedBrowser> browsers; final Set<String> blockedOrigins;
  final Map<String, DateTime> pausedUntil; }

class PairedBrowsersStore extends StateNotifier<PairedBrowsersState> {
  PairedBrowsersStore(SharedPreferences prefs, {DateTime Function()? clock, Random? random});
  Future<(PairedBrowser, String token)> pair({required String origin, required String label});
  PairedBrowser? authenticate(String token);                // temps constant sur les hachés ; met à jour lastSeenAt
  Future<void> revoke(String id);                           // pausedUntil[origin] = now + 10 min ; émet sur revoked
  Future<void> revokeAll();
  Future<void> block(String origin);  Future<void> unblock(String origin);
  bool isBlocked(String origin);  Duration? pauseRemaining(String origin);
  Stream<PairedBrowser> get revoked;                        // pour fermer les sockets
  static String hashToken(String token);                    // SHA-256 hex
}
final pairedBrowsersProvider = StateNotifierProvider<PairedBrowsersStore, PairedBrowsersState>(...);
```
Persistance : une chaîne JSON sous la clé `paired_browsers_v1` dans `SharedPreferences`.

- [ ] **Step 1 : tests en échec** — `pair` renvoie un jeton de 43 caractères base64url, stocke seulement son haché (le jeton en clair n'apparaît pas dans `toJson`) ; `authenticate(token)` renvoie le navigateur, un jeton modifié d'un caractère → null, vide → null ; deux appairages donnent deux jetons différents ; `revoke` retire le navigateur, pose la pause de 10 min (horloge injectée) et émet sur `revoked` ; `revokeAll` ; `block` / `isBlocked` / `unblock` ; rechargement depuis `SharedPreferences` (nouvelle instance) retrouve l'état, une valeur corrompue donne un état vide sans lever.
- [ ] **Step 2 :** FAIL. **Step 3 :** implémenter (SHA-256 via `package:crypto` déjà utilisé par `local_server_auth.dart`). **Step 4 :** PASS. **Step 5 : Commit** `feat(security): store paired browsers with hashed tokens`

## Task 3 : Coordinateur des demandes d'appairage

**Files:**
- Create: `lib/core/security/pairing_coordinator.dart`, `test/core/security/pairing_coordinator_test.dart`

**Interfaces — Consumes :** `PairedBrowsersStore` (Task 2). **Produces :**
```dart
class PairingRequest { final String id; final String origin; final String label; final String code; final DateTime createdAt; }
sealed class PairingOutcome  // PairingApproved(String token) | PairingDenied(Duration retryAfter) | PairingExpired()
enum PairingRefusal { paused, blocked, rateLimited, busy }
class PairingSubmit { final PairingRequest? request; final Future<PairingOutcome>? outcome;
  final PairingRefusal? refusal; final Duration? retryAfter; }

class PairingCoordinator extends StateNotifier<PairingRequest?> {   // state = demande en attente affichée par l'UI
  PairingCoordinator(PairedBrowsersStore store, {DateTime Function()? clock, Random? random, Duration expiry = const Duration(minutes: 2)});
  PairingSubmit submit({required String origin, required String label});   // adopte la demande en attente de la même origine
  Future<bool> approve(String requestId);                                 // true si un jeton a été émis
  Future<void> deny(String requestId, {bool always = false});
}
final pairingCoordinatorProvider = StateNotifierProvider<PairingCoordinator, PairingRequest?>(...);
```
Règles : code `Random.secure` à 4 chiffres (zéros initiaux conservés), nouveau à chaque demande ; une seule demande en attente (autre origine → `busy`) ; l'origine bloquée → `blocked`, en pause → `paused` avec `retryAfter` ; 3 soumissions par heure et par origine (la 4ᵉ → `rateLimited`) ; la même origine qui soumet pendant l'attente reçoit la même demande et le même `outcome` ; `approve` ne réussit qu'une fois et seulement si la demande est encore en attente ; `deny` pose la pause de 10 min (ou bloque avec `always`) ; l'expiration (horloge/minuteur injectables, jamais de vrai minuteur long en test) termine l'`outcome` par `PairingExpired`.

- [ ] **Step 1 : tests en échec** — code à 4 chiffres, différent entre deux demandes (graine fixe) ; adoption (même `request.id` et même `code`) ; `busy` pour une autre origine ; `paused` après `deny` avec `retryAfter` ≈ 10 min ; `blocked` après `deny(always: true)` ; 4ᵉ soumission dans l'heure → `rateLimited`, la 4ᵉ après une heure (horloge) passe ; `approve` deux fois → premier `true`, second `false`, un seul navigateur dans le magasin ; `approve` après expiration → `false` et aucun jeton ; `outcome` se résout avec `PairingApproved(token)` dont le jeton authentifie via `store.authenticate`.
- [ ] **Step 2 :** FAIL. **Step 3 :** implémenter (`Completer<PairingOutcome>` par demande). **Step 4 :** PASS. **Step 5 : Commit** `feat(security): pairing requests with comparison code, limits and expiry`

## Task 4 : Protocole d'appairage dans le serveur

**Files:**
- Modify: `lib/core/services/local_server_service.dart` (`_handleWebSocket`, `_isAuthorized`, `_clients` → métadonnées), `lib/core/services/extension_queue_contract.dart` (constantes de types si pertinent)
- Create: `lib/core/services/extension_pairing_contract.dart` (constantes de messages + `reason` + construction des réponses), `test/core/services/extension_pairing_ws_test.dart`

**Interfaces — Consumes :** `ExtensionOrigin`, `PairedBrowsersStore`, `PairingCoordinator`. **Produces :** le protocole des « Global Constraints » ; `LocalServerService` écoute `pairedBrowsersProvider.notifier.revoked` et ferme immédiatement les sockets de ce navigateur (table `Map<WebSocket, String> _socketBrowserId`).

Machine à états par socket (pas de vrai minuteur long en test : injecter les délais, `helloTimeout` reste 2 s, la fenêtre `PAIR_REQUEST` 10 s, le rythme de `PAIR_PENDING` 10 s sont des constantes surchargeables par les tests) :
1. `HELLO` avec un jeton valide (manuel ou appairé) → `HELLO_OK` comme aujourd'hui (+ `lastSeenAt`).
2. `HELLO` sans jeton ou invalide : si l'origine est une extension → `AUTH_FAILED { reason: 'pairing_required' }` et le socket reste ouvert pour la fenêtre `PAIR_REQUEST` ; sinon `AUTH_FAILED` nu puis fermeture (comportement actuel).
3. `PAIR_REQUEST` (origine d'extension uniquement) → `coordinator.submit` : refus → `PAIR_PAUSED`/`PAIR_DENIED`/`PAIR_BUSY` avec `retryAfterSeconds` puis fermeture ; sinon `PAIR_PENDING` immédiat puis toutes les 10 s jusqu'à la décision ; `PairingApproved` → `PAIR_OK { token }` (puis le client se reconnecte avec `HELLO`) ; `PairingDenied` → `PAIR_DENIED` ; `PairingExpired` → `PAIR_EXPIRED` ; puis fermeture.
4. Tout autre message avant authentification → `AUTH_FAILED { reason: 'not_authenticated' }` (inchangé) ; aucun message WebSocket ne peut approuver.
5. Annuler les minuteurs dans `onDone`/`onError` ; le socket fermé pendant l'attente n'annule pas la demande (l'extension se reconnecte et adopte la même demande).
6. `NotificationService().showExtensionConnected()` : seulement à l'appairage et à la première connexion de chaque session de l'application.

- [ ] **Step 1 : tests en échec** (vrai `HttpServer` sur port éphémère, `WebSocket.connect(url, headers: {'Origin': …})`, coordinateur/magasin avec horloge et délais injectés) — jeton manuel → `HELLO_OK` ; origine d'extension sans jeton → `AUTH_FAILED/pairing_required` puis `PAIR_REQUEST` → `PAIR_PENDING` avec code ; `coordinator.approve` → `PAIR_OK` ; reconnexion avec ce jeton → `HELLO_OK` ; refus → `PAIR_DENIED` ; second `PAIR_REQUEST` pendant la pause → `PAIR_PAUSED` ; sans `Origin` et sans jeton → `AUTH_FAILED` nu et fermeture, `PAIR_REQUEST` refusé ; deux sockets de la même origine → même `requestId` et même `code` ; `revoke` ferme le socket du navigateur ; aucun message WebSocket (`APPROVE`, `PAIR_APPROVE`, ...) n'émet de jeton ; expiration → `PAIR_EXPIRED`.
- [ ] **Step 2 :** FAIL. **Step 3 :** implémenter ; garder `LocalServerService(Ref, …)` compatible avec les tests existants (nouveaux paramètres optionnels, valeurs par défaut de production). **Step 4 :** PASS + suite `test/core/services` ; analyse. **Step 5 : Commit** `feat(server): pairing handshake for browser extensions`

## Task 5 : Invite d'appairage dans l'application

**Files:**
- Create: `lib/core/ui/pairing/pairing_invite_dialog.dart`, `test/core/ui/pairing/pairing_invite_dialog_test.dart`
- Modify: `lib/core/ui/app_shell.dart` (écoute de `pairingCoordinatorProvider`, y compris la branche mobile si l'écoute est partagée), `lib/l10n/app_fr.arb`, `app_en.arb`, `app_ar.arb` (+ `flutter gen-l10n`), `lib/core/services/notification_service.dart` / `local_server_service.dart` (politique de notification)

**Interfaces — Consumes :** `PairingCoordinator` (Task 3). **Produces :** `Future<void> showPairingInvite(BuildContext, WidgetRef, PairingRequest)` ; clés l10n `pairingInviteTitle`, `pairingInviteBody` (`{browser}`, `{code}`), `pairingInviteHint` (cliquer sur l'icône TapLoad du navigateur), `pairingAllow`, `pairingDeny`, `pairingAlwaysDeny`.

Comportement : quand `pairingCoordinatorProvider` passe à une demande non nulle, l'application fait `windowManager.show()` puis `focus()` (même en « Ne pas déranger », sur le modèle de `_flushExtensionDownloads`), puis affiche le dialogue « Autoriser l'extension de <navigateur> à contrôler TapLoad ? Le code affiché dans l'extension est-il <code> ? » avec trois boutons (Autoriser → `approve`, Refuser → `deny`, Toujours refuser → `deny(always: true)`) ; la fermeture du dialogue sans choix équivaut à Refuser ; le dialogue se ferme tout seul si la demande expire. Un seul dialogue à la fois. Le code est affiché en grand et lisible (chiffres espacés).

- [ ] **Step 1 : tests en échec** (widget test avec un `PairingCoordinator` pilotable) — le dialogue affiche navigateur et code ; Autoriser appelle `approve` avec l'identifiant de la demande ; Refuser et Toujours refuser appellent `deny` ; une demande qui expire ferme le dialogue ; une seconde demande pendant l'affichage n'ouvre pas un second dialogue.
- [ ] **Step 2 :** FAIL. **Step 3 :** implémenter le dialogue et l'écoute (thème/typographie existants de l'application, textes via `AppLocalizations`) ; ajouter les clés aux trois `.arb` et régénérer ; appliquer la politique de notification (Task 4 point 6) si elle n'est pas déjà complète.
- [ ] **Step 4 :** PASS ; analyse ; **Step 5 : Commit** `feat(ui): in-app invite to approve a browser extension pairing`

## Task 6 : Réglages — navigateurs appairés

**Files:**
- Create: `lib/core/ui/settings/widgets/paired_browsers_panel.dart`, `test/core/ui/settings/paired_browsers_panel_test.dart`
- Modify: `lib/core/ui/settings/advanced_settings_view.dart`, `lib/core/ui/settings/plugins_settings_view.dart` (`_BrowserExtensionsPanel`), `lib/features/designs/nocturne/nocturne_settings.dart`, `lib/features/designs/terminal/terminal_settings_pages.dart`, `lib/l10n/app_*.arb`

**Interfaces — Consumes :** `pairedBrowsersProvider` (Task 2). **Produces :** `class PairedBrowsersPanel extends ConsumerWidget` — liste (libellé, origine abrégée, « appairé le », « dernière connexion »), bouton Révoquer par navigateur (confirmation), « Révoquer tout », liste des origines bloquées avec Débloquer, et une sous-section repliée « Avancé » contenant le jeton manuel (copier) à la place des tuiles de jeton actuelles ; clés `pairedBrowsers*`, `revoke*`, `blockedOrigins*`, `manualTokenAdvanced`.

- [ ] **Step 1 : tests en échec** — liste vide → texte d'aide ; deux navigateurs affichés avec libellé ; Révoquer (après confirmation) appelle `revoke(id)` ; Révoquer tout ; une origine bloquée avec Débloquer ; le jeton manuel est dans la section Avancé et reste copiable.
- [ ] **Step 2 :** FAIL. **Step 3 :** implémenter le widget partagé, le brancher dans les quatre vues qui affichaient le jeton (supprimer leurs tuiles de jeton en gardant la copie accessible via le panneau), clés l10n fr/en/ar. **Step 4 :** PASS + tests de ces vues (`test/core/ui/settings`, designs) ; analyse. **Step 5 : Commit** `feat(settings): list and revoke paired browsers`

## Task 7 : Client d'appairage dans l'extension

**Files:**
- Create: `extension/shared/pairing.js`, `test/extension/pairing_test.cjs`, `test/extension/pairing_client_test.cjs`
- Modify: `extension/shared/connection.js`, `tool/build_extension.dart`, `tool/check_extension_contract.dart` (jetons `PAIR_REQUEST`, `pairing_required`, `PAIR_OK`), `extension/shared/sw_shell.js` (`importScripts`, si le service worker charge les modules par cette voie)

**Interfaces — Produces :**
```
MDPairing.reconnectDelayMs(attempt: number, elapsedMs: number): number   // 3000 pendant 300000 ms, ensuite 10000
MDPairing.next(state, event): state          // réducteur pur
  state = { phase: 'idle'|'pending'|'denied'|'paused'|'expired'|'busy'|'update_needed', code?: string, until?: number, requestId?: string }
  events: { type: 'AUTH_FAILED', reason?, hadToken } | 'PAIR_PENDING' {code, requestId, expiresInSeconds} | 'PAIR_OK' | 'PAIR_DENIED' {retryAfterSeconds} | 'PAIR_PAUSED' | 'PAIR_EXPIRED' | 'PAIR_BUSY' | 'SOCKET_CLOSED' | 'RETRY' | 'TOKEN_CLEARED'
MDPairing.shouldRequestPairing(state, now): boolean    // faux pendant une pause (until > now) ou quand update_needed
```
Comportement dans `connection.js` : sans jeton, ou après `AUTH_FAILED { reason: 'pairing_required' }`, envoyer `PAIR_REQUEST { extensionVersion }` (le gestionnaire `AUTH_FAILED` actuel ferme le socket : exception pour `pairing_required`) ; `PAIR_PENDING` → `storage.local.pairing = { phase: 'pending', code, … }`, badge d'action `?` ; `PAIR_OK` → enregistrer `apiToken`, effacer `pairing`, retirer le badge, rouvrir le socket ; `PAIR_DENIED`/`PAIR_PAUSED`/`PAIR_EXPIRED`/`PAIR_BUSY` → phase correspondante avec `until`, pas de nouvelle demande avant `until` ni avant un clic sur « Réessayer » (message `MD_PAIRING_RETRY` depuis le popup, accepté seulement des pages de l'extension via `isExtensionPage`) ; un `AUTH_FAILED` sans `reason` quand un `PAIR_REQUEST` vient d'être envoyé (ancienne application) → phase `update_needed`, reconnexion lente (10 s) ; un jeton enregistré révoqué (`AUTH_FAILED` avec jeton) → effacer le jeton et retomber sur l'appairage en respectant la pause ; reconnexion selon `reconnectDelayMs` tant que l'application est introuvable ; le jeton saisi à la main (champ du popup) continue de fonctionner.

- [ ] **Step 1 : tests en échec** — réducteur : `AUTH_FAILED(pairing_required)` → demande ; `PAIR_PENDING` → `pending` avec code ; `PAIR_OK` → `idle` ; `PAIR_DENIED(600)` → `denied` avec `until = now + 600 s` et `shouldRequestPairing` faux avant `until`, vrai après ; `AUTH_FAILED` nu après demande → `update_needed` ; `RETRY` lève la pause ; `reconnectDelayMs(0,0)`=3000, `(…, 299999)`=3000, `(…, 300000)`=10000. Client (vm + faux WebSocket/chrome stub, voir `test/extension/download_relay_test.cjs`) : un socket ouvert sans jeton envoie exactement un `PAIR_REQUEST` ; `PAIR_PENDING` écrit `pairing` et le badge ; `PAIR_OK` écrit `apiToken` et se reconnecte ; pas de second `PAIR_REQUEST` pendant la pause ; `MD_PAIRING_RETRY` refusé depuis un content script (`forbidden`) et accepté depuis une page de l'extension ; le jeton manuel de `storage.local` est utilisé tel quel.
- [ ] **Step 2 :** FAIL. **Step 3 :** implémenter `pairing.js` (script classique sur `self`, chargeable par `vm`) puis le branchement ; enregistrer le fichier (build, contrat, chargement du service worker). **Step 4 :** PASS (`node --test`), régénérer les copies, `check_extension_contract`. **Step 5 : Commit** `feat(extension): automatic pairing with the desktop app`

## Task 8 : Popup, textes, documentation et vérification de bout en bout

**Files:**
- Modify: `extension/shared/popup.html`, `popup.js`, `popup.css`, `extension/shared/_locales/{fr,en,ar}/messages.json`, `extension/README.md`, `extension/privacy.md`, `CHANGELOG.md`
- Create: `test/extension/popup_pairing_test.cjs`, `test/core/services/extension_pairing_integration_test.dart`, `C:/Users/entre/Documents/Dev/tapload-ext/.superpowers/sdd/2026-11-27-extension-pairing/manual-qa.md` (hors dépôt)

**Interfaces — Consumes :** `storage.local.pairing`, `MDPairing` (Task 7). **Produces :** états du popup — « Application introuvable » (réessaie seule), « En attente de validation dans l'application » avec le **code en grand** et la consigne de comparer, « Connecté », « Refusé / accès retiré » avec le délai et un bouton Réessayer (message `MD_PAIRING_RETRY`), « Mettez à jour l'application » ; le champ jeton passe dans une section « Avancé » repliée ; le badge `?` disparaît à la connexion.

- [ ] **Step 1 : tests en échec** — popup (vm + DOM minimal ou tests de logique pure extraits) : chaque phase affiche le bon texte, le code est présent seulement en `pending`, Réessayer n'apparaît qu'en `denied`/`paused`/`expired`, le champ jeton est dans « Avancé » ; clés i18n identiques en fr/en/ar. Dart d'intégration (vrai serveur, vrai magasin avec `SharedPreferences` simulé) : origine web refusée ; origine d'extension → appairage complet avec approbation → `HELLO_OK` ; révocation ferme le socket et impose la pause ; jeton manuel inchangé.
- [ ] **Step 2 :** FAIL. **Step 3 :** implémenter le popup ; documenter (README : fonctionnement de l'appairage, révocation, sécurité ; privacy : jeton d'appairage stocké dans `storage.local`, aucune donnée envoyée à des tiers) ; entrée `CHANGELOG.md` sous `[Unreleased]` ; rédiger `manual-qa.md` (voir ci-dessous). **Step 4 :** vérification finale — `node --test "test/extension/*.cjs"`, `flutter analyze --no-pub`, `flutter test --no-pub --reporter=compact` complet (en arrière-plan), build + contrat, `dart format` sur les fichiers modifiés, `git status` propre ; rapporter les chiffres exacts.
- [ ] **Step 5 : Commit** `feat(extension): pairing states in the popup, docs and end-to-end tests`

`manual-qa.md` doit couvrir : (1) **vérification Firefox de l'origine** — charger l'extension temporaire dans Firefox, lire dans le journal de l'application le schéma d'origine journalisé (`moz-extension`) ; sans cela ne pas considérer le refus des origines web comme validé pour Firefox ; (2) Chrome/Edge/Brave : même vérification (`chrome-extension`) ; (3) premier appairage : badge `?`, code identique dans le popup et l'invite, Autoriser, connexion immédiate, plus aucune saisie ; (4) Refuser, Toujours refuser, expiration 2 min, pause 10 min et bouton Réessayer ; (5) révocation depuis les réglages : socket fermé, pas d'invite pendant 10 min ; (6) page web : ouvrir `https://example.com` et tenter `new WebSocket('ws://127.0.0.1:6969')` dans la console → refus ; (7) ancienne application + nouvelle extension → « Mettez à jour l'application » ; (8) jeton manuel toujours valide ; (9) redémarrage de l'application → reconnexion en quelques secondes ; (10) fr/en/ar et RTL pour l'invite et le popup.

---

## Self-review

- **Couverture du spec :** objectif 1 (Tasks 4, 5, 7, 8), 2 (Task 1, 4), 3 (Tasks 2, 6), 4 (Tasks 7, 8), 5 (Task 4 point 1, Task 7, Task 8) ; code à comparer (Tasks 3, 4, 5, 8) ; limites et pauses (Task 3) ; reconnexion (Task 7) ; notification (Tasks 4, 5) ; interface dans les quatre vues (Task 6) ; compatibilité ancienne application (Task 7).
- **Cohérence des types :** `PairingRequest`, `PairingSubmit`, `PairingOutcome` (Task 3) sont consommés tels quels par le serveur (Task 4) et le dialogue (Task 5) ; `PairedBrowsersStore.revoked` (Task 2) est écouté par le serveur (Task 4) ; les noms de messages WebSocket sont les mêmes dans les Global Constraints, le serveur (Task 4), le client JS (Task 7) et le contrat de l'extension.
- **Ordre :** 1 → 2 → 3 → 4 en Dart (chacun dépend du précédent) ; 5 et 6 (UI) dépendent de 2 et 3 ; 7 dépend du protocole figé en 4 ; 8 clôt.
