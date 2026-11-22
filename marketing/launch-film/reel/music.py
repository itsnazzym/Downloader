"""Bande son du showreel, 100 % synthèse (numpy/scipy) : musique 120 BPM en la mineur + sound design calé à l'image.

    python -m reel.music            → out/reel/music.wav (48 kHz stéréo, avant mastering)
"""
import sys
from pathlib import Path

import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt

from . import timeline as tl

SR = 48000
DUR = 40.0
N = int(SR * DUR)
BEAT_S = 0.5
BAR_S = 2.0
OUT = Path(__file__).resolve().parents[1] / "out" / "reel"
_rng = np.random.default_rng(2026)


def fr(frame: float) -> float:
    """Image → secondes."""
    return frame / tl.FPS


def midi(n: float) -> float:
    return 440.0 * 2 ** ((n - 69) / 12)


# la mineur : Am – F – C – G (une mesure chacun)
PROG = ((57, 60, 64), (53, 57, 60), (55, 60, 64), (55, 59, 62))
ROOTS = (45, 41, 48, 43)


# ---------------------------------------------------------------- outils DSP
def lp(x, hz, order=2):
    return sosfilt(butter(order, min(hz, SR * 0.45), "low", fs=SR, output="sos"), x, axis=0)


def hp(x, hz, order=2):
    return sosfilt(butter(order, hz, "high", fs=SR, output="sos"), x, axis=0)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, (lo, min(hi, SR * 0.45)), "band", fs=SR, output="sos"), x, axis=0)


def saw(freq, n, phase=0.0):
    t = np.arange(n) / SR
    return 2 * ((freq * t + phase) % 1.0) - 1


def place(buf, sig, t, gain=1.0, pan=0.0):
    """Ajoute un signal mono ou stéréo à l'instant t (s)."""
    i = int(round(t * SR))
    if i >= len(buf):
        return
    if sig.ndim == 1:
        l, r = np.sqrt(0.5 * (1 - pan)), np.sqrt(0.5 * (1 + pan))
        sig = np.c_[sig * l * 1.414, sig * r * 1.414]
    j = min(len(buf), i + len(sig))
    s0 = max(0, -i)
    buf[max(0, i):j] += sig[s0:j - i] * gain


def env_ad(n, a, d, curve=4.0):
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-6), np.exp(-(t - a) / max(d, 1e-6) * curve / 4))
    return e


def section_gain(t_arr, keys):
    """Courbe par points (temps, valeur) interpolée linéairement."""
    ts, vs = zip(*keys)
    return np.interp(t_arr, ts, vs)


def reverb_ir(seconds=2.4, damp=5000):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = _rng.standard_normal((n, 2)) * np.exp(-t * 6.9 / seconds)[:, None]
    ir = lp(ir, damp)
    ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))[:, None]
    return ir / np.sqrt((ir ** 2).sum(0))


IR = None


def reverb(x, seconds=2.4, damp=5000):
    global IR
    if IR is None:
        IR = reverb_ir(seconds, damp)
    mono = x.mean(1) if x.ndim == 2 else x
    y = np.c_[fftconvolve(mono, IR[:, 0])[: len(mono)], fftconvolve(mono, IR[:, 1])[: len(mono)]]
    return y


# ---------------------------------------------------------------- instruments
def kick(gain=1.0, length=0.45, punch=1.0):
    n = int(length * SR)
    t = np.arange(n) / SR
    f = 46 + 110 * np.exp(-t / 0.035) * punch
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t / 0.16)
    click = hp(_rng.standard_normal(n), 3000) * np.exp(-t / 0.004) * 0.35
    return np.tanh((body + click) * 1.6) * gain


def clap():
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    noise = bp(_rng.standard_normal(n), 900, 3200)
    e = np.zeros(n)
    for d in (0.0, 0.011, 0.022):
        e += (t >= d) * np.exp(-np.clip(t - d, 0, None) / 0.008)
    e += (t >= 0.03) * np.exp(-np.clip(t - 0.03, 0, None) / 0.12) * 0.6
    return noise * e * 0.9


