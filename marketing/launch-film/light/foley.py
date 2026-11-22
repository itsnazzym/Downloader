"""Bruitages enregistrés (vrais sons, pas de synthèse) : souffles courts tirés de « Powerfull Whooshes 1 »
de Nic3_one sur Freesound (CC0, freesound.org/s/434870). Remplacent le « pop » synthétique sur les mots.

Chaque prise est découpée autour de son pic, filtrée sous 140 Hz (pas de boue sous la basse du morceau),
fondue aux bords, puis placée pour que son pic tombe juste après le coup (comme les souffles du kit)."""
from functools import lru_cache

import librosa
import numpy as np
from scipy.signal import butter, sosfilt

from earshot.forge import kit

from . import beats as B

SR = 48000
SRC = B.ROOT / "assets" / "sfx_gen" / "fs_434870_nic3.mp3"
# débuts (s) des prises retenues dans le fichier source : isolées, sans queue parasite
TAKES = (20.83, 24.9, 27.81, 22.09, 19.09, 14.28)
PRE, POST = 0.12, 0.42      # découpe autour du pic
OFFSET = 0.025              # le pic du souffle tombe 25 ms après le coup


@lru_cache(maxsize=None)
def take(i: int) -> tuple:
    """(stéréo float64 (n, 2), position du pic en s) pour la prise i (cyclique)."""
    t0 = TAKES[i % len(TAKES)]
    y, _ = librosa.load(str(SRC), sr=SR, mono=False, offset=max(0.0, t0 - 0.3), duration=1.2)
    y = np.asarray(y, np.float64)
    y = y.T if y.ndim == 2 else np.c_[y, y]
    env = np.convolve(np.abs(y).mean(1), np.ones(240) / 240, "same")
    p = int(env.argmax())
    a, b = max(0, p - int(PRE * SR)), min(len(y), p + int(POST * SR))
    x = sosfilt(butter(2, 140, "high", fs=SR, output="sos"), y[a:b], axis=0)
    n = len(x)
    f_in, f_out = int(0.01 * SR), int(0.15 * SR)
    w = np.ones(n)
    w[:f_in] = np.linspace(0, 1, f_in)
    w[-f_out:] = np.linspace(1, 0, f_out) ** 2
    x = x * w[:, None]
    return x, (p - a) / SR


def l50(x: np.ndarray) -> float:
    """sonie la plus forte sur 50 ms (échelle LUFS, comme le kit)."""
    return float(kit.loud_lufs(x, SR))


def gain(x: np.ndarray, bed: np.ndarray, t: float, bed_db: float) -> float:
    """gain (dB) pour que le souffle ressorte de bed_db au-dessus du lit musical juste avant t."""
    lvl = kit.bed_level(bed, t, SR)
    if lvl is None:
        return -18.0
    g = lvl + kit.over_bed(bed_db) - l50(x)
    pk = 20 * np.log10(np.abs(x).max() + 1e-12)
    return float(min(g, -3.0 - pk))


def pan(x: np.ndarray, p: float) -> np.ndarray:
    """panoramique à puissance constante, p ∈ [-1, 1]."""
    a = (p + 1) * np.pi / 4
    return np.c_[x[:, 0] * np.cos(a) * np.sqrt(2), x[:, 1] * np.sin(a) * np.sqrt(2)]


# ---------------------------------------------------------------- souffles de transition (plus longs)
# « Interface, Sf, Impact, Swoosh, Whoosh » de FALL-E sur Freesound (CC0, freesound.org/s/697434) :
# deux prises dessinées (montée puis pic), le pic est calé sur la coupe de la transition.
SRC_T = B.ROOT / "assets" / "sfx_gen" / "fs_697434_falle.mp3"
WHIPS = (9.4, 21.37)          # débuts approximatifs des deux prises dans le fichier source


@lru_cache(maxsize=None)
def whip(i: int) -> tuple:
    """(stéréo float64 (n, 2), position du pic en s) pour la prise de transition i (cyclique)."""
    t0 = WHIPS[i % len(WHIPS)]
    y, _ = librosa.load(str(SRC_T), sr=SR, mono=False, offset=t0 - 0.4, duration=2.0)
    y = np.asarray(y, np.float64)
    y = y.T if y.ndim == 2 else np.c_[y, y]
    env = np.convolve(np.abs(y).mean(1), np.ones(480) / 480, "same")
    th = env.max() * 0.1
    a = max(0, int(np.argmax(env > th)) - int(0.05 * SR))
    b = min(len(y), len(env) - int(np.argmax(env[::-1] > th)) + int(0.1 * SR))
    x = sosfilt(butter(2, 250, "high", fs=SR, output="sos"), y[a:b], axis=0)
    n = len(x)
    w = np.ones(n)
    f_in, f_out = int(0.02 * SR), int(0.25 * SR)
    w[:f_in] = np.linspace(0, 1, f_in)
    w[-f_out:] = np.linspace(1, 0, f_out) ** 2
    return x * w[:, None], (int(env.argmax()) - a) / SR
