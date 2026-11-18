"""Fetch credited, freely licensed stills for the offline Windows showcase.

Run explicitly when refreshing the checked-in demo assets. The desktop demo
itself never runs this script or contacts Wikimedia.
"""

from pathlib import Path
import json
import urllib.parse
import urllib.request


FILES = {
    "sintel.jpg": "File:Sintel poster.jpg",
    "tears-of-steel.jpg": "File:Tears of Steel frame 09 1a.jpg",
    "elephants-dream.jpg": "File:ElephantsDreamPoster.jpg",
    "big-buck-bunny.png": "File:Big.Buck.Bunny.-.Bunny.with.Bow.png",
}
DEST = Path(__file__).resolve().parents[1] / "assets" / "showcase"


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    params = {
        "action": "query",
        "format": "json",
        "prop": "imageinfo",
        "iiprop": "url",
        "iiurlwidth": "640",
        "titles": "|".join(FILES.values()),
    }
    api = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)
    headers = {"User-Agent": "ModernDownloaderShowcase/1.0 (https://github.com/itsnazzym/Downloader)"}
    with urllib.request.urlopen(urllib.request.Request(api, headers=headers)) as response:
        pages = json.load(response)["query"]["pages"].values()
    by_title = {page["title"]: page["imageinfo"][0]["thumburl"] for page in pages}
    for filename, title in FILES.items():
        with urllib.request.urlopen(urllib.request.Request(by_title[title], headers=headers)) as response:
            data = response.read()
        (DEST / filename).write_bytes(data)
        print(f"{filename}: {len(data)} bytes")


if __name__ == "__main__":
    main()
