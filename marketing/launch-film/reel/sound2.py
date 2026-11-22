"""Bande son v2 du showreel : vraie musique (Jamendo, CC BY 3.0) montée sur les drops, effets de la banque earshot.

    python -m reel.sound2      → out/reel/music.wav (puis python -m reel.assemble pour masteriser et muxer)

Musique : « Electron Wake [techno] », Hardcore Scm, CC BY 3.0, https://www.jamendo.com/track/1196244
(trouvée via Openverse). Le morceau (116,67 BPM) est rééchantillonné à 120 BPM (×36/35, +0,5 demi-ton),
puis monté par mesures : montée + drop 1 (0-20 s), fin du pont (20-24 s), drop 2 (24-36 s), coup final (36 s).
"""
import json
from fractions import Fraction
from pathlib import Path

import librosa
import numpy as np
from scipy.signal import fftconvolve, resample_poly

from earshot.forge import bank, kit

from . import music as synth
from . import timeline as tl

SR = 48000
N = int(SR * 40.0)
ROOT = Path(__file__).resolve().parents[1]
TRACK = ROOT / "assets" / "music" / "jam_1196244.mp3"
KIT = ROOT / "assets" / "kit"
OUT = ROOT / "out" / "reel"
SRC_BPM = 60 / 0.514289
# attaques des deux drops, mesurées sur le morceau rééchantillonné (saut d'énergie RMS 10 ms, voir find_drop)
D1, D2 = 42.849, 128.160
RATIO = Fraction(36, 35)  # 120 / 116.67


def fr(f: float) -> float:
    return f / tl.FPS


def load_track() -> np.ndarray:
    y, _ = librosa.load(TRACK, sr=SR, mono=False)
    y = y.T.astype(np.float64)
    return resample_poly(y, RATIO.denominator, RATIO.numerator, axis=0)


def find_drop(y: np.ndarray, t_guess: float, win: float = 0.6) -> float:
    """Instant du saut d'énergie (drop) le plus fort autour de t_guess : rapport des 300 ms après / avant."""
    lo = t_guess - win
    s = y[int(lo * SR):int((t_guess + win) * SR)].mean(1)
    w = int(0.01 * SR)
    r = np.sqrt(np.convolve(s ** 2, np.ones(w) / w, "same"))
    n, c = int(0.3 * SR), np.cumsum(r)
    i = np.arange(n, len(r) - n, 48)
    q = (c[i + n] - c[i]) / (c[i] - c[i - n] + 1e-9)
    k = int(i[np.argmax(q)])
    seg = r[k - int(0.02 * SR):k + int(0.02 * SR)]
    return lo + (k - int(0.02 * SR) + int(np.argmax(np.diff(seg)))) / SR


def edit(y: np.ndarray) -> tuple[np.ndarray, dict]:
    d1, d2 = find_drop(y, D1), find_drop(y, D2)
    out = np.zeros((N, 2))
    xf = int(0.012 * SR)

    def put(dst_t, src_t, dur, fade_in=True, fade_out=True):
        i, s, n = int(round(dst_t * SR)), int(round(src_t * SR)), int(round(dur * SR))
        seg = y[s:s + n + xf].copy()
        e = np.ones(len(seg))
        if fade_in:
            e[:xf] = np.linspace(0, 1, xf)
        if fade_out:
            e[-xf:] = np.linspace(1, 0, xf)
        j = min(N, i + len(seg))
        out[i:j] += (seg * e[:, None])[: j - i]

    put(0.0, d1 - 4.0, 20.0, fade_in=False)    # 2 mesures de montée, puis le drop à 4 s
    put(20.0, d2 - 4.0, 16.0)                  # fin du pont puis drop 2 à 24 s (coupé à 36 s)
    # 36 s : le temps fort du drop, prolongé par sa réverbération
    hit = y[int(d1 * SR):int((d1 + 0.6) * SR)].copy()
    hit *= np.linspace(1, 0, len(hit))[:, None] ** 2
    tail = fftconvolve(hit.mean(1), synth.reverb_ir(3.2, 3500)[:, 0])[: int(4 * SR)]
    tail = np.c_[tail, tail]
    seg = np.zeros((int(4 * SR), 2))
    seg[: len(hit)] += hit
    seg[: len(tail)] += tail / (np.abs(tail).max() + 1e-9) * 0.35
    seg *= np.linspace(1, 0, len(seg))[:, None] ** 1.5
    out[int(36 * SR):] += seg[: N - int(36 * SR)]
    out[int(36 * SR) - xf:int(36 * SR)] *= 0
    return out, {"d1": d1, "d2": d2}


def music_bed(y: np.ndarray) -> np.ndarray:
    m, _ = edit(y)
    m = synth.tape_stop(synth.stutter(m))
    a = int(fr(tl.TAPE_STOP[1]) * SR)
    m[a - int(0.02 * SR):a] *= np.linspace(1, 0, int(0.02 * SR))[:, None]
    # creux de 0,4 s sous la coupe drop 1 → pont (laisse passer le whoosh)
    t = np.arange(N) / SR
    g = 1 - 0.5 * np.exp(-((t - 19.9) / 0.15) ** 2)
    return m * g[:, None]


# ---------------------------------------------------------------- effets
def _stereo(x, width=0.0):
    if x.ndim == 2:
        return x
    if width <= 0:
        return np.c_[x, x]
    d = int(0.004 * SR * width)
    return np.c_[x, np.r_[np.zeros(d), x[:-d or None]]]


