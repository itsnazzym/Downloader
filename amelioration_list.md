# Modern Downloader - Amelioration List

## Objectif

Ce document recense les points a corriger, remplacer, ameliorer, ajouter ou supprimer pour faire evoluer le projet vers une version finale stable, propre et publiable.

## Resume rapide

- Le projet est une application Flutter desktop orientee Windows.
- Le coeur fonctionnel repose sur `yt-dlp`, `gallery-dl`, `aria2c` et `ffmpeg`.
- L'application dispose deja d'une UI desktop, d'une extension navigateur, d'une file d'attente, d'une persistance locale, d'un player integre, de statistiques et d'un systeme de plugins.
- Le projet est prometteur, mais plusieurs fonctions sont inachevees, incoherentes ou seulement partiellement branchees.

## Priorites globales

- `P0` : corriger les bugs de flux critiques et les incoherences fonctionnelles.
- `P1` : stabiliser le produit et rendre toutes les promesses du produit reelles.
- `P2` : enrichir l'experience utilisateur et la maintenabilite.
- `P3` : industrialiser le produit pour la publication et l'evolution long terme.

## P0 - A corriger en premier

### Flux d'entree et automatisation

- Corriger le flux deep link `moderndownloader://`.
- Corriger le flux "single instance" pour qu'une URL lancee depuis une deuxieme instance ouvre bien la bonne action dans l'UI.
- Corriger le flux presse-papiers pour qu'un lien detecte aboutisse au bon provider de lancement.
- Uniformiser la logique entre `launchUrlProvider` et `launchDataProvider`.
- Supprimer les chemins alternatifs morts ou non relies a l'UI.

### Extension navigateur

- Corriger la communication extension -> application pour que les cookies et le user-agent envoyes soient reellement exploites.
- Corriger l'usage du port configure dans l'extension.
- Eviter les valeurs hardcodees cote extension.
- Ajouter une validation de protocole et de format de message cote serveur local.
- Ajouter une gestion propre des erreurs de connexion WebSocket.
- Eviter les reconnexions infinies sans journal de diagnostic.

### Authentification / cookies

- Corriger le fait que `yt-dlp` force Firefox meme quand l'utilisateur choisit un autre navigateur.
- Respecter `cookieBrowser` dans tous les flux.
- Distinguer clairement cookies Netscape, cookies HTTP header et cookies importes depuis navigateur.
- Ajouter une verification claire avant utilisation des cookies.
- Ajouter des messages d'erreur comprehensibles pour les cookies invalides ou verrouilles.

### Bibliotheque locale

- Corriger le scan de bibliotheque qui pointe vers un chemin Windows fixe au lieu du dossier configure.
- Faire reposer tous les rescans sur le dossier de sortie utilisateur.
- Eviter les faux positifs ou faux negatifs lors du rattachement fichier <-> entree.
- Corriger la reconstruction d'etat au redemarrage.

### Gestion images / galleries

- Corriger le fait que le scanner ne traite actuellement que les fichiers video.
- Ajouter une vraie prise en charge des images telechargees par `gallery-dl`.
- Corriger le service d'organisation qui considere pratiquement toute image comme une miniature.
- Rendre les galleries visibles, consultables et filtrables dans l'UI.

### Integrite fonctionnelle

- Corriger les options exposees dans l'UI mais non appliquees reellement.
- Corriger les stats pour enregistrer aussi les volumes telecharges, pas seulement le nombre de telechargements.
- Corriger le drag and drop qui envoie des chemins de fichiers comme si c'etaient des URLs.
- Corriger la logique de fallback `gallery-dl` pour stocker correctement le `filePath`, le dossier et les metadonnees.

## P1 - A rendre solide pour une beta publique

### Telechargement

- Ajouter une vraie gestion pause / reprise dans l'interface.
- Ajouter reprise automatique des jobs interrompus.
- Ajouter un mode "retry failed all".
- Ajouter un mode "resume all paused".
- Ajouter un mode "clear completed".
- Ajouter une priorisation de file.
- Ajouter des presets de qualite par site.
- Ajouter des presets audio / video / galerie.
- Ajouter un mode de telechargement playlist plus robuste.
- Ajouter un mode batch via collage multiple.
- Ajouter un import de liste d'URLs depuis `.txt` ou `.csv`.

### Traitement media

- Ajouter un support reel des thumbnails cote `gallery-dl`.
- Ajouter un support reel des sous-titres dans l'UI et dans le player.
- Ajouter extraction et affichage de metadonnees media plus riches.
- Ajouter detection plus robuste des doublons par hash ou signature, pas seulement par nom.
- Ajouter verification de presence des fichiers de sortie apres telechargement.
- Ajouter verification de taille et integrite pour les telechargements critiques.

### Player integre

- Finaliser le player integre pour les videos completes.
- Ajouter support audio only.
- Ajouter support ouverture du dossier courant.
- Ajouter bouton "ouvrir avec lecteur systeme".
- Ajouter support d'apercu de fichiers partiels quand possible.
- Ajouter support sous-titres.
- Ajouter support capture image / screenshot.

