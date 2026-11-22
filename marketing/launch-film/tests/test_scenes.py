import numpy as np, pytest
from film.scenes import REGISTRY
from film.scenes.s3_browse import counter_value
from film.scenes.stage import place_phone, compose_phone
from film.assets import load_screen

@pytest.mark.parametrize("name,f", [("s2", 0), ("s2", 105), ("s2", 209), ("s3", 0), ("s3", 150), ("s4", 30), ("s4", 180)])
def test_scene_frames_valid(name, f):
    img = REGISTRY[name](f)
    assert img.shape == (1080, 1920, 3) and img.dtype == np.float32 and np.isfinite(img).all()
    assert 0 <= img.min() and img.max() <= 1

def test_phone_visible_after_slam():
    img = REGISTRY["s2"](60)          # f global 180, après l'impact de 165
    reg = img[100:1000, 700:1220]
    assert (reg.max(axis=2) > 0.6).sum() > 3000   # le texte blanc de l'écran est visible

def test_counter_reaches_1800():
    assert counter_value(55) == 1800 and counter_value(0) == 0
    assert all(counter_value(f) <= counter_value(f + 1) for f in range(74))

def test_place_phone_rotation_narrows():
    ph = compose_phone(load_screen("send"), 800)
    flat = place_phone(np.zeros((1080, 1920, 3), np.float32), ph, 960, 540, 1.0)
    turned = place_phone(np.zeros((1080, 1920, 3), np.float32), ph, 960, 540, 1.0, rot_y_deg=35)
    w = lambda im: np.ptp(np.nonzero(im.max(axis=(0, 2)) > 0.02)[0])
    assert w(turned) < w(flat)

@pytest.mark.parametrize("cy", [-600, -455, 1500])
def test_place_phone_mostly_offscreen_does_not_crash(cy):
    ph = compose_phone(load_screen("send"), 880)
    img = place_phone(np.zeros((1080, 1920, 3), np.float32), ph, 960, cy, 1.0, rot_z_deg=-6)
    assert img.shape == (1080, 1920, 3) and np.isfinite(img).all()

def test_s2_drop_in_frames_render():
    for f in (42, 42.5, 43, 44):
        assert REGISTRY["s2"](f).shape == (1080, 1920, 3)

def test_counter_held_settled_then_gone_before_phone():
    from film.scenes.s3_browse import counter_alpha, IMPACT
    held = [f for f in range(80) if counter_value(f) == 1800 and counter_alpha(f) == 1.0]
    assert len(held) >= 12
    assert counter_alpha(IMPACT - 2) == 0.0

def test_taps_have_sound():
    from film.timeline import CUES
    from film.scenes import s2_share, s3_browse
    taps = {c.frame for c in CUES if c.kind == "tap"}
    ripples = {s2_share.G0 + t for t in s2_share.TAPS} | {s3_browse.G0 + s3_browse.TAP}
    assert ripples <= taps

def test_s2_single_tap():
    from film.scenes import s2_share
    assert len(s2_share.TAPS) == 1
