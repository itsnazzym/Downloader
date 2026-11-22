from reel.timeline import SCENES, TOTAL, BEAT, DROPS, impact


def test_scenes_are_contiguous_and_cover_40_seconds():
    assert SCENES[0].start == 0 and SCENES[-1].end == TOTAL == 1200
    for a, b in zip(SCENES, SCENES[1:]):
        assert a.end == b.start


def test_every_scene_boundary_falls_on_a_beat():
    assert all(s.start % BEAT == 0 for s in SCENES)
    assert all(d % BEAT == 0 for d in DROPS)


def test_impact_peaks_on_the_hit_and_decays():
    assert impact(120) == 1.0 and 0 < impact(126) < 0.2 and impact(119) == 0
