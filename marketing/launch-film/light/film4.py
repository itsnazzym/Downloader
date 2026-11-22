"""Film v4 « clair 3D » : chorégraphie en 3D à 60 i/s, calée sur les coups de la musique.

Tout est fonction du temps continu t (secondes) : caméra look-at sur des trajectoires lisses (Catmull-Rom,
ressorts analytiques), éléments posés dans une vraie scène 3D (light.stage) avec profondeur de champ.
Mêmes sections et mêmes coups forts que la v3 (light.film.SECTIONS, light.film.pick).

- Le rythme vient d'actions réelles de l'appli ou de la chorégraphie, sur peu de coups : dans les sections
  d'interface, 3-4 coups forts par section (BEATS, choisis parmi pick) portent chacun un vrai événement (tap,
  sélection, saut de progression, fichier reçu…) ; attaque en 2 images, arrivée amortie sans rebond.
- La caméra ne réagit jamais aux coups (ni zoom, ni secousse, ni poussée de basse) : trajets lisses seulement.
- v7 : l'énergie vient du mouvement continu. Chaque changement de section est une transition de caméra dessinée
  (TRANS : whip-pan, whip-tilt, whip-orbit, traversée, balayage d'une carte au premier plan) dont le pic de
  vitesse tombe sur le premier temps de la phrase ; dans les sections, la caméra arrive vite, ralentit sur la pose
  lisible et repart en accélérant (travel) ; fragments d'interface flous à plusieurs profondeurs (parallaxe) ;
  titres en typographie cinétique (mots / lettres qui montent dans un masque et sortent vers la transition) ;
  flou de bougé proportionnel à la vitesse écran (render : sous-images sur une ouverture à 180°).
- Coupes franches (HARD_CUTS) : changements de fond de la section « words », tous sur des coups.
"""
import math
from functools import lru_cache

import cv2
import numpy as np

from film import assets
from reel import core
from reel.core import rot

from . import beats as B
from . import film
from . import sound4
from . import style as S
from . import ui
from .motion import catmull, look_at_cam, spring
from .stage import NEAR, PHONE_THICK, Extrude, Plane, PhoneItem, render as stage_render, text_groups, text_plane

FPS = 60
W, H = 1920, 1080
F0 = 1500.0
SEC = {n: (a, b) for n, a, b in film.SECTIONS}
ORDER = [n for n, _, _ in film.SECTIONS]
DARK = np.array((18, 18, 20), np.float32) / 255      # #121214
LIGHT_INK = (245, 245, 247)


# ================================================================ coups
def _pick6(name):
    a, b = SEC[name]
    return film.pick(a, b, 6, 0.3)


def _start_hit(name):
    """Le début de section s'il est lui-même un coup retenu par pick (drop, débuts de phrase marqués)."""
    a, b = SEC[name]
    return [x for x in film.pick(a, b, 8, 0.3) if abs(x - a) < 1e-6]


LAST_HIT = 2.2        # dernier coup d'une animation (s après le début de la section) : elle a le temps de se poser et
                      # d'être vue avant que la caméra ne parte (la sortie se voit à partir de ≈ 2,9 s)


def _wall_events():
    """Les huit coups forts des 2,2 premières secondes : les neuf écrans sont posés avant le whip de sortie."""
    a, b = SEC["wall"]
    return film.pick(a + 0.3, a + LAST_HIT, 8, 0.15)


def _grid_hits(name, rel):
    """Coups réels de la section les plus proches des instants (relatifs au début) donnés."""
    a, _ = SEC[name]
    out = []
    for r in rel:
        i = int(np.argmin(np.abs(film.T_ALL - (a + r))))
        assert abs(film.T_ALL[i] - (a + r)) < 0.05, (name, r)
        out.append(float(film.T_ALL[i]))
    return out


EV = {
    "intro": film.pick(0.0, SEC["intro"][1], 9, 0.3),
    **{n: _pick6(n) for n in ("hero", "quality", "browser", "progress", "send", "montage")},
    # un mot par coup sur la grille des temps (0,405 s) : le dernier mot est posé avant que la caméra ne parte
    "words": _grid_hits("words", (0.51, 0.91, 1.32, 1.72, 2.13, 2.53, 2.94)),
    "wall": _wall_events(),
}
# coups qui portent un vrai événement de l'appli / de la chorégraphie (3-4 par section d'interface, les plus forts,
# répartis) ; les autres coups forts de ces sections passent sans aucune pulsation visible
# v10 : plus aucun événement après ≈ 2,3 s de la section (indices 0-4 de EV) : chaque animation se pose et se voit
# avant que la transition de sortie ne commence
_B = {"hero": (0, 2, 4), "quality": (0, 2, 4), "browser": (0, 2, 3, 4), "progress": (0, 1, 2, 3),
      "send": (0, 1, 2, 3)}
BEATS = {n: [EV[n][i] for i in ix] for n, ix in _B.items()}
ACCENTS = sorted(set(x for v in EV.values() for x in v)
                 | set(x for n in ORDER[1:9] for x in _pick6(n))      # tous les coups forts de la musique
                 | set(x for n in ORDER[1:9] for x in _start_hit(n)))
HARD_CUTS = list(EV["words"])          # fond clair / sombre alterné sur chaque mot
KICKS = sound4.kicks()
PUNCH = 0.0                            # plus de coup de zoom sur les accents (jugé « faux dynamisme ») : le rythme vient des éléments
PUNCH_DOWN = 70.0


def snap(t, t0, w=40.0):
    return spring(t, t0, w)


def bump(t, times, amp, up=55.0, down=7.0, hold=0.05):
    """Impulsion sans oscillation : monte en ressort rapide sur le coup, redescend en ressort lent."""
    v = 0.0
    for h in times:
        if t > h:
            v += amp * (spring(t, h, up) - spring(t, h + hold, down))
    return v


def kick_env(t: float) -> float:
    """Somme des enveloppes de basse (≈ 1 par kick : montée 40 ms, retour 250 ms)."""
    m = (KICKS <= t) & (KICKS > t - 1.0)
    return float(sum(spring(t, k, 110.0) - spring(t, k + 0.04, 16.0) for k in KICKS[m]))


def smooth(u):
    u = min(1.0, max(0.0, u))
    return u * u * u * (u * (6 * u - 15) + 10)


def eo(u):
    """Départ en vitesse, arrivée douce (C¹)."""
    u = min(1.0, max(0.0, u))
    return 1 - (1 - u) ** 2.2


def glide(u, e=0.25):
    """Trajet à vitesse presque constante : accélération sur la fraction e, palier, freinage symétrique (C¹)."""
    u = min(1.0, max(0.0, u))
    if u < e:
        return u * u / (2 * e * (1 - e))
    if u > 1 - e:
        return 1 - (1 - u) ** 2 / (2 * e * (1 - e))
    return (u - e / 2) / (1 - e)


def lin(u):
    return min(1.0, max(0.0, u))


# ================================================================ textures
@lru_cache(maxsize=256)
def TXT(s, size, weight="black", color=S.INK, tracking=-0.045):
    return text_plane(s, size, weight, color, tracking)


@lru_cache(maxsize=8)
def ICON(size=1024):
    return ui.app_icon(size)


def CROP(name):
    """Découpe nommée de ui.CROPS (carte d'une vraie capture)."""
    key, box = ui.CROPS[name]
    return ui.crop(key, box)


def _ro(a):
    a.setflags(write=False)
    return a


@lru_cache(maxsize=4)
def ring_tex(w, h, r, color=S.RED, stroke=10, glow=22):
    """Anneau arrondi lumineux (sélection de la cible de partage)."""
    m = glow * 3
    W_, H_ = w + 2 * m, h + 2 * m
    ss = 4
    big = np.zeros((H_ * ss, W_ * ss), np.uint8)
    cv2.rectangle(big, ((m + r) * ss, m * ss), ((m + w - r) * ss, (m + h) * ss), 255, -1)
    cv2.rectangle(big, (m * ss, (m + r) * ss), ((m + w) * ss, (m + h - r) * ss), 255, -1)
    for cx, cy in ((m + r, m + r), (m + w - r, m + r), (m + r, m + h - r), (m + w - r, m + h - r)):
        cv2.circle(big, (cx * ss, cy * ss), r * ss, 255, -1)
    fill = cv2.resize(big, (W_, H_), interpolation=cv2.INTER_AREA).astype(np.float32) / 255
    inner = cv2.erode(fill, np.ones((2 * stroke + 1, 2 * stroke + 1), np.uint8))
    line = np.clip(fill - inner, 0, 1)
    halo = cv2.GaussianBlur(line, (0, 0), glow) * 1.6
    a = np.clip(np.maximum(line, halo * 0.55), 0, 1)
    out = np.zeros((H_, W_, 4), np.uint8)
    out[..., :3] = color
    out[..., 3] = (a * 255 + 0.5).astype(np.uint8)
    return _ro(out)


@lru_cache(maxsize=4)
def ripple_tex(size=512, stroke=14, color=S.RED):
    """Onde de tap : anneau net + disque translucide."""
    ss = 4
    big = np.zeros((size * ss, size * ss), np.uint8)
    c = size * ss // 2
    cv2.circle(big, (c, c), c - 2 * ss, 255, -1)
    disk = cv2.resize(big, (size, size), interpolation=cv2.INTER_AREA).astype(np.float32) / 255
    inner = cv2.erode(disk, np.ones((2 * stroke + 1, 2 * stroke + 1), np.uint8))
    a = np.clip((disk - inner) + inner * 0.25, 0, 1)
    out = np.zeros((size, size, 4), np.uint8)
    out[..., :3] = color
    out[..., 3] = (a * 255 + 0.5).astype(np.uint8)
    return _ro(out)


@lru_cache(maxsize=1)
def radar_ghost():
    """Radar de la page Envoi en négatif pour le fond clair : seuls les points (gris) restent."""
    rgba = CROP("radar")
    lum = rgba[..., :3].astype(np.float32).mean(2) / 255
    a = np.clip((lum - 0.06) * 1.5, 0, 1) * (rgba[..., 3] / 255)
    h, w = a.shape
    yy, xx = np.mgrid[0:h, 0:w]
    a *= np.clip((np.hypot(xx - w / 2, yy - h / 2) - 92) / 6, 0, 1)   # sans le bouton central plein
    out = np.zeros_like(rgba)
    out[..., :3] = (96, 96, 102)
    out[..., 3] = (a * 255 + 0.5).astype(np.uint8)
    return _ro(out)


@lru_cache(maxsize=16)
def slot_tex(w, h, r, color=(0, 0, 0)):
    """Rectangle arrondi plein (par défaut fond noir de l'appli : emplacement laissé par une carte détachée ;
    en blanc / noir translucide : état pressé d'un bouton)."""
    ss = 4
    big = np.zeros((h * ss, w * ss), np.uint8)
    cv2.rectangle(big, (r * ss, 0), ((w - r) * ss, h * ss), 255, -1)
    cv2.rectangle(big, (0, r * ss), (w * ss, (h - r) * ss), 255, -1)
    for cx, cy in ((r, r), (w - r, r), (r, h - r), (w - r, h - r)):
        cv2.circle(big, (cx * ss, cy * ss), r * ss, 255, -1)
    a = cv2.resize(big, (w, h), interpolation=cv2.INTER_AREA)
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = color
    out[..., 3] = a
    return _ro(out)


# ================================================================ géométrie du téléphone
PT = core.phone_tex("capture")
PH_H, PH_W = PT.shape[:2]                        # 1100 × 557 (unités monde)
BEZ = max(2, round(0.016 * PH_H))
KS = (PH_H - 2 * BEZ) / 2388                     # unités monde par pixel de capture
FACE = -PHONE_THICK / 2                          # face avant (corps 3D de stage, épaisseur ≈ 8 mm)


def on_phone(center, yaw, pitch, roll, u, v, dz=0.0):
    """Point (u, v) de la capture (1170×2388) sur la face d'un téléphone, décollé de dz vers l'avant."""
    loc = np.array([BEZ + u * KS - PH_W / 2, BEZ + v * KS - PH_H / 2, FACE - dz])
    return rot(yaw, pitch, roll) @ loc + np.asarray(center, np.float64)


def crop_plane(key, center, yaw, pitch, roll, dz=0.0, alpha=1.0, scale=1.0, shadow=0.0, dv=0.0):
    _, (x0, y0, x1, y1) = ui.CROPS[key]
    c = on_phone(center, yaw, pitch, roll, (x0 + x1) / 2, (y0 + y1) / 2 + dv, dz)
    return Plane(CROP(key), tuple(c), (x1 - x0) * KS * scale, yaw, pitch, roll, alpha, shadow)


def box_plane(tex, box, center, yaw, pitch, roll, dz=0.0, alpha=1.0, du=0.0, dv=0.0, scale=1.0, shadow=0.0):
    """Texture posée sur la case box (x0, y0, x1, y1, pixels de capture) de l'écran d'un téléphone."""
    x0, y0, x1, y1 = box
    c = on_phone(center, yaw, pitch, roll, (x0 + x1) / 2 + du, (y0 + y1) / 2 + dv, dz)
    return Plane(tex, tuple(c), (x1 - x0) * KS * scale, yaw, pitch, roll, alpha, shadow)


def BOX(key, box, radius=0):
    """Découpe d'une vraie capture (même source que la texture du téléphone)."""
    return ui.crop(key, box, radius)


def hit(t, h, w=60.0):
    """Attaque franche sur le coup (≈ 60 % en 2 images, 80 % en 3), arrivée sans rebond ; 0 avant le coup."""
    return snap(t, h, w) if t >= h else 0.0


# ================================================================ scène
class Scene:
    def __init__(self, cam_pos, target, fov=1.0, roll=0.0):
        self.cam_pos, self.target, self.fov, self.roll = cam_pos, target, fov, roll
        self.groups = [[]]      # groupes dessinés dans l'ordre (chaque groupe trié loin → proche)
        self.focus = None       # point monde mis au point
        self.dof = 0.0
        self.bg = None          # None = studio clair, sinon couleur (3,)
        self.white = 0.0        # fondu vers le blanc
        self.post = []          # effets 2D après projection : f(img, cam)
        self.shift = (0.0, 0.0)  # décentrement optique (px)
        self.floor = None        # hauteur monde d'un sol (ombres de contact)
        self.reflect = 0.0       # sol brillant : force du reflet des téléphones (avec floor)
        self.punch = 1.0         # gain du coup de zoom sur les accents
        self.cam_items = []      # éléments posés en coordonnées caméra (x, y, profondeur), après la transition

    def add(self, *items, group=-1, label=None):
        for i in items:
            if i is not None and i.alpha > 0.003:
                if label is not None:
                    i.label = label
                self.groups[group].append(i)

    def new_group(self):
        self.groups.append([])

    def camera(self, t):
        push = 1.0                 # plus de poussée de caméra sur chaque kick
        push += self.punch * PUNCH * bump(t, ACCENTS, 1.0, up=80.0, down=PUNCH_DOWN, hold=0.05)   # petit coup de zoom sur chaque coup fort
        cam = look_at_cam(self.cam_pos, self.target, F0 * self.fov * push, self.roll)
        cam.shift = self.shift
        return cam

    def base_cam(self):
        """Caméra sans poussée de basse (pour attacher un élément au cadre)."""
        return look_at_cam(self.cam_pos, self.target, F0 * self.fov, self.roll)

    def screen_point(self, sx, sy, depth, t=None):
        """Point monde qui se projette en (sx, sy) à la profondeur caméra depth : hors basse et hors coup de
        zoom, ou, avec t, avec la caméra complète de l'instant t (un titre attaché au cadre ne bouge pas avec le
        coup de zoom ni la basse : il reste dans la marge de sécurité et parfaitement stable)."""
        cam = self.base_cam() if t is None else self.camera(t)
        x = (sx - W / 2 - self.shift[0]) * depth / cam.f
        y = (sy - H / 2 - self.shift[1]) * depth / cam.f
        return cam.pos + cam.R @ np.array((x, y, depth))

    def cam_angles(self):
        from .motion import look_at_angles
        return look_at_angles(self.cam_pos, self.target)


