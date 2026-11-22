"""Palette, fond, finition et typographie de la direction claire."""
import cv2
import numpy as np

from reel.core import CX, CY, H, W, text_at, text_layer, paste  # noqa: F401

BG = np.array((245, 245, 247), np.float32) / 255
INK = (29, 29, 31)
GREY = (110, 110, 115)
RED = (247, 71, 59)

_BGIMG = None


def background(light: float = 1.0) -> np.ndarray:
    """Gris très clair avec un halo blanc au centre (studio)."""
    global _BGIMG
    if _BGIMG is None:
        y, x = np.mgrid[0:H, 0:W].astype(np.float32)
        d = np.sqrt(((x - CX) / W) ** 2 + ((y - CY * 0.9) / H) ** 2)
        g = np.clip(1 - d * 1.1, 0, 1) ** 1.5
        _BGIMG = (BG[None, None] * (0.94 + 0.06 * 0) + (1 - BG[None, None]) * g[..., None] * 0.9).astype(np.float32)
    return _BGIMG.copy()


def finish(img: np.ndarray, f: int) -> np.ndarray:
    rng = np.random.default_rng(9000 + f)
    g = cv2.resize(rng.standard_normal((H // 2, W // 2), dtype=np.float32), (W, H))
    out = img + g[..., None] * 0.006
    return (np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)


def title(img, s, size, x, y, align="left", alpha=1.0, color=INK, weight="black", tracking=-0.045):
    return text_at(img, s, size, x, y, align, weight, alpha, color, tracking)[0]
