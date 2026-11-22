"""v9 : aucun élément d'interface n'existe deux fois à l'image. Quand un morceau d'un écran se soulève en 3D (bouton
« Télécharger » du hero, couches de la vue éclatée du navigateur), l'écran du téléphone ne le contient plus (son
logement) : jamais une copie flottante pendant que l'original reste visible dans le téléphone.

Vérification sur la scène (déterministe) : chaque texture dessinée (plans, volumes) et l'écran de chaque téléphone
visible de face sont comparés par corrélation normalisée (1/4 de résolution) ; une correspondance exige aussi un
écart absolu faible (une zone unie ne compte pas)."""
from functools import lru_cache

import cv2
import numpy as np
import pytest

import light  # noqa: F401  (vidéo de démo = le film lui-même)
from film import assets
from light import film4, ui
from light.stage import PhoneItem
from reel.core import rot

DS = 4
NCC = 0.9
MAD = 12.0


def _gray(rgb, alpha=None):
    g = cv2.cvtColor(np.ascontiguousarray(rgb), cv2.COLOR_RGB2GRAY).astype(np.float32)
    if alpha is not None:
        g *= alpha.astype(np.float32) / 255
    return cv2.resize(g, (max(1, g.shape[1] // DS), max(1, g.shape[0] // DS)), interpolation=cv2.INTER_AREA)


@lru_cache(maxsize=None)
def _screen(key):
    return _gray(assets.load_screen(key))


_TEX = {}


def _tex(tex):
    ent = _TEX.get(id(tex))
    if ent is None or ent[0] is not tex:
        ent = (tex, _gray(tex[..., :3], tex[..., 3]))
        _TEX[id(tex)] = ent
    return ent[1]


def _found(T, S) -> bool:
    """Le gabarit T (gris, réduit) apparaît-il tel quel dans S ?"""
    if T.shape[0] > S.shape[0] or T.shape[1] > S.shape[1] or T.std() < 6 or min(T.shape) < 8:
        return False
    r = cv2.matchTemplate(S, T, cv2.TM_CCOEFF_NORMED)
    r[~np.isfinite(r)] = -1
    th, tw = T.shape
    for idx in np.argsort(r.ravel())[::-1][:20]:
        y, x = divmod(int(idx), r.shape[1])
        if r[y, x] < NCC:
            return False
        win = S[y:y + th, x:x + tw]
        if win.std() > 0.5 * T.std() and np.abs(win - T).mean() < MAD:
            return True
    return False


def _items(t):
    """(textures dessinées, écrans des téléphones visibles de face) de la scène à t."""
    sc = film4.scene(t)
    cam = sc.camera(t)
    planes, screens = [], []
    for g in sc.groups:
        for it in g:
            if isinstance(it, PhoneItem):
                n = rot(it.yaw, it.pitch, it.roll) @ np.array((0.0, 0.0, -1.0))
                if it.alpha > 0.3 and isinstance(it.key, str) and float(n @ (np.asarray(it.center) - cam.pos)) < 0:
                    screens.append(it.key)
            elif it.alpha >= 0.1:
                planes.append((getattr(it, "label", None) or f"{type(it).__name__}{it.tex.shape[1]}x{it.tex.shape[0]}",
                               it.tex))
    return planes, sorted(set(screens))


def duplicates(t):
    """Éléments dessinés qui sont une copie d'une partie de l'écran d'un téléphone visible au même instant."""
    planes, screens = _items(t)
    return [(name, key) for name, tex in planes for key in screens if _found(_tex(tex), _screen(key))]


def count(t, tex) -> int:
    """Nombre d'exemplaires de l'élément tex à l'image (dans les textures dessinées et les écrans visibles)."""
    T = _tex(tex)
    planes, screens = _items(t)
    return sum(_found(T, _tex(p)) for _, p in planes) + sum(_found(T, _screen(k)) for k in screens)


def test_detector_sees_the_pill_in_the_capture_and_not_in_its_slot():
    T = _tex(film4.pill_tex())
    assert _found(T, _screen("capture"))
    assert _found(T, _tex(ui.crop(*ui.CROPS["download_btn"])))   # l'ancienne carte (barre du bas) la contenait
    assert not _found(T, _screen(film4.HERO_SLOT))


HERO_TIMES = (5.5, 5.9, 6.2, 6.4)


@pytest.mark.parametrize("t", HERO_TIMES)
def test_hero_download_pill_exists_once(t):
    """Le bouton « Télécharger » sorti de l'écran (e2 → e4) : une seule pilule, la vraie ; l'écran montre son
    logement ; aucune copie de la barre du bas."""
    e = film4.EV["hero"]
    assert e[2] < t < e[4]
    assert count(t, film4.pill_tex()) == 1
    labels = [n for n, _ in _items(t)[0]]
    assert labels.count("pill") == 1
    assert film4.HERO_SLOT in _items(t)[1]
    assert not duplicates(t)


@pytest.mark.parametrize("t", (12.55, 12.7, 12.85))
def test_browser_exploded_layers_exist_once(t):
    e = film4.EV["browser"]
    assert e[3] < t < e[4] + 0.1
    for key, _ in film4.LAYERS:
        assert count(t, film4.CROP(key)) == 1, key
    assert not duplicates(t)


def test_no_floating_copy_of_visible_screen_content_anywhere():
    """Tout le film (pas de 0,1 s) : aucun plan (carte soulevée, fragment flou, vue éclatée, notification) n'est une
    copie d'une partie de l'écran d'un téléphone visible au même instant."""
    bad = []
    for t in np.arange(0.0, 31.5, 0.1):
        d = duplicates(float(t))
        if d:
            bad.append((round(float(t), 2), d))
    assert not bad, bad[:12]
