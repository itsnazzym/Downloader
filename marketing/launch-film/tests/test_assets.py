import numpy as np, pytest
from film.assets import logo_grid, sample_logo_colors, SCREENS, load_screen, phone, raw_screen

def test_logo_grid_counts():
    g = logo_grid()
    assert len(g) == 59
    assert sum(d.state == "on" for d in g) == 17
    assert [(d.col, d.row) for d in g if d.state == "red"] == [(3, 6)]
    assert {d.col for d in g if d.row in (0, 8)} == {1, 2, 3, 4, 5}

def test_logo_colors_plausible():
    w, r, o = sample_logo_colors()
    assert min(w) > 220 and r[0] > 200 and r[1] < 110 and max(o) < 40

@pytest.mark.parametrize("key", SCREENS)
def test_screens_cropped_dark_bottom(key):
    s = load_screen(key)
    assert s.shape[1] == 1170 and s.shape[0] >= 2380 and s[-20:].mean() < 60

@pytest.mark.parametrize("key,box", [("capture", (504, 666, 92, 378)), ("browser", (900, 1400, 0, 1170)),
                                     ("library", (500, 560, 330, 1000))])
def test_redactions_applied(key, box):
    y0, y1, x0, x1 = box
    assert np.abs(load_screen(key)[y0:y1, x0:x1].astype(int) - raw_screen(key)[y0:y1, x0:x1].astype(int)).mean() > 5

def test_phone_alpha():
    p = phone(load_screen("send"), 900)
    assert p.shape[0] == 900 and p[0, 0, 3] == 0 and p[450, p.shape[1] // 2, 3] == 255

def test_browser_redaction_draws_no_invented_card():
    s = load_screen("browser")
    assert s[1720:1900, 48:1122].max() < 40      # pas de fausse carte « Vidéo détectée »
