import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import numpy as _np
from scipy.io import wavfile as _wav


def make_click_track(path, bpm, offset, seconds, sr=48000):
    n = int(seconds * sr)
    y = _np.zeros(n, _np.float32)
    period = 60.0 / bpm
    click = (_np.sin(2 * _np.pi * 1000 * _np.arange(480) / sr) * _np.exp(-_np.arange(480) / 80)).astype(_np.float32)
    t = offset
    while t < seconds - 0.02:
        i = int(t * sr)
        y[i:i + 480] += click
        t += period
    _wav.write(str(path), sr, _np.stack([y, y], 1))
    return path
