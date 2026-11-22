"""Rendu du film v4 (60 i/s) en tranches parallèles puis assemblage avec la bande son v4.

    python3 -m light.render4 part K N [f0 f1]  → out/light4/partK.mp4 (tranche K sur N ; f0 f1 : sous-intervalle d'images)
    python3 -m light.render4 sound             → out/light4/master.wav (light.sound4.main)
    python3 -m light.render4 assemble [N]      → out/light4/modern-downloader-v4-1080p60.mp4
    python3 -m light.render4 stills t1,t2,...  → out/light4/stills/tXX.XX.jpg
"""
import subprocess
import sys
import time

from . import beats as B

OUT = B.ROOT / "out" / "light4"
FINAL = OUT / "modern-downloader-v4-1080p60.mp4"
FPS = 60
FRAMES = int(round(B.DUR * FPS))   # 1890
FF = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "1920x1080", "-r", str(FPS),
      "-i", "-", "-c:v", "libx264", "-preset", "medium", "-crf", "16", "-pix_fmt", "yuv420p", "-g", str(FPS)]


def bounds(k: int, n: int) -> tuple[int, int]:
    return FRAMES * k // n, FRAMES * (k + 1) // n


def part(k: int, n: int, f0: int | None = None, f1: int | None = None):
    from . import film4, style
    OUT.mkdir(parents=True, exist_ok=True)
    a, b = bounds(k, n)
    if f0 is not None:
        a, b = max(a, f0), min(b, f1)
    tmp, fin = OUT / f"part{k}.tmp.mp4", OUT / f"part{k}.mp4"
    p = subprocess.Popen(FF + [str(tmp)], stdin=subprocess.PIPE)
    t0 = time.time()
    for f in range(a, b):
        p.stdin.write(style.finish(film4.render(f / FPS), f).tobytes())
        if (f - a) % 60 == 59:
            print(f"part{k} {f - a + 1}/{b - a} {(time.time() - t0) / (f - a + 1):.3f}s/img", flush=True)
    p.stdin.close()
    if p.wait():
        raise RuntimeError("ffmpeg")
    tmp.replace(fin)
    print(f"part{k}: {b - a} images en {time.time() - t0:.1f}s → {fin}")


def assemble(n: int = 2):
    lst = OUT / "list.txt"
    lst.write_text("".join(f"file '{(OUT / f'part{k}.mp4').resolve()}'\n" for k in range(n)))
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(lst), "-i",
                    str(OUT / "master.wav"), "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-c:a", "aac", "-b:a",
                    "320k", "-shortest", "-movflags", "+faststart", str(FINAL)], check=True)
    print(FINAL)


def stills(ts: list[float]):
    import cv2

    from . import film4, style
    d = OUT / "stills"
    d.mkdir(parents=True, exist_ok=True)
    for t in ts:
        f = int(round(t * FPS))
        t0 = time.time()
        img = style.finish(film4.render(t), f)
        path = d / f"t{t:05.2f}.jpg"
        cv2.imwrite(str(path), img[..., ::-1], [cv2.IMWRITE_JPEG_QUALITY, 92])
        print(f"{path} ({time.time() - t0:.2f}s)", flush=True)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "part":
        extra = [int(x) for x in sys.argv[4:6]]
        part(int(sys.argv[2]), int(sys.argv[3]), *extra)
    elif cmd == "sound":
        from .sound4 import main
        main()
    elif cmd == "assemble":
        assemble(int(sys.argv[2]) if len(sys.argv) > 2 else 2)
    elif cmd == "stills":
        stills([float(x) for x in sys.argv[2].split(",")])
    else:
        raise SystemExit(__doc__)
