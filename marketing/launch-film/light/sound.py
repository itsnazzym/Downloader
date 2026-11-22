"""Bande son v3 : « Future Bass Lite » (fin du morceau, 30 s) + effets earshot discrets placés sur les mêmes coups
que l'image (mêmes appels à film.pick que les scènes)."""
import json

import librosa
import numpy as np
from scipy.signal import fftconvolve

from earshot.forge import bank, kit

from reel import music as synth

from . import beats as B
from . import film

SR = 48000
N = int(B.DUR * SR)
KIT = B.ROOT / "assets" / "kit"
OUT = B.ROOT / "out" / "light"


def music() -> np.ndarray:
    y, _ = librosa.load(B.TRACK, sr=SR, mono=False, offset=B.OFFSET, duration=B.MUSIC_LEN)
    y = y.T.astype(np.float64)
    out = np.zeros((N, 2))
    out[: len(y)] = y
    f = int(0.01 * SR)
    out[:f] *= np.linspace(0, 1, f)[:, None]
    # queue : réverbération des 250 dernières ms, le morceau finissant net
    end = len(y)
    last = y[end - int(0.25 * SR):end].mean(1)
    tail = fftconvolve(last, synth.reverb_ir(2.2, 4000)[:, 0])
    tail = tail / (np.abs(tail).max() + 1e-9) * np.abs(last).max() * 0.6
    n = min(len(tail), N - end + int(0.25 * SR))
    st = end - int(0.25 * SR)
    out[st:st + n] += np.c_[tail[:n], tail[:n]] * np.linspace(1, 0, n)[:, None] ** 2
    return out


class Mix:
    def __init__(self, bed):
        self.lock = kit.render(str(KIT / "kit.json"), str(KIT / "takes"))
        self.bed_path = OUT / "bed.wav"
        OUT.mkdir(parents=True, exist_ok=True)
        synth.write_wav(self.bed_path, bed)
        self.fx = np.zeros((N, 2))
        self.n = {}
        self.log = []

    def role(self, name, t, db=0.0):
        r = self.lock["roles"][name]
        i = self.n.get(name, 0)
        self.n[name] = i + 1
        take = r["takes"][i % len(r["takes"])]
        x, _ = librosa.load(str(KIT / "takes" / take["file"]), sr=SR, mono=False)
        x = x.T if x.ndim == 2 else np.c_[x, x]
        start = kit.place(take, r, t)
        g = kit.gain_db(take, r, kit.bed_level(str(self.bed_path), t)) + db
        self._add(x, start, g)
        self.log.append((round(t, 3), name, round(g, 1)))

    def foley(self, t, bed, bed_db, p=0.0):
        """souffle enregistré (light.foley) : son pic tombe juste après le coup t."""
        from . import foley as F
        i = self.n.get("foley", 0)
        self.n["foley"] = i + 1
        x, pk = F.take(i)
        g = F.gain(x, bed, t, bed_db)
        self._add(F.pan(x, p), t + F.OFFSET - pk, g)
        self.log.append((round(t, 3), "foley", round(g, 1)))

    def sound(self, sid, t, db, **kw):
        y, _ = bank.render(sid, **kw)
        y = np.asarray(y, np.float64)
        y = y.T if y.ndim == 2 and y.shape[0] == 2 else (np.c_[y, y] if y.ndim == 1 else y)
        self._add(y, t, db)
        self.log.append((round(t, 3), sid, db))

    def _add(self, x, t, db):
        i = int(round(t * SR))
        x = x * 10 ** (db / 20)
        s0 = max(0, -i)
        j = min(N, i + len(x))
        if j > max(0, i):
            self.fx[max(0, i):j] += x[s0:s0 + j - max(0, i)]


def _v4_transitions(m, bed):
    """v4 : un vrai souffle sur chaque transition dessinée, pic sur la coupe (film4.TRANS)."""
    from . import foley as F
    from .film4 import TRANS
    for k, tr in enumerate(TRANS[1:]):          # intro → hero : déjà la montée et l'impact du drop
        x, pk = F.whip(k)
        g = F.gain(x, bed, tr.cut, 4.0) - 1.0
        m._add(F.pan(x, (0.3, -0.3)[k % 2]), tr.cut - pk, g)
        m.log.append((round(tr.cut, 3), "whip", round(g, 1)))


