import numpy as np

from reel import music, timeline as tl


def _rms(x):
    return float(np.sqrt((x ** 2).mean()) + 1e-12)


def test_mix_is_40_seconds_stereo_and_finite():
    x = music.build()
    assert x.shape == (music.N, 2) and np.isfinite(x).all()


def test_drops_hit_harder_than_the_beat_before_them():
    x = music.build()
    sr = music.SR
    for f in tl.DROPS:
        t = int(f / tl.FPS * sr)
        before = _rms(x[t - sr // 4:t - sr // 20])
        after = _rms(x[t:t + sr // 4])
        assert after > 1.8 * before, (f, before, after)


def test_tape_stop_ends_in_near_silence_before_final_impact():
    x = music.build()
    t = int(tl.TAPE_STOP[1] / tl.FPS * music.SR)
    assert _rms(x[t - 2400:t]) < 0.02
