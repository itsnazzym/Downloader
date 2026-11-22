import cv2
import numpy as np

from light import motion, stage
from reel import core


def test_spring_is_continuous_and_settles():
    t0 = 1.25
    assert motion.spring(t0, t0) == 0
    assert motion.spring(t0 - 0.3, t0) == 0
    assert motion.spring(t0 + 0.5, t0) > 0.99
    ts = np.arange(t0 - 0.2, t0 + 1.0, 1 / 60)
    vals = np.array([motion.spring(t, t0) for t in ts])
    assert np.abs(np.diff(vals)).max() <= 0.3
    assert vals.max() <= 1.0 + 1e-9  # amorti critique : pas de dépassement


def test_track_has_no_jumps():
    tr = motion.Track([(0, 0), (1, 100), (2, -50)])
    ts = np.arange(0, 3 + 1e-9, 1 / 60)
    vals = np.array([tr(t) for t in ts])
    assert np.abs(np.diff(vals)).max() <= 35
    assert abs(tr(1.6) - 100) <= 2
    assert abs(tr(0.5)) < 1e-9 and abs(tr(3.0) + 50) <= 2


def test_track3_follows_each_axis():
    tr = motion.Track3([(0, (0, 0, 1000)), (0.5, (200, -100, 1500))])
    p = tr(2.0)
    assert p.shape == (3,) and np.allclose(p, (200, -100, 1500), atol=0.5)
    assert np.allclose(tr(0.0), (0, 0, 1000))


def test_catmull_passes_through_points():
    pts = np.array([[0, 0, 0], [100, 50, 0], [300, 0, 200], [400, -80, 900.0]])
    assert np.allclose(motion.catmull(pts, 0.0), pts[0])
    assert np.allclose(motion.catmull(pts, 1 / 3), pts[1], atol=1e-6)
    assert np.allclose(motion.catmull(pts, 2 / 3), pts[2], atol=1e-6)
    assert np.allclose(motion.catmull(pts, 1.0), pts[3])
    us = np.linspace(0, 1, 400)
    path = np.array([motion.catmull(pts, u) for u in us])
    assert np.linalg.norm(np.diff(path, axis=0), axis=1).max() < 15  # pas de saut


def test_look_at_centres_the_target():
    target = np.array([120.0, -60.0, 2500.0])
    for pos in [(0, 0, 0), (-900, -500, 600), (700, 300, 4200)]:
        cam = motion.look_at_cam(pos, target, fov_px=1500.0)
        uv, z = cam.project(target[None])
        assert z[0] > 0
        assert abs(uv[0, 0] - core.W / 2) <= 1 and abs(uv[0, 1] - core.H / 2) <= 1
    # le haut reste en haut : un point au-dessus de la cible (y plus petit) se projette plus haut
    cam = motion.look_at_cam((-900, -500, 600), target)
    uv, _ = cam.project(np.array([target, target + (0, -100, 0)]))
    assert uv[1, 1] < uv[0, 1]


def _white_plane(w=200, h=200):
    tex = np.zeros((h, w, 4), np.uint8)
    tex[...] = 255
    return tex


def test_plane_projects_where_expected():
    img = np.zeros((core.H, core.W, 3), np.float32)
    p = stage.Plane(tex=_white_plane(), center=(0, 0, 1500), size_w=400, yaw=0, pitch=0, roll=0)
    stage.render(img, core.Cam(f=1500), [p])
    cols = np.where(img[540, :, 0] > 0.5)[0]
    rows = np.where(img[:, 960, 0] > 0.5)[0]
    assert abs(len(cols) - 400) <= 3 and abs(len(rows) - 400) <= 3
    assert abs((cols[0] + cols[-1] + 1) / 2 - 960) <= 3
    assert abs((rows[0] + rows[-1] + 1) / 2 - 540) <= 3
    assert img[540, 700].sum() == 0  # rien en dehors du plan


