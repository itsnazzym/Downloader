"""Film v4 : chorégraphie 3D à 60 i/s (light/film4.py).

Temps continus en secondes ; les écarts d'image sont mesurés en 480×270, sur 255.
"""
from functools import lru_cache

import cv2
import numpy as np
import light  # noqa: F401  (vidéo de démo = le film lui-même)
from light import beats as B
from light import film

from light import film4  # noqa: E402

DT = 1 / 60


@lru_cache(maxsize=512)
def _small(t: float) -> np.ndarray:
    img = film4.render(float(t))
    assert img.shape == (1080, 1920, 3) and img.dtype == np.float32
    return cv2.resize(img, (480, 270), interpolation=cv2.INTER_AREA)


def _diff(t0: float, t1: float) -> float:
    return float(np.abs(_small(t0) - _small(t1)).mean() * 255)


def _strong():
    """Coups forts choisis par pick(...) dans la chorégraphie (tous des coups de beats.hits())."""
    return np.asarray(sorted(film4.ACCENTS), float)


def test_accents_and_cuts_are_hits():
    hits, _ = B.hits()
    for h in list(film4.ACCENTS) + list(film4.HARD_CUTS):
        assert np.abs(hits - h).min() < 1e-6, h
    assert film4.FPS == 60
    # les coups forts de chaque section (pick(a, b, 6, 0.3)) font tous partie des accents
    for name, a, b in film.SECTIONS[1:9]:
        for h in film.pick(a, b, 6, 0.3):
            assert np.abs(_strong() - h).min() < 1e-6, (name, h)


def _excluded(t: float) -> bool:
    t1 = t + DT
    for _, a, _ in film.SECTIONS:
        if abs(t - a) < 0.05 or abs(t1 - a) < 0.05:
            return True
    for c in film4.HARD_CUTS:
        if t - 0.05 < c <= t1 + 0.05:
            return True
    for h in _strong():
        if h - DT <= t <= h + 0.12:   # mouvements dynamiques voulus juste après un coup fort
            return True
    if film4.blur_exempt(t, DT):      # transitions de section rendues avec flou de bougé (whip, traversée…)
        return True
    return t1 >= B.DUR


def test_render_is_continuous_in_time():
    cand = [t for t in np.linspace(0.1, B.DUR - 0.1, 600) if not _excluded(float(t))]
    ts = [float(cand[i]) for i in np.linspace(0, len(cand) - 1, 20).round().astype(int)]
    bad = []
    for t in ts:
        d = _diff(t, t + DT)
        if d >= 4:
            bad.append((round(t, 3), round(d, 2)))
    assert not bad, bad


NOISE = 0.25        # plancher de la médiane (écart de scène, /255) : bruit d'une scène au repos


@lru_cache(maxsize=1024)
def _small_cam(t: float, cam_t: float) -> np.ndarray:
    img = film4.render(float(t), cam_t=float(cam_t))
    return cv2.resize(img, (480, 270), interpolation=cv2.INTER_AREA)


def _event_diff(t0: float, t1: float) -> float:
    """Écart (480×270, /255) entre la scène à t0 et la scène à t1, vues toutes deux par la caméra de t0 (sans flou
    de bougé) : ce qui change dans la scène elle-même (événements d'interface, objets), sans le trajet de caméra.
    Depuis la v7, la caméra voyage en continu (vitesse voulue, transitions) : mesurer les coups sur l'image brute
    reviendrait à comparer chaque événement au trajet de caméra ; test_no_camera_pulse_on_beats vérifie à part que
    la caméra ne réagit jamais aux coups."""
    return float(np.abs(_small_cam(t0, t0) - _small_cam(t1, t0)).mean() * 255)


def _hits(name, a, b):
    """Coups de la section dont la scène doit changer : les 6 plus forts de la musique ; pour « words » et « wall »
    (un mot / un écran par coup), les coups de la chorégraphie elle-même (film4.EV)."""
    return film4.EV[name] if name in ONE_PER_HIT else film.pick(a, b, 6, 0.3)


