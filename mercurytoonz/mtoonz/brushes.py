"""Движок кистей: параметры, набор готовых кистей и отрисовка мазков.

Виды кистей (BrushParams.kind):
    solid        гладкий мазок переменной толщины (тушь, перо, маркер)
    calligraphy  плоское перо под углом — толщина зависит от направления
    pixel        без сглаживания, квадратный кончик
    stamp        «штампы» кончика вдоль линии (карандаш, мел, мягкие кисти)
    spray        аэрограф: облако точек
"""

from __future__ import annotations

import math
import random
from dataclasses import asdict, dataclass, fields, replace
from functools import lru_cache

from PySide6.QtCore import QPointF, QRectF, Qt
from PySide6.QtGui import (
    QBrush, QColor, QImage, QPainter, QPainterPath, QPen, QPolygonF, QRadialGradient,
)


@dataclass(frozen=True)
class BrushParams:
    kind: str = "solid"
    hardness: float = 1.0        # для stamp: 0 — мягкий край, 1 — жёсткий
    spacing: float = 0.12        # шаг штампов в долях толщины
    texture: str = ""            # "" | grain | chalk | bristle
    angle: float = 40.0          # угол пера для calligraphy, градусы
    flat: float = 0.2            # толщина пера поперёк (0..1) для calligraphy
    jitter: float = 0.0          # разброс штампов в долях толщины
    pressure_min: float = 0.25   # толщина при нулевом нажиме (доля)
    taper_start: float = 0.0     # сужение в начале, 0..1
    taper_end: float = 0.0       # сужение в конце, 0..1
    flow: float = 1.0            # непрозрачность одного штампа

    def to_dict(self) -> dict:
        default = BrushParams()
        return {k: v for k, v in asdict(self).items() if getattr(default, k) != v}

    @classmethod
    def from_dict(cls, d: dict | None) -> "BrushParams":
        if not d:
            return cls()
        names = {f.name for f in fields(cls)}
        return cls(**{k: v for k, v in d.items() if k in names})


@dataclass(frozen=True)
class BrushPreset:
    key: str
    name: str
    group: str
    params: BrushParams
    size: float
    opacity: float = 1.0
    stabilizer: int = 20
    smoothing: int = 30
    speed: int = 0               # утончение от скорости мыши, 0..100
    pressure: bool = True


P = BrushParams
PRESETS: list[BrushPreset] = [
    # --- линия ---
    BrushPreset("ink", "Тушь", "Линия", P("solid", taper_start=0.5, taper_end=0.6, pressure_min=0.2),
                6, stabilizer=35, smoothing=40, speed=45),
    BrushPreset("gpen", "Перо G", "Линия", P("solid", taper_start=0.8, taper_end=0.9, pressure_min=0.05),
                8, stabilizer=30, smoothing=35, speed=60),
    BrushPreset("liner", "Линер", "Линия", P("solid", pressure_min=1.0), 4, stabilizer=25, smoothing=30,
                pressure=False),
    BrushPreset("calligraphy", "Каллиграфия", "Линия", P("calligraphy", angle=40, flat=0.15), 14,
                stabilizer=25, smoothing=30, pressure=False),
    BrushPreset("marker", "Маркер", "Линия", P("solid", pressure_min=1.0), 18, opacity=0.55, stabilizer=15,
                smoothing=25, pressure=False),
    BrushPreset("felt", "Фломастер", "Линия", P("solid", taper_end=0.15, pressure_min=0.7), 9, opacity=0.95,
                stabilizer=15, smoothing=25, speed=15),
    # --- графика ---
    BrushPreset("pencil_hb", "Карандаш HB", "Графика",
                P("stamp", hardness=0.85, spacing=0.18, texture="grain", pressure_min=0.5, taper_end=0.3, flow=0.7),
                3, opacity=0.9, stabilizer=10, smoothing=15, speed=20),
    BrushPreset("pencil_6b", "Карандаш 6B", "Графика",
                P("stamp", hardness=0.7, spacing=0.15, texture="grain", pressure_min=0.4, taper_end=0.3, flow=0.6),
                7, stabilizer=10, smoothing=15, speed=20),
    BrushPreset("chalk", "Мел", "Графика",
                P("stamp", hardness=0.8, spacing=0.22, texture="chalk", jitter=0.08, pressure_min=0.6, flow=0.85),
                16, stabilizer=10, smoothing=20),
    BrushPreset("charcoal", "Уголь", "Графика",
                P("stamp", hardness=0.6, spacing=0.12, texture="chalk", jitter=0.12, pressure_min=0.5, flow=0.5),
                24, stabilizer=10, smoothing=20),
    # --- живопись ---
    BrushPreset("round", "Круглая кисть", "Живопись",
                P("solid", taper_start=0.3, taper_end=0.4, pressure_min=0.3), 16, stabilizer=20, smoothing=35, speed=25),
    BrushPreset("gouache", "Гуашь", "Живопись",
                P("stamp", hardness=0.9, spacing=0.08, texture="bristle", pressure_min=0.6, taper_end=0.3, flow=0.9),
                26, stabilizer=15, smoothing=30),
    BrushPreset("watercolor", "Акварель", "Живопись",
                P("stamp", hardness=0.25, spacing=0.1, pressure_min=0.6, flow=0.12), 40, stabilizer=15, smoothing=35),
    BrushPreset("soft", "Мягкая", "Живопись",
                P("stamp", hardness=0.0, spacing=0.1, pressure_min=0.5, flow=0.18), 60, stabilizer=10, smoothing=30),
    BrushPreset("spray", "Аэрограф", "Живопись", P("spray", spacing=0.25, pressure_min=0.5, flow=0.9), 50,
                stabilizer=5, smoothing=10),
    # --- особые ---
    BrushPreset("pixel", "Пиксель", "Особые", P("pixel", pressure_min=1.0), 1, stabilizer=0, smoothing=0,
                pressure=False),
]
PRESETS_BY_KEY = {p.key: p for p in PRESETS}

