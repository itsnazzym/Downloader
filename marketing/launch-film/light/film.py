"""Film v3 « clair » : chaque animation part d'un coup réel de la musique (voir beats.py).

Sections = phrases musicales de 2 mesures. Dans chaque section, les événements (mots, puces, coupes, paquets...)
tombent sur les coups les plus forts de la phrase ; tous les autres coups donnent une petite impulsion.
"""
import math
from functools import lru_cache

import cv2
import numpy as np
from PIL import Image

from film import config

from reel.core import Cam, bezier, dir_blur, draw_phone, paste, text_layer
from reel.ease import in_out_cubic, out_back, out_expo, progress, spring

from . import beats as B
from . import style as S

APP_NAME = config.COPY["name"]

W, H = 1920, 1080
CAM = Cam(f=1500)
P = B.phrases()  # débuts de phrase (P[0] = drop)
SECTIONS = [("intro", 0.0, P[0]), ("hero", P[0], P[1]), ("quality", P[1], P[2]), ("browser", P[2], P[3]),
            ("progress", P[3], P[4]), ("send", P[4], P[5]), ("montage", P[5], P[6]), ("words", P[6], P[7]),
            ("wall", P[7], B.MUSIC_LEN), ("end", B.MUSIC_LEN, B.DUR)]
T_ALL, S_ALL = B.hits()


def pick(a: float, b: float, n: int, min_gap: float = 0.25, min_s: float = 0.0) -> list[float]:
    """Les n coups les plus forts de [a, b), espacés d'au moins min_gap, triés dans le temps."""
    m = (T_ALL >= a) & (T_ALL < b) & (S_ALL >= min_s)
    t, s = T_ALL[m], S_ALL[m]
    chosen = []
    for i in np.argsort(-s):
        if all(abs(t[i] - c) >= min_gap for c in chosen):
            chosen.append(float(t[i]))
        if len(chosen) == n:
            break
    return sorted(chosen)


def pulse(t: float, tau: float = 0.09) -> float:
    """Impulsion pondérée par la force du dernier coup."""
    i, h = B.last(t, T_ALL)
    if i < 0:
        return 0.0
    return float(min(1.0, S_ALL[i]) * math.exp(-(t - h) / tau))


def k_in(t: float, t0: float, d: float = 0.16) -> float:
    return out_expo(progress(t, t0, t0 + d))


def nth(t: float, events: list[float]) -> int:
    """Nombre d'événements déjà passés."""
    return int(np.searchsorted(np.asarray(events), t + 1e-9))


def phone(img, key, x, y, z, yaw=0.0, pitch=0.0, roll=0.0, alpha=1.0, shadow=0.32):
    return draw_phone(img, key, (x, y, z), yaw, pitch, roll, cam=CAM, alpha=alpha, shadow=shadow,
                      shadow_off=(-0.012 * yaw * 30, 55), gloss=0.1)


@lru_cache(maxsize=4)
def icon(size: int) -> np.ndarray:
    im = Image.open(B.ROOT / "assets" / "brand" / "logo-1024.png").convert("RGBA").resize((size, size), Image.LANCZOS)
    return np.asarray(im)


def put_icon(img, cx, cy, size, alpha=1.0, shadow=0.3):
    lay = icon(int(size))
    a = lay[..., 3].astype(np.float32) / 255
    if shadow > 0:
        sh = cv2.GaussianBlur(np.pad(a, 60), (0, 0), size * 0.06) * shadow * alpha
        x0, y0 = int(cx - size / 2 - 60), int(cy - size / 2 - 60 + size * 0.06)
        _mul(img, 1 - sh, x0, y0)
    return paste(img, lay, cx, cy, alpha=alpha)


def _mul(img, m, x0, y0):
    h, w = m.shape
    gx0, gy0, gx1, gy1 = max(0, x0), max(0, y0), min(W, x0 + w), min(H, y0 + h)
    if gx1 > gx0 and gy1 > gy0:
        img[gy0:gy1, gx0:gx1] *= m[gy0 - y0:gy1 - y0, gx0 - x0:gx1 - x0, None]


