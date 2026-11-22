"""Lit musical : estimation du tempo, calage sur la grille de 120 BPM, montage des impacts.

    python -m film.music SRC DST    → cale SRC sur 120 BPM puis le monte : 1er impact (1,5 s)
                                       décalé à 3,5 s (f105), retour au morceau à 5,5 s (sur la mesure)
"""
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from scipy.io import wavfile

SR = 48000
HIT_SRC, HIT_DST, REJOIN = 1.5, 3.5, 5.5   # montage du lit (voir ledger, Task 7)


def _read(path: Path) -> np.ndarray:
    path = Path(path)
    if path.suffix.lower() != ".wav":
        tmp = Path(tempfile.mkdtemp()) / "in.wav"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(path), "-ac", "2", "-ar", str(SR), str(tmp)], check=True)
        path = tmp
    sr, y = wavfile.read(path)
    y = y.astype(np.float32)
    if y.dtype != np.float32 or np.abs(y).max() > 1.5:
        y /= 32768.0
    if y.ndim == 1:
        y = np.stack([y, y], 1)
    if sr != SR:
        raise ValueError(f"sample rate {sr}")
    return y


def _write(path: Path, y: np.ndarray) -> None:
    wavfile.write(path, SR, np.clip(y, -1, 1).astype(np.float32))


def _onset_env(x: np.ndarray, hop: int = 256, win: int = 1024) -> np.ndarray:
    n = (len(x) - win) // hop
    frames = np.lib.stride_tricks.sliding_window_view(x, win)[::hop][:n] * np.hanning(win)
    mag = np.abs(np.fft.rfft(frames, axis=1))
    flux = np.maximum(np.diff(np.log1p(mag * 10), axis=0), 0).sum(axis=1)
    return np.concatenate([[0], flux])


def estimate_tempo(x: np.ndarray, hop: int = 256) -> float:
    env = _onset_env(x, hop)
    env = env - env.mean()
    ac = np.correlate(env, env, "full")[len(env) - 1:]
    fps = SR / hop
    lags = np.arange(len(ac))
    bpm = np.full(len(ac), np.nan)
    bpm[1:] = 60 * fps / lags[1:]
    ok = (bpm >= 80) & (bpm <= 160)
    i = np.argmax(np.where(ok, ac, -np.inf))
    # affinage parabolique
    if 1 <= i < len(ac) - 1:
        a, b, c = ac[i - 1], ac[i], ac[i + 1]
        i = i + 0.5 * (a - c) / (a - 2 * b + c + 1e-12)
    return 60 * fps / i


def _beat_phase(x: np.ndarray, bpm: float, hop: int = 256) -> float:
    env = _onset_env(x, hop)
    fps = SR / hop
    period = 60 / bpm
    best, best_off = -1, 0.0
    for off in np.arange(0, period, 0.002):
        idx = ((off + np.arange(0, len(env) / fps - off, period)) * fps).astype(int)
        idx = idx[idx < len(env)]
        s = env[idx].sum()
        if s > best:
            best, best_off = s, off
    return best_off


def _fit(y: np.ndarray, duration: float) -> np.ndarray:
    n = int(round(duration * SR))
    if len(y) >= n:
        y = y[:n].copy()
    else:
        y = np.concatenate([y, np.zeros((n - len(y), 2), np.float32)])
    fade = int(0.3 * SR)
    y[-fade:] *= np.linspace(1, 0, fade)[:, None]
    return y


def align_music(src: Path, dst: Path, bpm: float = 120, duration: float = 30.0) -> dict:
    y = _read(src)
    tempo = estimate_tempo(y.mean(1))
    stretched = abs(tempo - bpm) > 1.0
    if stretched:
        tmp_in = Path(tempfile.mkdtemp()) / "a.wav"
        tmp_out = tmp_in.with_name("b.wav")
        _write(tmp_in, y)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(tmp_in), "-filter:a",
                        f"atempo={bpm / tempo:.6f}", str(tmp_out)], check=True)
        y = _read(tmp_out)
    off = _beat_phase(y.mean(1), bpm)
    period = 60.0 / bpm
    if off > period / 2:          # phase la plus proche : un léger retard plutôt qu'un temps coupé
        off -= period
    k = int(round(off * SR))
    y = y[k:] if k >= 0 else np.concatenate([np.zeros((-k, 2), np.float32), y])
    _write(dst, _fit(y, duration))
    return {"tempo_in": float(tempo), "offset_s": float(off), "stretched": stretched}


def splice_bed(src: Path, dst: Path, hit_src: float, hit_dst: float, rejoin: float,
               duration: float = 30.0, xfade: float = 0.02) -> None:
    """Retarde la musique pour que son 1er impact (hit_src) tombe à hit_dst, puis, à `rejoin`,
    revient à la musique non décalée (raccord sur une barre de mesure, fondu de 20 ms)."""
    y = _read(src)
    n = int(round(duration * SR))
    d = int(round((hit_dst - hit_src) * SR))
    early = np.zeros((n, 2), np.float32)
    early[d:] = y[: n - d] if len(y) >= n - d else np.pad(y, ((0, n - d - len(y)), (0, 0)))
    late = y[:n] if len(y) >= n else np.pad(y, ((0, n - len(y)), (0, 0)))
    r = int(round(rejoin * SR))
    x = int(round(xfade * SR))
    w = np.zeros(n, np.float32)
    w[r:] = 1
    w[r - x:r] = np.linspace(0, 1, x)
    out = early * (1 - w)[:, None] + late * w[:, None]
    _write(dst, _fit(out, duration))


def build_bed(src: Path, dst: Path) -> dict:
    aligned = Path(tempfile.mkdtemp()) / "aligned.wav"
    info = align_music(src, aligned)
    splice_bed(aligned, dst, hit_src=HIT_SRC, hit_dst=HIT_DST, rejoin=REJOIN)
    return info


if __name__ == "__main__":
    print(build_bed(Path(sys.argv[1]), Path(sys.argv[2])))
