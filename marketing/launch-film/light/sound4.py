"""Bande son v4 : la v3 avec une basse et un rythme renforcés (étagère basse, sous-kicks synthétiques calés sur les
coups de grosse caisse du morceau, clicks de transitoire, sub earshot sur les gros coups, compression parallèle)."""
from functools import lru_cache

import librosa
import numpy as np
from scipy.signal import butter, sosfilt

from earshot.forge import bank
from reel import music as synth

from . import beats as B
from . import sound as v3

SR = v3.SR
N = v3.N
OUT = B.ROOT / "out" / "light4"
THR = 0.5          # seuil des coups de basse (normalisés par phrase)
SUB_DECAY = 0.12   # sous-kick avec du poids ; la queue des basses d'origine est resserrée (SH_D) pour ne pas baver
SUB_G = 0.2
LO_CEIL = 2.0
PRESENCE = 1.7      # gain au-dessus de 500 Hz au mastering (équilibre tonal : basses fortes sans mix terne)
TP_CEIL = -1.5
MID_CUT = 0.2      # creux 120-500 Hz au mastering : libère de la sonie pour les basses sans ternir le haut du spectre
BURST_TAU = 0.012
SUB_B = 6.0        # salve initiale courte (transitoire) en plus de la queue de SUB_DECAY
COMP_MIX = 0.0      # compression parallèle des basses : désactivée (elle écrase le transitoire)
SH_A = 4.0         # surcharge de l'attaque des basses (transitoire)
SH_D = 1.0         # creux juste après l'attaque (resserre la basse)


@lru_cache(maxsize=1)
def _low_env():
    y, sr = librosa.load(B.TRACK, sr=22050, mono=True)
    y = sosfilt(butter(4, 120, "low", fs=sr, output="sos"), y)
    hop = 64
    env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)
    t = librosa.frames_to_time(np.arange(len(env)), sr=sr, hop_length=hop) - B.OFFSET
    return t, env


@lru_cache(maxsize=1)
def kicks() -> np.ndarray:
    """Coups de grosse caisse/basse (bande < 120 Hz), sur la grille de doubles croches, en s vidéo."""
    t, env = _low_env()
    d = B.drop()
    ks = np.arange(int(np.floor(-d / B.S16)), int((B.MUSIC_LEN - d) / B.S16))
    slot = d + ks * B.S16
    val = np.array([env[(t >= x + 0.005) & (t < x + 0.085)].max(initial=0) for x in slot])
    ph = np.floor((slot - d) / B.PHRASE).astype(int)
    norm = np.zeros_like(val)
    for p in np.unique(ph):
        m = ph == p
        norm[m] = val[m] / (np.percentile(val[m], 90) + 1e-6)
    keep = (norm > THR) & (slot >= d - 0.05) & (slot < B.MUSIC_LEN)
    return slot[keep]


def _sub_kick() -> np.ndarray:
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    f = 48 + (110 - 48) * np.exp(-t / 0.04)
    ph = 2 * np.pi * np.cumsum(f) / SR
    e = np.minimum(t / 0.001, 1) * (np.exp(-t / SUB_DECAY) + SUB_B * np.exp(-t / BURST_TAU))
    return np.sin(ph) * e


def _click() -> np.ndarray:
    n = int(0.006 * SR)
    r = np.random.default_rng(4).standard_normal(n)
    r = sosfilt(butter(2, 2000, "high", fs=SR, output="sos"), r)
    return r * np.exp(-np.arange(n) / SR / 0.002) * np.minimum(np.arange(n) / (0.0005 * SR), 1)


def _add(buf, x, t, g):
    i = int(round(t * SR))
    j = min(len(buf), i + len(x))
    if 0 <= i < j:
        buf[i:j] += (x[:j - i] * g)[:, None] if buf.ndim == 2 else x[:j - i] * g


def _env(x, tau=0.01):
    a = np.exp(-1 / (tau * SR))
    r = sosfilt(np.array([[1 - a, 0, 0, 1, -a, 0]]), np.abs(x))
    return r


