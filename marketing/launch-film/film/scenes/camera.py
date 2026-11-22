"""Caméra 2D : zoom autour d'un point, appliqué aux positions (net, sans rééchantillonner l'image)."""


def zoom_xy(x: float, y: float, s: float, cx: float = 960, cy: float = 540) -> tuple[float, float]:
    return cx + (x - cx) * s, cy + (y - cy) * s
