"""Rendu du film v3 en deux moitiés parallèles puis assemblage avec la bande son.

    python -m light.render part 0|1      → out/light/part0.mp4 / part1.mp4
    python -m light.render sound         → out/light/master.wav
    python -m light.render assemble      → out/light/modern-downloader-v3-1080p.mp4
"""
import subprocess
import sys
import time
from pathlib import Path

from . import beats as B

OUT = B.ROOT / "out" / "light"
FINAL = OUT / "modern-downloader-v3-1080p.mp4"
FF = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "1920x1080", "-r", "30",
      "-i", "-", "-c:v", "libx264", "-preset", "medium", "-crf", "16", "-pix_fmt", "yuv420p", "-g", "30"]


def part(k: int):
    from . import film, style
    OUT.mkdir(parents=True, exist_ok=True)
    half = B.FRAMES // 2
    a, b = (0, half) if k == 0 else (half, B.FRAMES)
    tmp, fin = OUT / f"part{k}.tmp.mp4", OUT / f"part{k}.mp4"
    p = subprocess.Popen(FF + [str(tmp)], stdin=subprocess.PIPE)
    t0 = time.time()
    for f in range(a, b):
        p.stdin.write(style.finish(film.render(f), f).tobytes())
        if (f - a) % 60 == 59:
            print(f"part{k} {f - a + 1}/{b - a} {(time.time() - t0) / (f - a + 1):.2f}s/img", flush=True)
    p.stdin.close()
    if p.wait():
        raise RuntimeError("ffmpeg")
    tmp.replace(fin)


def assemble():
    lst = OUT / "list.txt"
    lst.write_text(f"file '{(OUT / 'part0.mp4').resolve()}'\nfile '{(OUT / 'part1.mp4').resolve()}'\n")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(lst), "-i",
                    str(OUT / "master.wav"), "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-c:a", "aac", "-b:a",
                    "320k", "-shortest", "-movflags", "+faststart", str(FINAL)], check=True)
    print(FINAL)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "part":
        part(int(sys.argv[2]))
    elif cmd == "sound":
        from .sound import main
        main()
    elif cmd == "assemble":
        assemble()
