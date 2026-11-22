"""Assets exacts : grille du logo, captures Android rognées et caviardées, maquette de téléphone."""
from dataclasses import dataclass
from functools import lru_cache

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

from . import config
from .localize import localize


@dataclass(frozen=True)
class Dot:
    col: int
    row: int
    state: str  # "off" | "on" | "red"


# ---------------------------------------------------------------- logo
def _logo_rgba() -> np.ndarray:
    return np.asarray(Image.open(config.ASSETS / "brand" / "logo-1024.png").convert("RGBA"))


@lru_cache(maxsize=1)
def _logo_blobs():
    a = _logo_rgba()
    rgb = a[..., :3].astype(int)
    mask = (rgb.max(axis=2) > 12) & (a[..., 3] > 0)
    n, lab, stats, cents = cv2.connectedComponentsWithStats(mask.astype(np.uint8), 8)
    blobs = []
    for i in range(1, n):
        x, y, w, h, area = stats[i]
        if area < 500 or abs(w - h) > 6:  # ignore anti-aliasing slivers
            continue
        col = rgb[lab == i].mean(axis=0)
        blobs.append((cents[i][0], cents[i][1], tuple(int(c) for c in col)))
    return blobs


def logo_grid() -> list[Dot]:
    blobs = _logo_blobs()
    xs = sorted({round(b[0]) for b in blobs})
    pitch = np.median(np.diff(sorted(b[0] for b in blobs if abs(b[1] - blobs[0][1]) < 5)))
    x0 = min(b[0] for b in blobs)
    y0 = min(b[1] for b in blobs)
    dots = []
    for cx, cy, col in blobs:
        c, r = int(round((cx - x0) / pitch)), int(round((cy - y0) / pitch))
        if col[0] > 200 and col[1] < 120:
            st = "red"
        elif min(col) > 180:
            st = "on"
        else:
            st = "off"
        dots.append(Dot(c, r, st))
    # colonnes indexées de 0 à 6 (la ligne 0 commence à la colonne 1)
    minc = min(d.col for d in dots)
    dots = [Dot(d.col - minc, d.row, d.state) for d in dots]
    return sorted(dots, key=lambda d: (d.row, d.col))


def logo_layout(center: tuple[float, float], pitch: float) -> list[tuple[Dot, float, float]]:
    cx, cy = center
    return [(d, cx + (d.col - 3) * pitch, cy + (d.row - 4) * pitch) for d in logo_grid()]


def sample_logo_colors():
    blobs = _logo_blobs()
    pick = lambda pred: tuple(int(v) for v in np.median([b[2] for b in blobs if pred(b[2])], axis=0))
    return (pick(lambda c: min(c) > 180),
            pick(lambda c: c[0] > 200 and c[1] < 120),
            pick(lambda c: max(c) < 60))


# ---------------------------------------------------------------- captures
SCREENS = {
    "share": "03_library.png",          # bibliothèque vide
    "capture": "23_capture_to_add_sheet.png",
    "done": "06_share.png",             # téléchargement en cours (débit en direct)
    "browser": "22_browser_capture_bar.png",
    "library": "15_french_first_run.png",
    "send": "12_send.png",
    "archive": "14_archive.png",
    "stats": "13_stats.png",
    "settings": "08_settings.png",
}
CROP_H = 2388  # la barre système grise commence à la ligne 2388
BBB_TITLE = "Big Buck Bunny (4K)"
# Vidéo de démonstration montrée dans les captures : "bbb" (films 1 et 2) ou "self" (film v3 : le film de présentation
# de l'appli lui-même, pour ne montrer aucun contenu tiers).
DEMO = {"mode": "bbb"}
SELF = {"title": f"{config.COPY['name']} — Présentation", "channel": "itsnazzym", "dur": "0:31",
        "url": "m.youtube.com", "file": "presentation-1080p.mp4", "short": "presentation-1080p"}


def set_demo(mode: str) -> None:
    """Change la vidéo de démonstration et vide les caches d'images."""
    DEMO["mode"] = mode
    _load.cache_clear()
    _composed.cache_clear()
    phone_key.cache_clear()


def _font(weight: str, size: int) -> ImageFont.FreeTypeFont:
    path = {"medium": "/usr/share/fonts/opentype/inter/Inter-Medium.otf",
            "semibold": "/usr/share/fonts/opentype/inter/Inter-SemiBold.otf"}[weight]
    return ImageFont.truetype(path, size)


