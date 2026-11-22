"""Concatène les scènes, masterise la bande son (-14 LUFS, crête -1,5 dBTP) et muxe le film final."""
import json
import re
import subprocess
from pathlib import Path

from .render import OUT
from .timeline import SCENES

FINAL = OUT / "modern-downloader-motion-1080p.mp4"


def master(src: Path = OUT / "music.wav", dst: Path = OUT / "master.wav") -> Path:
    r = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(src), "-af",
                        "loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json", "-f", "null", "-"],
                       capture_output=True, text=True)
    m = json.loads(re.findall(r"\{[^{}]*\}", r.stderr)[-1])
    af = (f"loudnorm=I=-14:TP=-1.5:LRA=11:measured_I={m['input_i']}:measured_TP={m['input_tp']}:"
          f"measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true,"
          "lowpass=f=17500,alimiter=limit=0.6:level=false")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(src), "-af", af, "-ar", "48000", str(dst)], check=True)
    return dst


def assemble() -> Path:
    lst = OUT / "list.txt"
    lst.write_text("".join(f"file '{(OUT / (s.name + '.mp4')).resolve()}'\n" for s in SCENES))
    video = OUT / "video.mp4"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy",
                    str(video)], check=True)
    tmp = FINAL.with_suffix(".tmp.mp4")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(video), "-i", str(OUT / "master.wav"), "-map", "0:v",
                    "-map", "1:a", "-c:v", "copy", "-c:a", "aac", "-b:a", "320k", "-shortest", "-movflags",
                    "+faststart", str(tmp)], check=True)
    tmp.replace(FINAL)
    return FINAL


def loudness(path: Path) -> tuple[float, float]:
    r = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(path), "-af", "ebur128=peak=true", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
    i = float(re.findall(r"I:\s+(-?[\d.]+) LUFS", r)[-1])
    tp = float(re.findall(r"Peak:\s+(-?[\d.]+) dBFS", r)[-1])
    return i, tp


if __name__ == "__main__":
    print(master())
    print(assemble())
    print(loudness(FINAL))
