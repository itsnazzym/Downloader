import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("ov", Path(__file__).parents[1] / "tools" / "openverse.py")
ov = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ov)

SAMPLE = {"results": [
    {"id": "abc12345-x", "title": "Deep Whoosh #1", "creator": "Kinoton", "license": "cc0", "license_version": "1.0",
     "license_url": "https://creativecommons.org/publicdomain/zero/1.0/", "source": "freesound",
     "foreign_landing_url": "https://freesound.org/s/351256", "url": "https://cdn.freesound.org/x.mp3",
     "duration": 3155, "filetype": "mp3"},
    {"id": "def", "title": "Long ambience", "license": "by", "url": "u", "duration": 60000, "filetype": "wav"}]}


def test_parse_keeps_licence_fields_and_filters_long_sounds():
    items = ov.parse(SAMPLE, max_ms=10000)
    assert len(items) == 1 and items[0]["license"] == "cc0" and items[0]["duration_s"] == 3.15


def test_attribution_csv_has_one_row_per_file(tmp_path):
    items = ov.parse(SAMPLE)
    ov.write_attribution(items, [tmp_path / "a.mp3", tmp_path / "b.wav"], tmp_path / "ATTRIBUTION.csv")
    rows = (tmp_path / "ATTRIBUTION.csv").read_text(encoding="utf-8").splitlines()
    assert len(rows) == 3 and "Kinoton" in rows[1]
