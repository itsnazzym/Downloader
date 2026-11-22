"""S5 Final (images 780–899) : le logo se reforme, wordmark, sous-ligne, crédit, noir."""
import numpy as np

from .. import config
from ..assets import logo_layout
from ..ease import in_out_cubic, out_expo, progress, spring
from ..fx import motion_blur, plate, screen_blend
from ..typo import kinetic, over_rgba, paste, text_layer, COPY_SIZES
from . import logo_anim

V = config.VERTICAL
BIG, SMALL = (96, 52) if V else (64, 24)
NAME_SIZE = 92 if V else 120
GAP = 52
LOGO_CY, NAME_CY = (680, 1000) if V else (520, 520)   # vertical : logo au-dessus du nom
TAG_Y, CREDIT_Y = (1120, 1440) if V else (700, 1000)
CREDIT = "Big Buck Bunny © Blender Foundation · CC BY 3.0"
CREDIT_SIZE = 26
CREDIT_COLOR = (205, 205, 212)

_rng = np.random.default_rng(7)
_START = None


def _starts(n: int):
    global _START
    if _START is None:
        a = _rng.random(n) * 2 * np.pi
        r = (500 if V else 650) + _rng.random(n) * (400 if V else 500)
        _START = np.stack([config.W / 2 + np.cos(a) * r, (LOGO_CY if V else 540) + np.sin(a) * r * (1.0 if V else 0.7)], 1)
    return _START


def _final_geom():
    if V:
        return config.W / 2, config.W / 2
    name_w = text_layer(config.COPY["name"], NAME_SIZE, "black").shape[1]
    logo_w = 6 * SMALL + 0.72 * SMALL
    total = logo_w + GAP + name_w
    left = 960 - total / 2
    logo_cx = left + logo_w / 2
    name_cx = left + logo_w + GAP + name_w / 2
    return logo_cx, name_cx


def _frame(f: float) -> np.ndarray:
    img = np.zeros((config.H, config.W, 3), np.float32)
    gf = 780 + f
    img = screen_blend(img, plate("p5").frame(gf / config.FPS), 0.25 + 0.3 * max(0.0, 1 - f / 20))
    if f < 12:
        img = screen_blend(img, plate("p3").frame(plate("p3").hit_time + 0.1 + f / config.FPS), 0.35 * (1 - f / 12))

    logo_cx, name_cx = _final_geom()
    k = in_out_cubic(progress(f, 24, 40))
    pitch = BIG + (SMALL - BIG) * k
    cx = config.W / 2 + (logo_cx - config.W / 2) * k
    cy = LOGO_CY
    target = logo_layout((cx, cy), pitch)
    st = _starts(len(target))
    tt = spring(progress(f, 0, 24), freq=2.2, damping=0.45)
    layout = [(d, sx + (x - sx) * tt, sy + (y - sy) * tt) for (d, x, y), (sx, sy) in zip(target, st)]
    glow = 0.3 + 0.4 * max(0.0, 1 - f / 12)
    img = logo_anim.draw(img, layout, pitch, lambda d: 1.0, vis=lambda d: 1.0, glow=glow)

    if f >= 34:
        words = config.COPY["name"].split()
        layer = kinetic(words, f - 34, NAME_SIZE, per_word=4, y=NAME_CY)
        # recentre le bloc de mots sur name_cx (kinetic centre sur W/2)
        layer = np.roll(layer, int(round(name_cx - config.W / 2)), axis=1)
        img = over_rgba(img, layer)
    if f >= 45:
        a = out_expo(progress(f, 45, 60))
        tag = text_layer(config.COPY["tagline"], COPY_SIZES["tagline"], "medium", 0.08, config.GREY)
        paste(img, tag, config.W / 2, TAG_Y + (1 - a) * 18, alpha=a)
    if f >= 60:
        cr = text_layer(CREDIT, CREDIT_SIZE, "medium", 0.02, CREDIT_COLOR)
        paste(img, cr, config.W / 2, CREDIT_Y, alpha=0.9 * progress(f, 60, 72))
    img = img * (1 - in_out_cubic(progress(f, 96, 110)))
    return np.clip(img, 0, 1).astype(np.float32)


def render(f: float) -> np.ndarray:
    if f <= 20:
        return np.clip(motion_blur(_frame, f, samples=4, shutter=0.5), 0, 1).astype(np.float32)
    return _frame(f)