def _section_ratios(name, a, b):
    """Écart de scène (caméra figée, 3 images après le coup) de chaque coup fort pick(a, b, 6, 0,3), rapporté à la
    médiane de la section (12 instants réguliers), au moins NOISE : caméra figée, une scène au repos ne change
    presque plus, et un chiffre du pourcentage qui avance tout seul ne doit pas compter comme un événement."""
    grid = np.linspace(a + 0.1, b - 0.15, 12)
    med = max(NOISE, float(np.median([_event_diff(t, t + 3 * DT) for t in grid])))
    # les coups de la transition de sortie (la caméra et les objets partent) ne sont pas des événements de la section
    t_out = film4.TR_FROM[name].cut - film4.TR_FROM[name].d_out
    return med, [(h, _event_diff(h, h + 3 * DT) / med) for h in _hits(name, a, b) if h < t_out]


# « words » et « wall » : un mot / un écran par coup, c'est la chorégraphie elle-même (coupes franches, mur)
ONE_PER_HIT = ("words", "wall")


def test_section_beats_are_real_events():
    """Le rythme vient d'actions réelles sur moins de coups, pas de la caméra : dans chaque section (hors intro et
    fin), 3 à 5 coups forts changent la scène (caméra figée, voir _event_diff) d'au moins 2,6× la médiane de la
    section ; dans les sections d'interface (film4.BEATS), ce sont exactement les 3-4 coups choisis (un vrai
    événement chacun) et aucun autre."""
    bad = []
    for name, a, b in film.SECTIONS[1:9]:
        med, rs = _section_ratios(name, a, b)
        strong = [h for h, r in rs if r >= 2.6]
        if len(strong) < 3 or (len(strong) > 5 and name not in ONE_PER_HIT):
            bad.append((name, "nombre", [(round(h, 3), round(r, 1)) for h, r in rs]))
        if name in film4.BEATS:
            want = film4.BEATS[name]
            assert 3 <= len(want) <= 4 and all(h in film.pick(a, b, 6, 0.3) for h in want), (name, want)
            for h, r in rs:
                if (h in want) != (r >= 2.6):
                    bad.append((name, round(h, 3), round(r, 2), "choisi" if h in want else "non choisi"))
    assert not bad, bad


def _cam(t):
    sc = film4.scene(t)
    cam = sc.camera(t)
    return cam.f, np.asarray(cam.pos, np.float64), np.asarray(sc.target, np.float64)


def test_no_camera_pulse_on_beats():
    """Aucun coup de zoom ni à-coup de caméra sur la basse ou les coups forts : entre le coup et +40 ms, la focale
    ne varie pas plus que 1,5× la variation médiane de la section, et la position / la visée pas plus que 1,5× ce
    que donne le mouvement lisse (max de la médiane de section et des 40 ms précédentes). Intro : la plongée finale
    dans l'icône (dernier coup) est la transition elle-même ; seuls les kicks y sont vérifiés (il n'y en a pas)."""
    w = 0.04
    kicks = np.asarray(film4.KICKS, float)
    bad = []
    for name, a, b in film.SECTIONS:
        grid = np.linspace(a + 0.05, b - 0.05 - w, 40)
        df, dp = [], []
        for t in grid:
            f0, p0, q0 = _cam(t)
            f1, p1, q1 = _cam(t + w)
            df.append(abs(f1 - f0))
            dp.append(np.linalg.norm(p1 - p0) + np.linalg.norm(q1 - q0))
        mf, mp = float(np.median(df)), float(np.median(dp))
        times = sorted(set(float(k) for k in kicks if a + 0.05 <= k < b - w - 0.01)
                       | set(h for h in film.pick(a, b, 6, 0.3) if a + 0.05 <= h < b - w - 0.01 and name != "intro"))
        for k in times:
            fb, pb, qb = _cam(k - w)
            f0, p0, q0 = _cam(k)
            f1, p1, q1 = _cam(k + w)
            if abs(f1 - f0) > 1.5 * mf + 1e-6 * f0:
                bad.append((name, round(k, 3), "focale", round(abs(f1 - f0), 3), round(mf, 3)))
            move = np.linalg.norm(p1 - p0) + np.linalg.norm(q1 - q0)
            before = np.linalg.norm(p0 - pb) + np.linalg.norm(q0 - qb)
            if move > 1.5 * max(mp, before) + 0.5:
                bad.append((name, round(k, 3), "position", round(move, 2), round(max(mp, before), 2)))
    assert not bad, bad


