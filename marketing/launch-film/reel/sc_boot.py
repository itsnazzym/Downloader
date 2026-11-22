"""0-4 s : le point rouge bat, la grille s'allume, les moteurs répondent, les 59 points du logo se lèvent du sol."""
import numpy as np

from .core import Cam, H, W, RED, canvas, dots, text
from .ease import in_out_cubic, out_expo, progress
from .world import LOGO, LOGO_STATE, RED_I, floor, logo_colors, logo_world

LOGO_C = (0.0, 30.0, 1500.0)
LOG = [("yt-dlp", 20), ("gallery-dl", 32), ("aria2c", 44), ("ffmpeg", 56)]
_rng = np.random.default_rng(11)
_START = np.c_[_rng.uniform(-1300, 1300, len(LOGO)), np.full(len(LOGO), 430.0), _rng.uniform(1900, 4200, len(LOGO))]
_ORDER = np.argsort(np.hypot(_START[:, 0], _START[:, 2] - 1500))
_T0 = np.empty(len(LOGO))
_T0[_ORDER] = 46 + np.arange(len(LOGO)) * 0.55
DUR = 22.0


def travel(f: float) -> float:
    return 6.0 * f + 0.45 * max(0.0, f - 84) ** 2


def cam_at(f: float) -> Cam:
    push = in_out_cubic(progress(f, 96, 120))
    return Cam(f=1300 * (1 + 0.12 * push), pos=(0, -30, -60 * push), pitch=-7 + 3 * push)


def logo_points(f: float):
    """Positions monde des points du logo (vol bézier du sol vers la grille)."""
    tgt = logo_world(LOGO_C)
    t = np.clip((f - _T0) / DUR, 0, 1)
    e = np.array([in_out_cubic(x) for x in t])[:, None]
    mid = np.c_[_START[:, 0] * 0.6 + tgt[:, 0] * 0.4, np.full(len(LOGO), -380.0), (_START[:, 2] + tgt[:, 2]) / 2]
    p = (1 - e) ** 2 * _START + 2 * (1 - e) * e * mid + e ** 2 * tgt
    p[RED_I] = tgt[RED_I]
    return p, t


def render(f: float) -> np.ndarray:
    img = canvas()
    cam = cam_at(f)
    waves = [(0, 1500, f - b, 0.55) for b in range(0, 120, 15) if f >= b]
    img = floor(img, cam, travel(f), alpha=progress(f, 4, 26), waves=waves,
                streak=max(0.0, f - 94) * 16)
    # points du logo : traînée de 4 sous-positions
    pts, t = logo_points(f)
    vis = (t > 0) | (np.arange(len(LOGO)) == RED_I)
    cols = logo_colors()
    for k, (dt, a) in enumerate(((3.0, 0.18), (2.0, 0.3), (1.0, 0.5), (0.0, 1.0))):
        p, tt = logo_points(f - dt)
        uv, d = cam.project(p)
        al = a * np.clip(tt * 4, 0, 1)
        al[RED_I] = a if k == 3 else 0
        m = vis & (al > 0.01)
        r = cam.f * 26 / d[m]
        img = dots(img, uv[m, 0], uv[m, 1], r, cols[m] * al[m, None], glow=0.5 if k == 3 else 0, mode="max")
    # battement du point rouge (un temps = 15 images)
    pulse = np.exp(-(f % 15) / 3.5)
    uv, d = cam.project(pts[RED_I:RED_I + 1])
    a = progress(f, 0, 6)
    img = dots(img, uv[:, 0], uv[:, 1], cam.f * 26 / d * (1 + 0.25 * pulse), np.array(RED) * a, glow=0.8 + pulse, mode="max")
    # journal des moteurs (bas gauche)
    for i, (name, t0) in enumerate(LOG):
        if f < t0:
            continue
        n = int((f - t0) * 1.4)
        y = 900 + i * 34
        fade = 1 - progress(f, 100, 116)
        img = text(img, name[:n], 22, 140 + len(name[:n]) * 6.6, y, "mono", 0.75 * fade, (160, 160, 168), 0)
        if f > t0 + 8:
            img = text(img, "prêt", 22, 330, y, "mono", fade * out_expo(progress(f, t0 + 8, t0 + 12)), (236, 236, 234), 0)
        img = dots(img, [116], [y + 1], 4.5, np.array(RED if f < t0 + 8 else (236, 236, 234)) * fade)
    return img
