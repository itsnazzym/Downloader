import numpy as np, pytest
from film.scenes import REGISTRY
from film.render import run_scene, probe_frames

@pytest.mark.parametrize("name,f", [("s1", 0), ("s1", 105), ("s5", 60)])
def test_scene_frame_shape(name, f):
    img = REGISTRY[name](f)
    assert img.shape == (1080, 1920, 3) and img.dtype == np.float32 and 0 <= img.min() and img.max() <= 1

def test_s1_starts_with_single_red_dot():
    img = REGISTRY["s1"](20)
    red = (img[..., 0] > 0.6) & (img[..., 1] < 0.4)
    assert red.any() and img[~red].mean() < 0.05

def test_s1_logo_complete_at_impact():
    img = REGISTRY["s1"](104)
    assert (img.max(axis=2) > 0.8).sum() > 17 * 500   # 17 points blancs + le rouge, bien visibles

def test_render_cli_writes_scene(tmp_path):
    run_scene("s1", out_dir=tmp_path, frames=(0, 30))
    assert probe_frames(tmp_path / "s1.mp4") == 30 and not (tmp_path / "s1.tmp.mp4").exists()