def _bbb_cover(w: int, h: int, radius: int = 0) -> Image.Image:
    name = "demo-thumb.png" if DEMO["mode"] == "self" else "big-buck-bunny.png"
    src = Image.open(config.ASSETS / "brand" / name).convert("RGB")
    s = max(w / src.width, h / src.height)
    im = src.resize((round(src.width * s), round(src.height * s)), Image.LANCZOS)
    l, t = (im.width - w) // 2, (im.height - h) // 2
    im = im.crop((l, t, l + w, t + h))
    if radius:
        m = Image.new("L", (w * 4, h * 4), 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, w * 4 - 1, h * 4 - 1), radius * 4, fill=255)
        im.putalpha(m.resize((w, h), Image.LANCZOS))
    return im


def _redact(key: str, im: Image.Image) -> Image.Image:
    d = ImageDraw.Draw(im)
    W, GR = (245, 245, 245), (161, 161, 170)
    me = DEMO["mode"] == "self"
    title = SELF["title"] if me else BBB_TITLE
    who = SELF["channel"] if me else "Blender Foundation"
    dur = SELF["dur"] if me else "9:56"
    url = SELF["url"] if me else "peach.blender.org"
    if key == "capture":
        d.rectangle((90, 500, 382, 670), fill=(11, 11, 11))
        th = _bbb_cover(286, 162, 16)
        im.paste(th, (92, 504), th)
        d.rounded_rectangle((290, 618, 370, 656), 8, fill=(0, 0, 0))
        d.text((330, 637), dur, font=_font("semibold", 26), fill=W, anchor="mm")
        d.rectangle((408, 516, 1112, 656), fill=(11, 11, 11))
        d.text((414, 562), _fit(title, 44, 690), font=_font("medium", 44), fill=W, anchor="lm")
        d.text((414, 618), who, font=_font("medium", 40), fill=GR, anchor="lm")
    elif key == "browser":
        d.rectangle((150, 345, 975, 425), fill=(0, 0, 0))
        d.text((162, 386), url, font=_font("medium", 40), fill=W, anchor="lm")
        d.rectangle((0, 805, 1170, 1976), fill=(0, 0, 0))
        im.paste(_bbb_cover(1170, 658), (0, 830))
        d.text((48, 1560), _fit(title, 52, 1080, "semibold"), font=_font("semibold", 52), fill=W, anchor="lm")
        d.text((48, 1630), f"{who} · {dur}", font=_font("medium", 38), fill=GR, anchor="lm")
        d.rectangle((55, 2058, 725, 2132), fill=(0, 0, 0))
        d.text((62, 2095), _fit(title, 42, 650, "semibold"), font=_font("semibold", 42), fill=W, anchor="lm")
    elif key == "library":
        d.rectangle((330, 498, 1000, 562), fill=(11, 11, 11))
        d.text((336, 530), _fit(title, 40, 660), font=_font("medium", 40), fill=W, anchor="lm")
        if me:
            d.rectangle((330, 722, 1000, 778), fill=(11, 11, 11))
            d.text((336, 750), SELF["file"], font=_font("medium", 40), fill=W, anchor="lm")
    elif key == "done" and me:
        d.rectangle((330, 1488, 1000, 1542), fill=(11, 11, 11))
        d.text((336, 1515), SELF["short"], font=_font("medium", 44), fill=W, anchor="lm")
    return im


def _fit(text: str, size: int, max_w: int, weight: str = "medium") -> str:
    """Tronque avec … si le texte dépasse max_w px."""
    f = _font(weight, size)
    if f.getlength(text) <= max_w:
        return text
    while text and f.getlength(text + "…") > max_w:
        text = text[:-1]
    return text.rstrip() + "…"


def raw_screen(key: str) -> np.ndarray:
    im = Image.open(config.ASSETS / "screens" / SCREENS[key]).convert("RGB")
    return np.asarray(im)[:CROP_H].copy()


@lru_cache(maxsize=None)
def _load(key: str) -> np.ndarray:
    im = Image.open(config.ASSETS / "screens" / SCREENS[key]).convert("RGB")
    im = localize(key, _redact(key, im)).crop((0, 0, im.width, CROP_H))
    a = np.asarray(im).copy()
    a.setflags(write=False)
    return a


# écrans composés à partir des vraies captures (états intermédiaires de l'appli : liste vide → 1 fichier → 2) :
# clé → (capture de base, [(capture source, (x0, y0, x1, y1), dy), ...]) ; chaque case est recopiée telle quelle,
# décalée verticalement de dy px (une ligne de liste qui change de place)
COMPOSED: dict[str, tuple[str, list]] = {}


def compose_screen(key: str, base: str, patches) -> str:
    """Déclare un écran composé (voir COMPOSED) ; patches : (source, box) ou (source, box, dy). Renvoie la clé."""
    COMPOSED[key] = (base, [(p[0], tuple(int(v) for v in p[1]), int(p[2]) if len(p) > 2 else 0) for p in patches])
    _composed.cache_clear()
    return key


