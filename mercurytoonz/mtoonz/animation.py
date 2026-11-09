"""Анимация по ключевым кадрам: свойства элемента, сглаживание (easing), деформация, готовые пресеты.

Элемент — это клип на видеодорожке (видео, картинка, GIF) или рисованный слой, превращённый в элемент.
У элемента есть свойства, каждое из которых может быть постоянным или анимированным ключами:

    x, y        — смещение от исходного положения, px сцены
    sx, sy      — масштаб по горизонтали и вертикали (1 = 100%)
    rot         — поворот, градусы
    skx         — наклон (сдвиг), градусы
    opacity     — непрозрачность 0..1
    c0x … c3y   — деформация «по углам» (corner pin): смещение каждого из 4 углов, px

Ключ хранит кадр (относительно начала элемента), значение и способ перехода к следующему ключу.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

from PySide6.QtCore import QPointF, QRectF
from PySide6.QtGui import QPolygonF, QTransform

DEFAULTS = {"x": 0.0, "y": 0.0, "sx": 1.0, "sy": 1.0, "rot": 0.0, "skx": 0.0, "opacity": 1.0,
            **{f"c{i}{a}": 0.0 for i in range(4) for a in "xy"}}
CORNERS = [f"c{i}{a}" for i in range(4) for a in "xy"]

# группы свойств для панели «Элемент»
GROUPS = [
    ("pos", "Положение", ["x", "y"]),
    ("scale", "Масштаб", ["sx", "sy"]),
    ("rot", "Поворот", ["rot"]),
    ("skew", "Наклон", ["skx"]),
    ("opacity", "Непрозрачность", ["opacity"]),
    ("corners", "Деформация", CORNERS),
]
GROUP_OF = {p: g for g, _t, props in GROUPS for p in props}


# ------------------------------------------------------------------ сглаживание (скорость движения)
def _bounce(t):
    n, d = 7.5625, 2.75
    if t < 1 / d:
        return n * t * t
    if t < 2 / d:
        t -= 1.5 / d
        return n * t * t + 0.75
    if t < 2.5 / d:
        t -= 2.25 / d
        return n * t * t + 0.9375
    t -= 2.625 / d
    return n * t * t + 0.984375


EASINGS = {
    "linear": ("Равномерно", lambda t: t),
    "smooth": ("Плавно", lambda t: t * t * (3 - 2 * t)),
    "in": ("Разгон", lambda t: t * t * t),
    "out": ("Торможение", lambda t: 1 - (1 - t) ** 3),
    "back": ("С перелётом", lambda t: 1 + 2.70158 * (t - 1) ** 3 + 1.70158 * (t - 1) ** 2),
    "elastic": ("Пружина", lambda t: 0 if t == 0 else 1 if t == 1 else
                2 ** (-10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi) / 3) + 1),
    "bounce": ("Отскок", _bounce),
    "hold": ("Скачком", lambda t: 0.0),
}
EASING_KEYS = list(EASINGS)


def ease(name: str, t: float) -> float:
    return EASINGS.get(name, EASINGS["smooth"])[1](max(0.0, min(1.0, t)))


@dataclass
class Key:
    frame: int
    value: float
    easing: str = "smooth"   # как идти от этого ключа к следующему


@dataclass
class Transform:
    """Набор свойств элемента: постоянные значения и анимированные ключи."""

    static: dict = field(default_factory=dict)   # свойство -> значение (если не анимировано)
    keys: dict = field(default_factory=dict)     # свойство -> [Key, ...] по возрастанию кадра

    def copy(self) -> "Transform":
        return Transform(dict(self.static), {p: [Key(k.frame, k.value, k.easing) for k in ks]
                                            for p, ks in self.keys.items()})

    def is_identity(self) -> bool:
        return not self.keys and all(abs(v - DEFAULTS[p]) < 1e-9 for p, v in self.static.items())

    def animated(self, prop: str) -> bool:
        return bool(self.keys.get(prop))

    def value(self, prop: str, frame: float) -> float:
        ks = self.keys.get(prop)
        if not ks:
            return self.static.get(prop, DEFAULTS[prop])
        if frame <= ks[0].frame:
            return ks[0].value
        if frame >= ks[-1].frame:
            return ks[-1].value
        for a, b in zip(ks, ks[1:]):
            if a.frame <= frame < b.frame:
                t = (frame - a.frame) / max(1, b.frame - a.frame)
                return a.value + (b.value - a.value) * ease(a.easing, t)
        return ks[-1].value

    def values(self, frame: float) -> dict:
        return {p: self.value(p, frame) for p in DEFAULTS}

    def set(self, prop: str, frame: int, value: float, auto_key: bool = False, easing: str | None = None):
        """Меняет свойство: если оно анимировано (или auto_key) — ставит/обновляет ключ на кадре."""
        if self.animated(prop) or auto_key:
            ks = self.keys.setdefault(prop, [])
            for k in ks:
                if k.frame == frame:
                    k.value = value
                    if easing:
                        k.easing = easing
                    return
            ks.append(Key(frame, value, easing or "smooth"))
            ks.sort(key=lambda k: k.frame)
        else:
            self.static[prop] = value

    def key_frames(self, props=None) -> list[int]:
        props = props or list(self.keys)
        return sorted({k.frame for p in props for k in self.keys.get(p, [])})

    def has_key(self, prop: str, frame: int) -> bool:
        return any(k.frame == frame for k in self.keys.get(prop, []))

    def remove_key(self, props, frame: int):
        for p in props:
            ks = self.keys.get(p)
            if not ks:
                continue
            val = self.value(p, frame)
            ks[:] = [k for k in ks if k.frame != frame]
            if not ks:
                del self.keys[p]
                self.static[p] = val

    def set_animated(self, props, frame: int, on: bool):
        """Включает/выключает анимацию группы свойств (как «секундомер» в After Effects)."""
        for p in props:
            if on and not self.animated(p):
                self.keys[p] = [Key(frame, self.static.get(p, DEFAULTS[p]))]
            elif not on and self.animated(p):
                self.static[p] = self.value(p, frame)
                del self.keys[p]

    def easing_at(self, props, frame: int) -> str | None:
        for p in props:
            for k in self.keys.get(p, []):
                if k.frame == frame:
                    return k.easing
        return None

    def set_easing(self, props, frame: int, easing: str):
        for p in props:
            for k in self.keys.get(p, []):
                if k.frame == frame:
                    k.easing = easing

    def shift_keys(self, delta: int):
        for ks in self.keys.values():
            for k in ks:
                k.frame += delta

    def to_dict(self) -> dict:
        d = {}
        static = {p: round(v, 5) for p, v in self.static.items() if abs(v - DEFAULTS[p]) > 1e-9}
        if static:
            d["static"] = static
        if self.keys:
            d["keys"] = {p: [[k.frame, round(k.value, 5), k.easing] for k in ks] for p, ks in self.keys.items()}
        return d

    @classmethod
    def from_dict(cls, d: dict | None) -> "Transform":
        t = cls()
        if not d:
            return t
        t.static = {p: float(v) for p, v in d.get("static", {}).items() if p in DEFAULTS}
        for p, ks in d.get("keys", {}).items():
            if p in DEFAULTS and ks:
                t.keys[p] = sorted((Key(int(f), float(v), str(e) if e in EASINGS else "smooth") for f, v, e in ks),
                                   key=lambda k: k.frame)
        return t


def element_quad(v: dict, w: float, h: float, cx: float, cy: float) -> QPolygonF:
    """Четыре угла элемента в сцене (по часовой: ЛВ, ПВ, ПН, ЛН) после трансформации и деформации.
    w, h — размер элемента, (cx, cy) — его центр в исходном положении."""
    t = QTransform()
    t.translate(cx + v["x"], cy + v["y"])
    t.rotate(v["rot"])
    t.shear(math.tan(math.radians(v["skx"])), 0)
    t.scale(v["sx"], v["sy"])
    corners = [QPointF(-w / 2, -h / 2), QPointF(w / 2, -h / 2), QPointF(w / 2, h / 2), QPointF(-w / 2, h / 2)]
    pts = [t.map(c) for c in corners]
    return QPolygonF([QPointF(p.x() + v[f"c{i}x"], p.y() + v[f"c{i}y"]) for i, p in enumerate(pts)])


def element_transform(v: dict, w: float, h: float, cx: float, cy: float) -> QTransform | None:
    """Преобразование из локальных координат элемента (0..w, 0..h) в сцену, с перспективой."""
    src = QPolygonF([QPointF(0, 0), QPointF(w, 0), QPointF(w, h), QPointF(0, h)])
    dst = element_quad(v, w, h, cx, cy)
    t = QTransform()
    return t if QTransform.quadToQuad(src, dst, t) else None


# ------------------------------------------------------------------ библиотека: переходы и анимации
@dataclass(frozen=True)
class Preset:
    key: str
    title: str
    kind: str          # "in" — появление, "out" — исчезновение, "anim" — анимация на месте
    frames: int        # длительность в кадрах при 24 fps (масштабируется под частоту сцены)
    build: object      # функция (длина, w, h) -> {свойство: [(кадр, значение, easing), ...]}


def _fade(n, w, h):
    return {"opacity": [(0, 0.0, "smooth"), (n, 1.0, "smooth")]}


def _slide(dx, dy):
    def f(n, w, h):
        return {"x": [(0, dx * w, "out"), (n, 0.0, "out")], "y": [(0, dy * h, "out"), (n, 0.0, "out")],
                "opacity": [(0, 0.0, "smooth"), (max(1, n // 2), 1.0, "smooth")]}
    return f


def _zoom_in(n, w, h):
    return {"sx": [(0, 0.0, "back"), (n, 1.0, "back")], "sy": [(0, 0.0, "back"), (n, 1.0, "back")],
            "opacity": [(0, 0.0, "smooth"), (max(1, n // 3), 1.0, "smooth")]}


def _pop(n, w, h):
    return {"sx": [(0, 0.0, "elastic"), (n, 1.0, "elastic")], "sy": [(0, 0.0, "elastic"), (n, 1.0, "elastic")]}


def _spin_in(n, w, h):
    return {"rot": [(0, -180.0, "out"), (n, 0.0, "out")], "sx": [(0, 0.2, "out"), (n, 1.0, "out")],
            "sy": [(0, 0.2, "out"), (n, 1.0, "out")], "opacity": [(0, 0.0, "smooth"), (n // 2, 1.0, "smooth")]}


def _drop(n, w, h):
    return {"y": [(0, -1.2 * h, "bounce"), (n, 0.0, "bounce")]}


def _unfold(n, w, h):  # «шторка»: раскрытие сверху вниз деформацией нижних углов
    return {"c2y": [(0, -h, "out"), (n, 0.0, "out")], "c3y": [(0, -h, "out"), (n, 0.0, "out")]}


def _bounce_anim(n, w, h):
    q = n // 4
    return {"y": [(0, 0.0, "out"), (q, -0.25 * h, "in"), (2 * q, 0.0, "smooth"), (n, 0.0, "smooth")],
            "sx": [(0, 1.0, "smooth"), (2 * q - 2, 1.0, "smooth"), (2 * q, 1.2, "out"), (3 * q, 1.0, "smooth")],
            "sy": [(0, 1.0, "smooth"), (2 * q - 2, 1.0, "smooth"), (2 * q, 0.8, "out"), (3 * q, 1.0, "smooth")]}


def _shake(n, w, h):
    amp = 0.04 * w
    return {"x": [(i, (amp if i % 2 else -amp) if 0 < i < n else 0.0, "smooth") for i in range(0, n + 1, 2)]}


def _pulse(n, w, h):
    return {p: [(0, 1.0, "smooth"), (n // 2, 1.15, "smooth"), (n, 1.0, "smooth")] for p in ("sx", "sy")}


def _wobble(n, w, h):
    s = n // 4
    return {"rot": [(0, 0.0, "smooth"), (s, 8.0, "smooth"), (2 * s, -8.0, "smooth"), (3 * s, 4.0, "smooth"),
                    (n, 0.0, "smooth")]}


def _spin(n, w, h):
    return {"rot": [(0, 0.0, "linear"), (n, 360.0, "linear")]}


def _jelly(n, w, h):
    s = n // 5
    return {"sx": [(0, 1.0, "smooth"), (s, 1.25, "smooth"), (2 * s, 0.85, "smooth"), (3 * s, 1.1, "smooth"),
                   (4 * s, 0.95, "smooth"), (n, 1.0, "smooth")],
            "sy": [(0, 1.0, "smooth"), (s, 0.75, "smooth"), (2 * s, 1.15, "smooth"), (3 * s, 0.9, "smooth"),
                   (4 * s, 1.05, "smooth"), (n, 1.0, "smooth")]}


def _swing3d(n, w, h):  # «поворот плоскости»: перспективное покачивание за счёт углов
    d = 0.12 * h
    return {"c1y": [(0, 0.0, "smooth"), (n // 2, d, "smooth"), (n, 0.0, "smooth")],
            "c2y": [(0, 0.0, "smooth"), (n // 2, -d, "smooth"), (n, 0.0, "smooth")],
            "c0y": [(0, 0.0, "smooth"), (n // 2, -d * 0.3, "smooth"), (n, 0.0, "smooth")],
            "c3y": [(0, 0.0, "smooth"), (n // 2, d * 0.3, "smooth"), (n, 0.0, "smooth")]}


def _reverse(fn):
    """Исчезновение — то же появление задом наперёд."""
    def f(n, w, h):
        return {p: [(n - fr, v, e) for fr, v, e in reversed(ks)] for p, ks in fn(n, w, h).items()}
    return f


PRESETS = [
    Preset("fade_in", "Проявление", "in", 12, _fade),
    Preset("slide_left", "Выезд слева", "in", 14, _slide(-1.2, 0)),
    Preset("slide_right", "Выезд справа", "in", 14, _slide(1.2, 0)),
    Preset("slide_up", "Выезд снизу", "in", 14, _slide(0, 1.2)),
    Preset("zoom_in", "Приближение", "in", 14, _zoom_in),
    Preset("pop", "Выскакивание", "in", 18, _pop),
    Preset("spin_in", "Влёт с вращением", "in", 18, _spin_in),
    Preset("drop", "Падение с отскоком", "in", 24, _drop),
    Preset("unfold", "Шторка", "in", 14, _unfold),
    Preset("fade_out", "Затухание", "out", 12, _reverse(_fade)),
    Preset("zoom_out", "Отдаление", "out", 12, _reverse(_zoom_in)),
    Preset("slide_out", "Уезд вправо", "out", 14, _reverse(_slide(1.2, 0))),
    Preset("bounce", "Подпрыгивание", "anim", 16, _bounce_anim),
    Preset("shake", "Тряска", "anim", 12, _shake),
    Preset("pulse", "Пульс", "anim", 16, _pulse),
    Preset("wobble", "Покачивание", "anim", 20, _wobble),
    Preset("spin", "Вращение", "anim", 24, _spin),
    Preset("jelly", "Желе", "anim", 20, _jelly),
    Preset("swing3d", "Поворот плоскости", "anim", 24, _swing3d),
]
PRESETS_BY_KEY = {p.key: p for p in PRESETS}


def apply_preset(tr: Transform, preset: Preset, start: int, fps: int, w: float, h: float, base: dict | None = None):
    """Ставит ключи пресета, начиная с кадра start (относительно элемента).
    Значения добавляются к текущим (base), поэтому пресет работает поверх уже сдвинутого элемента."""
    n = max(2, round(preset.frames * fps / 24))
    base = base or tr.values(start)
    for prop, ks in preset.build(n, w, h).items():
        additive = prop not in ("sx", "sy", "opacity")
        for fr, v, e in ks:
            fr = int(round(fr))
            if additive:
                val = base[prop] + v
            elif prop == "opacity":
                val = v * base["opacity"]
            else:
                val = v * base[prop]
            tr.set(prop, start + fr, val, auto_key=True, easing=e)
    return n


def bbox_of(points) -> QRectF:
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return QRectF(min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys))
