"""Film v4/v5 : lisibilité des écrans (light/film4.py, light/stage.py, light/ui.py).

Tout est mesuré image par image (60 i/s) avec film4.layout / film4.metrics : hauteur d'écran projetée,
lacet / tangage apparents, flou de profondeur de champ, hauteur de capitale apparente des cartes générées,
distance titres ↔ téléphones et marge de sécurité.
"""
from functools import lru_cache

import numpy as np
import pytest
from PIL import ImageFont

import light  # noqa: F401  (vidéo de démo = le film lui-même)
from film import config
from light import film, film4, ui
from light.stage import SPACE_EM, text_plane
from reel import core

FPS = 60
HOLD = 0.7          # durée minimale (s) d'une pose lisible par section
SAFE = 60           # marge de sécurité des titres (px)
GAP = 20            # écart minimal titre ↔ téléphone (px)


def _frames(name):
    a, b = film4.SEC[name]
    return [f / FPS for f in range(int(np.ceil(a * FPS)), int(np.ceil(b * FPS)))]


@lru_cache(maxsize=4096)
def _metrics(t):
    return film4.metrics(t)


@lru_cache(maxsize=4096)
def _layout(t):
    return film4.layout(t)


def _readable(m, hmin=620.0, yaw=10.0):
    return m["screen_h"] >= hmin and abs(m["yaw"]) <= yaw and abs(m["pitch"]) <= 6 and m["sigma"] <= 0.5


YAW_MAX = {"hero": 16.0}      # le téléphone du hero reste en léger trois-quarts (HERO_TURN) : le relief du bouton se lit


def _longest(flags, ts):
    best = run = 0
    for ok in flags:
        run = run + 1 if ok else 0
        best = max(best, run)
    return best / FPS


# ---------------------------------------------------------------- 1. espaces entre les mots
@pytest.mark.parametrize("tracking", [-0.1, -0.045, 0.0])
@pytest.mark.parametrize("s", ["Envoi local.", "Suivi en direct.", "en un tap."])
def test_word_space_is_at_least_028_em(s, tracking):
    size = 200
    a = text_plane(s, size, "black", (0, 0, 0), tracking)[..., 3]
    cols = np.nonzero((a > 40).any(0))[0]
    gaps = np.diff(cols) - 1
    n_spaces = s.count(" ")
    widest = np.sort(gaps)[::-1][:n_spaces]
    assert len(widest) == n_spaces and widest.min() >= SPACE_EM * size, (s, tracking, widest)
    # les autres blancs (entre lettres) restent bien plus étroits : les mots ne se coupent pas en deux
    assert np.sort(gaps)[::-1][n_spaces] < 0.12 * size


# ---------------------------------------------------------------- 2. une vraie pose lisible par section
MAIN = {"hero": ("capture",), "quality": ("share",), "browser": ("capture",), "send": ("send", "library")}


@pytest.mark.parametrize("name", sorted(MAIN))
def test_main_phone_has_a_readable_hold(name):
    """Pendant au moins 0,7 s d'affilée : écran ≥ 620 px de haut, |lacet| ≤ 10°, |tangage| ≤ 6°, net (σ ≤ 0,5 px)."""
    ts = _frames(name)
    flags = []
    for t in ts:
        ps = [m for m in _metrics(t) if m["kind"] == "phone" and m["key"] in MAIN[name]]
        flags.append(len(ps) == len(MAIN[name]) and all(_readable(m, yaw=YAW_MAX.get(name, 10.0)) for m in ps))
    assert _longest(flags, ts) >= HOLD, (name, _longest(flags, ts))


def _centre_phone(t):
    ps = [m for m in _metrics(t) if m["kind"] == "phone"]
    return min(ps, key=lambda m: abs(m["center"][0] - 960)) if ps else None


def test_montage_centre_phone_has_a_readable_hold_and_stays_tall():
    ts = _frames("montage")
    flags, short = [], []
    for t in ts:
        m = _centre_phone(t)
        flags.append(m is not None and _readable(m))
        if (m is not None and abs(m["center"][0] - 960) < 100 and m["screen_h"] < 560
                and t < film4.TR_FROM["montage"].cut - film4.TR_FROM["montage"].d_out):    # pas pendant le whip de sortie
            short.append((round(t, 3), m["key"], round(m["screen_h"])))
    assert _longest(flags, ts) >= HOLD, _longest(flags, ts)
    assert not short, short[:5]


