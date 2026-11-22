"""L'appli s'appelle TapLoad partout dans le film (textes générés, captures retouchées, vignette de démo)."""
from pathlib import Path

import numpy as np
from PIL import Image

import light  # noqa: F401  (vidéo de démo = le film lui-même)
from film import assets, config
from film.typo import text_layer
from light import ui

ROOT = Path(__file__).resolve().parent.parent
OLD = "Modern Downloader"


def test_name_constants():
    assert config.COPY["name"] == "TapLoad" == ui.APP_NAME
    assert assets.SELF["title"] == "TapLoad — Présentation"


def test_no_rendered_string_contains_old_name():
    """Aucune chaîne affichée par le film ne contient l'ancien nom (seul film/localize.py le cite, comme
    texte à rechercher dans la capture brute)."""
    for rel in ("light/ui.py", "light/film4.py", "light/film.py", "film/assets.py", "film/config.py",
                "reel/sc_end.py"):
        assert OLD not in (ROOT / rel).read_text(), rel
    for v in assets.SELF.values():
        assert OLD not in v


def _ink_cols(a, thr=60):
    return np.nonzero((np.abs(a.astype(int) - np.median(a.reshape(-1, 3), 0)).max(2) > thr).any(0))[0]


def test_archive_capture_is_renamed():
    """14_archive : la ligne « Modern Downloader est installée… » est repeinte ; le nouveau début de ligne
    a la largeur de « TapLoad » et la ligne entière est plus courte que l'originale."""
    raw, new = assets.raw_screen("archive"), assets.load_screen("archive")
    y0, y1 = 1340, 1395
    assert np.abs(raw[y0:y1].astype(int) - new[y0:y1].astype(int)).max() > 100
    r, n = _ink_cols(raw[y0:y1, 100:1100]), _ink_cols(new[y0:y1, 100:1100])
    assert r.min() - 4 <= n.min() <= r.min() + 4                          # même marge gauche
    assert 150 < (r.max() - n.max()) < 300        # « Modern Downloader » (≈ 384 px) → « TapLoad » (≈ 170 px)
    # le reste de la capture n'a pas bougé au-dessus et en dessous
    assert np.array_equal(raw[1200:1330], new[1200:1330]) and np.array_equal(raw[1405:2280], new[1405:2280])


def test_demo_thumb_shows_new_wordmark():
    """La vignette de démo porte « TapLoad » : la largeur d'encre de la ligne du nom correspond à text_layer."""
    a = np.asarray(Image.open(ROOT / "assets" / "brand" / "demo-thumb.png").convert("RGB"))
    band = a[590:700]
    ink = np.nonzero((band.max(2) < 90).any(0))[0]
    lay = text_layer("TapLoad", 110, "black", -0.045, (0, 0, 0))
    w = np.nonzero((lay[..., 3] > 128).any(0))[0]
    assert abs((ink.max() - ink.min()) - (w.max() - w.min())) < 8
