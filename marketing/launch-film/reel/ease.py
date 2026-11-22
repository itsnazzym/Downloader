"""Courbes d'easing (t ∈ [0, 1] → valeur, 0→0 et 1→1)."""
import math


def clamp01(x: float) -> float:
    return 0.0 if x < 0 else 1.0 if x > 1 else float(x)


def progress(f: float, a: float, b: float) -> float:
    return clamp01((f - a) / (b - a))


def out_expo(t: float) -> float:
    t = clamp01(t)
    return 1.0 if t >= 1 else 1 - 2 ** (-10 * t)


def in_out_cubic(t: float) -> float:
    t = clamp01(t)
    return 4 * t ** 3 if t < 0.5 else 1 - (-2 * t + 2) ** 3 / 2


def out_back(t: float, s: float = 1.70158) -> float:
    t = clamp01(t) - 1
    return t * t * ((s + 1) * t + s) + 1


def spring(t: float, freq: float = 4.5, damping: float = 0.35) -> float:
    t = clamp01(t)
    raw = lambda u: 1 - math.exp(-damping * 10 * u) * math.cos(freq * 2 * math.pi * u)
    return raw(t) / raw(1.0)
