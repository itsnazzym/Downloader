"""Typographie : rendu Inter net (sur-échantillonné), collage sous-pixel et révélation cinétique."""
from functools import lru_cache

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

from . import config
from .ease import out_expo, progress

COPY_SIZES = {"share": 150, "sites": 190, "send": 120, "archive": 120, "name": 110, "tagline": 34}
SS = 2  # facteur de sur-échantillonnage


@lru_cache(maxsize=256)
def text_layer(text: str, size: int, weight: str = "black", tracking: float = -0.03,
               color: tuple = (255, 255, 255)) -> np.ndarray:
    """RGBA uint8, recadré serré (avec une petite marge), une seule ligne."""
    font = ImageFont.truetype(str(config.FONTS[weight]), size * SS)
    asc, desc = font.getmetrics()
    track = tracking * size * SS
    widths = [font.getlength(" " if ch in "\u00a0\u202f" else ch) for ch in text]
    total = sum(widths) + track * (len(text) - 1)
    pad = 4 * SS
    w, h = int(np.ceil(total)) + 2 * pad, asc + desc + 2 * pad
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    x = pad
    for ch, cw in zip(text, widths):
        if ch not in " \u00a0\u202f":
            d.text((x, pad), ch, font=font, fill=255)
        x += cw + track
    a = np.asarray(im.resize((w // SS, h // SS), Image.LANCZOS))
    out = np.zeros(a.shape + (4,), np.uint8)
    out[..., :3] = color
    out[..., 3] = a
    out.setflags(write=False)
    return out


def paste(dst: np.ndarray, rgba: np.ndarray, cx: float, cy: float, scale: float = 1.0,
          alpha: float = 1.0) -> np.ndarray:
    """Colle rgba centré en (cx, cy) dans dst (float32 H×W×3), avec position sous-pixel."""
    if alpha <= 0 or scale <= 0:
        return dst
    h, w = rgba.shape[:2]
    M = np.float32([[scale, 0, cx - w * scale / 2], [0, scale, cy - h * scale / 2]])
    # ne déformer que la boîte englobante utile
    x0 = max(0, int(np.floor(cx - w * scale / 2)) - 2)
    y0 = max(0, int(np.floor(cy - h * scale / 2)) - 2)
    x1 = min(dst.shape[1], int(np.ceil(cx + w * scale / 2)) + 2)
    y1 = min(dst.shape[0], int(np.ceil(cy + h * scale / 2)) + 2)
    if x1 <= x0 or y1 <= y0:
        return dst
    M[0, 2] -= x0
    M[1, 2] -= y0
    warped = cv2.warpAffine(rgba, M, (x1 - x0, y1 - y0), flags=cv2.INTER_LINEAR,
                            borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))
    wf = warped.astype(np.float32) / 255
    a = wf[..., 3:4] * alpha
    region = dst[y0:y1, x0:x1]
    dst[y0:y1, x0:x1] = region * (1 - a) + wf[..., :3] * a
    return dst


def kinetic(words: list[str], f_local: float, size: int, per_word: int = 4, y: float = 540,
            weight: str = "black", tracking: float = -0.03, color=(255, 255, 255)) -> np.ndarray:
    """RGBA uint8 plein cadre : chaque mot monte depuis sous un masque de ligne, décalé de per_word images."""
    layers = [text_layer(w, size, weight, tracking, color) for w in words]
    gap = 0.22 * size
    total = sum(l.shape[1] for l in layers) + gap * (len(layers) - 1)
    canvas = np.zeros((config.H, config.W, 4), np.float32)
    x = config.W / 2 - total / 2
    lh = layers[0].shape[0]
    top, bot = int(y - lh / 2), int(y + lh / 2)  # masque de ligne
    for i, l in enumerate(layers):
        t = out_expo(progress(f_local, i * per_word, i * per_word + 10))
        dy = (1 - t) * lh * 1.05
        cx = x + l.shape[1] / 2
        if t > 0:
            acc = np.zeros((config.H, config.W, 3), np.float32)
            rgba = l.copy()
            rgba[..., :3] = 255
            paste(acc, rgba, cx, y + dy)  # canal alpha simulé : texte blanc sur noir
            al = acc[..., 0]
            al[:top] = 0
            al[bot:] = 0
            canvas[..., 3] = np.maximum(canvas[..., 3], al)
        x += l.shape[1] + gap
    canvas[..., :3] = np.array(color, np.float32) / 255
    out = np.zeros((config.H, config.W, 4), np.uint8)
    out[..., :3] = color
    out[..., 3] = (canvas[..., 3] * 255 + 0.5).astype(np.uint8)
    return out


def over_rgba(dst: np.ndarray, rgba: np.ndarray, alpha: float = 1.0) -> np.ndarray:
    """Composite un calque RGBA plein cadre sur dst (float32)."""
    a = rgba[..., 3:4].astype(np.float32) / 255 * alpha
    return dst * (1 - a) + (rgba[..., :3].astype(np.float32) / 255) * a


def kinetic_lines(lines: list[list[str]], f_local: float, size: int, y: float, line_gap: float,
                  per_word: int = 4, line_delay: int = 5, **kw) -> np.ndarray:
    """Titre sur plusieurs lignes (format vertical) : chaque ligne est un kinetic(), la suivante démarre line_delay images plus tard."""
    out = np.zeros((config.H, config.W, 4), np.uint8)
    acc = np.zeros((config.H, config.W), np.float32)
    for i, words in enumerate(lines):
        layer = kinetic(words, f_local - i * line_delay, size, per_word=per_word, y=y + i * line_gap, **kw)
        acc = np.maximum(acc, layer[..., 3].astype(np.float32))
    colour = kw.get("color", (255, 255, 255))
    out[..., :3] = colour
    out[..., 3] = acc.astype(np.uint8)
    return out