### Bibliotheque et classement

- Ajouter vue bibliotheque par type de media.
- Ajouter vue par source.
- Ajouter vue par date.
- Ajouter vue par taille.
- Ajouter vue "recently added".
- Ajouter tags ou labels personnalisables.
- Ajouter recherche plein texte plus robuste.
- Ajouter filtres combines.
- Ajouter options de tri stables et precises.
- Ajouter scan manuel de bibliotheque.
- Ajouter scan automatique au lancement configurable.

### Organisation intelligente

- Clarifier le perimetre du plugin Smart Organizer.
- Rendre les regles d'organisation plus visibles et plus comprehensibles.
- Ajouter simulation avant deplacer les fichiers.
- Ajouter historique des deplacements.
- Ajouter annulation d'un lot de deplacements.
- Ajouter categories distinctes pour videos, audios, images et archives.
- Ajouter exclusions de dossiers.
- Ajouter mode dry-run.

## P1 - Fiabilite produit

### Persistance et donnees

- Remplacer la persistance JSON brute par une vraie base locale.
- Ajouter migration de schema.
- Ajouter index pour filtres et recherche.
- Ajouter sauvegarde / restauration plus robuste.
- Ajouter export CSV et JSON.
- Ajouter rotation et nettoyage des logs.

### Etat et architecture

- Clarifier la separation entre presentation, orchestration, domaine et infra.
- Supprimer les providers ou services dupliques.
- Eviter les flux d'etat en double.
- Introduire des modeles plus coherents pour video, audio, gallery, fichier local.
- Distinguer "download job" et "library item".
- Distinguer "source URL" et "local file".

### Erreurs et diagnostic

- Ajouter une vraie couche d'erreurs typifiees.
- Ajouter une vue diagnostic complete.
- Ajouter une vue logs reelle par job.
- Ajouter une vue "copy debug report".
- Ajouter une vue "dependency health".
- Ajouter des messages d'erreur plus lisibles pour l'utilisateur final.

## P1 - UI / UX

### Interface generale

- Rendre l'interface entierement localisable.
- Remplacer les textes hardcodes par la couche `l10n`.
- Finaliser les presets visuels pour qu'ils aient un effet reel.
- Finaliser la couleur d'accent personnalisee pour qu'elle alimente le theme runtime.
- Harmoniser les composants UI entre design system et UI legacy.
- Uniformiser les marges, rayons, ombres, comportements hover et feedbacks.

### Experience utilisateur

- Ajouter onboarding au premier lancement.
- Ajouter ecran "setup dependencies" si les binaires manquent.
- Ajouter ecran "welcome" avec test systeme.
- Ajouter statut global de telechargement dans l'entete.
- Ajouter actions rapides globales.
- Ajouter confirmations plus intelligentes pour suppression et nettoyage.
- Ajouter vue vide plus utile avec raccourcis d'action.
- Ajouter raccourcis clavier visibles dans l'interface.
- Ajouter toast / notification plus informatifs.

### Accessibilite

- Ajouter navigation clavier complete.
- Ajouter focus states coherents.
- Ajouter meilleur contraste visuel.
- Ajouter tailles adaptatives.
- Ajouter labels accessibles pour icones et actions.

## P2 - Fonctions a ajouter

### Fonctionnalites produit

- Ajouter telechargement programme.
- Ajouter planification de jobs.
- Ajouter limites de bande passante.
- Ajouter limite par site.
- Ajouter historique des sites frequents.
- Ajouter file "watch later".
- Ajouter profils de telechargement.
- Ajouter profils "audio", "clip", "full quality", "archive".
- Ajouter mode "download later".
- Ajouter resume au reboot.
- Ajouter surveillance d'un dossier d'import.
- Ajouter surveillance d'une liste RSS ou chaines.

### Fonctions techniques

- Ajouter auto-update applicatif.
- Ajouter verification de version des binaires.
- Ajouter telechargement automatique de binaires manquants.
- Ajouter telemetry locale optionnelle de performance sans collecte distante.
- Ajouter crash recovery.
- Ajouter watchdog des process externes.
- Ajouter timeout configurable par source.
- Ajouter file d'operations de post-processing.

### Extensions et integrations

- Ajouter support extension Edge officiel.
- Ajouter support plus fiable Brave / Vivaldi / Opera.
- Ajouter menu contextuel plus riche.
- Ajouter detection du media de la page plus intelligente.
- Ajouter synchronisation de queue entre extension et app.
- Ajouter bouton "open in app" plus robuste.

## P2 - Nettoyage de code

### A supprimer ou fusionner

- Supprimer les fichiers legacy inutilises.
- Supprimer les doublons de theme.
- Supprimer les services deprecies.
- Supprimer les providers de lancement redondants.
- Supprimer les composants UI non utilises.
- Supprimer les artefacts de build du depot de travail final.
- Supprimer les archives release presentes a la racine.
- Supprimer les fichiers de debug ou notes temporaires.

