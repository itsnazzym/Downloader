"""SFX procéduraux calés sur la table de cues, mixage avec la musique (ducking), master à −14 LUFS.

    python -m film.audio            → out/master.wav
"""
import json
import re
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sawtooth, sosfilt

from . import config
from .timeline import CUES, Cue

SR = 48000
SPF = SR // config.FPS  # 1600 échantillons par image
LEVEL = {"impact": 0.95, "riser": 0.30, "whoosh": 0.45, "tap": 0.35, "tick": 0.16,
         "glitch": 0.28, "swell": 0.28}


def _rng(seed: int):
    return np.random.default_rng(seed)


def _bp(x, lo, hi):
    return sosfilt(butter(2, [lo, hi], "bandpass", fs=SR, output="sos"), x)


def _lp(x, hz, order=2):
    return sosfilt(butter(order, hz, "lowpass", fs=SR, output="sos"), x)


def _hp(x, hz, order=2):
    return sosfilt(butter(order, hz, "highpass", fs=SR, output="sos"), x)


def _norm(x):
    m = np.abs(x).max()
    return x / m if m > 0 else x


def _impact():
    n = int(1.8 * SR)
    t = np.arange(n) / SR
    f = 38 + (90 - 38) * np.exp(-t / 0.18)
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.5)
    sub = np.tanh(2.2 * sub) * 0.8
    r = _rng(1)
    trans = _hp(r.standard_normal(n), 2000) * np.exp(-t / 0.008) * 0.6
    tails = []
    for s in (2, 3):
        tail = _lp(_rng(s).standard_normal(n), 800) * np.exp(-t / 0.35)
        tails.append(tail / (np.abs(tail).max() + 1e-9) * 0.35)
    L = sub + trans + tails[0]
    R = sub + trans + tails[1]
    x = np.stack([L, R], 1)
    return _norm(x), 0


