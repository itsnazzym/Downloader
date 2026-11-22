"""36-40 s : le point rouge éclate, les 59 points reviennent en ressort former le logo, puis le nom et le lien."""
import numpy as np

from .core import RED, Cam, canvas, dots, radial, ring, text_at, text_layer, paste
from .ease import out_expo, progress, spring
from .world import LOGO, LOGO_CR, RED_I, floor, logo_colors

PITCH = 32.0
LC = (960.0, 360.0)
TGT = np.c_[LC[0] + (LOGO_CR[:, 0] - 3) * PITCH, LC[1] + (LOGO_CR[:, 1] - 4) * PITCH]
_rng = np.random.default_rng(5)
_ANG = _rng.uniform(0, 2 * np.pi, len(LOGO))
_BURST = np.c_[np.cos(_ANG), np.sin(_ANG)] * _rng.uniform(380, 760, (len(LOGO), 1)) + [960, 540]
_DEL = _rng.uniform(4, 11, len(LOGO))
FCAM = Cam(f=1300, pos=(0, -30, 0), pitch=-7)


def pos_at(f: float) -> np.ndarray:
    out = np.zeros((len(LOGO), 2))
    for i in range(len(LOGO)):
        b = out_expo(progress(f, 0, 6))
        burst = np.array([960, 540]) + (_BURST[i] - [960, 540]) * b
        back = spring(progress(f, _DEL[i], _DEL[i] + 26), freq=1.7, damping=0.42)
        out[i] = burst + (TGT[i] - burst) * back
    out[RED_I] = np.array([960, 540]) + (TGT[RED_I] - [960, 540]) * spring(progress(f, 2, 26), 1.5, 0.45)
    return out


def render(f: float) -> np.ndarray:
    img = canvas()
    fade = 1 - progress(f, 102, 119)
    img = floor(img, FCAM, 4 * f, alpha=0.7 * fade, waves=[(0, 1500, f, 1.0), (0, 1500, f - 30, 0.4)])
    img = img + radial(960, 380, 700, RED, 2.2) * 0.12 * np.exp(-f / 20) * fade
    for d, a in ((0, 1.0), (3, 0.7), (7, 0.4)):
        p = progress(f - d, 0, 28)
        if 0 < p < 1:
            img = ring(img, 960, 540, 20 + 1300 * out_expo(p), 7 * (1 - p) + 1, (255, 255, 255), a * (1 - p) ** 1.6, glow=0.8)
    cols = logo_colors(fade)
    for dt, al in ((2.0, 0.22), (1.0, 0.45), (0.0, 1.0)):
        p = pos_at(f - dt)
        img = dots(img, p[:, 0], p[:, 1], PITCH * 0.4, cols * al, glow=0.55 if al == 1 else 0)
    # nom, accroche, lien
    k1 = out_expo(progress(f, 26, 40))
    lay = text_layer("TapLoad", 104, "black", -0.04, (255, 255, 255))
    img = paste(img, lay, 960, 690 + 30 * (1 - k1), alpha=k1 * fade)
    k2 = out_expo(progress(f, 36, 48)) * fade
    img, _ = text_at(img, "Android  ·  Windows  ·  Open source", 32, 960, 780, "center", "dmedium", k2, (178, 178, 186), 0.01)
    url = "github.com/itsnazzym/Downloader"
    n = int(np.clip((f - 50) * 1.6, 0, len(url)))
    if n:
        img, w = text_at(img, url[:n], 26, 960 - text_layer(url, 26, "mono", 0, (255, 255, 255)).shape[1] / 2, 860,
                         "left", "mono", fade, (236, 236, 234), 0)
    k3 = progress(f, 64, 76) * fade
    img, _ = text_at(img, "Musique : « Electron Wake », Hardcore Scm (CC BY 3.0)   ·   Big Buck Bunny © Blender Foundation (CC BY 3.0)", 18, 960, 1030, "center", "regular", 0.8 * k3,
                     (130, 130, 136), 0)
    return img
