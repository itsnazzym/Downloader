"""Drop 2 (24-30 s) : carrousel 3D de six écrans, un cran tous les deux temps, sol miroir et profondeur de champ."""
import math

import numpy as np

from .core import RED, Cam, canvas, dir_blur, draw_phone, floor_ring, radial, ring, shake, text_at
from .ease import out_back, out_expo, progress
from .world import floor

SCREENS = (("browser", "Navigateur", "Capture la vidéo de la page ouverte."),
           ("library", "Bibliothèque", "Chaque téléchargement, suivi en direct."),
           ("send", "Envoi", "D'un appareil à l'autre, sans câble."),
           ("archive", "Archive TikTok", "Importe l'export JSON de tes favoris."),
           ("stats", "Statistiques", "Volume, activité et sources."),
           ("settings", "Réglages", "yt-dlp à jour, téléchargements en parallèle."))
C = np.array([0.0, 0.0, 3800.0])
RC = 1700.0
FLOOR_Y = 575.0
SNAPS = tuple(30 * k for k in range(1, 6))


def rotation(f: float) -> float:
    r = -300 * (1 - out_expo(progress(f, 0, 26)))
    for s in SNAPS:
        r += 60 * out_back(progress(f, s, s + 13), 1.4)
    return r


def render(f: float) -> np.ndarray:
    sx, sy = shake(720 + f, 22)
    cam = Cam(f=1300, pos=(0, -190, 0), pitch=-4.0, shift=(sx, sy - 95))
    img = canvas()
    img = img + radial(960, 470, 1100, (255, 255, 255), 2.4) * 0.07
    img = img + radial(960, 560, 800, RED, 2.0) * 0.08 * np.exp(-(f % 30) / 8)
    img = floor(img, cam, 0, y=FLOOR_Y, alpha=0.8, waves=[(0, C[2] - RC, f - s, 0.6) for s in (0,) + SNAPS if f >= s])
    img = floor_ring(img, cam, C[0], C[2], RC + 120, FLOOR_Y, 0.35)
    rot = rotation(f)
    items = []
    for i, (key, _, _) in enumerate(SCREENS):
        th = math.radians(i * 60 - rot)
        P = C + np.array([RC * math.sin(th), 0, -RC * math.cos(th)])
        items.append((np.linalg.norm(P - cam.pos), key, P, -math.degrees(th), math.cos(th)))
    for dist, key, P, yaw, c in sorted(items, key=lambda t: -t[0]):
        blur = float(np.clip((dist - 2250) / 450, 0, 3.2))
        fy = 540 + cam.shift[1] + cam.f * (FLOOR_Y - cam.pos[1]) / (P[2] - cam.pos[2]) - 8
        draw_phone(img, key, P, yaw, 0, cam=cam, blur=blur, alpha=0.55 + 0.45 * max(0, c),
                   reflect=0.3 * max(0, c), floor_y=fy, thick=52)
    # flou de bougé horizontal pendant les crans
    spd = rotation(f + 0.5) - rotation(f - 0.5)
    img = dir_blur(img, min(220, abs(spd) * 9), 0)
    if f < 20:
        p = progress(f, 0, 20)
        img = ring(img, 960, 600, 60 + 1400 * out_expo(p), 6 * (1 - p) + 1, (255, 255, 255), (1 - p) ** 1.4, sy=0.35)
    # légende de l'écran au premier plan
    idx = int(round(rot / 60)) % 6
    last = max([0] + [s for s in SNAPS if f >= s + 6])
    k = out_expo(progress(f, last + 6 if last else 16, (last + 6 if last else 16) + 10))
    _, name, desc = SCREENS[idx]
    if k > 0:
        img, _ = text_at(img, f"0{idx + 1} / 06", 22, 960, 898 + 10 * (1 - k), "center", "mono", k, RED, 0.05)
        img, _ = text_at(img, name, 60, 960, 948 + 18 * (1 - k), "center", "black", k)
        img, _ = text_at(img, desc, 27, 960, 1008 + 18 * (1 - k), "center", "dmedium", k * 0.95, (175, 175, 182), 0)
    return img