def hat(open_=False):
    n = int((0.28 if open_ else 0.06) * SR)
    t = np.arange(n) / SR
    x = hp(_rng.standard_normal(n), 7500, 3) * np.exp(-t / (0.09 if open_ else 0.014))
    return x * (0.5 if open_ else 0.4)


def pluck(freq, length=0.32, bright=4000.0, pw=0.32):
    n = int(length * SR)
    t = np.arange(n) / SR
    ph = (freq * t) % 1
    sq = np.where(ph < pw, 1.0, -1.0) * 0.6 + saw(freq * 2.002, n) * 0.25
    x = lp(sq, bright) * np.exp(-t / 0.075) * np.minimum(1, t / 0.002)
    return x


def blip(freq, length=0.18, decay=0.04, tone="sine"):
    n = int(length * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * freq * t) if tone == "sine" else np.sign(np.sin(2 * np.pi * freq * t)) * 0.5
    return s * np.exp(-t / decay) * np.minimum(1, t / 0.001)


def riser(length, f0=300, f1=6000):
    n = int(length * SR)
    t = np.linspace(0, 1, n)
    noise = _rng.standard_normal(n)
    out = np.zeros(n)
    k = 24
    for i in range(k):  # filtre balayé par blocs
        a, b = i * n // k, (i + 1) * n // k
        fc = f0 * (f1 / f0) ** (i / k)
        out[a:b] = bp(noise[a:b], fc * 0.6, fc * 1.6)
    tone = np.sin(2 * np.pi * np.cumsum(110 * 2 ** (t * 2.5)) / SR) * 0.25
    return (out * 0.9 + tone) * t ** 2.2


def impact(big=1.0):
    n = int(3.0 * SR)
    t = np.arange(n) / SR
    f = 32 + 70 * np.exp(-t / 0.08)
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.9)
    crash = hp(_rng.standard_normal(n), 2500) * np.exp(-t / 0.5) * 0.35
    body = lp(_rng.standard_normal(n), 600) * np.exp(-t / 0.12) * 0.7
    return np.tanh((sub * 1.2 + crash + body) * 1.3) * big


def whoosh(length=0.6, rise=True):
    n = int(length * SR)
    t = np.linspace(0, 1, n)
    noise = _rng.standard_normal(n)
    out = np.zeros(n)
    k = 16
    for i in range(k):
        a, b = i * n // k, (i + 1) * n // k
        u = i / k if rise else 1 - i / k
        fc = 500 * 12 ** u
        out[a:b] = bp(noise[a:b], fc * 0.5, fc * 1.5)
    return out * np.sin(np.pi * t) ** 1.5 * 0.8


def ping(freq=1760, length=1.4):
    n = int(length * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2.01 * t)) * np.exp(-t / 0.35) * 0.3


