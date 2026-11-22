"""Film v7 : transitions de section dessinées, flou de bougé, typographie cinétique (light/film4.py)."""
import numpy as np

import light  # noqa: F401  (vidéo de démo = le film lui-même)
from light import film, film4

DT = 1 / 60


def test_every_section_change_is_a_designed_transition_on_the_downbeat():
    """Une transition par changement de section, au moins 3 types différents ; le pic de vitesse (la coupe) tombe
    sur le premier temps de la phrase entrante, sauf la carte de fin qui s'y pose (fin du freinage)."""
    names = [n for n, _, _ in film.SECTIONS]
    assert [(tr.frm, tr.to) for tr in film4.TRANS] == list(zip(names, names[1:]))
    assert len({tr.kind for tr in film4.TRANS}) >= 3
    for tr in film4.TRANS:
        a = film4.SEC[tr.to][0]
        if tr.cut < a:
            assert abs(tr.cut + tr.d_in - a) < 1e-9, tr.to          # se pose sur le temps
        else:
            assert abs(tr.cut - a) < 1e-9, tr.to                     # pic sur le temps


def test_transition_speed_peaks_at_the_cut_and_is_continuous():
    """La sortie accélère jusqu'à la coupe (vitesse finale v_out), l'entrée repart à la même vitesse et freine
    jusqu'à l'arrêt : rampes monotones, nulles hors fenêtre."""
    for tr in film4.TRANS:
        c = tr.cut
        g = [film4.ramp_out(c - tr.d_out + k * tr.d_out / 50, c, tr.d_out, tr.tau) for k in range(51)]
        assert g[0] == 0.0 and abs(g[-1] - 1) < 1e-9 and all(np.diff(g) >= 0)
        assert np.all(np.diff(np.diff(g)) > -1e-12)                     # accélère jusqu'à la coupe
        h = [film4.ramp_in(c + k * tr.d_in / 50, c, tr.d_in, tr.p) for k in range(51)]
        assert h[0] == 1.0 and h[-1] < 1e-9 and all(np.diff(h) <= 0)
        if tr.out and tr.matched:   # même vitesse de part et d'autre (entrée dérivée de la sortie)
            for comp, v in tr.out.items():
                if comp != "roll" and comp in tr.inn:
                    vin = -tr.inn[comp] * tr.p / tr.d_in
                    assert abs(vin - v * film4.v_out(tr.d_out, tr.tau)) < 1e-6 * abs(v) + 1e-9


def test_motion_blur_is_applied_across_every_cut():
    for tr in film4.TRANS:
        for k in (-2, -1, 1, 2):
            t = tr.cut + k * DT
            assert film4.motion_samples(t) > 1, (tr.frm, tr.to, round(t, 3))


def test_shutter_never_straddles_a_cut():
    for c in film4.CUTS:
        for t in (c - 0.5 * DT, c - 1e-4, c, c + 1e-4):
            t0, t1 = film4.shutter(t)
            assert not (t0 < c <= t1 and t0 < c - 1e-9), (c, t, t0, t1)


def test_end_card_is_still_and_complete_for_its_last_1_5_s():
    a, b = film4.SEC["end"]
    assert abs((b - a) - 1.5) < 1e-9
    ref = film4.render(a)
    for t in (a + DT, a + 0.5, b - DT):
        assert np.abs(film4.render(t) - ref).max() < 1e-6, t
    assert film4.motion_samples(a) == 1


def test_kinetic_text_at_rest_is_the_plain_text():
    s = "n'importe quelle app."
    n = film4.kin_count(s)
    assert n == 3
    assert film4.kin_tex(s, [0.0] * n) is film4.TXT(s, 200, "black", film4.S.INK)
    half = film4.kin_tex(s, [0.5] * n)
    assert half.shape == film4.TXT(s, 200, "black", film4.S.INK).shape
    assert 0 < half[..., 3].sum() < film4.TXT(s, 200, "black", film4.S.INK)[..., 3].sum()
    assert film4.kin_alpha([1.0] * n) == 0.0 and film4.kin_alpha([-1.0] * n) == 0.0
