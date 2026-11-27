# Refonte de l'extension TapLoad — Design

Maquette de référence (canvas, privée) : https://claude.ai/artifact/GnG3Lsns3ZuFPV4ei8DRvq
Les fichiers de la maquette sont des illustrations : le code de l'extension reste du JavaScript simple, sans build.

## Intention

Rendre le panneau « Vidéos repérées » de l'extension (side panel Chrome, panneau Firefox) utilisable au quotidien : profils toujours ouverts sur la bonne plateforme, ordre des vidéos stable pendant le scroll, sélection multiple rapide, actions directement sur les cartes, téléchargements suivis en direct (progression, débit, ETA, file). Le tout dans un design plus sobre, qui suit toujours le design de l'application desktop.

Demande d'origine de l'utilisateur : 9 points (profils, ordre, glisser-sélectionner, refonte UX, actions like/signets/profil, infos vidéo, progression + file, logo, audit global). L'utilisateur trouve la première maquette « trop IA et brouillonne » : la version retenue est la seconde (sobre, un seul accent).

## Objectifs

1. **Profils** : un clic sur un compte ouvre le profil sur la plateforme de la vidéo, jamais une autre. Résolution automatique par plateforme (X, TikTok, Instagram, YouTube, Facebook, Twitch), sans configuration.
2. **Ordre** : l'ordre des vidéos reste stable pendant le scroll, sans doublon. Deux modes : « Ordre du flux » (défaut) et « Plus récentes ».
3. **Sélection** : maintenir le clic sur une carte puis glisser sur d'autres pour sélectionner (ou désélectionner si on part d'une carte sélectionnée). Rond de sélection individuel conservé. Barre d'action en bas.
4. **Interface** : layout simplifié (en-tête, onglets Vidéos / Téléchargements / Comptes, une ligne d'outils, liste), états visuels cohérents (survol, sélection, attente, en cours, terminé, erreur).
5. **Actions sur carte** : télécharger (toujours visible) ; like, signet, profil au survol et au clavier. Retour visuel (toast + icône persistante).
6. **Infos carte** : durée sur la miniature, plateforme, compte, détail (résolution, taille), état.
7. **Téléchargements** : progression, débit et ETA calculés à partir de données réelles, plusieurs en parallèle, file d'attente visible, annuler / retirer / réessayer / reprendre quand c'est techniquement possible, vue globale.
8. **Logo** : l'asset du desktop (`assets/brand/logo.svg` et PNG) pour l'icône de l'extension et le branding du panneau.
9. **Audit** : fluidité au scroll, nombre de vidéos, fiabilité de la détection, erreurs, ressources, synchronisation avec l'app.

## Non-objectifs

- Pas de framework, pas de bundler, pas d'étape de build (extension signée par Mozilla ; Chrome et Firefox partagent `extension/shared/`).
- Pas de nouvelle plateforme prise en charge pour le téléchargement.
- Pas de like ni de signet sur TikTok, Instagram, YouTube… dans cette version : X seulement (voir décisions).
- Pas de refonte du popup ni de la carte de synchro injectée dans les pages, sauf le logo.
- Pas de changement de l'identifiant Firefox `moderndownloader@extension.addon` ni du nom du dépôt.

## Anti-objectifs (un échec même si « ça marche »)

- Le panneau ne suit plus le design de l'application (couleur écrite en dur, `theme.js` contourné ou supprimé).
- Une vidéo X ouvre un profil TikTok (ou l'inverse).
- Les cartes changent de place pendant le scroll.
- Régression des fonctions existantes (envoi à l'app, synchro TikTok, onglet Comptes, flux X, auto-clear).
- Une action Like/Signets lancée sans que l'utilisateur ait vu l'avertissement.

## Contraintes

- **Thème** : `theme.js` reste en place. Le panneau n'utilise que les variables CSS qu'il pose : `--canvas --panel --panel-2 --line --ink --sub --mute --a/--on-a --b/--on-b --c/--on-c --ok/--on-ok --bad/--on-bad --r-card --r-ctl`, plus `color-scheme`. Il n'y a que trois couleurs d'action (`a`, `b`, `c`), donc **un seul accent** (`--a`). Les designs vont du sombre au clair, des angles droits (rayon 0) aux contrôles ronds (999). Un test automatique interdit les couleurs en dur dans le CSS du panneau.
- **Protocole app ↔ extension** : le serveur WebSocket du desktop (`lib/core/services/local_server_service.dart`) ne comprend aujourd'hui que `HELLO`, `PING`, `DEBUG`, `DOWNLOAD`, `HEARTBEAT_COOKIES`, `TIKTOK_COLLECTIONS_SYNC`. Annuler, réessayer, lister la file demandent de nouveaux messages côté Dart. La progression existe déjà (`PROGRESS` → `MD_DOWNLOAD_PROGRESS` avec `progress`, `speed`, `eta`, `status`).
- **Existant** : barre de progression basique par carte (`.card-progress-bar-wrap`), durée dans la ligne de méta, déduplication par identifiant dans `mergeItems`, URL de profil TikTok écrite en dur à plusieurs endroits de `feed_panel.js` (seul le chemin « liste des comptes » gère X).
- **Sécurité** : l'extension a des permissions larges (`*://*/*`, cookies). Les appels like/signets restent dans le content script de x.com, avec les cookies du navigateur, sans jamais envoyer de cookie à l'app ni stocker de secret.
- **Base de code** : partir de `main` après le merge de la PR de renommage TapLoad (#31), car elle modifie les textes de l'extension.
- **Langues** : fr, en, ar (`_locales`). Toute nouvelle chaîne est ajoutée aux trois.
- **Accessibilité** : vrais `<button>`, `aria-label` sur les icônes, focus visible, contraste respecté, actions de survol aussi accessibles au clavier.

## Approches envisagées

1. **Évolution par étapes de l'existant (retenue)** : on garde le JavaScript sans build et on sort de `feed_panel.js` (3000 lignes) quelques modules purs et testables (profils, store des vidéos et ordre, sélection, suivi des téléchargements, actions X). Livraison par chantiers indépendants, interface visuelle à la fin. Risque de régression le plus bas.
2. Réécriture avec framework (Preact + bundler) : code d'interface plus propre, mais ajoute une chaîne de build à une extension signée, oblige à réécrire 3000 lignes d'un coup. Écartée.
3. Refonte visuelle d'abord : résultat visible vite, mais on dessine avant de connaître les données de chaque carte. Écartée, remplacée par « maquette jetable d'abord » (faite), puis chantiers.

L'utilisateur a hésité entre 2 et 3 ; il a validé la variante « maquette cliquable d'abord, puis modules par étapes, sans framework ».

## Décisions prises

**Par l'utilisateur**
- Like et signets sur X passent par l'API interne de X avec la session du navigateur. Avertissement affiché une seule fois, avant la première action.
- Maquette retenue : la seconde (sobre), thème-compatible. Changement de design de l'app préservé.

**Par moi (à confirmer à la relecture)**
- Ordre par défaut : « Ordre du flux » (ordre de la page de haut en bas). « Plus récentes » met les dernières détections en haut.
- Like/signets masqués hors X. Sur TikTok et les autres, seules les actions télécharger, profil et sélection sont proposées.
- Une seule action visible sur la carte au repos (télécharger). Like, signet et profil au survol, au focus clavier et quand la carte est sélectionnée ; l'état « liké » ou « enregistré » reste visible par une petite icône dans la ligne de méta.
- Le panneau Vidéos et l'onglet Téléchargements réutilisent la même carte.
- Concurrence de téléchargement : celle de l'application (la maquette montre 2). La file est gérée par l'app ; l'extension l'affiche et envoie des commandes.
- Reprendre = relancer le téléchargement en réutilisant le fichier partiel quand `yt-dlp` le permet ; sinon « Réessayer ».
- ETA : celui de l'app s'il est fourni, sinon calcul lissé côté extension à partir de la progression et du débit mesurés. Jamais une valeur fixe.

## Chantiers (ordre de livraison, une PR chacun)

1. **Profils** : module `profile_url` (plateforme + identifiant → URL), remplacement de tous les `https://www.tiktok.com/@…` en dur, tests unitaires par plateforme. Corrige le bug signalé.
2. **Store et ordre** : module de store (clé stable, séquence de détection, position dans le flux, déduplication, fusion), tri « flux » / « récentes », chip « nouvelles vidéos », pas de réordonnancement au scroll.
3. **Sélection** : état de sélection, glisser, barre d'action, clavier (Espace, Maj+clic). Option tactile si faisable.
4. **Téléchargements** : côté Dart, messages `CANCEL`, `RETRY`, snapshot de la file ; côté extension, store de téléchargements, ETA, onglet Téléchargements, mini-barre d'activité.
5. **Actions X** : découverte des identifiants GraphQL à l'exécution, `FavoriteTweet` et `CreateBookmark` depuis le content script, secours par clic sur le bouton de la page quand le post est visible, avertissement unique, toasts.
6. **Interface** : nouveau layout et styles basés sur les variables du thème, états visuels, logo desktop (icônes 16–128 px + en-tête), chaînes fr/en/ar.
7. **Audit** : mesure de fluidité avec beaucoup de vidéos, virtualisation seulement si nécessaire, gestion d'erreurs, consommation, synchronisation avec l'app.

## Laissé au constructeur

- Découpage exact des modules et leur système de chargement (scripts classiques partagés, comme `url_policy.js`).
- Outil de test JavaScript (par exemple `node --test` ajouté à la CI) et format des fixtures.
- Format exact des nouveaux messages WebSocket, tant qu'ils restent rétrocompatibles avec une extension ou une app d'une version voisine.
- Détails d'implémentation de l'ETA lissé, du glisser et de l'accessibilité clavier.
- Choix de virtualiser ou non la liste, selon les mesures de l'audit.

## Risques connus

- L'API interne de X change et peut exiger des en-têtes anti-bot (`x-client-transaction-id`) : prévoir détection de l'échec, secours par clic et message clair.
- Un usage intensif de like/signets peut limiter ou signaler le compte de l'utilisateur : d'où l'avertissement et un espacement des requêtes.
- Annuler et reprendre côté app touchent à la file de téléchargement existante : tests de non-régression nécessaires.

## Précisions après relecture par un constructeur indépendant

**Réponses tirées du code**
- Le desktop sait déjà annuler, mettre en pause, reprendre et relancer : `DownloaderNotifier.cancelDownload`, `pauseDownload`, `resumeDownload`, `retryDownload`, `pauseAllActive`, `retryAllFailed` (`lib/features/downloader/presentation/providers/downloader_provider.dart`). Le chantier 4 ajoute seulement des messages WebSocket qui appellent ces méthodes. « Reprendre » = `resumeDownload` sur un téléchargement en pause ; « Réessayer » = `retryDownload` sur un échec.
- L'app diffuse déjà la progression de **tous** ses téléchargements à l'extension (`PROGRESS`, avec `id`, titre, `url`, `tweetId`, `tikTokId`) : l'onglet Téléchargements montre donc toute la file de l'app, sans nouvelle exposition de données. Un message `QUEUE_SNAPSHOT` donne l'état initial à l'ouverture du panneau : l'activité, pas la bibliothèque (tout ce qui n'est pas terminé, échecs et annulés compris, plus les 50 derniers terminés). Les lignes sans carte (téléchargement lancé depuis le desktop) sont affichées sans actions like/signet.
- `PROGRESS` est filtré (`_progressFilter`) : l'ETA lissé côté extension doit tolérer des mises à jour espacées et un `eta` fourni par l'app.
- `extension/chrome/` et `extension/firefox/` sont versionnés et régénérés par `tool/build_extension.dart` ; la CI lance `dart run tool/check_extension_contract.dart`. Chaque nouveau fichier de `shared/` doit être ajouté à la liste `commonFiles` du script, à `feed_panel.html` ou au manifeste (content script), et les copies régénérées sont commitées avec la PR.
- Les tests JavaScript existent déjà (`test/extension/*.cjs`, `node --test`) mais **la CI ne les lance pas** : le chantier 1 ajoute cette étape.
- Le test « pas de couleur en dur » est du travail nouveau. Les valeurs de repli dans le bloc `:root` de `feed_panel.css` (avant la réception du premier message `THEME`) restent autorisées ; le test interdit toute couleur ailleurs, sauf les noirs et blancs translucides posés sur les miniatures.

**Choix de ma part (mineurs, à contester à la relecture)**
- **Profils** : l'extension ne connaît un identifiant de compte que pour X et TikTok (Instagram et YouTube n'exposent aujourd'hui qu'un nom d'affichage, pas un identifiant). Le module sait construire les URL des six plateformes, mais le bouton Profil est **masqué** quand l'identifiant manque. Ajouter l'extraction pour les autres plateformes est hors périmètre.
- **Store** : en mémoire pendant la vie du panneau ; un rechargement repart d'un nouveau scan. Les vidéos du flux X de l'app (gobird) et celles du DOM passent par la même fusion ; l'ordre vient de la source qui les a fournies, le filtre de plateforme s'applique après le tri.
- **Actions X** : « like » et « signet » sont des bascules (annuler possible). « Déjà liké » renvoyé par X = succès. Boutons désactivés (info-bulle « Ouvrez x.com ») quand aucun onglet x.com n'est ouvert. Espacement minimal de 1,5 s entre deux actions, 30 par minute au maximum.
- **Branche de départ** : `main` après le merge de la PR #31.
