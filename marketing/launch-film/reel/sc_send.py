"""20-24 s (pont) : deux téléphones, orbite de caméra, flux de points de l'un à l'autre, anneaux radar au sol."""
import math

import numpy as np

from .core import (RED, Cam, H, W, bezier, canvas, dots, draw_phone, floor_ring, halftone, radial, text_at)
from .ease import in_out_cubic, out_expo, progress
from .world import floor

PIV = np.array([0.0, 0.0, 2350.0])
FLOOR_Y = 560.0
L_POS, R_POS = np.array([-520.0, 0, 2350]), np.array([520.0, 0, 2350])


def cam_at(f: float) -> Cam:
    phi = -13 + 24 * in_out_cubic(progress(f, 0, 120))
    dist = 2750 - 420 * in_out_cubic(progress(f, 96, 120)) ** 2
    a = math.radians(phi)
    pos = PIV - dist * np.array([math.sin(a), 0, math.cos(a)]) + np.array([0, -40, 0])
    return Cam(f=1450, pos=pos, yaw=phi, pitch=-2.0, shift=(0, 70))


def render(f: float) -> np.ndarray:
    cam = cam_at(f)
    img = canvas()
    img = img + radial(960, 600, 1000, (255, 255, 255), 2.6) * 0.05
    img = floor(img, cam, 0, y=FLOOR_Y, alpha=0.75)
    for b in range(0, 120, 15):
        age = f - b
        if 0 <= age < 40:
            img = floor_ring(img, cam, L_POS[0], L_POS[2], 260 + age * 26, FLOOR_Y, (1 - age / 40) ** 1.5 * 0.8)
    fy = lambda z: 540 + cam.f * (FLOOR_Y - cam.pos[1]) / max(z - cam.pos[2], 1) - 6
    # ordre de dessin : le plus loin d'abord
    phones = [("send", L_POS, 24), ("library", R_POS, -24)]
    phones.sort(key=lambda p: -np.linalg.norm(p[1] - cam.pos))
    for key, P, yaw in phones:
        draw_phone(img, key, P, yaw, -2, cam=cam, reflect=0.32, floor_y=fy(P[2]))
    # flux de points en arc
    if f >= 14:
        m = 36
        t = ((f - 14) * 0.016 + np.arange(m) / m) % 1
        born = (f - 14) * 0.016 >= np.arange(m) / m
        p0, p2 = L_POS + [60, -180, -40], R_POS + [-60, -180, -40]
        p1 = (p0 + p2) / 2 + [0, -600, -120]
        acc = img
        for dt, al in ((0.012, 0.25), (0.006, 0.5), (0.0, 1.0)):
            pts = bezier(p0, p1, p2, np.clip(t - dt, 0, 1))
            uv, d = cam.project(pts)
            a = np.sin(np.pi * t) ** 0.6 * born * al
            col = np.where((np.arange(m) % 11 == 0)[:, None], np.array(RED)[None], np.array((255, 255, 255))[None])
            acc = dots(acc, uv[:, 0], uv[:, 1], cam.f * 7 / d, col * a[:, None], glow=0.9 if al == 1 else 0, mode="add")
        img = acc
    # titre
    words = (("Envoi local.", 6), ("Sans câble.", 36))
    x = 960
    for i, (wd, t0) in enumerate(words):
        k = out_expo(progress(f, t0, t0 + 12)) * (1 - progress(f, 100, 112))
        if k <= 0:
            continue
        img, _ = text_at(img, wd, 92, 952 if i == 0 else 968, 128 + 30 * (1 - k), "right" if i == 0 else "left",
                         "black", k, (255, 255, 255), -0.035)
    k = out_expo(progress(f, 52, 64)) * (1 - progress(f, 100, 112))
    img, _ = text_at(img, "Sur le réseau local, par QR code ou adresse IP.", 28, 960, 1010, "center", "dmedium", k,
                     (170, 170, 178), 0)
    # montée vers le drop
    w = progress(f, 108, 120)
    if w > 0:
        img = img + radial(960, 520, 300 + 1700 * w ** 2, (255, 255, 255), 1.5) * w ** 3 * 0.8
    return halftone(img, 1 - progress(f, 0, 14), 24, -1)
