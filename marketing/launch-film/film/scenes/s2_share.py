"""S2 Partage (images 120–329) : carton cinétique, puis le téléphone claque et le flux d'ajout se déroule."""
import numpy as np

from .. import config
from ..assets import load_screen
from ..ease import in_out_cubic, out_expo, progress, spring
from ..fx import motion_blur, plate, screen_blend
from ..typo import COPY_SIZES, kinetic, kinetic_lines, over_rgba
from .stage import as_f, compose_phone, place_phone, ripple, slide_screens

G0 = 120
V = config.VERTICAL
PH = 1250 if V else 880
PY = 880 if V else 560   # ligne de centre du téléphone
SLAM, SHEET, TAP, PROG, SW2, WHIP = 45, 60, 105, 120, 165, 195
TAPS = (TAP,)              # un seul tap : « Télécharger » (cue global 225)
DL_BTN = (913, 2031)       # bouton « Télécharger » de la feuille d'ajout


def _screen(f: float) -> np.ndarray:
    # partage depuis une autre app → la feuille d'ajout monte toute seule, puis un tap
    s = as_f(load_screen("share"))
    if f >= SHEET:
        cap = ripple(load_screen("capture"), *DL_BTN, progress(f, TAP, TAP + 12))
        s = slide_screens(s, cap, out_expo(progress(f, SHEET, SHEET + 8)), offset=900)
    if f >= PROG:
        s = slide_screens(s, load_screen("done"), out_expo(progress(f, PROG, PROG + 8)), offset=140)
    if f >= SW2:
        s = slide_screens(s, load_screen("library"), out_expo(progress(f, SW2, SW2 + 8)), offset=140)
    return s


def _frame(f: float) -> np.ndarray:
    gf = G0 + f
    t = gf / config.FPS
    img = np.zeros((config.H, config.W, 3), np.float32)
    streaks = 0.32 * (1 - progress(f, 40, 55)) + 0.12 * progress(f, 45, 60)
    img = screen_blend(img, plate("p2").frame(t), streaks)

    # carton « Partage. Un tap. »
    if f < 46:
        lift = in_out_cubic(progress(f, 30, 45))
        if V:
            layer = kinetic_lines([["Partage."], ["Un", "tap."]], f, 210, y=PY - 150 - lift * 90, line_gap=230, per_word=4)
        else:
            layer = kinetic(config.COPY["share"].split(), f, COPY_SIZES["share"], per_word=4, y=540 - lift * 90)
        img = over_rgba(img, layer, alpha=1 - lift)

    # téléphone
    if f >= SLAM - 3:
        k = spring(progress(f, SLAM - 3, SLAM + 12), freq=2.0, damping=0.55)
        cy = -600 + (PY + 600) * k
        rz = -6 * (1 - k)
        ry = 8 + (-4 - 8) * in_out_cubic(progress(f, SLAM, WHIP))
        cx = config.W / 2 - (2000 if V else 2400) * in_out_cubic(progress(f, WHIP, 209)) ** 1.5
        sc = 1.0 + 0.04 * in_out_cubic(progress(f, SLAM, WHIP))
        ph = compose_phone(_screen(f), PH)
        img = place_phone(img, ph, cx, cy, sc, rot_y_deg=ry, rot_z_deg=rz)

    if SLAM - 1 <= f < SLAM + 20:
        img = screen_blend(img, plate("p3").frame(plate("p3").hit_time + (f - SLAM) / config.FPS), 0.22)
    # anneau blanc à la validation
    if SW2 <= f < SW2 + 24:
        u = progress(f, SW2, SW2 + 24)
        r = (330 if V else 480) + (400 if V else 520) * out_expo(u)
        yy, xx = np.ogrid[0:config.H, 0:config.W]
        d = np.sqrt((xx - config.W / 2) ** 2 + ((yy - float(PY)) * 1.0) ** 2)
        ring = np.exp(-((d - r) / 4) ** 2) * (1 - u) ** 1.5 * 0.6
        img = img + (1 - img) * ring[..., None].astype(np.float32)
    return np.clip(img, 0, 1).astype(np.float32)


def render(f: float) -> np.ndarray:
    if SLAM - 3 <= f <= SLAM + 8 or f >= WHIP:
        return np.clip(motion_blur(_frame, f, samples=5, shutter=0.5), 0, 1).astype(np.float32)
    return _frame(f)
