from film.ease import out_expo, in_out_cubic, out_back, spring, progress

def test_ease_endpoints():
    for fn in (out_expo, in_out_cubic, out_back, spring):
        assert abs(fn(0)) < 1e-6 and abs(fn(1) - 1) < 1e-3

def test_out_back_overshoots():
    assert max(out_back(i / 100) for i in range(101)) > 1.0

def test_progress_clamped():
    assert progress(5, 10, 20) == 0 and progress(25, 10, 20) == 1 and progress(15, 10, 20) == 0.5