def _riser(length):
    n = max(int(length * SPF), SR // 4)
    t = np.arange(n) / SR
    T = n / SR
    u = t / T
    r = _rng(4)
    noise = r.standard_normal(n)
    bands = np.geomspace(300, 6000, 9)
    out = np.zeros(n)
    centre = np.log(300) + (np.log(6000) - np.log(300)) * u
    for i in range(len(bands) - 1):
        b = _bp(noise, bands[i], bands[i + 1])
        c = np.log(np.sqrt(bands[i] * bands[i + 1]))
        out += b * np.exp(-((centre - c) / 0.45) ** 2)
    f = 110 * 2 ** u
    saw = sawtooth(2 * np.pi * np.cumsum(f) / SR) * 0.25
    x = (_norm(out) + _lp(saw, 3000)) * u ** 3
    st = np.stack([x, np.roll(x, 37)], 1)
    return _norm(st), n - 1


def _whoosh():
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    u = t / t[-1]
    noise = _rng(5).standard_normal(n)
    lo = _bp(noise, 400, 1200)
    hi = _bp(noise, 1200, 3000)
    mix = lo * (1 - np.sin(np.pi * u)) + hi * np.sin(np.pi * u)
    env = np.sin(np.pi * u) ** 2
    x = _norm(mix * env)
    pan = u
    return np.stack([x * np.cos(pan * np.pi / 2), x * np.sin(pan * np.pi / 2)], 1) * 1.3, n // 2


def _tap():
    n = int(0.05 * SR)
    t = np.arange(n) / SR
    click = np.sin(2 * np.pi * 2200 * t) * np.exp(-t / 0.0025) * (t < 0.008)
    body = np.sin(2 * np.pi * 180 * t) * np.exp(-t / 0.012)
    x = _norm(click * 0.8 + body * 0.7)
    return np.stack([x, x], 1), int(0.001 * SR)


def _tick():
    n = int(0.006 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 4000 * t) * np.exp(-t / 0.0012)
    x = _norm(x)
    return np.stack([x, x], 1), 0


def _glitch():
    n = int(0.2 * SR)
    x = np.zeros(n)
    r = _rng(6)
    for k in range(3):
        a = int((k * 0.07) * SR)
        b = a + int(0.03 * SR)
        burst = r.standard_normal(b - a)
        burst = np.round(burst * 7) / 7                      # 4 bits environ
        burst = np.repeat(burst[::8], 8)[: b - a]            # ~6 kHz
        x[a:b] = burst * (0.6 + 0.4 * r.random())
    x = _norm(x)
    return np.stack([x, np.roll(x, 120)], 1), 0


def _swell(length):
    n = max(int(length * SPF), SR // 4)
    t = np.arange(n) / SR
    noise = _rng(7).standard_normal(n)
    rev = _lp(noise, 2500) * np.exp(-t / 0.6)
    x = rev[::-1]
    x = _norm(x)
    st = np.stack([x, np.roll(x, 211)], 1)
    return st, n - 1


def sfx(kind: str, length: int = 0, sr: int = SR):
    if kind == "impact":
        x, p = _impact()
    elif kind == "riser":
        x, p = _riser(length or 60)
    elif kind == "whoosh":
        x, p = _whoosh()
    elif kind == "tap":
        x, p = _tap()
    elif kind == "tick":
        x, p = _tick()
    elif kind == "glitch":
        x, p = _glitch()
    elif kind == "swell":
        x, p = _swell(length or 60)
    else:
        raise ValueError(kind)
    return x.astype(np.float32), int(p)


def build_sfx_track(cues=CUES, sr: int = SR, total: int = config.TOTAL) -> np.ndarray:
    n = total * SPF
    out = np.zeros((n, 2), np.float32)
    for c in cues:
        x, peak = sfx(c.kind, c.length)
        g = LEVEL[c.kind] * 10 ** (c.gain_db / 20)
        start = c.frame * SPF - peak
        a, b = max(start, 0), min(start + len(x), n)
        if b > a:
            out[a:b] += x[a - start:b - start] * g
    return out


def duck_env(cues=CUES, sr: int = SR, depth_db: float = -6.0, release_s: float = 0.35) -> np.ndarray:
    n = config.TOTAL * SPF
    e = np.ones(n, np.float32)
    depth = 10 ** (depth_db / 20)
    for c in cues:
        if c.kind != "impact":
            continue
        s = c.frame * SPF
        att = int(0.005 * SR)
        rel = np.arange(int(release_s * 4 * SR))
        curve = 1 - (1 - depth) * np.exp(-rel / (release_s * SR))
        a = max(s - att, 0)
        e[a:s] = np.minimum(e[a:s], np.linspace(1, depth, s - a))
        b = min(s + len(curve), n)
        e[s:b] = np.minimum(e[s:b], curve[: b - s])
    return e


def measure(path: Path) -> tuple[float, float]:
    """(loudness intégrée LUFS, true peak dBTP) via le filtre ebur128 de ffmpeg."""
    r = subprocess.run(["ffmpeg", "-nostats", "-i", str(path), "-af", "ebur128=peak=true", "-f", "null", "-"],
                       capture_output=True, text=True)
    summ = r.stderr[r.stderr.rfind("Summary:"):]
    I = float(re.search(r"I:\s+(-?[\d.]+) LUFS", summ).group(1))
    TP = float(re.search(r"True peak:\s+Peak:\s+(-?[\d.]+) dBFS", summ).group(1))
    return I, TP


def master(out: Path, music: Path | None = config.ASSETS / "audio" / "music_120.wav",
           limit: float | None = 0.25, target_i: float = -14.0) -> dict:
    sfx_track = build_sfx_track()
    mix = sfx_track * 0.9
    if music is not None and Path(music).exists():
        sr, m = wavfile.read(music)
        m = m.astype(np.float32)
        if np.abs(m).max() > 1.5:
            m /= 32768
        m = m[: len(mix)]
        mix[: len(m)] += m * duck_env()[: len(m), None]
    tmpdir = Path(tempfile.mkdtemp())
    raw = tmpdir / "raw.wav"
    peak = np.abs(mix).max()
    wavfile.write(raw, SR, (mix / max(peak, 1e-9) * 0.5).astype(np.float32))
    if limit:  # limiteur crête : écrête les transitoires pour gagner du niveau perçu
        lim = tmpdir / "lim.wav"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(raw), "-af",
                        f"alimiter=limit={limit}:attack=1:release=40:level=disabled", "-c:a", "pcm_f32le", str(lim)], check=True)
        raw = lim
    target = f"I={target_i}:TP=-3.2:LRA=11"
    r = subprocess.run(["ffmpeg", "-nostats", "-i", str(raw), "-af", f"loudnorm={target}:print_format=json",
                        "-f", "null", "-"], capture_output=True, text=True)
    js = json.loads(r.stderr[r.stderr.rfind("{"):])
    lin = (f"loudnorm={target}:measured_I={js['input_i']}:measured_TP={js['input_tp']}:"
           f"measured_LRA={js['input_lra']}:measured_thresh={js['input_thresh']}:"
           f"offset={js['target_offset']}:linear=true")
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(raw), "-af", lin, "-ar", str(SR),
                    "-c:a", "pcm_s24le", str(out)], check=True)
    I, TP = measure(out)
    return {"I": I, "TP": TP}


if __name__ == "__main__":
    print(master(config.MASTER))
