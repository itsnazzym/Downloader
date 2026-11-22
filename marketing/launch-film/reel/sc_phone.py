"""8-14 s : le téléphone entre en 3D ; des annotations suivent l'écran en temps réel ; tap sur Télécharger."""
import numpy as np

from .core import RED, Cam, H, W, canvas, cv2, dir_blur, dots, draw_phone, line, radial, ring, text_at
from .ease import in_out_cubic, out_back, out_expo, progress, spring
from .world import floor

CAM = Cam(f=1500)
FLOOR_Y = 575.0
# (image d'apparition, point dans la capture, côté, position du libellé, numéro, texte)
CALLOUTS = (
    (15, (585, 355), "right", (1360, 260), "01", "Un lien, ou le menu Partager"),
    (45, (585, 815), "left", (600, 430), "02", "Vidéo ou audio seul"),
    (75, (300, 1015), "left", (600, 590), "03", "Jusqu'à la qualité max."),
    (105, (985, 1015), "right", (1360, 640), "04", "Taille connue d'avance"),
)
TAP_F, TAP_UV = 135, (915, 2030)


def pose(f: float):
    e = spring(progress(f, 0, 34), freq=1.6, damping=0.45)
    y = 1500 * (1 - e) + 6 * np.sin(f / 18)
    yaw = 62 * (1 - out_expo(progress(f, 0, 30))) - 20 + 38 * in_out_cubic(progress(f, 26, 170))
    pitch = 28 * (1 - out_expo(progress(f, 0, 26))) - 4 + 6 * in_out_cubic(progress(f, 26, 170))
    z = 2600 - 550 * out_expo(progress(f, 0, 30))
    press = np.exp(-max(0.0, f - TAP_F) / 4) * 40 if f >= TAP_F else 0
    x = -80.0
    w = in_out_cubic(progress(f, 158, 180))
    x -= 2600 * w ** 1.6
    yaw -= 45 * w
    return (x, y, z + press), yaw, pitch


def render(f: float) -> np.ndarray:
    img = canvas()
    img = img + radial(900, 520, 900, (255, 255, 255), 2.4) * 0.07
    img = floor(img, CAM, 9 * f, y=FLOOR_Y, alpha=0.65, waves=[(-80, 2050, f - b, 0.4) for b in (15, 45, 75, 105, TAP_F) if f >= b])
    pos, yaw, pitch = pose(f)
    info = draw_phone(img, "capture", pos, yaw, pitch, cam=CAM, reflect=0.3,
                      floor_y=540 + CAM.f * FLOOR_Y / pos[2] - 6)
    m = info["map"]
    out = 1 - progress(f, 126, 140)
    for t0, uv, side, (lx, ly), num, label in CALLOUTS:
        if f < t0 or out <= 0:
            continue
        ax, ay = m(*uv)
        k = out_expo(progress(f, t0, t0 + 10))
        ex = lx + (60 if side == "left" else -60)
        # ligne à coude : ancre → coude → libellé, tracée progressivement
        seg1 = (ax + (ex - ax) * min(1, k * 1.6), ay + (ly - ay) * min(1, k * 1.6))
        img = line(img, (ax, ay), seg1, (230, 230, 232), 2, out)
        if k > 0.62:
            k2 = (k - 0.62) / 0.38
            end = (ex + ((lx + (12 if side == "left" else -12)) - ex) * k2, ly)
            img = line(img, (ex, ly), end, (230, 230, 232), 2, out)
        pulse = progress(f, t0, t0 + 18)
        img = ring(img, ax, ay, 8 + 36 * out_expo(pulse), 2, (255, 255, 255), (1 - pulse) * out, glow=0.4)
        img = dots(img, [ax], [ay], 7, np.array((255, 255, 255)) * out, glow=0.6)
        t = out_expo(progress(f, t0 + 5, t0 + 14)) * out
        if t > 0:
            dx = (1 - t) * (24 if side == "right" else -24)
            if side == "right":
                img, w = text_at(img, num, 22, lx + dx, ly - 34, "left", "mono", t, RED, 0)
                img, _ = text_at(img, label, 38, lx + dx, ly + 6, "left", "semibold", t)
            else:
                img, w = text_at(img, num, 22, lx + dx, ly - 34, "right", "mono", t, RED, 0)
                img, _ = text_at(img, label, 38, lx + dx, ly + 6, "right", "semibold", t)
    # tap sur Télécharger
    if f >= TAP_F:
        tx, ty = m(*TAP_UV)
        for d in (0, 5):
            p = progress(f, TAP_F + d, TAP_F + d + 20)
            if 0 < p < 1:
                img = ring(img, tx, ty, 20 + 150 * out_expo(p), 3, (255, 255, 255), (1 - p) ** 1.3, glow=0.7)
        fl = np.exp(-(f - TAP_F) / 3)
        img = dots(img, [tx], [ty], 60, np.array((255, 255, 255)) * 0.35 * fl, glow=1.2 * fl, mode="add")
    # entrée : fin du fouet venu de la scène précédente ; sortie : fouet vers la gauche
    if f < 7:
        img = dir_blur(img, 0, 140 * (1 - f / 7) ** 2)
    w = progress(f, 158, 180)
    if w > 0:
        img = dir_blur(img, 260 * np.sin(np.pi * min(1, w * 1.1)), 0)
    return img
