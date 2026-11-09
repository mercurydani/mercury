"""Настройки программы (хранятся в системе через QSettings)."""

from __future__ import annotations

from PySide6.QtCore import QObject, QSettings, Signal

DEFAULTS = {
    "general/splash": True,            # заставка при запуске
    "general/startup_sound": True,     # звук при запуске
    "tablet/curve": 1.0,               # кривая нажима: <1 — мягче (легче нажимать), >1 — жёстче
    "tablet/pen_eraser": True,         # обратный конец пера — ластик
    "tablet/min_pressure": 0.0,        # «мёртвая зона»: нажим ниже порога не рисует
    "mouse/extra_stab": 15,            # дополнительная стабилизация при рисовании мышью, %
}


class Prefs(QObject):
    changed = Signal(str)

    def __init__(self):
        super().__init__()
        self._s = QSettings("Mercury", "MercuryToonz")
        self._cache: dict = {}

    def get(self, key: str):
        if key not in self._cache:
            default = DEFAULTS[key]
            v = self._s.value(key, default)
            if isinstance(default, bool):
                v = v if isinstance(v, bool) else str(v).lower() in ("1", "true", "yes")
            elif isinstance(default, int):
                v = int(float(v))
            elif isinstance(default, float):
                v = float(v)
            self._cache[key] = v
        return self._cache[key]

    def set(self, key: str, value):
        self._cache[key] = value
        self._s.setValue(key, value)
        self.changed.emit(key)

    def reset(self):
        for k, v in DEFAULTS.items():
            self.set(k, v)


_prefs: Prefs | None = None


def prefs() -> Prefs:
    global _prefs
    if _prefs is None:
        _prefs = Prefs()
    return _prefs


def apply_curve(pressure: float, curve: float | None = None, floor: float | None = None) -> float:
    """Нажим пера с учётом кривой и порога. Возвращает 0.05..1."""
    p = prefs()
    curve = p.get("tablet/curve") if curve is None else curve
    floor = p.get("tablet/min_pressure") if floor is None else floor
    if pressure <= floor:
        return 0.05
    x = (pressure - floor) / max(1e-6, 1 - floor)
    return max(0.05, min(1.0, x ** curve))
