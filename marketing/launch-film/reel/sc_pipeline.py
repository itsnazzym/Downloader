"""14-20 s : le téléchargement. Compteur LED, barre de points, chaîne yt-dlp → aria2c → ffmpeg → appareil."""
import numpy as np

from .core import (RED, WHITE, OFF, Cam, H, W, bezier, canvas, dir_blur, dots, draw_phone, halftone, led_text,
                   line, radial, ring, rrect, text_at)
from .ease import in_out_cubic, out_back, out_expo, progress
from .world import floor

CAM = Cam(f=1500)
FLOOR_Y = 575.0
NODES = (("yt-dlp", "extraction"), ("aria2c", "segments parallèles"), ("ffmpeg", "assemblage"),
         ("Fichier", "sur l'appareil"))
NX = (1100.0, 1320.0, 1540.0, 1760.0)
NY, NW_, NH_ = 655.0, 176.0, 84.0
ACT = (30, 45, 60, 75)
DONE = 140


def pct(f: float) -> int:
    t = progress(f, 20, DONE)
    return int(round(100 * (0.5 - 0.5 * np.cos(np.pi * t)) ** 0.9))


def pose(f: float):
    e = out_expo(progress(f, 0, 16))
    x = -2400 + (2400 - 600) * e
    return (x, 10 + 5 * np.sin(f / 17), 2150), 30 - 8 * in_out_cubic(progress(f, 0, 180)) + 40 * (1 - e), -3


def render(f: float) -> np.ndarray:
    img = canvas()
    img = img + radial(560, 560, 800, (255, 255, 255), 2.4) * 0.05
    img = img + radial(1430, 500, 900, RED, 2.6) * 0.06 * progress(f, 20, 40)
    img = floor(img, CAM, 520 + 9 * f, y=FLOOR_Y, alpha=0.6,
                waves=[(-600, 2150, f - b, 0.35) for b in ACT + (DONE,) if f >= b])
    pos, yaw, pitch = pose(f)
    info = draw_phone(img, "done", pos, yaw, pitch, cam=CAM, reflect=0.3, floor_y=540 + CAM.f * FLOOR_Y / pos[2] - 6)
    p = pct(f)
    done = f >= DONE
    flash = np.exp(-(f - DONE) / 5) if done else 0.0
    # titre + compteur LED
    ta = out_expo(progress(f, 8, 18))
    img, _ = text_at(img, "Terminé" if done else "Téléchargement", 28, 1012, 225, "left", "dmedium", ta, (175, 175, 182), 0)
    s = f"{p:3d}%"

    def on_alpha(cells, xs, ys):
        return np.full(len(cells), ta)
    img = led_text(img, s, 1012 + (len(s) * 6 - 1) * 9.5, 345, 19, on_alpha=on_alpha, off_alpha=ta,
                   glow=0.7 + 2 * flash, red_index=None)
    # barre de progression en points (le point de tête est rouge, comme dans l'app)
    n = 40
    xs = 1012 + np.arange(n) * 20.5
    lit = p / 100 * n
    a = np.clip(lit - np.arange(n), 0, 1) * ta
    img = dots(img, xs, np.full(n, 455), 6, np.array(OFF)[None] * 1.6 * ta)
    col = np.tile(np.array(WHITE, float), (n, 1))
    head = int(min(n - 1, np.floor(lit)))
    if not done and lit > 0:
        col[head] = RED
    img = dots(img, xs, np.full(n, 455), 6.5, col * a[:, None], glow=0.6)
    # chaîne de traitement
    for i, ((name, cap), x) in enumerate(zip(NODES, NX)):
        k = progress(f, ACT[i] - 6, ACT[i] + 6)
        if k <= 0:
            continue
        on = f >= ACT[i]
        sc = out_back(k) if k < 1 else 1.0
        hw, hh = NW_ / 2 * sc, NH_ / 2 * sc
        c = (255, 255, 255) if on else (90, 90, 96)
        img = rrect(img, x - hw, NY - hh, x + hw, NY + hh, 18 * sc, c, 2, min(1, k * 2), fill=(14, 14, 16))
        img, _ = text_at(img, name, 30, x, NY, "center", "semibold", min(1, k * 2), c, -0.01)
        img, _ = text_at(img, cap, 19, x, NY + 72, "center", "regular", min(1, k * 2) * 0.9, (150, 150, 158), 0)
        if on:
            pp = progress(f, ACT[i], ACT[i] + 16)
            img = ring(img, x, NY, 60 + 90 * out_expo(pp), 2, (255, 255, 255), (1 - pp) * 0.8, sy=0.55, glow=0.5)
        if i > 0 and f >= ACT[i]:
            x0, x1 = NX[i - 1] + NW_ / 2 + 4, x - NW_ / 2 - 4
            lanes = (-15, -5, 5, 15) if i == 1 else (0,)
            for j, oy in enumerate(lanes):
                img = line(img, (x0, NY + oy), (x1, NY + oy), (80, 80, 86), 1)
                if not done or f < DONE + 20:
                    ph = ((f - ACT[i]) * 0.09 + np.arange(3) / 3 + j * 0.21) % 1
                    px = x0 + (x1 - x0) * ph
                    img = dots(img, px, np.full(3, NY + oy), 3.2, np.array((255, 255, 255)) * 0.95, glow=0.8, mode="add")
    # le fichier arrive dans le téléphone : flux de points le long d'une courbe
    tgt = info["map"](585, 1300)
    src = (NX[3], NY + NH_ / 2 + 4)
    ctrl = ((src[0] + tgt[0]) / 2 + 150, 1080)
    if 96 <= f < DONE + 26:
        m = 70
        t = ((f - 96) * 0.03 + np.arange(m) / m) % 1
        emitted = (f - 96) * 0.03 > np.arange(m) / m - 0.0
        stop = np.clip(1 - (f - DONE) / 26, 0, 1) if done else 1
        pts = bezier(src, ctrl, tgt, t)
        a = np.sin(np.pi * t) * emitted * stop
        col = np.where((np.arange(m) % 9 == 0)[:, None], np.array(RED)[None], np.array((255, 255, 255))[None])
        img = dots(img, pts[:, 0], pts[:, 1], 3 + 2 * np.sin(np.pi * t), col * a[:, None], glow=0.9, mode="add")
    if done:
        img = ring(img, tgt[0], tgt[1], 30 + 400 * out_expo(progress(f, DONE, DONE + 22)), 3, (255, 255, 255),
                   (1 - progress(f, DONE, DONE + 22)), glow=0.8)
    if f < 8:
        img = dir_blur(img, 220 * (1 - f / 8) ** 2, 0)
    return halftone(img, progress(f, 164, 180), 24)
