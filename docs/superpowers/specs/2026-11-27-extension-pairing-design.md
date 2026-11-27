# Appairage automatique extension ↔ application — Design

## Intention

Aujourd'hui l'utilisateur doit copier un jeton depuis les réglages avancés de l'application et le coller dans le popup de l'extension. Demande de l'utilisateur : « au lieu d'utiliser un token, que la connexion se fasse automatiquement, facilement et rapidement entre l'extension et l'app desktop ». Choix validé : une **invite dans l'application** au premier contact avec un navigateur.

## État actuel (relevé dans le code)

- L'application génère un UUID (`apiToken`, `lib/core/providers/settings_provider.dart`) et le garde dans ses réglages ; il s'affiche dans `advanced_settings_view.dart`, `plugins_settings_view.dart` (panneau des extensions navigateur), `features/designs/nocturne/nocturne_settings.dart` et `features/designs/terminal/terminal_settings_pages.dart`.
- Le serveur (`lib/core/services/local_server_service.dart`) écoute sur `ws://127.0.0.1:<port>` (défaut 6969, boucle locale seulement). Le client doit envoyer `HELLO` avec le jeton dans les 2 s ; sinon `AUTH_FAILED` et fermeture. Le serveur ne regarde **pas** l'en-tête `Origin` de la connexion.
- L'extension (`extension/shared/connection.js`) lit `apiToken` depuis `storage.local` (champ du popup) et l'envoie dans `HELLO`.
- Le motif « un événement de l'extension ouvre une boîte de dialogue dans l'app » existe : `launchDataProvider` ouvre le dialogue d'ajout de téléchargement depuis `app_shell.dart` (il existe aussi une branche mobile `MobileAppShell`) ; à la réception d'un lot de l'extension le service fait déjà `windowManager.show()` puis `focus()`. (`pluginInstallRequestProvider` navigue vers une page, ce n'est pas un dialogue.)
- Pourquoi un simple « sans jeton » est refusé : n'importe quelle page web peut ouvrir `ws://127.0.0.1:6969` ; sans contrôle, un site pourrait lancer des téléchargements ou lire la bibliothèque.

## Objectifs

1. Premier lancement : l'extension se connecte seule ; l'application affiche une invite « Autoriser <navigateur> ? » ; un clic suffit. Ensuite plus aucune action manuelle, connexion silencieuse et rapide à chaque démarrage.
2. Les pages web ne peuvent jamais s'authentifier ni s'appairer.
3. Gestion visible dans l'application : liste des navigateurs appairés (nom, date, dernière connexion), révocation d'un navigateur ou de tous.
4. L'extension affiche clairement l'état : non connecté (app fermée), en attente de validation, connecté, refusé.
5. Les installations existantes (jeton manuel) continuent de fonctionner sans rien faire.

## Non-objectifs

