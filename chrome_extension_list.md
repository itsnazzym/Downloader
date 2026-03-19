# Chrome Extension - Liste de travail

## Objectif

Ce document recense ce qu'il faut corriger, simplifier, remplacer, ajouter ou supprimer dans l'extension Chrome de Modern Downloader.

Le perimetre produit est desormais clair:

- l'application doit telecharger des videos
- l'extension Chrome doit donc rester orientee video
- les flux audio-only et photo/galerie doivent etre retires ou bloques

## Fichiers concernes

- `extension/chrome/manifest.json`
- `extension/chrome/background.js`
- `extension/chrome/content.js`
- `extension/chrome/popup.html`
- `extension/chrome/popup.js`
- `extension/chrome/popup.css`

## Resume rapide

L'extension fonctionne deja comme pont entre la page web et l'application desktop, mais elle reste trop large, trop permissive et trop heuristique.

Elle doit etre recentree sur:

- la detection video
- l'envoi fiable d'une URL video vers l'application
- l'etat de connexion avec l'app locale
- des reglages simples et coherents

## P0 - A corriger en premier

### Perimetre video-only

- Supprimer l'option `Audio Only` dans `content.js`.
- Supprimer le contexte `audio` du menu contextuel dans `background.js`.
- Revoir le contexte `page` du menu contextuel: ne le garder que si la page est clairement une page video.
- Empêcher l'extension d'envoyer des URLs qui ne correspondent pas a un flux video ou a une page video valide.
- Bloquer explicitement les telechargements photo/galerie cote extension avant envoi a l'application.

### Permissions et surface d'attaque

- Remplacer `"<all_urls>"` dans `manifest.json` par une liste de domaines supportes.
- Remplacer `host_permissions: "*://*/*"` par des permissions plus strictes.
- Verifier si `tabs` doit etre ajoute explicitement, car `background.js` utilise `api.tabs.query`.
- Revoir l'usage de `cookies` pour ne l'activer que sur les domaines utiles.

### Communication avec l'application

- Ajouter un vrai handshake avec token au lieu d'un simple `HELLO`.
- Verifier la version de protocole entre l'extension et l'app.
- Valider le schema des messages `DOWNLOAD`, `PROGRESS`, `HEARTBEAT_COOKIES`, `DEBUG`.
- Ajouter des erreurs explicites dans le popup quand l'application n'est pas joignable.
- Ajouter un backoff progressif sur les reconnexions WebSocket au lieu d'une boucle fixe a 5 secondes.

### Robustesse des payloads

- Verifier `mediaUrl` et `pageUrl` avant envoi.
- Ne pas baser toute la collecte cookies uniquement sur `pageUrl.hostname`.
- Gérer proprement les sous-domaines et les cas `www`, `m.`, `mobile`, etc.
- Clarifier le role de `cookieBrowser`: navigateur detecte, navigateur prefere, ou navigateur force.

### Nettoyage d'encodage

- Corriger tous les textes moches ou mal encodes dans `background.js` (`âœ…`, `âŒ`, `âš ï¸`, etc.).
- Uniformiser tous les fichiers JS/HTML/CSS en UTF-8 propre.

## P1 - A rendre propre et fiable

### `content.js`

- Remplacer le `setInterval(scan, 1000)` par une logique moins agressive.
- Debouncer le `MutationObserver`.
- Eviter de scanner toutes les balises `a` de la page en boucle.
- Remplacer les heuristiques generiques par des adapteurs par site.
- Eviter de muter brutalement la page avec `container.style.position = 'relative'` si cela peut casser le layout.
- Corriger le doublon `gap: '2px'`.
- Supprimer les variables inutilisees comme `hostname`.
- Mieux detecter les URLs video finales quand `video.currentSrc` est un `blob:`.

### UI injectee sur les pages

