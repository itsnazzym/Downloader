import numpy as np
from film import config
from film.fx import Plate, screen_blend, finish, motion_blur

def test_plate_fallback(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "ASSETS", tmp_path)
    for n in ("p1", "p2", "p3", "p4", "p5"):
        p = Plate(n); a, b = p.frame(0.5), p.frame(1.5)
        assert a.shape == (1080, 1920, 3) and 0 <= a.min() and a.max() <= 1
        assert a.mean() < 0.35 and np.abs(a - b).max() > 0.05, n

def test_screen_blend_never_darkens():
    base = np.random.rand(8, 8, 3).astype(np.float32); lay = np.random.rand(8, 8, 3).astype(np.float32)
    assert (screen_blend(base, lay, 1.0) >= base - 1e-6).all()

def test_finish_uint8_and_deterministic():
    img = np.full((1080, 1920, 3), 0.5, np.float32)
    assert finish(img, 10).dtype == np.uint8 and (finish(img, 10) == finish(img, 10)).all()

def test_motion_blur_averages():
    r = lambda t: np.full((4, 4, 3), t, np.float32)
    assert abs(motion_blur(r, 10, samples=4, shutter=0.5).mean() - (10 + 0.1875)) < 1e-4


def test_truncated_plate_falls_back(tmp_path, monkeypatch):
    import subprocess
    monkeypatch.setattr(config, "ASSETS", tmp_path)
    (tmp_path / "plates").mkdir()
    full = tmp_path / "full.mp4"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc2=s=320x180:r=24:d=5",
                    "-c:v", "libx264", "-movflags", "+faststart", str(full)], check=True)
    data = full.read_bytes()
    (tmp_path / "plates" / "p2.mp4").write_bytes(data[: len(data) * 2 // 5])
    p = Plate("p2")
    assert not p.is_video