- Pas de messagerie native (Native Messaging) : elle demanderait de modifier l'installeur et d'ajouter un programme intermédiaire. À reconsidérer plus tard.
- Pas d'accès distant : le serveur reste lié à la boucle locale.
- Pas de chiffrement du stockage du jeton dans le navigateur (identique à l'état actuel).

## Anti-objectifs

- Un site web, ou une page `null`/sans origine navigateur, obtient un accès ou déclenche une invite.
- Une invite qui apparaît en boucle (harcèlement) ou qui peut être déclenchée par un site.
- Un navigateur appairé qui ne peut pas être révoqué.
- Casser les utilisateurs qui ont déjà collé un jeton.

## Conception

**Contrôle d'origine (sur toute connexion WebSocket).** Le navigateur pose lui-même `Origin: chrome-extension://<id>` (Chrome, Edge, Brave) ou `moz-extension://<uuid>` (Firefox) quand le socket est ouvert par une extension ; une page web ne peut pas falsifier cet en-tête. Le serveur refuse (HTTP 403, avant la mise à niveau WebSocket) toute connexion dont l'`Origin` est présent et n'est pas une origine d'extension. Une connexion **sans** `Origin` (outil local, test) n'est acceptée que si elle présente un jeton valide ; elle ne peut pas demander d'appairage.

**Appairage (première connexion).**
1. L'extension envoie `HELLO` avec le jeton qu'elle a. Si elle n'en a pas, ou s'il est refusé, le serveur répond `AUTH_FAILED` avec `reason: 'pairing_required'` (au lieu de fermer tout de suite) et accepte un seul message `PAIR_REQUEST { browser, extensionVersion }` (délai 10 s).
2. Le serveur crée une demande en attente (une seule à la fois, identifiée par l'origine) et répond `PAIR_PENDING`. L'application affiche l'invite : « Autoriser l'extension <navigateur> à contrôler TapLoad ? » avec l'origine, le navigateur déduit du `User-Agent` et trois boutons : Autoriser, Refuser, Toujours refuser ce navigateur.
3. Autoriser : le serveur génère un jeton de 256 bits (`Random.secure`), le stocke **haché** (SHA-256) avec { id, origine, libellé, date de création, dernière connexion }, puis envoie `PAIR_OK { token }`. L'extension enregistre ce jeton comme `apiToken` et se reconnecte ; plus aucune saisie.
4. Refuser : `PAIR_DENIED`, et l'extension ne redemande pas avant 10 minutes. Après un refus ou une révocation, l'extension affiche la pause restante et redemande d'elle-même quand elle se termine ; le bouton « Réessayer » n'existe que pour une demande expirée ou un refus « occupé ». « Toujours refuser » : l'origine est bloquée jusqu'à révocation de la règle dans les réglages.
5. Limites : une invite à la fois ; 3 demandes par heure et par origine ; l'invite expire après 2 minutes (`PAIR_PENDING` → `PAIR_EXPIRED`).

**Authentification.** `HELLO` est accepté si le jeton correspond au jeton manuel historique (`apiToken`, conservé, comparaison à temps constant) **ou** au haché d'un navigateur appairé. Rien d'autre n'est accepté avant `HELLO_OK`.

**Application (réglages).** Dans Réglages avancés : liste « Navigateurs appairés » (libellé, origine abrégée, appairé le, dernière connexion, bouton Révoquer) et « Révoquer tout ». Le jeton manuel reste affiché dans une section « Avancé ». Une révocation ferme immédiatement les sockets de ce navigateur.

**Extension (popup et connexion).** Plus de champ jeton obligatoire : le champ passe dans une section « Avancé ». L'extension tente de se connecter dès le démarrage, puis avec un recul croissant (2 s, 4 s, 8 s, plafonné à 15 s) tant que l'application est fermée, et se reconnecte en moins de 2 s quand elle apparaît. États du popup : « Application introuvable » (réessaie toute seule), « En attente de validation dans l'application », « Connecté », « Refusé » (pause restante affichée, sans bouton Réessayer ; ce bouton n'existe que pour une demande expirée ou « occupé »). Si le jeton enregistré est révoqué, l'extension retombe sur l'appairage.

**Compatibilité.** Un jeton manuel déjà saisi continue de fonctionner ; la nouvelle extension et l'ancienne application, ou l'inverse, doivent échouer proprement : une ancienne application répond `AUTH_FAILED` simple, la nouvelle extension affiche « Mettez à jour l'application ».

## Approches envisagées

1. **Invite dans l'application au premier contact (retenue)** : sûr (origine + validation humaine), un clic une seule fois, révocable.
2. Bouton « Associer un navigateur » dans l'app (mode appairage de 60 s) : plus de friction (il faut penser à cliquer avant), même sécurité. Écartée par l'utilisateur.
3. Acceptation automatique de toute origine d'extension, sans invite : toute extension installée pourrait piloter l'app. Écartée.
4. Messagerie native : la plus solide, mais installeur et programme à ajouter. Reportée.

## Contraintes

- Windows desktop (l'application Flutter) ; extensions Chrome (MV3) et Firefox ; code partagé dans `extension/shared/`, sans build.
- Aucune régression pour les utilisateurs avec jeton manuel ; mêmes ports (6969 par défaut).
- Textes en fr, en, ar (extension et application).
- Dart : tests unitaires du contrôle d'origine, de l'appairage et de la révocation ; JS : tests `node --test`.
- L'invite ne doit jamais bloquer l'application (non modale pour le thread principal) et ne s'affiche que si la fenêtre existe ; si l'application est réduite dans la zone de notification, une notification Windows ouvre l'invite.

## Laissé au constructeur

- Stockage des navigateurs appairés (réglages existants ou un fichier dédié), format et migration.
- Détails visuels de l'invite et de la liste, en suivant les designs de l'application.
- Détection du navigateur depuis le `User-Agent` (libellé « Chrome », « Edge », « Firefox »…).
- Nombre exact de tentatives et délais de recul, tant que les limites ci-dessus sont tenues.


## Précisions après relecture par un constructeur indépendant

**Réponses tirées du code**
- Le serveur peut lire `request.headers.value('origin')` avant `WebSocketTransformer.upgrade` et répondre 403 ; les tests existants (`WebSocket.connect(url)` sans en-tête) restent valables et couvrent « sans Origin ». Chrome/Edge/Brave envoient `Origin: chrome-extension://<id>` ; Firefox doit envoyer `moz-extension://<uuid>` : **à vérifier par un essai de 5 minutes (journaliser l'en-tête) avant de coder le refus 403**. Un client local hors navigateur peut forger n'importe quelle origine : le contrôle protège des pages web, pas d'un programme local (qui doit, lui aussi, passer par l'invite).
- Aujourd'hui chaque socket a un seul minuteur HELLO de 2 s, un échec envoie `AUTH_FAILED` nu et ferme. Garder le socket ouvert pendant l'appairage demande une machine à états par socket (hello → fenêtre `PAIR_REQUEST` de 10 s → attente de validation), l'annulation des minuteurs dans `onDone`/`onError`, l'adoption d'une demande déjà en attente quand la même origine se reconnecte (l'extension rouvre le socket dans plusieurs cas), et une table socket → appairage pour la révocation immédiate (`_clients` est une simple liste). Côté extension, le gestionnaire `AUTH_FAILED` ferme le socket : exception pour `pairing_required`. Le service worker Chrome est tué après ~30 s sans trafic : le serveur envoie des `PAIR_PENDING` périodiques (toutes les 10 s) pendant l'attente.
- `connection.js` tourne dans le service worker Chrome (`importScripts`). Les copies `extension/chrome` et `extension/firefox` sont versionnées : tout changement de `shared/` demande `dart run tool/build_extension.dart` ; `tool/check_extension_contract.dart` a une liste de jetons obligatoires à compléter pour les nouveaux messages.

**Choix de ma part (mineurs, à contester)**
- Après « Révoquer » (ou « Révoquer tout ») ou « Refuser », l'origine concernée est en pause de 10 minutes : l'extension affiche « Accès retiré / refusé » avec la pause restante (pas de bouton Réessayer) et redemande d'elle-même à la fin de la pause. Les révocations multiples ne mettent donc pas N invites en file.
- L'invite fait `windowManager.show()` + `focus()` même en mode « Ne pas déranger » (c'est une demande de sécurité, elle doit être vue) ; pas de plomberie de clic de notification.
- Reconnexion : tant que l'application est fermée, sondage toutes les 3 s pendant 5 minutes, puis toutes les 10 s (connexion locale, coût négligeable) ; on abandonne la phrase « moins de 2 s » du design initial.
- Interface de l'application : un widget partagé « Navigateurs appairés » (liste, révocation, section Avancé avec le jeton manuel) utilisé dans les 4 vues qui affichent le jeton aujourd'hui.
- La notification « extension connectée » ne s'affiche plus qu'à l'appairage et à la première connexion de chaque session de l'application (plus à chaque reconnexion).