def test_depth_in_every_section():
    for name, a, b in film.SECTIONS[:9]:
        ds = sorted(film4.depth_layers((a + b) / 2))
        layers = []
        for d in ds:
            if not layers or d - layers[-1] >= 300:
                layers.append(d)
        assert len(layers) >= 3, (name, [round(d) for d in ds])


def _lum(img):
    """Luminance relative WCAG d'une image float RGB dans [0, 1]."""
    c = np.where(img <= 0.04045, img / 12.92, ((img + 0.055) / 1.055) ** 2.4)
    return c @ np.array([0.2126, 0.7152, 0.0722])


def test_words_hits_are_legible():
    """Sur chaque coup de « words » et les 3 images suivantes, le mot dominant est le nouveau mot, lisible
    (contraste encre / fond local ≥ 4,5:1 sur sa boîte), sans mot fantôme d'une autre couleur."""
    bad = []
    for j, h in enumerate(film4.EV["words"]):
        want = "word:" + film4.WORDS[min(j + 1, len(film4.WORDS) - 1)]
        for k in range(4):
            t = h + k * DT
            words = [(n, b) for n, b in film4.layout(t) if n.startswith("word:")]
            if [n for n, _ in words] != [want]:
                bad.append((round(t, 3), "mots", [n for n, _ in words]))
                continue
            x0, y0, x1, y1 = words[0][1]
            x0, y0, x1, y1 = max(0, x0), max(0, y0), min(1920, x1), min(1080, y1)
            L = _lum(film4.render(t)[y0:y1, x0:x1]).ravel()
            bg = float(np.median(L))
            ink = float(np.percentile(L, 3 if bg > 0.5 else 97))
            ratio = (max(bg, ink) + 0.05) / (min(bg, ink) + 0.05)
            if ratio < 4.5:
                bad.append((round(t, 3), want, round(ratio, 2)))
    assert not bad, bad


def _inter(a, b):
    return not (a[2] <= b[0] or b[2] <= a[0] or a[3] <= b[1] or b[3] <= a[1])


def test_progress_notification_stays_clear_of_headline_and_inside_frame():
    a, b = film4.SEC["progress"]
    h = film4.BEATS["progress"][-1]
    seen = 0
    for t in np.linspace(h, b - 1e-3, 24):
        L = dict(film4.layout(float(t)))
        if "notif" not in L:
            continue
        seen += 1
        n = L["notif"]
        hl = L.get("headline:Suivi en direct.")
        assert hl is not None and not _inter(n, hl), (round(t, 3), n, hl)
        assert n[0] >= 60 and n[1] >= 60 and n[2] <= 1920 - 60 and n[3] <= 1080 - 60, (round(t, 3), n)
    assert seen >= 20


def test_intro_has_no_ghost_word():
    """Intro : 2 images après chaque coup de mot, seul le nouveau mot est visible (le sortant est parti)."""
    ev = film4.EV["intro"]
    words_t = (ev[1], ev[3], ev[5])
    bad = []
    for j, h in enumerate(words_t):
        want = "iword:" + film4.INTRO_WORDS[j]
        for k in (2, 3, 4):
            t = h + k * DT
            vis = [it.label for g in film4.scene(t).groups for it in g
                   if getattr(it, "label", "").startswith("iword:") and it.alpha > 0.02]
            if vis != [want]:
                bad.append((round(t, 3), vis, want))
    assert not bad, bad
