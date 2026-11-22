"""Éléments d'interface de TapLoad générés en code, dans le style exact des captures Android.

Toutes les fonctions renvoient un RGBA uint8 en lecture seule (couleur non prémultipliée, transparent hors
de la forme, bords anti-crénelés), mis en cache pour être réutilisé d'une image à l'autre. Échelle des
captures : 1170 px de large (3 px par dp). Mesures relevées sur les captures (`film.assets.load_screen`) :
fond #000000 avec une trame de points 4×4 au pas de 30 px, cartes #0B0B0B à bord #272727 de 3 px,
rayons 40-56 px, texte blanc (244, 244, 242), texte secondaire (161, 161, 160), rouge (255, 74, 61),
chiffres matriciels 5×7 à cellules carrées (cellule = 0,83 × pas).
"""
from functools import lru_cache
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageFont

from film import assets, config
from film.typo import SS, text_layer
from reel import core  # noqa: F401  (déclare les graisses "regular", "mono"… dans config.FONTS)
from reel.core import FONT

# Chiffres matriciels tels que l'appli les dessine (relevés sur « 236 » de Statistiques et sur la version
# yt-dlp « 2026.11.17.232707 » des Réglages) ; 4, 5, 8, 9 n'apparaissent dans aucune capture : glyphes
# 5×7 classiques de reel.core.FONT.
_APP_DIGITS = {
    "0": "..#.. .#.#. #...# #...# #...# .#.#. ..#..",
    "1": "..#.. .##.. #.#.. ..#.. ..#.. ..#.. #####",
    "2": ".###. #...# ....# ..##. .#... #.... #####",
    "3": "##### ....# ...#. ..##. ....# #...# .###.",
    "6": "..##. .#... #.... #.##. ##..# #...# .###.",
    "7": "##### ....# ...#. ...#. ..#.. .#... .#...",
}
MATRIX = {**FONT, **{k: v.split() for k, v in _APP_DIGITS.items()}}

APP_NAME = config.COPY["name"]     # « TapLoad »
ROOT = Path(__file__).resolve().parent.parent
LOGO = ROOT / "assets" / "brand" / "logo-1024.png"
THUMB = ROOT / "assets" / "brand" / "demo-thumb.png"

# ---------------------------------------------------------------- palette relevée sur les captures
BLACK = (0, 0, 0)
CARD = (11, 11, 11)          # fond des cartes
CARD_DOT = (28, 28, 28)      # trame de points dans les cartes
EDGE = (39, 39, 39)          # bord des cartes
EDGE_HI = (54, 54, 53)       # bord du champ d'URL, des boutons ronds
SURFACE = (20, 20, 20)       # surfaces système (feuille de partage, notification) : #141414
SURFACE_EDGE = (38, 38, 38)  # #262626
CELL = (37, 37, 37)          # carrés de progression vides
WHITE = (244, 244, 242)
GREY = (161, 161, 160)
RED = (255, 74, 61)

# ---------------------------------------------------------------- vues éclatées (boîtes x0, y0, x1, y1)
# Chaque boîte entoure l'élément d'une marge de fond noir (24 px env.) : la découpe arrondie de crop()
# ne mord jamais dans les coins arrondis propres aux cartes.
CROPS: dict[str, tuple[str, tuple[int, int, int, int]]] = {
    "url": ("capture", (36, 246, 1134, 462)),            # champ d'URL (bord y 270-438)
    "video_card": ("capture", (36, 452, 1134, 718)),     # vignette + titre (carte y 474-696)
    "toggle": ("capture", (36, 716, 1134, 916)),         # Vidéo / Audio seul (bord y 738-894)
    "qualities": ("capture", (36, 900, 1134, 1758)),     # 4 lignes de qualité (y 924-1734)
    "download_btn": ("capture", (30, 1922, 1140, 2140)),  # Qualité choisie + « Max » + Télécharger
    "live_chart": ("done", (24, 399, 1146, 1161)),       # carte Débit en direct (y 423-1137)
    "heatmap": ("stats", (36, 729, 1134, 1623)),         # carte Activité (y 753-1599)
    "radar": ("send", (215, 478, 955, 1218)),            # cercles en pointillés + bouton central
    "ytdlp": ("settings", (36, 261, 1134, 939)),         # carte Moteur yt-dlp (y 285-915)
    "parallel": ("settings", (36, 890, 1134, 1218)),     # carte Téléchargements en parallèle (y 912-1196)
    "by_source": ("stats", (36, 1578, 1134, 2024)),      # carte Téléchargements par source (y 1600-2002)
}


