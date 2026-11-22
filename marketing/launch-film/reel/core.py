"""Socle du showreel : matrice LED, points lumineux, caméra 3D, téléphone 3D, finition.

Toutes les images sont des float32 H×W×3 dans [0, 1] ; la finition les convertit en uint8.
"""
import math
from functools import lru_cache

import cv2
import numpy as np

from film import assets
from film.typo import paste, text_layer  # noqa: F401  (réexportés pour les scènes)

from .timeline import DROPS, impact

W, H, FPS = 1920, 1080, 30
CX, CY = W / 2, H / 2
WHITE = (236, 236, 234)
RED = (247, 71, 59)
OFF = (34, 34, 37)  # un cran au-dessus du gris du logo pour rester lisible après compression

# ---------------------------------------------------------------- police LED 5×7
_G = """
A .###. #...# #...# ##### #...# #...# #...#
B ####. #...# #...# ####. #...# #...# ####.
C .###. #...# #.... #.... #.... #...# .###.
D ####. #...# #...# #...# #...# #...# ####.
E ##### #.... #.... ####. #.... #.... #####
É ..##. ##### #.... ####. #.... #.... #####
F ##### #.... #.... ####. #.... #.... #....
G .###. #...# #.... #.### #...# #...# .###.
H #...# #...# #...# ##### #...# #...# #...#
I .###. ..#.. ..#.. ..#.. ..#.. ..#.. .###.
J ..### ...#. ...#. ...#. ...#. #..#. .##..
K #...# #..#. #.#.. ##... #.#.. #..#. #...#
L #.... #.... #.... #.... #.... #.... #####
M #...# ##.## #.#.# #.#.# #...# #...# #...#
N #...# #...# ##..# #.#.# #..## #...# #...#
O .###. #...# #...# #...# #...# #...# .###.
P ####. #...# #...# ####. #.... #.... #....
Q .###. #...# #...# #...# #.#.# #..#. .##.#
R ####. #...# #...# ####. #.#.. #..#. #...#
S .#### #.... #.... .###. ....# ....# ####.
T ##### ..#.. ..#.. ..#.. ..#.. ..#.. ..#..
U #...# #...# #...# #...# #...# #...# .###.
V #...# #...# #...# #...# #...# .#.#. ..#..
W #...# #...# #...# #.#.# #.#.# #.#.# .#.#.
X #...# #...# .#.#. ..#.. .#.#. #...# #...#
Y #...# #...# .#.#. ..#.. ..#.. ..#.. ..#..
Z ##### ....# ...#. ..#.. .#... #.... #####
0 .###. #...# #..## #.#.# ##..# #...# .###.
1 ..#.. .##.. ..#.. ..#.. ..#.. ..#.. .###.
2 .###. #...# ....# ...#. ..#.. .#... #####
3 ##### ...#. ..#.. ...#. ....# #...# .###.
4 ...#. ..##. .#.#. #..#. ##### ...#. ...#.
5 ##### #.... ####. ....# ....# #...# .###.
6 ..##. .#... #.... ####. #...# #...# .###.
7 ##### ....# ...#. ..#.. .#... .#... .#...
8 .###. #...# #...# .###. #...# #...# .###.
9 .###. #...# #...# .#### ....# ...#. .##..
% ##... ##..# ...#. ..#.. .#... #..## ...##
. ..... ..... ..... ..... ..... .##.. .##..
+ ..... ..#.. ..#.. ##### ..#.. ..#.. .....
- ..... ..... ..... ##### ..... ..... .....
/ ....# ....# ...#. ..#.. .#... #.... #....
! ..#.. ..#.. ..#.. ..#.. ..#.. ..... ..#..
: ..... .##.. .##.. ..... .##.. .##.. .....
"""
FONT = {ln[0]: ln[2:].split() for ln in _G.strip().splitlines()}
FONT[" "] = ["....."] * 7
LED_TEXTS = ("VIDÉO.", "AUDIO.", "HORS LIGNE.", "0123456789%", "MP4 MP3", "YT-DLP", "ARIA2C", "FFMPEG")


def led_cells(text: str) -> np.ndarray:
    """Toutes les cellules (colonne, ligne, allumée) d'un texte, 1 colonne vide entre les caractères."""
    out = []
    for i, ch in enumerate(text):
        g = FONT[ch]
        for r in range(7):
            for c in range(5):
                out.append((i * 6 + c, r, g[r][c] == "#"))
    return np.array(out, np.int32).reshape(-1, 3)