@lru_cache(maxsize=None)
def _composed(key: str) -> np.ndarray:
    base, patches = COMPOSED[key]
    a = load_screen(base).copy()
    for src, (x0, y0, x1, y1), dy in patches:
        a[y0 + dy:y1 + dy, x0:x1] = load_screen(src)[y0:y1, x0:x1]
    a.setflags(write=False)
    return a


# écrans évidés (v9) : quand un élément de l'interface se soulève de l'écran en 3D (bouton extrudé, couche d'une vue
# éclatée), l'écran ne le contient plus : sa place devient un logement vide. Il n'existe jamais deux fois à l'image.
# clé → (écran de base, ((x0, y0, x1, y1, rayon), ...))
RECESSED: dict[str, tuple[str, tuple]] = {}
RECESS_FILL = (2, 2, 3)            # fond du logement (l'appli est sur fond noir)
RECESS_EDGE = (30, 30, 33)         # liseré du bord du logement
RECESS_LIP = (58, 58, 62)          # arête intérieure basse, éclairée par la lumière venue d'en haut


def recess_screen(key: str, base: str, boxes) -> str:
    """Déclare l'écran `base` dont chaque case (x0, y0, x1, y1, rayon) est évidée (logement de l'élément soulevé).
    Renvoie la clé."""
    RECESSED[key] = (base, tuple(tuple(int(v) for v in b) for b in boxes))
    _recessed.cache_clear()
    return key


@lru_cache(maxsize=None)
def _recessed(key: str) -> np.ndarray:
    base, boxes = RECESSED[key]
    a = load_screen(base).astype(np.float32)
    for x0, y0, x1, y1, r in boxes:
        w, h = x1 - x0, y1 - y0
        m = _rrect_mask(w, h, r)
        dist = cv2.distanceTransform((m > 0.5).astype(np.uint8), cv2.DIST_L2, 5)
        edge = np.clip(1.6 - dist / 2.0, 0, 1)                     # liseré ≈ 3 px
        ys = np.arange(h, dtype=np.float32)[:, None]
        lip = np.clip(1 - dist / 9.0, 0, 1) * np.clip((ys - h * 0.55) / (h * 0.45), 0, 1)
        col = np.empty((h, w, 3), np.float32)
        col[:] = RECESS_FILL
        col += (np.asarray(RECESS_LIP, np.float32) - RECESS_FILL) * lip[..., None]
        col += (np.asarray(RECESS_EDGE, np.float32) - col) * (edge * (1 - lip))[..., None]
        reg = a[y0:y1, x0:x1]
        reg[:] = reg * (1 - m[..., None]) + col * m[..., None]
    out = np.clip(a + 0.5, 0, 255).astype(np.uint8)
    out.setflags(write=False)
    return out


def load_screen(key: str) -> np.ndarray:
    if key in COMPOSED:
        return _composed(key)
    if key in RECESSED:
        return _recessed(key)
    return _load(key)


# ---------------------------------------------------------------- téléphone
def _rrect_mask(w: int, h: int, r: float, ss: int = 2) -> np.ndarray:
    m = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w * ss - 1, h * ss - 1), r * ss, fill=255)
    return np.asarray(m.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255


def phone(screen: np.ndarray, height: int) -> np.ndarray:
    """RGBA uint8 : bezel noir, coins arrondis, liseré 1 px, écran incrusté."""
    b = max(2, round(0.016 * height))
    sh = height - 2 * b
    sw = round(sh * screen.shape[1] / screen.shape[0])
    w = sw + 2 * b
    out = np.zeros((height, w, 4), np.float32)
    body = _rrect_mask(w, height, 0.13 * w)
    out[..., :3] = np.array((11, 11, 12), np.float32) / 255
    # liseré : différence entre le masque plein et le masque rétréci d'1 px
    inner = np.zeros_like(body)
    inner[1:-1, 1:-1] = _rrect_mask(w - 2, height - 2, 0.13 * w - 1)
    rim = np.clip(body - inner, 0, 1)[..., None]
    out[..., :3] = out[..., :3] * (1 - rim) + np.array((42, 42, 46), np.float32) / 255 * rim
    scr = cv2.resize(screen, (sw, sh), interpolation=cv2.INTER_AREA).astype(np.float32) / 255
    sm = _rrect_mask(sw, sh, 0.11 * sw)[..., None]
    region = out[b:b + sh, b:b + sw, :3]
    out[b:b + sh, b:b + sw, :3] = region * (1 - sm) + scr * sm
    out[..., 3] = body
    return (out * 255 + 0.5).astype(np.uint8)


@lru_cache(maxsize=64)
def phone_key(key: str, height: int) -> np.ndarray:
    """Version mise en cache de phone() pour une capture nommée."""
    return phone(load_screen(key), height)
