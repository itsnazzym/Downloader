from film.timeline import SCENES, CUES, beat, scene_at

def test_scenes_contiguous():
    assert SCENES[0].start == 0 and SCENES[-1].end == 900
    assert all(a.end == b.start for a, b in zip(SCENES, SCENES[1:]))
    assert [s.name for s in SCENES] == ["s1", "s2", "s3", "s4", "s5"]

def test_cues_on_beat_grid():
    assert all(c.frame % 15 == 0 for c in CUES if c.kind != "tick")
    assert all(0 <= c.frame < 900 for c in CUES)

def test_tick_run():
    assert [c.frame for c in CUES if c.kind == "tick"] == list(range(330, 387, 3))

def test_beat_and_scene_at():
    assert beat(7) == 105 and scene_at(105).name == "s1" and scene_at(780).name == "s5"