def face(P, cam_pos) -> tuple[float, float]:
    """(lacet, tangage) en degrés d'un téléphone en P dont l'écran regarde exactement la caméra en cam_pos."""
    d = np.asarray(cam_pos, np.float64) - np.asarray(P, np.float64)
    d /= np.linalg.norm(d)
    return math.degrees(math.atan2(-d[0], -d[2])), math.degrees(math.asin(np.clip(d[1], -1, 1)))


def mix(x, y, k):
    return x + (y - x) * k


def orbit(center, yaw_deg, pitch_deg, dist):
    """Position d'une caméra à dist du centre, sur la sphère (lacet, tangage en degrés)."""
    a, p = math.radians(yaw_deg), math.radians(pitch_deg)
    off = np.array([-math.sin(a) * math.cos(p), -math.sin(p), -math.cos(a) * math.cos(p)]) * dist
    return np.asarray(center, np.float64) + off


def word_plane(s, center, height_px, depth_ref, weight="black", color=S.INK, alpha=1.0, yaw=0.0, pitch=0.0,
               size=200, align="center", scale=1.0, tex=None):
    """Texte posé en 3D : à la profondeur caméra depth_ref, la ligne fait height_px de corps à l'écran (tex :
    texture de même cadre que TXT, p. ex. kin_tex)."""
    tex = TXT(s, size, weight, tuple(color)) if tex is None else tex
    k = height_px / size * depth_ref / F0 * scale          # unités monde par pixel de texture
    w = tex.shape[1] * k
    c = np.asarray(center, np.float64).copy()
    if align == "left":
        c[0] += w / 2
    elif align == "right":
        c[0] -= w / 2
    return Plane(tex, tuple(c), w, yaw, pitch, 0.0, alpha)


def text_width(s, height_px, depth_ref, weight="black", size=200):
    return TXT(s, size, weight, S.INK).shape[1] * height_px / size * depth_ref / F0


# ================================================================ typographie cinétique
def kin_count(s, size=200, weight="black", mode="word"):
    return len(text_groups(s, size, weight, -0.045, mode))


def kin_tex(s, offs, size=200, weight="black", color=S.INK, mode="word", smear=None):
    """Ligne s dont chaque mot (ou lettre) glisse verticalement dans un masque (le cadre de la ligne) : offs[i] en
    fraction de hauteur de texture (0 = posé, > 0 = sous le masque, < 0 = sorti par le haut). Au repos : TXT exact."""
    base = TXT(s, size, weight, tuple(color))
    if all(abs(o) < 1e-3 for o in offs):
        return base
    h, w = base.shape[:2]
    alpha = np.zeros((h, w), np.uint8)
    for i, ((x0, x1, a), o) in enumerate(zip(text_groups(s, size, weight, -0.045, mode), offs)):
        dy = float(o) * h
        if abs(dy) >= h - 0.5:
            continue
        src = a
        k = int(round(abs(smear[i]) * h)) if smear is not None else 0
        if k >= 2:          # flou de bougé du glissement dans le masque (longueur parcourue pendant l'ouverture)
            src = cv2.blur(np.pad(a, ((k, k), (0, 0))), (1, k))[k:-k]
        sh = cv2.warpAffine(src, np.float32([[1, 0, 0], [0, 1, dy]]), (x1 - x0, h), flags=cv2.INTER_LINEAR,
                            borderMode=cv2.BORDER_CONSTANT, borderValue=0)
        np.maximum(alpha[:, x0:x1], sh, out=alpha[:, x0:x1])
    out = np.empty((h, w, 4), np.uint8)
    out[..., :3] = tuple(color)
    out[..., 3] = alpha
    return out


def kin_offs(t, n, t_in, t_out=None, stagger=0.06, w=34.0, out_stagger=0.04, out_d=0.3, out_dir=-1.0):
    """Décalages de kin_tex : chaque groupe monte depuis sous le masque (ressort franc, décalé de stagger) à partir
    de t_in, puis, à partir de t_out, sort par le haut (courbe en S sur out_d, vers la transition)."""
    offs = []
    for i in range(n):
        k = spring(t, t_in + i * stagger, w)
        o = 0.0 if k > 0.998 else 1.0 - k
        if t_out is not None:
            u = (t - (t_out + i * out_stagger)) / out_d
            if u > 0:
                o += out_dir * smooth(u)
        offs.append(o)
    return offs


def kin_alpha(offs):
    """1 tant qu'un groupe est au moins en partie dans le masque, 0 sinon (la ligne n'existe plus)."""
    return 1.0 if any(-0.995 < o < 0.995 for o in offs) else 0.0


# ================================================================ transitions de section
# Chaque changement de section est un mouvement de caméra continu : la section sortante accélère (rampe
# exponentielle, sans à-coup), la section entrante part à la même vitesse et freine jusqu'à l'arrêt ; le pic de
# vitesse (la coupe, cachée par le flou de bougé) tombe sur le premier temps de la phrase. Composantes : lacet /
# tangage de la visée (whip-pan / whip-tilt, degrés), orbite autour de la visée (degrés), travelling avant
# (unités monde), roulis (degrés, bosse symétrique autour de la coupe).
def ramp_out(t, c, d, tau):
    """0 → 1 sur [c − d, c] : position et vitesse nulles au départ, croissance exponentielle (constante tau)."""
    s = t - (c - d)
    if s <= 0:
        return 0.0
    s = min(s, d)
    return (math.exp(s / tau) - 1 - s / tau) / (math.exp(d / tau) - 1 - d / tau)


def v_out(d, tau):
    """Vitesse de ramp_out à la coupe (1/s)."""
    return (math.exp(d / tau) - 1) / tau / (math.exp(d / tau) - 1 - d / tau)


def ramp_in(t, c, d, p):
    """1 → 0 sur [c, c + d] : vitesse maximale p/d à la coupe, arrivée sans vitesse (freinage en (1 − s/d)^p)."""
    s = t - c
    if s >= d:
        return 0.0
    return (1 - max(0.0, s) / d) ** p


class Tr:
    def __init__(self, frm, to, kind, out, inn=None, cut=None, d_out=0.50, tau=0.115, d_in=0.50, p=5.0):
        self.frm, self.to, self.kind = frm, to, kind
        self.b = SEC[to][0]                       # premier temps de la phrase entrante
        self.cut = self.b if cut is None else cut
        self.d_out, self.tau, self.d_in, self.p = d_out, tau, d_in, p
        self.out = dict(out)
        self.matched = inn is None                 # entrée dérivée de la sortie (sinon : arrivée choisie à part)
        if inn is None:                            # même vitesse de part et d'autre de la coupe
            k = v_out(d_out, tau) / (p / d_in)
            inn = {c: (v if c == "roll" else -k * v) for c, v in out.items()}
        self.inn = dict(inn)

    def offsets(self, t, side):
        if side == "out":
            g = ramp_out(t, self.cut, self.d_out, self.tau)
            return {c: v * g for c, v in self.out.items()}
        g = ramp_in(t, self.cut, self.d_in, self.p)
        return {c: v * g for c, v in self.inn.items()}

    def window(self):
        return self.cut - self.d_out, self.cut + self.d_in


TRANS = [
    Tr("intro", "hero", "push-through", {}, {"dolly": -1700.0, "roll": 0.0}, d_in=0.55, p=4.0),
    Tr("hero", "quality", "whip-pan", {"yaw": 44.0, "roll": 4.0}),
    Tr("quality", "browser", "whip-tilt", {"pitch": -36.0, "roll": -3.0}),
    Tr("browser", "progress", "whip-orbit", {"orbit": 30.0, "yaw": 38.0, "roll": 4.0}),
    Tr("progress", "send", "card-wipe", {}, {"yaw": -10.0}, d_out=0.42, d_in=0.45),
    # traversée : arrivée plus douce, en léger panoramique (l'écran central du carrousel reste grand dès la coupe)
    Tr("send", "montage", "push-through", {"dolly": 2300.0}, {"dolly": -420.0, "yaw": 12.0}),
    Tr("montage", "words", "whip-pan", {"yaw": 44.0, "roll": 4.0}),
    Tr("words", "wall", "whip-tilt", {"pitch": 32.0, "roll": 3.0}),
    Tr("wall", "end", "whip-pan", {"yaw": 40.0, "roll": 3.0}, cut=30.0 - 0.36, d_in=0.36),
]
TR_TO = {tr.to: tr for tr in TRANS}
TR_FROM = {tr.frm: tr for tr in TRANS}


def _apply_offsets(sc, off):
    pos = np.asarray(sc.cam_pos, np.float64).copy()
    tgt = np.asarray(sc.target, np.float64).copy()
    if off.get("orbit"):
        a = math.radians(off["orbit"])
        d = pos - tgt
        c, s = math.cos(a), math.sin(a)
        pos = tgt + np.array((c * d[0] - s * d[2], d[1], s * d[0] + c * d[2]))
    if off.get("dolly"):
        f = tgt - pos
        f /= np.linalg.norm(f)
        pos = pos + f * off["dolly"]
        tgt = tgt + f * off["dolly"]
    if off.get("yaw") or off.get("pitch"):
        from .motion import look_at_angles
        ya, pi = look_at_angles(pos, tgt)
        dist = float(np.linalg.norm(tgt - pos))
        ya, pi = math.radians(ya + off.get("yaw", 0.0)), math.radians(pi + off.get("pitch", 0.0))
        tgt = pos + dist * np.array((math.sin(ya) * math.cos(pi), -math.sin(pi), math.cos(ya) * math.cos(pi)))
    sc.cam_pos, sc.target = pos, tgt
    sc.roll = sc.roll + off.get("roll", 0.0)


def transition_at(t):
    """(transition, côté « out » / « in ») active à t, ou (None, None)."""
    name, _, _ = render_section(t)
    tr = TR_FROM.get(name)
    if tr is not None and tr.out and tr.cut - tr.d_out < t < tr.cut:
        return tr, "out"
    tr = TR_TO.get(name)
    if tr is not None and tr.cut <= t < tr.cut + tr.d_in:
        return tr, "in"
    return None, None


def render_section(t):
    """Section dont la scène est rendue à t : la section du temps t, sauf entre une coupe avancée (transition qui
    se pose sur le premier temps de la phrase suivante) et ce premier temps, où c'est déjà la scène suivante."""
    name, a, b = section(t)
    tr = TR_FROM.get(name)
    if tr is not None and tr.cut < tr.b and t >= tr.cut:
        return tr.to, tr.b, SEC[tr.to][1]
    return name, a, b


def cam_plane(sc, tex, c, size_w, alpha=1.0, shadow=0.0, yaw=0.0, pitch=0.0, roll=0.0, label=None, extrude=None):
    """Plan posé en coordonnées caméra (c = x, y, profondeur ; orientation relative à la caméra), converti en monde
    après la transition : il suit la caméra finale (cartes de balayage au premier plan). extrude : paramètres
    d'Extrude (depth, side, side_back, rim) pour un volume (lettres, cartes épaisses)."""
    sc.cam_items.append((tex, tuple(c), size_w, alpha, shadow, yaw, pitch, roll, label, extrude))


def _place_cam_items(sc):
    if not sc.cam_items:
        return
    cam = sc.base_cam()
    yc, pc = sc.cam_angles()
    sc.new_group()
    for tex, c, w, al, sh, yw, pt, rl, label, ext in sorted(sc.cam_items, key=lambda x: -x[1][2]):
        P = cam.pos + cam.R @ np.asarray(c, np.float64)
        if ext is None:
            it = Plane(tex, tuple(P), w, yc + yw, pc + pt, sc.roll + rl, al, sh)
        else:
            it = Extrude(tex, tuple(P), w, yc + yw, pc + pt, sc.roll + rl, al, sh, 0.0, **ext)
        sc.add(it, label=label)
    sc.cam_items = []


# ================================================================ trajets dans les sections
_CAM_T = None          # temps « caméra » imposé (render(t, cam_t=…)) : la scène de t vue par la caméra de cam_t


def camt(t):
    """Temps qui pilote la caméra (et tout ce qui la suit : écrans tournés vers elle, titres attachés au cadre)."""
    return t if _CAM_T is None else _CAM_T


def travel(t, a, b, w_in=0.45, w_out=0.35, tau_in=0.45, tau_out=0.3):
    """Avancement 0 → 1 du trajet de caméra d'une section, vitesse continue : rapide à l'entrée (la vitesse de la
    transition décroît en exponentielle, tau_in), presque posé au milieu (la pose lisible), puis accélération en
    rampe exponentielle (tau_out) vers la transition suivante. w_in / w_out : part du trajet faite à l'entrée /
    à la sortie (le reste est une dérive lente et régulière)."""
    T = b - a
    x = min(max(t - a, 0.0), T)
    fin = (1 - math.exp(-x / tau_in)) / (1 - math.exp(-T / tau_in))
    fout = (math.exp((x - T) / tau_out) - math.exp(-T / tau_out)) / (1 - math.exp(-T / tau_out))
    return w_in * fin + (1 - w_in - w_out) * x / T + w_out * fout


def swing(t, t0, omega=30.0, zeta=0.62):
    """Ressort légèrement sous-amorti (≈ 8 % de dépassement) : un élément lourd lancé avec de l'élan."""
    dt = t - t0
    if dt <= 0:
        return 0.0
    wd = omega * math.sqrt(1 - zeta * zeta)
    return 1 - math.exp(-zeta * omega * dt) * (math.cos(wd * dt) + zeta * omega / wd * math.sin(wd * dt))


def anchor(cam_pos, target, sx, sy, depth, roll=0.0, shift=(0.0, 0.0)):
    """Point monde vu en (sx, sy) à la profondeur depth par la caméra (cam_pos → target) : sert à poser des
    fragments fixes dans le monde à l'endroit voulu du cadre au moment de la pose ; le trajet de caméra crée
    ensuite leur parallaxe."""
    cam = look_at_cam(cam_pos, target, F0, roll)
    x = (sx - W / 2 - shift[0]) * depth / F0
    y = (sy - H / 2 - shift[1]) * depth / F0
    return cam.pos + cam.R @ np.array((x, y, depth))