# ================================================================ rendu : toile prémultipliée + SDF
class _Canvas:
    """Toile RGBA flottante en alpha prémultiplié ; les formes sont décrites par des distances signées."""

    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.p = np.zeros((h, w, 3), np.float32)
        self.a = np.zeros((h, w), np.float32)

    # -- composition « over » d'une couverture (0..1) sur une fenêtre
    def cover(self, cov: np.ndarray, color, x0: int = 0, y0: int = 0, alpha: float = 1.0):
        h, w = cov.shape
        sx0, sy0 = max(x0, 0), max(y0, 0)
        sx1, sy1 = min(x0 + w, self.w), min(y0 + h, self.h)
        if sx1 <= sx0 or sy1 <= sy0:
            return
        c = cov[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0] * alpha
        col = np.asarray(color, np.float32) / 255
        P = self.p[sy0:sy1, sx0:sx1]
        P *= (1 - c)[..., None]
        P += c[..., None] * col
        A = self.a[sy0:sy1, sx0:sx1]
        A *= 1 - c
        A += c

    def _grid(self, x0, y0, x1, y1, pad=2):
        bx0, by0 = int(np.floor(x0)) - pad, int(np.floor(y0)) - pad
        bx1, by1 = int(np.ceil(x1)) + pad, int(np.ceil(y1)) + pad
        ys, xs = np.mgrid[by0:by1, bx0:bx1].astype(np.float32)
        return xs + 0.5, ys + 0.5, bx0, by0

    # -- formes
    def rrect(self, x0, y0, x1, y1, r, fill=None, border=None, bw=3.0, alpha=1.0):
        X, Y, bx, by = self._grid(x0, y0, x1, y1)
        d = _sdf_rrect(X, Y, x0, y0, x1, y1, r)
        if fill is not None:
            self.cover(np.clip(0.5 - d, 0, 1), fill, bx, by, alpha)
        if border is not None:
            di = _sdf_rrect(X, Y, x0 + bw, y0 + bw, x1 - bw, y1 - bw, max(r - bw, 0))
            ring = np.clip(0.5 - d, 0, 1) * np.clip(0.5 + di, 0, 1)
            self.cover(ring, border, bx, by, alpha)

    def circle(self, cx, cy, r, fill=None, border=None, bw=3.0):
        X, Y, bx, by = self._grid(cx - r, cy - r, cx + r, cy + r)
        d = np.hypot(X - cx, Y - cy) - r
        if fill is not None:
            self.cover(np.clip(0.5 - d, 0, 1), fill, bx, by)
        if border is not None:
            self.cover(np.clip(0.5 - d, 0, 1) * np.clip(0.5 + d + bw, 0, 1), border, bx, by)

    def stroke(self, pts, width, color):
        """Polyligne à bouts et jointures arrondis (union de capsules)."""
        pts = np.asarray(pts, np.float32)
        hw = width / 2
        X, Y, bx, by = self._grid(pts[:, 0].min() - hw, pts[:, 1].min() - hw,
                                  pts[:, 0].max() + hw, pts[:, 1].max() + hw)
        d = np.full(X.shape, 1e9, np.float32)
        for (ax, ay), (cx, cy) in zip(pts[:-1], pts[1:]):
            vx, vy = cx - ax, cy - ay
            t = np.clip(((X - ax) * vx + (Y - ay) * vy) / max(vx * vx + vy * vy, 1e-6), 0, 1)
            d = np.minimum(d, np.hypot(X - ax - t * vx, Y - ay - t * vy))
        self.cover(np.clip(0.5 - (d - hw), 0, 1), color, bx, by)

    # -- images
    def image(self, rgba: np.ndarray, x: int, y: int, alpha: float = 1.0):
        """Colle un RGBA uint8 (non prémultiplié) en (x, y) entiers."""
        a = rgba[..., 3].astype(np.float32) / 255 * alpha
        h, w = a.shape
        sx0, sy0 = max(x, 0), max(y, 0)
        sx1, sy1 = min(x + w, self.w), min(y + h, self.h)
        if sx1 <= sx0 or sy1 <= sy0:
            return
        c = a[sy0 - y:sy1 - y, sx0 - x:sx1 - x]
        col = rgba[sy0 - y:sy1 - y, sx0 - x:sx1 - x, :3].astype(np.float32) / 255
        P = self.p[sy0:sy1, sx0:sx1]
        P *= (1 - c)[..., None]
        P += c[..., None] * col
        A = self.a[sy0:sy1, sx0:sx1]
        A *= 1 - c
        A += c

    def text(self, s, size, x, baseline, color=WHITE, weight="medium", align="left", tracking=0.0):
        """Texte Inter posé sur sa ligne de base ; renvoie sa largeur d'encre approximative."""
        lay = text_layer(s, size, weight, tracking, tuple(int(c) for c in color))
        pad = 4
        w = lay.shape[1] - 2 * pad
        left = x if align == "left" else x - w if align == "right" else x - w / 2
        top = baseline - (pad * SS + _ascent(size, weight)) / SS
        self.image(lay, int(round(left)) - pad, int(round(top)))
        return w

    def dots_texture(self, x0, y0, x1, y1, color, pitch=30, size=4, offset=13):
        """Trame de points de l'appli (carrés 4×4 au pas de 30 px), limitée au rectangle donné."""
        for y in range(offset, self.h, pitch):
            if y < y0 or y + size > y1:
                continue
            for x in range(offset, self.w, pitch):
                if x0 <= x and x + size <= x1:
                    self.p[y:y + size, x:x + size] = np.asarray(color, np.float32) / 255 * self.a[y:y + size, x:x + size, None]

    def matrix(self, s, x, top, pitch, color=WHITE):
        """Chiffres matriciels 5×7 de l'appli (MATRIX, à défaut reel.core.FONT), comme « 236 » (Statistiques) ou « Max »."""
        cell = pitch * 0.83
        adv = pitch * 5.8
        for i, ch in enumerate(s):
            rows = MATRIX[ch]
            for r, line in enumerate(rows):
                for c, on in enumerate(line):
                    if on == "#":
                        cx0 = x + i * adv + c * pitch
                        cy0 = top + r * pitch
                        self.rrect(cx0, cy0, cx0 + cell, cy0 + cell, max(cell * 0.06, 0.5), fill=color)
        return len(s) * adv - (adv - 4 * pitch - cell)

    # -- sortie
    def rgba(self, mask: np.ndarray | None = None) -> np.ndarray:
        a = self.a if mask is None else self.a * mask
        rgb = np.where(self.a[..., None] > 1e-6, self.p / np.maximum(self.a, 1e-6)[..., None], 0)
        out = np.empty((self.h, self.w, 4), np.uint8)
        out[..., :3] = np.clip(rgb * 255 + 0.5, 0, 255).astype(np.uint8)
        out[..., 3] = np.clip(a * 255 + 0.5, 0, 255).astype(np.uint8)
        out.setflags(write=False)
        return out