def _v4_events(m, bed):
    """v4 : un son par vrai événement de l'image (film4.BEATS), rien sur les autres coups."""
    from .film4 import BEATS
    h, q, w, p, s = (BEATS[k] for k in ("hero", "quality", "browser", "progress", "send"))
    m.foley(h[0], bed, 5.0, -0.2)            # « en un tap. » se pose
    m.foley(h[1], bed, 3.0, 0.3)             # la carte « Télécharger » se décolle
    m.role("land.light", h[2], 0)            # tap sur « Télécharger »
    m.role("land.light", q[0], 0)            # tap sur la tuile TapLoad
    m.role("click.confirm", q[1], -3)        # notification « Téléchargement lancé »
    m.foley(q[2], bed, 2.0, 0.3)             # la notification remonte
    m.role("tick", w[0], 0)                  # la sélection passe à 1080p
    m.role("tick", w[1], 0)                  # retour à Meilleure qualité
    m.foley(w[2], bed, 4.0, 0.0)             # la vue éclate
    m.role("land", w[3], -4)                 # les couches se rangent
    for t in p[:3]:
        m.role("tick.crisp", t, 2)           # paliers de progression
    m.role("bell", p[3], -2)                 # 100 %, téléchargement terminé
    for k in (0, 2):
        m.role("land.light", s[k], 0)        # tap sur l'appareil
        m.foley(s[k] + 0.02, bed, 3.0, 0.4)  # le fichier part vers l'autre téléphone
        m.role("land", s[k + 1], -4)         # il se range dans la bibliothèque


def build(real_pops=False):
    """real_pops : les « pop » synthétiques sont remplacés par des souffles enregistrés (v4)."""
    bed = music()
    m = Mix(bed)
    P, pick = film.P, film.pick
    S = dict((n, (a, b)) for n, a, b in film.SECTIONS)
    a, b = S["intro"]
    for k, t in enumerate(pick(0.3, b - 0.15, 3, 0.6, 0.8)):
        if real_pops:
            m.foley(t, bed, 7.0, (-0.35, 0.35, 0.0)[k])
        else:
            m.role("pop", t, -2)
    m.sound("reverse_swell/dark", P[0] - 0.57, -10)
    m.sound("pro_impact/deep", P[0] - 0.01, -10)
    if real_pops:
        _v4_transitions(m, bed)
    else:
        for t in P[1:8]:
            m.role("whoosh.short", t - 0.03, -3)
    if real_pops:
        _v4_events(m, bed)
    else:
        a, b = S["hero"]
        for t in pick(a + 0.2, b - 0.2, 4, 0.35)[:3]:
            m.role("land", t, -4)
        a, b = S["quality"]
        for k, t in enumerate(pick(a + 0.15, b - 0.15, 6, 0.3)):
            if real_pops:
                m.foley(t, bed, 3.5, 0.25 * (-1) ** k)
            else:
                m.role("pop", t, -1)
        a, b = S["browser"]
        for t in pick(a + 0.15, b - 0.2, 4, 0.4):
            m.role("snap", t, -2)
        a, b = S["progress"]
        ev = pick(a + 0.1, b - 0.1, 6, 0.3)
        for t in ev:
            m.role("tick.crisp", t, 2)
        m.role("bell", ev[-1], -2)
        a, b = S["send"]
        for t in pick(a + 0.1, b - 0.3, 7, 0.28):
            m.role("tick", t, 0)
            m.role("land.light", t + 0.26, 0)
    a, b = S["montage"]
    if real_pops:
        from .film4 import EV
        mont, words, wall = [EV["montage"][i] for i in (0, 1, 3)], EV["words"], EV["wall"][::2]    # v10 : exactement les coups de l'image
    else:
        mont, words, wall = pick(a + 0.3, b - 0.1, 7, 0.3), None, None
    for t in mont:
        m.role("snap", t, -3)              # v4 : un cran du carrousel par coup
    a, b = S["words"]
    for t in (words if real_pops else pick(a + 0.25, b - 0.1, 7, 0.3)):
        m.role("land", t, -5)
    a, b = S["wall"]
    for k, t in enumerate(wall if real_pops else pick(a + 0.15, b - 0.4, 8, 0.25)):
        if real_pops:
            m.foley(t, bed, 2.0, 0.3 * (-1) ** k)
        else:
            m.role("pop", t, -4)
    m.sound("pro_impact/air", B.MUSIC_LEN - 0.02, -9)
    m.sound("pro_logo_sting/taps_tone", B.MUSIC_LEN + 0.02, -12)
    mix = bed + m.fx
    fade = np.ones(N)
    fade[-int(0.4 * SR):] = np.linspace(1, 0, int(0.4 * SR))
    return (mix * fade[:, None]).astype(np.float32), m.log


def main():
    from reel.assemble import master
    mix, log = build()
    raw = synth.write_wav(OUT / "mix.wav", mix)
    master(raw, OUT / "master.wav")
    (OUT / "sfx_log.json").write_text(json.dumps(log))
    print(OUT / "master.wav", len(log), "effets")
