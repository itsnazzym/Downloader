"""Rendu du showreel : une scène → un mp4.  python -m reel.render --scene boot|...|all [--stills 0,30]"""
import argparse
import importlib
import subprocess
import sys
import time
from pathlib import Path

import cv2

from .core import H, W, finish
from .timeline import SCENES, scene

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "out" / "reel"
FFMPEG = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", "30",
          "-i", "-", "-c:v", "libx264", "-preset", "medium", "-crf", "15", "-pix_fmt", "yuv420p", "-g", "30"]


def frame(name: str, f: int):
    mod = importlib.import_module(f"reel.sc_{name}")
    return finish(mod.render(f), scene(name).start + f)


def run(name: str) -> Path:
    sc = scene(name)
    OUT.mkdir(parents=True, exist_ok=True)
    tmp, final = OUT / f"{name}.tmp.mp4", OUT / f"{name}.mp4"
    proc = subprocess.Popen(FFMPEG + [str(tmp)], stdin=subprocess.PIPE)
    t0 = time.time()
    n = sc.end - sc.start
    try:
        for f in range(n):
            proc.stdin.write(frame(name, f).tobytes())
            if f % 30 == 29:
                print(f"{name} {f + 1}/{n} {(time.time() - t0) / (f + 1):.2f}s/img", flush=True)
    finally:
        proc.stdin.close()
        rc = proc.wait()
    if rc:
        raise RuntimeError(f"ffmpeg {rc} ({name})")
    tmp.replace(final)
    return final


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--scene", required=True)
    ap.add_argument("--stills")
    a = ap.parse_args(argv)
    names = [s.name for s in SCENES] if a.scene == "all" else a.scene.split(",")
    for n in names:
        if a.stills:
            for f in (int(x) for x in a.stills.split(",")):
                p = OUT / "stills" / f"{n}_{f:03d}.jpg"
                p.parent.mkdir(parents=True, exist_ok=True)
                cv2.imwrite(str(p), frame(n, f)[..., ::-1], [cv2.IMWRITE_JPEG_QUALITY, 92])
                print(p)
        else:
            print(run(n), flush=True)


if __name__ == "__main__":
    sys.exit(main())