def build():
    mix, log = v3.build(real_pops=True)
    mix = mix.astype(np.float64)
    # (a) étagère basse +4 dB sous 110 Hz
    low = sosfilt(butter(2, 110, "low", fs=SR, output="sos"), mix, axis=0)
    mix = mix + (10 ** (4 / 20) - 1) * low
    # (d) compression parallèle du bas du spectre (enveloppe 10 ms, ratio 3, mélange COMP_MIX)
    low = sosfilt(butter(4, 120, "low", fs=SR, output="sos"), mix, axis=0)
    e = _env(low.mean(1)) + 1e-6
    thr = np.percentile(e, 60)
    gain = np.where(e > thr, (e / thr) ** (1 / 3 - 1), 1.0)
    comp = low * gain[:, None] * (1 / max(gain.mean(), 1e-3))
    mix = mix + COMP_MIX * comp
    # (b0) mise en forme du transitoire : l'attaque de la basse ressort, sa queue se resserre sous chaque coup
    low = sosfilt(butter(4, 120, "low", fs=SR, output="sos"), mix, axis=0)
    g = np.zeros(N)
    for t in kicks():
        i = int(t * SR)
        m = min(N - i, int(0.12 * SR))
        dt = np.arange(m) / SR
        g[i:i + m] += SH_A * np.exp(-dt / 0.012) - SH_D * np.clip((dt - 0.012) / 0.01, 0, 1) * np.exp(-dt / 0.06)
    mix = mix + low * g[:, None]
    # (b) sous-kick synthétique + click sur chaque coup de grosse caisse
    sub, clk = _sub_kick(), _click()
    ref = np.abs(mix).mean(1)
    for t in kicks():
        i = int(t * SR)
        pk = ref[i:i + int(0.06 * SR)].max(initial=0.2)
        pk = max(pk, 0.2)
        _add(mix, sub, t, pk * SUB_G)
        _add(mix, clk, t, pk * 0.35)
    # (c) sub earshot sur les gros coups
    ht, hs = B.hits()
    y, _ = bank.render("cut_hit/sub")
    y = np.asarray(y, np.float64)
    y = y.mean(1) if y.ndim == 2 and y.shape[1] == 2 else (y.mean(0) if y.ndim == 2 else y)
    for t in ht[hs >= 0.95]:
        _add(mix, y, t, 10 ** (-12 / 20))
    return mix.astype(np.float32), log


def _limit_gain(pk, ceil, look=0.004, rel=0.08):
    """Gain d'un limiteur à anticipation (min glissant + lissage, relâchement exponentiel)."""
    from scipy.ndimage import minimum_filter1d, uniform_filter1d
    need = np.minimum(1.0, ceil / np.maximum(pk, 1e-9))
    w = int(look * SR)
    g = uniform_filter1d(minimum_filter1d(need, 2 * w + 1), 2 * w + 1)
    a = np.exp(-1 / (rel * SR))
    out = np.empty_like(g)
    c = 1.0
    for i in range(len(g)):
        c = g[i] if g[i] < c else a * c + (1 - a) * g[i]
        out[i] = c
    return np.minimum(out, need)


def _chain(x, gain_db, lo_ceil=None, hi_ceil=0.4):
    """Gain, puis deux bandes : basses écrêtées en douceur (tanh), reste limité à anticipation."""
    lo_ceil = lo_ceil or LO_CEIL
    from scipy.signal import sosfiltfilt
    x = x * 10 ** (gain_db / 20)
    lo = sosfiltfilt(butter(4, 120, "low", fs=SR, output="sos"), x, axis=0)
    md = sosfiltfilt(butter(4, 500, "low", fs=SR, output="sos"), x - lo, axis=0)
    hi = (x - lo - md) * PRESENCE
    md = md * MID_CUT
    lo = sosfiltfilt(butter(2, 32, "high", fs=SR, output="sos"), lo, axis=0)
    lo = lo_ceil * np.tanh(lo / lo_ceil)
    hm = (hi + md) * _limit_gain(np.abs(hi + md).max(1), hi_ceil)[:, None]
    return lo + hm


def master(src, dst, target=-14.0, tp=None):
    """Mastering propre à la v4 (sans le limiteur partagé de reel.assemble) : -14 LUFS, basses préservées,
    puis limiteur ffmpeg suréchantillonné pour la crête vraie. Le gain est itéré jusqu'à -14 LUFS."""
    tp = TP_CEIL if tp is None else tp
    import subprocess
    import tempfile
    from scipy.io import wavfile
    from reel.assemble import loudness
    sr, x = wavfile.read(str(src))
    x = x.astype(np.float64) / 32768.0 if x.dtype == np.int16 else x.astype(np.float64)
    ceil = 10 ** (tp / 20)
    gain = 0.0
    with tempfile.TemporaryDirectory() as d:
        tmp = f"{d}/c.wav"
        for _ in range(6):
            wavfile.write(tmp, SR, _chain(x, gain).astype(np.float32))   # float : peut dépasser 1,0, le limiteur gère les crêtes
            af = f"aresample=192000,alimiter=limit={ceil:.4f}:attack=3:release=50:level=false,aresample=48000"
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-af", af, "-ar", "48000", str(dst)], check=True)
            i, peak = loudness(dst)
            if abs(i - target) < 0.15 and peak <= -1.0:
                break
            gain += target - i
    return dst


def main():
    mix, log = build()
    OUT.mkdir(parents=True, exist_ok=True)
    raw = synth.write_wav(OUT / "mix.wav", mix)
    master(raw, OUT / "master.wav")
    print(OUT / "master.wav", len(kicks()), "coups")