def _sdf_rrect(X, Y, x0, y0, x1, y1, r):
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx, qy = np.abs(X - cx) - hx, np.abs(Y - cy) - hy
    out = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    return out + np.minimum(np.maximum(qx, qy), 0) - r


def _rrect_mask(w: int, h: int, r: float) -> np.ndarray:
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    return np.clip(0.5 - _sdf_rrect(xs + 0.5, ys + 0.5, 0, 0, w, h, r), 0, 1)


@lru_cache(maxsize=64)
def _ascent(size: int, weight: str) -> int:
    return ImageFont.truetype(str(config.FONTS[weight]), size * SS).getmetrics()[0]


def _fit(s: str, size: int, max_w: float, weight="medium") -> str:
    """Tronque avec « … » comme Flutter (TextOverflow.ellipsis)."""
    def width(t):
        return text_layer(t, size, weight, 0.0, WHITE).shape[1] - 8
    if width(s) <= max_w:
        return s
    while s and width(s.rstrip() + "…") > max_w:
        s = s[:-1]
    return s.rstrip() + "…"


def _resize_rgba(rgba: np.ndarray, w: int, h: int) -> np.ndarray:
    """Redimensionne en alpha prémultiplié (pas de liseré sombre)."""
    f = rgba.astype(np.float32) / 255
    f[..., :3] *= f[..., 3:]
    interp = cv2.INTER_AREA if w < rgba.shape[1] else cv2.INTER_CUBIC
    g = np.clip(cv2.resize(f, (w, h), interpolation=interp), 0, 1)
    rgb = np.where(g[..., 3:] > 1e-6, g[..., :3] / np.maximum(g[..., 3:], 1e-6), 0)
    out = np.empty((h, w, 4), np.uint8)
    out[..., :3] = np.clip(rgb * 255 + 0.5, 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(g[..., 3] * 255 + 0.5, 0, 255).astype(np.uint8)
    return out


# ================================================================ éléments
@lru_cache(maxsize=16)
def app_icon(size: int) -> np.ndarray:
    """Icône de l'appli (logo-1024.png, coins déjà transparents) à size × size."""
    logo = np.asarray(Image.open(LOGO).convert("RGBA"))
    out = _resize_rgba(logo, size, size)
    out[0, 0, 3] = out[0, -1, 3] = out[-1, 0, 3] = out[-1, -1, 3] = 0
    out.setflags(write=False)
    return out


def crop(key: str, box, radius: int = 28) -> np.ndarray:
    """Découpe arrondie (anti-crénelée) d'une vraie capture, pour les vues éclatées (box : tuple ou liste)."""
    return _crop(key, tuple(int(v) for v in box), int(radius))


@lru_cache(maxsize=64)
def _crop(key: str, box: tuple[int, int, int, int], radius: int) -> np.ndarray:
    x0, y0, x1, y1 = (int(v) for v in box)
    scr = assets.load_screen(key)
    w, h = x1 - x0, y1 - y0
    out = np.empty((h, w, 4), np.uint8)
    out[..., :3] = scr[y0:y1, x0:x1]
    out[..., 3] = np.clip(_rrect_mask(w, h, radius) * 255 + 0.5, 0, 255).astype(np.uint8)
    out.setflags(write=False)
    return out


@lru_cache(maxsize=8)
def _thumb(w: int, h: int, r: float) -> np.ndarray:
    img = np.asarray(Image.open(THUMB).convert("RGB"))
    img = cv2.resize(img, (w, h), interpolation=cv2.INTER_AREA)
    out = np.empty((h, w, 4), np.uint8)
    out[..., :3] = img
    out[..., 3] = np.clip(_rrect_mask(w, h, r) * 255 + 0.5, 0, 255).astype(np.uint8)
    return out


def _icon_copy(cv: _Canvas, cx, cy, s=1.0, color=WHITE, lw=5.0):
    # Deux feuilles décalées (forme « content_copy ») : feuille avant entière, feuille arrière en L.
    cv.rrect(cx - 10 * s, cy - 16 * s, cx + 26 * s, cy + 28 * s, 6 * s, border=color, bw=lw)
    cv.stroke([(cx - 24 * s, cy + 16 * s), (cx - 24 * s, cy - 24 * s), (cx - 21 * s, cy - 28 * s),
               (cx + 14 * s, cy - 28 * s)], lw, color)


def _icon_more(cv: _Canvas, cx, cy, s=1.0, color=WHITE):
    for dx in (-22, 0, 22):
        cv.circle(cx + dx * s, cy, 5.5 * s, fill=color)


def _icon_print(cv: _Canvas, cx, cy, bg, s=1.0, color=WHITE, lw=5.0):
    # Imprimante : feuille du haut, corps, feuille de sortie devant le corps.
    cv.stroke([(cx - 18 * s, cy - 12 * s), (cx - 18 * s, cy - 30 * s), (cx + 18 * s, cy - 30 * s),
               (cx + 18 * s, cy - 12 * s)], lw, color)
    cv.rrect(cx - 34 * s, cy - 12 * s, cx + 34 * s, cy + 20 * s, 7 * s, border=color, bw=lw)
    cv.rrect(cx - 18 * s, cy + 4 * s, cx + 18 * s, cy + 32 * s, 2 * s, fill=bg)
    cv.rrect(cx - 18 * s - lw / 2, cy + 4 * s - lw / 2, cx + 18 * s + lw / 2, cy + 32 * s + lw / 2,
             3 * s, border=color, bw=lw)
    cv.circle(cx + 23 * s, cy - 2 * s, 3.2 * s, fill=color)


# Corps de texte au réglage « Grande » de la taille de police Android (×1,2 environ) : les éléments générés
# restent lisibles une fois posés dans le film (hauteur de capitale ≥ 18 px à l'écran quand ils sont le sujet).
SHARE_W, SHARE_H = 1170, 812
SHARE_ICON = 150   # taille de l'icône TapLoad dans la feuille de partage
SHARE_TILE = (60 + 1050 * 0.5 / 4 - 130, 446, 60 + 1050 * 0.5 / 4 + 130, 762)   # tuile TapLoad (x0, y0, x1, y1)
SHARE_MIN_TEXT = 44   # plus petit corps de la feuille (libellés des cibles)


SHARE_PARTS = ("base", "preview", "targets")


@lru_cache(maxsize=1)
def share_sheet() -> np.ndarray:
    """Feuille de partage Android (bas d'écran) avec TapLoad mis en évidence."""
    return _share(SHARE_PARTS)


@lru_cache(maxsize=4)
def share_layer(part: str) -> np.ndarray:
    """Une couche de la feuille de partage (même cadre que share_sheet) pour la vue éclatée : « base » (surface,
    poignée, « Partager »), « preview » (aperçu du lien), « targets » (rangée de cibles)."""
    return _share((part,))


def _share(parts) -> np.ndarray:
    W_, H_ = SHARE_W, SHARE_H
    cv = _Canvas(W_, H_)
    if "base" in parts:
        cv.rrect(0, 0, W_, H_, 56, fill=SURFACE, border=SURFACE_EDGE, bw=2)
        cv.rrect(W_ / 2 - 50, 26, W_ / 2 + 50, 38, 6, fill=(72, 72, 72))          # poignée
        cv.text("Partager", 54, 60, 128, WHITE)

    # aperçu du lien (même gabarit que la carte vidéo de « Nouveau téléchargement »)
    py0, py1 = 168, 398
    if "preview" in parts:
        cv.rrect(60, py0, 1110, py1, 44, fill=CARD, border=EDGE, bw=3)
        tw, th = 286, 161
        cv.image(_thumb(tw, th, 18), 92, (py0 + py1 - th) // 2)
        tx = 92 + tw + 39
        cv.text(_fit(assets.SELF["title"], 50, 1110 - 30 - tx), 50, tx, py0 + 102, WHITE)
        cv.text("m.youtube.com/watch?…", SHARE_MIN_TEXT, tx, py0 + 164, GREY)

    if "targets" not in parts:
        return cv.rgba()
    # rangée de cibles
    ty0, ty1 = SHARE_TILE[1], SHARE_TILE[3]
    cols = [60 + 1050 * (i + 0.5) / 4 for i in range(4)]
    icy = ty0 + 34 + SHARE_ICON / 2
    lab = ty0 + 34 + SHARE_ICON + 74
    # TapLoad : tuile sélectionnée (bord blanc comme la qualité choisie)
    cv.rrect(cols[0] - 130, ty0, cols[0] + 130, ty1, 44, fill=CARD, border=WHITE, bw=4)
    ic = app_icon(SHARE_ICON)
    cv.image(ic, int(round(cols[0] - SHARE_ICON / 2)), int(round(icy - SHARE_ICON / 2)))
    cv.text(APP_NAME, SHARE_MIN_TEXT, cols[0], lab, WHITE, align="center")
    # actions système génériques : rond sombre bordé (style des boutons − / + des Réglages)
    for cx, label in zip(cols[1:], ("Copier", "Plus", "Imprimer")):
        cv.circle(cx, icy, SHARE_ICON / 2 - 6, fill=CARD, border=EDGE_HI, bw=3)
        if label == "Copier":
            _icon_copy(cv, cx, icy)
        elif label == "Plus":
            _icon_more(cv, cx, icy)
        else:
            _icon_print(cv, cx, icy, CARD)
        cv.text(label, SHARE_MIN_TEXT, cx, lab, GREY, align="center")
    return cv.rgba()


NOTIF_W, NOTIF_H = 1100, 252
NOTIF_H2 = 304        # notification déployée : corps sur deux lignes
NOTIF_MIN_TEXT = 38   # « TapLoad · maintenant »

# Les seules notifications de l'appli (lib/l10n/app_fr.arb, NotificationService) : titre → corps (motif).
# Rien d'autre ne peut être dessiné comme notification de TapLoad.
REAL_NOTIFICATIONS = {
    "Téléchargement terminé": r".+",                                    # corps = titre du fichier
    "Téléchargement échoué": r".+",                                     # titre + erreur
    "Lien détecté": r"Cliquez pour télécharger : \S+",
    "Liens en file": r"1 lien en file|([2-9]|[1-9]\d+) liens en file",
    "Extension connectée": r"L'extension de navigateur est connectée\.",
    "Lot terminé": r"([2-9]|[1-9]\d+) téléchargements terminés — \S.* au total",
    "yt-dlp mis à jour": r"Mis à jour vers \S+",
}


def is_real_notification(title: str, body: str) -> bool:
    import re
    pat = REAL_NOTIFICATIONS.get(title)
    return pat is not None and re.fullmatch(pat, body) is not None


def _wrap2(s: str, size: int, max_w: float) -> list[str]:
    """Corps sur deux lignes au plus (notification déployée) : coupure aux espaces, ellipse sur la 2e ligne."""
    def width(t):
        return text_layer(t, size, "medium", 0.0, WHITE).shape[1] - 8
    if width(s) <= max_w:
        return [s]
    if " — " in s:                       # coupure naturelle après le tiret cadratin
        a, b = s.split(" — ", 1)
        if width(a + " —") <= max_w:
            return [a + " —", _fit(b, size, max_w)]
    words = s.split(" ")
    line = words[0]
    for i, w in enumerate(words[1:], 1):
        if width(line + " " + w) > max_w:
            return [line, _fit(" ".join(words[i:]), size, max_w)]
        line += " " + w
    return [line]


@lru_cache(maxsize=32)
def notification(title: str, body: str, glass: bool = False, expanded: bool = False) -> np.ndarray:
    """Notification Android de l'appli : icône 104 px, « TapLoad · maintenant », titre, corps (une ligne avec ellipse,
    ou deux lignes si expanded). Seulement les vraies notifications de l'appli (REAL_NOTIFICATIONS).
    glass : carte de verre fumé (fond légèrement translucide, liseré clair en haut, reflet diagonal)."""
    if not is_real_notification(title, body):
        raise ValueError(f"notification inexistante dans l'appli : {title!r} / {body!r}")
    tx = 40 + 104 + 34
    maxw = NOTIF_W - 60 - tx
    lines = _wrap2(body, 42, maxw) if expanded else [_fit(body, 42, maxw)]
    h = NOTIF_H if len(lines) == 1 else NOTIF_H2
    cv = _Canvas(NOTIF_W, h)
    cv.rrect(0, 0, NOTIF_W, h, 64, fill=SURFACE, border=SURFACE_EDGE, bw=2, alpha=0.93 if glass else 1.0)
    if glass:
        X, Y, bx, by = cv._grid(0, 0, NOTIF_W, h)
        inside = np.clip(0.5 - _sdf_rrect(X, Y, 3, 3, NOTIF_W - 3, h - 3, 61), 0, 1)
        sheen = np.exp(-(((X / NOTIF_W) * 0.8 + (Y / h) * 0.35 - 0.32) / 0.1) ** 2) * 0.10
        cv.cover((inside * sheen).astype(np.float32), (255, 255, 255), bx, by)
        top = np.clip(0.5 - _sdf_rrect(X, Y, 2, 2, NOTIF_W - 2, h - 2, 62), 0, 1) * \
            np.clip(0.5 + _sdf_rrect(X, Y, 2, 4.5, NOTIF_W - 2, h - 2, 62), 0, 1) * np.clip(1 - Y / 40, 0, 1)
        cv.cover((top * 0.55).astype(np.float32), (255, 255, 255), bx, by)
    ix, iy = 40, (NOTIF_H - 104) // 2
    cv.image(app_icon(104), ix, iy)
    cv.text(f"{APP_NAME} · maintenant", NOTIF_MIN_TEXT, tx, 76, GREY)
    cv.text(_fit(title, 50, maxw), 50, tx, 142, WHITE)
    for i, ln in enumerate(lines):
        cv.text(ln, 42, tx, 202 + 52 * i, GREY)
    # chevron d'extension (vers le haut quand la notification est déployée)
    ex, ey = NOTIF_W - 62, 62
    d = -1 if len(lines) > 1 else 1
    cv.stroke([(ex - 11, ey - 5 * d), (ex, ey + 6 * d), (ex + 11, ey - 5 * d)], 4, GREY)
    return cv.rgba()


PROG_W, PROG_H = 1074, 456
PROG_MIN_TEXT = 38   # titre et « YouTube »
_COLS, _ROWS, _PITCH, _CELL = 24, 3, 41, 32
_QUANT = 100  # pourcentage quantifié au 1 % : au plus 101 cartes distinctes (~2 Mo chacune) en cache


@lru_cache(maxsize=1)
def _progress_base() -> _Canvas:
    cv = _Canvas(PROG_W, PROG_H)
    cv.rrect(0, 0, PROG_W, PROG_H, 56, fill=CARD)
    cv.dots_texture(8, 8, PROG_W - 8, PROG_H - 8, CARD_DOT)
    cv.rrect(0, 0, PROG_W, PROG_H, 56, border=EDGE, bw=3)
    cv.text(assets.SELF["title"], 38, 52, 98, WHITE)
    cv.text("YouTube", 38, PROG_W - 50, 98, GREY, align="right")
    return cv


HOT = (255, 196, 186)   # carrés qui viennent de se remplir (éclat bref avant de se poser en rouge)


@lru_cache(maxsize=128)
def _progress_card(q: int, hot_from: int = -1, heat: int = 0) -> np.ndarray:
    base = _progress_base()
    cv = _Canvas(PROG_W, PROG_H)
    cv.p[:] = base.p
    cv.a[:] = base.a
    fill = q / _QUANT * _COLS * _ROWS        # nombre de carrés remplis (colonne par colonne)
    gx, gy = 48, 144
    red, grey = np.array(RED, np.float32), np.array(CELL, np.float32)
    hot = red + (np.array(HOT, np.float32) - red) * (heat / 8)
    first_hot = hot_from / _QUANT * _COLS * _ROWS if hot_from >= 0 else 1e9
    for c in range(_COLS):
        for r in range(_ROWS):
            k = c * _ROWS + r
            f = float(np.clip(fill - k, 0, 1))
            col = grey + ((hot if k + 1 > first_hot else red) - grey) * f
            x0, y0 = gx + c * _PITCH, gy + r * _PITCH
            cv.rrect(x0, y0, x0 + _CELL, y0 + _CELL, 6, fill=tuple(col))
    pct = q * 100 // _QUANT
    top, pitch = gy + 2 * _PITCH + _CELL + 54, 13
    w = cv.matrix(str(pct), 50, top, pitch, WHITE)
    cv.text("%", 48, 50 + w + 24, top + 7 * pitch - pitch * 0.17, GREY)
    return cv.rgba()


def progress_card(pct: float, hot_from: float | None = None, heat: float = 0.0) -> np.ndarray:
    """Carte de progression (style « Débit en direct ») : titre, grille 24×3 et pourcentage matriciel.

    hot_from, heat : les carrés remplis au-delà de hot_from (fraction) brillent (heat 0..1, quantifié en 8 pas)."""
    q = int(round(float(np.clip(pct, 0, 1)) * _QUANT))
    hq = int(round(heat * 8))
    if hot_from is None or hq <= 0:
        return _progress_card(q)
    return _progress_card(q, int(round(float(np.clip(hot_from, 0, 1)) * _QUANT)), hq)


# ================================================================ vignette de la vidéo de démo
THUMB_CREDIT = ("Musique : « Future Bass Lite », NERDtasticBEATS (CC BY 4.0)  ·  "
                "Big Buck Bunny © Blender Foundation (CC BY 3.0)")


def demo_thumb(path=THUMB) -> np.ndarray:
    """(Re)dessine assets/brand/demo-thumb.png : carte de fin du film clair v3 (light.film.s_end posée),
    avec le nom APP_NAME. Vignette de la vidéo « TapLoad — Présentation » montrée dans les captures."""
    from . import film, style as S
    img = S.background()
    img = film.put_icon(img, 960, 380, 221)
    for s, size, y, wt, col in ((APP_NAME, 110, 640, "black", S.INK),
                                ("Android · Windows · Open source", 36, 740, "dmedium", S.GREY),
                                ("github.com/itsnazzym/Downloader", 30, 820, "mono", S.INK),
                                (THUMB_CREDIT, 18, 1035, "regular", S.GREY)):
        img = film.word(img, s, size, 960, y, 1.0, 0.0, "center", color=col, weight=wt)
    out = S.finish(img, 0)                   # même grain que l'original (pas de bandes dans le dégradé)
    Image.fromarray(out).save(path)
    return out


# ================================================================ planche de contrôle
def control_sheet(path) -> np.ndarray:
    """Pose tous les éléments sur le fond clair du film (light.style.background()) et écrit un PNG."""
    from .style import background

    items = [("share_sheet", share_sheet()),
             ("notif_fin", notification("Téléchargement terminé", assets.SELF["title"])),
             ("notif_file", notification("Liens en file", "1 lien en file", glass=True)),
             ("icon", app_icon(160))]
    items += [(f"progress {p:.0%}", progress_card(p)) for p in (0.0, 0.47, 1.0)]
    items += [(f"crop {k}", crop(*CROPS[k])) for k in CROPS]
    gap, col_h = 60, 2700
    cols, cur, h = [], [], 0
    for name, a in items:
        if cur and h + a.shape[0] + gap > col_h:
            cols.append(cur)
            cur, h = [], 0
        cur.append(a)
        h += a.shape[0] + gap
    cols.append(cur)
    W_ = sum(max(a.shape[1] for a in c) + gap for c in cols) + gap
    H_ = col_h + gap
    bg = cv2.resize(background(), (W_, H_), interpolation=cv2.INTER_LINEAR)
    x = gap
    for c in cols:
        y = gap
        for a in c:
            f = a.astype(np.float32) / 255
            reg = bg[y:y + a.shape[0], x:x + a.shape[1]]
            reg[:] = reg * (1 - f[..., 3:]) + f[..., :3] * f[..., 3:]
            y += a.shape[0] + gap
        x += max(a.shape[1] for a in c) + gap
    out = (np.clip(bg, 0, 1) * 255 + 0.5).astype(np.uint8)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(path), out[..., ::-1])
    return out


if __name__ == "__main__":
    import light  # noqa: F401  (la démo des captures est le film lui-même)
    control_sheet(ROOT / "out" / "light4" / "ui_sheet.png")
