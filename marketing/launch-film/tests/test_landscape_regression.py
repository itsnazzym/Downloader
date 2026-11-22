"""La version horizontale ne doit pas changer quand on ajoute la version verticale (empreintes d'images exactes)."""
import hashlib
import json
from pathlib import Path

import numpy as np
import pytest

from film import config
from film.scenes import REGISTRY

BASE = json.loads((Path(__file__).parent / "landscape_baseline.json").read_text())
pytestmark = pytest.mark.skipif(config.VERTICAL, reason="référence horizontale")


@pytest.mark.parametrize("key", sorted(BASE))
def test_landscape_frame_unchanged(key):
    name, f = key.split(":")
    a = REGISTRY[name](int(f))
    assert hashlib.sha1((a * 255 + 0.5).astype(np.uint8).tobytes()).hexdigest() == BASE[key]
