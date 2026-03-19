# Modern Downloader - Implementation Plan

## But

Transformer le projet actuel en produit final stable, publiable et maintenable, sans casser les fonctions deja existantes.

## Strategie

- Corriger d'abord les flux critiques et les incoherences.
- Stabiliser ensuite le coeur de telechargement et la bibliotheque locale.
- Finaliser enfin l'experience utilisateur, les tests, le packaging et la publication.

## Vue d'ensemble

### Phase 1 - Stabilisation critique

Objectif:
- Rendre le produit coherent sur ses fonctions principales.

Livrables:
- Deep links corriges
- Flux extension corrige
- Cookies navigateur corriges
- Bibliotheque locale corrigee
- Support images/galleries remis a niveau
- Stats minimales fiables

### Phase 2 - Beta publiable

Objectif:
- Rendre le produit utilisable au quotidien sur machine normale.

Livrables:
- Installation plus simple
- UI coherente
- Pause/reprise UI
- Bibliotheque media propre
- Logs et diagnostics utiles
- Settings reellement appliques

### Phase 3 - Release finale

Objectif:
- Industrialiser et publier une vraie v1.

Livrables:
- Packaging complet
- Tests solides
- CI utile
- Nettoyage du depot
- Architecture refactoree

## Phase 1 - Stabilisation critique

### 1. Corriger les flux de lancement

Taches:
- Unifier `launchUrlProvider` et `launchDataProvider`.
- Revoir `main.dart`, `AppShell` et `SingleInstanceService`.
- Faire un seul flux d'entree standard:
- URL recue
- normalisation
- transformation en `LaunchData`
- execution ou ouverture du dialog

Definition of done:
- Un lien `moderndownloader://...` ouvre bien l'app et demarre la bonne action.
- Une deuxieme instance transmet correctement l'URL.
- Le clipboard et le deep link passent par le meme pipeline.

### 2. Corriger le pipeline extension

Taches:
- Respecter les cookies et le user-agent envoyes.
- Respecter le port configure.
- Ajouter structure de message stable.
- Ajouter validation des messages recus.
- Ajouter journal de connexion et erreurs explicites.

Definition of done:
- L'extension peut lancer un telechargement authentifie qui fonctionne sur sites protegees.
- Le mini dashboard recoit des mises a jour fiables.

### 3. Corriger les cookies navigateur

Taches:
- Supprimer le `--cookies-from-browser firefox` force.
- Utiliser `cookieBrowser` si fourni.
- Prioriser correctement:
- cookies fournis explicitement
- fichier cookies
- navigateur choisi

- Gérer clairement les conflits entre ces modes.

Definition of done:
- Le navigateur choisi par l'utilisateur est vraiment utilise.
- Les erreurs de cookies sont compréhensibles.

### 4. Corriger la bibliotheque locale

Taches:
- Remplacer le chemin hardcode par `settings.outputFolder`.
- Centraliser la notion de "library root".
- Revoir le scan de reparation.
- Revoir le scan des nouveaux medias.
- Ajouter support videos, audios et images.

Definition of done:
- Un changement de dossier de sortie est reflété partout.
- Le redemarrage restaure correctement les medias deja telecharges.

### 5. Reparer le support gallery/image

Taches:
- Etendre le scanner pour images et galleries.
- Corriger `FileOrganizationService` pour ne plus deplacer toute image vers `Thumbnails`.
- Enregistrer le dossier ou la liste de fichiers issus de `gallery-dl`.
- Afficher ces medias dans l'UI.

Definition of done:
- Un lot d'images telecharge par `gallery-dl` apparait correctement dans l'application.
- L'organizer ne detruit pas la bibliotheque image.

### 6. Rendre les stats fiables

Taches:
- Enregistrer aussi les octets telecharges.
- Ajouter source, type de media, date, duree du job si possible.
- Revoir les cartes et graphiques pour afficher des donnees utiles.

Definition of done:
- Les stats ne sont plus decoratives.

## Phase 2 - Beta publiable

### 7. Revoir la persistance

Decision recommandee:
- Migrer vers `Isar` ou `Hive`.

Taches:
- Creer modeles persistants:
- DownloadJob
- LibraryItem
- AppLog
- AppSetting si necessaire

- Ajouter migration depuis JSON existant.
- Ajouter index utiles.

Definition of done:
- Les donnees survivent bien aux redemarrages.
- Les filtres restent performants.

### 8. Revoir le domaine metier

Taches:
- Separer clairement:
- job de telechargement
- element de bibliotheque
- source distante
- fichier local

- Introduire types media:
- video
- audio
- image
- gallery
- local import

Definition of done:
- Le code n'a plus besoin d'heuristiques partout pour savoir de quoi il s'agit.

### 9. Pause / reprise / queue management

Taches:
- Exposer pause et resume dans la liste et l'inspector.
- Afficher l'etat queue de facon plus claire.
- Ajouter actions globales:
- pause all
- resume all
- retry failed
- clear completed

Definition of done:
- L'utilisateur controle reellement les jobs depuis l'UI.

### 10. Revoir l'UI des settings

Taches:
- Supprimer les options mortes.
- Brancher les options manquantes.
- Localiser tous les libelles.
- Regrouper les settings par domaine.
- Ajouter ecran de diagnostic dependances.

Definition of done:
- Chaque setting visible a un effet reel.

### 11. Revoir l'UI bibliotheque

