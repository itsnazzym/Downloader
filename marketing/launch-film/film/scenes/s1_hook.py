"""S1 Accroche (images 0–119) : point rouge seul → matrice qui s'allume → logo, impact à f105."""
import math

import numpy as np

from .. import config
from ..assets import logo_layout
from ..ease import in_out_cubic, out_back, out_expo, progress, spring
from ..fx import motion_blur, plate, screen_blend
from . import logo_anim
from .camera import zoom_xy

PITCH = 84 if config.VERTICAL else 64
CENTER = (config.CX, 0.45 * config.H) if config.VERTICAL else (960, 540)
IMPACT = 105
COL_START = {3: 30, 2: 36, 4: 36, 1: 42, 5: 42, 0: 48, 6: 48}


def _cam_scale(f: float) -> float:
    s = 1.0 + 0.15 * in_out_cubic(progress(f, 60, IMPACT))
    if f >= IMPACT:  # coup de zoom à l'impact, qui se pose en ressort
        s += 0.07 * (1 - spring(progress(f, IMPACT, IMPACT + 14), freq=2.5, damping=0.5))
    # rétraction vers ×0,4 avant la coupe
    s *= 1 - 0.6 * in_out_cubic(progress(f, 110, 119))
    return s


def _frame(f: float) -> np.ndarray:
    img = np.zeros((config.H, config.W, 3), np.float32)
    t = f / config.FPS
    # grille de points en écho, très discrète
    grid_op = 0.18 * progress(f, 30, 80) * (1 - progress(f, 108, 116))
    if grid_op > 0:
        img = screen_blend(img, plate("p1").frame(t), grid_op)

    s = _cam_scale(f)
    base = logo_layout(CENTER, PITCH)
    red_home = next((x, y) for d, x, y in base if d.state == "red")
    layout = []
    for d, x, y in base:
        if d.state == "red":
            k = in_out_cubic(progress(f, 30, 42))
            x, y = CENTER[0] + (red_home[0] - CENTER[0]) * k, CENTER[1] + (red_home[1] - CENTER[1]) * k
        layout.append((d,) + zoom_xy(x, y, s, *CENTER))

    def appear(d):
        if d.state == "red":
            return 1.0
        st = COL_START[d.col] + d.row * 0.8
        return progress(f, st, st + 8)

    def lit(d):
        if d.state == "red":
            return out_expo(progress(f, 0, 18)) * (1 + 0.06 * math.sin(f / 4))
        if d.state == "on":
            st = COL_START[d.col] + d.row * 0.8 + 4
            return out_expo(progress(f, st, st + 6))
        return 0.0

    def scale(d):
        if d.state == "red":
            breath = 1 + 0.08 * math.sin(f / 5) * (1 - progress(f, 30, 42))
            return s * breath * (0.4 + 0.6 * out_expo(progress(f, 0, 18)))
        return s * out_back(appear(d))

    glow = 0.3 + 0.4 * max(0.0, 1 - (f - IMPACT) / 10) if f >= IMPACT else 0.3 * progress(f, 0, 18)
    fade = 1 - progress(f, 114, 119)
    img = logo_anim.draw(img, layout, PITCH, lit, vis=lambda d: min(1.0, appear(d) * 1.5) * fade,
                         glow=glow * fade, scale=scale)

    if f >= IMPACT - 1:
        burst = 0.5 * max(0.0, 1 - (f - IMPACT) / 40)
        img = screen_blend(img, plate("p3").frame(plate("p3").hit_time + (f - IMPACT) / config.FPS), burst)
        # flash blanc d'une image
        img = img + (1 - img) * 0.12 * max(0.0, 1 - abs(f - IMPACT) / 1.0)
    return np.clip(img, 0, 1).astype(np.float32)


def render(f: float) -> np.ndarray:
    if 100 <= f <= 119:
        return np.clip(motion_blur(_frame, f, samples=4, shutter=0.5), 0, 1).astype(np.float32)
    return _frame(f)
