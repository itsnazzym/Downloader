import numpy as np

from light import beats as B, film


def test_film_lasts_31_5_seconds_and_sections_tile_it():
    assert B.FRAMES == 945
    ends = [(a, b) for _, a, b in film.SECTIONS]
    assert ends[0][0] == 0 and abs(ends[-1][1] - B.DUR) < 1e-9
    assert all(abs(x[1] - y[0]) < 1e-9 for x, y in zip(ends, ends[1:]))


def test_every_scheduled_event_sits_on_a_detected_hit():
    t, _ = B.hits()
    for _, a, b in film.SECTIONS[1:-1]:
        for e in film.pick(a, b, 6, 0.3):
            assert np.min(np.abs(t - e)) < 1e-6


def test_hits_are_on_the_sixteenth_grid_from_the_drop():
    t, _ = B.hits()
    k = (t - B.drop()) / B.S16
    assert np.allclose(k, np.round(k), atol=1e-6)
