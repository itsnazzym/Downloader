# Film de lancement — TapLoad

`tapload-launch-1080p60.mp4` : 31,5 s, 1920×1080, 60 i/s, −14 LUFS. Motion design 3D entièrement procédural en Python (numpy, OpenCV, Pillow) : vraies captures de l'app, écrans Android générés en code (menu Partager, notifications, carte de progression), caméra et objets animés par ressorts amortis, profondeur de champ, animations calées sur les coups de basse du morceau.

## Rendu
```bash
python3 -m light.render4 part 0 2 & python3 -m light.render4 part 1 2; wait   # 2 moitiés en parallèle (≈ 3 min)
python3 -m light.render4 sound        # out/light4/master.wav (−14 LUFS, −1 dBTP)
python3 -m light.render4 assemble     # out/light4/modern-downloader-v4-1080p60.mp4 (crf 16)
python3 -m light.render4 stills 4.5,9.0,16.0   # images de contrôle
python3 -m light.check4               # contrôle de fluidité image par image
python3 -m pytest tests_reel -q
```
Le fichier livré est ré-encodé en crf 20 (`tapload-launch-1080p60.mp4`, < 100 Mo pour GitHub).
Images du README de l'app : `python3 -m tools.readme_media <dossier>`.

## Prérequis
Python 3.11+, numpy, scipy, opencv-python, Pillow, librosa, earshot 0.4, pytest, ffmpeg 6+, polices Inter / Inter Display.

## Crédits
- Musique : « Future Bass Lite », NERDtasticBEATS, CC BY 4.0 (`assets/music/ATTRIBUTION_v4.md`).
- Souffles sur les mots : « Powerfull Whooshes 1 », Nic3_one, Freesound, CC0.
- Autres effets : earshot (synthèse locale).

Les films précédents (`modern-downloader-*.mp4`, packages `film/` et `reel/`) portent l'ancien nom ; les deux premiers montrent aussi Big Buck Bunny (© Blender Foundation, CC BY 3.0). Ils ne sont plus liés depuis le README.
