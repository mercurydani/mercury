"""Холст: отображение кадра, луковая кожа, рисование, масштаб и панорама."""

from __future__ import annotations

import math

from PySide6.QtCore import QPointF, QRectF, Qt, Signal
from PySide6.QtGui import QColor, QImage, QPainter, QPen, QTransform
from PySide6.QtWidgets import QWidget

from .. import theme
from ..model import Drawing, Project, Stroke
from ..render import draw_drawing, draw_stroke
from ..state import TOOLS_BY_KEY, EditorState

ONION_PREV = QColor("#ff4f6d")
ONION_NEXT = QColor("#2fb4ff")
ZOOM_STEPS = [0.05, 0.1, 0.15, 0.25, 0.33, 0.5, 0.67, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 16.0]


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


def shape_points(kind: str, a: QPointF, b: QPointF, constrain: bool):
    if constrain and kind != "line":
        d = max(abs(b.x() - a.x()), abs(b.y() - a.y()))
        b = QPointF(a.x() + math.copysign(d, b.x() - a.x()), a.y() + math.copysign(d, b.y() - a.y()))
    if kind == "rect":
        pts = [(a.x(), a.y()), (b.x(), a.y()), (b.x(), b.y()), (a.x(), b.y()), (a.x(), a.y())]
        # дублируем углы, чтобы сплайн не скруглял их
        out = []
        for q in pts:
            out += [q, q]
        return [(x, y, 1.0) for x, y in out]
    if kind == "ellipse":
        cx, cy = (a.x() + b.x()) / 2, (a.y() + b.y()) / 2
        rx, ry = abs(b.x() - a.x()) / 2, abs(b.y() - a.y()) / 2
        steps = 72
        return [(cx + rx * math.cos(t), cy + ry * math.sin(t), 1.0)
                for t in (2 * math.pi * i / steps for i in range(steps + 1))]
    if constrain:  # линия под шагом 45°
        ang = math.atan2(b.y() - a.y(), b.x() - a.x())
        ang = round(ang / (math.pi / 4)) * (math.pi / 4)
        ln = math.hypot(b.x() - a.x(), b.y() - a.y())
        b = QPointF(a.x() + ln * math.cos(ang), a.y() + ln * math.sin(ang))
    return [(a.x(), a.y(), 1.0), (b.x(), b.y(), 1.0)]


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
        self._live: list | None = None          # точки текущего мазка
        self._shape_start: QPointF | None = None
        self._shape_end: QPointF | None = None
        self._pan_last: QPointF | None = None
        self._space = False
        self._mouse: QPointF | None = None
        self._tablet_pressure: float | None = None

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
        state.toolChanged.connect(lambda _: self._update_cursor())
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

    # ---------- отрисовка ----------
    def _buffer(self) -> QImage:
        dpr = self.devicePixelRatioF()
        img = QImage(int(self.width() * dpr), int(self.height() * dpr), QImage.Format_ARGB32_Premultiplied)
        img.setDevicePixelRatio(dpr)
        img.fill(Qt.transparent)
        return img

    def _render_drawing(self, drawing: Drawing | None, extra: Stroke | None = None,
                        tint: QColor | None = None) -> QImage:
        img = self._buffer()
        p = QPainter(img)
        p.setRenderHint(QPainter.Antialiasing)
        p.setTransform(self.transform())
        p.setClipRect(self.paper_rect())
        draw_drawing(p, drawing)
        if extra:
            draw_stroke(p, extra)
        if tint is not None:
            p.resetTransform()
            p.setClipping(False)
            p.setCompositionMode(QPainter.CompositionMode_SourceIn)
            p.fillRect(QRectF(0, 0, self.width(), self.height()), tint)
        p.end()
        return img

    def _live_stroke(self) -> Stroke | None:
        tool = self.state.tool
        st = self.state.tool_settings()
        if st is None:
            return None
        if self._live:
            return Stroke(tuple(self._live), QColor(self.state.color), st.size, st.opacity,
                          erase=(tool == "eraser"), use_pressure=st.pressure)
        if self._shape_start is not None and self._shape_end is not None:
            pts = shape_points(st.shape, self._shape_start, self._shape_end, self._shift)
            return Stroke(tuple(pts), QColor(self.state.color), st.size, st.opacity)
        return None

    @property
    def _shift(self) -> bool:
        from PySide6.QtWidgets import QApplication
        return bool(QApplication.keyboardModifiers() & Qt.ShiftModifier)

    def paintEvent(self, _):
        p = QPainter(self)
        p.fillRect(self.rect(), QColor(theme.BG_DEEP))
        t = self.transform()
        paper = t.mapRect(self.paper_rect())

        # тень и лист
        p.setRenderHint(QPainter.Antialiasing)
        for i, a in enumerate((26, 16, 8)):
            p.fillRect(paper.adjusted(-i - 1, -i + 1, i + 1, i + 3), QColor(0, 0, 0, a))
        p.fillRect(paper, self.project.background)

        proj = self.project
        cur_layer = proj.layer()
        f = proj.current_frame

        # луковая кожа: соседние рисунки текущего слоя
        if self.state.onion and cur_layer is not None and cur_layer.visible:
            keys = cur_layer.sorted_keys()
            cur_key = cur_layer.key_at_or_before(f)
            idx = keys.index(cur_key) if cur_key in keys else -1
            for n in range(1, self.state.onion_prev + 1):
                if idx - n >= 0:
                    img = self._render_drawing(cur_layer.keys[keys[idx - n]], tint=ONION_PREV)
                    p.setOpacity(0.35 / n)
                    p.drawImage(0, 0, img)
            for n in range(1, self.state.onion_next + 1):
                j = idx + n if idx >= 0 else n - 1
                if 0 <= j < len(keys) and keys[j] > f:
                    img = self._render_drawing(cur_layer.keys[keys[j]], tint=ONION_NEXT)
                    p.setOpacity(0.35 / n)
                    p.drawImage(0, 0, img)
            p.setOpacity(1.0)

        live = self._live_stroke()
        for layer in reversed(proj.layers):  # снизу вверх
            if not layer.visible:
                continue
            extra = live if layer is cur_layer else None
            drawing = layer.drawing_at(f)
            if (drawing is None or drawing.is_empty()) and extra is None:
                continue
            img = self._render_drawing(drawing, extra)
            p.setOpacity(layer.opacity)
            p.drawImage(0, 0, img)
        p.setOpacity(1.0)

        # рамка листа
        p.setPen(QPen(QColor(0, 0, 0, 60), 1))
        p.setBrush(Qt.NoBrush)
        p.drawRect(paper)

        self._paint_cursor(p)
        p.end()

    def _paint_cursor(self, p: QPainter):
        info = TOOLS_BY_KEY.get(self.state.tool)
        if self._mouse is None or info is None or not info.sized or self._space or self._pan_last:
            return
        st = self.state.tool_settings()
        r = max(1.5, st.size * self.zoom / 2)
        p.setRenderHint(QPainter.Antialiasing)
        p.setBrush(Qt.NoBrush)
        p.setPen(QPen(QColor(255, 255, 255, 200), 1.5))
        p.drawEllipse(self._mouse, r, r)
        p.setPen(QPen(QColor(0, 0, 0, 200), 1))
        p.drawEllipse(self._mouse, r, r)

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
        if layer.locked:
            self.message.emit(f"Слой «{layer.name}» заблокирован")
            return False
        if not layer.visible:
            self.message.emit(f"Слой «{layer.name}» скрыт")
            return False
        return True

    def _pressure(self) -> float:
        return self._tablet_pressure if self._tablet_pressure is not None else 1.0

    def tabletEvent(self, e):
        # давление пера; сами координаты обрабатываются синтезированными событиями мыши
        self._tablet_pressure = max(0.05, e.pressure())
        e.ignore()

    def mousePressEvent(self, e):
        pos = e.position()
        tool = self.state.tool
        if e.button() == Qt.MiddleButton or (e.button() == Qt.LeftButton and (self._space or tool == "hand")):
            self._pan_last = pos
            self._update_cursor()
            return
        if e.button() == Qt.RightButton and tool == "zoom":
            self.zoom_step(-1, pos)
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
        elif tool in ("brush", "pencil", "eraser"):
            if self._can_draw():
                self._live = [(scene.x(), scene.y(), self._pressure())]
                self.update()
        elif tool == "shapes":
            if self._can_draw():
                self._shape_start = scene
                self._shape_end = scene
        else:
            self.message.emit(f"Инструмент «{TOOLS_BY_KEY[tool].title}» появится на следующих шагах")

    def mouseMoveEvent(self, e):
        pos = e.position()
        self._mouse = pos
        scene = self.to_scene(pos)
        self.cursorMoved.emit(scene.x(), scene.y())
        if self._pan_last is not None:
            self.offset += pos - self._pan_last
            self._pan_last = pos
            self.update()
            return
        if self._live is not None:
            lx, ly, _ = self._live[-1]
            min_dist = 0.75 / self.zoom
            if math.hypot(scene.x() - lx, scene.y() - ly) >= min_dist:
                self._live.append((scene.x(), scene.y(), self._pressure()))
        elif self._shape_start is not None:
            self._shape_end = scene
        self.update()

    def mouseReleaseEvent(self, e):
        if self._pan_last is not None and e.button() in (Qt.LeftButton, Qt.MiddleButton):
            self._pan_last = None
            self._update_cursor()
            return
        if e.button() != Qt.LeftButton:
            return
        stroke = None
        st = self.state.tool_settings()
        if self._live is not None:
            pts = smooth_points(self._live, st.smoothing)
            stroke = Stroke(tuple(pts), QColor(self.state.color), st.size, st.opacity,
                            erase=(self.state.tool == "eraser"), use_pressure=st.pressure)
            self._live = None
        elif self._shape_start is not None:
            stroke = self._live_stroke()
            if self._shape_end is not None and (self._shape_end - self._shape_start).manhattanLength() < 0.5:
                stroke = None
            self._shape_start = self._shape_end = None
        self._tablet_pressure = None
        if stroke is not None:
            self.project.add_stroke(stroke)
        self.update()

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
