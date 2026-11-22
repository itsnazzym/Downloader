"""30-36 s : rafale typographique sur chaque temps, puis mur de neuf écrans, stutter et arrêt de bande."""
import math

import numpy as np

from .core import (RED, Cam, H, W, canvas, cv2, dots, draw_phone, led_text, text_at, text_layer)
from .ease import in_out_cubic, out_expo, progress
from .timeline import STUTTER

# (texte, style, alignement, sous-titre) ; style : "dark" | "light" | "led"
CARDS = (("Open source", "dark", "left", None),
         ("Licence MIT", "light", "center", None),
         ("Zéro pub", "dark", "right", None),
         ("Zéro pisteur", "light", "left", None),
         ("ANDROID", "led", "center", None),
         ("WINDOWS", "led", "center", None),
         ("Chrome", "dark", "center", "Extension navigateur"),
         ("Firefox", "light", "center", "Extension navigateur"))
WALL = ("browser", "capture", "done", "library", "stats", "send", "archive", "settings", "share")
WALL_START = 120
_rng = np.random.default_rng(23)


def _card(f: float, i: int) -> np.ndarray:
    word, style, align, sub = CARDS[i]
    t = f - i * 15
    light = style == "light"
    img = canvas(0.93 if light else 0.0)
    k = out_expo(progress(t, 0, 7))
    sc = 1.12 - 0.12 * k
    drift = 10 * t
    ink = (12, 12, 14) if light else (255, 255, 255)
    if style == "led":
        img = led_text(img, word, 960 + drift * 0.3, 520, 30 * sc, glow=0.8)
        img, _ = text_at(img, "Disponible sur", 30, 960, 340, "center", "dmedium", k, (170, 170, 178), 0)
        return img
    size = 210
    lay = text_layer(word, size, "black", -0.045, ink)
    w = lay.shape[1] * sc
    x = {"left": 130 + w / 2, "center": 960, "right": 1790 - w / 2 - 40}[align] + (drift if align != "right" else -drift)
    y = 520 if sub is None else 480
    from .core import paste
    img = paste(img, lay, x, y, scale=sc)
    # point final rouge, signature du logo
    img = dots(img, [x + w / 2 + 16 * sc], [y + 0.30 * size * sc], 20 * sc, np.array(RED), glow=0 if light else 0.5,
               mode="over")
    if sub:
        img, _ = text_at(img, sub, 36, 960, 650, "center", "dmedium", k, (120, 120, 126) if light else (175, 175, 182), 0)
    return img


def _glitch(img: np.ndarray, f: int, amount: float) -> np.ndarray:
    rng = np.random.default_rng(int(f) * 31 + 1)
    out = img.copy()
    for _ in range(9):
        y0 = int(rng.integers(0, H - 40))
        h = int(rng.integers(8, 90))
        dx = int(rng.integers(-90, 90) * amount)
        out[y0:y0 + h] = np.roll(img[y0:y0 + h], dx, axis=1)
    px = int(14 * amount)
    if px:
        out[:, px:, 0] = out[:, :-px, 0]
        out[:, :-px, 2] = out[:, px:, 2]
    return out


def _wall(f: float) -> np.ndarray:
    img = canvas()
    t = f - WALL_START
    dolly = in_out_cubic(progress(t, 0, 44))
    cam = Cam(f=1400, pos=(0, 0, -900 + 1500 * dolly), yaw=-8 + 10 * dolly, pitch=4 - 4 * dolly, roll=-4 + 4 * dolly)
    R = 0
    items = []
    for i, key in enumerate(WALL):
        r, c = divmod(i, 3)
        P = np.array([(c - 1) * 680.0, (r - 1) * 1230.0, 3200.0])
        flip = out_expo(progress(t, abs(r - 1) * 2 + abs(c - 1) * 2, abs(r - 1) * 2 + abs(c - 1) * 2 + 10))
        items.append((np.linalg.norm(P - cam.pos), key, P, 90 * (1 - flip), flip))
    for _, key, P, yaw, fl in sorted(items, key=lambda x: -x[0]):
        if fl > 0:
            draw_phone(img, key, P, yaw, 0, cam=cam, alpha=fl, gloss=0.2)
    return img


def render(f: float) -> np.ndarray:
    gf = 900 + f
    # stutter : on répète l'image du dernier coup pendant 2 images, avec glitch
    st = [s for s in STUTTER if 0 <= gf - s < 2]
    if st:
        f = st[0] - 900 - 3
    # arrêt de bande : le temps ralentit puis s'arrête
    tape = progress(f, 162, 180)
    if tape > 0:
        f = 162 + 10 * (1 - (1 - tape) ** 2)
    if f < WALL_START:
        img = _card(f, min(len(CARDS) - 1, int(f // 15)))
        loc = f % 15
        if loc < 2:
            img = _glitch(img, int(f), 1 - loc / 2)
    else:
        img = _wall(f)
    if st:
        img = _glitch(img, gf, 1.0)
    if tape > 0:
        # la bande ralentit : l'image se tasse, s'assombrit et se resserre sur le point rouge
        s = 1 - 0.35 * tape ** 2
        M = np.float32([[s, 0, 960 * (1 - s)], [0, s * (1 - 0.6 * tape ** 3), 540 * (1 - s * (1 - 0.6 * tape ** 3))]])
        img = cv2.warpAffine(img, M, (W, H)) * (1 - tape) ** 1.5
        img = dots(img, [960], [540], 8 + 10 * tape, np.array(RED) * progress(tape, 0.55, 0.9), glow=1.2)
    return img