def _checker(n=320, cell=8):
    y, x = np.mgrid[0:n, 0:n]
    v = (((x // cell) + (y // cell)) % 2 * 255).astype(np.uint8)
    tex = np.zeros((n, n, 4), np.uint8)
    tex[..., :3] = v[..., None]
    tex[..., 3] = 255
    return tex


def test_dof_blurs_far_items_only():
    img = np.full((core.H, core.W, 3), 0.5, np.float32)
    tex = _checker()
    near = stage.Plane(tex=tex, center=(-350, 0, 1500), size_w=320, yaw=0, pitch=0, roll=0)
    far = stage.Plane(tex=tex, center=(1600, 0, 4000), size_w=320 * 4000 / 1500, yaw=0, pitch=0, roll=0)
    stage.render(img, core.Cam(f=1500), [near, far], dof_focus=1500, dof_scale=0.004)
    g = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)
    lap = cv2.Laplacian(g, cv2.CV_32F)
    # même taille à l'écran (320 px) : centres en x = 610 et 1560
    v_near = lap[440:640, 520:700].var()
    v_far = lap[440:640, 1470:1650].var()
    assert v_near >= 2 * v_far


def test_render_sorts_far_to_near_and_returns_phone_info():
    img = np.zeros((core.H, core.W, 3), np.float32)
    red = np.zeros((50, 50, 4), np.uint8)
    red[..., 0], red[..., 3] = 255, 255
    blue = red.copy()
    blue[..., 0], blue[..., 2] = 0, 255
    items = [stage.Plane(tex=blue, center=(0, 0, 1000), size_w=200, yaw=0, pitch=0, roll=0),
             stage.Plane(tex=red, center=(0, 0, 3000), size_w=1200, yaw=0, pitch=0, roll=0),
             stage.PhoneItem("capture", (0, 0, 5000), 0, 0, 0)]
    infos = stage.render(img, core.Cam(f=1500), items)
    assert img[540, 960, 2] > 0.9 and img[540, 960, 0] < 0.1  # le plan proche est devant
    assert len(infos) == 3 and "map" in infos[2]


def test_text_plane_is_transparent_rgba():
    t = stage.text_plane("Vidéo.", 120)
    assert t.dtype == np.uint8 and t.shape[2] == 4
    assert t[..., 3].max() == 255 and t[0, 0, 3] == 0


def test_items_behind_camera_or_off_screen_are_skipped():
    img = np.full((core.H, core.W, 3), 0.5, np.float32)
    items = [stage.Plane(tex=_white_plane(), center=(0, 0, -500), size_w=400),
             stage.Plane(tex=_white_plane(), center=(0, 0, 5), size_w=400),  # coupe le plan proche
             stage.Plane(tex=_white_plane(), center=(9000, 0, 1500), size_w=400, shadow=0.5),
             stage.PhoneItem("capture", (0, 0, -2000), 0, 0, 0)]
    infos = stage.render(img, core.Cam(f=1500), items, dof_focus=1500, dof_scale=0.01)
    assert len(infos) == 4 and np.all(img == 0.5)


def test_receding_plane_keeps_its_average_tone():
    """Mipmaps : un damier très réduit reste gris moyen (pas de moiré), et sans saut d'un niveau à l'autre."""
    tex = _checker(1024, 1)  # damier d'un pixel : plus fin que la grille écran dès que l'échelle < 0,5
    means, stds = [], []
    for z in np.linspace(3200, 12000, 23):
        img = np.zeros((core.H, core.W, 3), np.float32)
        stage.render(img, core.Cam(f=1500), [stage.Plane(tex=tex, center=(0, 0, z), size_w=1024)])
        r = int(1500 * 1024 / z / 2 * 0.8)
        roi = img[540 - r:540 + r, 960 - r:960 + r, 0]
        means.append(roi.mean())
        stds.append(roi.std())
    means = np.array(means)
    assert np.abs(means - 0.5).max() < 0.04 and np.abs(np.diff(means)).max() < 0.02
    assert max(stds) < 0.06  # sans mipmaps, le damier sous-échantillonné crée un moiré (écart-type ≈ 0,16)


def test_floor_shadow_fades_with_alpha():
    """Avec floor_y, l'ombre de contact suit l'alpha de l'élément (pas de disparition d'un coup)."""
    def darkness(alpha, item):
        img = np.ones((core.H, core.W, 3), np.float32)
        cam = motion.look_at_cam((0, -900, -600), (0, 400, 2000), 1500)
        stage.render(img, cam, [item(alpha)], floor_y=600)
        # zone du sol sous l'élément, sous son bord inférieur : seule l'ombre y assombrit le fond
        uv, _ = cam.project(np.array([[0, 600, 2000.0]]))
        x, y = int(uv[0, 0]), int(uv[0, 1])
        return float((1 - img[y + 25:y + 60, x - 120:x + 120]).sum())

    items = [lambda a: stage.Plane(tex=_white_plane(400, 200), center=(0, 300, 2000), size_w=500, alpha=a, shadow=0.6),
             lambda a: stage.PhoneItem("capture", (0, 0, 2000), 0, 0, 0, alpha=a, shadow=0.6)]
    for item in items:
        full, half, faint = darkness(1.0, item), darkness(0.5, item), darkness(0.01, item)
        assert full > 0
        assert abs(half / full - 0.5) < 0.1
        assert faint / full < 0.03