def led_layout(text: str, cx: float, cy: float, pitch: float):
    """Cellules et positions écran (centrées sur cx, cy)."""
    cells = led_cells(text)
    wcols = len(text) * 6 - 1
    xs = cx + (cells[:, 0] - (wcols - 1) / 2) * pitch
    ys = cy + (cells[:, 1] - 3) * pitch
    return cells, xs, ys


# ---------------------------------------------------------------- points lumineux
def dots(img: np.ndarray, xs, ys, r, colors, glow: float = 0.0, mode: str = "max") -> np.ndarray:
    """Disques antialiasés. colors : (N,3) ou (3,) en 0..255, déjà multipliés par l'opacité.

    mode "max" : éclaircir ; "add" : lumière additive. glow ajoute un halo flou de la même couche.
    """
    xs, ys = np.atleast_1d(xs).astype(np.float64), np.atleast_1d(ys).astype(np.float64)
    n = len(xs)
    if n == 0:
        return img
    rs = np.broadcast_to(np.atleast_1d(r), (n,)).astype(np.float64)
    cols = np.broadcast_to(np.asarray(colors, np.float64).reshape(-1, 3), (n, 3))
    vis = (xs > -rs - 2) & (xs < W + rs + 2) & (ys > -rs - 2) & (ys < H + rs + 2) & (cols.max(1) > 0.5) & (rs > 0.05)
    if not vis.any():
        return img
    layer = np.zeros((H, W, 3), np.uint8)
    for x, y, rr, c in zip(xs[vis], ys[vis], rs[vis], cols[vis]):
        cv2.circle(layer, (int(round(x * 16)), int(round(y * 16))), max(8, int(round(rr * 16))),
                   (int(c[0]), int(c[1]), int(c[2])), -1, cv2.LINE_AA, 4)
    lf = layer.astype(np.float32) * (1 / 255)
    if mode == "over":
        # couleur uniforme posée par-dessus (fonds clairs) : l'alpha est la couverture du disque
        c = cols[vis][0] / 255
        a = (lf.max(axis=2, keepdims=True) / max(c.max(), 1e-6)).clip(0, 1)
        out = img * (1 - a) + c.astype(np.float32) * a
    else:
        out = np.maximum(img, lf) if mode == "max" else img + lf
    if glow > 0:
        out = out + bloom_of(lf, 14) * glow
    return out


def bloom_of(layer: np.ndarray, sigma: float) -> np.ndarray:
    small = cv2.resize(layer, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
    small = cv2.GaussianBlur(small, (0, 0), sigma / 4)
    return cv2.resize(small, (W, H), interpolation=cv2.INTER_LINEAR)


def led_text(img, text, cx, cy, pitch, on_alpha=None, off_alpha=0.85, radius=0.36, glow=0.6,
             color=WHITE, red_index=None):
    """Matrice LED : cellules éteintes en gris, allumées en blanc. on_alpha(cells, xs, ys) -> (N,) opacités."""
    cells, xs, ys = led_layout(text, cx, cy, pitch)
    on = cells[:, 2] == 1
    a = np.ones(len(cells)) if on_alpha is None else np.asarray(on_alpha(cells, xs, ys), np.float64)
    offc = np.array(OFF, np.float64)[None] * off_alpha * np.ones((len(cells), 1))
    img = dots(img, xs[~on], ys[~on], pitch * radius, offc[~on])
    col = np.tile(np.array(color, np.float64), (len(cells), 1))
    if red_index is not None:
        col[red_index] = RED
    img = dots(img, xs[on], ys[on], pitch * radius * (0.6 + 0.4 * np.clip(a[on], 0, 1)),
               col[on] * np.clip(a[on], 0, 1)[:, None], glow=glow)
    return img


# ---------------------------------------------------------------- 3D
def rot(yaw=0.0, pitch=0.0, roll=0.0) -> np.ndarray:
    """Rotation (degrés) : lacet autour de y, tangage autour de x, roulis autour de z. y vers le bas."""
    a, b, c = (math.radians(v) for v in (yaw, pitch, roll))
    ry = np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])
    rx = np.array([[1, 0, 0], [0, math.cos(b), -math.sin(b)], [0, math.sin(b), math.cos(b)]])
    rz = np.array([[math.cos(c), -math.sin(c), 0], [math.sin(c), math.cos(c), 0], [0, 0, 1]])
    return ry @ rx @ rz


