"""Carte des coups de « Future Bass Lite » (NERDtasticBEATS, CC BY 4.0), en temps vidéo.

Le film utilise la fin du morceau : de 8,95 s à 38,95 s (sa fin), soit 30 s, plus 1,5 s de queue de réverbération.
Le drop tombe à 4,12 s vidéo ; ensuite 8 phrases de 2 mesures (3,244 s, 148 BPM en demi-tempo).
"""
from functools import lru_cache
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
TRACK = ROOT / "assets" / "music" / "v3_fblite.mp3"
OFFSET = 8.95          # début de l'extrait dans le morceau (s)
MUSIC_LEN = 30.0       # durée utilisée du morceau
TAIL = 1.5             # queue après la dernière note
DUR = MUSIC_LEN + TAIL
FPS = 30
FRAMES = int(round(DUR * FPS))
DROP_T = 13.0719       # attaque du drop dans le morceau
PHRASE = 6.4876 / 2    # 2 mesures (s)


def drop() -> float:
    return DROP_T - OFFSET


def phrases() -> list[float]:
    """Débuts de phrase en temps vidéo (le premier est le drop)."""
    return [drop() + k * PHRASE for k in range(9)]


S16 = PHRASE / 32       # double croche (0,1014 s)
LAG = 0.04              # l'enveloppe d'onset culmine ~40 ms après l'attaque


@lru_cache(maxsize=1)
def _env():
    import librosa
    y, sr = librosa.load(TRACK, sr=22050, mono=True)
    hop = 64
    env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)
    t = librosa.frames_to_time(np.arange(len(env)), sr=sr, hop_length=hop) - OFFSET
    return t, env


@lru_cache(maxsize=1)
def hits(thr: float = 0.42) -> tuple[np.ndarray, np.ndarray]:
    """Coups perçus calés sur la grille de doubles croches du morceau (temps d'attaque, en s vidéo) et leur force.

    Pour chaque case de la grille : maximum de l'enveloppe d'onset juste après l'attaque, normalisé par le
    90e centile de sa phrase (la seconde moitié du drop est moins percussive mais garde ses coups).
    """
    t, env = _env()
    d = drop()
    ks = np.arange(int(np.floor(-d / S16)), int((MUSIC_LEN - d) / S16))
    slot = d + ks * S16
    val = np.array([env[(t >= x + 0.005) & (t < x + LAG + 0.045)].max(initial=0) for x in slot])
    ph = np.floor((slot - d) / PHRASE).astype(int)
    norm = np.zeros_like(val)
    for p in np.unique(ph):
        m = ph == p
        norm[m] = val[m] / (np.percentile(val[m], 90) + 1e-6)
    keep = (norm > thr) & (slot >= 0.2) & (slot < MUSIC_LEN - 0.05)
    # un coup par case au plus, et au moins une croche entre deux coups faibles
    return slot[keep], np.clip(norm[keep], 0, 1.5)


def hits_between(a: float, b: float, min_s: float = 0.0) -> np.ndarray:
    t, s = hits()
    return t[(t >= a) & (t < b) & (s >= min_s)]


def last(t: float, times) -> tuple[int, float]:
    """Index et instant du dernier coup ≤ t (-1, -inf si aucun)."""
    times = np.asarray(times)
    i = int(np.searchsorted(times, t + 1e-9)) - 1
    return (i, float(times[i])) if i >= 0 else (-1, -np.inf)


def punch(t: float, times, tau: float = 0.11) -> float:
    """Impulsion qui retombe après chaque coup (1 sur le coup)."""
    _, h = last(t, times)
    return float(np.exp(-(t - h) / tau)) if np.isfinite(h) else 0.0
