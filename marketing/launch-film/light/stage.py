"""Scène 3D v4 : plans texturés et téléphones placés dans le monde, profondeur de champ, ombres douces.

Coordonnées monde de reel.core (y vers le bas, la caméra regarde vers +z). Chaque élément est dessiné
uniquement dans sa boîte englobante écran (avec la marge du flou), du plus loin au plus proche.
Les textures sont converties en alpha prémultiplié avant l'homographie : pas de liseré sombre ni de halo
sur les bords, et le flou de profondeur de champ reste correct (on floute couleur·alpha et alpha).
"""
from collections import OrderedDict
from functools import lru_cache
from dataclasses import dataclass

import cv2
import numpy as np

from reel import core
from reel.core import H, W, Cam, rot

from .style import INK

NEAR = 10.0          # plan de coupe proche (unités monde, profondeur caméra)
MAX_SIGMA = 8.0      # flou de profondeur de champ maximal (px)
# v8 : vrai corps de téléphone. Épaisseur ≈ 8 mm pour ≈ 155 mm de haut (texture de 1100 unités de haut).
PHONE_THICK = 56.0
BAND_N = 8           # bandes du profil arrondi de la tranche (aluminium)
BAND_BULGE = 4.0     # bombé de la tranche (unités monde)
BAND_TILT = 66.0     # inclinaison (°) des normales d'ombrage aux bords avant / arrière de la tranche (profil arrondi)


@dataclass
class Plane:
    """Carte plate texturée (RGBA uint8) centrée en center, de largeur monde size_w (hauteur au prorata).

    Pour profiter du cache de mipmaps, passer une texture en lecture seule (tex.setflags(write=False)) :
    c'est le cas de text_plane() et de reel.core.text_layer().
    """
    tex: np.ndarray
    center: tuple
    size_w: float
    yaw: float = 0.0
    pitch: float = 0.0
    roll: float = 0.0
    alpha: float = 1.0
    shadow: float = 0.0
    blur: float = 0.0        # flou propre (px, au moins) : fragments d'interface hors champ de netteté


@dataclass
class Extrude(Plane):
    """Plan texturé extrudé vers l'arrière (lettres, pastilles, cartes épaisses) : la face avant est la texture,
    les flancs (depth unités monde, vers +z local) prennent la forme de son alpha, couleur side près de la face
    → side_back au fond ; rim : liseré clair au bord avant des flancs (0..1)."""
    depth: float = 40.0
    side: tuple = (70, 70, 76)
    side_back: tuple = (20, 20, 22)
    rim: float = 0.0


@dataclass
class PhoneItem:
    """Téléphone 3D (capture `key`) centré en center : corps épais (tranche en aluminium au profil arrondi), vitre
    avec reflet qui dépend de l'orientation, dos mat avec module photo et logo TapLoad."""
    key: str
    center: tuple
    yaw: float = 0.0
    pitch: float = 0.0
    roll: float = 0.0
    alpha: float = 1.0
    shadow: float = 0.3


SPACE_EM = 0.28      # chasse minimale d'une espace (em), quel que soit l'interlettrage