class Cam:
    """Caméra au point pos, regardant vers +z (après rotation), focale f en pixels."""

    def __init__(self, f=1400.0, pos=(0.0, 0.0, 0.0), yaw=0.0, pitch=0.0, roll=0.0, shift=(0.0, 0.0)):
        self.f, self.pos = f, np.asarray(pos, np.float64)
        self.R = rot(yaw, pitch, roll)
        self.shift = shift

    def to_cam(self, P):
        return (np.asarray(P, np.float64) - self.pos) @ self.R

    def project(self, P):
        p = self.to_cam(P)
        z = np.maximum(p[:, 2], 1e-3)
        u = CX + self.shift[0] + self.f * p[:, 0] / z
        v = CY + self.shift[1] + self.f * p[:, 1] / z
        return np.stack([u, v], 1), p[:, 2]


# ---------------------------------------------------------------- téléphone 3D
TEX_H = 1100


@lru_cache(maxsize=16)
def phone_tex(key: str) -> np.ndarray:
    t = assets.phone(assets.load_screen(key), TEX_H)
    t.setflags(write=False)
    return t


@lru_cache(maxsize=4)
def _uv(h: int, w: int):
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    return u / w, v / h


@lru_cache(maxsize=4)
def _ring(w: float, h: float, r: float, n: int = 14):
    """Contour d'un rectangle arrondi (sens horaire écran) et normales sortantes."""
    pts, nrm = [], []
    for cx, cy, a0 in ((w / 2 - r, -h / 2 + r, -90), (w / 2 - r, h / 2 - r, 0),
                       (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180)):
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
            nrm.append((math.cos(a), math.sin(a)))
    return np.array(pts), np.array(nrm)


def _gloss(tex: np.ndarray, sweep: float, strength: float) -> np.ndarray:
    """Reflet de vitre : bande diagonale douce à la position sweep (0..1)."""
    h, w = tex.shape[:2]
    u, v = _uv(h, w)
    d = (u * 0.55 + v * 0.45) - sweep
    band = np.exp(-(d / 0.09) ** 2) * strength + np.exp(-(d / 0.35) ** 2) * strength * 0.25
    out = tex.astype(np.float32)
    a = out[..., 3:4] / 255
    out[..., :3] = np.minimum(255, out[..., :3] + band[..., None] * 255 * a)
    return out


