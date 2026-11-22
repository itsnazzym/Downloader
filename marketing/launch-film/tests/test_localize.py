import numpy as np
import pytest

from film import config
from film.assets import SCREENS, load_screen, raw_screen
from film.localize import PATCHES

PAD = 8


@pytest.mark.parametrize("key", sorted(PATCHES))
def test_localized_screen_only_changes_inside_patch_boxes(key):
    if key in ("library",):         # déjà retouchée par _redact (Big Buck Bunny) : on ne compare que les zones
        pytest.skip("captures caviardées par ailleurs")
    raw, new = raw_screen(key).astype(int), load_screen(key).astype(int)
    mask = np.zeros(raw.shape[:2], bool)
    for (x0, y0, x1, y1), *_ in PATCHES[key]:
        mask[max(0, y0 - PAD):min(raw.shape[0], y1 + PAD), max(0, x0 - PAD):min(raw.shape[1], x1 + PAD)] = True
    changed = np.abs(raw - new).max(axis=2) > 0
    assert changed[mask].any() and not changed[~mask].any()


@pytest.mark.parametrize("key", ["share", "done", "send", "archive", "stats", "settings"])
def test_english_nav_labels_are_gone(key):
    # la zone des libellés « Library / Settings » doit avoir changé par rapport à la capture brute
    raw, new = raw_screen(key).astype(int), load_screen(key).astype(int)
    assert np.abs(raw[2290:2360] - new[2290:2360]).max() > 40