# ---------------------------------------------------------------- pistes
def pad_track():
    out = np.zeros((N, 2))
    xf = int(0.08 * SR)
    for bar in range(20):
        t0 = bar * BAR_S
        n = int(BAR_S * SR) + xf
        voice = np.zeros((n, 2))
        notes = PROG[bar % 4] + (PROG[bar % 4][0] + 12,)
        for k, m in enumerate(notes):
            for det, side in ((-0.09, 0), (0.0, None), (0.09, 1)):
                s = saw(midi(m + det), n, phase=_rng.random())
                if side is None:
                    voice += s[:, None] * 0.5
                else:
                    voice[:, side] += s * 0.7
        e = np.ones(n)
        e[:xf] = np.linspace(0, 1, xf)
        e[-xf:] = np.linspace(1, 0, xf)
        place(out, voice * e[:, None] * 0.05, t0 - (xf / SR if bar else 0))
    tt = np.arange(N) / SR
    # filtre qui s'ouvre pendant l'intro et le pont, puis fermé en fin
    cut = section_gain(tt, [(0, 300), (3.9, 2600), (4, 1800), (20, 1600), (23.8, 4200), (24, 2200), (36, 2800), (40, 900)])
    blocks = 200
    res = np.zeros_like(out)
    for i in range(blocks):
        a, b = i * N // blocks, (i + 1) * N // blocks
        pad = int(0.05 * SR)
        a0 = max(0, a - pad)
        seg = lp(out[a0:b], cut[(a + b) // 2], 2)
        res[a:b] = seg[a - a0:]
    g = section_gain(tt, [(0, 0.0), (1.0, 0.7), (4, 0.8), (20, 1.0), (24, 0.75), (30, 0.6), (36, 1.0), (39.5, 0.0), (40, 0)])
    return res * g[:, None]


def bass_track():
    out = np.zeros((N, 2))
    for bar in range(20):
        t_bar = bar * BAR_S
        root = ROOTS[bar % 4]
        in_drop = 4 <= t_bar < 20 or 24 <= t_bar < 36
        bridge = 20 <= t_bar < 24
        if t_bar < 4 or t_bar >= 36 and t_bar != 36:
            continue
        if t_bar == 36:
            n = int(3.6 * SR)
            t = np.arange(n) / SR
            s = np.sin(2 * np.pi * midi(root - 12) * t) * np.exp(-t / 1.2)
            place(out, s * 0.55, t_bar)
            continue
        for e8 in range(8):
            if bridge and e8 % 2 == 0:
                continue
            t = t_bar + e8 * BEAT_S / 2 + (BEAT_S / 4 if in_drop and e8 % 2 == 0 else 0)
            if in_drop and e8 % 2 == 0:
                continue  # le kick occupe le temps, la basse joue les contretemps
            n = int(0.22 * SR)
            tt = np.arange(n) / SR
            f0 = midi(root - 12)
            s = np.sin(2 * np.pi * f0 * tt) * 0.8 + lp(saw(f0 * 2, n), 900) * 0.35
            e = np.minimum(1, tt / 0.004) * np.exp(-tt / 0.11)
            place(out, s * e * (0.5 if bridge else 0.62), t)
    return out


def arp_track():
    out = np.zeros((N, 2))
    pattern = (0, 1, 2, 3, 2, 1, 0, 2, 1, 3, 2, 1, 0, 1, 3, 2)
    for bar in range(18):
        t_bar = bar * BAR_S
        if bar == 0:
            continue
        notes = PROG[bar % 4]
        tones = [notes[0] + 12, notes[1] + 12, notes[2] + 12, notes[0] + 24]
        drop2 = 12 <= bar < 15
        for s16 in range(16):
            t = t_bar + s16 * BEAT_S / 4
            if 30 <= t < 36:
                continue
            m = tones[pattern[s16]] + (12 if drop2 and s16 % 4 == 3 else 0)
            bright = 1800 if t < 4 else 5200 if t >= 24 else 3600
            vel = 0.16 * (0.75 + 0.25 * (s16 % 4 == 0))
            pan = 0.35 if s16 % 2 else -0.35
            place(out, pluck(midi(m), bright=bright) * vel, t, pan=pan)
    # écho ping-pong 3/16
    d = int(0.375 * SR)
    echo = np.zeros_like(out)
    src = out.copy()
    for k in range(1, 5):
        g = 0.38 ** k
        sh = np.zeros_like(out)
        sh[d * k:] = src[:-d * k]
        if k % 2:
            sh = sh[:, ::-1]
        echo += sh * g
    return out + lp(echo, 3500)


def drums_track():
    kicks, out = [], np.zeros((N, 2))
    for b in range(80):
        t = b * BEAT_S
        drop = 4 <= t < 20 or 24 <= t < 30
        words = 30 <= t < 36
        if drop or words:
            place(out, kick(0.95), t)
            kicks.append(t)
            if b % 2 == 1:
                place(out, clap(), t, 0.55)
        elif t < 4:
            # battement du point rouge : kick feutré
            place(out, lp(kick(0.5, punch=0.4), 220), t)
            kicks.append(t)
        elif 20 <= t < 24 and b % 2 == 0:
            place(out, lp(kick(0.45, punch=0.5), 400), t)
        for h in range(4):
            th = t + h * BEAT_S / 4
            if drop and not (b == 79):
                if h == 2:
                    place(out, hat(True), th, 0.6, pan=0.2)
                else:
                    place(out, hat(), th, 0.55 if h % 2 else 0.35, pan=-0.25)
            elif 20 <= t < 24 and h % 2 == 1:
                place(out, hat(), th, 0.3, pan=-0.2)
    # roulement de caisse avant le drop 2
    for k in range(16):
        t = 23.0 + k * (1.0 / 16)
        place(out, clap(), t, 0.15 + 0.4 * k / 16)
    return out, np.array(kicks)


def sidechain(kicks, depth=0.55, release=0.16):
    tt = np.arange(N) / SR
    g = np.ones(N)
    for k in kicks:
        i = int(k * SR)
        n = int(0.6 * SR)
        seg = 1 - depth * np.exp(-np.arange(n) / SR / release)
        j = min(N, i + n)
        g[i:j] = np.minimum(g[i:j], seg[: j - i])
    return g


def sfx_track():
    out = np.zeros((N, 2))
    # intro : moteurs prêts, montée des points du logo, riser
    for _, t0 in (("yt-dlp", 20), ("gallery-dl", 32), ("aria2c", 44), ("ffmpeg", 56)):
        place(out, blip(2400, 0.06, 0.012), fr(t0), 0.12, pan=-0.5)
        place(out, blip(midi(81), 0.25, 0.06), fr(t0 + 8), 0.16, pan=-0.4)
    for k in range(40):
        place(out, blip(midi(84 + (k % 7) * 2), 0.12, 0.02, "sq"), fr(48 + k * 1.1), 0.03 + 0.03 * k / 40,
              pan=np.sin(k) * 0.6)
    place(out, riser(2.0), 2.0, 0.42)
    # impacts
    for f in tl.DROPS:
        place(out, impact(1.0), fr(f), 0.9)
    # transitions
    for f in tl.CUTS:
        place(out, whoosh(0.7, rise=True), fr(f) - 0.45, 0.55, pan=-0.3)
    # annotations du téléphone + tap
    for k, f in enumerate((255, 285, 315, 345)):
        place(out, blip(midi(76 + (0, 3, 7, 12)[k]), 0.4, 0.09), fr(f), 0.18, pan=0.3 * (-1) ** k)
        place(out, blip(3200, 0.05, 0.006), fr(f), 0.08)
    place(out, blip(260, 0.12, 0.02) + hp(_rng.standard_normal(int(0.12 * SR)), 2000) * np.exp(-np.arange(int(0.12 * SR)) / SR / 0.01) * 0.3,
          fr(375), 0.5)
    place(out, ping(midi(88), 1.6), fr(375), 0.35)
    # chaîne yt-dlp → aria2c → ffmpeg → fichier
    for k, f in enumerate((450, 465, 480, 495)):
        place(out, blip(midi(69 + (0, 4, 7, 12)[k]), 0.5, 0.12, "sq"), fr(f), 0.07)
        place(out, blip(midi(81 + (0, 4, 7, 12)[k]), 0.3, 0.05), fr(f), 0.12)
    # compteur : grésillement de données qui accélère
    for k in range(120):
        f = 440 + 120 * (k / 120) ** 0.8
        place(out, blip(5000 + 1500 * (k % 3), 0.02, 0.003), fr(f), 0.05, pan=0.5)
    for m, dt in ((84, 0), (88, 0.08), (91, 0.16), (96, 0.24)):
        place(out, ping(midi(m), 1.5), fr(560) + dt, 0.3)
    # pont : sonar à chaque mesure, paquets
    for b in range(4):
        place(out, ping(midi(76), 2.0), fr(600) + b * 1.0, 0.18, pan=-0.4)
    for k in range(30):
        place(out, blip(midi(88 + (k % 5)), 0.08, 0.015), fr(614) + k * 0.115, 0.04, pan=-0.6 + 1.2 * (k % 10) / 10)
    place(out, riser(1.6, 400, 9000), 22.4, 0.5)
    # carrousel : chaque cran
    for f in (750, 780, 810, 840, 870):
        place(out, whoosh(0.35, rise=False), fr(f) - 0.05, 0.35, pan=0.5)
        place(out, blip(1800, 0.05, 0.008), fr(f + 4), 0.15)
    # cartes typographiques : coup par temps
    for k, f in enumerate(tl.WORD_HITS[:8]):
        place(out, hp(_rng.standard_normal(int(0.15 * SR)), 1500) * np.exp(-np.arange(int(0.15 * SR)) / SR / 0.03), fr(f), 0.22)
        place(out, blip(midi(64 + (k % 4) * 3), 0.3, 0.06, "sq"), fr(f), 0.05)
    # mur d'écrans : nappe montante
    place(out, riser(1.6, 200, 4000), fr(1020), 0.3)
    # point final : logo + frappe du lien
    for k in range(31):
        place(out, blip(4200, 0.015, 0.002), fr(1130 + k / 1.6), 0.06, pan=0.2)
    for m, dt in ((69, 0), (76, 0.02), (81, 0.04), (84, 0.06)):
        place(out, ping(midi(m), 3.0), fr(1080) + dt, 0.22)
    return out


# ---------------------------------------------------------------- effets globaux sur la musique
def stutter(x):
    """Répète des tranches de 1/16 sur les images de glitch."""
    y = x.copy()
    for f in tl.STUTTER:
        t = fr(f)
        i = int(t * SR)
        sl = int(SR * BEAT_S / 8)
        src = x[i - sl:i]
        for r in range(3):
            a = i + r * sl
            y[a:a + sl] = src * (1 - 0.15 * r)
    return y


def tape_stop(x):
    a, b = int(fr(tl.TAPE_STOP[0]) * SR), int(fr(tl.TAPE_STOP[1]) * SR)
    n = b - a
    rate = np.linspace(1, 0, n) ** 1.3
    pos = a + np.cumsum(rate)
    idx = np.clip(pos, 0, len(x) - 2)
    i0 = idx.astype(int)
    fr_ = (idx - i0)[:, None]
    seg = x[i0] * (1 - fr_) + x[i0 + 1] * fr_
    y = x.copy()
    y[a:b] = seg * np.linspace(1, 0.0, n)[:, None] ** 0.5
    return y


def build() -> np.ndarray:
    drums, kicks = drums_track()
    sc = sidechain(kicks)[:, None]
    music = pad_track() * sc + bass_track() * sc + arp_track() * (0.6 + 0.4 * sc)
    music = music + reverb(music * 0.25) * 0.35
    beat = drums + reverb(drums * 0.12) * 0.25
    bus = music + beat
    bus = tape_stop(stutter(bus))
    # silence net juste avant l'impact final
    a = int(fr(tl.TAPE_STOP[1]) * SR)
    bus[a:a + int(0.02 * SR)] *= np.linspace(1, 0, int(0.02 * SR))[:, None]
    fx = sfx_track()
    fx = fx + reverb(fx * 0.3) * 0.5
    mix = bus * 0.9 + fx
    mix = hp(mix, 28)
    mix = np.tanh(mix * 1.2) / 1.2
    fade = np.ones(N)
    fade[-int(1.2 * SR):] = np.linspace(1, 0, int(1.2 * SR)) ** 2
    return (mix * fade[:, None]).astype(np.float32)


def write_wav(path: Path, x: np.ndarray):
    import wave
    path.parent.mkdir(parents=True, exist_ok=True)
    pk = np.abs(x).max()
    y = (x / max(pk, 1e-9) * 0.89 * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(y.tobytes())
    return path


if __name__ == "__main__":
    print(write_wav(OUT / "music.wav", build()))
    sys.exit(0)