def _cap(size, weight="medium"):
    f = ImageFont.truetype(str(config.FONTS[weight]), 1000)
    return -f.getbbox("H", anchor="ls")[1] / 1000 * size


def test_progress_card_has_a_readable_hold():
    """« progress » n'a pas de téléphone : la carte de progression est le sujet (de face, nette, texte ≥ 18 px)."""
    ts = _frames("progress")
    flags = []
    for t in ts:
        c = [m for m in _metrics(t) if m["key"] == "card"]
        flags.append(bool(c) and abs(c[0]["yaw"]) <= 10 and abs(c[0]["pitch"]) <= 6 and c[0]["sigma"] <= 0.5
                     and c[0]["scale_v"] * _cap(ui.PROG_MIN_TEXT) >= 18)
    assert _longest(flags, ts) >= HOLD


# ---------------------------------------------------------------- 3. cartes générées : texte ≥ 18 px quand elles sont le sujet
def _subject_windows():
    q, p = film4.EV["quality"], film4.EV["progress"]
    qa, qb = film4.SEC["quality"]
    pa, pb = film4.SEC["progress"]
    return [("share_sheet", ui.SHARE_MIN_TEXT, qa + 0.35, q[2]),       # monte, puis part sur e[2]
            # « Liens en file » (v8 : tombe du haut de l'écran sur e2, se décolle et grandit vers la caméra en 0,3 s,
            # balayée sur e4) : pose lisible de 0,71 s
            ("notif", ui.NOTIF_MIN_TEXT, q[2] + 0.3, q[4]),
            ("card", ui.PROG_MIN_TEXT, pa, pb),
            ("notif", ui.NOTIF_MIN_TEXT, film4.BEATS["progress"][-1] + 0.5, pb)]     # « Téléchargement terminé »


@pytest.mark.parametrize("key,size,t0,t1", _subject_windows())
def test_generated_cards_text_cap_height(key, size, t0, t1):
    bad = []
    for t in [f / FPS for f in range(int(np.ceil(t0 * FPS)), int(np.ceil(t1 * FPS)))]:
        ms = [m for m in _metrics(t) if m["key"] == key]
        assert ms, (key, t)
        cap = ms[0]["scale_v"] * _cap(size)
        if cap < 18:
            bad.append((round(t, 3), round(cap, 1)))
    assert not bad, (key, bad[:5])


# ---------------------------------------------------------------- 4. titres : jamais sur un téléphone, dans la marge
def _heads(L):
    return [(n, b) for n, b in L if n.startswith(("headline:", "iword:", "word:"))]


def _grown_overlap(h, p, g=GAP):
    return not (h[2] + g <= p[0] or p[2] + g <= h[0] or h[3] + g <= p[1] or p[3] + g <= h[1])


@pytest.mark.parametrize("name", [n for n, _, _ in film.SECTIONS])
def test_headlines_clear_of_phones_and_inside_safe_margin(name):
    phones = {"capture", "share", "done", "browser", "library", "send", "archive", "stats", "settings"}
    near, out, n_heads = [], [], 0
    for t in _frames(name):
        L = _layout(t)
        ps = [b for n, b in L if n in phones]
        for n, h in _heads(L):
            n_heads += 1
            if h[0] < SAFE or h[1] < SAFE or h[2] > 1920 - SAFE or h[3] > 1080 - SAFE:
                out.append((round(t, 3), n, h))
            for p in ps:
                if _grown_overlap(h, p):
                    near.append((round(t, 3), n, h, p))
    if name not in ("wall", "end"):
        assert n_heads > 0, name
    assert not near, (len(near), near[:3])
    assert not out, (len(out), out[:3])


# ---------------------------------------------------------------- 5. textures assez fines pour les grands téléphones
def test_phone_texture_is_not_upsampled():
    """La texture du téléphone (core.TEX_H px de haut) n'est jamais agrandie à l'écran."""
    tex_screen = core.TEX_H * 2388 / (2388 + 2 * film4.BEZ / film4.KS)       # hauteur d'écran dans la texture
    worst = max(m["screen_h"] for f in range(0, int(31.5 * FPS), 2)
                for m in _metrics(f / FPS) if m["kind"] == "phone")
    assert worst <= tex_screen, (round(worst), round(tex_screen))
