"""Contrôle de fluidité du film v4 sur les 1890 images (preuve versionnée, à lancer après toute retouche).

    python3 -m light.check4 [N_PROCESSUS]

1. Écart moyen absolu entre images consécutives (480×270, sur 255), hors fenêtres exclues :
   ±0,05 s autour des débuts de section et des coupes franches (film4.HARD_CUTS), [h − 1/60, h + 0,12 s]
   après chaque accent (film4.ACCENTS, coups forts choisis par pick), et (v7) les paires d'images des
   transitions de section rendues avec flou de bougé (film4.blur_exempt : whip, traversée, balayage ; un
   panoramique filé dépasse forcément le seuil). Seuil : < 4 partout ailleurs, y compris dans une fenêtre de
   transition là où aucun flou de bougé n'est appliqué. Les pics des transitions sont listés à part.
2. Accélération du sujet de chaque section (centre projeté, px/image²) sur les triplets d'images
   consécutives hors fenêtres exclues, avec et sans les 0,3 s qui suivent un kick (poussée de basse voulue).
   Repère « tremblement » de la revue : une variation de plus de 1,5 px/image hors coup.
"""
import sys
import time
from multiprocessing import Pool

import cv2
import numpy as np

FPS = 60
DT = 1 / FPS
SMALL = (480, 270)


def _frames():
    from . import beats as B
    return int(round(B.DUR * FPS))


def excluded(t: float) -> bool:
    from . import film, film4
    t1 = t + DT
    for _, a, _ in film.SECTIONS:
        if abs(t - a) < 0.05 or abs(t1 - a) < 0.05:
            return True
    for c in film4.HARD_CUTS:
        if t - 0.05 < c <= t1 + 0.05:
            return True
    acc = np.asarray(film4.ACCENTS)
    if np.any((acc - DT <= t) & (t <= acc + 0.12)):
        return True
    return film4.blur_exempt(t, DT)


def _diffs(rng):
    from . import film4
    a, b = rng
    out, prev = [], None
    for f in range(max(0, a - 1), b):
        sm = cv2.resize(film4.render(f / FPS), SMALL, interpolation=cv2.INTER_AREA)
        if prev is not None:
            out.append((f - 1, float(np.abs(sm - prev).mean() * 255)))
        prev = sm
    return out


SUBJECT = {"intro": "icon", "hero": "capture", "quality": "share", "browser": "capture", "progress": "card",
           "send": "library", "montage": "<centre>", "words": "word:", "wall": "capture", "end": "icon"}


def subject(t: float):
    """(identifiant, centre projeté (x, y)) du sujet de la section à t, ou None."""
    from . import film4
    from .stage import PhoneItem, _phone_geom, _plane_corners
    name, _, _ = film4.section(t)
    want = SUBJECT[name]
    sc = film4.scene(t)
    cam = sc.camera(t)
    best = None
    for g in sc.groups:
        for it in g:
            if it.alpha < 0.5:
                continue
            ident = (getattr(it, "label", None) or it.key) if isinstance(it, PhoneItem) else getattr(it, "label", "")
            pts = _phone_geom(it) if isinstance(it, PhoneItem) else _plane_corners(it)
            uv, z = cam.project(pts)
            if z.min() < 10:
                continue
            c = uv.mean(0)
            if want == "<centre>":
                if isinstance(it, PhoneItem):
                    d = float(np.hypot(c[0] - 960, c[1] - 540))
                    if best is None or d < best[0]:
                        best = (d, ident, c)
            elif ident == want or (want.endswith(":") and ident.startswith(want)):
                return ident, c
    return (best[1], best[2]) if best else None


def main(nproc: int = 2):
    from . import film, film4
    t0 = time.time()
    n = _frames()
    cuts = [(n * k // nproc, n * (k + 1) // nproc) for k in range(nproc)]
    with Pool(nproc) as pool:
        d = [x for part in pool.map(_diffs, cuts) for x in part]
    kicks = np.asarray(film4.KICKS)
    print(f"Écart image à image (480×270, /255), {len(d)} paires :")
    worst = (0.0, None)
    for name, a, b in film.SECTIONS:
        m = [(f, v) for f, v in d if a <= f / FPS < b and not excluded(f / FPS)]
        if not m:
            continue
        vs = np.array([v for _, v in m])
        fmax, vmax = max(m, key=lambda x: x[1])
        if vmax > worst[0]:
            worst = (vmax, fmax / FPS)
        print(f"  {name:9s} mesurées {len(m):4d}  médiane {np.median(vs):5.2f}  max {vmax:5.2f} (t={fmax / FPS:.3f})"
              f"  ≥4 : {int((vs >= 4).sum())}")
    over = sum(1 for f, v in d if not excluded(f / FPS) and v >= 4)
    print(f"  MAX hors fenêtres exclues : {worst[0]:.2f} à t={worst[1]:.3f} ; paires ≥ 4 : {over}")
    print("Transitions (flou de bougé) : pic d'écart près de la coupe, médiane des 0,5 s de part et d'autre :")
    dd = dict(d)
    for tr in film4.TRANS:
        c = int(round(tr.cut * FPS))
        win = [dd[f] for f in range(c - 6, c + 6) if f in dd]
        nb = [dd[f] for f in list(range(c - 60, c - 30)) + list(range(c + 30, c + 60)) if f in dd]
        nob = sum(1 for f in range(int(tr.window()[0] * FPS), int(tr.window()[1] * FPS) + 1)
                  if f in dd and dd[f] >= 4 and not film4.blur_exempt(f / FPS, DT) and not excluded(f / FPS))
        print(f"  {tr.frm:8s}→ {tr.to:8s} {tr.kind:12s} coupe {tr.cut:6.3f}  pic {max(win):6.2f}"
              f"  voisinage {np.median(nb):5.2f}  ≥4 sans flou : {nob}")

    print("Accélération du sujet (px/image²), triplets hors fenêtres exclues :")
    pos = {f: subject(f / FPS) for f in range(n)}
    for name, a, b in film.SECTIONS:
        acc_all, acc_nokick = [], []
        for f in range(int(np.ceil(a * FPS)) + 1, min(n - 1, int(np.ceil(b * FPS)) - 1)):
            ts = ((f - 1) / FPS, f / FPS)
            if any(excluded(t) for t in ts):
                continue
            p = [pos[f - 1], pos[f], pos[f + 1]]
            if any(x is None for x in p) or len({x[0] for x in p}) != 1:
                continue
            acc = float(np.linalg.norm(p[2][1] - 2 * p[1][1] + p[0][1]))
            acc_all.append(acc)
            if not np.any((kicks <= f / FPS + DT) & (kicks > f / FPS - 0.3)):
                acc_nokick.append(acc)
        if acc_all:
            nk = f"{max(acc_nokick):5.2f}" if acc_nokick else "  —  "
            print(f"  {name:9s} sujet {SUBJECT[name]:9s} max {max(acc_all):5.2f}  hors kicks {nk}"
                  f"  (triplets {len(acc_all)})")
    print(f"({time.time() - t0:.0f} s)")
    return worst[0], over


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 2)