### A refactorer

- Refactorer la logique `main.dart` en bootstrap modulaire.
- Refactorer le pipeline `yt-dlp` dans un orchestrateur dedie.
- Refactorer la gestion des regex de progression.
- Refactorer la persistence dans un repository de donnees propre.
- Refactorer les plugins pour un vrai cycle de vie.
- Refactorer l'organisation des dossiers `core`, `services`, `theme`, `ui`.
- Refactorer la gestion des commandes systeme pour centraliser l'execution.

### A renommer / reorganiser

- Renommer les dossiers pour separer clairement app, infra, domain, features.
- Reorganiser les fichiers settings par domaine fonctionnel.
- Reorganiser la couche extension.
- Reorganiser la couche installation / packaging.

## P2 - Securite et vie privee

- Ajouter authentification locale entre extension et app.
- Utiliser vraiment `apiToken`.
- Ajouter validation du client WebSocket.
- Ajouter liste blanche de commandes ou d'origines.
- Ajouter chiffrement local optionnel des donnees sensibles.
- Ajouter politique claire de conservation des cookies temporaires.
- Supprimer automatiquement les cookies temporaires obsoletes.
- Ajouter journal d'audit local minimal pour actions sensibles.

## P2 - Packaging et distribution

- Bundler les binaires requis dans l'installateur.
- Ajouter verification post-install.
- Ajouter signature du binaire.
- Ajouter versioning plus propre.
- Ajouter changelog automatique.
- Ajouter build portable et installable coherents.
- Ajouter verification de presence de Visual C++ runtime si necessaire.
- Ajouter script de registration protocole integre a l'installateur.
- Ajouter test d'installation sur machine vierge Windows 10 et 11.

## P3 - Industrialisation

### Tests

- Ajouter tests unitaires sur:
- Parsing progression `yt-dlp`
- Queue manager
- Repository downloader
- Persistence
- Scan bibliotheque
- Plugins
- Service extension / serveur local
- Settings et migrations

- Ajouter tests widget sur:
- Ecrans de settings
- Liste de downloads
- Inspector
- Dialog d'ajout
- Sidebar

- Ajouter tests d'integration sur:
- Flux extension -> app
- Flux deep-link
- Flux clipboard
- Flux playlist
- Flux fallback `gallery-dl`

### CI / qualite

- Ajouter format check automatique.
- Ajouter coverage minimal.
- Ajouter analyse statique stricte.
- Ajouter matrice de build.
- Ajouter tests Windows desktop reels.
- Ajouter verification de packaging release.

## Remplacer

- Remplacer la persistence JSON par une base locale robuste.
- Remplacer les chemins hardcodes par une resolution basee sur les settings.
- Remplacer les flags hardcodes de cookies navigateur par des options reelles.
- Remplacer les faux logs par de vrais journaux de job.
- Remplacer les heuristiques fragiles de scan par des modeles de bibliotheque dedies.
- Remplacer les artifacts manuels de release par un pipeline reproductible.

## Ameliorer

- Ameliorer la fiabilite globale des telechargements.
- Ameliorer la coherence entre UI et logique metier.
- Ameliorer la gestion des erreurs.
- Ameliorer la gestion des cookies.
- Ameliorer la bibliotheque media.
- Ameliorer l'extension navigateur.
- Ameliorer les stats.
- Ameliorer l'accessibilite.
- Ameliorer la localisation.
- Ameliorer la maintenabilite du code.

## Ajouter

- Ajouter onboarding.
- Ajouter installation guidee des dependances.
- Ajouter support complet galleries/images.
- Ajouter profils et presets.
- Ajouter pause/reprise UI.
- Ajouter tests et couverture.
- Ajouter packaging complet.
- Ajouter securisation de la communication locale.
- Ajouter journaux reels et diagnostics.

## Supprimer

- Supprimer les doublons de code.
- Supprimer les options mortes ou non branchees.
- Supprimer les artefacts a la racine.
- Supprimer les comportements hardcodes injustifies.
- Supprimer les fichiers legacy de theme et services non utilises.

## Nettoyage final recommande

- Nettoyer la racine du projet.
- Nettoyer l'architecture des dossiers.
- Nettoyer les flux de lancement.
- Nettoyer les services systeme.
- Nettoyer les flags de settings non utilises.
- Nettoyer les imports et composants non utilises.
- Nettoyer les textes en dur.
- Nettoyer les promesses produit non tenues.

## Definition d'un projet final

Le projet peut etre considere comme "final" quand les points suivants sont vrais:

- Tous les flux d'entree fonctionnent: UI, extension, clipboard, deep-link.
- Les cookies et navigateurs choisis sont respectes.
- Les videos, audios et galleries sont tous pris en charge proprement.
- Les settings exposes ont tous un effet reel.
- Le telechargement, la reprise, les erreurs et les stats sont fiables.
- L'installation sur une machine vierge fonctionne sans bricolage manuel.
- Les binaires requis sont geres proprement.
- Le code est nettoye, teste et structure pour evoluer.
