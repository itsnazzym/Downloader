"""Recherche et téléchargement de sons sous licence libre via l'API Openverse (api.openverse.org).

    python tools/openverse.py search "whoosh" --n 10            # liste titres, durées, licences
    python tools/openverse.py get "deep whoosh" --n 3 -o assets/sfx/   # télécharge + ATTRIBUTION.csv

Par défaut seules les licences utilisables commercialement sont gardées (CC0, CC BY, CC BY-SA, PDM).
Les sons CC BY / BY-SA doivent être crédités : le fichier ATTRIBUTION.csv contient tout le nécessaire.
"""
import argparse
import csv
import json
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://api.openverse.org/v1/audio/"
UA = {"User-Agent": "modern-downloader-launch-film/1.0"}


def search(q: str, n: int = 20, license_type: str = "commercial", max_ms: int | None = None, source: str | None = None):
    params = {"q": q, "page_size": min(n, 20), "license_type": license_type}
    if source:
        params["source"] = source
    req = urllib.request.Request(API + "?" + urllib.parse.urlencode(params), headers=UA)
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)
    return parse(data, max_ms)[:n]


def parse(data: dict, max_ms: int | None = None) -> list[dict]:
    out = []
    for r in data.get("results", []):
        if max_ms and (r.get("duration") or 0) > max_ms:
            continue
        out.append({"id": r["id"], "title": r.get("title", ""), "creator": r.get("creator", ""),
                    "license": r.get("license", ""), "license_version": r.get("license_version", ""),
                    "license_url": r.get("license_url", ""), "source": r.get("source", ""),
                    "landing": r.get("foreign_landing_url", ""), "url": r["url"],
                    "duration_s": round((r.get("duration") or 0) / 1000, 2), "filetype": r.get("filetype", "")})
    return out


def slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")[:48] or "son"


def download(items: list[dict], out: Path) -> list[Path]:
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for it in items:
        p = out / f"{slug(it['title'])}-{it['id'][:8]}.{it['filetype'] or 'mp3'}"
        with urllib.request.urlopen(urllib.request.Request(it["url"], headers=UA), timeout=60) as r:
            p.write_bytes(r.read())
        paths.append(p)
    write_attribution(items, paths, out / "ATTRIBUTION.csv")
    return paths


def write_attribution(items, paths, csv_path: Path):
    new = not csv_path.exists()
    with csv_path.open("a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["fichier", "titre", "auteur", "licence", "lien licence", "source", "page"])
        for it, p in zip(items, paths):
            w.writerow([p.name, it["title"], it["creator"], f"{it['license']} {it['license_version']}".strip(),
                        it["license_url"], it["source"], it["landing"]])


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["search", "get"])
    ap.add_argument("query")
    ap.add_argument("--n", type=int, default=10)
    ap.add_argument("--max-s", type=float)
    ap.add_argument("--source", help="ex. freesound, jamendo, wikimedia_audio")
    ap.add_argument("--all-licenses", action="store_true", help="inclure les licences non commerciales")
    ap.add_argument("-o", "--out", default="assets/sfx")
    a = ap.parse_args(argv)
    items = search(a.query, a.n, "all" if a.all_licenses else "commercial",
                   int(a.max_s * 1000) if a.max_s else None, a.source)
    for it in items:
        print(f"{it['duration_s']:6.2f}s  {it['license']:<6} {it['title'][:60]:<60} {it['creator']}")
    if a.cmd == "get":
        for p in download(items, Path(a.out)):
            print(p)


if __name__ == "__main__":
    sys.exit(main())
