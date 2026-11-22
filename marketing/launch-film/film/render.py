"""Rendu : une scène → un mp4 (via ffmpeg), ou des images fixes JPEG pour contrôle.

    python -m film.render --scene s1|s2|s3|s4|s5|all [--stills 0,60,105] [--frames A:B]
"""
import argparse
import hashlib
import json
import subprocess
import sys
import time
from pathlib import Path

import cv2
import numpy as np

from . import config
from .fx import finish
from .scenes import REGISTRY
from .timeline import SCENES

FFMPEG = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
          "-s", f"{config.W}x{config.H}", "-r", str(config.FPS), "-i", "-",
          "-c:v", "libx264", "-preset", "veryfast", "-crf", "16", "-pix_fmt", "yuv420p",
          "-g", "30", "-bf", "2"]


def _scene(name: str):
    return next(s for s in SCENES if s.name == name)


def frame_rgb(name: str, f: int) -> np.ndarray:
    sc = _scene(name)
    return finish(REGISTRY[name](f), sc.start + f)


def source_stamp() -> str:
    """Empreinte de tout ce qui détermine l'image : code, plates, captures et marque."""
    h = hashlib.sha1()
    root = Path(__file__).resolve().parent
    for p in sorted(root.rglob("*.py")):
        h.update(p.name.encode() + p.read_bytes())
    for p in sorted(p for d in ("plates", "screens", "brand") for p in (config.ASSETS / d).rglob("*") if p.is_file()):
        st = p.stat()
        h.update(f"{p.name}{st.st_size}{st.st_mtime_ns}".encode())
    return h.hexdigest()


def run_scene(name: str, out_dir: Path = config.OUT / "scenes",
              frames: tuple[int, int] | None = None, force: bool = False) -> Path:
    """Rend une scène en mp4. Une scène déjà à jour (même empreinte) n'est pas refaite, sauf force=True."""
    sc = _scene(name)
    a, b = frames or (0, sc.end - sc.start)
    out_dir.mkdir(parents=True, exist_ok=True)
    tmp, final = out_dir / f"{name}.tmp.mp4", out_dir / f"{name}.mp4"
    stamp = out_dir / f"{name}.stamp"
    full = frames is None
    if full and not force and final.exists() and stamp.exists() and stamp.read_text() == source_stamp():
        print(f"{name} à jour, rien à refaire (--force pour rendre à nouveau)", flush=True)
        return final
    if full:
        stamp.unlink(missing_ok=True)
    proc = subprocess.Popen(FFMPEG + [str(tmp)], stdin=subprocess.PIPE)
    t0 = time.time()
    try:
        for f in range(a, b):
            proc.stdin.write(frame_rgb(name, f).tobytes())
            if (f - a) % 30 == 29:
                print(f"{name} {f + 1 - a}/{b - a}  {(time.time() - t0) / (f + 1 - a):.2f}s/img", flush=True)
    finally:
        proc.stdin.close()
        rc = proc.wait()
    if rc != 0:
        raise RuntimeError(f"ffmpeg a échoué ({rc}) pour {name}")
    tmp.replace(final)
    if full:
        stamp.write_text(source_stamp())
    return final


def write_stills(name: str, frames: list[int], out_dir: Path = config.OUT / "stills") -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for f in frames:
        p = out_dir / f"{name}_f{f:03d}.jpg"
        cv2.imwrite(str(p), frame_rgb(name, f)[..., ::-1], [cv2.IMWRITE_JPEG_QUALITY, 92])
        paths.append(p)
    return paths


def probe_frames(path: Path) -> int:
    out = subprocess.run(["ffprobe", "-v", "error", "-count_frames", "-select_streams", "v:0",
                          "-show_entries", "stream=nb_read_frames", "-of", "json", str(path)],
                         capture_output=True, text=True, check=True).stdout
    return int(json.loads(out)["streams"][0]["nb_read_frames"])


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--scene", required=True)
    ap.add_argument("--stills")
    ap.add_argument("--frames")
    ap.add_argument("--force", action="store_true", help="rendre même si la scène est à jour")
    a = ap.parse_args(argv)
    names = [s.name for s in SCENES] if a.scene == "all" else [a.scene]
    for n in names:
        if a.stills:
            for p in write_stills(n, [int(x) for x in a.stills.split(",")]):
                print(p)
        else:
            fr = tuple(int(x) for x in a.frames.split(":")) if a.frames else None
            print(run_scene(n, frames=fr, force=a.force))


if __name__ == "__main__":
    sys.exit(main())
