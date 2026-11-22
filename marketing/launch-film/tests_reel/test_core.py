import numpy as np
import pytest

from reel import core


def test_led_font_covers_every_character_used_in_the_film():
    for text in core.LED_TEXTS:
        for ch in text:
            assert ch in core.FONT, ch
    assert all(len(g) == 7 and all(len(r) == 5 for r in g) for g in core.FONT.values())


def test_led_cells_width_and_on_count():
    cells = core.led_cells("A1")
    assert cells.shape[1] == 3 and cells[:, 0].max() == 10 and cells[:, 1].max() == 6
    assert cells[:, 2].sum() == sum(r.count("#") for ch in "A1" for r in core.FONT[ch])


def test_projection_centre_and_depth_scale():
    cam = core.Cam(f=1000)
    uv, z = cam.project(np.array([[0.0, 0, 1000], [100, 0, 1000], [100, 0, 2000]]))
    assert np.allclose(uv[0], (960, 540)) and np.allclose(uv[1], (1060, 540)) and np.allclose(uv[2], (1010, 540))


def test_phone_facing_camera_covers_centre_and_texture_maps_inside():
    img = np.zeros((core.H, core.W, 3), np.float32)
    info = core.draw_phone(img, "capture", pos=(0, 0, 1600), yaw=0, pitch=0, cam=core.Cam(f=1400))
    assert img[540, 960].sum() > 0 and info["front"]
    u, v = info["map"](585, 1194)  # centre de la capture
    assert abs(u - 960) < 3 and abs(v - 540) < 3


def test_phone_seen_from_behind_hides_screen():
    img = np.zeros((core.H, core.W, 3), np.float32)
    info = core.draw_phone(img, "capture", pos=(0, 0, 1600), yaw=180, pitch=0, cam=core.Cam(f=1400))
    assert not info["front"] and img.max() < 0.5


def test_finish_returns_uint8_frame():
    out = core.finish(np.full((core.H, core.W, 3), 0.5, np.float32), 10)
    assert out.dtype == np.uint8 and out.shape == (core.H, core.W, 3)
