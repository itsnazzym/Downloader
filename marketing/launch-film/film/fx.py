"""Effets de compositing, plates lumineuses (Seedance ou repli procédural) et finition."""
from collections import OrderedDict
from typing import Callable, Literal

import cv2
import numpy as np

from . import config
from .timeline import CUES

W, H = config.W, config.H
HW, HH = W // 2, H // 2  # les replis procéduraux sont calculés en demi-résolution


# ---------------------------------------------------------------- opérations de base
def screen_blend(base: np.ndarray, layer: np.ndarray, opacity: float) -> np.ndarray:
    if opacity <= 0:
        return base
    return base + (layer * opacity) * (1.0 - base)


def over(base: np.ndarray, rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Composite rgb (H,W,3) avec alpha (H,W,1) au-dessus de base."""
    return base * (1.0 - alpha) + rgb * alpha


def grain(img: np.ndarray, f: int, amount: float = 0.035) -> np.ndarray:
    rng = np.random.default_rng(1000 + f)
    g = rng.standard_normal((HH, HW), dtype=np.float32)
    g = cv2.resize(g, (img.shape[1], img.shape[0]), interpolation=cv2.INTER_LINEAR)
    lum = img.mean(axis=2, keepdims=True)
    # le grain est plus visible dans les tons moyens, presque nul dans le noir pur
    return img + g[..., None] * amount * (0.25 + 0.75 * np.sqrt(np.clip(lum, 0, 1)))


_VIG = None


def vignette(img: np.ndarray, strength: float = 0.25) -> np.ndarray:
    global _VIG
    if _VIG is None or _VIG.shape[:2] != img.shape[:2]:
        h, w = img.shape[:2]
        y, x = np.mgrid[0:h, 0:w].astype(np.float32)
        d = np.sqrt(((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2) / np.sqrt(2)
        _VIG = (1 - d ** 2.2)[..., None].astype(np.float32)
    return img * (1 - strength + strength * _VIG)


def chroma_shift(img: np.ndarray, px: int) -> np.ndarray:
    if px <= 0:
        return img
    out = img.copy()
    out[:, px:, 0] = img[:, :-px, 0]
    out[:, :-px, 2] = img[:, px:, 2]
    return out


def motion_blur(render: Callable[[float], np.ndarray], f: int, samples: int = 4,
                shutter: float = 0.5) -> np.ndarray:
    acc = None
    for k in range(samples):
        im = render(f + k * shutter / samples)
        acc = im.astype(np.float32) if acc is None else acc + im
    return acc / samples


_IMPACTS = [c.frame for c in CUES if c.kind == "impact"]


def impact_amount(global_f: float, decay: int = 3) -> float:
    """1 sur l'image d'impact, décroît linéairement sur `decay` images."""
    best = 0.0
    for fr in _IMPACTS:
        d = global_f - fr
        if 0 <= d < decay:
            best = max(best, 1 - d / decay)
    return best


def finish(img: np.ndarray, global_f: int) -> np.ndarray:
    out = vignette(img)
    px = int(round(6 * impact_amount(global_f)))
    out = chroma_shift(out, px)
    out = grain(out, global_f)
    return (np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)


# ---------------------------------------------------------------- replis procéduraux
def _splat(buf: np.ndarray, xs: np.ndarray, ys: np.ndarray, vals: np.ndarray) -> None:
    m = (xs >= 0) & (xs < buf.shape[1] - 1) & (ys >= 0) & (ys < buf.shape[0] - 1)
    xs, ys, vals = xs[m], ys[m], vals[m]
    x0, y0 = np.floor(xs).astype(int), np.floor(ys).astype(int)
    fx, fy = xs - x0, ys - y0
    for dx, dy, w in ((0, 0, (1 - fx) * (1 - fy)), (1, 0, fx * (1 - fy)),
                      (0, 1, (1 - fx) * fy), (1, 1, fx * fy)):
        np.add.at(buf, (y0 + dy, x0 + dx), vals * w)


class _Proc:
    def __init__(self, name: str):
        self.name = name
        rng = np.random.default_rng({"p1": 1, "p2": 2, "p3": 3, "p4": 4, "p5": 5}[name])
        y, x = np.mgrid[0:HH, 0:HW].astype(np.float32)
        self.x, self.y = x, y
        if name == "p1":
            pitch = 24
            self.pitch = pitch
            tile = np.zeros((pitch, pitch), np.float32)
            cv2.circle(tile, (pitch // 2, pitch // 2), 3, 1.0, -1, cv2.LINE_AA)
            self.tile = np.tile(tile, (HH // pitch + 1, HW // pitch + 1))[:HH, :HW]
            self.gx = (x // pitch) * pitch + pitch / 2
            self.gy = (y // pitch) * pitch + pitch / 2
        elif name == "p2":
            cx, cy = HW / 2, HH / 2
            self.r = np.hypot(x - cx, y - cy) + 1e-3
            ang = np.arctan2(y - cy, x - cx)
            n = 540
            pos = (ang + np.pi) / (2 * np.pi) * n
            self.sec = np.floor(pos).astype(int) % n
            self.perp = np.abs(pos - np.floor(pos) - 0.5) * (2 * np.pi / n) * self.r  # distance au rayon central, px
            self.logr = np.log(self.r)
            self.ph = rng.random(n).astype(np.float32)
            self.sp = (0.7 + rng.random(n) * 0.9).astype(np.float32)
            self.on = (rng.random(n) < 0.45).astype(np.float32) * (0.4 + 0.6 * rng.random(n)).astype(np.float32)
            self.red = (rng.random(n) < 0.05)
        elif name == "p3":
            n = 2600
            self.ang = rng.random(n) * 2 * np.pi
            self.spd = (rng.random(n) ** 0.6) * 520
            self.bri = 0.4 + rng.random(n) * 0.8
            self.red = rng.random(n) < 0.03
        elif name == "p4":
            pass
        elif name == "p5":
            n = 320
            self.px = rng.random(n) * HW
            self.py = rng.random(n) * HH
            self.vx = (rng.random(n) - 0.5) * 6
            self.vy = -rng.random(n) * 5 - 1
            self.depth = rng.random(n)

    def frame(self, t: float) -> np.ndarray:
        n = self.name
        out = np.zeros((HH, HW, 3), np.float32)
        if n == "p1":
            wave_x = ((t * 0.32) % 1.4 - 0.2) * HW
            amp = np.exp(-((self.gx - wave_x) / 110) ** 2) * (0.7 + 0.3 * np.sin(self.gy / 60 + t * 2))
            v = self.tile * (0.05 + 0.95 * amp)
            v += cv2.GaussianBlur(v, (0, 0), 4) * 1.2 * amp
            out[:] = v[..., None]
        elif n == "p2":
            u = self.logr / 0.22 - t * 2.4 * self.sp[self.sec] + self.ph[self.sec] * 7
            seg = np.clip(1 - np.abs(np.mod(u, 1.0) - 0.3) / 0.3, 0, 1)  # segment radial effilé
            line = np.exp(-(self.perp / 0.9) ** 2)
            fall = np.clip((self.r - 60) / (HW * 0.5), 0, 1) ** 1.4
            v = seg * line * self.on[self.sec] * fall * 1.4
            out[:] = v[..., None]
            red = self.red[self.sec]
            out[red] *= np.array((1.0, 0.42, 0.36), np.float32)
        elif n == "p3":
            buf = np.zeros((HH, HW), np.float32)
            rbuf = np.zeros((HH, HW), np.float32)
            te = max(0.0, t - 0.5)
            if t >= 0.5:
                k = 1 - np.exp(-te * 2.2)
                fade = np.exp(-te * 0.9)
                xs = HW / 2 + np.cos(self.ang) * self.spd * k
                ys = HH / 2 + np.sin(self.ang) * self.spd * k * 0.92
                _splat(buf, xs[~self.red], ys[~self.red], self.bri[~self.red] * fade)
                _splat(rbuf, xs[self.red], ys[self.red], self.bri[self.red] * fade * 2)
                ring_r = 420 * k
                d = np.abs(np.hypot(self.x - HW / 2, self.y - HH / 2) - ring_r)
                buf += np.exp(-(d / 5) ** 2) * 0.6 * np.exp(-te * 2.0)
            flash = np.exp(-((t - 0.5) / 0.08) ** 2)
            buf += flash * np.exp(-(np.hypot(self.x - HW / 2, self.y - HH / 2) / 70) ** 2) * 1.2
            buf = buf + cv2.GaussianBlur(buf, (0, 0), 3) * 0.8
            rbuf = cv2.GaussianBlur(rbuf, (0, 0), 1.2)
            out[:] = buf[..., None]
            out[..., 0] += rbuf
            out[..., 1] += rbuf * 0.3
            out[..., 2] += rbuf * 0.25
        elif n == "p4":
            buf = np.zeros((HH, HW), np.float32)
            for i in range(6):
                r = (t * 70 + i * 90) % 540 + 20
                cnt = int(2 * np.pi * r / 9)
                a = np.linspace(0, 2 * np.pi, cnt, endpoint=False)
                b = np.full(cnt, np.clip(1 - r / 540, 0, 1) ** 1.3)
                _splat(buf, HW / 2 + np.cos(a) * r, HH / 2 + np.sin(a) * r, b)
            buf = cv2.GaussianBlur(buf, (0, 0), 0.8) * 4.0
            out[:] = buf[..., None]
        elif n == "p5":
            near = np.zeros((HH, HW), np.float32)
            far = np.zeros((HH, HW), np.float32)
            xs = np.mod(self.px + self.vx * t, HW)
            ys = np.mod(self.py + self.vy * t, HH)
            nm = self.depth > 0.8
            _splat(far, xs[~nm], ys[~nm], 0.5 + 0.5 * self.depth[~nm])
            _splat(near, xs[nm], ys[nm], np.full(nm.sum(), 6.0))
            v = cv2.GaussianBlur(far, (0, 0), 0.7) + cv2.GaussianBlur(near, (0, 0), 5)
            out[:] = (v * 1.0)[..., None]
        return np.clip(out, 0, 1)


# ---------------------------------------------------------------- plates
def _cover(rgb: np.ndarray) -> np.ndarray:
    """Redimensionne en remplissant tout le cadre W×H, recadré au centre (identique à resize si même format)."""
    h, w = rgb.shape[:2]
    if (w * H > h * W - 1) and (w * H < h * W + 1):
        return cv2.resize(rgb, (W, H), interpolation=cv2.INTER_CUBIC)
    s = max(W / w, H / h)
    big = cv2.resize(rgb, (round(w * s), round(h * s)), interpolation=cv2.INTER_CUBIC)
    x0, y0 = (big.shape[1] - W) // 2, (big.shape[0] - H) // 2
    return big[y0:y0 + H, x0:x0 + W]


class Plate:
    """Plate lumineuse 1920×1080 en float32. Lit assets/plates/{name}.mp4, sinon repli procédural."""

    def __init__(self, name: Literal["p1", "p2", "p3", "p4", "p5"]):
        self.name = name
        self.path = config.ASSETS / "plates" / f"{name}.mp4"
        if config.VERTICAL and (config.ASSETS / "plates" / f"{name}_v.mp4").exists():
            self.path = config.ASSETS / "plates" / f"{name}_v.mp4"  # plate générée en 9:16
        self.cap = None
        self.proc = None
        if self.path.exists():
            self.cap = cv2.VideoCapture(str(self.path))
            self.n = int(self.cap.get(cv2.CAP_PROP_FRAME_COUNT))
            self.fps = self.cap.get(cv2.CAP_PROP_FPS) or 24.0
            if self.n <= 0 or self._count_decodable() < 0.95 * self.n:
                self.cap = None  # fichier tronqué ou illisible : repli procédural
        if self.cap is None:
            self.proc = _Proc(name)
        self.last = -2
        self.cache: OrderedDict[int, np.ndarray] = OrderedDict()

    def _count_decodable(self) -> int:
        """Décode tout le fichier une fois : un fichier tronqué renvoie des images figées au seek."""
        self.cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
        k = 0
        while self.cap.grab():
            k += 1
        self.cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
        return k

    @property
    def is_video(self) -> bool:
        return self.cap is not None

    @property
    def hit_time(self) -> float:
        """Instant (s) du pic lumineux de la plate (flash de p3) ; 0,5 s pour le repli procédural."""
        if self.cap is None:
            return 0.5
        if not hasattr(self, "_hit"):
            lum = []
            for i in range(min(self.n, int(self.fps * 2))):
                self.cap.set(cv2.CAP_PROP_POS_FRAMES, i)
                ok, bgr = self.cap.read()
                lum.append(bgr.mean() if ok else 0)
            self.last = -2
            self._hit = float(np.argmax(lum)) / self.fps
        return self._hit

    def _video_frame(self, idx: int) -> np.ndarray:
        if idx in self.cache:
            return self.cache[idx]
        if idx != self.last + 1:
            self.cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ok, bgr = self.cap.read()
        if not ok:
            bgr = np.zeros((H, W, 3), np.uint8)
        self.last = idx
        rgb = _cover(bgr[..., ::-1])
        img = rgb.astype(np.float32) / 255
        img = np.clip((img - 0.07) / 0.93, 0, 1)  # noir pur : écrase le voile des plates IA
        self.cache[idx] = img
        while len(self.cache) > 6:
            self.cache.popitem(last=False)
        return img

    LOOP_XFADE = 8  # images source fondues l'une dans l'autre au raccord de boucle

    def _interp(self, pos: float) -> np.ndarray:
        i0 = int(pos)
        a = self._video_frame(i0)
        frac = pos - i0
        if frac > 1e-3:  # interpolation douce entre images source (24 → 30 fps)
            b = self._video_frame(min(i0 + 1, self.n - 1))
            return a * (1 - frac) + b * frac
        return a

    def frame(self, t: float) -> np.ndarray:
        if self.cap is None:
            return cv2.resize(self.proc.frame(t), (W, H), interpolation=cv2.INTER_LINEAR)
        n, x = self.n, min(self.LOOP_XFADE, self.n // 4)
        q = t * self.fps
        if q >= n:  # boucles suivantes : on repart de l'image x, la fin est fondue vers le début
            q = x + (q - n) % (n - x)
        a = self._interp(q)
        if q >= n - x:
            w = (q - (n - x)) / x
            return a * (1 - w) + self._interp(q - (n - x)) * w
        return a


_PLATES: dict[str, Plate] = {}


def plate(name: str) -> Plate:
    if name not in _PLATES:
        _PLATES[name] = Plate(name)
    return _PLATES[name]