@lru_cache(maxsize=256)
def text_plane(s: str, size: int, weight: str = "black", color=INK, tracking: float = -0.045) -> np.ndarray:
    """Mot ou ligne en RGBA uint8 (fond transparent, lecture seule) à poser dans un Plane.

    Même rendu que reel.core.text_layer (Inter sur-échantillonné, même marge, même ligne de base), sauf les
    espaces : l'interlettrage (souvent négatif) n'est pas appliqué de part et d'autre d'une espace et une
    espace avance d'au moins SPACE_EM em, pour que « Envoi local. » ne se lise pas « Envoilocal. »."""
    from PIL import Image, ImageDraw, ImageFont

    from film import config
    from film.typo import SS
    font = ImageFont.truetype(str(config.FONTS[weight]), size * SS)
    asc, desc = font.getmetrics()
    track = tracking * size * SS
    space = max(font.getlength(" "), SPACE_EM * size * SS)
    blank = " \u00a0\u202f"
    adv = []
    for i, ch in enumerate(s):
        if ch in blank:
            adv.append(space)
        else:
            nxt = s[i + 1] if i + 1 < len(s) else None
            adv.append(font.getlength(ch) + (track if nxt is not None and nxt not in blank else 0.0))
    pad = 4 * SS
    w, h = int(np.ceil(sum(adv))) + 2 * pad, asc + desc + 2 * pad
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    x = pad
    for ch, a in zip(s, adv):
        if ch not in blank:
            d.text((x, pad), ch, font=font, fill=255)
        x += a
    a = np.asarray(im.resize((w // SS, h // SS), Image.LANCZOS))
    out = np.zeros(a.shape + (4,), np.uint8)
    out[..., :3] = tuple(color)
    out[..., 3] = a
    out.setflags(write=False)
    return out


@lru_cache(maxsize=64)
def text_groups(s: str, size: int, weight: str = "black", tracking: float = -0.045, mode: str = "word"):
    """Couches d'alpha (uint8, même cadre que text_plane) de chaque mot (mode « word ») ou de chaque lettre
    (mode « char ») de s : mêmes positions et même chasse que text_plane, pour animer mots / lettres séparément
    (typographie cinétique). Renvoie [(x0, x1, alpha[:, x0:x1])] ; les espaces ne forment pas de groupe."""
    from PIL import Image, ImageDraw, ImageFont

    from film import config
    from film.typo import SS
    font = ImageFont.truetype(str(config.FONTS[weight]), size * SS)
    asc, desc = font.getmetrics()
    track = tracking * size * SS
    space = max(font.getlength(" "), SPACE_EM * size * SS)
    blank = "   "
    adv = []
    for i, ch in enumerate(s):
        if ch in blank:
            adv.append(space)
        else:
            nxt = s[i + 1] if i + 1 < len(s) else None
            adv.append(font.getlength(ch) + (track if nxt is not None and nxt not in blank else 0.0))
    pad = 4 * SS
    w, h = int(np.ceil(sum(adv))) + 2 * pad, asc + desc + 2 * pad
    groups, cur, x = [], [], pad
    for ch, a in zip(s, adv):
        if ch in blank:
            if cur:
                groups.append(cur)
            cur = []
        else:
            cur.append((ch, x))
            if mode == "char":
                groups.append(cur)
                cur = []
        x += a
    if cur:
        groups.append(cur)
    out = []
    for g in groups:
        im = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(im)
        for ch, x in g:
            d.text((x, pad), ch, font=font, fill=255)
        a = np.asarray(im.resize((w // SS, h // SS), Image.LANCZOS))
        cols = np.nonzero(a.max(0))[0]
        if len(cols) == 0:
            continue
        x0, x1 = int(cols[0]), int(cols[-1]) + 1
        sl = a[:, x0:x1].copy()
        sl.setflags(write=False)
        out.append((x0, x1, sl))
    return tuple(out)


# ---------------------------------------------------------------- textures prémultipliées (mipmaps)
_MIPS: "OrderedDict[int, tuple[np.ndarray, list[np.ndarray]]]" = OrderedDict()
_MIPS_MAX = 96


def _premult(tex: np.ndarray) -> np.ndarray:
    f = tex.astype(np.float32) * (1.0 / 255)
    if f.shape[2] == 3:
        f = np.concatenate([f, np.ones(f.shape[:2] + (1,), np.float32)], 2)
    f[..., :3] *= f[..., 3:4]
    return f


def _mip(tex: np.ndarray, level: int) -> np.ndarray:
    """Niveau `level` (largeur / 2**level) de la texture prémultipliée ; mis en cache si tex est en lecture seule."""
    cache = not tex.flags.writeable
    ent = _MIPS.get(id(tex)) if cache else None
    if ent is None or ent[0] is not tex:
        ent = (tex, [_premult(tex)])
        if cache:
            _MIPS[id(tex)] = ent
            while len(_MIPS) > _MIPS_MAX:
                _MIPS.popitem(last=False)
    elif cache:
        _MIPS.move_to_end(id(tex))
    levels = ent[1]
    while len(levels) <= level:
        prev = levels[-1]
        h, w = prev.shape[:2]
        if min(h, w) < 4:
            break
        levels.append(cv2.resize(prev, (max(1, w // 2), max(1, h // 2)), interpolation=cv2.INTER_AREA))
    return levels[min(level, len(levels) - 1)]


# ---------------------------------------------------------------- flou et ombres rapides
def _blur(a: np.ndarray, sigma: float) -> np.ndarray:
    """Flou gaussien ; au-delà de 3 px on floute à demi-résolution (même rendu, ~4× moins cher)."""
    if sigma <= 0.3:
        return a
    if sigma < 3.0:
        return cv2.GaussianBlur(a, (0, 0), sigma)
    h, w = a.shape[:2]
    small = cv2.resize(a, (max(1, w // 2), max(1, h // 2)), interpolation=cv2.INTER_AREA)
    s2 = max(0.3, np.sqrt(max(sigma * sigma - 0.7 ** 2, 0.0)) / 2)
    small = cv2.GaussianBlur(small, (0, 0), s2)
    return cv2.resize(small, (w, h), interpolation=cv2.INTER_LINEAR)


def _soft_shadow(img: np.ndarray, a: np.ndarray, X0: int, Y0: int, strength: float, off, blur: float) -> None:
    """Même ombre que reel.core._shadow (couverture floutée, décalée, qui assombrit le fond),
    calculée à 1/4 de résolution avec décalage sous-pixel (≈ 10× plus rapide, mouvement continu)."""
    if strength <= 0:
        return
    a = a[..., 0] if a.ndim == 3 else a
    h, w = a.shape
    ds = 4 if blur >= 8 else 2 if blur >= 3 else 1
    m = int(np.ceil(3 * blur)) + ds
    ph = -(-(h + 2 * m) // ds) * ds
    pw = -(-(w + 2 * m) // ds) * ds
    pad = np.zeros((ph, pw), np.float32)
    pad[m:m + h, m:m + w] = a
    small = cv2.resize(pad, (pw // ds, ph // ds), interpolation=cv2.INTER_AREA) if ds > 1 else pad
    small = cv2.GaussianBlur(small, (0, 0), max(0.3, blur / ds)) * strength
    ox, oy = X0 - m + float(off[0]), Y0 - m + float(off[1])   # origine (écran) du tampon
    gx0, gy0 = max(0, int(np.floor(ox))), max(0, int(np.floor(oy)))
    gx1, gy1 = min(W, int(np.ceil(ox + pw)) + 1), min(H, int(np.ceil(oy + ph)) + 1)
    if gx1 <= gx0 or gy1 <= gy0:
        return
    c = (ds - 1) / 2
    M = np.float32([[ds, 0, c + ox - gx0], [0, ds, c + oy - gy0]])
    s = cv2.warpAffine(small, M, (gx1 - gx0, gy1 - gy0), flags=cv2.INTER_LINEAR,
                       borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    region = img[gy0:gy1, gx0:gx1]
    inv = (1 - np.minimum(s, 1.0)).astype(region.dtype, copy=False)
    region[...] = cv2.multiply(region, cv2.merge([inv, inv, inv]))


def _floor_shadow(img, cam: Cam, corners: np.ndarray, floor_y: float, strength: float) -> None:
    """Ombre de contact : ellipse floue posée sur le sol y = floor_y sous l'élément, plus pâle et plus
    large quand l'élément est haut au-dessus du sol."""
    cx, cz = corners[:, 0].mean(), corners[:, 2].mean()
    half = max(np.ptp(corners[:, 0]), np.ptp(corners[:, 2]), 1.0) / 2
    height = max(np.ptp(corners[:, 1]), 1.0)
    gap = max(0.0, floor_y - corners[:, 1].max())
    k = 1.0 / (1.0 + gap / (0.5 * height))
    ang = np.linspace(0, 2 * np.pi, 48, endpoint=False)
    rx, rz = half * (1.0 + 0.3 * (1 - k)), half * (0.3 + 0.2 * (1 - k))
    pts = np.c_[cx + rx * np.cos(ang), np.full_like(ang, floor_y), cz + rz * np.sin(ang)]
    uv, z = cam.project(pts)
    if z.min() < NEAR:
        return
    zc = float(cam.to_cam(np.array([[cx, floor_y, cz]]))[0, 2])
    blur = float(np.clip((0.12 * half + 0.4 * gap) * cam.f / zc, 2.0, 60.0))
    x0, y0 = np.floor(uv.min(0)).astype(int) - 2
    x1, y1 = np.ceil(uv.max(0)).astype(int) + 2
    if x1 <= 0 or y1 <= 0 or x0 >= W or y0 >= H or (x1 - x0) * (y1 - y0) > 16 * W * H:
        return
    mask = np.zeros((y1 - y0, x1 - x0), np.uint8)
    cv2.fillPoly(mask, [np.round((uv - (x0, y0)) * 16).astype(np.int32)], 255, cv2.LINE_AA, 4)
    _soft_shadow(img, mask.astype(np.float32) / 255, x0, y0, strength * k, (0.0, 0.0), blur)


def _drop(cam: Cam, zc: float) -> tuple[tuple[float, float], float]:
    """Décalage et flou de l'ombre portée sur le fond, à l'échelle de l'élément à l'écran."""
    k = float(np.clip(cam.f / max(zc, NEAR), 0.25, 2.0))
    return (0.0, 48.0 * k), 40.0 * k


def _roi(uv: np.ndarray, pad: int):
    x0, y0 = np.floor(uv.min(0)).astype(int) - pad
    x1, y1 = np.ceil(uv.max(0)).astype(int) + pad
    return max(0, x0), max(0, y0), min(W, x1), min(H, y1)


def _composite(img, prem: np.ndarray, X0, Y0, alpha: float, shadow: float, cam: Cam, zc: float,
               floor_y) -> None:
    """prem : RGBA prémultiplié (ROI) déjà flouté ; ombre puis fondu « over »."""
    if alpha < 1:
        prem = prem * alpha
    a = prem[..., 3:4]
    if shadow > 0 and floor_y is None:
        off, blur = _drop(cam, zc)
        _soft_shadow(img, a, X0, Y0, shadow, off, blur)
    h, w = a.shape[:2]
    region = img[Y0:Y0 + h, X0:X0 + w]
    prem = prem.astype(region.dtype, copy=False)
    inv = 1 - prem[..., 3]
    region[...] = cv2.add(cv2.multiply(region, cv2.merge([inv, inv, inv])),
                          cv2.cvtColor(prem, cv2.COLOR_RGBA2RGB))


# ---------------------------------------------------------------- éléments
def _plane_corners(p: Plane) -> np.ndarray:
    th, tw = p.tex.shape[:2]
    w = float(p.size_w)
    h = w * th / tw
    loc = np.array([[-w / 2, -h / 2, 0], [w / 2, -h / 2, 0], [w / 2, h / 2, 0], [-w / 2, h / 2, 0]])
    return loc @ rot(p.yaw, p.pitch, p.roll).T + np.asarray(p.center, np.float64)


def _warp_level(tex: np.ndarray, level: int, dst: np.ndarray, rw: int, rh: int) -> np.ndarray:
    """Projette le niveau de mipmap `level` (prémultiplié) sur le quadrilatère dst (coordonnées ROI)."""
    t = _mip(tex, level)
    lh, lw = t.shape[:2]
    src = np.float32([[-0.5, -0.5], [lw - 0.5, -0.5], [lw - 0.5, lh - 0.5], [-0.5, lh - 0.5]])
    Hroi = cv2.getPerspectiveTransform(src, dst)
    return cv2.warpPerspective(t, Hroi, (rw, rh), flags=cv2.INTER_LINEAR,
                               borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))


def _draw_plane(img, cam: Cam, p: Plane, sigma: float, zc: float, floor_y) -> dict:
    th, tw = p.tex.shape[:2]
    corners = _plane_corners(p)
    uv, z = cam.project(corners)
    Hm = cv2.getPerspectiveTransform(np.float32([[0, 0], [tw, 0], [tw, th], [0, th]]), uv.astype(np.float32))

    def mapper(u, v):
        q = Hm @ np.array([u, v, 1.0])
        return q[0] / q[2], q[1] / q[2]

    info = {"kind": "plane", "corners": uv, "depth": zc, "sigma": sigma, "H": Hm, "map": mapper,
            "bbox": (0, 0, 0, 0)}
    if p.alpha <= 0 or z.min() < NEAR:
        return info
    pad = 2 + int(np.ceil(3 * sigma))
    X0, Y0, X1, Y1 = _roi(uv, pad)
    info["bbox"] = (X0, Y0, X1, Y1)
    if X1 <= X0 or Y1 <= Y0:
        return info
    if floor_y is not None and p.shadow > 0:
        _floor_shadow(img, cam, corners, floor_y, p.shadow * min(1.0, p.alpha))
    # échelle écran / texture → niveau de mipmap (évite le scintillement des textures réduites)
    e = np.linalg.norm(np.roll(uv, -1, 0) - uv, axis=1)
    s = max((e[0] + e[2]) / (2 * tw), (e[1] + e[3]) / (2 * th))
    # mélange trilinéaire entre deux niveaux : la netteté varie continûment quand le plan recule
    lod = max(0.0, float(np.log2(1 / max(s, 1e-6))) - 0.25)
    l0 = int(lod)
    frac = lod - l0
    dst = (uv - 0.5 - (X0, Y0)).astype(np.float32)
    warped = _warp_level(p.tex, l0, dst, X1 - X0, Y1 - Y0)
    if frac > 0.02:
        warped = cv2.addWeighted(warped, 1 - frac, _warp_level(p.tex, l0 + 1, dst, X1 - X0, Y1 - Y0), frac, 0)
    warped = _blur(warped, sigma)
    _composite(img, warped, X0, Y0, p.alpha, p.shadow, cam, zc, floor_y)
    return info


# ---------------------------------------------------------------- téléphone : corps 3D
@lru_cache(maxsize=1)
def _band_profile():
    """Profil de la tranche, de la face avant (s = 0) au dos (s = 1) : décalage vers l'extérieur et z locaux des
    BAND_N + 1 anneaux, inclinaison géométrique (rad, > 0 : tournée vers l'avant) et inclinaison d'ombrage des
    BAND_N bandes (profil arrondi : la normale passe de l'avant à l'arrière)."""
    s = np.linspace(0.0, 1.0, BAND_N + 1)
    off = BAND_BULGE * np.sin(np.pi * s)
    z = -PHONE_THICK / 2 + PHONE_THICK * s
    mid = (s[:-1] + s[1:]) / 2
    geom = np.arctan2(np.diff(off), np.diff(z))
    shade = np.radians(BAND_TILT) * (1 - 2 * mid)
    return off, z, geom, shade


@lru_cache(maxsize=4)
def _ring_local(tw: float, th: float):
    """Anneaux locaux (BAND_N + 1, n, 3), normales 2D des segments (n, 2), du contour arrondi du téléphone."""
    ring, nrm = core._ring(tw, th, 0.13 * tw)
    off, z, _, _ = _band_profile()
    rings = np.stack([np.c_[ring + o * nrm, np.full(len(ring), zz)] for o, zz in zip(off, z)])
    seg = nrm + np.roll(nrm, -1, 0)
    seg /= np.linalg.norm(seg, axis=1, keepdims=True)
    return rings, seg


def _phone_frame(it: PhoneItem):
    """(R, P) de l'élément : rotation et centre monde."""
    return rot(it.yaw, it.pitch, it.roll), np.asarray(it.center, np.float64)


def _phone_geom(it: PhoneItem, R=None, P=None):
    """Points monde de la silhouette du corps (tous les anneaux de la tranche)."""
    tex = core.phone_tex(it.key)
    th, tw = tex.shape[:2]
    if R is None:
        R, P = _phone_frame(it)
    rings, _ = _ring_local(float(tw), float(th))
    return rings.reshape(-1, 3) @ R.T + P


@lru_cache(maxsize=1)
def phone_back_tex() -> np.ndarray:
    """Dos du téléphone (RGBA, même cadre que core.phone_tex), tel qu'on le voit de derrière : verre mat graphite,
    module photo en haut à gauche (trois objectifs, flash), logo TapLoad en matrice de points au centre."""
    from .ui import _Canvas, app_icon
    base = core.phone_tex("capture")
    th, tw = base.shape[:2]
    cv = _Canvas(tw, th)
    cv.p[:] = 0
    cv.a[:] = 0
    cv.rrect(0, 0, tw, th, 0.13 * tw, fill=(34, 34, 38))
    # dégradé vertical léger (verre dépoli éclairé par le haut)
    g = np.linspace(1.10, 0.86, th, dtype=np.float32)[:, None, None]
    cv.p *= g
    cv.rrect(1, 1, tw - 1, th - 1, 0.13 * tw - 1, border=(58, 58, 63), bw=2)
    # module photo
    m0x, m0y, ms = 0.06 * tw, 0.028 * th, 0.42 * tw
    cv.rrect(m0x + 4, m0y + 6, m0x + ms + 4, m0y + ms + 6, 0.24 * ms, fill=(12, 12, 14), alpha=0.6)   # ombre
    cv.rrect(m0x, m0y, m0x + ms, m0y + ms, 0.24 * ms, fill=(46, 46, 51), border=(82, 82, 88), bw=3)
    lr = 0.19 * ms
    for cx, cy in ((0.29, 0.28), (0.29, 0.72), (0.72, 0.5)):
        x, y = m0x + cx * ms, m0y + cy * ms
        cv.circle(x, y, lr, fill=(92, 92, 98))
        cv.circle(x, y, lr * 0.80, fill=(9, 9, 12))
        cv.circle(x, y, lr * 0.46, fill=(18, 22, 34))
        cv.circle(x - lr * 0.22, y - lr * 0.24, lr * 0.13, fill=(120, 130, 150))
    cv.circle(m0x + 0.72 * ms, m0y + 0.17 * ms, 0.055 * ms, fill=(214, 206, 180))           # flash
    cv.circle(m0x + 0.86 * ms, m0y + 0.82 * ms, 0.03 * ms, fill=(8, 8, 9))                 # micro
    # logo : matrice de points de l'icône (points allumés en gris satiné, éteints en relief discret, point rouge)
    ic = app_icon(512).astype(np.float32) / 255
    lum = ic[..., :3].mean(2)
    red = (ic[..., 0] > 0.6) & (ic[..., 1] < 0.45)
    lit = (lum > 0.55) & ~red
    off_ = (lum > 0.08) & (lum <= 0.55) & ~red & (ic[..., 3] > 0.9)
    size = int(0.40 * tw)
    x0, y0 = int(tw / 2 - size / 2), int(th * 0.50 - size / 2)
    for mask, col in ((off_, (50, 50, 55)), (lit, (150, 150, 158)), (red, (235, 70, 58))):
        a = cv2.resize(mask.astype(np.float32), (size, size), interpolation=cv2.INTER_AREA)
        cv.cover(a, col, x0, y0)
    out = cv.rgba(base[..., 3].astype(np.float32) / 255)
    out = out.copy()
    out.setflags(write=False)
    return out


_KEY = np.array((-0.55, -0.75, -0.45)) / np.linalg.norm((-0.55, -0.75, -0.45))   # vers la lumière principale
_RIM = np.array((0.80, -0.30, 0.52)) / np.linalg.norm((0.80, -0.30, 0.52))       # contre-jour à droite
_METAL = np.array((0.30, 0.305, 0.33))
_ENV_A = np.array((0.9, -0.35, 0.25)) / np.linalg.norm((0.9, -0.35, 0.25))        # boîte à lumière (reflet de vitre)


def _band_quads(cam: Cam, R, P, tw, th):
    """Quads visibles de la tranche : (profondeur, quad écran (4, 2), couleur RGB 0..255)."""
    rings, seg = _ring_local(float(tw), float(th))
    _, _, geom, shade = _band_profile()
    K, n = rings.shape[0] - 1, rings.shape[1]
    wr = rings.reshape(-1, 3) @ R.T + P
    uv, z = cam.project(wr)
    wr = wr.reshape(K + 1, n, 3)
    uv = uv.reshape(K + 1, n, 2)
    j = np.arange(n)
    j1 = (j + 1) % n
    out = []
    for k in range(K):
        mid = (wr[k, j] + wr[k, j1] + wr[k + 1, j] + wr[k + 1, j1]) / 4
        cg, sg = np.cos(geom[k]), np.sin(geom[k])
        ng = np.c_[seg * cg, np.full(n, -sg)] @ R.T
        vis = np.einsum("ij,ij->i", ng, mid - cam.pos) < 0
        if not vis.any():
            continue
        ca, sa = np.cos(shade[k]), np.sin(shade[k])
        ns = (np.c_[seg * ca, np.full(n, -sa)] @ R.T)[vis]
        m = mid[vis]
        v = cam.pos - m
        dist = np.linalg.norm(v, axis=1)
        v /= dist[:, None]
        dif = np.clip(ns @ _KEY, 0, 1)
        hk = _KEY + v
        hk /= np.linalg.norm(hk, axis=1, keepdims=True)
        hr = _RIM + v
        hr /= np.linalg.norm(hr, axis=1, keepdims=True)
        spec = np.clip(np.einsum("ij,ij->i", ns, hk), 0, 1) ** 60
        rim = np.clip(np.einsum("ij,ij->i", ns, hr), 0, 1) ** 30
        refl = 2 * np.einsum("ij,ij->i", ns, v)[:, None] * ns - v
        # studio clair : le métal reflète un environnement lumineux, plus clair vers le haut, et une boîte à
        # lumière étroite (ligne spéculaire fine le long de la tranche)
        env = 0.30 + 0.45 * np.clip(-refl[:, 1] * 0.9 + 0.3, 0, 1)
        box = np.exp(-((refl @ _ENV_A - 0.33) / 0.08) ** 2)
        col = (_METAL[None] * (0.30 + 0.55 * dif[:, None]) + 0.55 * env[:, None] * np.array((0.60, 0.61, 0.65))
               + (1.1 * spec + 0.7 * rim + 0.85 * box)[:, None])
        col = np.clip(col, 0, 1) * 255
        idx = np.nonzero(vis)[0]
        for q, i in enumerate(idx):
            quad = np.array([uv[k, i], uv[k, j1[i]], uv[k + 1, j1[i]], uv[k + 1, i]])
            out.append((float(dist[q]), quad, col[q]))
    return out


def _grow(quad: np.ndarray, px: float = 0.7) -> np.ndarray:
    c = quad.mean(0)
    d = quad - c
    nrm = np.linalg.norm(d, axis=1, keepdims=True)
    return quad + d / np.maximum(nrm, 1e-6) * px


def _glass(cam: Cam, n_world, X0, Y0, rw, rh, step: int = 8) -> np.ndarray:
    """Reflet de la vitre (intensité 0..1 par pixel de la ROI) : la boîte à lumière du studio vue dans le reflet du
    rayon de visée sur la normale de l'écran (bande nette + halo large), plus le terme de Fresnel (la vitre reflète
    le studio clair aux angles rasants). Calculé sur une grille grossière puis interpolé (fonction lisse)."""
    gw, gh = rw // step + 2, rh // step + 2
    xs = X0 + np.arange(gw, dtype=np.float64) * step
    ys = Y0 + np.arange(gh, dtype=np.float64) * step
    X, Y = np.meshgrid(xs, ys)
    d = np.stack([(X - core.CX - cam.shift[0]) / cam.f, (Y - core.CY - cam.shift[1]) / cam.f, np.ones_like(X)], -1)
    d /= np.linalg.norm(d, axis=-1, keepdims=True)
    d = d @ cam.R.T
    dn = d @ n_world
    r = d - 2 * dn[..., None] * n_world
    e = r @ _ENV_A
    stripe = 0.17 * np.exp(-((e - 0.33) / 0.045) ** 2) + 0.05 * np.exp(-((e - 0.33) / 0.2) ** 2)
    fres = 0.035 + 0.6 * (1 - np.abs(dn)) ** 5
    g = (stripe * (0.6 + 2 * fres) + fres * 0.9).astype(np.float32)
    g = cv2.resize(g, (gw * step, gh * step), interpolation=cv2.INTER_LINEAR)
    return g[:rh, :rw]


def _face_warp(tex, corners_local, R, P, cam, X0, Y0, rw, rh):
    """Texture (mipmaps prémultipliés) posée sur la face aux coins locaux corners_local → RGBA ROI prémultiplié."""
    th, tw = tex.shape[:2]
    uv, _ = cam.project(corners_local @ R.T + P)
    e = np.linalg.norm(np.roll(uv, -1, 0) - uv, axis=1)
    s = max((e[0] + e[2]) / (2 * tw), (e[1] + e[3]) / (2 * th))
    lod = max(0.0, float(np.log2(1 / max(s, 1e-6))) - 0.25)
    l0 = int(lod)
    frac = lod - l0
    dst = (uv - 0.5 - (X0, Y0)).astype(np.float32)
    w = _warp_level(tex, l0, dst, rw, rh)
    if frac > 0.02:
        w = cv2.addWeighted(w, 1 - frac, _warp_level(tex, l0 + 1, dst, rw, rh), frac, 0)
    return w, uv


def _draw_phone(img, cam: Cam, it: PhoneItem, sigma: float, zc: float, floor_y, mirror=None) -> dict:
    """Corps 3D du téléphone : tranche (quads ombrés : diffus, reflet du studio, ligne spéculaire, contre-jour),
    face écran (texture + reflet de vitre) ou dos (texture du dos, jamais l'écran en miroir), couverture = enveloppe
    convexe anti-crénelée du solide ; flou de profondeur de champ puis ombre et fondu.
    mirror = (floor_y, force) : reflet sur un sol brillant (objet symétrisé sous le sol, estompé en s'éloignant)."""
    tex = core.phone_tex(it.key)
    th, tw = tex.shape[:2]
    R, P = _phone_frame(it)
    if mirror is not None:
        fy, strength = mirror
        M = np.diag((1.0, -1.0, 1.0))
        R = M @ R
        P = np.array((P[0], 2 * fy - P[1], P[2]))
    b = max(2, round(0.016 * th))
    kk = (th - 2 * b) / 2388
    T2 = PHONE_THICK / 2
    fl = np.array([[-tw / 2, -th / 2, -T2], [tw / 2, -th / 2, -T2], [tw / 2, th / 2, -T2], [-tw / 2, th / 2, -T2]])
    cuv, _ = cam.project(fl @ R.T + P)
    Hm = cv2.getPerspectiveTransform(np.float32([[0, 0], [tw, 0], [tw, th], [0, th]]), cuv.astype(np.float32))

    def mapper(u, v):
        """Coordonnées dans la capture d'écran (1170×2388) → pixel écran."""
        p = Hm @ np.array([b + u * kk, b + v * kk, 1.0])
        return p[0] / p[2], p[1] / p[2]

    nf = R @ np.array((0.0, 0.0, -1.0))
    front_vis = float(nf @ (P + nf * T2 - cam.pos)) < 0
    pts = _phone_geom(it, R, P)
    uv, z = cam.project(pts)
    pad = 2 + int(np.ceil(3 * sigma)) + (2 if mirror is None else 8)
    X0, Y0, X1, Y1 = _roi(uv, pad)
    info = {"kind": "phone", "front": front_vis, "map": mapper, "bbox": (X0, Y0, X1, Y1), "H": Hm, "depth": zc,
            "sigma": sigma}
    if X1 <= X0 or Y1 <= Y0 or z.min() < NEAR or it.alpha <= 0:
        return info
    rw, rh = X1 - X0, Y1 - Y0
    off = np.array((X0, Y0), np.float64)
    # couverture : enveloppe convexe du solide
    hull = cv2.convexHull(np.round((uv - off) * 16).astype(np.int32))
    mask = np.zeros((rh, rw), np.uint8)
    cv2.fillConvexPoly(mask, hull, 255, cv2.LINE_AA, 4)
    # tranche
    band = np.zeros((rh, rw, 4), np.uint8)
    quads = _band_quads(cam, R, P, tw, th)
    for _, q, c in sorted(quads, key=lambda x: -x[0]):
        cv2.fillConvexPoly(band, np.round((_grow(q) - off) * 16).astype(np.int32),
                           (int(c[0]), int(c[1]), int(c[2]), 255), cv2.LINE_8, 4)
    if quads:
        empty = band[..., 3] == 0
        if empty.any():
            dil = cv2.dilate(band, np.ones((3, 3), np.uint8))
            band[empty] = dil[empty]
    prem = np.empty((rh, rw, 4), np.float32)
    a = mask.astype(np.float32) * (1.0 / 255)
    prem[..., :3] = band[..., :3].astype(np.float32) * (1.0 / 255) * a[..., None]
    prem[..., 3] = a
    # face visible : écran (avant) ou dos
    if front_vis:
        face, _ = _face_warp(tex, fl, R, P, cam, X0, Y0, rw, rh)
        g = _glass(cam, nf, X0, Y0, rw, rh)
        fa = face[..., 3]
        face[..., :3] += (g * fa)[..., None]
    else:
        back = phone_back_tex()
        bl = np.array([[tw / 2, -th / 2, T2], [-tw / 2, -th / 2, T2], [-tw / 2, th / 2, T2], [tw / 2, th / 2, T2]])
        face, _ = _face_warp(back, bl, R, P, cam, X0, Y0, rw, rh)
        nb = -nf
        lit = 0.62 + 0.5 * max(0.0, float(nb @ _KEY))
        g = _glass(cam, nb, X0, Y0, rw, rh) * 0.45
        fa = face[..., 3]
        face[..., :3] = face[..., :3] * lit + (g * fa)[..., None]
    inv = 1 - fa
    prem[..., :3] = prem[..., :3] * inv[..., None] + face[..., :3]
    prem[..., 3] = np.maximum(prem[..., 3], fa)
    if mirror is not None:
        # reflet : estompé à partir de la ligne de contact (projection du sol sous le téléphone)
        fy, strength = mirror
        cuv_, _ = cam.project(np.array([[P[0], fy, P[2]]]))
        v0 = float(cuv_[0, 1]) - Y0
        hgt = float(np.ptp(uv[:, 1]))
        ys = np.arange(rh, dtype=np.float32)
        fade = np.clip(1 - (ys - v0) / max(0.42 * hgt, 1.0), 0, 1) ** 1.6 * strength
        prem *= fade[:, None, None]
        prem = _blur(prem, max(sigma, 1.6))
        _composite(img, prem, X0, Y0, it.alpha, 0.0, cam, zc, None)
        return info
    if floor_y is not None and it.shadow > 0:
        _floor_shadow(img, cam, pts, floor_y, it.shadow * min(1.0, it.alpha))
    prem = _blur(prem, sigma)
    _composite(img, prem, X0, Y0, it.alpha, it.shadow, cam, zc, floor_y)
    return info


# ---------------------------------------------------------------- extrusion
def _draw_extrude(img, cam: Cam, p: Extrude, sigma: float, zc: float, floor_y) -> dict:
    """Plan extrudé : flancs = empilement de la silhouette (alpha) du fond vers la face (couleur du calque le plus
    avant qui couvre le pixel, dégradé side_back → side, liseré rim), puis la face texturée par-dessus."""
    th, tw = p.tex.shape[:2]
    R = rot(p.yaw, p.pitch, p.roll)
    front = _plane_corners(p)
    back = front + R @ np.array((0.0, 0.0, 1.0)) * p.depth
    uvf, zf = cam.project(front)
    uvb, zb = cam.project(back)
    Hm = cv2.getPerspectiveTransform(np.float32([[0, 0], [tw, 0], [tw, th], [0, th]]), uvf.astype(np.float32))

    def mapper(u, v):
        q = Hm @ np.array([u, v, 1.0])
        return q[0] / q[2], q[1] / q[2]

    info = {"kind": "plane", "corners": uvf, "depth": zc, "sigma": sigma, "H": Hm, "map": mapper,
            "bbox": (0, 0, 0, 0)}
    if p.alpha <= 0 or min(zf.min(), zb.min()) < NEAR:
        return info
    pad = 2 + int(np.ceil(3 * sigma))
    X0, Y0, X1, Y1 = _roi(np.r_[uvf, uvb], pad)
    info["bbox"] = (X0, Y0, X1, Y1)
    if X1 <= X0 or Y1 <= Y0:
        return info
    rw, rh = X1 - X0, Y1 - Y0
    e = np.linalg.norm(np.roll(uvf, -1, 0) - uvf, axis=1)
    s = max((e[0] + e[2]) / (2 * tw), (e[1] + e[3]) / (2 * th))
    lod = max(0.0, float(np.log2(1 / max(s, 1e-6))) - 0.25)
    l0 = int(lod)
    A = np.ascontiguousarray(_mip(p.tex, l0)[..., 3])
    lh, lw = A.shape
    src = np.float32([[-0.5, -0.5], [lw - 0.5, -0.5], [lw - 0.5, lh - 0.5], [-0.5, lh - 0.5]])
    S = _outline_shade(p.tex, l0)
    disp = float(np.abs(uvf - uvb).max())
    n = int(np.clip(np.ceil(disp / 1.0), 1, 48))
    acc = np.zeros((rh, rw), np.float32)
    code = np.zeros((rh, rw), np.float32)       # 2·(rang du calque le plus avant) + ombrage de son contour
    for k in range(n):
        f = (k + 1) / (n + 1)
        uvk, _ = cam.project(back + (front - back) * f)
        Hk = cv2.getPerspectiveTransform(src, (uvk - 0.5 - (X0, Y0)).astype(np.float32))
        kw = dict(flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
        a = cv2.warpPerspective(A, Hk, (rw, rh), **kw)
        sk = cv2.warpPerspective(S, Hk, (rw, rh), **kw)
        acc = cv2.max(acc, a)
        code = cv2.max(code, (a > 0.5).astype(np.float32) * (2 * (k + 1) + np.minimum(sk, 0.999)))
    rank = np.floor(code / 2)
    idx = rank / (n + 1)
    shade = code - 2 * rank
    sb, sf = np.asarray(p.side_back, np.float32) / 255, np.asarray(p.side, np.float32) / 255
    col = (sb + (sf - sb) * (idx[..., None] ** 0.8)) * (0.5 + 0.7 * shade[..., None])
    if p.rim > 0:
        col = col + p.rim * np.clip((idx - 0.86) / 0.1, 0, 1)[..., None] * (1 - col)
    col = np.clip(col, 0, 1)
    prem = np.empty((rh, rw, 4), np.float32)
    prem[..., :3] = col * acc[..., None]
    prem[..., 3] = acc
    dst = (uvf - 0.5 - (X0, Y0)).astype(np.float32)
    face = _warp_level(p.tex, l0, dst, rw, rh)
    fa = face[..., 3]
    prem[..., :3] = prem[..., :3] * (1 - fa)[..., None] + face[..., :3]
    prem[..., 3] = prem[..., 3] * (1 - fa) + fa
    prem = _blur(prem, sigma)
    _composite(img, prem, X0, Y0, p.alpha, p.shadow, cam, zc, floor_y)
    return info


_SHADE: "OrderedDict[tuple, tuple[np.ndarray, np.ndarray]]" = OrderedDict()
_L2 = np.array((-0.42, -0.91), np.float32)          # lumière des flancs : en haut à gauche (texture)


def _outline_shade(tex: np.ndarray, level: int) -> np.ndarray:
    """Ombrage des flancs selon l'orientation du contour (texture, 0..1) : 1 pour un bord tourné vers la lumière
    (en haut à gauche), 0 pour un bord à l'opposé, 0,5 loin des bords. Mis en cache si tex est en lecture seule."""
    key = (id(tex), level)
    ent = _SHADE.get(key) if not tex.flags.writeable else None
    if ent is not None and ent[0] is tex:
        return ent[1]
    A = np.ascontiguousarray(_mip(tex, level)[..., 3])
    b = cv2.GaussianBlur(A, (0, 0), max(1.0, A.shape[0] / 60))
    gx = cv2.Sobel(b, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(b, cv2.CV_32F, 0, 1, ksize=3)
    m = np.sqrt(gx * gx + gy * gy)
    # normale sortante du contour = −gradient de l'alpha
    d = -(gx * _L2[0] + gy * _L2[1]) / np.maximum(m, 1e-6)
    w = np.clip(m / (m.max() * 0.15 + 1e-6), 0, 1)
    S = (0.5 + 0.5 * d * w).astype(np.float32)
    if not tex.flags.writeable:
        _SHADE[key] = (tex, S)
        while len(_SHADE) > 64:
            _SHADE.popitem(last=False)
    return S


def extrude_corners(p: Extrude) -> np.ndarray:
    """Coins monde de la face avant et de la face arrière (boîte de mise en page)."""
    front = _plane_corners(p)
    return np.r_[front, front + rot(p.yaw, p.pitch, p.roll) @ np.array((0.0, 0.0, 1.0)) * p.depth]


def render(img: np.ndarray, cam: Cam, items, floor_y=None, dof_focus=None, dof_scale: float = 0.0,
           reflect: float = 0.0) -> list:
    """Dessine items (Plane / Extrude / PhoneItem) dans img (float32 H×W×3, en place), du plus loin au plus proche.

    - Profondeur de champ : sigma = min(8, |profondeur caméra - dof_focus| · dof_scale) px.
    - Ombres : sans floor_y, ombre douce portée sur le fond (décalée vers le bas) ;
      avec floor_y (hauteur monde du sol, y vers le bas), ombre de contact posée sur ce sol.
    - reflect > 0 (avec floor_y) : sol brillant, les téléphones s'y reflètent (dessinés d'abord, sous les ombres).
    Renvoie les info dans l'ordre de items (pour un téléphone : avec "map", "front").
    """
    items = list(items)
    depth = [float(cam.to_cam(np.asarray(it.center, np.float64)[None])[0, 2]) for it in items]
    infos: list = [None] * len(items)
    order = sorted(range(len(items)), key=lambda k: -depth[k])

    def sig(zc):
        if dof_focus is not None and dof_scale > 0:
            return min(MAX_SIGMA, abs(zc - dof_focus) * dof_scale)
        return 0.0
    if reflect > 0 and floor_y is not None:
        for i in order:
            it = items[i]
            if isinstance(it, PhoneItem) and it.alpha > 0:
                _draw_phone(img, cam, it, sig(depth[i]), depth[i], floor_y, mirror=(floor_y, reflect))
    for i in order:
        it, zc = items[i], depth[i]
        sigma = sig(zc)
        if isinstance(it, PhoneItem):
            infos[i] = _draw_phone(img, cam, it, sigma, zc, floor_y)
        elif isinstance(it, Extrude):
            infos[i] = _draw_extrude(img, cam, it, max(sigma, it.blur), zc, floor_y)
        else:
            infos[i] = _draw_plane(img, cam, it, max(sigma, it.blur), zc, floor_y)
    return infos