def draw_phone(img: np.ndarray, key: str, pos, yaw=0.0, pitch=0.0, roll=0.0, cam: Cam | None = None,
               thick: float = 46.0, alpha: float = 1.0, blur: float = 0.0, reflect: float = 0.0,
               floor_y: float | None = None, gloss: float = 0.16, light=(-0.5, -0.6, -0.62),
               tex: np.ndarray | None = None) -> dict:
    """Dessine un téléphone 3D (face écran, tranche éclairée, dos) dans img (en place).

    Renvoie {"front": bool, "map": (u_tex, v_tex) -> (x, y) écran, "bbox": (x0, y0, x1, y1)}.
    """
    cam = cam or Cam()
    tex = phone_tex(key) if tex is None else tex
    th, tw = tex.shape[:2]
    R = rot(yaw, pitch, roll)
    P = np.asarray(pos, np.float64)
    rr = 0.13 * tw
    ring, nrm = _ring(float(tw), float(th), float(rr))
    n = len(ring)
    front = np.c_[ring, np.full(n, -thick / 2)] @ R.T + P
    back = np.c_[ring, np.full(n, thick / 2)] @ R.T + P
    uvf, zf = cam.project(front)
    uvb, zb = cam.project(back)
    allp = np.r_[uvf, uvb]
    x0, y0 = np.floor(allp.min(0)).astype(int) - 4
    x1, y1 = np.ceil(allp.max(0)).astype(int) + 4
    X0, Y0, X1, Y1 = max(0, x0), max(0, y0), min(W, x1), min(H, y1)
    corners = np.array([[-tw / 2, -th / 2, -thick / 2], [tw / 2, -th / 2, -thick / 2],
                        [tw / 2, th / 2, -thick / 2], [-tw / 2, th / 2, -thick / 2]]) @ R.T + P
    cuv, _ = cam.project(corners)
    Hm = cv2.getPerspectiveTransform(np.float32([[0, 0], [tw, 0], [tw, th], [0, th]]), cuv.astype(np.float32))

    b = max(2, round(0.016 * th))
    k = (th - 2 * b) / assets.CROP_H

    def mapper(u, v):
        """Coordonnées dans la capture d'écran (1170×2388) → pixel écran."""
        p = Hm @ np.array([b + u * k, b + v * k, 1.0])
        return p[0] / p[2], p[1] / p[2]

    nz = R @ np.array([0, 0, -1.0])
    view = P - cam.pos
    front_vis = float(nz @ view) < 0
    info = {"front": front_vis, "map": mapper, "bbox": (X0, Y0, X1, Y1), "H": Hm}
    if X1 <= X0 or Y1 <= Y0 or alpha <= 0 or min(zf.min(), zb.min()) < 10:
        return info
    rw, rh = X1 - X0, Y1 - Y0
    layer = np.zeros((rh, rw, 4), np.uint8)
    off = np.array([X0, Y0], np.float64)
    L = np.asarray(light, np.float64)
    L = L / np.linalg.norm(L)
    # tranche : quads triés du plus loin au plus proche
    quads = []
    for i in range(n):
        j = (i + 1) % n
        nw = R @ np.array([*(nrm[i] + nrm[j]) / 2, 0.0])
        mid = (front[i] + front[j] + back[i] + back[j]) / 4
        vdir = mid - cam.pos
        if nw @ vdir >= 0:
            continue
        vdir = vdir / np.linalg.norm(vdir)
        lam = max(0.0, -(nw @ L))
        h = -(L + vdir)
        h = h / (np.linalg.norm(h) + 1e-9)
        spec = max(0.0, nw @ h) ** 24
        c = 255 * np.clip(np.array([0.13, 0.13, 0.145]) * (0.45 + 1.1 * lam) + spec * 0.55, 0, 1)
        q = np.array([uvf[i], uvf[j], uvb[j], uvb[i]]) - off
        quads.append((float(np.linalg.norm(mid - cam.pos)), q, c))
    for _, q, c in sorted(quads, key=lambda t: -t[0]):
        cv2.fillConvexPoly(layer, np.round(q * 16).astype(np.int32), (int(c[0]), int(c[1]), int(c[2]), 255),
                           cv2.LINE_AA, 4)
    if front_vis:
        sweep = 0.5 - yaw / 70.0 + pitch / 120.0
        t = _gloss(tex, sweep, gloss) if gloss > 0 else tex.astype(np.float32)
        Hroi = np.array([[1, 0, -X0], [0, 1, -Y0], [0, 0, 1]], np.float64) @ Hm
        warped = cv2.warpPerspective(t, Hroi, (rw, rh), flags=cv2.INTER_LINEAR,
                                     borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))
        a = warped[..., 3:4] / 255
        lf = layer.astype(np.float32)
        lf[..., :3] = lf[..., :3] * (1 - a) + warped[..., :3] * a
        lf[..., 3:4] = np.maximum(lf[..., 3:4], warped[..., 3:4])
    else:
        lf = layer.astype(np.float32)
        poly = np.round((uvb - off) * 16).astype(np.int32)
        backl = np.zeros_like(layer)
        cv2.fillPoly(backl, [poly], (20, 20, 22, 255), cv2.LINE_AA, 4)
        ba = backl[..., 3:4].astype(np.float32) / 255
        lf[..., :3] = lf[..., :3] * (1 - ba) + backl[..., :3] * ba
        lf[..., 3:4] = np.maximum(lf[..., 3:4], backl[..., 3:4])
    if blur > 0.3:
        lf = cv2.GaussianBlur(lf, (0, 0), blur)
    rgb = lf[..., :3] / 255
    a = lf[..., 3:4] / 255 * alpha
    if reflect > 0 and floor_y is not None:
        _reflection(img, rgb, a, X0, Y0, floor_y, reflect)
    region = img[Y0:Y1, X0:X1]
    img[Y0:Y1, X0:X1] = region * (1 - a) + rgb * a
    return info


def _reflection(img, rgb, a, X0, Y0, floor_y, strength):
    """Reflet sur un sol brillant : symétrie autour de floor_y, fondu et léger flou."""
    rh = rgb.shape[0]
    fr = rgb[::-1]
    fa = a[::-1]
    top = int(round(2 * floor_y - (Y0 + rh)))  # le bas de l'objet touche floor_y
    ys = np.arange(rh)[:, None, None] + top
    fade = np.clip(1 - (ys - floor_y) / 260.0, 0, 1) ** 1.6 * strength
    y0, y1 = max(0, top), min(H, top + rh)
    if y1 <= y0:
        return
    s0 = y0 - top
    fa2 = cv2.GaussianBlur((fa * fade)[s0:s0 + (y1 - y0)], (0, 0), 3)
    if fa2.ndim == 2:
        fa2 = fa2[..., None]
    fr2 = fr[s0:s0 + (y1 - y0)]
    x1 = X0 + rgb.shape[1]
    region = img[y0:y1, X0:x1]
    img[y0:y1, X0:x1] = region * (1 - fa2) + fr2 * fa2


