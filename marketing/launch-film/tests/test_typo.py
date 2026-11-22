import numpy as np, pytest
from film.config import COPY
from film.typo import text_layer, kinetic, COPY_SIZES

@pytest.mark.parametrize("key", list(COPY))
def test_copy_fits_safe_area(key):
    t = text_layer(COPY[key], COPY_SIZES[key], "black" if key != "tagline" else "medium")
    h, w = t.shape[:2]
    assert t[..., 3].max() == 255
    assert w <= 1824 - 96 and h <= COPY_SIZES[key] * 1.6

def test_kinetic_end_state_inside_safe():
    a = kinetic(COPY["send"].split(), 60, COPY_SIZES["send"])[..., 3]
    ys, xs = np.nonzero(a)
    assert xs.min() >= 96 and xs.max() <= 1824 and ys.min() >= 54 and ys.max() <= 1026

def test_kinetic_starts_hidden():
    assert kinetic(COPY["share"].split(), 0, 150)[..., 3].max() == 0