def chip(img, label, cx, cy, scale=1.0, alpha=1.0, dark=False):
    """Puce arrondie (fond blanc, ombre douce) avec un libellé."""
    if alpha <= 0 or scale <= 0.02:
        return img
    lay = text_layer(label, 34, "semibold", -0.01, (255, 255, 255) if dark else S.INK)
    w, h = lay.shape[1] + 56, 74
    pad = 40
    m = np.zeros((h + 2 * pad, w + 2 * pad), np.uint8)
    cv2.rectangle(m, (pad, pad), (pad + w, pad + h), 255, -1)
    m = cv2.GaussianBlur(m, (0, 0), 0.1)
    pill = np.zeros((h * 4, w * 4), np.uint8)
    cv2.rectangle(pill, (h * 2, 0), (w * 4 - h * 2, h * 4), 255, -1)
    cv2.circle(pill, (h * 2, h * 2), h * 2, 255, -1)
    cv2.circle(pill, (w * 4 - h * 2, h * 2), h * 2, 255, -1)
    pill = cv2.resize(pill, (w, h), interpolation=cv2.INTER_AREA).astype(np.float32) / 255
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[..., :3] = (29, 29, 31) if dark else (255, 255, 255)
    rgba[..., 3] = (pill * 255).astype(np.uint8)
    # ombre
    sh = cv2.GaussianBlur(np.pad(pill, 40), (0, 0), 14) * 0.18 * alpha
    hw, hh = (w + 80) * scale, (h + 80) * scale
    shs = cv2.resize(sh, (max(1, int(hw)), max(1, int(hh))))
    _mul(img, 1 - shs, int(cx - hw / 2), int(cy - hh / 2 + 10 * scale))
    img = paste(img, rgba, cx, cy, scale=scale, alpha=alpha)
    return paste(img, lay, cx, cy, scale=scale, alpha=alpha)


def word(img, s, size, x, y, t, t0, align="left", color=S.INK, weight="black", d=0.14):
    """Mot qui claque sur un coup : monte de 40 px et se pose avec un léger dépassement."""
    if t < t0:
        return img
    k = out_back(progress(t, t0, t0 + d), 1.6)
    lay = text_layer(s, size, weight, -0.045, tuple(color))
    w = lay.shape[1]
    cx = x + w / 2 if align == "left" else x - w / 2 if align == "right" else x
    return paste(img, lay, cx, y + 40 * (1 - k), scale=0.92 + 0.08 * k, alpha=min(1, progress(t, t0, t0 + 0.05)))


# ---------------------------------------------------------------- sections
def s_intro(t, a, b):
    img = S.background()
    ev = pick(0.3, b - 0.15, 3, 0.6, 0.8)
    words = ("Vidéo.", "Audio.", "Hors ligne.")
    i = nth(t, ev)
    if i > 0:
        img = word(img, words[i - 1], 170, 960, 760, t, ev[i - 1], "center")
    grow = in_out_cubic(progress(t, 0.0, b))
    size = 180 + 60 * grow + 30 * pulse(t)
    rise = out_expo(progress(t, 0.0, 0.5))
    img = put_icon(img, 960, 400 - 30 * (1 - rise), size, alpha=rise)
    # aspiration vers le drop
    z = progress(t, b - 0.2, b)
    if z > 0:
        img = cv2.resize(img, None, fx=1 + 0.6 * z ** 2, fy=1 + 0.6 * z ** 2)
        hh, ww = img.shape[:2]
        y0, x0 = (hh - H) // 2, (ww - W) // 2
        img = img[y0:y0 + H, x0:x0 + W] * (1 - z ** 2) + z ** 2
    return img


def s_hero(t, a, b):
    img = S.background()
    ev = pick(a + 0.2, b - 0.2, 4, 0.35)
    e = spring(progress(t, a, a + 0.5), 1.6, 0.5)
    i = nth(t, ev)
    yaw = -22 + 6 * i + 3 * pulse(t)
    img = word(img, "Télécharge", 150, 140, 420, t, a + 0.02)
    if i >= 1:
        img = word(img, "en un", 150, 140, 580, t, ev[0])
    if i >= 2:
        img = word(img, "tap.", 150, 140 + text_layer("en un ", 150, "black", -0.045, S.INK).shape[1], 580, t, ev[1], color=S.RED)
    if i >= 3:
        img = word(img, "Vidéo ou audio, depuis n'importe quelle app.", 34, 145, 700, t, ev[2], weight="dmedium",
                   color=S.GREY)
    phone(img, "capture", 440, 1300 * (1 - e) + 10, 2150 - 60 * pulse(t), yaw, 4, 2)
    flash = math.exp(-(t - a) / 0.08)
    return img * (1 - flash) + flash