Taches:
- Ajouter filtres combines.
- Ajouter tri robuste.
- Ajouter vue video / audio / images.
- Ajouter recherche par titre, URL, source, fichier.
- Ajouter `reveal in folder`.
- Ajouter `copy file path`.

Definition of done:
- La bibliotheque devient exploitable sur gros volume.

### 12. Revoir les logs et diagnostics

Taches:
- Stocker vrai log par job.
- Ajouter panneau debug.
- Ajouter export diagnostic.
- Ajouter visualisation des commandes lancees et erreurs externes.

Definition of done:
- Un bug de telechargement peut etre diagnostique sans deviner.

## Phase 3 - Release finale

### 13. Revoir le bootstrap applicatif

Taches:
- Sortir l'initialisation de `main.dart` dans un bootstrap dedie.
- Separer:
- init prefs
- init window
- init notifications
- init protocol
- init single instance
- init services background

Definition of done:
- Le demarrage devient lisible, testable et maintenable.

### 14. Refactorer la structure du projet

Taches:
- Supprimer couches legacy.
- Fusionner themes et services dupliques.
- Clarifier `core`, `features`, `infra`, `shared`.
- Supprimer les fichiers deprecies.

Structure cible recommandee:
- `lib/app`
- `lib/shared`
- `lib/features/downloader`
- `lib/features/library`
- `lib/features/settings`
- `lib/infra/process`
- `lib/infra/storage`
- `lib/infra/integration`

Definition of done:
- Le projet devient facile a parcourir.

### 15. Packaging / installation

Taches:
- Decider si les binaires sont embarques ou telecharges au premier lancement.
- Integrer le protocole custom dans l'installation.
- Integrer verification des dependances.
- Ajouter build portable + installable coherents.
- Ajouter tests sur machine vierge.

Definition of done:
- Une machine neuve peut installer et utiliser l'application sans manipulation obscure.

### 16. Securiser la communication locale

Taches:
- Utiliser `apiToken`.
- Ajouter handshake signe simple entre extension et app.
- Ajouter validation de version de protocole.
- Ajouter rotation du token si necessaire.

Definition of done:
- Le serveur local n'accepte pas n'importe quel client aveuglement.

### 17. Tests et CI

Taches:
- Ajouter tests unitaires sur les parseurs de sortie CLI.
- Ajouter tests du repository et de la queue.
- Ajouter tests widgets sur ecrans critiques.
- Ajouter tests integration desktop.
- Ajouter couverture minimale.
- Renforcer CI.

Definition of done:
- Les regressions critiques sont detectees automatiquement.

## Ordre recommande des chantiers

1. Flux de lancement
2. Extension + cookies
3. Bibliotheque locale
4. Support gallery/image
5. Stats et logs
6. Persistence propre
7. UI queue / pause / reprise
8. Settings reels + localisation
9. Packaging
10. Refactor architecture
11. Tests et publication

## Chantiers a supprimer ou repousser

Ces points ne doivent pas bloquer la stabilisation:

- Nouvelles animations UI
- Refactoring cosmetique sans impact produit
- Plugins externes avances
- Fonctions "AI" supplementaires
- Android natif si le produit reste Windows-first

## Risques techniques

### Risque 1 - dette de structure

Probleme:
- Plusieurs couches se chevauchent deja.

Mitigation:
- Refactor par etapes.
- Introduire une architecture cible avant gros chantier.

### Risque 2 - comportement des binaires externes

Probleme:
- `yt-dlp`, `gallery-dl`, `ffmpeg` et les navigateurs changent souvent.

Mitigation:
- Envelopper toutes les commandes dans une couche stable.
- Ajouter tests sur sorties parsees.

### Risque 3 - support cookies navigateur

Probleme:
- Les bases de cookies peuvent etre verrouillees.

Mitigation:
- Ajouter plusieurs modes d'auth:
- browser direct
- fichier cookies
- cookies importes

### Risque 4 - migration des donnees

Probleme:
- Le passage JSON -> DB peut casser l'historique.

Mitigation:
- Ajouter migration a sens unique testee.
- Conserver backup automatique.

## Criteres de validation finale

Le projet est considere pret pour une release finale si:

- Les deep links fonctionnent.
- L'extension fonctionne avec authentification.
- Les videos, audios et galleries sont visibles et fiables.
- Les settings visibles ont tous un effet.
- Les statistiques sont justes.
- Les logs sont exploitables.
- L'installation est simple.
- Les dependances sont gerees.
- Les tests critiques existent.
- Le depot est nettoye et structure.

## Proposition de jalons

### Milestone A - Core stable

- Flux de lancement corriges
- Extension corrigee
- Cookies corriges
- Bibliotheque corrigee

### Milestone B - Product usable

- Persistence propre
- Gallery/image support correct
- Queue et controle utilisateur complets
- UI settings et localisation propres

### Milestone C - Release ready

- Packaging final
- Security locale
- Tests renforces
- Nettoyage du projet

## Recommandation concrete

Le meilleur chemin n'est pas de "rajouter des fonctions partout" tout de suite.

Le meilleur chemin est:

1. Reparer les flux critiques.
2. Stabiliser les modeles et la persistence.
3. Finaliser le support media reel.
4. Nettoyer l'architecture.
5. Emballer et tester.

Sans cette sequence, toute nouvelle fonctionnalite sera construite sur une base encore trop fragile.