def _ftex(key):
    if key == "share":
        return ui.share_sheet()
    if key == "progress":
        return ui.progress_card(1.0)
    if key == "notif":
        return NTEX("done", glass=False)
    return CROP(key)


def frags(sc, ref, specs, alpha=1.0):
    """Fragments d'interface flous à plusieurs profondeurs (parallaxe) : specs = (clé, sx, sy, profondeur, largeur
    écran px, lacet, flou px, opacité) posés par rapport à la caméra de référence ref = (pos, visée[, roulis, décal.])."""
    for key, sx, sy, d, wpx, yaw, blur, al in specs:
        P = anchor(*ref[:2], sx, sy, d, *(ref[2:] or ()))
        sc.add(Plane(_ftex(key), tuple(P), wpx * d / F0, yaw, 0.0, 0.0, al * alpha, 0.0, blur))


def head(sc, t, s, sx, sy, depth, px, t_in, t_out=None, color=S.INK, weight="black", mode="word", stagger=0.06,
         out_stagger=0.04, align="left", label=None, w=24.0, out_d=0.3):
    """Ligne de titre attachée au cadre (posée avec la caméra de la section avant transition) qui entre mot par
    mot (ou lettre par lettre) dans un masque, et en sort par le haut à t_out (vers la transition)."""
    n = kin_count(s, weight=weight, mode=mode)
    kw = dict(stagger=stagger, w=w, out_stagger=out_stagger, out_d=out_d)
    offs = kin_offs(t, n, t_in, t_out, **kw)
    al = kin_alpha(offs)
    if al <= 0:
        return
    smear = [b_ - a_ for a_, b_ in zip(offs, kin_offs(t + SHUTTER, n, t_in, t_out, **kw))]
    tw = text_width(s, px, depth, weight)
    P = sc.screen_point(sx, sy, depth)
    dx = tw / 2 if align == "left" else 0.0
    P = P + sc.base_cam().R @ np.array((dx, 0, 0))
    yaw_c, pit_c = sc.cam_angles()
    sc.add(Plane(kin_tex(s, offs, 200, weight, color, mode, smear), tuple(P), tw, yaw_c, pit_c, sc.roll, al),
           label=label or "headline:" + s)


# ================================================================ notifications (v8)
# Uniquement les vraies notifications de l'appli (lib/l10n/app_fr.arb, NotificationService ; ui.REAL_NOTIFICATIONS
# refuse tout autre texte). Corps réels : titre du fichier (Téléchargement terminé), lien copié, nombre de liens,
# taille totale de la Bibliothèque (235,0 Mo + 770,0 Ko), version yt-dlp de la capture des Réglages.
NOTIFS = {
    "queued": ("Liens en file", "1 lien en file"),
    "link": ("Lien détecté", "Cliquez pour télécharger : https://m.youtube.com/watch?…"),
    "done": ("Téléchargement terminé", assets.SELF["title"]),
    "done_file": ("Téléchargement terminé", assets.SELF["file"]),
    "batch": ("Lot terminé", "2 téléchargements terminés — 235,8 Mo au total"),
    "ytdlp": ("yt-dlp mis à jour", "Mis à jour vers 2026.11.17.232707"),
}
NOTIF_EXPANDED = ("link", "batch")          # corps sur deux lignes (notification déployée)
NOTIF_CAP = 1100.0                          # largeur d'une notification sur l'écran (px de capture, écran 1170)
GLASS = dict(depth=10.0, side=(74, 74, 80), side_back=(34, 34, 38), rim=0.1)   # tranche de la carte de verre


def notif_schedule():
    """Notifications du film : (étiquette, clé NOTIFS, entrée, début et fin de la pose lisible où elle est le sujet).
    Les entrées tombent sur un coup choisi (BEATS / crans du carrousel / coups du mur) ou un premier temps de phrase.
    v10 : tout événement est posé avant ≈ 2,3 s : « Téléchargement terminé » de « progress » (100 %, dernier palier à
    1,7 s) reste lisible ≈ 1 s avant le balayage de la carte."""
    q, br, m = EV["quality"], EV["browser"], EV["montage"]
    w = [SEC["wall"][0]] + EV["wall"]
    pl = BEATS["progress"][-1]
    return [("notif", "queued", q[2], q[2] + 0.3, q[4]),
            ("notif:link", "link", SEC["browser"][0], SEC["browser"][0] + 0.6, br[2]),
            ("notif", "done", pl, pl + 0.5, TR_FROM["progress"].cut - TR_FROM["progress"].d_out),
            ("notif:ytdlp", "ytdlp", m[1], m[1] + 0.65, TR_FROM["montage"].cut - TR_FROM["montage"].d_out),
            ("notif:stack1", "done_file", w[0], w[0] + 0.2, w[2]),
            ("notif:stack2", "done", w[2], w[2] + 0.2, w[6]),
            ("notif:batch", "batch", w[6], w[6] + 0.16, TR_FROM["wall"].cut - 0.1)]


def NTEX(key, glass=True):
    title, body = NOTIFS[key]
    return ui.notification(title, body, glass, key in NOTIF_EXPANDED)


def _clip_top(tex, rows):
    """Texture dont les `rows` premières lignes (fractionnaire) sont transparentes : la notification sort de sous le
    bord haut de l'écran."""
    if rows <= 0:
        return tex
    h = tex.shape[0]
    if rows >= h:
        return None
    out = tex.copy()
    r = int(rows)
    out[:r, :, 3] = 0
    if r < h:
        out[r, :, 3] = (out[r, :, 3] * (1 - (rows - r))).astype(np.uint8)
    return out


def heads_up(sc, t, key, pose, t_in, lift_at, w_up, dz_up, t_out=None, out="swipe", label=None, du_up=0.0,
             dv_up=0.0, anchor=None, out_d=0.3, lift_d=0.34):
    """Notification heads-up Android en 3D sur l'écran d'un téléphone (pose = centre, lacet, tangage, roulis) :
    1. à t_in, tombe du bord haut de l'écran (ressort, léger dépassement), découpée par ce bord, à plat sur la vitre ;
    2. à lift_at, se décolle et vient flotter vers la caméra (dz_up) en grandissant jusqu'à la largeur monde w_up
       (lisible) et en glissant de (du_up, dv_up) px de capture : carte de verre épaisse qui porte son ombre ;
       anchor : pose figée utilisée une fois décollée (le téléphone peut ensuite repartir sans elle) ;
    3. à t_out : balayée sur le côté (out = « swipe » : accélère, pivote, s'efface) ou remontée (« retract »)."""
    if t < t_in:
        return None
    tex = NTEX(key)
    th_, tw_ = tex.shape[:2]
    hc = NOTIF_CAP * th_ / tw_                          # hauteur en px de capture, à l'échelle de l'écran
    v_rest = 96 + hc / 2                                # sous la barre d'état
    k = swing(t, t_in, 26.0, 0.72)
    up = smooth((t - lift_at) / lift_d)
    if anchor is not None and up > 0:
        pose = tuple(np.asarray(pose[0]) * (1 - up) + np.asarray(anchor[0]) * up), \
            *(p0 * (1 - up) + p1 * up for p0, p1 in zip(pose[1:], anchor[1:]))
    ph, yaw, pit, roll = pose
    v = v_rest - (v_rest + hc / 2 + 8) * (1 - k) + dv_up * up
    u = 585 + du_up * up
    w0 = NOTIF_CAP * KS
    width = w0 + (w_up - w0) * up
    dz = 3.0 + (dz_up - 3.0) * up
    alpha = min(1.0, (t - t_in) / 0.04)
    dyaw, droll, dpit = 0.0, 0.0, 10.0 * math.sin(math.pi * up)
    if t_out is not None and t >= t_out:
        so = min(1.0, (t - t_out) / out_d)
        if out == "swipe":
            u += 2400 * so ** 1.6
            dyaw += 28 * so ** 1.6
            droll -= 9 * so ** 2
            alpha *= 1 - smooth((so - 0.5) / 0.5)
        else:
            v -= 1100 * hit(t, t_out, 30)
            alpha *= 1 - smooth((t - t_out) / 0.2)
    if alpha <= 0.003:
        return None
    top = v - hc * width / w0 / 2 if up <= 0 else 1.0
    if up <= 0 and top < 0:
        tex = _clip_top(tex, -top / (hc * width / w0) * th_)
        if tex is None:
            return None
    c = on_phone(ph, yaw, pit, roll, u, v, dz)
    nrm = rot(yaw + dyaw, pit + dpit, roll + droll) @ np.array((0.0, 0.0, -1.0))
    if float(nrm @ (c - sc.base_cam().pos)) >= 0:
        return None                     # écran du téléphone encore tourné vers l'arrière : rien à voir
    it = Extrude(tex, tuple(c), width, yaw + dyaw, pit + dpit, roll + droll, alpha, 0.3 * up, 0.0,
                 **{**GLASS, "depth": 2.0 + GLASS["depth"] * up})
    sc.new_group()
    sc.add(it, label=label or "notif:" + key)
    return it


def float_card(sc, t, key, sx, sy, depth, w_px, t_in, label=None, t_out=None, yaw=0.0, drop_px=150.0,
               push=(0.0, 0.0, 0.0), shadow=0.3, alpha=1.0, under=0.0, cam=False, from_d=600.0, slide=None):
    """Notification flottante attachée au cadre de la section (posée avec la caméra avant transition, elle part donc
    avec le whip) : tombe du haut en ressort en basculant vers l'avant et en arrivant du fond, carte de verre épaisse
    avec ombre portée. push = (dx px, dy px, profondeur) : décalage animé (pile éclatée) ; under (0..1) : glisse
    sous la carte de devant (pile repliée) ; t_out : balayée sur le côté."""
    if t < t_in:
        return None
    k = swing(t, t_in, 24.0, 0.74)
    dx, dy, dd = push
    d = depth + dd + from_d * (1 - k)
    x, y = sx + dx, sy + dy - drop_px * (1 - k)
    al = alpha * min(1.0, (t - t_in) / 0.05)
    dyaw = 0.0
    if t_out is not None and t >= t_out:
        so = min(1.0, (t - t_out) / 0.34)
        x += 1500 * so ** 2.2
        dyaw += 26 * so ** 2
        al *= 1 - smooth((so - 0.5) / 0.5)
    if slide is not None:          # (coupe, durée, tau, px) : part avec le whip en accélérant (rampe exponentielle)
        x += slide[3] * ramp_out(t, slide[0], slide[1], slide[2])
    if al <= 0.003:
        return None
    P = sc.screen_point(x, y, d)
    tex = NTEX(key)
    w = w_px * (depth + dd) / F0
    if cam:          # posée avec les éléments en coordonnées caméra (triée en profondeur avec eux)
        base = sc.base_cam()
        cam_plane(sc, tex, (P - base.pos) @ base.R, w, al, shadow * (1 - 0.6 * under), yaw + dyaw, 32 * (1 - k),
                  0.0, label or "notif:" + key, GLASS)
        return None
    yw, pt = sc.cam_angles()
    it = Extrude(tex, tuple(P), w, yw + yaw + dyaw, pt + 32 * (1 - k), sc.roll, al,
                 shadow * (1 - 0.6 * under), 0.0, **GLASS)
    sc.new_group()
    sc.add(it, label=label or "notif:" + key)
    return it


# ================================================================ 1. intro : couloir d'interface → icône
ICON_Z = 10500.0
FRAGS = (  # (texture, x, y, z, lacet, tangage, largeur) : murs gauche/droite, sol et plafond du couloir
    ("url", -1400, -260, 2000, 36, 0, 950),
    ("live_chart", 1400, 160, 2700, -36, 0, 950),
    ("toggle", -250, 950, 3400, 0, -38, 900),
    ("radar", 1350, -420, 4100, -36, 0, 720),
    ("video_card", -1400, 280, 4800, 36, 0, 950),
    ("ytdlp", 300, -1000, 5500, 0, 38, 900),
    ("qualities", -1350, -280, 6200, 36, 0, 800),
    ("heatmap", 1400, 320, 6900, -36, 0, 860),
    ("share", -1300, 320, 7600, 36, 0, 900),
    ("download_btn", 1300, -260, 8300, -36, 0, 950),
)
INTRO_WORDS = ("Vidéo.", "Audio.", "Hors ligne.")


def _frag_tex(key):
    if key == "share":
        return ui.share_sheet()
    return CROP(key)


def intro_zcam(t):
    z = 1120 * t + 80 * t * t
    h = EV["intro"][-1]
    if t > h:
        u = (t - h) / 0.101
        z += 4200 * u * u
    return z


def s_intro(t, a, b):
    ev = EV["intro"]
    words_t = (ev[1], ev[3], ev[5])                       # 0,57 / 1,28 / 1,99 s
    rolls = [x for x in ev if x not in words_t][:-1]       # autres coups de la montée : roulis
    u = t / b
    zc = intro_zcam(t)
    xy = catmull([(0, -90, 0), (110, 40, 0), (-80, -30, 0), (0, 0, 0)], u)
    roll = -3.0
    for i, h in enumerate(rolls):
        roll += (3.2 if i % 2 == 0 else -2.8) * snap(t, h, 60)
    sc = Scene((xy[0], xy[1], zc), (0, 0, ICON_Z), 1.0, roll)
    sc.punch = 1.4                       # le couloir file vite : les coups doivent ressortir (zoom ≤ 0,10)
    fade_in = 0.6 * smooth(t / 0.6) + 0.4 * snap(t, ev[0], 60)     # le premier coup fait jaillir le couloir
    for key, x, y, z, yaw, pit, w in FRAGS:
        d = z - zc
        al = fade_in * lin((d - 1400) / 700) * min(1.0, max(0.3, 1 - (d - 2600) / 3200))   # brume au loin
        sc.add(Plane(_frag_tex(key), (x, y, z), w, yaw, pit, 0, al, 0.18))
    # mots posés devant la caméra au moment de leur coup
    word_z = []
    for i, (s, h) in enumerate(zip(INTRO_WORDS, words_t)):
        z = intro_zcam(h) + 3000
        word_z.append(z)
        if t < h:
            continue
        nxt = words_t[i + 1] if i + 1 < len(words_t) else words_t[-1] + 0.85
        if i + 1 < len(words_t) and t >= nxt:
            continue                       # coupe franche sur le coup suivant : pas de mot fantôme sous le nouveau
        al = snap(t, h, 45) * lin((z - zc - 1500) / 500) * (1 - snap(t, nxt, 22) * (i + 1 == len(words_t)))
        k = 0.82 + 0.18 * snap(t, h, 40)
        sc.add(word_plane(s, (0, 260, z), 136 * k, 3000, alpha=al), label="iword:" + s)
    # icône au bout du couloir
    sc.add(Plane(ICON(), (0, 0, ICON_Z), 900, 0, 0, 0, 1.0, 0.25), label="icon")
    # mise au point : suit le mot courant puis l'icône
    focus = word_z[0] + sum((word_z[i] - word_z[i - 1]) * spring(t, words_t[i], 28) for i in (1, 2))   # net dès le coup
    focus += (ICON_Z - word_z[2]) * spring(t, words_t[2] + 0.9, 5)
    sc.focus = (0, 0, focus)
    sc.dof = 0.0019
    h = ev[-1]
    if t > h:
        sc.white = ((t - h) / (b - h)) ** 2
    return sc


