"""Mise en scène 2,5D des téléphones : bezel mis en cache, perspective, contre-jour, ripple de tap."""
import math
from functools import lru_cache

import cv2
import numpy as np

from ..assets import CROP_H, _rrect_mask

SCREEN_W = 1170
FOCAL = 2200.0


@lru_cache(maxsize=16)
def _geom(height: int):
    b = max(2, round(0.016 * height))
    sh = height - 2 * b
    sw = round(sh * SCREEN_W / CROP_H)
    w = sw + 2 * b
    body = _rrect_mask(w, height, 0.13 * w)
    inner = np.zeros_like(body)
    inner[1:-1, 1:-1] = _rrect_mask(w - 2, height - 2, 0.13 * w - 1)
    rim = np.clip(body - inner, 0, 1)[..., None]
    base = np.zeros((height, w, 3), np.float32) + np.array((11, 11, 12), np.float32) / 255
    base = base * (1 - rim) + np.array((58, 58, 64), np.float32) / 255 * rim
    sm = _rrect_mask(sw, sh, 0.11 * sw)[..., None]
    return b, sw, sh, w, body, base, sm


def compose_phone(screen: np.ndarray, height: int) -> np.ndarray:
    """RGBA float32 (h, w, 4) : bezel + écran (screen uint8 ou float, 1170×2395)."""
    b, sw, sh, w, body, base, sm = _geom(int(height))
    scr = screen.astype(np.float32) / 255 if screen.dtype == np.uint8 else screen
    scr = cv2.resize(scr, (sw, sh), interpolation=cv2.INTER_AREA)
    out = np.empty((int(height), w, 4), np.float32)
    out[..., :3] = base
    out[b:b + sh, b:b + sw, :3] = base[b:b + sh, b:b + sw] * (1 - sm) + scr * sm
    out[..., 3] = body
    return out


def as_f(screen: np.ndarray) -> np.ndarray:
    return screen.astype(np.float32) / 255 if screen.dtype == np.uint8 else screen


def slide_screens(a: np.ndarray, b: np.ndarray, t: float, offset: float = 120.0) -> np.ndarray:
    """B monte par-dessus A (feuille modale) : t ∈ [0,1], déjà eased."""
    if t <= 0:
        return as_f(a)
    if t >= 1:
        return as_f(b)
    out = as_f(a).copy()
    dy = int(round((1 - t) * offset))
    bb = as_f(b)
    al = t
    out[dy:] = out[dy:] * (1 - al) + bb[:CROP_H - dy] * al
    return out


def ripple(screen: np.ndarray, x: float, y: float, t: float) -> np.ndarray:
    """Anneau de tap sur la capture (coordonnées 1170×2395), t ∈ [0,1]."""
    if t <= 0 or t >= 1:
        return as_f(screen)
    s = as_f(screen).copy()
    r = 30 + 150 * (1 - (1 - t) ** 3)
    a = (1 - t) ** 1.5
    x0, y0, x1, y1 = int(x - r - 12), int(y - r - 12), int(x + r + 12), int(y + r + 12)
    x0, y0 = max(x0, 0), max(y0, 0)
    x1, y1 = min(x1, s.shape[1]), min(y1, s.shape[0])
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    d = np.hypot(xx - x, yy - y)
    ring = np.exp(-((d - r) / 7) ** 2) * a
    fill = (d < r).astype(np.float32) * 0.18 * a
    v = np.clip(ring + fill, 0, 1)[..., None]
    s[y0:y1, x0:x1] = s[y0:y1, x0:x1] * (1 - v) + v
    return s


def _project(w: float, h: float, cx: float, cy: float, scale: float, ry: float, rz: float) -> np.ndarray:
    pts = []
    cz, sz = math.cos(math.radians(rz)), math.sin(math.radians(rz))
    cyw, syw = math.cos(math.radians(ry)), math.sin(math.radians(ry))
    for X, Y in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)):
        X, Y = X * scale, Y * scale
        X, Y = X * cz - Y * sz, X * sz + Y * cz
        X, Z = X * cyw, X * syw
        k = FOCAL / (FOCAL + Z)
        pts.append((cx + X * k, cy + Y * k))
    return np.float32(pts)


def place_phone(img: np.ndarray, phone_rgba: np.ndarray, cx: float, cy: float, scale: float,
                rot_y_deg: float = 0.0, rot_z_deg: float = 0.0, alpha: float = 1.0,
                backlight: float = 0.10) -> np.ndarray:
    if alpha <= 0 or scale <= 0:
        return img
    h, w = phone_rgba.shape[:2]
    dst = _project(w, h, cx, cy, scale, rot_y_deg, rot_z_deg)
    pad = 90
    x0 = max(0, int(dst[:, 0].min()) - pad)
    y0 = max(0, int(dst[:, 1].min()) - pad)
    x1 = min(img.shape[1], int(dst[:, 0].max()) + pad)
    y1 = min(img.shape[0], int(dst[:, 1].max()) + pad)
    if x1 <= x0 or y1 <= y0:
        return img
    src = np.float32([(0, 0), (w, 0), (w, h), (0, h)])
    M = cv2.getPerspectiveTransform(src, dst - np.float32([x0, y0]))
    warped = cv2.warpPerspective(phone_rgba, M, (x1 - x0, y1 - y0), flags=cv2.INTER_LINEAR,
                                 borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))
    a = warped[..., 3:4] * alpha
    reg = img[y0:y1, x0:x1]
    if backlight > 0 and min(x1 - x0, y1 - y0) >= 16:  # contre-jour doux pour détacher le bezel noir du fond noir
        small = cv2.resize(warped[..., 3], None, fx=0.25, fy=0.25, interpolation=cv2.INTER_AREA)
        glow = cv2.GaussianBlur(small, (0, 0), 10)
        glow = cv2.resize(glow, (x1 - x0, y1 - y0), interpolation=cv2.INTER_LINEAR)[..., None]
        reg = reg + (1 - reg) * glow * backlight * alpha
    img[y0:y1, x0:x1] = reg * (1 - a) + warped[..., :3] * a
    return img
