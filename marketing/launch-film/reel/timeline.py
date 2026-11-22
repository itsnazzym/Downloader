"""Chronologie partagée image/son : 120 BPM, 1 temps = 15 images, 1 mesure = 60 images, 1200 images (40 s)."""
from dataclasses import dataclass

FPS, BPM = 30, 120
BEAT, BAR = 15, 60
TOTAL = 1200


@dataclass(frozen=True)
class Scene:
    name: str
    start: int
    end: int


SCENES = (
    Scene("boot", 0, 120),        # mesures 1-2 : intro, la grille s'allume
    Scene("title", 120, 240),     # drop 1
    Scene("phone", 240, 420),     # téléphone 3D et annotations
    Scene("pipeline", 420, 600),  # yt-dlp → aria2c → ffmpeg
    Scene("send", 600, 720),      # pont : envoi local
    Scene("carousel", 720, 900),  # drop 2 : carrousel 3D
    Scene("words", 900, 1080),    # rafale typographique, stutter
    Scene("end", 1080, 1200),     # impact final, logo
)

DROPS = (120, 720, 1080)                           # impacts lourds
CUTS = (240, 420, 600, 900)                        # whooshes de transition
TAPS = (372, 393)                                  # doigt sur l'écran (scène phone)
WORD_HITS = tuple(900 + i * BEAT for i in range(9))  # une carte par temps
STUTTER = tuple(1035 + i * 4 for i in range(6))   # glitch sur la dernière mesure
TAPE_STOP = (1062, 1080)


def scene(name: str) -> Scene:
    return next(s for s in SCENES if s.name == name)


def impact(f: float, decay: float = 6.0, hits=DROPS) -> float:
    """1 sur l'image d'impact, décroissance exponentielle ensuite."""
    best = 0.0
    for h in hits:
        d = f - h
        if 0 <= d < decay * 4:
            best = max(best, 2.0 ** (-d / decay * 3))
    return best
