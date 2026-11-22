"""Constantes globales du film (voir spec 2026-11-19-launch-film-design.md)."""
import os
from pathlib import Path

# MDL_FORMAT=vertical → version TikTok 1080×1920 (même montage, même son)
VERTICAL = os.environ.get("MDL_FORMAT", "landscape") == "vertical"
W, H = (1080, 1920) if VERTICAL else (1920, 1080)
FPS = 30
CX, CY = W / 2, H / 2
BPM, BEAT, BAR = 120, 15, 60
TOTAL = 900
# x0, y0, x1, y1 ; en vertical on laisse libres le haut, le bas et la droite occupés par l'interface TikTok
SAFE = (60, 220, 960, 1500) if VERTICAL else (96, 54, 1824, 1026)

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
OUT = ROOT / "out" / "vertical" if VERTICAL else ROOT / "out"
MASTER = ROOT / "out" / "master.wav"  # la même bande son sert aux deux formats

_FD = Path("/usr/share/fonts/opentype/inter")
FONTS = {
    "black": _FD / "InterDisplay-Black.otf",
    "bold": _FD / "InterDisplay-Bold.otf",
    "semibold": _FD / "Inter-SemiBold.otf",
    "medium": _FD / "Inter-Medium.otf",
}

COPY = {
    "share": "Partage. Un tap.",
    "sites": "1 800+ sites.",
    "send": "Envoi local. Sans câble.",
    "archive": "Ton archive TikTok.",
    "name": "TapLoad",
    "tagline": "Android · Open source · Zéro pub",
}

# Mesurées dans assets/brand/logo-1024.png (Task 2)
LOGO_WHITE = (236, 236, 234)
LOGO_RED = (247, 71, 59)
LOGO_OFF = (22, 22, 22)
GREY_DARK = (39, 39, 42)
GREY = (161, 161, 170)