ERASER_PRESETS = [
    BrushPreset("eraser_hard", "Жёсткий", "Ластик", P("solid", pressure_min=0.5), 24, stabilizer=10, smoothing=15),
    BrushPreset("eraser_soft", "Мягкий", "Ластик", P("stamp", hardness=0.1, spacing=0.1, flow=0.35, pressure_min=0.5),
                48, stabilizer=10, smoothing=15),
]
ERASER_BY_KEY = {p.key: p for p in ERASER_PRESETS}

SHAPE_PARAMS = BrushParams("solid", pressure_min=1.0)


# ------------------------------------------------------------------ геометрия
def chaikin(points, iterations: int = 2):
    """Сглаживание ломаной (срез углов). Концы сохраняются."""
    pts = list(points)
    for _ in range(iterations):
        if len(pts) < 3:
            return pts
        out = [pts[0]]
        for a, b in zip(pts, pts[1:]):
            out.append((0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1], 0.75 * a[2] + 0.25 * b[2]))
            out.append((0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1], 0.25 * a[2] + 0.75 * b[2]))
        out.append(pts[-1])
        pts = out
    return pts


def _cumulative(points):
    dist = [0.0]
    for a, b in zip(points, points[1:]):
        dist.append(dist[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    return dist


def widths(points, base: float, params: BrushParams, use_pressure: bool):
    """Толщина в каждой точке с учётом нажима и сужения концов."""
    dist = _cumulative(points)
    total = dist[-1]
    pmin = params.pressure_min
    t_start = params.taper_start * base * 6
    t_end = params.taper_end * base * 6
    if total > 0 and t_start + t_end > total * 0.8:  # короткий мазок — сужаем пропорционально
        k = total * 0.8 / (t_start + t_end)
        t_start, t_end = t_start * k, t_end * k
    out = []
    for (x, y, pr), d in zip(points, dist):
        f = (pmin + (1 - pmin) * pr) if use_pressure else 1.0
        if t_start > 0 and d < t_start:
            f *= 0.15 + 0.85 * math.sin(d / t_start * math.pi / 2)
        if t_end > 0 and total - d < t_end:
            f *= 0.15 + 0.85 * math.sin((total - d) / t_end * math.pi / 2)
        out.append(max(0.3, base * f))
    return out, dist


# ------------------------------------------------------------------ кончики
@lru_cache(maxsize=256)
def _tip(hardness: float, texture: str, rgba: int, variant: int) -> QImage:
    """Изображение кончика 64×64 указанного цвета."""
    size = 64
    img = QImage(size, size, QImage.Format_ARGB32_Premultiplied)
    img.fill(Qt.transparent)
    color = QColor.fromRgba(rgba)
    p = QPainter(img)
    p.setRenderHint(QPainter.Antialiasing)
    c = QPointF(size / 2, size / 2)
    r = size / 2 - 1
    g = QRadialGradient(c, r)
    solid = QColor(color)
    solid.setAlpha(255)
    clear = QColor(color)
    clear.setAlpha(0)
    g.setColorAt(0, solid)
    g.setColorAt(max(0.0, min(0.99, hardness)), solid)
    g.setColorAt(1, clear)
    p.setPen(Qt.NoPen)
    p.setBrush(QBrush(g))
    p.drawEllipse(c, r, r)
    if texture:
        rnd = random.Random(variant * 7919 + sum(map(ord, texture)))
        p.setCompositionMode(QPainter.CompositionMode_DestinationOut)
        if texture == "grain":
            holes, rad = 260, (0.8, 2.2)
        elif texture == "chalk":
            holes, rad = 170, (1.5, 4.5)
        else:  # bristle — продольные «щетинки»
            holes, rad = 0, (0, 0)
            for i in range(14):
                y = rnd.uniform(4, size - 4)
                p.setPen(QPen(QColor(0, 0, 0, rnd.randint(90, 200)), rnd.uniform(0.8, 2.2)))
                p.drawLine(QPointF(0, y), QPointF(size, y + rnd.uniform(-3, 3)))
        p.setPen(Qt.NoPen)
        for _ in range(holes):
            p.setBrush(QColor(0, 0, 0, rnd.randint(120, 255)))
            p.drawEllipse(QPointF(rnd.uniform(0, size), rnd.uniform(0, size)), *([rnd.uniform(*rad)] * 2))
    p.end()
    return img


# ------------------------------------------------------------------ отрисовка
def _seed(points) -> int:
    if not points:
        return 0
    x, y, _ = points[0]
    return int(x * 131 + y * 17 + len(points) * 7) & 0xFFFFFFFF


def _solid_path(points, ws) -> QPainterPath:
    """Объединение кружков и трапеций между ними — без «перекрытий» при прозрачности."""
    path = QPainterPath()
    path.setFillRule(Qt.WindingFill)
    for i, ((x, y, _), w) in enumerate(zip(points, ws)):
        path.addEllipse(QPointF(x, y), w / 2, w / 2)
        if i == 0:
            continue
        (x0, y0, _), w0 = points[i - 1], ws[i - 1]
        dx, dy = x - x0, y - y0
        ln = math.hypot(dx, dy)
        if ln < 1e-6:
            continue
        nx, ny = -dy / ln, dx / ln
        poly = QPolygonF([
            QPointF(x0 + nx * w0 / 2, y0 + ny * w0 / 2),
            QPointF(x + nx * w / 2, y + ny * w / 2),
            QPointF(x - nx * w / 2, y - ny * w / 2),
            QPointF(x0 - nx * w0 / 2, y0 - ny * w0 / 2),
        ])
        path.addPolygon(poly)
        path.closeSubpath()
    return path


def _calligraphy_path(points, ws, params: BrushParams) -> QPainterPath:
    path = QPainterPath()
    path.setFillRule(Qt.WindingFill)
    a = math.radians(params.angle)
    ux, uy = math.cos(a), math.sin(a)
    minor = max(0.05, params.flat)
    for i in range(len(points)):
        x, y, _ = points[i]
        w = ws[i]
        hx, hy = ux * w / 2, uy * w / 2
        tx, ty = -uy * w * minor / 2, ux * w * minor / 2  # толщина пера поперёк
        if i > 0:
            px, py, _ = points[i - 1]
            pw = ws[i - 1]
            phx, phy = ux * pw / 2, uy * pw / 2
            path.addPolygon(QPolygonF([
                QPointF(px - phx, py - phy), QPointF(px + phx, py + phy),
                QPointF(x + hx, y + hy), QPointF(x - hx, y - hy),
            ]))
            path.closeSubpath()
        # сам кончик пера — тонкий параллелограмм
        path.addPolygon(QPolygonF([
            QPointF(x - hx - tx, y - hy - ty), QPointF(x + hx - tx, y + hy - ty),
            QPointF(x + hx + tx, y + hy + ty), QPointF(x - hx + tx, y - hy + ty),
        ]))
        path.closeSubpath()
    return path


def _walk(points, ws, dist, step_of):
    """Точки вдоль линии с шагом step_of(толщина). Возвращает (x, y, w)."""
    if len(points) == 1:
        yield points[0][0], points[0][1], ws[0]
        return
    i = 0
    d = 0.0
    total = dist[-1]
    while d <= total:
        while i < len(points) - 2 and dist[i + 1] < d:
            i += 1
        seg = dist[i + 1] - dist[i]
        t = 0.0 if seg <= 0 else (d - dist[i]) / seg
        x = points[i][0] + (points[i + 1][0] - points[i][0]) * t
        y = points[i][1] + (points[i + 1][1] - points[i][1]) * t
        w = ws[i] + (ws[i + 1] - ws[i]) * t
        yield x, y, w
        d += max(0.25, step_of(w))


def draw_brush_stroke(p: QPainter, points, color: QColor, width: float, params: BrushParams,
                      use_pressure: bool, erase: bool):
    if not points:
        return
    if len(points) > 2 and params.kind != "pixel":
        points = chaikin(points, 2)
    ws, dist = widths(points, width, params, use_pressure)
    col = QColor(0, 0, 0) if erase else QColor(color)

    if params.kind in ("solid", "calligraphy"):
        path = _solid_path(points, ws) if params.kind == "solid" else _calligraphy_path(points, ws, params)
        p.setPen(Qt.NoPen)
        p.setBrush(col)
        p.drawPath(path)
        return

    if params.kind == "pixel":
        aa = p.testRenderHint(QPainter.Antialiasing)
        p.setRenderHint(QPainter.Antialiasing, False)
        w = max(1, round(width))
        p.setPen(Qt.NoPen)
        p.setBrush(col)
        for x, y, _ in _walk(points, [w] * len(points), dist, lambda _w: 0.5):
            p.drawRect(QRectF(math.floor(x - w / 2 + 0.5), math.floor(y - w / 2 + 0.5), w, w))
        p.setRenderHint(QPainter.Antialiasing, aa)
        return

    rnd = random.Random(_seed(points))
    base_op = p.opacity()
    if params.kind == "spray":
        p.setPen(Qt.NoPen)
        p.setBrush(col)
        for x, y, w in _walk(points, ws, dist, lambda w: w * params.spacing):
            n = max(4, int(w * 0.9))
            for _ in range(n):
                a = rnd.uniform(0, 2 * math.pi)
                r = w / 2 * math.sqrt(rnd.random())
                dot = rnd.uniform(0.5, 1.5) * max(0.7, w / 35)
                p.setOpacity(base_op * params.flow * rnd.uniform(0.3, 1.0))
                p.drawEllipse(QPointF(x + r * math.cos(a), y + r * math.sin(a)), dot, dot)
        p.setOpacity(base_op)
        return

    # stamp
    p.setOpacity(base_op * params.flow)
    for x, y, w in _walk(points, ws, dist, lambda w: w * params.spacing):
        if params.jitter:
            x += rnd.uniform(-1, 1) * params.jitter * w
            y += rnd.uniform(-1, 1) * params.jitter * w
        tip = _tip(round(params.hardness, 2), params.texture, col.rgba(),
                   rnd.randrange(6) if params.texture else 0)
        if params.texture:
            p.save()
            p.translate(x, y)
            p.rotate(rnd.uniform(0, 360) if params.texture != "bristle" else 0)
            p.drawImage(QRectF(-w / 2, -w / 2, w, w), tip)
            p.restore()
        else:
            p.drawImage(QRectF(x - w / 2, y - w / 2, w, w), tip)
    p.setOpacity(base_op)


def preview_points(width: float, height: float):
    """Волнистая линия для превью кисти."""
    pts = []
    n = 40
    for i in range(n + 1):
        t = i / n
        x = 8 + t * (width - 16)
        y = height / 2 + math.sin(t * math.pi * 2) * height * 0.22
        pr = math.sin(t * math.pi) ** 0.7
        pts.append((x, y, pr))
    return pts


def preset_params(preset: BrushPreset, taper: int | None = None) -> BrushParams:
    if taper is None:
        return preset.params
    k = taper / 50.0  # 50 — «как задумано», 0 — без сужения, 100 — вдвое сильнее
    return replace(preset.params,
                   taper_start=min(1.0, preset.params.taper_start * k) if preset.params.taper_start else 0.25 * max(0, k - 1),
                   taper_end=min(1.0, preset.params.taper_end * k) if preset.params.taper_end else 0.25 * max(0, k - 1))