def s_quality(t, a, b):
    img = S.background()
    ev = pick(a + 0.15, b - 0.15, 6, 0.3)
    k = k_in(t, a, 0.25)
    img = word(img, "Choisis ta qualité.", 92, 960, 120, t, a + 0.01, "center")
    phone(img, "capture", 0, 120 + 400 * (1 - k), 2350 - 50 * pulse(t), -8 + 16 * in_out_cubic(progress(t, a, b)), 0)
    chips = (("Vidéo", 520, 360), ("Audio seul", 1400, 330), ("Meilleure qualité", 470, 560),
             ("1080p", 1420, 540), ("720p", 560, 760), ("480p", 1380, 760))
    for j, (lab, x, y) in enumerate(chips):
        if t >= ev[j]:
            sc = out_back(progress(t, ev[j], ev[j] + 0.2), 2.2)
            img = chip(img, lab, x, y + 6 * math.sin((t - a) * 3 + j), sc * (1 + 0.04 * pulse(t)), dark=j == 2)
    return img


def s_browser(t, a, b):
    img = S.background()
    ev = pick(a + 0.15, b - 0.2, 4, 0.4)
    i = nth(t, ev)
    zs = (2500, 1900, 1450, 1150, 950)
    if i == 0:
        z, fx = zs[0], 0.0
    else:
        zt = out_expo(progress(t, ev[i - 1], ev[i - 1] + 0.18))
        z = zs[i - 1] + (zs[i] - zs[i - 1]) * zt
        fx = ((i - 1) + zt) / 4
    # on zoome vers le bouton Télécharger : décalage de la caméra
    x = -380 - 120 * fx
    y = 0 - 380 * fx
    phone(img, "browser", x - 240 * (1 - k_in(t, a, 0.25)), y, z, 8 - 8 * fx, 0, 0)
    tx = 1060
    img = word(img, "Navigue.", 130, tx, 420, t, a + 0.02, "left") if i < 2 else img
    img = word(img, "Capture.", 130, tx, 570, t, ev[0], "left") if 1 <= i < 2 else img
    if i >= 2:
        img = word(img, "Un tap,", 120, tx, 470, t, ev[1], "left")
        img = word(img, "c'est parti.", 120, tx, 620, t, ev[2] if i >= 3 else 1e9, "left", color=S.RED)
    return img


def s_progress(t, a, b):
    img = S.background()
    ev = pick(a + 0.1, b - 0.1, 6, 0.3)
    i = nth(t, ev)
    vals = (0, 18, 37, 55, 74, 91, 100)
    v = vals[i]
    phone(img, "done", -560, 30, 2250, 22 - 4 * pulse(t), 0, 0)
    img = word(img, "Téléchargement", 40, 1000, 300, t, a, weight="dmedium", color=S.GREY)
    txt = f"{v}%"
    lay = text_layer(txt, 260, "black", -0.05, S.RED if i == len(ev) else S.INK)
    sc = 1 + 0.06 * pulse(t, 0.07)
    img = paste(img, lay, 1000 + lay.shape[1] / 2, 470, scale=sc)
    # barre de progression
    x0, x1, yb = 1000, 1780, 640
    cv2.rectangle(img, (x0, yb - 5), (x1, yb + 5), (0.86, 0.86, 0.88), -1, cv2.LINE_AA)
    fill = x0 + (x1 - x0) * v / 100
    cv2.rectangle(img, (x0, yb - 5), (int(fill), yb + 5), np.array(S.INK, float) / 255, -1, cv2.LINE_AA)
    if i == len(ev):
        img = word(img, "Terminé.", 110, 1000, 780, t, ev[-1], color=S.INK)
    else:
        img = word(img, "yt-dlp · aria2c · ffmpeg", 34, 1000, 730, t, a + 0.1, weight="dmedium", color=S.GREY)
    return img


