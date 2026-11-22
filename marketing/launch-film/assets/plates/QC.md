# Contrôle des plates Seedance

| Plate | Job | Verdict | Raison |
|---|---|---|---|
| p2 traînées | 2342eff1-9c7d-4446-94dc-f7549ee598c4 | accepté | Aucun texte ni objet ; voile gris (luminance 0,151 à 2,5 s) neutralisé par l'écrasement du noir dans `fx.Plate` |
| p3 onde de choc | af92688f-29cb-4aed-8513-a964fd93762f | accepté | Flash, anneau et particules, quelques étincelles rouges ; aucun texte ni objet ; pic mesuré automatiquement (`Plate.hit_time`) pour le caler sur les impacts |
| p1 trame | 1a9d7521-1d82-40f4-8ef9-ecce6e8b1995 | accepté (3ᵉ version) | Trame de fins points en perspective balayée par une vague ; luminance moyenne 0,006–0,038 ; aucun texte ni objet ; remplace la comète d'origine (d7cf2e61…) qui se lisait comme un lens flare. Essai intermédiaire b4ebfdf6… rejeté : gros points gris, luminance 0,18–0,26 |
| p4 anneaux | 9908c670-d197-49b5-8c12-ce71c4050c28 | accepté | Anneaux de points concentriques, écho du radar de l'écran Envoi ; aucun texte ni objet |
| p5 poussière | 9b0606b6-0ae0-47b1-ab64-19750d20197b | accepté | Poussière fine avec profondeur de champ ; aucun texte ni objet |
| p1 trame 9:16 | 25c4c960-e8d5-4acd-80af-4c1b63028c9e | accepté (version verticale) | Natif 720×1280 ; luminance moyenne ≤ 0,044 ; aucun texte ni objet ; `p1_v.mp4` est préféré par `fx.Plate` en mode vertical |
| p2 traînées 9:16 | ed789086-6d02-4649-a756-473b83133482 | rejeté | Aucun texte ni objet, mais luminance moyenne 0,81 en fin de plate (seuil 0,15) ; la version verticale reprend p2 recadré (`fx._cover`) |

Pour le format vertical, p2 à p5 sont les plates 16:9 acceptées ci-dessus, recadrées au centre (`fx._cover`) ; seul p1 existe en version native 9:16.
