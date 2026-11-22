import pytest
from film.assemble import FINAL, probe, ebur128

pytestmark = pytest.mark.skipif(not FINAL.exists(), reason="film final pas encore assemblé")

def test_final_specs():
    p = probe(FINAL)
    v, a = p["video"], p["audio"]
    assert (v["width"], v["height"], v["r_frame_rate"]) == (1920, 1080, "30/1")
    assert v["nb_frames"] == 900 and abs(p["duration"] - 30.0) <= 0.05
    assert a["sample_rate"] == 48000 and a["channels"] == 2

def test_final_loudness():
    I, TP = ebur128(FINAL); assert -14.6 <= I <= -13.4 and TP <= -1.5
