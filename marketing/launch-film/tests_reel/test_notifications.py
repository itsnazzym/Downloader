"""v8 : notifications du film — uniquement les vraies notifications de l'appli (lib/l10n/app_fr.arb,
NotificationService), animées en 3D, lisibles quand elles sont le sujet."""
import re
from functools import lru_cache
from pathlib import Path

import numpy as np
import pytest
from PIL import ImageFont

import light  # noqa: F401  (vidéo de démo = le film lui-même)
from film import config
from light import film4, ui

ROOT = Path(__file__).resolve().parent.parent
FPS = 60
# Chaînes réelles de l'appli (app_fr.arb), recopiées ici indépendamment de ui.REAL_NOTIFICATIONS
REAL = {
    "Téléchargement terminé": r".+",                       # corps = titre du fichier
    "Téléchargement échoué": r".+",
    "Lien détecté": r"Cliquez pour télécharger : .+",
    "Liens en file": r"1 lien en file|\d+ liens en file",
    "Extension connectée": r"L'extension de navigateur est connectée\.",
    "Lot terminé": r"\d+ téléchargements terminés — .+ au total",
    "yt-dlp mis à jour": r"Mis à jour vers .+",
}


def _real(title, body):
    return title in REAL and re.fullmatch(REAL[title], body) is not None


def test_every_notification_text_is_a_real_app_notification():
    for key, (title, body) in film4.NOTIFS.items():
        assert _real(title, body), (key, title, body)
        assert ui.is_real_notification(title, body)
    assert {k for _, k, *_ in film4.notif_schedule()} <= set(film4.NOTIFS)
    # aucune notification inventée : ni dans les sources du film, ni dessinable
    for rel in ("light/film4.py", "light/ui.py"):
        assert "Téléchargement lancé" not in (ROOT / rel).read_text(), rel
    with pytest.raises(ValueError):
        ui.notification("Téléchargement lancé", "TapLoad — Présentation")
    with pytest.raises(ValueError):
        ui.notification("Téléchargement terminé", "")
    # le corps de « Téléchargement terminé » est un titre de fichier montré dans la Bibliothèque
    for key in ("done", "done_file"):
        assert film4.NOTIFS[key][1] in (film4.assets.SELF["title"], film4.assets.SELF["file"])
    assert film4.NOTIFS["ytdlp"][1].endswith("2026.11.17.232707")          # version de la capture des Réglages


def test_notifications_drawn_in_the_film_use_the_real_textures():
    real = [film4.NTEX(k) for k in film4.NOTIFS] + [film4.NTEX(k, glass=False) for k in film4.NOTIFS]
    seen = set()
    for label, key, t_in, t0, t1 in film4.notif_schedule():
        for t in np.linspace(t_in + 0.02, t1, 8):
            for g in film4.scene(float(t)).groups:
                for it in g:
                    lab = getattr(it, "label", "") or ""
                    if not lab.startswith("notif"):
                        continue
                    seen.add(lab)
                    ok = any(it.tex.shape[1] == r.shape[1] and it.tex.shape[0] == r.shape[0]
                             and np.array_equal(it.tex[..., :3], r[..., :3]) for r in real)
                    assert ok, (round(float(t), 3), lab)
    assert seen >= {lab for lab, *_ in film4.notif_schedule()}


def _cap(size, weight="medium"):
    f = ImageFont.truetype(str(config.FONTS[weight]), 1000)
    return -f.getbbox("H", anchor="ls")[1] / 1000 * size


@lru_cache(maxsize=4096)
def _metrics(t):
    return film4.metrics(t)


HOLDS = film4.notif_schedule()


@pytest.mark.parametrize("label,key,t_in,t0,t1", HOLDS)
def test_notification_is_readable_when_it_is_the_subject(label, key, t_in, t0, t1):
    """Pendant sa pose (≥ 0,6 s) : capitales du plus petit texte (« TapLoad · maintenant ») ≥ 18 px, nette
    (σ ≤ 0,8 px), opaque, entièrement dans le cadre, immobile ou lente (centre ≤ 4 px par image)."""
    assert t1 - t0 >= 0.6 - 1e-6, (label, t1 - t0)
    prev, bad = None, []
    for f in range(int(np.ceil(t0 * FPS)), int(np.floor(t1 * FPS)) + 1):
        t = f / FPS
        ms = [m for m in _metrics(t) if m["key"] == label]
        if len(ms) != 1:
            bad.append((round(t, 3), "absente", len(ms)))
            continue
        m = ms[0]
        cap = m["scale_v"] * _cap(ui.NOTIF_MIN_TEXT)
        x0, y0, x1, y1 = m["box"]
        if cap < 18 or m["sigma"] > 0.8 or m["alpha"] < 0.95 or x0 < 0 or y0 < 0 or x1 > 1920 or y1 > 1080:
            bad.append((round(t, 3), round(cap, 1), round(m["sigma"], 2), round(m["alpha"], 2), m["box"]))
        c = np.asarray(m["center"])
        if prev is not None and np.linalg.norm(c - prev) > 4.0:
            bad.append((round(t, 3), "bouge", round(float(np.linalg.norm(c - prev)), 1)))
        prev = c
    assert not bad, (label, bad[:6])
