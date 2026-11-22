"""Décor commun : sol de points en perspective (fil rouge visuel du film) et logo en 3D."""
import numpy as np

from film import assets

from .core import RED, WHITE, OFF, Cam, cv2, dots, H, W

LOGO = assets.logo_grid()
LOGO_STATE = np.array([{"off": 0, "on": 1, "red": 2}[d.state] for d in LOGO])
LOGO_CR = np.array([(d.col, d.row) for d in LOGO], np.float64)
RED_I = int(np.flatnonzero(LOGO_STATE == 2)[0])


def logo_world(center=(0.0, -40.0, 1500.0), pitch=70.0) -> np.ndarray:
    cx, cy, cz = center
    return np.c_[cx + (LOGO_CR[:, 0] - 3) * pitch, cy + (LOGO_CR[:, 1] - 4) * pitch, np.full(len(LOGO), cz)]


def logo_colors(alpha=1.0, off_level=1.6):
    c = np.zeros((len(LOGO), 3))
    c[LOGO_STATE == 0] = np.array(OFF) * off_level
    c[LOGO_STATE == 1] = WHITE
    c[LOGO_STATE == 2] = RED
    return c * np.broadcast_to(np.atleast_1d(alpha), (len(LOGO),))[:, None]


def floor(img, cam: Cam, travel=0.0, y=430.0, step=170.0, alpha=1.0, waves=(), streak=0.0,
          xr=4400.0, zr=(260.0, 9800.0), level=0.26, color=(205, 205, 212)):
    """Plan de points infini qui défile vers la caméra. waves : (x, z, âge en images, amplitude)."""
    if alpha <= 0:
        return img
    xs = np.arange(-xr, xr + 1, step)
    zs = np.arange(zr[0], zr[1], step) - (travel % step) + step
    X, Z = np.meshgrid(xs, zs)
    X, Z = X.ravel(), Z.ravel()
    P = np.c_[X, np.full(len(X), y), Z]
    uv, d = cam.project(P)
    keep = (d > 120) & (uv[:, 0] > -40) & (uv[:, 0] < W + 40) & (uv[:, 1] > -40) & (uv[:, 1] < H + 40)
    X, Z, uv, d = X[keep], Z[keep], uv[keep], d[keep]
    fog = np.clip(1 - (d - 300) / (zr[1] - 900), 0, 1) ** 1.7 * np.clip((d - 160) / 500, 0, 1)
    b = level * fog
    for (ox, oz, age, amp) in waves:
        if age < 0:
            continue
        r = np.hypot(X - ox, Z - oz)
        front = 90 + age * 95
        b = b + amp * np.exp(-((r - front) / 210) ** 2) * fog * np.exp(-age / 26)
    b = np.clip(b * alpha, 0, 1.4)
    rad = np.clip(cam.f * 7.0 / d, 0.55, 3.2)
    if streak > 0:
        P2 = np.c_[X, np.full(len(X), y), Z + streak]
        uv2, _ = cam.project(P2)
        layer = np.zeros((H, W, 3), np.uint8)
        for (x0, y0), (x1, y1), bb, rr in zip(uv, uv2, b, rad):
            c = int(min(255, 150 * bb))
            if c < 3:
                continue
            cv2.line(layer, (int(x0 * 16), int(y0 * 16)), (int(x1 * 16), int(y1 * 16)), (c, c, c),
                     max(1, int(rr)), cv2.LINE_AA, 4)
        img = img + layer.astype(np.float32) / 255
    return dots(img, uv[:, 0], uv[:, 1], rad, np.array(color)[None] * b[:, None], mode="add")
