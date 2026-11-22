"""Mouvement fluide v4 : ressorts analytiques amortis critiques, pistes, spline et caméra look-at.

Tout est fonction du temps continu (secondes) : aucun état d'une image à l'autre, donc aucun
tremblement possible et rendu image par image parallélisable.
"""
import math

import numpy as np

from reel.core import Cam


def spring(t: float, t0: float, omega: float = 18.0) -> float:
    """Réponse indicielle d'un ressort amorti critique lancé en t0 : 0 avant, monte vers 1 sans dépasser.

    1 - (1 + w·dt)·exp(-w·dt) : position et vitesse continues (vitesse nulle au départ).
    """
    dt = t - t0
    if dt <= 0:
        return 0.0
    x = omega * dt
    return 1.0 - (1.0 + x) * math.exp(-x)


class Track:
    """Valeur scalaire pilotée par des consignes (temps, valeur) : chaque changement part en ressort.

    La valeur initiale est keys[0][1] ; à chaque clé suivante, l'écart avec la consigne précédente
    s'ajoute via spring(). La somme de fonctions C¹ reste C¹ : aucun saut, même si une nouvelle
    consigne arrive avant que la précédente soit atteinte.
    """

    def __init__(self, keys, omega: float = 18.0):
        keys = sorted(((float(t), v) for t, v in keys), key=lambda k: k[0])
        if not keys:
            raise ValueError("Track sans clé")
        self.omega = omega
        self.v0 = self._val(keys[0][1])
        self.steps = [(keys[i][0], self._val(keys[i][1]) - self._val(keys[i - 1][1])) for i in range(1, len(keys))]

    @staticmethod
    def _val(v):
        return float(v)

    def __call__(self, t: float):
        out = self.v0
        for tk, dv in self.steps:
            if t <= tk:
                break  # clés triées : les suivantes ne sont pas encore parties
            out = out + dv * spring(t, tk, self.omega)
        return out


class Track3(Track):
    """Track en 3D : consignes (temps, (x, y, z)), renvoie np.ndarray (3,)."""

    @staticmethod
    def _val(v):
        return np.asarray(v, np.float64).reshape(3)

    def __call__(self, t: float) -> np.ndarray:
        return np.array(super().__call__(t), np.float64)


def catmull(points, u: float) -> np.ndarray:
    """Spline de Catmull-Rom centripète (alpha = 0,5) passant par points (N, 3), u ∈ [0, 1].

    u est réparti uniformément par segment : u = k/(N-1) tombe exactement sur points[k].
    Les extrémités sont prolongées par symétrie (points fantômes).
    """
    P = np.asarray(points, np.float64)
    n = len(P)
    if n == 0:
        raise ValueError("catmull sans point")
    if n == 1:
        return P[0].copy()
    u = min(1.0, max(0.0, float(u)))
    s = u * (n - 1)
    i = min(int(s), n - 2)
    s -= i
    p1, p2 = P[i], P[i + 1]
    p0 = P[i - 1] if i > 0 else 2 * p1 - p2
    p3 = P[i + 2] if i + 2 < n else 2 * p2 - p1
    eps = 1e-6
    t0 = 0.0
    t1 = t0 + max(np.linalg.norm(p1 - p0), eps) ** 0.5
    t2 = t1 + max(np.linalg.norm(p2 - p1), eps) ** 0.5
    t3 = t2 + max(np.linalg.norm(p3 - p2), eps) ** 0.5
    t = t1 + s * (t2 - t1)
    a1 = ((t1 - t) * p0 + (t - t0) * p1) / (t1 - t0)
    a2 = ((t2 - t) * p1 + (t - t1) * p2) / (t2 - t1)
    a3 = ((t3 - t) * p2 + (t - t2) * p3) / (t3 - t2)
    b1 = ((t2 - t) * a1 + (t - t0) * a2) / (t2 - t0)
    b2 = ((t3 - t) * a2 + (t - t1) * a3) / (t3 - t1)
    return ((t2 - t) * b1 + (t - t1) * b2) / (t2 - t1)


def look_at_angles(pos, target) -> tuple[float, float]:
    """(lacet, tangage) en degrés pour que l'axe +z de la caméra pointe de pos vers target.

    Avec reel.core.rot (y vers le bas), l'axe avant vaut (sin a·cos b, -sin b, cos a·cos b).
    """
    d = np.asarray(target, np.float64) - np.asarray(pos, np.float64)
    yaw = math.degrees(math.atan2(d[0], d[2]))
    pitch = math.degrees(math.atan2(-d[1], math.hypot(d[0], d[2])))
    return yaw, pitch


def look_at_cam(pos, target, fov_px: float = 1500.0, roll: float = 0.0) -> Cam:
    """Caméra en pos, visant target (centre de l'image), focale fov_px en pixels, roulis en degrés."""
    yaw, pitch = look_at_angles(pos, target)
    return Cam(f=fov_px, pos=tuple(np.asarray(pos, np.float64)), yaw=yaw, pitch=pitch, roll=roll)