# ================================================================ 2. hero : le téléphone jaillit, orbite
HERO_P = np.array((720.0, 0.0, 0.0))
HERO_FLIP = 0.56     # durée du demi-tour et de la montée du téléphone sur le drop (s)


# v9 : le vrai bouton « Télécharger » devient un bouton 3D extrudé (plus de copie flottante de la barre du bas) :
# sur e2 il sort de l'écran (l'écran ne le contient plus : sa place devient son logement), sur e5 il est enfoncé à
# fleur de l'écran (état pressé + onde) et l'appli passe à la Bibliothèque. Il n'existe qu'une fois à l'image.
HERO_PILL = (722, 1944, 1110, 2118)      # bouton « Télécharger » dans la capture (x0, y0, x1, y1), bords exacts
HERO_TURN = 10.0                          # écart au face-caméra du téléphone posé (°)
HERO_PRESS = 0.26                         # durée du bouton enfoncé avant que l'appli ne passe à la Bibliothèque (s)
HERO_PILL_R = 87                          # pilule : rayon = demi-hauteur
HERO_SLOT = assets.recess_screen("capture_pill_slot", "capture", [(*HERO_PILL, HERO_PILL_R)])
HERO_LIFT = 96.0                          # hauteur du bouton sorti (unités monde ; écran ≈ 0,45 u / px de capture)
PILL_SIDES = dict(side=(178, 178, 184), side_back=(78, 78, 84), rim=0.3)   # flancs : plastique clair, arête vive


def pill_tex():
    return BOX("capture", HERO_PILL, HERO_PILL_R)


def _hero_cam(s, hold):
    tgt = np.array((60, -30, 380)) + np.array((110, 0, 0)) * hold
    return orbit(tgt, 24 - 34 * s, mix(9 - 4 * s, 1.0, hold), 3050 - 250 * s - 150 * hold), tgt


def s_hero(t, a, b):
    """Coups : e0 « en un tap. » se pose ; e2 le bouton « Télécharger » se décolle ; e4 l'appli passe à la
    Bibliothèque, téléchargement en cours, 0,26 s après le tap sur le bouton (il s'enfonce, état pressé + onde).
    Caméra : arrive du fond (traversée de l'icône), orbite rapide qui se pose face au téléphone, puis repart en
    accélérant (whip-pan vers la section suivante) ; rien sur les coups."""
    e = EV["hero"]
    s = travel(camt(t), a, b, 0.5, 0.3, 0.4, 0.3)
    rise = 1 - (1 - lin((t - a) / HERO_FLIP)) ** 3
    ph = HERO_P + (0, 1100 * (1 - rise), 0)
    # pose lisible : à partir de la carte « Télécharger », le téléphone se tourne face caméra et la caméra
    # s'approche ; il reste net et de face jusqu'à la fin de la section
    hold = smooth((t - (e[2] - 0.06)) / 0.42)       # le téléphone se tourne avec la carte qui se décolle (e2)
    cam_pos, tgt = _hero_cam(s, smooth((camt(t) - (e[2] - 0.7)) / 1.8))
    sc = Scene(cam_pos, tuple(tgt), 1.0)
    fy, fp = face(ph, cam_pos)
    # v8 : sur le drop, le téléphone jaillit de dos et fait un demi-tour et plus (≈ 200°) : on voit son dos (module
    # photo, logo), sa tranche, puis l'écran qui se pose ; léger tangage qui se redresse
    flip = (1 - lin((t - a) / HERO_FLIP)) ** 3          # part à pleine vitesse sur le drop, posé sans traîne
    # v10 : posé en léger trois-quarts (HERO_TURN) pour que le relief du bouton se lise (flanc et ombre)
    yaw = mix(-40 + 26 * spring(t, a, 12.0) - 205 * flip, fy + 5 + HERO_TURN, hold)
    pit = mix(4.0 + 16 * flip, fp + 1 + 0.3 * HERO_TURN, hold)
    sc.add(PhoneItem("capture" if t < e[2] else HERO_SLOT, tuple(ph), yaw, pit, 2 * (1 - rise), 1.0, 0.32),
           label="capture")
    # fragments flous à plusieurs profondeurs (parallaxe de l'orbite)
    # (v9 : jamais un morceau de l'écran montré par le téléphone, « capture » puis « done » : autres écrans de l'appli)
    frags(sc, _hero_cam(0.55, 1.0), (("heatmap", 1580, 150, 5200, 520, -14, 3.0, 0.7),
                                     ("ytdlp", 260, 900, 5600, 380, 18, 3.0, 0.55),
                                     ("parallel", 1780, 1010, 950, 640, -10, 12.0, 0.9),
                                     ("by_source", -60, 120, 1100, 560, 16, 12.0, 0.8)))
    # titre derrière le téléphone (parallaxe), lettre par lettre puis mot par mot ; sort par le haut avant le whip
    zt, x0, dref = 350.0, -1380.0, 3700.0
    tout = e[3] + 0.1                  # le titre sort avant le tap (e4) : le bouton et son relief restent seuls

    def line(s_, x, y, t_in, color=S.INK, mode="word", stagger=0.06, dt_out=0.0, travel_z=260.0, w=34.0):
        n = kin_count(s_, mode=mode)
        kw = dict(stagger=stagger, w=w, out_stagger=0.025 if mode == "char" else 0.06, out_d=0.32)
        offs = kin_offs(t, n, t_in, tout + dt_out, **kw)
        al = kin_alpha(offs)
        if al <= 0:
            return None
        smear = [b_ - a_ for a_, b_ in zip(offs, kin_offs(t + SHUTTER, n, t_in, tout + dt_out, **kw))]
        k = spring(t, t_in, 30)
        return word_plane(s_, (x, y, zt + travel_z * (1 - k)), 120, dref, color=color, alpha=al, align="left",
                          tex=kin_tex(s_, offs, color=color, mode=mode, smear=smear))
    sc.add(line("Télécharge", x0, -180, a + 0.10, mode="char", stagger=0.028, w=24.0), label="headline:Télécharge")
    sc.add(line("en un", x0, 170, e[0], dt_out=0.16, travel_z=900.0, w=60.0, stagger=0.04), label="headline:en un")
    sc.add(line("tap.", x0 + text_width("en un ", 120, dref), 170, e[0] + 0.03, S.RED, dt_out=0.26, travel_z=900.0,
                w=60.0), label="headline:tap.")
    # tap : le bouton s'enfonce et reste pressé HERO_PRESS, puis l'écran passe à la Bibliothèque (vraie capture,
    # téléchargement en cours) sur le coup e4
    tap = e[4] - HERO_PRESS            # le doigt se pose HERO_PRESS avant le coup e4, où l'écran répond (Bibliothèque)
    kn = hit(t, e[4], 40)
    if kn > 0:
        sc.new_group()
        sc.add(PhoneItem("done", tuple(ph), yaw, pit, 2 * (1 - rise), min(1.0, kn * 2.0), 0.0))
    # bouton « Télécharger » 3D (e2) : la vraie pilule sort de l'écran (extrusion vers la caméra, flancs clairs,
    # ombre douce sur l'écran), l'écran montre son logement ; tapée (e5) : enfoncée à fleur de l'écran, état pressé
    # et onde, puis l'appli passe à la Bibliothèque (le bouton appartient à l'écran qui s'en va)
    if t >= e[2]:
        k = hit(t, e[2], 42) * (1 - hit(t, tap, 40))        # s'enfonce sur le tap, reste à fleur de l'écran
        lift = HERO_LIFT * k
        card_al = 1 - min(1.0, kn * 2.0)
        px0, py0, px1, py1 = HERO_PILL
        cu, cv = (px0 + px1) / 2, (py0 + py1) / 2
        roll = 2 * (1 - rise)
        sc.new_group()
        # ombre portée sur l'écran (lumière en haut à gauche) : s'étale et s'éloigne quand le bouton monte
        sh = slot_tex(px1 - px0, py1 - py0, HERO_PILL_R)
        shadow = box_plane(sh, HERO_PILL, ph, yaw, pit, roll, dz=0.5, du=0.25 * lift / KS, dv=0.4 * lift / KS,
                           alpha=0.6 * k * card_al)
        shadow.blur = 2.0 + 6.0 * k
        sc.add(shadow, label="pill_shadow")
        c = on_phone(ph, yaw, pit, roll, cu, cv, lift)
        sc.new_group()
        sc.add(Extrude(pill_tex(), tuple(c), (px1 - px0) * KS, yaw, pit, roll, card_al, 0.0, 0.0,
                       depth=max(lift, 0.3), **PILL_SIDES), label="pill")
        if t >= tap:
            # bouton pressé : voile sombre sur la pilule tant que le doigt est dessus (HERO_PRESS), onde rouge du tap
            press = hit(t, tap, 70) * (1 - spring(t, tap + HERO_PRESS - 0.04, 40))
            sc.add(box_plane(sh, HERO_PILL, ph, yaw, pit, roll, dz=lift + 0.6, alpha=0.42 * press * card_al))
            r = spring(t, tap, 12)
            pc = on_phone(ph, yaw, pit, roll, cu, cv, lift + 1.2)
            sc.add(Plane(ripple_tex(), tuple(pc), 60 + 420 * r, yaw, pit, roll, (1 - r) ** 1.5 * hit(t, tap, 70)))
    sc.focus = tuple(ph + (0, 0, 170))
    sc.dof = 0.0016
    if t < a + 0.4:
        sc.white = math.exp(-(t - a) / 0.05)       # éclat du drop, bref : la traversée reste visible
    return sc


# ================================================================ 3. quality : partage → TapLoad
# ================================================================ 3. quality : partage → TapLoad
Q_P = np.array((640.0, 0.0, 0.0))
Q_YAW = 6.0          # écart au face-caméra (trois-quarts léger)
Q_PITCH = 1.0
Q_CAM_Z = -2380.0
Q_SHEET = 1.9        # largeur de la feuille de partage / largeur de l'écran
Q_SHEET_DZ = 520.0   # décollement de la feuille vers la caméra
Q_NOTIF_W = 1260.0
Q_LAYERS = (("preview", 90.0), ("targets", 190.0))   # vue éclatée de la feuille : décollement des couches (monde)
# Bibliothèque avec le téléchargement lancé : onglets, « Débit en direct » et « Extraction du titre… » (capture
# « done »), sous un fond vide de Bibliothèque (efface « Ta liste … est vide »)
SHARE_DL = assets.compose_screen("share_dl", "share", [("done", (0, 240, 1170, 1440)),
                                                       ("library", (0, 1440, 1170, 1600))])


def _q_cam(s):
    camx = 1000 - 1450 * s                     # long travelling latéral : la feuille et le téléphone glissent
    cam_pos = np.array((camx, -230 + 120 * s, Q_CAM_Z + 120 * s))
    return cam_pos, Q_P + (0.12 * camx, -10, 0)


def s_quality(t, a, b):
    """Coups : e0 tap sur la tuile TapLoad (état pressé, anneau, onde) ; e2 la feuille part et la vraie notification
    « Liens en file / 1 lien en file » tombe du bord haut de l'écran, se décolle et flotte vers la caméra ; e4 elle est
    balayée sur le côté et le téléchargement apparaît dans la Bibliothèque (vraie capture). La feuille de partage est
    une vue éclatée (surface, aperçu du lien, rangée de cibles séparés en profondeur, ombres entre eux). Caméra :
    arrive en whip-pan, long travelling latéral qui ralentit sur la pose puis repart (whip-tilt) ; rien sur les
    coups."""
    e = EV["quality"]
    s = travel(camt(t), a, b, 0.35, 0.25, 0.45, 0.3)
    cam_pos, tgt = _q_cam(s)
    sc = Scene(cam_pos, tuple(tgt), 1.0)
    sc.shift = (440.0, 0.0)                    # téléphone à droite du cadre, titre à gauche
    # le téléphone suit la caméra (de face, léger trois-quarts) : l'écran reste lisible pendant tout le travelling
    fy, fp = face(Q_P, cam_pos)
    qy, qp = fy + Q_YAW, fp + Q_PITCH
    R = rot(qy, qp, 0)
    # au fond, flou : la carte de la vidéo partagée (profondeur) ; fragments à plusieurs profondeurs
    sc.add(Plane(CROP("video_card"), (-1550, 1150, 3300), 1500, 12, 0, 0, 0.85, 0.08))
    frags(sc, (*_q_cam(0.5), 0.0, (440.0, 0.0)),
          (("url", 180, 120, 5600, 460, 10, 3.0, 0.55), ("heatmap", 1900, 820, 6200, 520, -16, 3.0, 0.5),
           ("toggle", 120, 1030, 1000, 640, 12, 12.0, 0.9), ("ytdlp", 1880, 60, 1150, 560, -12, 12.0, 0.75)))
    sc.add(PhoneItem("share", tuple(Q_P), qy, qp, 0, 1.0, 0.3))
    if t >= e[4]:
        # le téléchargement lancé apparaît dans la Bibliothèque : l'état vide laisse place à la carte « Débit en
        # direct » et à la ligne « Extraction du titre… » (vraies captures)
        k = hit(t, e[4], 45)
        sc.new_group()
        sc.add(PhoneItem(SHARE_DL, tuple(Q_P), qy, qp, 0, min(1.0, k * 2.5), 0.0))
    # titre attaché au cadre, à la profondeur du téléphone (net) : mot par mot ; sort avant le whip
    tout = b - 0.80
    head(sc, t, "Partage depuis", 140, 430, 2150, 78, a + 0.16, tout)
    head(sc, t, "n'importe quelle app.", 140, 545, 2150, 78, e[0], tout + 0.06, color=S.GREY, stagger=0.05, w=34.0)
    # feuille de partage qui monte devant le téléphone, agrandie vers la caméra (sujet jusqu'à e[2]) : vue éclatée,
    # l'aperçu du lien et la rangée de cibles flottent au-dessus de la surface (Q_LAYERS), ombre sur la couche du
    # dessous ; ils se reposent dans la surface quand la feuille part (e2)
    rise = spring(t, a + 0.04, 13)
    gone = spring(t, e[2], 22)
    sw = 1170 * KS * Q_SHEET
    c0 = on_phone(Q_P, qy, qp, 0, 585 + 90, 2388 - 760, Q_SHEET_DZ)
    c = c0 + R @ np.array((0, 200 * (1 - rise) + 1500 * gone, 0))
    sheet_al = (1 - gone)          # déjà là sur la coupe, finit de monter : pas de fondu sur une grande surface
    ex = smooth((t - a - 0.05) / 0.45) * (1 - smooth((t - e[2] + 0.05) / 0.15))
    sc.new_group()
    sc.add(Plane(ui.share_layer("base"), tuple(c), sw, qy, qp, 0, sheet_al, 0.35), label="share_sheet")
    lifts = {}
    for part, dz in Q_LAYERS:
        lifts[part] = dz * ex
        sc.add(Plane(ui.share_layer(part), tuple(c - R @ np.array((0, 0, lifts[part] + 1.0))), sw, qy, qp, 0,
                     sheet_al, 0.28 * ex), label="share:" + part)
    # tap sur la cible TapLoad (e0) : tuile pressée (voile clair ≈ 150 ms), anneau de sélection, onde
    if t >= e[0] and sheet_al > 0.003:
        k = hit(t, e[0], 60)
        s_ = sw / ui.SHARE_W
        x0, y0, x1, y1 = ui.SHARE_TILE
        tc = c + R @ np.array((((x0 + x1) / 2 - ui.SHARE_W / 2) * s_, ((y0 + y1) / 2 - ui.SHARE_H / 2) * s_,
                               -6 - lifts["targets"]))
        press = k * (1 - spring(t, e[0] + 0.15, 22))
        sc.new_group()                      # toujours devant la feuille (tri par centre : la feuille est inclinée)
        tile = slot_tex(int(x1 - x0), int(y1 - y0), 44, (255, 255, 255))
        sc.add(Plane(tile, tuple(tc + R @ np.array((0, 0, 2))), (x1 - x0) * s_, qy, qp, 0, 0.32 * press * sheet_al))
        rt = ring_tex(int(x1 - x0), int(y1 - y0), 44)
        rw = rt.shape[1] * s_ * (1.25 - 0.25 * k)
        sc.add(Plane(rt, tuple(tc), rw, qy, qp, 0, k * sheet_al))
        r = spring(t, e[0], 12)
        sc.add(Plane(ripple_tex(), tuple(tc - R @ np.array((0, 0, 4))), (60 + 520 * r) * s_,
                     qy, qp, 0, (1 - r) ** 1.5 * k * sheet_al))
    # notification « Liens en file » (e2) : heads-up qui tombe du bord haut de l'écran, se décolle et vient flotter
    # vers la caméra (lisible), puis balayée sur le côté (e4) quand la Bibliothèque montre le téléchargement
    heads_up(sc, t, "queued", (Q_P, qy, qp, 0.0), e[2], e[2] + 0.1, Q_NOTIF_W, 230.0, t_out=e[4], label="notif",
             dv_up=150.0, lift_d=0.2)
    sheet_f = on_phone(Q_P, qy, qp, 0, 585, 1600, Q_SHEET_DZ)
    nf = spring(t, e[2] - 0.1, 14) if t > e[2] - 0.1 else 0.0
    sc.focus = tuple(sheet_f * (1 - nf) + on_phone(Q_P, qy, qp, 0, 585, 1194, 110) * nf)
    sc.dof = 0.0017
    return sc


