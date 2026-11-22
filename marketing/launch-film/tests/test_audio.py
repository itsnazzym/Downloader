import numpy as np
from film.audio import build_sfx_track, sfx, master, duck_env
from film.timeline import Cue, CUES

def test_track_length_and_finite():
    t = build_sfx_track(); assert t.shape == (30 * 48000, 2) and np.isfinite(t).all()

def test_impact_aligned():
    t = build_sfx_track([Cue(105, "impact")])
    assert abs(np.argmax(np.abs(t[:, 0])) - 105 * 1600) <= 1600

def test_riser_ends_at_cue():
    x, peak = sfx("riser", 90); assert abs(peak - len(x)) < 4800

def test_every_kind_renders():
    for k in ("riser", "impact", "whoosh", "tap", "tick", "glitch", "swell"):
        x, peak = sfx(k, 60); assert x.ndim == 2 and x.shape[1] == 2 and 0 <= peak < len(x) + 1 and np.isfinite(x).all()

def test_duck_dips_on_impacts():
    e = duck_env(CUES); assert e[105 * 1600 + 200] < 0.6 and e[10] == 1.0

import pytest
from film import config as _cfg

@pytest.mark.skipif(not (_cfg.ASSETS / "audio" / "music_120.wav").exists(), reason="lit musical absent (non versionné)")
def test_master_loudness(tmp_path):
    m = master(tmp_path / "m.wav")             # mix réel : SFX + musique
    assert -14.5 <= m["I"] <= -13.5 and m["TP"] <= -2.8   # niveau plateformes (≈ −14 LUFS), marge de pic avant AAC
