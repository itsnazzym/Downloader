"""v8 : volumes 3D (light/stage.py) : corps du téléphone (tranche, dos) et typographie extrudée.

Rendus isolés sur fond uni, caméra reel.core.Cam(f=1500) à l'origine regardant vers +z.
"""
import cv2
import numpy as np

import light  # noqa: F401  (vidéo de démo = le film lui-même)
from light import stage
from light import style as S
from reel import core
from reel.core import rot

BG = 0.5
Z = 1700.0


def _render(items):
    img = np.full((core.H, core.W, 3), BG, np.float32)
    stage.render(img, core.Cam(f=1500), items)
    return img


def _gray(a):
    return a[..., :3].astype(np.float32).mean(-1)


def _corr(a, b, m):
    a, b = a[m], b[m]
    a, b = a - a.mean(), b - b.mean()
    return float((a * b).sum() / np.sqrt((a * a).sum() * (b * b).sum() + 1e-9))


def _face_to_tex(img, yaw, zface, xs):
    """Ramène la face (coins locaux x = xs[0] → xs[1] en haut, à z local zface) d'un téléphone en (0, 0, Z) tourné de
    yaw dans le cadre de sa texture (th × tw), pour la comparer à une texture."""
    th, tw = core.phone_tex("capture").shape[:2]
    loc = np.array([[xs[0], -th / 2, zface], [xs[1], -th / 2, zface], [xs[1], th / 2, zface], [xs[0], th / 2, zface]])
    uv, _ = core.Cam(f=1500).project(loc @ rot(yaw, 0, 0).T + (0, 0, Z))
    Hm = cv2.getPerspectiveTransform(uv.astype(np.float32), np.float32([[0, 0], [tw, 0], [tw, th], [0, th]]))
    return cv2.warpPerspective(img, Hm, (tw, th), flags=cv2.INTER_AREA)


def test_phone_back_shows_the_back_texture_not_the_mirrored_screen():
    """Tourné de 180°, on voit le dos (module photo, logo) dans le bon sens, pas l'écran vu à l'envers."""
    img = _render([stage.PhoneItem("capture", (0, 0, Z), 180.0, 0, 0, 1.0, 0.0)])
    th, tw = core.phone_tex("capture").shape[:2]
    seen = _gray(_face_to_tex(img, 180.0, stage.PHONE_THICK / 2, (tw / 2, -tw / 2)) * 255)
    back = stage.phone_back_tex()
    screen = core.phone_tex("capture")
    m = cv2.erode((back[..., 3] > 250).astype(np.uint8), np.ones((15, 15), np.uint8)).astype(bool)
    c_back = _corr(seen, _gray(back), m)
    c_back_mirror = _corr(seen, _gray(back[:, ::-1]), m)
    c_screen = max(_corr(seen, _gray(screen), m), _corr(seen, _gray(screen[:, ::-1]), m))
    assert c_back > 0.85, c_back
    assert c_back - c_back_mirror > 0.3, (c_back, c_back_mirror)
    assert c_screen < 0.3, c_screen
    # le module photo est en haut à gauche de l'image (vu de dos), le logo au centre
    x0, y0 = int(0.06 * tw), int(0.028 * th)
    assert seen[y0 + 20:y0 + 200, x0 + 20:x0 + 200].std() > 20


def test_phone_side_band_is_visible_and_metallic_at_yaw_40():
    """À 40° de lacet, la tranche (≈ 8 mm : 56 unités pour 1100 de haut) se voit entre le contour de la face avant et
    la silhouette : au moins 85 % de l'aire attendue, avec une ligne spéculaire claire."""
    yaw = 40.0
    img = _render([stage.PhoneItem("capture", (0, 0, Z), yaw, 0, 0, 1.0, 0.0)])
    sil = np.abs(img - BG).max(-1) > 0.02
    th, tw = core.phone_tex("capture").shape[:2]
    ring, _ = core._ring(float(tw), float(th), 0.13 * tw)
    R = rot(yaw, 0, 0)
    uv, _ = core.Cam(f=1500).project(np.c_[ring, np.full(len(ring), -stage.PHONE_THICK / 2)] @ R.T + (0, 0, Z))
    front = np.zeros(sil.shape, np.uint8)
    cv2.fillPoly(front, [np.round(uv * 16).astype(np.int32)], 1, cv2.LINE_AA, 4)
    front = cv2.dilate(front, np.ones((3, 3), np.uint8)).astype(bool)
    band = sil & ~front
    # aire attendue : la tranche vue de biais sur toute la hauteur du téléphone
    expected = stage.PHONE_THICK * np.sin(np.radians(yaw)) * th * (1500 / Z) ** 2
    assert band.sum() >= 0.85 * expected, (int(band.sum()), int(expected))
    lum = img[band].mean(-1)
    assert np.percentile(lum, 99) > 0.7, np.percentile(lum, 99)       # ligne spéculaire
    assert 0.12 < np.median(lum) < 0.6, np.median(lum)                 # aluminium (ni noir, ni fond)


def test_extruded_word_has_side_faces():
    """Mot extrudé tourné de 14° : des pixels de flancs (plus sombres que le fond, distincts de l'encre de la face)
    apparaissent hors de la face avant ; la face avant garde l'encre exacte."""
    tex = stage.text_plane("Zéro pub", 200, "black", S.INK)
    th, tw = tex.shape[:2]
    p = stage.Extrude(tex, (0, 0, 1500), tw * 1.18, 14.0, -8.0, 0.0, 1.0, 0.0, 0.0, 45.0, (96, 96, 104), (18, 18, 20))
    img = _render([p])
    flat = _render([stage.Plane(tex, (0, 0, 1500), tw * 1.18, 14.0, -8.0, 0.0, 1.0)])
    face = np.abs(flat - BG).max(-1) > 0.02
    sil = np.abs(img - BG).max(-1) > 0.02
    side = sil & ~cv2.dilate(face.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
    assert side.sum() > 8000, int(side.sum())
    ink = np.asarray(S.INK, np.float32) / 255
    core_face = cv2.erode(face.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
    assert np.abs(img[core_face] - ink).max(-1).mean() < 0.02
    # boîte de mise en page : face + fond de l'extrusion
    assert stage.extrude_corners(p).shape == (8, 3)
