# Film de lancement Modern Downloader — Design

**Date :** 2026-11-19 · **Statut :** approuvé (approche B, hybride)

## Intention
Un film de lancement de 30 s pour l'app Android Modern Downloader, au format 16:9. Il est fait surtout de motion design, avec un montage épique, des effets et du sound design. Il doit être dynamique et de haute qualité, et ne jamais avoir l'air généré par IA.

## Objectifs / non-objectifs / anti-objectifs
- **Objectifs :** une accroche forte dès la 1re seconde. Les vraies fonctions mobiles sont montrées sur les vrais écrans. Les coupes tombent sur le tempo. Le logo est reconstruit exactement. Les titres sont en français, exacts.
- **Non-objectifs :** pas de voix off, pas de version verticale, pas de fonctions desktop (Tor, extension navigateur, Windows).
- **Anti-objectifs (le film échoue même s'il « marche ») :** l'IA dessine une interface, du texte, un logo, un téléphone, des mains ou des visages. Dégradés violet/bleu génériques, blobs lumineux, lens flares gratuits. Fondus enchaînés mous. Texte qui déborde ou tremble. Musique sans lien avec les coupes. Promesse fausse sur l'app.

## Contraintes
- Sortie : 1920×1080, 30 fps, H.264 yuv420p CRF 16, AAC 320 kb/s 48 kHz, durée 30,00 s (900 images).
- Le tempo est fixé à 120 BPM : 1 temps = 15 images, 1 mesure = 60 images.
- Palette du logo : noir `#000000`, blanc logo (échantillonné), rouge logo (échantillonné), gris `#27272A` / `#A1A1AA`. Le rouge est réservé à un seul accent par plan.
- Typo : Inter Display Black/Bold pour les titres, Inter Medium pour les sous-titres, 4 mots maximum par carton. Tout le texte reste dans la zone sûre (90 %).
- Higgsfield : tout passe par l'illimité (expire le 2026-11-22 07:38, heure de Paris). Seedance 2.5 en t2v, 720p, `generate_audio:false`, pour les plates abstraites uniquement. Aucune dépense de crédits sans accord explicite.
- Le workspace n'a pas d'accès réseau vers Higgsfield. Les plates passent par le navigateur intégré ou par l'utilisateur, puis par `device_stage_files`. Le film doit se rendre même sans aucune plate, avec un repli procédural.

## Approches
- **A — tout IA (Seedance avec les écrans en référence)** : rapide et spectaculaire, mais l'interface et le texte se déforment. Écartée : c'est exactement le « slop » à éviter.
- **B — hybride (retenue)** : Seedance ne fait que des textures lumineuses abstraites, et le code compose tout ce qui doit être exact.
- **C — 100 % code** : fidèle, mais moins cinématique. Elle sert de repli automatique si les plates manquent.

## Ce qui est décidé
**Structure (images à 30 fps) :**
| Scène | Images | Contenu | Texte |
|---|---|---|---|
| S1 Accroche | 0–119 | Point rouge seul → la matrice s'allume colonne par colonne → logo, impact à f105 | — |
| S2 Partage | 120–329 | Carton cinétique, puis le téléphone claque : 06_share → 23_capture_to_add_sheet (tap) → 05_done (validation) | « Partage. Un tap. » |
| S3 Navigateur & bibliothèque | 330–569 | Compteur qui monte jusqu'à 1 800+, puis 22_browser_capture_bar en push caméra, whip pan, 03_library | « 1 800+ sites. » |
| S4 Envoi & archive | 570–779 | Deux téléphones (12_send) reliés par un flux de points, puis éventail de cartes 14_archive / 13_stats | « Envoi local. Sans câble. » · « Ton archive TikTok. » |
| S5 Final | 780–899 | Le logo se reforme, wordmark, sous-ligne, noir à f890 | « Modern Downloader » · « Android · Open source · Zéro pub » |

**Couches :** fond noir, puis plates Seedance en mode screen (luminosité ≤ 35 %), puis maquette téléphone dessinée en code avec les vraies captures (barre de navigation Android grise coupée), puis typo, puis finition : grain léger, vignette, aberration chromatique de 2 images sur les impacts, flou de mouvement par sous-images sur les mouvements rapides.

**Plates Seedance (5 × 5 s) :** P1 vague de grille de points, P2 traînées de lumière en tunnel, P3 onde de choc de particules, P4 anneaux concentriques en pointillés, P5 poussière ambiante. Toutes sur fond noir pur, sans texte, objet, personne ni logo.

**Son :** un lit musical trailer instrumental de 30 s à 120 BPM, plus des SFX procéduraux (numpy) calés à l'image : riser, impact sub, whoosh, tap UI, ticks du compteur, glitch. Ducking de la musique sous les impacts. Master à −14 LUFS intégré, crête ≤ −1 dBTP. Source de la musique : Seedance 2.5 t2v 30 s, audio extrait (gratuit), ou ElevenLabs Music v2.5 si l'utilisateur accepte le coût en crédits.

**Promesses autorisées** (vérifiées dans le README) : partage depuis n'importe quelle app, 1 800+ sites (yt-dlp), envoi LAN sans câble, archive TikTok, open source MIT, zéro pub et zéro télémétrie. Aucun logo de marque tierce (YouTube, TikTok) n'est dessiné.

## Laissé au réalisateur
Les courbes d'easing exactes, les amplitudes de caméra, le dosage des plates et l'ordre fin des SFX à l'intérieur d'un plan, tant que les cues restent sur la grille des temps.