# ================================================================ 4. browser : vue éclatée de « capture »
# ================================================================ 4. browser : vue éclatée de « capture »
X_P = np.array((0.0, 0.0, 0.0))
LAYERS = (("url", 120), ("video_card", 240), ("toggle", 360), ("qualities", 480), ("download_btn", 600))
# v9 : pendant la vue éclatée, l'écran ne contient plus les cinq couches soulevées (logements vides), jamais une
# seconde copie de chacune ; même rayon que les découpes (ui.crop)
X_SLOTS = assets.recess_screen("capture_layer_slots", "capture", [(*ui.CROPS[k][1], 28) for k, _ in LAYERS])


ROW1 = (50, 914, 1120, 1123)        # ligne « Meilleure qualité » (sélectionnée dans la capture), avec marge
ROW_PITCH = 207                     # pas entre deux lignes de qualité (capture)
ROW2 = (50, 914 + ROW_PITCH, 1120, 1123 + ROW_PITCH)   # ligne « 1080p »


@lru_cache(maxsize=1)
def quality_rows():
    """(Meilleure qualité non sélectionnée, 1080p sélectionnée) : bord et bouton radio échangés entre les deux
    lignes de la vraie capture (même gabarit, même pas)."""
    scr = assets.load_screen("capture").astype(np.float32)
    x0, y0, x1, y1 = ROW1
    r1 = scr[y0:y1, x0:x1]
    r2 = scr[y0 + ROW_PITCH:y1 + ROW_PITCH, x0:x1]
    h, w = r1.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    band = ui._sdf_rrect(xs + 0.5, ys + 0.5, 10, 10, w - 10, h - 10, 40) > -16      # bord de la carte
    radio = np.hypot(xs - (134.5 - x0), ys - (1018 - y0)) < 42
    m = (band | radio).astype(np.float32)[..., None]
    out = []
    for a_, b_ in ((r1, r2), (r2, r1)):
        tex = np.empty((h, w, 4), np.uint8)
        tex[..., :3] = np.clip(a_ * (1 - m) + b_ * m + 0.5, 0, 255).astype(np.uint8)
        tex[..., 3] = 255
        out.append(_ro(tex))
    return tuple(out)


def _x_cam(s, turn, u):
    ang = 9 - 12 * s - 20 * turn
    pit = -4 + 5.5 * s + 9 * turn
    ctr = X_P + (-120 * turn, 0, -110 * turn)
    return orbit(ctr, ang, pit, 2140 - 200 * s + 260 * turn), X_P + (-105 * turn, 0, 0), ctr


def s_browser(t, a, b):
    """Sur le premier temps : la notification « Lien détecté » tombe du haut de l'écran et flotte devant lui.
    Coups : e0 « ta qualité. » se pose et la sélection passe sur 1080p ; e2 retour sur « Meilleure qualité » et la
    notification est balayée ;
    e3 la vue éclate (les cinq couches se décollent ensemble) ; e4 elles se rangent dans l'écran (posées à ≈ 2,7 s).
    Caméra : arrive en whip-tilt, glisse en orbite et en grue vers la pose de face, puis un tour continu à partir
    de e3 (la vue éclatée se déploie pendant le tour) qui se prolonge en whip-orbit ; focale fixe."""
    e = EV["browser"]
    tc = camt(t)
    u = (tc - a) / (b - a)
    s = travel(tc, a, b, 0.55, 0.15, 0.4, 0.3)
    t0 = e[3] + 0.07
    turn = glide((tc - t0) / (b - t0), 0.3)       # le tour ne s'arrête pas : il se prolonge dans le whip-orbit
    cam_pos, tgt, ctr = _x_cam(s, turn, u)
    sc = Scene(cam_pos, tuple(tgt), 1.0)
    sc.shift = (230.0, 0.0)
    pos_r, tgt_r, _ = _x_cam(0.6, 0.0, 0.5)
    frags(sc, (pos_r, tgt_r, 0.0, (230.0, 0.0)),
          (("live_chart", 1750, 900, 5600, 520, -14, 3.0, 0.55), ("heatmap", 330, 130, 6000, 420, 16, 3.0, 0.5),
           ("radar", 1840, 120, 1000, 420, -8, 12.0, 0.8), ("share", 60, 980, 1050, 620, 14, 12.0, 0.85)))
    sc.add(PhoneItem("browser", (300, -270, 1400), -12, 0, 0, 1.0, 0.25))
    # vue éclatée (e3 → e4) : les couches soulevées ne sont plus dans l'écran, qui montre leurs logements
    ex = hit(t, e[3], 44) * (1 - hit(t, e[4], 44))
    lifts = [ex * dz for _, dz in LAYERS]
    lifted = ex > 0.003
    sc.add(PhoneItem(X_SLOTS if lifted else "capture", tuple(X_P), 0, 0, 0, 1.0, 0.3), label="capture")
    # titre attaché au cadre (la vue éclatée tourne derrière lui), mot par mot ; sort avant le whip
    tout = e[3] - 0.1                  # sort juste avant que la vue éclate (e3), quand le tour démarre
    head(sc, t, "Choisis", 185, 440, 2300, 128, a + 0.18, tout - 0.08, mode="char", stagger=0.03, out_stagger=0.03,
         out_d=0.28)
    head(sc, t, "ta qualité.", 185, 575, 2300, 128, e[0], tout + 0.06, w=34.0, out_stagger=0.08, out_d=0.28)
    sc.new_group()
    for i, (key, dz) in enumerate(LAYERS):
        if lifted:
            sc.new_group()
            sc.add(crop_plane(key, X_P, 0, 0, 0, dz=lifts[i] + 2, shadow=0.16 * lifts[i] / dz))
    # sélection de la qualité (vraie interface : bord blanc + bouton radio) et anneau rouge qui la suit,
    # posés sur la couche « qualités » (suivent son décollement)
    sel = hit(t, e[0], 60) - hit(t, e[2], 60)
    dzq = lifts[3] + 4
    sc.new_group()
    if sel > 0.003:
        r1u, r2s = quality_rows()
        sc.add(box_plane(r1u, ROW1, X_P, 0, 0, 0, dz=dzq, alpha=min(1.0, sel)))
        sc.add(box_plane(r2s, ROW2, X_P, 0, 0, 0, dz=dzq, alpha=min(1.0, sel)))
    x0, y0, x1, y1 = ROW1
    rt = ring_tex(1050, 189, 40)
    pc = on_phone(X_P, 0, 0, 0, (x0 + x1) / 2, (y0 + y1) / 2 + ROW_PITCH * sel, dzq + 2)
    sc.add(Plane(rt, tuple(pc), rt.shape[1] * KS, 0, 0, 0, snap(t, a + 0.03, 40)))
    # « Lien détecté » (vraie notification du presse-papiers) : tombe du bord haut de l'écran sur le premier temps de
    # la phrase (le lien copié ouvre « Nouveau téléchargement »), se décolle et flotte vers la caméra au-dessus de
    # l'écran, puis balayée sur le côté au retour sur « Meilleure qualité » (e2)
    heads_up(sc, t, "link", (X_P, 0.0, 0.0, 0.0), a, a + 0.25, 900.0, 230.0, t_out=e[2], dv_up=60.0)
    sc.focus = tuple(ctr)
    sc.dof = 0.0018
    return sc


# ================================================================ 5. progress : carte de progression 3D
# ================================================================ 5. progress : carte de progression 3D
P_LEVELS = (0.06, 0.30, 0.55, 0.80, 1.0)      # avant / après chacun des 4 coups choisis (BEATS["progress"])
P_CREEP = 0.025                                # avance continue entre deux paliers (le téléchargement tourne)
P_CARD = np.array((0.0, 70.0, 0.0))


def progress_state(t, a, hits):
    """(fraction affichée, fraction d'où partent les carrés « chauds », éclat 0..1) : chaque coup fait sauter la
    progression d'un bloc (attaque en 2 images), les carrés neufs brillent ~150 ms puis se posent en rouge."""
    creep = lambda x: P_CREEP * lin((x - a) / (hits[-1] - a))      # noqa: E731
    jumps = [hit(t, h, 70) for h in hits]
    p = P_LEVELS[0] + sum((P_LEVELS[i + 1] - P_LEVELS[i]) * jumps[i] for i in range(len(hits)))
    p += creep(t) * (1 - jumps[-1])
    i = int(np.searchsorted(np.asarray(hits), t, side="right")) - 1
    if i < 0:
        return p, None, 0.0
    h = hits[i]
    before = P_LEVELS[i] + creep(h)
    heat = hit(t, h, 70) * (1 - spring(t, h + 0.05, 24))
    return p, before, heat


def _p_cam(s):
    return np.array((-1150 + 1800 * s, -420 + 200 * s, -2480 + 140 * s)), np.array((40.0, 40.0, 0.0))


# balayage de la carte de progression devant l'objectif (transition progress → send), en coordonnées caméra :
# de sa place, elle passe à droite (P1), couvre tout le cadre sur la coupe (P2, légèrement tournée), puis sort à
# gauche (P3) pendant que la section suivante arrive en panoramique dans le même sens
WIPE_P1 = np.array((1900.0, -150.0, 1150.0))
WIPE_P2 = np.array((0.0, 0.0, 700.0))
WIPE_P3 = np.array((-3700.0, 120.0, 620.0))
WIPE_D, WIPE_TAU = 0.42, 0.11
WIPE_IN = 0.45


def wipe_card(t, c, hold=None):
    """(position caméra, lacet relatif) de la carte qui balaie le cadre autour de la coupe c ; hold = (position
    caméra, lacet) de la carte à sa place (avant la coupe)."""
    if t < c:
        k = ramp_out(t, c, WIPE_D, WIPE_TAU)
        H, yh = hold
        P = (1 - k) ** 2 * H + 2 * (1 - k) * k * WIPE_P1 + k * k * WIPE_P2
        return P, yh + (12 - yh) * k + 72 * k * (1 - k)
    f = 1 - ramp_in(t, c, WIPE_IN, 5.0)
    return WIPE_P2 + (WIPE_P3 - WIPE_P2) * f, 12 - 30 * f


def s_progress(t, a, b):
    """Coups (BEATS) : trois sauts de progression puis 100 % + notification « Téléchargement terminé » (corps : titre
    du fichier, comme l'appli). La carte
    reste de face ; caméra : arrive en whip-orbit, travelling latéral qui ralentit sur la pose ; à la fin, la carte
    terminée quitte sa place et balaie l'objectif (transition card-wipe). Rien sur les coups."""
    e = EV["progress"]
    hits = BEATS["progress"]
    s = travel(camt(t), a, b, 0.3, 0.2, 0.45, 0.3)
    p, hot_from, heat = progress_state(t, a, hits)
    pos, tgt = _p_cam(s)
    sc = Scene(pos, tuple(tgt), 1.0)
    sc.add(Plane(CROP("live_chart"), (2700, 420, 4200), 2400, -24, 0, 0, 0.9, 0.1))   # sous le titre, jamais derrière
    frags(sc, _p_cam(0.5), (("heatmap", 250, 980, 5800, 460, 14, 3.0, 0.5),
                            ("video_card", 1830, 90, 1050, 700, -12, 12.0, 0.85),
                            ("ytdlp", 40, 520, 1000, 520, 16, 12.0, 0.8)))
    card = ui.progress_card(p, hot_from, heat)
    fy, fp = face(P_CARD, pos)
    c = TR_FROM["progress"].cut
    if t < c - WIPE_D:
        sc.add(Plane(card, tuple(P_CARD), 1750, fy + 5, fp + 1, 0, 1.0, 0.3), label="card")
    else:
        cam = sc.base_cam()
        yc, pc = sc.cam_angles()
        P, yw = wipe_card(t, c, ((P_CARD - cam.pos) @ cam.R, fy + 5 - yc))
        cam_plane(sc, card, P, 1750, 1.0, 0.3, yw, fp + 1 - pc, label="card")
    head(sc, t, "Suivi en direct.", 175, 180, 2200, 100, a + 0.16, None, mode="char", stagger=0.025)
    head(sc, t, "yt-dlp · aria2c · ffmpeg", 185, 935, 2200, 40, e[0], None, color=S.GREY, weight="dmedium",
         label="headline:moteurs", w=34.0)
    # « Téléchargement terminé » (dernier palier, 100 %) : carte de verre qui tombe en basculant et arrive du fond, en bas à
    # droite devant la carte de progression (jamais sur le titre, dans le cadre)
    float_card(sc, t, "done", 1360, 880, 1950, 860, hits[-1], label="notif", yaw=-6.0, drop_px=60.0, cam=True,
               from_d=-250.0)
    sc.focus = (0, 70, -170)
    sc.dof = 0.0016
    return sc


