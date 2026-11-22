"""Drop 1 (4-8 s) : le logo explose, un panneau LED affiche VIDÉO. / AUDIO. / HORS LIGNE."""
import numpy as np

from . import sc_boot
from .core import RED, WHITE, OFF, Cam, H, W, canvas, cv2, dir_blur, dots, radial, ring, text
from .ease import in_out_cubic, out_expo, progress
from .world import LOGO, floor, logo_colors, logo_world

CAM0 = sc_boot.cam_at(120)
P0, D0 = CAM0.project(logo_world(sc_boot.LOGO_C))
R0 = CAM0.f * 26 / D0
C0 = CAM0.project(np.array([[0.0, sc_boot.LOGO_C[1], sc_boot.LOGO_C[2]]]))[0][0]
_rng = np.random.default_rng(7)
_V = (P0 - C0) / (np.linalg.norm(P0 - C0, axis=1, keepdims=True) + 1e-6) * _rng.uniform(60, 130, (len(LOGO), 1))
_V += _rng.normal(0, 6, _V.shape)
NS = 280
_ang = _rng.uniform(0, 2 * np.pi, NS)
_SV = np.c_[np.cos(_ang), np.sin(_ang)] * _rng.uniform(30, 120, (NS, 1))
_SL = _rng.uniform(14, 40, NS)
_SR = _rng.random(NS) < 0.16
TAU = 9.0

COLS, ROWS, PITCH = 69, 9, 24.0
PCX, PCY = 960.0, 455.0
WORDS = (("VIDÉO.", 3, 30, "La meilleure qualité disponible, ou celle que tu choisis."),
         ("AUDIO.", 30, 60, "Ou seulement la piste audio."),
         ("HORS LIGNE.", 60, 109, "Enregistré sur ton appareil, à toi pour de bon."))
_gr, _gc = np.mgrid[0:ROWS, 0:COLS]
GX = PCX + (_gc.ravel() - (COLS - 1) / 2) * PITCH
GY = PCY + (_gr.ravel() - (ROWS - 1) / 2) * PITCH
_GD = np.hypot(GX - PCX, (GY - PCY) * 3)
_OFF_RND = _rng.random(COLS * ROWS)
FLOOR_CAM = Cam(f=1300, pos=(0, -30, 0), pitch=-7)


def _word_alpha(f):
    """Opacité de chaque cellule du panneau et index des cellules rouges."""
    a = np.zeros(COLS * ROWS)
    red = np.zeros(COLS * ROWS, bool)
    for word, s, e, _ in WORDS:
        if not (s <= f < e + 1):
            continue
        from .core import led_cells
        cells = led_cells(word)
        c0 = (COLS - (len(word) * 6 - 1)) // 2
        idx = (cells[:, 1] + 1) * COLS + cells[:, 0] + c0
        on = cells[:, 2] == 1
        t_on = s + cells[:, 0] * 0.28
        al = np.clip((f - t_on) / 1.5, 0, 1)
        gone = f > e - 3 + _OFF_RND[idx] * 3
        al = np.where(gone, 0, al)
        a[idx[on]] = np.maximum(a[idx[on]], al[on])
        dotcol = len(word) - 1
        red[idx[on & (cells[:, 0] >= dotcol * 6) & (np.array(list(word))[cells[:, 0] // 6] == ".")]] = True
    return a, red


def _pop(f):
    best = 0.0
    for _, s, _, _ in WORDS:
        if f >= s:
            best = np.exp(-(f - s) / 4)
    return best


def render(f: float) -> np.ndarray:
    img = canvas()
    beat_env = np.exp(-(f % 15) / 4)
    # sol qui continue de défiler, onde à chaque temps
    tr = sc_boot.travel(120) + 40 * f - 0.08 * f * f
    waves = [(0, 1500, f - b, 0.5) for b in range(0, 120, 15) if f >= b]
    img = floor(img, FLOOR_CAM, tr, waves=waves, alpha=0.85)
    img = img + radial(PCX, PCY + 40, 900, RED, 2.2) * (0.10 + 0.10 * beat_env) * progress(f, 2, 10)
    # onde de choc + éclats + points du logo projetés
    for d, amp in ((0, 1.0), (4, 0.6)):
        t = progress(f - d, 0, 26)
        if 0 < t < 1:
            img = ring(img, C0[0], C0[1], 30 + 1500 * out_expo(t), 8 * (1 - t) + 1, (255, 255, 255), amp * (1 - t) ** 1.5, glow=0.8)
    if f < 40:
        k = TAU * (1 - np.exp(-f / TAU))
        p = P0 + _V * k
        fade = (1 - progress(f, 2, 16)) ** 1.5
        img = dots(img, p[:, 0], p[:, 1], R0 * (1 + f / 12), logo_colors(fade), glow=0.6 * fade)
        life = np.clip(1 - f / _SL, 0, 1)
        sp = C0 + _SV * k
        tail = C0 + _SV * TAU * (1 - np.exp(-max(f - 1.5, 0) / TAU))
        layer = np.zeros((H, W, 3), np.uint8)
        for (x0, y0), (x1, y1), l, r in zip(sp, tail, life, _SR):
            if l <= 0:
                continue
            c = (np.array(RED) if r else np.array((255, 255, 255))) * l
            cv2.line(layer, (int(x0 * 16), int(y0 * 16)), (int(x1 * 16), int(y1 * 16)), tuple(int(v) for v in c), 2, cv2.LINE_AA, 4)
        img = img + layer.astype(np.float32) / 255
    # panneau LED
    reveal = np.clip((f - 2 - _GD / 120) / 4, 0, 1)
    exit_k = progress(f, 106, 113)
    s = 1 + 0.045 * _pop(f)
    gx, gy = PCX + (GX - PCX) * s, PCY + (GY - PCY) * s
    a, red = _word_alpha(f)
    offc = np.array(OFF)[None] * 1.25 * (reveal * (1 - exit_k))[:, None]
    img = dots(img, gx, gy, PITCH * 0.34 * s, offc)
    on = a > 0
    col = np.where(red[on, None], np.array(RED)[None], np.array(WHITE)[None]) * a[on, None]
    img = dots(img, gx[on], gy[on], PITCH * 0.36 * s * (0.85 + 0.15 * a[on]), col, glow=0.9)
    # légendes
    for word, st, e, cap in WORDS:
        if st + 4 <= f < e:
            t = out_expo(progress(f, st + 4, st + 12)) * (1 - progress(f, e - 4, e))
            img = text(img, cap, 30, PCX, PCY + 175 + 14 * (1 - t), "dmedium", t, (175, 175, 182), 0)
    # sortie : fouet vers le haut
    w = in_out_cubic(progress(f, 108, 120))
    if w > 0:
        dy = 1150 * w
        img = cv2.warpAffine(img, np.float32([[1, 0, 0], [0, 1, -dy]]), (W, H))
        sp = 1150 * (in_out_cubic(progress(f + 1, 108, 120)) - w)
        img = dir_blur(img, 0, sp * 1.4)
    return img
