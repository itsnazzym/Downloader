"""Défauts mineurs de la revue finale : un test par correction (RED avant, GREEN après)."""
import subprocess

import numpy as np
import pytest

from film import config, render
from film.fx import Plate
from film.scenes import REGISTRY, s3_browse, s4_send


# ---------- S5 : fondu final et crédit CC BY
def test_s5_fade_reaches_black_by_f890():
    assert REGISTRY["s5"](110).max() < 0.005          # image 890 globale : noir franc
    assert REGISTRY["s5"](90).max() > 0.5             # et le fondu ne commence pas trop tôt


def test_s5_credit_is_legible():
    band = REGISTRY["s5"](88)[975:1035, 660:1260].max(axis=2)
    assert band.max() > 0.55                          # contraste suffisant
    assert (band.max(axis=1) > 0.3).sum() >= 18       # hauteur de glyphes lisible en 1080p


def test_s5_first_frame_has_visible_dots():
    # l'impact de l'image 780 doit tomber sur un logo en éclats, pas sur un simple halo
    assert (REGISTRY["s5"](0).max(axis=2) > 0.7).sum() >= 300


# ---------- S3 : pas de trou pendant le comptage
def test_counter_has_no_gap_while_counting():
    row = s3_browse._counter_canvas(30)[440:640].max(axis=(0, 2)) > 0.1
    cols = np.nonzero(row)[0]
    gaps = np.diff(cols)
    # 87 px = « 1 » étroit dans sa cellule tabulaire ; sans « + » le trou valait ~220 px
    assert gaps.max() <= 95, f"trou de {gaps.max()} px entre le nombre et « sites. »"


# ---------- S4 : flou de mouvement continu (pas de copies empilées)
def _cx(img):
    lum = img[200:1000, :960].mean(axis=2)
    return (lum.sum(axis=0) * np.arange(960)).sum() / max(lum.sum(), 1e-6)


@pytest.mark.parametrize("f", [14, 15, 16, 120, 121])
def test_s4_blur_substep_is_small(f):
    step = s4_send.SHUTTER / s4_send.SAMPLES
    assert abs(_cx(s4_send._frame(f + step)) - _cx(s4_send._frame(f))) <= 6.0


# ---------- Plates : pas de saut à la boucle
def _two_level_plate(tmp_path, monkeypatch, n=48):
    monkeypatch.setattr(config, "ASSETS", tmp_path)
    (tmp_path / "plates").mkdir()
    frames = np.zeros((n, 90, 160), np.uint8)
    frames[:] = np.linspace(51, 204, n).astype(np.uint8)[:, None, None]   # rampe 0,2 → 0,8, aucun saut interne
    p = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "gray", "-s", "160x90",
                          "-r", "24", "-i", "-", "-c:v", "libx264", "-crf", "8", "-pix_fmt", "yuv420p",
                          str(tmp_path / "plates" / "p2.mp4")], stdin=subprocess.PIPE)
    p.communicate(frames.tobytes())
    assert p.returncode == 0
    return Plate("p2")


def test_plate_loop_seam_is_crossfaded(tmp_path, monkeypatch):
    pl = _two_level_plate(tmp_path, monkeypatch)
    assert pl.is_video
    v = [float(pl.frame(k / 30).mean()) for k in range(0, 130)]   # > 2 boucles de 2 s
    assert np.abs(np.diff(v)).max() <= 0.12     # sans fondu, le raccord sautait de ~0,6
    assert np.all(np.diff(v[:40]) > 0)                # la première passe (avant le raccord) reste intacte


# ---------- Rendu : on ne refait pas ce qui est à jour
def test_run_scene_skips_up_to_date_scene(tmp_path, monkeypatch):
    calls = []
    monkeypatch.setattr(render, "frame_rgb", lambda n, f: calls.append(f) or np.zeros((1080, 1920, 3), np.uint8))
    render.run_scene("s1", out_dir=tmp_path)
    first = len(calls)
    assert first == 120
    render.run_scene("s1", out_dir=tmp_path)
    assert len(calls) == first                        # rien de rejoué
    render.run_scene("s1", out_dir=tmp_path, force=True)
    assert len(calls) == 2 * first
    monkeypatch.setattr(render, "source_stamp", lambda: "autre")
    render.run_scene("s1", out_dir=tmp_path)
    assert len(calls) == 3 * first                    # le code a changé : on refait


# ---------- Planche-contact régénérable depuis le film final
def test_contact_sheet_is_built_from_the_final_film(tmp_path):
    from film.assemble import contact_sheet
    clip = tmp_path / "c.mp4"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc2=s=320x180:r=30:d=4",
                    "-pix_fmt", "yuv420p", str(clip)], check=True)
    import cv2
    out = contact_sheet(clip, tmp_path / "sheet.jpg", frames=[0, 30, 60, 90, 100, 110], cols=3, tile=(160, 90))
    img = cv2.imread(str(out))
    assert img.shape[:2] == (180, 480)
