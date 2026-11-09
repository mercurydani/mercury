"""Холст: отображение кадра, луковая кожа, рисование, масштаб и панорама.

Удобство рисования мышью:
  * стабилизатор — кисть «тянется» за курсором и гасит дрожание руки;
  * сглаживание — линия дополнительно выравнивается после отпускания кнопки;
  * нажим от скорости — быстрые движения дают более тонкую линию (как у пера);
  * сужение концов — у линий аккуратные «хвостики»;
  * Shift при нажатии — прямая линия; инструмент «Фигуры → Кривая» — дуга.
"""

from __future__ import annotations

import math
import time

from PySide6.QtCore import QPointF, QRect, QRectF, Qt, Signal
from PySide6.QtGui import QColor, QImage, QPainter, QPen, QTransform
from PySide6.QtWidgets import QApplication, QWidget

from .. import theme
from ..brushes import SHAPE_PARAMS, preset_params
from ..model import Drawing, Project, Stroke
from ..render import draw_drawing, draw_stroke
from ..state import TOOLS_BY_KEY, EditorState

ONION_PREV = QColor("#ff4f6d")
ONION_NEXT = QColor("#2fb4ff")
ZOOM_STEPS = [0.05, 0.1, 0.15, 0.25, 0.33, 0.5, 0.67, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 16.0]
MAX_CACHE_SIDE = 4096
DRAW_TOOLS = ("brush", "pencil", "eraser")


def smooth_points(points, amount: int):
    """Скользящее среднее; amount 0..100."""
    radius = int(amount / 100 * 6)
    if radius == 0 or len(points) < 3:
        return points
    out = []
    n = len(points)
    for i in range(n):
        if i == 0 or i == n - 1:
            out.append(points[i])
            continue
        lo, hi = max(0, i - radius), min(n, i + radius + 1)
        seg = points[lo:hi]
        out.append((
            sum(q[0] for q in seg) / len(seg),
            sum(q[1] for q in seg) / len(seg),
            points[i][2],
        ))
    return out


def _constrain_45(a: QPointF, b: QPointF) -> QPointF:
    ang = math.atan2(b.y() - a.y(), b.x() - a.x())
    ang = round(ang / (math.pi / 4)) * (math.pi / 4)
    ln = math.hypot(b.x() - a.x(), b.y() - a.y())
    return QPointF(a.x() + ln * math.cos(ang), a.y() + ln * math.sin(ang))


def line_points(a: QPointF, b: QPointF, n: int = 24):
    return [(a.x() + (b.x() - a.x()) * i / n, a.y() + (b.y() - a.y()) * i / n, 1.0) for i in range(n + 1)]


def curve_points(a: QPointF, b: QPointF, through: QPointF, n: int = 64):
    """Квадратичная кривая от a до b, проходящая через точку through в середине."""
    cx = 2 * through.x() - (a.x() + b.x()) / 2
    cy = 2 * through.y() - (a.y() + b.y()) / 2
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append((u * u * a.x() + 2 * u * t * cx + t * t * b.x(),
                    u * u * a.y() + 2 * u * t * cy + t * t * b.y(), 1.0))
    return out


def shape_points(kind: str, a: QPointF, b: QPointF, constrain: bool):
    if constrain and kind in ("rect", "ellipse"):
        d = max(abs(b.x() - a.x()), abs(b.y() - a.y()))
        b = QPointF(a.x() + math.copysign(d, b.x() - a.x()), a.y() + math.copysign(d, b.y() - a.y()))
    if kind == "rect":
        corners = [(a.x(), a.y()), (b.x(), a.y()), (b.x(), b.y()), (a.x(), b.y()), (a.x(), a.y())]
        out = []
        for (x0, y0), (x1, y1) in zip(corners, corners[1:]):
            out += [(x0 + (x1 - x0) * i / 12, y0 + (y1 - y0) * i / 12, 1.0) for i in range(12)]
        out.append((a.x(), a.y(), 1.0))
        return out
    if kind == "ellipse":
        cx, cy = (a.x() + b.x()) / 2, (a.y() + b.y()) / 2
        rx, ry = abs(b.x() - a.x()) / 2, abs(b.y() - a.y()) / 2
        steps = 96
        return [(cx + rx * math.cos(t), cy + ry * math.sin(t), 1.0)
                for t in (2 * math.pi * i / steps for i in range(steps + 1))]
    if constrain:
        b = _constrain_45(a, b)
    return line_points(a, b, 2)


