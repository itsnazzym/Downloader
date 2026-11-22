"""Images du README de l'app (docs/media) refaites à partir des vraies captures, avec la vidéo de démonstration
« TapLoad — Présentation » (plus de Big Buck Bunny) et le nom TapLoad.

python3 -m tools.readme_media OUT_DIR  →  OUT_DIR/hero.png, OUT_DIR/screenshots/*.png"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import light  # noqa: F401  (active la démo « self »)
from film import assets as A

SHOTS = {  # nom de fichier du README → capture
    "telechargement": "capture",
    "navigateur": "browser",
    "bibliotheque": "done",
    "envoi": "send",
    "archive-tiktok": "archive",
    "statistiques": "stats",
    "reglages": "settings",
}
HERO = ("capture", "browser", "send", "archive", "stats")
SHOT_SIZE = (540, 1102)
HERO_SIZE = (2339, 940)


def shots(out: Path) -> list[Path]:
    (out / "screenshots").mkdir(parents=True, exist_ok=True)
    paths = []
    for name, key in SHOTS.items():
        p = out / "screenshots" / f"{name}.png"
        Image.fromarray(A.load_screen(key)).resize(SHOT_SIZE, Image.LANCZOS).save(p, optimize=True)
        paths.append(p)
    return paths


def hero(out: Path) -> Path:
    W, H = HERO_SIZE
    canvas = Image.new("RGB", (W, H), (0, 0, 0))
    ph = [Image.fromarray(A.phone(A.load_screen(k), 880)) for k in HERO]
    gap = (W - sum(p.width for p in ph)) // (len(ph) + 1)
    x = gap
    for p in ph:
        canvas.paste(p, (x, (H - p.height) // 2), p)
        x += p.width + gap
    path = out / "hero.png"
    canvas.save(path, optimize=True)
    return path


if __name__ == "__main__":
    o = Path(sys.argv[1])
    print(hero(o), *shots(o), sep="\n")
