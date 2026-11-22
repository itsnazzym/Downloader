"""S4 Envoi & archive (images 570–779) : deux téléphones reliés par un flux de points, puis éventail de cartes."""
import cv2
import numpy as np

from .. import config
from ..assets import load_screen
from ..ease import in_out_cubic, out_back, out_expo, progress, spring
from ..fx import _splat, motion_blur, plate, screen_blend
from ..typo import COPY_SIZES, kinetic, kinetic_lines, over_rgba
from .stage import compose_phone, place_phone

G0 = 570
IMPACT1, IMPACT2 = 15, 120
SAMPLES, SHUTTER = 16, 0.2   # flou de mouvement des images rapides
V = config.VERTICAL
CARDS = ([("archive", 135, 235, -8.0), ("library", 150, 540, 0.0), ("settings", 165, 845, 8.0)] if V
         else [("archive", 135, 620, -8.0), ("library", 150, 960, 0.0), ("settings", 165, 1300, 8.0)])
PH = 880
PS = 0.95 if V else 0.62            # échelle des téléphones
PY = 980 if V else 600              # ligne de centre des téléphones
L, R = ((265.0, PY), (815.0, PY)) if V else ((560.0, 600.0), (1360.0, 600.0))
TITLE_Y = 340 if V else 150
N = 140
_rng = np.random.default_rng(11)
PHASE = _rng.random(N)
SPEED = 0.55 + _rng.random(N) * 0.5
JIT = (_rng.random(N) - 0.5) * 70


def _bezier(u: np.ndarray, jit: np.ndarray):
    p0 = np.array(L) + (0, -60)
    p2 = np.array(R) + (0, -60)
    p1 = np.array((config.W / 2, 330.0 if V else 260.0))
    x = (1 - u) ** 2 * p0[0] + 2 * (1 - u) * u * p1[0] + u ** 2 * p2[0]
    y = (1 - u) ** 2 * p0[1] + 2 * (1 - u) * u * (p1[1] + jit) + u ** 2 * p2[1]
    return x, y


def _stream(f: float) -> np.ndarray:
    hw, hh = config.W // 2, config.H // 2
    buf = np.zeros((hh, hw), np.float32)
    on = progress(f, IMPACT1 + 4, IMPACT1 + 14) * (1 - progress(f, IMPACT2 - 6, IMPACT2))
    if on <= 0:
        return np.zeros((config.H, config.W, 3), np.float32)
    for k in range(7):  # traînée de 6 images
        tt = (f - k * 0.9 - IMPACT1) / config.FPS
        u = np.mod(PHASE + tt * SPEED, 1.0)
        born = (tt * SPEED - (1 - PHASE)) > -1  # ne montrer que les points déjà émis
        x, y = _bezier(u, JIT)
        b = (1 - k / 7) ** 2 * np.sin(np.pi * u) ** 0.5 * born
        _splat(buf, x / 2, y / 2, b * 0.9)
    buf = buf + cv2.GaussianBlur(buf, (0, 0), 2.0) * 1.5
    full = cv2.resize(buf, (config.W, config.H), interpolation=cv2.INTER_LINEAR) * on
    return np.repeat(np.clip(full, 0, 1)[..., None], 3, axis=2)


def _frame(f: float) -> np.ndarray:
    gf = G0 + f
    t = gf / config.FPS
    img = np.zeros((config.H, config.W, 3), np.float32)

    # titres
    if f < IMPACT2:
        out = progress(f, IMPACT2 - 8, IMPACT2)
        if V:
            layer = kinetic_lines([["Envoi", "local."], ["Sans", "câble."]], f, 150, y=TITLE_Y - out * 40,
                                  line_gap=165, per_word=3, line_delay=4)
        else:
            layer = kinetic(config.COPY["send"].split(), f, COPY_SIZES["send"], per_word=3, y=150 - out * 40)
        img = over_rgba(img, layer, alpha=1 - out)
    if f >= IMPACT2:
        if V:
            layer = kinetic_lines([["Ton", "archive"], ["TikTok."]], f - IMPACT2, 150, y=TITLE_Y,
                                  line_gap=165, per_word=3, line_delay=4)
        else:
            layer = kinetic(config.COPY["archive"].split(), f - IMPACT2, COPY_SIZES["archive"], per_word=3, y=150)
        img = over_rgba(img, layer, alpha=1 - progress(f, 196, 209))

    # partie 1 : envoi entre deux téléphones
    if IMPACT1 - 2 <= f < IMPACT2 + 10:
        rings = plate("p4").frame(t)
        rings = np.roll(rings, int(R[0] - config.W / 2), axis=1)
        if V:
            rings = np.roll(rings, int(R[1] - config.H / 2), axis=0)
        img = screen_blend(img, rings, (0.28 if V else 0.45) * progress(f, IMPACT1, IMPACT1 + 10) * (1 - progress(f, IMPACT2 - 4, IMPACT2)))
        k = spring(progress(f, IMPACT1 - 2, IMPACT1 + 12), freq=1.8, damping=0.6)
        drop = out_expo(progress(f, IMPACT2, IMPACT2 + 10))
        ph = compose_phone(load_screen("send"), PH)
        for (cx, cy), ry, side in ((L, 10.0, -1), (R, -10.0, 1)):
            x = cx + side * 500 * (1 - k)
            y = cy + 900 * drop
            img = place_phone(img, ph, x, y, PS, rot_y_deg=ry, alpha=min(1.0, k * 1.5) * (1 - drop))
        img = screen_blend(img, _stream(f), 1.0)

    # partie 2 : éventail de cartes
    shrink = in_out_cubic(progress(f, 180, 209))
    for key, start, cx, rz in CARDS:
        if f < start - 1:
            continue
        k = out_back(progress(f, start - 1, start + 11), s=1.4)
        x = cx + (config.W / 2 - cx) * 0.35 * shrink
        y = (PY + 40 if V else 640) + 700 * (1 - k)
        sc = PS * (1 - 0.1 * shrink)
        img = place_phone(img, compose_phone(load_screen(key), PH), x, y, sc,
                          rot_z_deg=rz * (1 - 0.5 * shrink), alpha=min(1.0, 0.3 + k))
    img = img * (1 - 0.85 * in_out_cubic(progress(f, 200, 209)))

    return np.clip(img, 0, 1).astype(np.float32)


def render(f: float) -> np.ndarray:
    fast = (IMPACT1 - 2 <= f <= IMPACT1 + 8 or IMPACT2 <= f <= IMPACT2 + 8
            or any(s - 1 <= f <= s + 6 for _, s, _, _ in CARDS))
    if fast:
        return np.clip(motion_blur(_frame, f, samples=SAMPLES, shutter=SHUTTER), 0, 1).astype(np.float32)
    return _frame(f)
