"""Registre des scènes : nom → render(f_local) -> float32 (1080, 1920, 3)."""
from importlib import import_module


class _Registry(dict):
    _MODULES = {"s1": "s1_hook", "s2": "s2_share", "s3": "s3_browse", "s4": "s4_send", "s5": "s5_end"}

    def __missing__(self, name):
        fn = import_module(f"{__name__}.{self._MODULES[name]}").render
        self[name] = fn
        return fn

    def __iter__(self):
        return iter(self._MODULES)


REGISTRY = _Registry()
