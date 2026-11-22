"""Assemblage : concat des scènes (sans réencodage) + master audio → film final.

    python -m film.assemble
"""
import json
import subprocess
from pathlib import Path

from . import config
from .audio import measure
from .timeline import SCENES

FINAL = config.OUT / ("modern-downloader-tiktok-1080x1920.mp4" if config.VERTICAL else "modern-downloader-launch-1080p.mp4")


def assemble(scenes_dir: Path = config.OUT / "scenes", master: Path = config.MASTER,
             final: Path = FINAL) -> Path:
    lst = scenes_dir / "list.txt"
    lst.write_text("".join(f"file '{(scenes_dir / (s.name + '.mp4')).resolve()}'\n" for s in SCENES))
    video = scenes_dir / "video.mp4"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(lst),
                    "-c", "copy", str(video)], check=True)
    tmp = final.with_suffix(".tmp.mp4")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(video), "-i", str(master),
                    "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-c:a", "aac", "-b:a", "320k",
                    "-ar", "48000", "-shortest", "-movflags", "+faststart", str(tmp)], check=True)
    tmp.replace(final)
    return final


def probe(path: Path) -> dict:
    out = subprocess.run(["ffprobe", "-v", "error", "-count_frames", "-show_streams", "-show_format",
                          "-of", "json", str(path)], capture_output=True, text=True, check=True).stdout
    js = json.loads(out)
    v = next(s for s in js["streams"] if s["codec_type"] == "video")
    a = next(s for s in js["streams"] if s["codec_type"] == "audio")
    return {
        "video": {"width": v["width"], "height": v["height"], "r_frame_rate": v["r_frame_rate"],
                  "nb_frames": int(v.get("nb_read_frames") or v["nb_frames"])},
        "audio": {"sample_rate": int(a["sample_rate"]), "channels": a["channels"]},
        "duration": float(js["format"]["duration"]),
    }


SHEET_FRAMES = [30, 105, 165, 225, 285, 345, 405, 465, 525, 585, 690, 810]


def contact_sheet(video: Path = FINAL, out: Path = config.OUT / "contact_sheet.jpg",
                  frames: list[int] = SHEET_FRAMES, cols: int = 4, tile: tuple[int, int] = (480, 270)) -> Path:
    """Planche-contact : une image du film final à chacun des instants clés."""
    import cv2
    import numpy as np
    cap = cv2.VideoCapture(str(video))
    tiles = []
    for f in frames:
        cap.set(cv2.CAP_PROP_POS_FRAMES, f)
        ok, img = cap.read()
        tiles.append(cv2.resize(img if ok else np.zeros((tile[1], tile[0], 3), np.uint8), tile, interpolation=cv2.INTER_AREA))
    while len(tiles) % cols:
        tiles.append(np.zeros_like(tiles[0]))
    sheet = np.vstack([np.hstack(tiles[i:i + cols]) for i in range(0, len(tiles), cols)])
    cv2.imwrite(str(out), sheet, [cv2.IMWRITE_JPEG_QUALITY, 90])
    return out


def ebur128(path: Path) -> tuple[float, float]:
    return measure(path)


if __name__ == "__main__":
    print(assemble())
    print(contact_sheet())
