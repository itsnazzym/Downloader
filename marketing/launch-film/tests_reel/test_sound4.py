import numpy as np
import pytest
from scipy.signal import butter, sosfilt

from light import beats as B
from light import sound as v3
from light import sound4
from reel.assemble import loudness

SR = 48000
V3_MASTER = v3.OUT / "master.wav"
V4_MASTER = sound4.OUT / "master.wav"


@pytest.fixture(scope="module")
def masters():
    import librosa
    sound4.main()
    if not V3_MASTER.exists():
        v3.main()
    out = []
    for p in (V3_MASTER, V4_MASTER):
        y, _ = librosa.load(str(p), sr=SR, mono=True)
        out.append(y)
    return out  # (v3, v4)


def _band(x, lo, hi):
    return sosfilt(butter(4, (lo, hi), "band", fs=SR, output="sos"), x)


def _rms(x):
    return np.sqrt(np.mean(x ** 2))


def _level_db(x, lo, hi, path):
    """Niveau RMS (dB) de la bande lo-hi sur 4,2-30 s, ramené à -14 LUFS intégrés (égalité de sonie)."""
    a, b = int(4.2 * SR), int(30 * SR)
    i, _ = loudness(path)
    return 20 * np.log10(_rms(_band(x, lo, hi)[a:b])) + (-14.0 - i)


def test_kicks_are_on_the_grid_and_dense_after_drop():
    k = sound4.kicks()
    r = (k - B.drop()) / B.S16
    assert np.allclose(r, np.round(r), atol=1e-6)
    bar = B.PHRASE / 2
    d = B.drop()
    for i in range(int((B.MUSIC_LEN - d) // bar)):
        n = ((k >= d + i * bar) & (k < d + (i + 1) * bar)).sum()
        assert n >= 2, (i, n)


def test_mastered_low_end_is_stronger_than_v3(masters):
    v3m, v4m = masters
    # +2,0 dB (au lieu de +2,5) depuis la v7 : les souffles de transition ajoutent de la sonie large bande,
    # ce qui, à sonie intégrée égale, retire ~0,35 dB à la bande 40-120 Hz.
    assert _level_db(v4m, 40, 120, V4_MASTER) >= _level_db(v3m, 40, 120, V3_MASTER) + 2.0


def test_mastered_mix_is_not_duller_than_v3(masters):
    v3m, v4m = masters
    assert _level_db(v4m, 500, 16000, V4_MASTER) >= _level_db(v3m, 500, 16000, V3_MASTER) - 1.5


def test_mastered_kick_transients_are_punchier(masters):
    def crest(x):
        l = _band(x, 40, 120)
        w = int(0.06 * SR)
        c = []
        for t in sound4.kicks():
            s = l[int(t * SR):int(t * SR) + w]
            if len(s) == w:
                c.append(np.abs(s).max() / (np.sqrt(np.mean(s ** 2)) + 1e-9))
        return np.mean(c)
    assert crest(masters[1]) >= 1.15 * crest(masters[0])


def test_master_level(masters):
    i, tp = loudness(V4_MASTER)
    assert -14.7 <= i <= -13.3 and tp <= -1.0, (i, tp)


def test_no_flat_clipping_before_the_limiter(tmp_path):
    """Le fichier envoyé au limiteur ne contient aucun écrêtage dur : pas de plateau de >= 3 échantillons égaux
    au maximum (le float WAV peut dépasser 1,0)."""
    from scipy.io import wavfile
    seen = {}
    real = wavfile.write

    def spy(path, sr, data):
        if str(path).endswith("c.wav"):
            seen["x"] = np.array(data, copy=True)
        return real(path, sr, data)

    src = sound4.OUT / "mix.wav"
    assert src.exists()
    import unittest.mock as m
    with m.patch.object(wavfile, "write", spy):
        sound4.master(src, tmp_path / "m.wav")
    x = np.abs(seen["x"]).max(axis=1) if seen["x"].ndim == 2 else np.abs(seen["x"])
    mx = x.max()
    assert mx > 1.0, "le pic doit pouvoir dépasser 1,0 (pas d'écrêtage dur)"
    flat = (x >= mx - 1e-7).astype(np.int8)
    runs = np.convolve(flat, np.ones(3, np.int8), "valid")
    assert runs.max() < 3, "plateau d'écrêtage détecté"
