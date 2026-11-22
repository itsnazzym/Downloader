import numpy as np
from scipy.io import wavfile
from tests.conftest import make_click_track
from film.music import align_music, splice_bed

def test_align_synthetic_click(tmp_path):
    src = make_click_track(tmp_path / "c.wav", bpm=118, offset=0.13, seconds=32)
    info = align_music(src, tmp_path / "o.wav")
    assert abs(info["tempo_in"] - 118) < 1.0
    sr, y = wavfile.read(tmp_path / "o.wav"); assert sr == 48000 and len(y) == 30 * 48000
    env = np.abs(y[:, 0]).astype(float)
    peaks = [np.argmax(env[int(k * 24000) - 2400 : int(k * 24000) + 2400]) - 2400 for k in range(2, 50)]
    assert np.median(np.abs(peaks)) < 480           # < 10 ms

def test_splice_bed_moves_hits(tmp_path):
    # un clic par 4 s à 1,55 + 4k : après montage, des clics à 3,5 / 5,5 / 9,5 s
    sr = 48000; y = np.zeros(31 * sr, np.float32)
    for t in (1.55, 5.55, 9.55, 13.55):
        y[int(t * sr):int(t * sr) + 200] = 0.9
    wavfile.write(tmp_path / "m.wav", sr, np.stack([y, y], 1))
    splice_bed(tmp_path / "m.wav", tmp_path / "o.wav", hit_src=1.55, hit_dst=3.5, rejoin=5.5)
    _, o = wavfile.read(tmp_path / "o.wav"); o = np.abs(o[:, 0].astype(float))
    for t in (3.5, 5.5, 9.5):
        w = o[int((t - 0.1) * sr):int((t + 0.1) * sr)]
        assert w.max() > 0.5 * o.max(), t
    assert len(o) == 30 * sr

def test_music_cli_builds_spliced_bed(tmp_path):
    import subprocess, sys
    sr = 48000; y = np.zeros(31 * sr, np.float32)
    for k in range(62):                       # pulsation à 120 BPM
        y[int(k * 0.5 * sr):int(k * 0.5 * sr) + 200] = 0.2
    for t in (1.5, 5.5, 9.5):                 # gros impacts
        y[int(t * sr):int(t * sr) + 200] = 0.9
    wavfile.write(tmp_path / "raw.wav", sr, np.stack([y, y], 1))
    subprocess.run([sys.executable, "-m", "film.music", str(tmp_path / "raw.wav"), str(tmp_path / "bed.wav")], check=True)
    _, o = wavfile.read(tmp_path / "bed.wav"); o = np.abs(o[:, 0].astype(float))
    assert o[int(3.4 * sr):int(3.6 * sr)].max() > 0.5 * o.max()   # 1er impact déplacé à 3,5 s
