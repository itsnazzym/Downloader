"""Version verticale TikTok : formats, zones sûres, aucun contenu inventé. Tourne en sous-processus (MDL_FORMAT lu à l'import)."""
import json
import os
import subprocess
import sys

CODE = r'''
import json, numpy as np
from film import config
from film.scenes import REGISTRY
out = {"wh": [config.W, config.H], "frames": {}}
for key in ("s1:105", "s2:110", "s2:60", "s3:110", "s3:60", "s4:60", "s4:180", "s5:70", "s5:100"):
    n, f = key.split(":")
    img = REGISTRY[n](int(f))
    assert img.shape == (1920, 1080, 3) and np.isfinite(img).all()
    bright = img.max(axis=2) > 0.5
    out["frames"][key] = {"top": int(bright[:160].sum()), "bottom": int(bright[1540:].sum()),
                          "right": int(bright[:, 1000:].sum())}
print(json.dumps(out))
'''


def _run():
    env = dict(os.environ, MDL_FORMAT="vertical")
    r = subprocess.run([sys.executable, "-c", CODE], capture_output=True, text=True, env=env,
                       cwd=os.path.dirname(os.path.dirname(__file__)))
    assert r.returncode == 0, r.stderr[-800:]
    return json.loads(r.stdout.strip().splitlines()[-1])


def test_vertical_frames_have_1080x1920_and_respect_tiktok_safe_zones():
    res = _run()
    assert res["wh"] == [1080, 1920]
    for key, z in res["frames"].items():
        # haut (nom du compte, onglets), bas (légende, boutons) et bord droit sont masqués par l'interface TikTok
        assert z["top"] < 300 and z["bottom"] < 300 and z["right"] < 3000, (key, z)
