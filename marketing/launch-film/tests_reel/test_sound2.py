import numpy as np
import pytest

from reel import sound2


@pytest.fixture(scope="module")
def edited():
    y = sound2.load_track()
    return sound2.edit(y)


def _jump(x, t, sr=48000):
    a = x[int((t - 0.3) * sr):int(t * sr)]
    b = x[int(t * sr):int((t + 0.3) * sr)]
    return np.sqrt((b ** 2).mean()) / np.sqrt((a ** 2).mean() + 1e-12)


def test_music_drops_land_on_the_picture_drops(edited):
    bed, info = edited
    y = sound2.load_track()
    # le drop retrouvé dans le montage tombe à moins de 15 ms de 4 s et de 24 s
    for t in (4.0, 24.0):
        found = sound2.find_drop(bed, t)
        assert abs(found - t) < 0.015, (t, found)
        assert _jump(bed.mean(1), t) > 2.5


def test_tempo_is_resampled_to_120_bpm():
    assert abs(sound2.SRC_BPM * float(sound2.RATIO) - 120) < 0.05