# ================================================================ 6. send : deux téléphones, un fichier voyage de l'un à l'autre
# ================================================================ 6. send : deux téléphones, un fichier voyage de l'un à l'autre
SEND_L = np.array((-560.0, 0.0, 0.0))
SEND_R = np.array((560.0, 0.0, 0.0))


SEND_BTN = (512, 776, 658, 922)                 # bouton central du radar (capture « send »)
LIB_ROWS = ((40, 457, 1130, 658), (40, 679, 1130, 880))   # « TapLoad — Présentation », « presentation-1080p.mp4 »
LIB_PITCH = LIB_ROWS[1][1] - LIB_ROWS[0][1]
LIB_SLIDE = 0.15                                # durée du rangement d'une ligne reçue (puis l'écran la contient)
SEND_HOVER = 520.0                              # attente du fichier au-dessus de sa place (px de capture)
SEND_RATE = 12.0                                # vol : approche exponentielle (1/s), ~99 % en 0,4 s
# états de la Bibliothèque du récepteur (vraies captures recomposées, liste du plus récent au plus ancien) :
# vide (« Ta liste … est vide », Tous 0) ; lignes vides le temps qu'une ligne se range ; « presentation-1080p.mp4 »
# seul, en tête ; puis la capture complète (« TapLoad — Présentation » reçu ensuite, au-dessus)
LIB_STATES = (assets.compose_screen("library_0", "library", [("share", (0, 240, 1170, 1600))]),
              assets.compose_screen("library_1x", "library", [("share", (0, 440, 1170, 900))]),
              assets.compose_screen("library_1", "library", [("share", (0, 440, 1170, 900)),
                                                             ("library", LIB_ROWS[1], -LIB_PITCH)]),
              "library")


def _in_frame(cam, it):
    """Le téléphone it (PhoneItem) a-t-il au moins un coin dans le cadre de la caméra cam ?"""
    pts = np.array([on_phone(it.center, it.yaw, it.pitch, it.roll, u, v)
                    for u, v in ((0, 0), (1170, 0), (1170, 2388), (0, 2388))])
    uv, z = cam.project(pts)
    if z.min() < NEAR:
        return False
    return not (uv[:, 0].max() < 0 or uv[:, 0].min() > W or uv[:, 1].max() < 0 or uv[:, 1].min() > H)