class Canvas(QWidget):
    cursorMoved = Signal(float, float)
    zoomChanged = Signal(float)
    message = Signal(str)

    def __init__(self, project: Project, state: EditorState, parent=None):
        super().__init__(parent)
        self.project = project
        self.state = state
        self.zoom = 0.5
        self.offset = QPointF(40, 40)
        self._fitted = False
        # рисование
        self._live: list | None = None          # точки текущего мазка (сцена)
        self._live_line: tuple | None = None     # (начало, конец) прямой по Shift
        self._stab: QPointF | None = None        # положение «ленивой» кисти
        self._target: QPointF | None = None      # где сейчас курсор (сцена)
        self._last_t = 0.0
        self._speed_p = 1.0
        # фигуры и кривая
        self._shape_start: QPointF | None = None
        self._shape_end: QPointF | None = None
        self._curve_bend: QPointF | None = None  # вторая фаза кривой
        # навигация
        self._pan_last: QPointF | None = None
        self._space = False
        self._mouse: QPointF | None = None
        self._tablet_pressure: float | None = None
        self._cache: dict = {}

        self.setMouseTracking(True)
        self.setTabletTracking(True)
        self.setFocusPolicy(Qt.StrongFocus)
        self.setAttribute(Qt.WA_OpaquePaintEvent)
        self.setMinimumSize(320, 240)

        project.contentChanged.connect(self.update)
        project.structureChanged.connect(self.update)
        project.frameChanged.connect(lambda _: self.update())
        project.layerChanged.connect(lambda _: self.update())
        project.sceneChanged.connect(self.fit_to_view)
        state.onionChanged.connect(self.update)
        state.toolChanged.connect(lambda _: self._on_tool_changed())
        state.settingsChanged.connect(self.update)

    # ---------- геометрия ----------
    def transform(self) -> QTransform:
        return QTransform().translate(self.offset.x(), self.offset.y()).scale(self.zoom, self.zoom)

    def to_scene(self, pos: QPointF) -> QPointF:
        return QPointF((pos.x() - self.offset.x()) / self.zoom, (pos.y() - self.offset.y()) / self.zoom)

    def paper_rect(self) -> QRectF:
        return QRectF(0, 0, self.project.width, self.project.height)

    def fit_to_view(self):
        margin = 48
        w, h = self.project.width, self.project.height
        z = min((self.width() - 2 * margin) / w, (self.height() - 2 * margin) / h)
        self.zoom = max(0.02, z)
        self.offset = QPointF((self.width() - w * self.zoom) / 2, (self.height() - h * self.zoom) / 2)
        self.zoomChanged.emit(self.zoom)
        self.update()

    def set_zoom(self, z: float, anchor: QPointF | None = None):
        z = max(0.02, min(z, 32.0))
        if anchor is None:
            anchor = QPointF(self.width() / 2, self.height() / 2)
        scene = self.to_scene(anchor)
        self.zoom = z
        self.offset = QPointF(anchor.x() - scene.x() * z, anchor.y() - scene.y() * z)
        self.zoomChanged.emit(z)
        self.update()

    def zoom_step(self, direction: int, anchor: QPointF | None = None):
        if direction > 0:
            nxt = next((s for s in ZOOM_STEPS if s > self.zoom + 1e-6), ZOOM_STEPS[-1])
        else:
            nxt = next((s for s in reversed(ZOOM_STEPS) if s < self.zoom - 1e-6), ZOOM_STEPS[0])
        self.set_zoom(nxt, anchor)

    def resizeEvent(self, e):
        if not self._fitted and self.width() > 100:
            self._fitted = True
            self.fit_to_view()
        super().resizeEvent(e)

    # ---------- кэш отрисованных слоёв ----------
    def _region(self) -> QRect:
        """Область листа (в пикселях при текущем масштабе), которую держим в кэше.
        Если лист целиком помещается в разумный размер — кэшируем весь, тогда панорама бесплатна."""
        pw, ph = self.project.width * self.zoom, self.project.height * self.zoom
        dpr = self.devicePixelRatioF()
        if pw * dpr <= MAX_CACHE_SIDE and ph * dpr <= MAX_CACHE_SIDE:
            return QRect(0, 0, math.ceil(pw), math.ceil(ph))
        vis = QRectF(-self.offset.x(), -self.offset.y(), self.width(), self.height())
        return vis.intersected(QRectF(0, 0, pw, ph)).toAlignedRect()

    def _render(self, drawing: Drawing | None, region: QRect, extra: Stroke | None = None,
                tint: QColor | None = None) -> QImage:
        dpr = self.devicePixelRatioF()
        img = QImage(max(1, int(region.width() * dpr)), max(1, int(region.height() * dpr)),
                     QImage.Format_ARGB32_Premultiplied)
        img.setDevicePixelRatio(dpr)
        img.fill(Qt.transparent)
        p = QPainter(img)
        p.setRenderHint(QPainter.Antialiasing)
        p.translate(-region.x(), -region.y())
        p.scale(self.zoom, self.zoom)
        p.setClipRect(self.paper_rect())
        draw_drawing(p, drawing)
        if extra:
            draw_stroke(p, extra)
        if tint is not None:
            p.resetTransform()
            p.setClipping(False)
            p.setCompositionMode(QPainter.CompositionMode_SourceIn)
            p.fillRect(QRectF(0, 0, img.width(), img.height()), tint)
        p.end()
        return img

    def _cached(self, drawing: Drawing, region: QRect, tint: QColor | None = None) -> QImage:
        key = (id(drawing), len(drawing.strokes), id(drawing.strokes[-1]) if drawing.strokes else 0,
               self.zoom, region.x(), region.y(), region.width(), region.height(),
               tint.rgba() if tint else 0, self.devicePixelRatioF())
        img = self._cache.get(key)
        if img is None:
            if len(self._cache) > 48:
                self._cache.clear()
            img = self._render(drawing, region, tint=tint)
            self._cache[key] = img
        return img

    # ---------- отрисовка ----------
    def _live_stroke(self) -> Stroke | None:
        tool = self.state.tool
        st = self.state.tool_settings()
        if st is None:
            return None
        color = QColor(self.state.color)
        if self._live_line is not None:
            a, b = self._live_line
            pts = line_points(a, b)
        elif self._live:
            pts = self._live
        elif tool == "shapes" and self._shape_start is not None and self._shape_end is not None:
            if st.shape == "curve":
                bend = self._curve_bend or (self._shape_start + self._shape_end) / 2
                pts = curve_points(self._shape_start, self._shape_end, bend)
            else:
                pts = shape_points(st.shape, self._shape_start, self._shape_end, self._shift)
            return Stroke(tuple(pts), color, st.size, st.opacity, brush=SHAPE_PARAMS)
        else:
            return None
        preset = self.state.preset()
        params = preset_params(preset, st.taper) if preset else SHAPE_PARAMS
        return Stroke(tuple(pts), color, st.size, st.opacity, erase=(tool == "eraser"),
                      use_pressure=st.pressure, brush=params)

    @property
    def _shift(self) -> bool:
        return bool(QApplication.keyboardModifiers() & Qt.ShiftModifier)

    def paintEvent(self, _):
        p = QPainter(self)
        p.fillRect(self.rect(), QColor(theme.BG_DEEP))
        paper = self.transform().mapRect(self.paper_rect())

        p.setRenderHint(QPainter.Antialiasing)
        for i, a in enumerate((26, 16, 8)):
            p.fillRect(paper.adjusted(-i - 1, -i + 1, i + 1, i + 3), QColor(0, 0, 0, a))
        p.fillRect(paper, self.project.background)

        proj = self.project
        cur_layer = proj.layer()
        f = proj.current_frame
        region = self._region()
        origin = QPointF(self.offset.x() + region.x(), self.offset.y() + region.y())

        # луковая кожа: соседние рисунки текущего слоя
        if self.state.onion and cur_layer is not None and cur_layer.visible and cur_layer.type == "drawing":
            keys = cur_layer.sorted_keys()
            cur_key = cur_layer.key_at_or_before(f)
            idx = keys.index(cur_key) if cur_key in keys else -1
            for n in range(1, self.state.onion_prev + 1):
                if idx - n >= 0 and not cur_layer.keys[keys[idx - n]].is_empty():
                    p.setOpacity(0.35 / n)
                    p.drawImage(origin, self._cached(cur_layer.keys[keys[idx - n]], region, ONION_PREV))
            for n in range(1, self.state.onion_next + 1):
                j = idx + n if idx >= 0 else n - 1
                if 0 <= j < len(keys) and keys[j] > f and not cur_layer.keys[keys[j]].is_empty():
                    p.setOpacity(0.35 / n)
                    p.drawImage(origin, self._cached(cur_layer.keys[keys[j]], region, ONION_NEXT))
            p.setOpacity(1.0)

        live = self._live_stroke()
        for layer in reversed(proj.layers):  # снизу вверх
            if not layer.visible or layer.type != "drawing":
                continue
            extra = live if layer is cur_layer else None
            drawing = layer.drawing_at(f)
            has = drawing is not None and not drawing.is_empty()
            if not has and extra is None:
                continue
            p.setOpacity(layer.opacity)
            if extra is not None and extra.erase:
                # ластик должен стирать уже нарисованное — рисуем слой заново вместе с ним
                p.drawImage(origin, self._render(drawing, region, extra))
            else:
                if has:
                    p.drawImage(origin, self._cached(drawing, region))
                if extra is not None:
                    p.save()
                    p.setTransform(self.transform())
                    p.setClipRect(self.paper_rect())
                    p.setRenderHint(QPainter.Antialiasing)
                    draw_stroke(p, extra)
                    p.restore()
        p.setOpacity(1.0)

        p.setPen(QPen(QColor(0, 0, 0, 60), 1))
        p.setBrush(Qt.NoBrush)
        p.drawRect(paper)
        self._paint_overlay(p)
        p.end()

    def _paint_overlay(self, p: QPainter):
        p.setRenderHint(QPainter.Antialiasing)
        t = self.transform()
        # «верёвочка» стабилизатора
        if self._live is not None and self._stab is not None and self._target is not None:
            a, b = t.map(self._stab), t.map(self._target)
            p.setPen(QPen(QColor(theme.ACCENT), 1, Qt.DashLine))
            p.drawLine(a, b)
            p.setBrush(QColor(theme.ACCENT))
            p.drawEllipse(a, 2.5, 2.5)
        # опорные точки кривой
        if self._curve_bend is not None and self._shape_start is not None:
            p.setPen(QPen(QColor(theme.ACCENT), 1))
            p.setBrush(QColor(theme.BG_DEEP))
            for pt in (self._shape_start, self._shape_end, self._curve_bend):
                p.drawEllipse(t.map(pt), 4, 4)
        # контур кисти
        info = TOOLS_BY_KEY.get(self.state.tool)
        if self._mouse is None or info is None or not info.sized or self._space or self._pan_last:
            return
        st = self.state.tool_settings()
        r = max(1.5, st.size * self.zoom / 2)
        p.setBrush(Qt.NoBrush)
        p.setPen(QPen(QColor(255, 255, 255, 200), 1.5))
        p.drawEllipse(self._mouse, r, r)
        p.setPen(QPen(QColor(0, 0, 0, 200), 1))
        p.drawEllipse(self._mouse, r, r)
        if r > 6:
            p.drawPoint(self._mouse)

    def _on_tool_changed(self):
        self._cancel_shape()
        self._update_cursor()

    def _update_cursor(self):
        tool = self.state.tool
        if self._space or tool == "hand":
            self.setCursor(Qt.ClosedHandCursor if self._pan_last else Qt.OpenHandCursor)
        elif TOOLS_BY_KEY[tool].sized:
            self.setCursor(Qt.BlankCursor if self.underMouse() else Qt.CrossCursor)
        elif tool == "zoom":
            self.setCursor(Qt.SizeAllCursor)
        elif tool in ("select", "transform"):
            self.setCursor(Qt.ArrowCursor)
        else:
            self.setCursor(Qt.CrossCursor)
        self.update()

    # ---------- ввод ----------
    def _can_draw(self) -> bool:
        layer = self.project.layer()
        if layer is None:
            return False
        if self.project.draw_layer() is None:
            self.message.emit(f"На слое «{layer.name}» рисовать нельзя — выберите рисованный слой")
            return False
        if layer.locked:
            self.message.emit(f"Слой «{layer.name}» заблокирован")
            return False
        if not layer.visible:
            self.message.emit(f"Слой «{layer.name}» скрыт")
            return False
        return True

    def _pressure_at(self, pos_widget: QPointF) -> float:
        """Нажим пера, а для мыши — по скорости движения."""
        if self._tablet_pressure is not None:
            return self._tablet_pressure
        st = self.state.tool_settings()
        if not st or st.speed <= 0 or self._mouse is None:
            return 1.0
        now = time.perf_counter()
        dt = max(1e-3, now - self._last_t)
        self._last_t = now
        v = math.hypot(pos_widget.x() - self._mouse.x(), pos_widget.y() - self._mouse.y()) / dt  # px/с
        target = 1.0 - (st.speed / 100) * min(1.0, v / 2500)
        self._speed_p += (target - self._speed_p) * 0.35
        return max(0.05, self._speed_p)

    def tabletEvent(self, e):
        self._tablet_pressure = max(0.05, e.pressure())
        e.ignore()  # координаты обрабатываются синтезированными событиями мыши

    def _cancel_shape(self):
        self._shape_start = self._shape_end = self._curve_bend = None
        self.update()

    def mousePressEvent(self, e):
        pos = e.position()
        tool = self.state.tool
        if e.button() == Qt.MiddleButton or (e.button() == Qt.LeftButton and (self._space or tool == "hand")):
            self._pan_last = pos
            self._update_cursor()
            return
        if e.button() == Qt.RightButton:
            if tool == "zoom":
                self.zoom_step(-1, pos)
            elif self._shape_start is not None:
                self._cancel_shape()
            return
        if e.button() != Qt.LeftButton:
            return
        scene = self.to_scene(pos)
        if tool == "zoom":
            self.zoom_step(-1 if e.modifiers() & Qt.AltModifier else 1, pos)
        elif tool == "eyedropper":
            img = self.grab().toImage()
            dpr = img.devicePixelRatio()
            self.state.set_color(img.pixelColor(int(pos.x() * dpr), int(pos.y() * dpr)))
        elif tool in DRAW_TOOLS:
            if not self._can_draw():
                return
            self._mouse = pos
            self._last_t = time.perf_counter()
            self._speed_p = 1.0
            if e.modifiers() & Qt.ShiftModifier:
                self._live_line = (scene, scene)
            else:
                self._live = [(scene.x(), scene.y(), self._tablet_pressure or 1.0)]
                self._stab = QPointF(scene)
                self._target = QPointF(scene)
            self.update()
        elif tool == "shapes":
            if self._curve_bend is not None:
                self._commit_shape()  # второй щелчок фиксирует кривую
                return
            if self._can_draw():
                self._shape_start = scene
                self._shape_end = scene
        else:
            self.message.emit(f"Инструмент «{TOOLS_BY_KEY[tool].title}» появится на следующих шагах")

    def _add_live_point(self, target: QPointF, pressure: float):
        st = self.state.tool_settings()
        s = (st.stabilizer / 100) if st else 0
        if s > 0:
            k = max(0.03, (1 - s) ** 1.6)
            self._stab = self._stab + (target - self._stab) * k
            pt = self._stab
        else:
            pt = target
        lx, ly, _ = self._live[-1]
        if math.hypot(pt.x() - lx, pt.y() - ly) >= 0.6 / self.zoom:
            self._live.append((pt.x(), pt.y(), pressure))

    def mouseMoveEvent(self, e):
        pos = e.position()
        scene = self.to_scene(pos)
        self.cursorMoved.emit(scene.x(), scene.y())
        if self._pan_last is not None:
            self.offset += pos - self._pan_last
            self._pan_last = pos
            self._mouse = pos
            self.update()
            return
        if self._live_line is not None:
            a = self._live_line[0]
            self._live_line = (a, _constrain_45(a, scene) if e.modifiers() & Qt.ShiftModifier else scene)
        elif self._live is not None:
            pressure = self._pressure_at(pos)
            self._target = scene
            self._add_live_point(scene, pressure)
        elif self._curve_bend is not None:
            self._curve_bend = scene
        elif self._shape_start is not None:
            self._shape_end = scene
        self._mouse = pos
        self.update()

    def mouseReleaseEvent(self, e):
        if self._pan_last is not None and e.button() in (Qt.LeftButton, Qt.MiddleButton):
            self._pan_last = None
            self._update_cursor()
            return
        if e.button() != Qt.LeftButton:
            return
        st = self.state.tool_settings()
        stroke = None
        if self._live_line is not None:
            stroke = self._live_stroke()
            a, b = self._live_line
            if (b - a).manhattanLength() < 0.5:
                stroke = None
            self._live_line = None
        elif self._live is not None:
            self._target = self.to_scene(e.position())
            # стабилизатор отстаёт — дотягиваем линию до курсора
            if self._target is not None and self._stab is not None:
                gap = math.hypot(self._target.x() - self._stab.x(), self._target.y() - self._stab.y())
                steps = max(1 if gap > 0.01 else 0, int(gap / max(1.0, st.size * 0.3)))
                last_p = self._live[-1][2]
                for i in range(1, steps + 1):
                    q = self._stab + (self._target - self._stab) * (i / steps)
                    self._live.append((q.x(), q.y(), last_p))
            self._live = smooth_points(self._live, st.smoothing)
            stroke = self._live_stroke()
            self._live = None
            self._stab = self._target = None
        elif self._shape_start is not None and self._curve_bend is None:
            if (self._shape_end - self._shape_start).manhattanLength() < 0.5:
                self._cancel_shape()
            elif st.shape == "curve":
                # первая фаза завершена: теперь движение мыши изгибает кривую
                self._curve_bend = (self._shape_start + self._shape_end) / 2
                self.message.emit("Ведите мышь, чтобы изогнуть кривую; щелчок — готово, Esc — отмена")
            else:
                stroke = self._live_stroke()
                self._cancel_shape()
        self._tablet_pressure = None
        if stroke is not None:
            self.project.add_stroke(stroke)
        self.update()

    def _commit_shape(self):
        stroke = self._live_stroke()
        self._cancel_shape()
        if stroke is not None:
            self.project.add_stroke(stroke)

    def wheelEvent(self, e):
        d = e.angleDelta()
        if e.modifiers() & Qt.ControlModifier or self.state.tool == "zoom":
            if d.y():
                self.set_zoom(self.zoom * (1.0015 ** d.y()), e.position())
        else:
            pd = e.pixelDelta()
            delta = QPointF(pd) if not pd.isNull() else QPointF(d) / 2
            if e.modifiers() & Qt.ShiftModifier:
                delta = QPointF(delta.y(), delta.x())
            self.offset += delta
            self.update()
        e.accept()

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Space and not e.isAutoRepeat():
            self._space = True
            self._update_cursor()
            return
        if e.key() == Qt.Key_Escape and self._shape_start is not None:
            self._cancel_shape()
            return
        if e.key() in (Qt.Key_Return, Qt.Key_Enter) and self._curve_bend is not None:
            self._commit_shape()
            return
        super().keyPressEvent(e)

    def keyReleaseEvent(self, e):
        if e.key() == Qt.Key_Space and not e.isAutoRepeat():
            self._space = False
            self._pan_last = None
            self._update_cursor()
            return
        super().keyReleaseEvent(e)

    def enterEvent(self, e):
        self._update_cursor()
        super().enterEvent(e)

    def leaveEvent(self, e):
        self._mouse = None
        self.update()
        super().leaveEvent(e)