def s_send(t, a, b):
    img = S.background()
    ev = pick(a + 0.1, b - 0.3, 7, 0.28)
    k = k_in(t, a, 0.3)
    img = word(img, "Envoi local.", 110, 948, 130, t, a + 0.01, "right")
    img = word(img, "Sans câble.", 110, 972, 130, t, ev[1] if len(ev) > 1 else a, "left", color=S.RED)
    rl = phone(img, "send", -470 - 300 * (1 - k), 160, 2350, 18, 0, 0)
    bump = max([math.exp(-(t - (e + 0.26)) / 0.08) for e in ev if t >= e + 0.26] + [0])
    rr = phone(img, "library", 470 + 300 * (1 - k), 160 - 30 * bump, 2350, -18, 0, 0)
    p0 = rl["map"](585, 900)
    p2 = rr["map"](585, 900)
    p1 = ((p0[0] + p2[0]) / 2, 300)
    path = bezier(p0, p1, p2, np.linspace(0, 1, 60))
    lay = np.zeros((H, W), np.uint8)
    for (x, y) in path[::3]:
        cv2.circle(lay, (int(x * 16), int(y * 16)), 3 * 16, 255, -1, cv2.LINE_AA, 4)
    al = lay.astype(np.float32)[..., None] / 255 * 0.25 * k
    img = img * (1 - al) + np.array((0.5, 0.5, 0.52)) * al
    for e in ev:
        u = progress(t, e, e + 0.26)
        if 0 < u < 1:
            for d, r in ((0.0, 16), (0.04, 11), (0.08, 7)):
                x, y = bezier(p0, p1, p2, max(0, in_out_cubic(u) - d))
                cv2.circle(img, (int(x * 16), int(y * 16)), r * 16, np.array(S.RED, float) / 255, -1, cv2.LINE_AA, 4)
    return img


MONTAGE = (("archive", "Archive TikTok", "Importe tes favoris."), ("stats", "Statistiques", "Tout ce que tu as gardé."),
           ("settings", "Réglages", "yt-dlp toujours à jour."), ("library", "Bibliothèque", "Tout, au même endroit."),
           ("browser", "Navigateur", "Capture la vidéo de la page."), ("send", "Envoi", "Du PC au téléphone."),
           ("capture", "Qualité", "Jusqu'au maximum."), ("done", "File d'attente", "Suivie en direct."))


def s_montage(t, a, b):
    ev = [a] + pick(a + 0.3, b - 0.1, 7, 0.3)
    i = max(0, nth(t, ev) - 1)
    key, name, sub = MONTAGE[i % len(MONTAGE)]
    img = S.background()
    side = (-1, 1, 0, 1, -1, 0, 1, -1)[i % 8]
    lt = t - ev[i]
    k = out_expo(min(1, lt / 0.18))
    x = side * 420 if side else 0
    z = (2300 if side == 0 else 1500) + 300 * (1 - k)
    yaw = -side * 18 + side * 6 * lt
    phone(img, key, x, 230 if side == 0 else 40, z, yaw, 2, -side * 2)
    if side == 0:
        img = word(img, name, 96, 960, 95, t, ev[i], "center")
    else:
        tx = 1060 if side < 0 else 860
        img = word(img, name, 110, tx, 470, t, ev[i], "left" if side < 0 else "right")
        img = word(img, sub, 40, tx + (6 if side < 0 else -6), 580, t, ev[i] + 0.03, "left" if side < 0 else "right",
                   weight="dmedium", color=S.GREY)
    if lt < 0.06:
        img = dir_blur(img, 60 * side if side else 0, 0 if side else 50)
    return img


WORDS = ("Open source.", "Licence MIT.", "Zéro pub.", "Android.", "Windows.", "Chrome.", "Firefox.", "Gratuit.")