def s_send(t, a, b):
    """Coups (BEATS, les quatre premiers de la section, le dernier à ≈ 2,1 s) : e0 tap sur l'appareil du radar
    (bouton pressé, onde du radar) → le fichier « presentation-1080p.mp4 » part vers l'autre téléphone ; e1 il se
    range dans sa Bibliothèque vide ; e2 / e3 idem avec « TapLoad — Présentation », rangé au-dessus ; la
    Bibliothèque reste vue ≈ 0,7 s avant la traversée. Caméra : la carte de progression finit de balayer le
    cadre, orbite qui ralentit sur la pose puis traversée entre les deux téléphones ; rien sur les coups."""
    e = EV["send"]
    taps, lands = BEATS["send"][0::2], BEATS["send"][1::2]
    s = travel(camt(t), a, b, 0.3, 0.3, 0.45, 0.3)
    ctr = (0, -124, 150)

    def cam_at(s_):
        return orbit(ctr, -24 + 40 * s_, -3 + 8 * s_, 2520 - 220 * s_)
    cam_pos = cam_at(s)
    sc = Scene(cam_pos, ctr, 1.0)
    # traversée de sortie : les deux téléphones s'écartent comme des portes pour laisser passer la caméra ; ils
    # quittent le cadre avant d'y devenir plus grands que leur texture
    tr = TR_FROM["send"]
    part = ramp_out(t, tr.cut, tr.d_out, tr.tau)
    pL = SEND_L + np.array((-2600.0, 0.0, 900.0)) * part
    pR = SEND_R + np.array((2600.0, 0.0, 900.0)) * part
    final = Scene(cam_pos, ctr, 1.0)
    _apply_offsets(final, tr.offsets(camt(t), "out"))
    fcam = final.base_cam()
    frags(sc, (cam_at(0.5), ctr), (("live_chart", 180, 160, 6000, 460, 12, 3.0, 0.45),
                                   ("heatmap", 1760, 960, 6200, 460, -12, 3.0, 0.45),
                                   ("url", 1850, 1010, 950, 600, -10, 12.0, 0.85),
                                   ("toggle", 70, 1000, 1050, 560, 12, 12.0, 0.8)))
    # la carte de progression terminée finit de balayer le cadre (transition card-wipe depuis « progress »)
    if t < a + WIPE_IN:
        P, yw = wipe_card(t, a)
        cam_plane(sc, ui.progress_card(1.0), P, 1750, 1.0, 0.3, yw, 0.0)
    sc.add(Plane(radar_ghost(), (0, -120, 2700), 3400, 0, 0, 0, 1.0, 0.0))
    # les deux écrans restent de face (lisibles), légèrement tournés l'un vers l'autre
    yl, pl = face(pL, cam_pos)
    yr, pr = face(pR, cam_pos)
    # v8 : en s'écartant, les deux téléphones basculent vers l'extérieur et font presque un demi-tour en passant de
    # part et d'autre de la caméra (on voit leur tranche puis leur dos), avec un peu de roulis
    tumble = ramp_out(t, tr.cut, 0.45, 0.14)
    # les téléphones se retournent dans la traversée de sortie (la Bibliothèque qui a reçu les deux fichiers reste
    # vue de 2,1 s au début de la sortie)
    turn = smooth((t - (tr.cut - tr.d_out)) / 0.3)
    yl, yr = yl + 5 - 50 * part - 230 * turn, yr - 5 + 50 * part + 230 * turn
    rl_, rr_ = -18 * tumble, 18 * tumble
    vis_l = 1.0 if _in_frame(fcam, PhoneItem("send", tuple(pL), yl, pl, rl_)) else 0.0
    vis_r = 1.0 if _in_frame(fcam, PhoneItem("library", tuple(pR), yr, pr, rr_)) else 0.0
    pl, pr = pl + 1 - 8 * tumble, pr + 1 - 8 * tumble
    l1, l2 = lands
    sliding = l1 <= t < l1 + LIB_SLIDE or l2 <= t < l2 + LIB_SLIDE
    lib = LIB_STATES[0 if t < l1 else 1 if sliding else 2 if t < l2 else 3]
    sc.add(PhoneItem("send", tuple(pL), yl, pl, rl_, vis_l, 0.3))
    sc.add(PhoneItem(lib, tuple(pR), yr, pr, rr_, vis_r, 0.3), label="library")
    # écran de l'émetteur : tap sur l'appareil au centre du radar (bouton pressé ≈ 150 ms) et onde du radar
    sc.new_group()
    bx0, by0, bx1, by1 = SEND_BTN
    for h in taps:
        if t >= h:
            press = hit(t, h, 70) * (1 - spring(t, h + 0.15, 22))
            sc.add(box_plane(slot_tex(bx1 - bx0, by1 - by0, (bx1 - bx0) // 2), SEND_BTN, pL, yl, pl, rl_, dz=1.0,
                             alpha=0.45 * press))
            r = spring(t, h, 9)
            al = (1 - r) ** 1.5 * hit(t, h, 70)
            if al > 0.003:
                pc = on_phone(pL, yl, pl, rl_, (bx0 + bx1) / 2, (by0 + by1) / 2, 1.5)
                sc.add(Plane(ripple_tex(), tuple(pc), (150 + 900 * r) * KS, yl, pl, 0, al))
    # le fichier voyage : sa ligne de Bibliothèque jaillit du radar de l'émetteur sur le tap (départ franc,
    # approche amortie), attend au-dessus de la liste du récepteur, puis s'y range sur le coup d'arrivée ;
    # l'état vide de la Bibliothèque disparaît à la première arrivée (écran recomposé, voir LIB_STATES)
    sc.new_group()
    # « presentation-1080p.mp4 » arrive d'abord (en tête de liste) ; « TapLoad — Présentation » ensuite, au-dessus,
    # et pousse la première ligne d'un cran vers le bas
    if l2 <= t < l2 + LIB_SLIDE:
        x0, y0, x1, y1 = LIB_ROWS[1]
        sc.add(box_plane(BOX("library", LIB_ROWS[1], 24), LIB_ROWS[1], pR, yr, pr, rr_, dz=1.0,
                         dv=-LIB_PITCH * (1 - hit(t, l2, 60))))
    for box, h0, h1 in zip((LIB_ROWS[1], LIB_ROWS[0]), taps, lands):
        if not h0 <= t < h1 + LIB_SLIDE:
            continue
        x0, y0, x1, y1 = box
        tex = BOX("library", box, 24)
        sy = LIB_ROWS[0][1] + (y1 - y0) / 2                       # toujours rangé en tête de liste
        slot = on_phone(pR, yr, pr, rr_, (x0 + x1) / 2, sy, 1.0)
        hover = on_phone(pR, yr, pr, rr_, (x0 + x1) / 2, sy - SEND_HOVER, 140.0)
        start = on_phone(pL, yl, pl, rl_, (SEND_BTN[0] + SEND_BTN[2]) / 2, (SEND_BTN[1] + SEND_BTN[3]) / 2, 30.0)
        fly = 1 - math.exp(-SEND_RATE * (t - h0))
        mid = (start + hover) / 2 + (0, -300, -380)
        P = (1 - fly) ** 2 * start + 2 * (1 - fly) * fly * mid + fly * fly * hover
        drop = hit(t, h1, 60)
        P = P + (slot - hover) * drop
        yaw_, pit_ = mix(yl, yr, fly), mix(pl, pr, fly)
        sc.add(Plane(tex, tuple(P), (x1 - x0) * KS * (0.45 + 0.55 * fly), yaw_, pit_, mix(rl_, rr_, fly),
                     min(1.0, (t - h0) / 0.02 + 0.3), 0.2 * (1 - drop)))
    # titre attaché au cadre, en haut, centré au-dessus des téléphones : mot par mot, « Sans câble. » sur le tap
    # (e1) ; il sort avant la traversée
    gap = 40
    D = 2830.0                                  # derrière les téléphones (profondeur), encore net
    wl = text_width("Envoi local.", 92, D)
    wr = text_width("Sans câble.", 92, D)
    xl = W / 2 - (wl + wr + gap) / 2 * F0 / D
    xr = xl + (wl + gap) * F0 / D
    tout = b - 0.72                              # le titre part au début de la traversée, pas pendant la pose
    head(sc, t, "Envoi local.", xl, 134, D, 92, a + 0.16, tout)
    head(sc, t, "Sans câble.", xr, 134, D, 92, BEATS["send"][0], tout + 0.06, color=S.RED, w=34.0)
    sc.focus = (0, 0, 0)
    sc.dof = 0.0016
    return sc


# ================================================================ 7. montage : carrousel de six écrans
CAROUSEL = (("archive", "Archive TikTok", "Importe tes favoris."), ("stats", "Statistiques", "Tout ce que tu as gardé."),
            ("settings", "Réglages", "yt-dlp toujours à jour."), ("library", "Bibliothèque", "Tout, au même endroit."),
            ("browser", "Navigateur", "Capture la vidéo de la page."), ("send", "Envoi", "Du PC au téléphone."))
CAR_R = 2500.0
CAR_FLIP = 115.0     # pivot propre (°) d'un téléphone loin du centre du carrousel (on voit sa tranche puis son dos)
CAR_C = np.array((0.0, 175.0, CAR_R))
STEP = 30.0


def s_montage(t, a, b):
    """Le carrousel tourne par crans sur trois coups forts (e0, e1, e3 : un temps de pose d'une seconde, le dernier
    cran à ≈ 2,3 s : posé avant le whip),
    avec de l'élan (léger dépassement), puis s'emballe dans le whip-pan de sortie ; caméra : arrive de
    la traversée, travelling diagonal qui ralentit puis repart."""
    e = EV["montage"]
    NOTCHES = (e[0], e[1], e[3])
    s = travel(camt(t), a, b, 0.45, 0.3, 0.45, 0.3)
    tr = TR_FROM["montage"]
    spin = 0.95 * ramp_out(t, tr.cut, tr.d_out, tr.tau)          # le carrousel part avec la caméra
    k = sum(swing(t, h, 50.0, 0.8) for h in NOTCHES) + spin

    def cam_at(s_):
        return (-300 + 800 * s_, -400 + 110 * s_, -2420 + 200 * s_)
    cam_pos = cam_at(s)
    sc = Scene(cam_pos, (0, 92, 300), 1.0, 2.5 - 5 * s)
    # (v9 : pas de fragment d'un écran du carrousel, « send » compris : « toggle » remplace « radar »)
    frags(sc, (cam_at(0.5), (0, 92, 300)), (("toggle", 160, 140, 6400, 520, 10, 3.0, 0.45),
                                            ("live_chart", 1780, 900, 6400, 520, -10, 3.0, 0.45),
                                            ("video_card", 1850, 1000, 950, 640, -12, 12.0, 0.85),
                                            ("qualities", 40, 120, 1100, 460, 14, 12.0, 0.75)))
    pitch = face(CAR_C - (0, 0, CAR_R), cam_pos)[1] + 1      # carrousel incliné vers la caméra : écran de face

    def pose(th):
        """Position et lacet d'un téléphone à l'angle th du carrousel : en s'éloignant du centre, il pivote sur
        lui-même vers l'extérieur (v8) : tranche, puis dos ; au centre, de face."""
        r = math.radians(th)
        P = CAR_C + (CAR_R * math.sin(r), 0, -CAR_R * math.cos(r))
        return P, -th - math.copysign(CAR_FLIP * smooth((abs(th) - 6) / 34), th)
    for i, (key, _, _) in enumerate(CAROUSEL):
        th = (i - k) * STEP
        if abs(th) > 55:
            continue
        P, yw = pose(th)
        al = lin((55 - abs(th)) / 15)
        sc.add(PhoneItem(key, tuple(P), yw, pitch, 0, al, 0.28))
    # « yt-dlp mis à jour » (vraie notification, version de la capture des Réglages) : tombe du haut de l'écran des
    # Réglages quand il se pose (e1), se décolle et glisse à droite en flottant vers la caméra (lisible), reste
    # pendant les crans suivants (le carrousel tourne derrière elle), balayée au départ du whip
    th_s = (2 - min(k, 2.0)) * STEP
    Ps, ys = pose(th_s)
    P0, y0 = pose(0.0)
    heads_up(sc, t, "ytdlp", (Ps, ys, pitch, 0.0), e[1], e[1] + 0.25, 980.0, 300.0, t_out=TR_FROM["montage"].cut - TR_FROM["montage"].d_out + 0.05,
             du_up=1616.0, dv_up=260.0, anchor=(P0, y0, pitch, 0.0))
    # nom de l'écran de devant, au-dessus du carrousel (attaché au cadre)
    yaw_c, pit_c = sc.cam_angles()
    for i in range(len(CAROUSEL)):
        w = max(0.0, 1 - abs(k - i) * 1.8)
        if w <= 0.003 or i > len(NOTCHES):      # pas de nouveau nom pendant l'emballement de sortie
            continue
        _, name, sub = CAROUSEL[i]
        off = (k - i) * 330
        for s_, px, y, wt, col, o, d in ((name, 74, 113, "black", S.INK, off, 0.0),
                                         (sub, 34, 178, "dmedium", S.GREY, off * 0.8, 0.05)):
            offs = kin_offs(t, kin_count(s_, weight=wt), a - 1.0, b - 0.62 + d, out_stagger=0.02, out_d=0.22)  # sort avant le whip
            if kin_alpha(offs) <= 0:
                continue
            P = sc.screen_point(W / 2 - o, y, 2030, t)          # devant le carrousel, encore net (σ < 0,5 px)
            sc.add(Plane(kin_tex(s_, offs, 200, wt, col), tuple(P), text_width(s_, px, 2030, wt), yaw_c, pit_c,
                         sc.roll, w), label="headline:" + s_)
    sc.focus = tuple(CAR_C + (0, 0, -CAR_R))
    sc.dof = 0.0015
    return sc


# ================================================================ 8. words : typographie 3D
# ================================================================ 8. words : typographie 3D
WORDS = ("Open source", "Licence MIT", "Zéro pub", "Android", "Windows", "Chrome", "Firefox")
WZ = 1500.0


def s_words(t, a, b):
    """Un mot par coup (coupe franche, fond clair / sombre alterné) ; le premier entre lettre par lettre quand le
    whip-pan d'arrivée se pose. Les mots sont attachés au cadre pendant les transitions (la caméra file derrière
    eux) ; entre deux, la caméra orbite autour du mot (parallaxe du point rouge)."""
    e = EV["words"]
    starts = ([a] + list(e))[:len(WORDS)]            # un mot par coup ; le dernier coup ne fait que basculer le fond
    n_ev = int(np.searchsorted(np.asarray(e), t + 1e-9))
    i = min(n_ev, len(WORDS) - 1)
    dark = n_ev % 2 == 1
    ink = LIGHT_INK if dark else S.INK

    def eye(tt):
        s_ = travel(tt, a, b, 0.4, 0.3, 0.45, 0.3)
        return orbit((0, 0, WZ), -20 + 40 * s_, 5 - 9 * s_, WZ)

    def mid(j):
        return (starts[j] + (starts[j + 1] if j + 1 < len(starts) else b)) / 2

    sc = Scene(eye(camt(t)), (0, 0, WZ), 1.0)
    if dark:
        sc.bg = DARK
    h = starts[i]
    offs = None
    if h > a:
        # le mot claque dès l'image du coup : déjà lisible (opaque, aux 2/3 de sa taille), il arrive du fond en
        # ressort puis continue d'avancer vers la caméra
        z = WZ * math.exp(math.log(1.75) * (1 - spring(t, h, 50))) - 420 * min(1.0, t - h)
        z /= 1.0 + 0.1 * sum(spring(t, x, 50) for x in e[len(WORDS) - 1:])   # dernier coup : le mot avance d'un cran
        al = 1.0
    else:   # premier mot : entre lettre par lettre dans son masque quand le whip-pan d'arrivée se pose
        n = kin_count(WORDS[0], mode="char")
        offs = kin_offs(t, n, a + 0.12, None, stagger=0.022, w=40)
        al = kin_alpha(offs)
        z = WZ * (1.06 - 0.06 * spring(t, a + 0.12, 14)) - 420 * max(0.0, t - a - 0.12)
    s = WORDS[i]
    smear = None
    if i == len(WORDS) - 1:
        # dernier mot : lisible sur son coup et les 3 images suivantes, puis ses lettres plongent dans leur masque
        # (vers le bas, comme le whip-tilt qui suit) dans les 3 dernières images avant la coupe
        ex = dict(out_stagger=0.002, out_d=0.035, out_dir=1.0)
        n = kin_count(s, mode="char")
        offs = kin_offs(t, n, a - 10.0, b - 0.048, **ex)
        later = kin_offs(t + SHUTTER, n, a - 10.0, b - 0.048, **ex)
        smear = [o1 - o0 for o0, o1 in zip(offs, later)]
        al = kin_alpha(offs)
    tmp = Scene(eye(camt(t)), (0, 0, WZ))
    dot_al = spring(t, a + 0.3, 40) if i == 0 else 1.0
    if i == len(WORDS) - 1:
        dot_al = 1 - lin((t - (b - 0.048)) / 0.03)
    # v8 : le mot se pose en tournant légèrement en 3D (lacet alterné, tangage) : ses flancs apparaissent puis il se
    # stabilise en léger trois-quarts (l'orbite de la caméra continue de faire vivre le volume)
    land = 1 - spring(t, h, 24.0) if h > a else 1 - spring(t, a + 0.12, 14.0)
    sgn = 1.0 if i % 2 == 0 else -1.0
    wyaw = sgn * (18.0 * land + 4.0)
    wpit = -10.0 * land + 3.0
    _word3d(tmp, s, z, al, ink, eye(mid(i)), offs, dot_al=dot_al, smear=smear, yaw=wyaw, pitch=wpit, dark=dark)
    cam0 = sc.base_cam()
    yc, pc = sc.cam_angles()
    for it in tmp.groups[0]:
        c = (np.asarray(it.center, np.float64) - cam0.pos) @ cam0.R
        ext = dict(depth=it.depth, side=it.side, side_back=it.side_back, rim=it.rim) if isinstance(it, Extrude) \
            else None
        cam_plane(sc, it.tex, c, it.size_w, it.alpha, 0.0, it.yaw - yc, it.pitch - pc, -sc.roll,
                  getattr(it, "label", None), ext)
    # halo rouge flou loin derrière (le point, hors champ de netteté) et fragments lointains (la caméra file)
    u = (t - a) / (b - a)
    sc.add(Plane(BOKEH(), (1500 - 400 * u, -700, 7000), 4200, 0, 0, 0, 0.16 if dark else 0.09))
    ref = (eye(a + 1.6), (0, 0, WZ))
    frags(sc, ref, (("radar", 240, 200, 7000, 380, 12, 4.0, 0.35), ("live_chart", 1700, 880, 7400, 460, -12, 4.0, 0.35),
                    ("heatmap", 1750, 140, 7600, 380, -10, 4.0, 0.3), ("ytdlp", 200, 900, 7400, 380, 10, 4.0, 0.3)))
    sc.focus = (0, 0, WZ)
    sc.dof = 0.0012
    return sc


@lru_cache(maxsize=1)
def _baseline():
    """Position de la ligne de base dans une texture de text_layer (fraction de hauteur, police black)."""
    from PIL import ImageFont

    from film import config
    from film.typo import SS
    f = ImageFont.truetype(str(config.FONTS["black"]), 200 * SS)
    asc, desc = f.getmetrics()
    return (4 * SS + asc) / (asc + desc + 8 * SS)


WORD_DEPTH = 48.0                                   # extrusion des mots (px à l'écran à la profondeur WZ)
WORD_SIDES = {False: ((96, 96, 104), (18, 18, 20)),   # fond clair : flancs graphite (près de la face → au fond)
              True: ((176, 176, 184), (46, 46, 52))}   # fond sombre : flancs gris clair
DOT_SIDES = ((196, 52, 44), (92, 22, 18))


def _word3d(sc, s, z, al, ink, eye, offs=None, dot_al=1.0, smear=None, yaw=0.0, pitch=0.0, dark=False):
    """Mot extrudé (v8 : vraies lettres en volume, flancs plus sombres, face éclairée à l'encre exacte) à la
    profondeur z, tourné de (yaw, pitch) autour de son centre, + point rouge en volume détaché en avant
    (parallaxe), calé sur la ligne de base au repos (offs : lettres dans leur masque, voir kin_tex)."""
    if al <= 0.003:
        return
    tex = TXT(s, 200, "black", tuple(ink)) if offs is None else kin_tex(s, offs, 200, "black", ink, "char", smear)
    th, tw = tex.shape[:2]
    ratio = z / WZ
    kk = 236 / 200 * ratio                     # unités monde par pixel de texture (1 px écran = 1 unité à WZ)
    r = 27 * ratio
    gap = 14 * ratio
    pad = 4 * kk
    xc = -(gap + 2 * r) / 2
    side, back = WORD_SIDES[bool(dark)]
    sc.add(Extrude(tex, (xc, 0, z), tw * kk, yaw, pitch, 0, al, 0.0, 0.0, WORD_DEPTH * ratio, side, back, 0.1),
           label="word:" + s)
    right = xc + tw * kk / 2 - pad
    base = (_baseline() - 0.5) * th * kk
    # le point tourne avec le mot, puis il est posé sur le rayon issu de l'œil (caméra au milieu du mot) : bien
    # placé au milieu, puis parallaxe
    dz = 0.72
    eye = np.asarray(eye, np.float64)
    ctr = np.array((xc, 0.0, z))
    tgt = ctr + rot(yaw, pitch, 0) @ (np.array((right + gap + r, base - r, z)) - ctr)
    sc.add(Extrude(DOT(), tuple(eye + (tgt - eye) * dz), 2 * r * dz, yaw, pitch, 0, al * dot_al, 0.0, 0.0,
                   WORD_DEPTH * ratio * dz, *DOT_SIDES, 0.1))


@lru_cache(maxsize=1)
def BOKEH():
    n = 256
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    d = np.hypot(xx - n / 2 + 0.5, yy - n / 2 + 0.5) / (n / 2)
    a = np.clip(1 - d, 0, 1) ** 1.6
    out = np.zeros((n, n, 4), np.uint8)
    out[..., :3] = S.RED
    out[..., 3] = (a * 255).astype(np.uint8)
    return _ro(out)


@lru_cache(maxsize=1)
def DOT():
    n = 256
    ss = 4
    big = np.zeros((n * ss, n * ss), np.uint8)
    cv2.circle(big, (n * ss // 2, n * ss // 2), n * ss // 2 - 4 * ss, 255, -1)
    a = cv2.resize(big, (n, n), interpolation=cv2.INTER_AREA)
    out = np.zeros((n, n, 4), np.uint8)
    out[..., :3] = S.RED
    out[..., 3] = a
    return _ro(out)


# ================================================================ 9. wall : arc de neuf écrans
WALL = ("capture", "browser", "done", "library", "send", "stats", "archive", "settings", "share")
WALL_SLOTS = (4, 3, 5, 2, 6, 1, 7, 0, 8)               # ordre d'entrée : du centre vers les bords
ARC_R = 3300.0
ARC_STEP = 11.0


def s_wall(t, a, b):
    """Neuf écrans arrivent sur les coups, du centre vers les bords, de dos puis en pivotant (v8) ; sol brillant :
    reflets et ombres de contact. En haut à gauche, pile éclatée de vraies notifications : « Téléchargement terminé »
    (presentation-1080p.mp4, ev1) puis (TapLoad — Présentation, ev2) qui repousse la première vers le haut et vers le
    fond ; sur ev5 elles se replient sous « Lot terminé — 2 téléchargements terminés — 235,8 Mo au total ».
    Caméra : arrive en whip-tilt, recule en balayant l'arc puis part en whip-pan vers la carte de fin."""
    ev = [a] + EV["wall"]
    s = travel(camt(t), a, b, 0.4, 0.35, 0.45, 0.3)
    back = eo((camt(t) - a) / (b - a))       # recul continu qui ralentit (les écrans arrivent sur les coups, pas la caméra)
    cam = (640 - 1280 * s, -150 + 60 * s, -2350 - 1900 * back - 150 * s)
    sc = Scene(cam, (0, 0, 0), 1.0, 3.0 - 6 * s)
    for n, (h, slot) in enumerate(zip(ev, WALL_SLOTS)):
        if t < h:
            continue
        k = spring(t, h, 50 if n else 34)
        turn = 1 - spring(t, h, 30.0)          # arrive de dos et pivote en se posant
        al = min(1.0, k * 2.2)
        ang = (slot - 4) * ARC_STEP
        r = math.radians(ang)
        rad = ARC_R + 1500 * (1 - k)
        P = (rad * math.sin(r), 0.0, -ARC_R + rad * math.cos(r))
        sc.add(PhoneItem(WALL[n], P, -ang + 150 * turn * (1 if slot >= 4 else -1), 0, 0, al, 0.22))
    # arrière-plan : radar de l'envoi en filigrane ; premier plan : carte de progression flottante floue
    sc.add(Plane(radar_ghost(), (0, -60, 5200), 7000, 0, 0, 0, 0.8))
    fk = spring(t, a, 12)
    yw, pt = sc.cam_angles()
    sx, sy, w = 1760, 1010, 560
    P = sc.screen_point(sx + (1 - fk) * (sx - 960) * 0.6, sy + (1 - fk) * (sy - 540) * 0.6, 900)
    sc.add(Plane(ui.progress_card(1.0), tuple(P), w * 900 / F0, yw, pt, sc.roll, fk))
    # pile de notifications (attachée au cadre, à la profondeur nette du mur)
    wall_notifs(sc, t, ev)
    sc.floor = 640.0
    sc.reflect = 0.2
    sc.focus = (0, 0, 0)
    sc.dof = 0.0032
    return sc


WALL_NW = 740.0      # largeur écran des notifications de la pile (px) : capitales ≥ 18 px
WALL_NX, WALL_NY = 440.0, 238.0


def wall_notifs(sc, t, ev):
    """Pile éclatée puis repliée de vraies notifications (voir s_wall), en haut à gauche du cadre, attachée au cadre
    (y compris pendant les transitions : lisible pendant le whip d'arrivée) ; « Lot terminé » part avec le whip de
    sortie dans ses dernières images."""
    cam = sc.base_cam()
    depth = float(cam.to_cam(np.zeros((1, 3)))[0, 2]) - 150.0      # un peu devant le mur : nette
    t1, t2, tc = ev[0], ev[2], ev[6]
    # la plus ancienne recule en profondeur et dépasse au-dessus de la nouvelle (pile éclatée), puis toutes deux
    # se replient sous la notification de groupe
    sep = smooth((t - t2) / 0.22) if t >= t2 else 0.0
    fold = smooth((t - tc) / 0.22) if t >= tc else 0.0
    cut = TR_FROM["wall"].cut
    out = (cut, 0.1, 0.03, -2600.0)
    float_card(sc, t, "done_file", WALL_NX, WALL_NY, depth, WALL_NW, t1, drop_px=120.0, cam=True,
               push=(-16 * sep, -64 * sep + 30 * fold, 240 * sep + 60 * fold), under=sep, label="notif:stack1",
               alpha=1 - 0.25 * sep, slide=out)
    float_card(sc, t, "done", WALL_NX, WALL_NY, depth, WALL_NW, t2, drop_px=120.0, cam=True,
               push=(0.0, 18 * fold, 150 * fold), under=fold, label="notif:stack2", slide=out)
    float_card(sc, t, "batch", WALL_NX, WALL_NY + 8, depth, WALL_NW, tc, drop_px=140.0, cam=True,
               label="notif:batch", slide=out)


# ================================================================ 10. end
END_CAM = ((-60.0, -40.0, -1410.0), (0.0, -20.0, 200.0))
END_ROWS = ((ui.APP_NAME, 104, "black", S.INK, -10, 0.0, "char"),
            ("Android · Windows · Open source", 36, "dmedium", S.GREY, 100, 0.07, "word"),
            ("github.com/itsnazzym/Downloader", 30, "mono", S.INK, 175, 0.11, "word"),
            ("Musique : « Future Bass Lite », NERDtasticBEATS (CC BY 4.0)", 26, "dmedium", S.GREY, 455, 0.15, "word"))


END_FLOOR = 800.0
END_Z = 1500.0
END_PHONES = (("capture", -1360.0, -24.0), ("library", 1240.0, 24.0))


def s_end(t, a, b):
    """Carte de fin : arrive avec le whip-pan (la coupe est avancée pour que tout soit posé sur le premier temps a),
    les lignes montent dans leur masque ; à partir de a, image parfaitement fixe et lisible."""
    sc = Scene(*END_CAM, 1.0)
    t_in = TR_TO["end"].cut + 0.02
    sc.add(Plane(ICON(), (0, -300, 0), 250, 0, 0, 0, 1.0, 0.3), label="icon")
    dref = 1500 + 500
    for s, px, wt, col, y, d, mode in END_ROWS:
        size = max(60, px * 2)
        n = kin_count(s, size, wt, mode)
        offs = [0.0] * n if t >= a else kin_offs(t, n, t_in + d, None, stagger=0.02 if mode == "char" else 0.035, w=48)
        al = kin_alpha(offs)
        if al > 0:
            sc.add(word_plane(s, (0, y * dref / F0, 500), px, dref, weight=wt, color=col, size=size,
                              tex=kin_tex(s, offs, size, wt, col, mode)))
    # v8 : deux téléphones posés sur un sol brillant encadrent le texte (reflets, ombres de contact), tournés vers
    # le centre ; immobiles dès le premier temps (la carte de fin reste parfaitement fixe)
    for key, x, yw in END_PHONES:
        sc.add(PhoneItem(key, (x, END_FLOOR - 552.0, END_Z), yw, 0.0, 0.0, 1.0, 0.35))
    sc.floor = END_FLOOR
    sc.reflect = 0.26
    sc.focus = (0, 0, 250)
    sc.dof = 0.0
    return sc


FUNCS = {"intro": s_intro, "hero": s_hero, "quality": s_quality, "browser": s_browser, "progress": s_progress,
         "send": s_send, "montage": s_montage, "words": s_words, "wall": s_wall, "end": s_end}


def section(t: float):
    for name, a, b in film.SECTIONS:
        if a <= t < b or (name == "end" and t >= a):
            return name, a, b
    return film.SECTIONS[0]


def scene(t: float) -> Scene:
    name, a, b = render_section(t)
    sc = FUNCS[name](t, a, b)
    tr, side = transition_at(camt(t))
    if tr is not None:
        _apply_offsets(sc, tr.offsets(camt(t), side))
        # pendant un whip, un téléphone entièrement hors cadre n'est pas dessiné (il n'est pas visible ; aux grands
        # angles hors axe, sa projection serait démesurément étirée)
        cam = sc.camera(t)
        for g in sc.groups:
            for it in g:
                if isinstance(it, PhoneItem) and it.alpha > 0 and not _in_frame(cam, it):
                    it.alpha = 0.0
    _place_cam_items(sc)
    return sc


# ================================================================ flou de bougé
# Obturateur à 180° (une demi-image) : quand un élément visible se déplace de plus de MB_STEP px à l'écran pendant
# l'ouverture, l'image est la moyenne de n sous-images réparties sur l'ouverture (n proportionnel à la vitesse
# écran, au plus MB_MAX). L'ouverture ne chevauche jamais une coupe (changement de scène, coupe franche).
SHUTTER = 0.5 / FPS
MB_STEP = 3.0
MB_MAX = 16


def _cut_times():
    ev = EV["intro"]
    return sorted({a for _, a, _ in film.SECTIONS} | {tr.cut for tr in TRANS} | set(HARD_CUTS)
                  | {ev[1], ev[3], ev[5]})


CUTS = _cut_times()


def shutter(t: float) -> tuple[float, float]:
    t0, t1 = t - SHUTTER / 2, t + SHUTTER / 2
    for c in CUTS:
        if t0 < c <= t1:
            if c <= t:
                t0 = c
            else:
                t1 = c - 1e-6
    return t0, t1


def _screen_pts(sc):
    from .stage import _plane_corners
    cam = sc.camera(0.0)
    out, seen = {}, {}
    for g in sc.groups:
        for it in g:
            if it.alpha < 0.15:
                continue
            if isinstance(it, PhoneItem):
                key = ("P", it.key, getattr(it, "label", None))
                pts = np.array([on_phone(it.center, it.yaw, it.pitch, it.roll, u, v)
                                for u, v in ((0, 0), (1170, 0), (1170, 2388), (0, 2388), (585, 1194))])
            else:
                key = ("L", getattr(it, "label", None), it.tex.shape)
                c = _plane_corners(it)
                pts = np.r_[c, c.mean(0, keepdims=True)]
            n = seen.get(key, 0)
            seen[key] = n + 1
            uv, z = cam.project(pts)
            if z.min() < NEAR:
                continue
            out[key + (n,)] = uv
    return out


def screen_motion(t0: float, t1: float):
    """(plus grand déplacement écran en px d'un coin d'élément visible entre t0 et t1, vecteur de ce déplacement,
    cohérence) ; cohérence = part de la surface visible (éléments pondérés par leur aire dans le cadre) qui se
    déplace d'au moins la moitié de ce maximum dans la même direction (mouvement d'ensemble : whip, balayage)."""
    p0, p1 = _screen_pts(scene(t0)), _screen_pts(scene(t1))
    best, vec = 0.0, (0.0, 0.0)
    items = []
    for k, a in p0.items():
        b = p1.get(k)
        if b is None:
            continue
        inside = ((a[:, 0] > -200) & (a[:, 0] < W + 200) & (a[:, 1] > -200) & (a[:, 1] < H + 200)) | \
                 ((b[:, 0] > -200) & (b[:, 0] < W + 200) & (b[:, 1] > -200) & (b[:, 1] < H + 200))
        if inside.any():
            d = np.linalg.norm(b - a, axis=1)
            d[~inside] = -1
            i = int(np.argmax(d))
            x0, y0 = np.clip(a.min(0), 0, (W, H))
            x1, y1 = np.clip(a.max(0), 0, (W, H))
            items.append(((x1 - x0) * (y1 - y0), (b - a).mean(0)))
            if d[i] > best:
                best, vec = float(d[i]), tuple(b[i] - a[i])
    coh = 0.0
    tot = sum(ar for ar, _ in items)
    if best > 0 and tot > 0:
        u = np.asarray(vec) / best
        coh = sum(ar for ar, m in items if float(np.dot(m, u)) > 0.5 * best) / tot
    return best, vec, coh


def screen_speed(t0: float, t1: float) -> float:
    return screen_motion(t0, t1)[0]


def motion_samples(t: float) -> int:
    """Nombre de sous-images du flou de bougé à t (1 = image nette)."""
    t0, t1 = shutter(t)
    if t1 - t0 < 1e-4:
        return 1
    return int(min(MB_MAX, max(1, math.ceil(screen_speed(t0, t1) / MB_STEP))))


def in_transition(t: float) -> bool:
    """t est-il dans la fenêtre d'une transition de section (accélération de sortie + freinage d'entrée) ?"""
    return any(w0 <= t <= w1 for w0, w1 in (tr.window() for tr in TRANS))


def blur_exempt(t: float, dt: float = 1 / FPS) -> bool:
    """La paire d'images (t, t + dt) appartient à un mouvement de transition rendu avec flou de bougé : l'écart
    image à image y dépasse volontairement le seuil de fluidité (whip, traversée, balayage), comme un vrai
    panoramique filé ; hors de ces fenêtres, ou sans flou de bougé, le seuil s'applique."""
    return (in_transition(t) or in_transition(t + dt)) and (motion_samples(t) > 1 or motion_samples(t + dt) > 1)


def render(t: float, blur: bool = True, cam_t: float | None = None) -> np.ndarray:
    """Image du film à l'instant t (s) : float32 H×W×3 dans [0, 1], avec flou de bougé (blur).

    cam_t : scène de l'instant t vue par la caméra de l'instant cam_t (sans flou) ; sert à mesurer ce qui change
    dans la scène elle-même (événements d'interface), indépendamment du trajet de caméra."""
    if cam_t is not None:
        return _render1(t, cam_t)
    n = motion_samples(t) if blur else 1
    if n <= 1:
        return _render1(t)
    t0, t1 = shutter(t)
    acc = None
    for i in range(n):
        img = _render1(t0 + (i + 0.5) * (t1 - t0) / n)
        acc = img if acc is None else cv2.add(acc, img)
    acc *= 1.0 / n
    # au-delà de MB_MAX sous-images, l'écart restant entre deux sous-images est comblé par un flou directionnel
    # dans le sens du mouvement le plus rapide (pas de copies échelonnées sur les très grands balayages)
    disp, (vx, vy), coh = screen_motion(t0, t1)
    if disp / n > 3.0 and coh > 0.45:
        from reel.core import dir_blur
        acc = dir_blur(acc, vx / n, vy / n)
    return acc


def _render1(t: float, cam_t: float | None = None) -> np.ndarray:
    global _CAM_T
    _CAM_T = cam_t
    try:
        sc = scene(t)
    finally:
        _CAM_T = None
    if cam_t is not None:
        ref = scene(cam_t)
        sc.cam_pos, sc.target, sc.roll, sc.fov, sc.shift = ref.cam_pos, ref.target, ref.roll, ref.fov, ref.shift
    cam = sc.camera(t)
    img = S.background() if sc.bg is None else np.empty((H, W, 3), np.float32)
    if sc.bg is not None:
        img[:] = sc.bg
    focus = None
    if sc.focus is not None and sc.dof > 0:
        focus = float(cam.to_cam(np.asarray(sc.focus, np.float64)[None])[0, 2])
    for g in sc.groups:
        if g:
            stage_render(img, cam, g, floor_y=sc.floor, dof_focus=focus,
                         dof_scale=sc.dof if focus is not None else 0.0, reflect=sc.reflect)
    for fx in sc.post:
        fx(img, cam)
    if sc.white > 0:
        w = min(1.0, sc.white)
        img = img * (1 - w) + w
    return np.clip(img, 0, 1, out=img)


def depth_layers(t: float) -> list[float]:
    """Profondeurs caméra des éléments visibles à t (debug / tests)."""
    sc = scene(t)
    cam = sc.camera(t)
    out = []
    for g in sc.groups:
        for it in g:
            if it.alpha < 0.05:
                continue
            c = np.asarray(it.center, np.float64)[None]
            uv, z = cam.project(c)
            if z[0] < NEAR or not (-300 < uv[0, 0] < W + 300 and -300 < uv[0, 1] < H + 300):
                continue
            out.append(float(z[0]))
    return out


def _rel_angles(normal, center, cam) -> tuple[float, float]:
    """Lacet / tangage apparents (degrés) d'une face de normale `normal` vue depuis la caméra : angle entre la
    normale et la ligne de visée, projeté sur le plan horizontal (lacet) et vertical (tangage) de la caméra."""
    n = cam.R.T @ np.asarray(normal, np.float64)
    v = cam.R.T @ (cam.pos - np.asarray(center, np.float64))
    yaw = math.degrees(math.atan2(n[0], -n[2]) - math.atan2(v[0], -v[2]))
    pit = math.degrees(math.atan2(n[1], math.hypot(n[0], n[2])) - math.atan2(v[1], math.hypot(v[0], v[2])))
    return (yaw + 180) % 360 - 180, (pit + 180) % 360 - 180


def metrics(t: float) -> list[dict]:
    """Éléments visibles à t avec leur lisibilité : pour un téléphone (kind « phone », key = capture) la hauteur
    d'écran projetée (px, bords gauche/droit moyennés) ; pour un plan étiqueté (kind « plane », key = étiquette)
    l'échelle écran / texture verticale (min des deux bords, scale_v) ; pour tous : lacet et tangage apparents
    (°), flou de profondeur de champ (sigma px, comme stage.render), boîte écran, centre projeté."""
    from .stage import MAX_SIGMA, _phone_geom, _plane_corners
    sc = scene(t)
    cam = sc.camera(t)
    focus = None
    if sc.focus is not None and sc.dof > 0:
        focus = float(cam.to_cam(np.asarray(sc.focus, np.float64)[None])[0, 2])
    out = []
    for g in sc.groups:
        for it in g:
            phone = isinstance(it, PhoneItem)
            if it.alpha < 0.05 or not (phone or getattr(it, "label", None)):
                continue
            uv, z = cam.project(_phone_geom(it) if phone else _plane_corners(it))
            if z.min() < NEAR:
                continue
            c = np.asarray(it.center, np.float64)
            zc = float(cam.to_cam(c[None])[0, 2])
            sigma = min(MAX_SIGMA, abs(zc - focus) * sc.dof) if focus is not None else 0.0
            yaw, pit = _rel_angles(rot(it.yaw, it.pitch, it.roll) @ np.array((0, 0, -1.0)), c, cam)
            key = (getattr(it, "label", None) or it.key) if phone else it.label
            m = {"kind": "phone" if phone else "plane", "key": key, "yaw": yaw,
                 "pitch": pit, "sigma": float(sigma), "alpha": it.alpha,
                 "box": tuple(int(v) for v in (*uv.min(0), *uv.max(0))), "center": tuple(uv.mean(0))}
            if phone:
                corners = np.array([on_phone(c, it.yaw, it.pitch, it.roll, u, v)
                                    for u, v in ((0, 0), (1170, 0), (1170, 2388), (0, 2388))])
                cuv, _ = cam.project(corners)
                m["screen_h"] = float((np.linalg.norm(cuv[3] - cuv[0]) + np.linalg.norm(cuv[2] - cuv[1])) / 2)
            else:
                th = it.tex.shape[0]
                m["scale_v"] = float(min(np.linalg.norm(uv[3] - uv[0]), np.linalg.norm(uv[2] - uv[1])) / th)
            out.append(m)
    return out


def phones(t: float) -> list[dict]:
    """Téléphones visibles à t (voir metrics)."""
    return [m for m in metrics(t) if m["kind"] == "phone"]


def layout(t: float) -> list:
    """Boîtes écran (x0, y0, x1, y1) des éléments visibles à t (debug de mise en page)."""
    from .stage import _phone_geom, _plane_corners, extrude_corners
    sc = scene(t)
    cam = sc.camera(t)
    out = []
    for g in sc.groups:
        for it in g:
            if it.alpha < 0.05:
                continue
            pts = _phone_geom(it) if isinstance(it, PhoneItem) else \
                extrude_corners(it) if isinstance(it, Extrude) else _plane_corners(it)
            uv, z = cam.project(pts)
            if z.min() < NEAR:
                continue
            name = getattr(it, "label", None) or (it.key if isinstance(it, PhoneItem)
                                                  else f"plane{it.tex.shape[1]}x{it.tex.shape[0]}")
            out.append((name, tuple(int(v) for v in (*uv.min(0), *uv.max(0)))))
    return out
