"""S3 Navigateur & bibliothèque (images 330–569) : compteur 1 800+, push sur le navigateur, whip pan, bibliothèque."""
import cv2
import numpy as np

from .. import config
from ..ease import in_out_cubic, out_expo, progress, spring
from ..fx import chroma_shift, motion_blur, plate, screen_blend
from ..assets import load_screen
from ..typo import kinetic, over_rgba, paste, text_layer
from .stage import compose_phone, place_phone, ripple

G0 = 330
V = config.VERTICAL
SIZE = 230 if V else 190
IMPACT, TAP, WHIP = 75, 135, 150
PH = 1250 if V else 900
PY = 880 if V else 560      # ligne de centre du téléphone
CNT_Y = 740                  # compteur vertical : ligne du nombre ; « sites. » est dessous
DL = (933, 2095)  # bouton « Télécharger » du navigateur


def counter_value(f: float) -> int:
    p = progress(f, 0, 55)
    return int(round(1800 * (1 - (1 - p) ** 3)))


def counter_alpha(f: float) -> float:
    """Pleine opacité jusqu'à f68 (≥ 12 images posées sur 1 800+), sortie terminée à f73."""
    return 1.0 - progress(f, 68, 73)


def _counter_canvas(f: float) -> np.ndarray:
    """Calque blanc sur noir (float32 H×W×3) du compteur « 1 800+ sites. » à l'échelle 1."""
    img = np.zeros((config.H, config.W, 3), np.float32)
    v = counter_value(f)
    digits = [text_layer(c, SIZE, "black", 0.0) for c in "0123456789"]
    cw = max(d.shape[1] for d in digits) - 8          # cellule tabulaire (sans la marge de 2×4 px)
    sp = 0.24 * SIZE                                  # espace insécable des milliers
    plus = text_layer("+", SIZE, "black", 0.0)
    sites_w = text_layer("sites.", SIZE, "black", -0.03).shape[1]
    block = 4 * cw + sp
    gap = 0.22 * SIZE
    total = (block + plus.shape[1]) if V else (block + plus.shape[1] + gap + sites_w)
    left = config.W / 2 - total / 2
    cy = CNT_Y if V else 540
    x_right = left + block
    x = x_right
    for i, ch in enumerate(reversed(f"{v:d}")):
        if i == 3:
            x -= sp
        x -= cw
        paste(img, digits[int(ch)], x + cw / 2, cy)
    pop = 1.0 + 0.4 * (1 - out_expo(progress(f, 55, 63))) if f >= 55 else 1.0
    paste(img, plus, x_right + plus.shape[1] / 2, cy, scale=pop)
    if V:  # « sites. » centré sous le nombre
        return over_rgba(img, kinetic(["sites."], f - 4, SIZE, y=cy + 0.95 * SIZE))
    layer = kinetic(["sites."], f - 4, SIZE, y=cy)
    shift = int(round(x_right + plus.shape[1] + gap + sites_w / 2 - 960))
    return over_rgba(img, np.roll(layer, shift, axis=1))


def _counter_layer(f: float, img: np.ndarray, alpha: float, scale: float) -> np.ndarray:
    c = _counter_canvas(f)
    if scale != 1.0:
        zx, zy = (config.W / 2, CNT_Y + 0.5 * SIZE) if V else (960, 540)
        M = np.float32([[scale, 0, zx * (1 - scale)], [0, scale, zy * (1 - scale)]])
        c = cv2.warpAffine(c, M, (config.W, config.H), flags=cv2.INTER_LINEAR)
    return img + (1 - img) * c * alpha


def _frame(f: float) -> np.ndarray:
    gf = G0 + f
    t = gf / config.FPS
    img = np.zeros((config.H, config.W, 3), np.float32)
    img = screen_blend(img, plate("p1").frame(t), 0.35 * (1 - progress(f, IMPACT, IMPACT + 8)) + 0.1)

    a = counter_alpha(f)
    if a > 0:
        img = _counter_layer(f, img, alpha=a, scale=1 + 0.3 * out_expo(1 - a))

    if f >= IMPACT - 2:
        if f < WHIP + 10:
            k = out_expo(progress(f, IMPACT - 2, IMPACT + 10))
            sc = 0.8 + 0.25 * k + 0.05 * in_out_cubic(progress(f, IMPACT, WHIP))
            ry = 12 * (1 - 0.6 * in_out_cubic(progress(f, IMPACT, WHIP)))
            cx = config.W / 2 - (2000 if V else 2600) * in_out_cubic(progress(f, WHIP, WHIP + 10)) ** 1.3
            scr = ripple(load_screen("browser"), *DL, progress(f, TAP, TAP + 14))
            img = place_phone(img, compose_phone(scr, PH), cx, PY, sc, rot_y_deg=ry, rot_z_deg=0)
        if f >= WHIP:
            k = out_expo(progress(f, WHIP + 2, WHIP + 14))
            cx = config.W / 2 + (2000 if V else 2600) * (1 - k) - 40 * in_out_cubic(progress(f, WHIP + 14, 239))
            ry = -14 + 10 * in_out_cubic(progress(f, WHIP, 239))
            sc = 1.0 + 0.14 * in_out_cubic(progress(f, WHIP, 239))
            img = place_phone(img, compose_phone(load_screen("stats"), PH), cx, PY, sc, rot_y_deg=ry)
            img = screen_blend(img, plate("p5").frame(t), 0.3)

    if IMPACT - 1 <= f < IMPACT + 10:  # bouffée de traînées au lieu d'une onde de choc répétée
        img = screen_blend(img, plate("p2").frame(t), 0.5 * (1 - progress(f, IMPACT, IMPACT + 10)))
    return np.clip(img, 0, 1).astype(np.float32)


def _glitch(img: np.ndarray, f: int) -> np.ndarray:
    rng = np.random.default_rng(900 + f)
    out = img.copy()
    for _ in range(9):
        y = rng.integers(0, config.H - 60)
        h = rng.integers(8, 60)
        out[y:y + h] = np.roll(out[y:y + h], int(rng.integers(-60, 60)), axis=1)
    return chroma_shift(out, 10)


def render(f: float) -> np.ndarray:
    if IMPACT - 2 <= f <= IMPACT + 6 or WHIP - 1 <= f <= WHIP + 14:
        img = np.clip(motion_blur(_frame, f, samples=6, shutter=0.5), 0, 1).astype(np.float32)
    else:
        img = _frame(f)
    if WHIP <= f < WHIP + 3:
        img = _glitch(img, int(f))
    return img