class Mixer:
    def __init__(self, bed: np.ndarray):
        self.lock = kit.render(str(KIT / "kit.json"), str(KIT / "takes"))
        self.bed = bed
        self.bed_path = OUT / "bed.wav"
        synth.write_wav(self.bed_path, bed)
        self.fx = np.zeros((N, 2))
        self._k = {}
        self.log = []

    def role(self, name: str, cue_f: float, extra_db: float = 0.0):
        r = self.lock["roles"][name]
        i = self._k.get(name, 0)
        self._k[name] = i + 1
        take = r["takes"][i % len(r["takes"])]
        x, sr = librosa.load(str(KIT / "takes" / take["file"]), sr=SR, mono=False)
        x = x.T if x.ndim == 2 else x
        cue = fr(cue_f)
        start = kit.place(take, r, cue)
        gain = kit.gain_db(take, r, kit.bed_level(str(self.bed_path), cue)) + extra_db
        self._add(_stereo(x, r.get("width") or 0), start, gain)
        self.log.append((round(cue, 3), name, take["file"], round(gain, 1)))

    def sound(self, sid: str, start_s: float, gain_db: float, **kw):
        y, meta = bank.render(sid, **kw)
        y = np.asarray(y, np.float64)
        y = y.T if y.ndim == 2 and y.shape[0] == 2 else y
        self._add(_stereo(y, 0.5), start_s, gain_db)
        self.log.append((round(start_s, 3), sid, "bank", gain_db))
        return meta

    def _add(self, x, start_s, gain_db):
        i = int(round(start_s * SR))
        x = x * 10 ** (gain_db / 20)
        s0 = max(0, -i)
        j = min(N, i + len(x))
        if j > max(0, i):
            self.fx[max(0, i):j] += x[s0:s0 + j - max(0, i)]


def apex_start(sid, apex_s, **kw):
    """Instant de départ pour que le maximum d'un son tombe à apex_s."""
    y, _ = bank.render(sid, **kw)
    y = np.asarray(y)
    mono = np.abs(y if y.ndim == 1 else y.mean(0 if y.shape[0] == 2 else 1))
    return apex_s - int(np.argmax(mono)) / SR


def build() -> tuple[np.ndarray, list]:
    y = load_track()
    bed = music_bed(y)
    m = Mixer(bed)
    # --- 0-4 s : les moteurs répondent, les points du logo se posent
    for t0 in (20, 32, 44, 56):
        m.role("tick.crisp", t0)
        m.role("pop", t0 + 8, -3)
    lands = kit.space_run([fr(f) for f in np.linspace(68, 104, 9)], 114)
    for t in lands:
        m.role("tick", t * tl.FPS, -2)
    m.sound("pro_riser/roll", fr(120) - 1.278, -14)
    # --- drops : impact + sous-grave accordés sur sol#
    for f in tl.DROPS:
        m.sound("pro_impact/deep", fr(f) - 0.01, -9, pitch="G#1")
        m.sound("pro_sub_drop/ref", fr(f), -12, pitch="G#1")
    # --- 4-8 s : panneau LED (chaque mot)
    for f in (123, 150, 180):
        m.role("land", f)
    m.sound("pro_whoosh_big/long", apex_start("pro_whoosh_big/long", fr(232)), -12)
    # --- 8-14 s : téléphone, annotations, tap
    m.role("whoosh.short", 241)
    m.role("land", 262, -2)
    for f in (255, 285, 315, 345):
        m.role("pop", f)
    m.role("land.light", 375)
    m.role("click.confirm", 377)
    m.role("whoosh.short", 410)
    # --- 14-20 s : chaîne et compteur
    for i, f in enumerate((450, 465, 480, 495)):
        m.role("tock", f, -1)
    for t in kit.space_run([fr(f) for f in np.arange(445, 556, 6.0)], 66):
        m.role("tick", t * tl.FPS, -6)
    m.role("bell", 560)
    m.role("bell", 563, -4)
    m.sound("downlifter/air_fall", fr(584), -16)
    # --- 20-24 s : pont, envoi local
    for f in (606, 636):
        m.role("land", f, -2)
    for t in kit.space_run([fr(f) for f in np.arange(616, 700, 15.0)], 114):
        m.role("tick", t * tl.FPS, -7)
    m.sound("reverse_swell/cymbal", fr(720) - 0.518, -11)
    # --- 24-30 s : carrousel
    for f in (750, 780, 810, 840, 870):
        m.role("whoosh.short", f, -1)
        m.role("tock", f + 6, -4)
    # --- 30-36 s : cartes, mur, glitch
    for k, f in enumerate(tl.WORD_HITS[:8]):
        m.role("hit" if k % 2 == 0 else "land", f, -2)
    for t in kit.space_run([fr(f) for f in np.arange(1020, 1034, 1.6)], 114):
        m.role("pop", t * tl.FPS, -6)
    for k, f in enumerate(tl.STUTTER[::2]):
        m.sound(("pro_glitch/fastroll", "glitch/mid", "pro_glitch/crunchy")[k % 3], fr(f), -15)
    m.sound("downlifter/tape", fr(tl.TAPE_STOP[0]), -14)
    # --- 36-40 s : logo, frappe du lien
    m.sound("pro_logo_sting/sweep_hit", fr(1080) - 0.338 + 0.04, -10)
    for t in kit.space_run([fr(f) for f in np.arange(1086, 1104, 4.0)], 114):
        m.role("pop", t * tl.FPS, -8)
    m.sound("pro_typing_run/soft", fr(1130), -16, dur=fr(31 / 1.6))
    mix = bed + m.fx
    mix = synth.hp(mix, 25)
    fade = np.ones(N)
    fade[-int(0.8 * SR):] = np.linspace(1, 0, int(0.8 * SR))
    return (mix * fade[:, None]).astype(np.float32), m.log


if __name__ == "__main__":
    mix, log = build()
    print(synth.write_wav(OUT / "music.wav", mix))
    (OUT / "sfx_log.json").write_text(json.dumps(log, indent=0))
    print(len(log), "effets placés")