def s_words(t, a, b):
    ev = [a] + pick(a + 0.25, b - 0.1, 7, 0.3)
    i = max(0, nth(t, ev) - 1)
    dark = i % 2 == 1
    img = np.full((H, W, 3), 0.07 if dark else 0.96, np.float32) if dark else S.background()
    ink = (245, 245, 247) if dark else S.INK
    s = WORDS[i]
    lt = t - ev[i]
    k = out_expo(min(1, lt / 0.15))
    lay = text_layer(s, 240, "black", -0.05, ink)
    if s.endswith("."):
        lay = text_layer(s[:-1], 240, "black", -0.05, ink)
    sc = 1.15 - 0.15 * k + 0.03 * pulse(t)
    img = paste(img, lay, 960, 540, scale=sc)
    dot_x = 960 + lay.shape[1] * sc / 2 + 30 * sc
    cv2.circle(img, (int(dot_x * 16), int((540 + 62 * sc) * 16)), int(26 * sc * 16), np.array(S.RED, float) / 255, -1,
               cv2.LINE_AA, 4)
    return img


WALL = ("browser", "capture", "done", "library", "stats", "send", "archive", "settings", "share")


def s_wall(t, a, b):
    img = S.background()
    order = (4, 1, 7, 3, 5, 0, 2, 6, 8)
    ev = [a] + pick(a + 0.15, b - 0.4, 8, 0.25)
    n = nth(t, ev)
    pull = in_out_cubic(progress(t, a, b))
    cam = Cam(f=1500, pos=(0, 0, -400 * pull), yaw=6 - 12 * pull, pitch=-3 + 3 * pull)
    items = []
    for rank, idx in enumerate(order):
        if rank >= n:
            continue
        r, c = divmod(idx, 3)
        P3 = np.array([(c - 1) * 700.0, (r - 1) * 1250.0, 3700.0])
        fl = out_back(progress(t, ev[rank], ev[rank] + 0.2), 1.4)
        items.append((P3, WALL[idx], 90 * (1 - fl), fl))
    for P3, key, yaw, fl in sorted(items, key=lambda x: -np.linalg.norm(x[0] - cam.pos)):
        draw_phone(img, key, tuple(P3), yaw, 0, cam=cam, shadow=0.22, shadow_off=(0, 40), gloss=0.08,
                   alpha=min(1, fl * 2))
    img = word(img, APP_NAME, 72, 960, 990, t, ev[-1], "center") if n >= 9 else img
    z = progress(t, b - 0.12, b)
    if z > 0:
        img = img * (1 - z) + z
    return img


def s_end(t, a, b):
    img = S.background()
    e = spring(progress(t, a, a + 0.6), 1.5, 0.5)
    img = put_icon(img, 960, 380, 220 * e + 1, alpha=min(1, e * 2))
    img = word(img, APP_NAME, 110, 960, 640, t, a + 0.05, "center")
    img = word(img, "Android · Windows · Open source", 36, 960, 740, t, a + 0.15, "center", weight="dmedium",
               color=S.GREY)
    img = word(img, "github.com/itsnazzym/Downloader", 30, 960, 820, t, a + 0.25, "center", weight="mono",
               color=S.INK)
    cr = "Musique : « Future Bass Lite », NERDtasticBEATS (CC BY 4.0)"
    img = word(img, cr, 18, 960, 1035, t, a + 0.3, "center", weight="regular", color=S.GREY)
    return img


FUNCS = {"intro": s_intro, "hero": s_hero, "quality": s_quality, "browser": s_browser, "progress": s_progress,
         "send": s_send, "montage": s_montage, "words": s_words, "wall": s_wall, "end": s_end}


def render(f: int) -> np.ndarray:
    t = f / B.FPS
    for name, a, b in SECTIONS:
        if a <= t < b or name == "end" and t >= a:
            img = FUNCS[name](t, a, b)
            # sortie de section : léger zoom avant + flou de bougé pendant les 3 dernières images
            out = progress(t, b - 0.1, b)
            if 0 < out and name not in ("intro", "wall", "end", "words"):
                s = 1 + 0.12 * out ** 2
                M = np.float32([[s, 0, 960 * (1 - s)], [0, s, 540 * (1 - s)]])
                img = cv2.warpAffine(img, M, (W, H), borderMode=cv2.BORDER_REPLICATE)
                img = dir_blur(img, 0, 50 * out)
            return np.clip(img, 0, 1)
    return S.background()