## Décision de l'utilisateur : code à comparer

L'appairage exige un **code à 4 chiffres** à comparer :
- Le serveur génère le code (aléatoire sûr, `Random.secure`) quand il crée la demande et le renvoie dans `PAIR_PENDING { code }` ; le même code s'affiche dans l'invite de l'application et dans le popup de l'extension (état « En attente de validation »). Le code sert uniquement à la comparaison humaine : l'utilisateur ne le saisit nulle part.
- Le bouton « Autoriser » reste actif sans saisie, mais l'invite demande explicitement « Le code affiché dans l'extension est-il <1234> ? ». Le code change à chaque nouvelle demande.
- Pour que l'utilisateur voie le code sans chercher : pendant l'attente, l'extension pose un badge « ? » sur son icône et l'invite de l'application indique « Cliquez sur l'icône TapLoad de votre navigateur pour voir le code ». Le popup affiche le code en grand et se met à jour tout seul.
- Un code faux ou absent ne permet jamais l'appairage : le jeton n'est émis que si l'utilisateur clique « Autoriser » dans l'application pour cette demande précise (identifiant de demande + code) ; « Refuser » ou l'expiration (2 minutes) invalide la demande.
- Anti-objectif ajouté : un attaquant local ou une extension tierce ne peut pas deviner le code et l'approuver à la place de l'utilisateur (l'approbation ne passe que par l'interface de l'application, jamais par un message WebSocket).
