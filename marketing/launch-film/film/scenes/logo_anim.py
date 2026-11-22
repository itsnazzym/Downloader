"""Dessin de la matrice de points du logo (disques anticrénelés, halo)."""
from functools import lru_cache
from typing import Callable

import cv2
import numpy as np

from .. import config
from ..assets import Dot

WHITE = np.array(config.LOGO_WHITE, np.float32) / 255
RED = np.array(config.LOGO_RED, np.float32) / 255
OFF = np.array(config.LOGO_OFF, np.float32) / 255


@lru_cache(maxsize=32)
def _disk(radius_q: int) -> np.ndarray:
    """Alpha d'un disque anticrénelé de rayon radius_q/4 px (sur-échantillonné ×8)."""
    r = radius_q / 4
    size = int(np.ceil(r)) * 2 + 4
    ss = 8
    big = np.zeros((size * ss, size * ss), np.uint8)
    cv2.circle(big, (size * ss // 2, size * ss // 2), int(r * ss), 255, -1, cv2.LINE_AA)
    return cv2.resize(big, (size, size), interpolation=cv2.INTER_AREA).astype(np.float32) / 255


def _stamp(img: np.ndarray, alpha: np.ndarray, x: float, y: float, color: np.ndarray, a: float) -> None:
    h, w = alpha.shape
    M = np.float32([[1, 0, x - w / 2], [0, 1, y - h / 2]])
    x0, y0 = int(np.floor(x - w / 2)) - 1, int(np.floor(y - h / 2)) - 1
    x1, y1 = x0 + w + 2, y0 + h + 2
    cx0, cy0 = max(x0, 0), max(y0, 0)
    cx1, cy1 = min(x1, img.shape[1]), min(y1, img.shape[0])
    if cx1 <= cx0 or cy1 <= cy0:
        return
    M[0, 2] -= cx0
    M[1, 2] -= cy0
    al = cv2.warpAffine(alpha, M, (cx1 - cx0, cy1 - cy0), flags=cv2.INTER_LINEAR)[..., None] * a
    reg = img[cy0:cy1, cx0:cx1]
    img[cy0:cy1, cx0:cx1] = reg * (1 - al) + color * al


def dot_color(d: Dot, lit: float) -> np.ndarray:
    if d.state == "red":
        return OFF + (RED - OFF) * lit
    if d.state == "on":
        return OFF + (WHITE - OFF) * lit
    return OFF


def draw(img: np.ndarray, layout: list[tuple[Dot, float, float]], pitch: float,
         lit: Callable[[Dot], float], vis: Callable[[Dot], float] = lambda d: 1.0,
         glow: float = 0.0, scale: Callable[[Dot], float] = lambda d: 1.0) -> np.ndarray:
    """Dessine les points. lit = intensité d'allumage, vis = opacité, scale = échelle du disque."""
    glow_layer = np.zeros_like(img) if glow > 0 else None
    for d, x, y in layout:
        v = vis(d)
        s = scale(d)
        if v <= 0 or s <= 0:
            continue
        r = 0.36 * pitch * s
        disk = _disk(max(2, int(round(r * 4))))
        l = lit(d)
        col = dot_color(d, l)
        _stamp(img, disk, x, y, col, v)
        if glow_layer is not None and d.state != "off" and l > 0:
            _stamp(glow_layer, disk, x, y, col * l, v)
    if glow_layer is not None:
        sig = max(2.0, pitch * 0.45)
        small = cv2.resize(glow_layer, (img.shape[1] // 2, img.shape[0] // 2), interpolation=cv2.INTER_AREA)
        b1 = cv2.GaussianBlur(small, (0, 0), sig / 2)
        b2 = cv2.GaussianBlur(small, (0, 0), sig * 2)
        halo = cv2.resize(b1 * 0.8 + b2 * 0.35, (img.shape[1], img.shape[0]), interpolation=cv2.INTER_LINEAR)
        img = img + halo * glow * (1 - img)
    return img