- Ajouter une logique pour ne pas afficher plusieurs boutons sur le meme contenu.
- Eviter les faux positifs sur des miniatures non videos.
- Ajouter un vrai etat "envoye", "erreur", "hors ligne" sur le bouton injecte.
- Ajouter un mode desactivation par site.
- Ajouter une whitelist/blacklist de sites cote utilisateur.

### Popup

- Remplacer le polling de statut toutes les 2 secondes par des evenements ou un etat stocke plus proprement.
- Afficher le dernier message d'erreur de connexion.
- Ajouter un bouton `Open App`.
- Ajouter un bouton `Test Connection`.
- Ajouter un bouton `Clear Recent`.
- Afficher la vraie URL source ou l'identifiant du job.
- Eviter l'injection HTML brute avec `innerHTML` pour des titres venant de l'application.
- Echapper ou sanitiser `item.title` et les valeurs affichees.

### Reglages

- Clarifier ce qui va dans `storage.local` et ce qui va dans `storage.sync`.
- Decider si `preferredBrowser` doit rester visible dans une extension Chrome.
- Supprimer ou brancher le setting mort `showQualitySelector`.
- Ajouter validation du port dans le popup.
- Ajouter reset des reglages.

## P2 - A ameliorer ensuite

### Experience utilisateur

- Ajouter un compteur de jobs recents plus lisible.
- Ajouter une vue "last successful send".
- Ajouter un indicateur du site detecte.
- Ajouter des raccourcis popup: `download current page`, `download detected video`, `open desktop app`.
- Ajouter notifications Chrome optionnelles apres envoi reussi/echec.

### Packaging et maintenance

- Synchroniser automatiquement la version extension avec `extension_version.json` ou le `pubspec`.
- Ajouter un script de build pour packager l'extension Chrome.
- Ajouter un zip release propre de l'extension.
- Ajouter une check-list de publication Chrome Web Store.
- Ajouter des tests de base sur les helpers JS critiques.

### Compatibilite

- Revoir la liste `SUPPORTED_DOMAINS`.
- Ajouter les sites reellement supportes par l'application.
- Supprimer les domaines non prioritaires si l'app ne les gere pas bien.
- Aligner les heuristiques de l'extension avec les plateformes effectivement supportees cote desktop.

## Remplacer

- Remplacer les scans generiques de DOM par des adapteurs par plateforme.
- Remplacer le polling de statut popup par un flux d'etat plus propre.
- Remplacer les permissions globales par des permissions minimales.
- Remplacer les `innerHTML` dynamiques par un rendu DOM plus sur.
- Remplacer les reconnexions fixes par une strategie de retry avec backoff.

## Ajouter

- Ajouter authentification locale extension -> application.
- Ajouter validation de schema des messages.
- Ajouter gestion d'erreurs visible.
- Ajouter mode debug propre.
- Ajouter packaging release extension.
- Ajouter journal minimum de connexion.

## Supprimer

- Supprimer `Audio Only`.
- Supprimer les flux non video.
- Supprimer les permissions trop larges.
- Supprimer les scans inutiles sur toutes les pages.
- Supprimer les textes mal encodes.
- Supprimer les options mortes ou non branchees.

## Nettoyage recommande

- Nettoyer `background.js` en modules/fonctions plus petites.
- Nettoyer `content.js` pour separer detection, UI, envoi et observer.
- Nettoyer `popup.js` pour separer rendu, storage et statut.
- Nettoyer `manifest.json` pour ne garder que les permissions utiles.
- Nettoyer les styles inline de `popup.html`.

## Definition d'une extension Chrome finale

L'extension Chrome peut etre consideree prete quand:

- elle n'envoie que des telechargements video valides
- elle communique proprement et de facon authentifiee avec l'application
- elle n'utilise pas de permissions globales inutiles
- elle ne degrade pas les pages web avec des scans trop agressifs
- son popup donne un vrai diagnostic de connexion
- elle est packagable et versionnee proprement