# ---------------------------------------------------------------- utilitaires d'image
def canvas(value: float = 0.0) -> np.ndarray:
    return np.full((H, W, 3), value, np.float32)


def radial(cx, cy, r, color=(255, 255, 255), power=2.0) -> np.ndarray:
    """Halo radial plein cadre (calculé en quart de résolution)."""
    y, x = np.mgrid[0:H // 4, 0:W // 4].astype(np.float32) * 4
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / max(r, 1)
    g = np.clip(1 - d, 0, 1) ** power
    g = cv2.resize(g, (W, H), interpolation=cv2.INTER_LINEAR)
    return g[..., None] * (np.array(color, np.float32) / 255)


def ring(img, cx, cy, r, width, color=(255, 255, 255), alpha=1.0, sy=1.0, glow=0.5):
    if alpha <= 0 or r <= 0:
        return img
    layer = np.zeros((H, W, 3), np.uint8)
    c = tuple(int(v * min(1, alpha)) for v in color)
    cv2.ellipse(layer, (int(cx * 16), int(cy * 16)), (int(r * 16), int(r * sy * 16)), 0, 0, 360, c,
                max(1, int(round(width))), cv2.LINE_AA, 4)
    lf = layer.astype(np.float32) / 255
    return img + lf + (bloom_of(lf, 10) * glow if glow else 0)


def line(img, p0, p1, color=(255, 255, 255), width=2, alpha=1.0):
    layer = np.zeros((H, W, 3), np.uint8)
    c = tuple(int(v * alpha) for v in color)
    cv2.line(layer, (int(p0[0] * 16), int(p0[1] * 16)), (int(p1[0] * 16), int(p1[1] * 16)), c, width,
             cv2.LINE_AA, 4)
    return np.maximum(img, layer.astype(np.float32) / 255)


def text(img, s, size, cx, cy, weight="black", alpha=1.0, color=(255, 255, 255), tracking=-0.03, scale=1.0):
    return paste(img, text_layer(s, size, weight, tracking, tuple(color)), cx, cy, scale=scale, alpha=alpha)


def shake(f: float, amount: float = 18.0) -> tuple[float, float]:
    k = impact(f, decay=5)
    if k <= 0:
        return 0.0, 0.0
    rng = np.random.default_rng(int(f) * 7 + 3)
    return tuple(rng.uniform(-1, 1, 2) * amount * k)


def dir_blur(img: np.ndarray, dx: float, dy: float) -> np.ndarray:
    """Flou de bougé directionnel (longueur en pixels)."""
    n = int(round(math.hypot(dx, dy)))
    if n < 2:
        return img
    k = np.zeros((2 * n + 1, 2 * n + 1), np.float32)
    cv2.line(k, (n - int(dx / 2), n - int(dy / 2)), (n + int(dx / 2), n + int(dy / 2)), 1.0, 1)
    k /= k.sum()
    return cv2.filter2D(img, -1, k)


# ---------------------------------------------------------------- finition
_VIG = None


def finish(img: np.ndarray, f: int) -> np.ndarray:
    global _VIG
    if _VIG is None:
        y, x = np.mgrid[0:H, 0:W].astype(np.float32)
        d = np.sqrt(((x - CX) / CX) ** 2 + ((y - CY) / CY) ** 2) / math.sqrt(2)
        _VIG = (1 - 0.3 * d ** 2.2)[..., None].astype(np.float32)
    out = np.clip(img, 0, 4)
    hi = np.clip(out - 0.75, 0, None)
    out = out + bloom_of(hi, 18) * 0.9 + bloom_of(hi, 60) * 0.5
    out = out * _VIG
    k = impact(f, decay=4)
    px = int(round(10 * k))
    if px > 0:
        o2 = out.copy()
        o2[:, px:, 0] = out[:, :-px, 0]
        o2[:, :-px, 2] = out[:, px:, 2]
        out = o2 + k * 0.25
    rng = np.random.default_rng(5000 + f)
    g = cv2.resize(rng.standard_normal((H // 2, W // 2), dtype=np.float32), (W, H))
    lum = np.clip(out.mean(2, keepdims=True), 0, 1)
    out = out + g[..., None] * 0.028 * (0.3 + 0.7 * np.sqrt(lum))
    # tone mapping doux : les hautes lumières s'arrondissent au lieu de brûler
    out = np.where(out > 0.85, 0.85 + 0.15 * np.tanh((out - 0.85) / 0.15), out)
    return (np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)


__all__ = ["DROPS"]

# ---------------------------------------------------------------- polices supplémentaires
from pathlib import Path as _P  # noqa: E402

from film import config as _fc  # noqa: E402

_FD = _P("/usr/share/fonts/opentype/inter")
_fc.FONTS.setdefault("mono", _P("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"))
_fc.FONTS.setdefault("regular", _FD / "Inter-Regular.otf")
_fc.FONTS.setdefault("light", _FD / "InterDisplay-Light.otf")
_fc.FONTS.setdefault("dmedium", _FD / "InterDisplay-Medium.otf")


# ---------------------------------------------------------------- texte aligné, trames, anneaux au sol
def text_at(img, s, size, x, y, align="left", weight="semibold", alpha=1.0, color=(255, 255, 255), tracking=-0.02):
    lay = text_layer(s, size, weight, tracking, tuple(color))
    w = lay.shape[1]
    cx = x + w / 2 if align == "left" else x - w / 2 if align == "right" else x
    return paste(img, lay, cx, y, alpha=alpha), w


_HT = {}


def halftone(img: np.ndarray, t: float, pitch: int = 24, direction: int = 1) -> np.ndarray:
    """Fondu en trame de points : t=0 image intacte, t=1 noir. Balaye de gauche à droite (direction=1)."""
    if t <= 0:
        return img
    if t >= 1:
        return np.zeros_like(img)
    if pitch not in _HT:
        y, x = np.mgrid[0:H, 0:W].astype(np.float32)
        cxs = (np.floor(x / pitch) + 0.5) * pitch
        cys = (np.floor(y / pitch) + 0.5) * pitch
        _HT[pitch] = (np.hypot(x - cxs, y - cys), cxs / W)
    d, cx = _HT[pitch]
    pos = cx if direction == 1 else 1 - cx
    local = np.clip(t * 1.6 - pos * 0.6, 0, 1)
    r = (1 - local) * pitch * 0.75
    m = np.clip(r - d + 0.5, 0, 1)
    return img * m[..., None]


def floor_ring(img, cam: Cam, cx, cz, r, y, alpha=1.0, color=(255, 255, 255), width=2):
    if alpha <= 0.01:
        return img
    a = np.linspace(0, 2 * np.pi, 120)
    P = np.c_[cx + r * np.cos(a), np.full(len(a), y), cz + r * np.sin(a)]
    uv, d = cam.project(P)
    if (d < 50).any():
        return img
    layer = np.zeros((H, W, 3), np.uint8)
    c = tuple(int(v * min(1, alpha)) for v in color)
    cv2.polylines(layer, [np.round(uv * 16).astype(np.int32)], True, c, width, cv2.LINE_AA, 4)
    lf = layer.astype(np.float32) / 255
    return img + lf + bloom_of(lf, 8) * 0.6


def bezier(p0, p1, p2, t):
    t = np.asarray(t)[..., None]
    return (1 - t) ** 2 * np.asarray(p0) + 2 * (1 - t) * t * np.asarray(p1) + t ** 2 * np.asarray(p2)


def rrect(img, x0, y0, x1, y1, r, color=(255, 255, 255), width=2, alpha=1.0, fill=None):
    layer = np.zeros((H, W, 3), np.uint8)
    c = tuple(int(v * alpha) for v in color)
    s = 16
    pts = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for k in range(9):
            a = math.radians(a0 + 90 * k / 8)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    poly = np.round(np.array(pts) * s).astype(np.int32)
    if fill is not None:
        fl = np.zeros((H, W, 3), np.uint8)
        cv2.fillPoly(fl, [poly], tuple(int(v * alpha) for v in fill), cv2.LINE_AA, 4)
        img = np.maximum(img, fl.astype(np.float32) / 255)
    cv2.polylines(layer, [poly], True, c, width, cv2.LINE_AA, 4)
    return np.maximum(img, layer.astype(np.float32) / 255)
