"""Découpage en scènes et table des cues son/image, sur une grille de 120 BPM."""
from dataclasses import dataclass

from .config import BEAT


@dataclass(frozen=True)
class Scene:
    name: str
    start: int
    end: int  # exclue


@dataclass(frozen=True)
class Cue:
    frame: int          # instant du pic / de l'impact
    kind: str           # riser, impact, whoosh, tap, tick, glitch, swell
    gain_db: float = 0.0
    length: int = 0     # durée en images avant le pic (riser, swell)


SCENES = (
    Scene("s1", 0, 120),
    Scene("s2", 120, 330),
    Scene("s3", 330, 570),
    Scene("s4", 570, 780),
    Scene("s5", 780, 900),
)

CUES = tuple(sorted([
    Cue(105, "riser", length=90), Cue(105, "impact"), Cue(120, "whoosh"),
    Cue(165, "impact"), Cue(225, "tap"), Cue(285, "impact"),
    *[Cue(f, "tick") for f in range(330, 387, 3)],
    Cue(405, "impact"), Cue(465, "tap"), Cue(480, "whoosh"), Cue(480, "glitch"),
    Cue(570, "whoosh"), Cue(585, "impact"), Cue(630, "swell", length=60),
    Cue(690, "impact"), Cue(705, "tap"), Cue(720, "tap"), Cue(735, "tap"),
    Cue(780, "riser", length=60), Cue(780, "impact", gain_db=2.0),
    Cue(840, "swell", length=60),
], key=lambda c: c.frame))


def beat(n: float) -> int:
    return round(n * BEAT)


def scene_at(frame: int) -> Scene:
    for s in SCENES:
        if s.start <= frame < s.end:
            return s
    raise ValueError(frame)
