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

from PySide6.QtCore import QEvent, QPointF, QRect, QRectF, Qt, Signal
from PySide6.QtGui import QColor, QImage, QPainter, QPen, QPointingDevice, QPolygonF, QTransform
from PySide6.QtWidgets import QApplication, QWidget

from .. import theme
from ..animation import element_quad
from ..brushes import SHAPE_PARAMS, preset_params
from ..model import Drawing, Project, Stroke
from ..prefs import apply_curve, prefs
from ..media import MediaPool
from ..render import clip_geometry, clip_transform, draw_clip, draw_drawing, draw_stroke, layer_transform
from ..state import TOOLS_BY_KEY, EditorState

ONION_PREV = QColor("#ff4f6d")
ONION_NEXT = QColor("#2fb4ff")
ZOOM_STEPS = [0.05, 0.1, 0.15, 0.25, 0.33, 0.5, 0.67, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 16.0]
MAX_CACHE_SIDE = 4096
PREVIEW_MEDIA_W = 1280   # ширина кадров видео для просмотра на холсте
DRAW_TOOLS = ("brush", "pencil", "eraser")  # инструменты «от руки»


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


def catmull_rom(points, seg: int = 18):
    """Плавная кривая, проходящая через все точки (как инструмент «Кривая» в Paint Tool SAI)."""
    pts = [(p.x(), p.y()) for p in points]
    if len(pts) < 2:
        return [(x, y, 1.0) for x, y in pts]
    out = []
    for i in range(len(pts) - 1):
        p0 = pts[i - 1] if i > 0 else pts[i]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[i + 2] if i + 2 < len(pts) else pts[i + 1]
        for k in range(seg):
            t = k / seg
            t2, t3 = t * t, t * t * t
            x = 0.5 * (2 * p1[0] + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                       + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * (2 * p1[1] + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                       + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y, 1.0))
    out.append((pts[-1][0], pts[-1][1], 1.0))
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
    penMoved = Signal()
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
        self._pen = False                        # текущий мазок рисуется пером планшета
        self._stroke_tool: str | None = None
        self.pen_info = None                     # (нажим, наклон x, наклон y, конец пера) — для настроек
        self._cache: dict = {}
        self._sai: list | None = None            # точки инструмента «Кривая» (как в SAI)
        self._sai_hover: QPointF | None = None
        self._tf: dict | None = None             # перетаскивание в инструменте «Трансформация»
        self.pool = MediaPool()                  # открытые видео, картинки и GIF для просмотра

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
                tint: QColor | None = None, lt: QTransform | None = None) -> QImage:
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
        if lt is not None:
            p.setTransform(lt, True)
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

    def _cached(self, drawing: Drawing, region: QRect, tint: QColor | None = None,
                lt: QTransform | None = None) -> QImage:
        m = None if lt is None else tuple(round(x, 4) for x in (lt.m11(), lt.m12(), lt.m13(), lt.m21(), lt.m22(),
                                                                 lt.m23(), lt.m31(), lt.m32(), lt.m33()))
        key = (id(drawing), len(drawing.strokes), id(drawing.strokes[-1]) if drawing.strokes else 0,
               self.zoom, region.x(), region.y(), region.width(), region.height(),
               tint.rgba() if tint else 0, self.devicePixelRatioF(), m)
        img = self._cache.get(key)
        if img is None:
            if len(self._cache) > 48:
                self._cache.clear()
            img = self._render(drawing, region, tint=tint, lt=lt)
            self._cache[key] = img
        return img

    # ---------- отрисовка ----------
    def _live_stroke(self) -> Stroke | None:
        tool = self._active_tool()
        st = self.state.tool_settings(tool)
        if st is None:
            return None
        color = QColor(self.state.color)
        if self._live_line is not None:
            a, b = self._live_line
            pts = line_points(a, b)
        elif self._live:
            pts = self._live
        elif tool == "curve" and self._sai:
            ctrl = self._sai + ([self._sai_hover] if self._sai_hover is not None else [])
            if len(ctrl) < 2:
                return None
            pts = catmull_rom(ctrl)
        elif tool == "shapes" and self._shape_start is not None and self._shape_end is not None:
            if st.shape == "curve":
                bend = self._curve_bend or (self._shape_start + self._shape_end) / 2
                pts = curve_points(self._shape_start, self._shape_end, bend)
            else:
                pts = shape_points(st.shape, self._shape_start, self._shape_end, self._shift)
            return Stroke(tuple(pts), color, st.size, st.opacity, brush=SHAPE_PARAMS)
        else:
            return None
        preset = self.state.preset(tool)
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

        # дорожки снизу вверх: клипы видео/картинок/GIF и рисунок «Анимации»
        for track in reversed(proj.tracks):
            if track.kind != "video" or not track.enabled:
                continue
            if track.animation:
                self._paint_layers(p, region, origin, cur_layer, f)
            else:
                clip = track.clip_at(f, proj.fps)
                if clip is not None and hasattr(clip, "transform"):
                    p.save()
                    p.setTransform(self.transform())
                    p.setClipRect(self.paper_rect())
                    if not draw_clip(p, proj, self.pool, clip, f, PREVIEW_MEDIA_W):
                        self._paint_missing(p, clip, f)
                    p.restore()
        p.setOpacity(1.0)

        p.setPen(QPen(QColor(0, 0, 0, 60), 1))
        p.setBrush(Qt.NoBrush)
        p.drawRect(paper)
        self._paint_overlay(p)
        p.end()

    def _paint_missing(self, p: QPainter, clip, f):
        """Клип, для которого нет кадра (файл не найден) — серая заглушка с названием."""
        t = clip_transform(self.project, clip, f)
        if t is None:
            return
        w, h = clip_geometry(self.project, clip)
        p.setTransform(t, True)
        p.fillRect(QRectF(0, 0, w, h), QColor(60, 64, 80, 160))
        p.setPen(QColor("#ffffff"))
        p.drawText(QRectF(0, 0, w, h), Qt.AlignCenter, f"{clip.name}\n(файл не найден)")

    def _layer_t(self, layer, f) -> QTransform | None:
        return layer_transform(self.project, layer, f)

    def _paint_layers(self, p: QPainter, region: QRect, origin: QPointF, cur_layer, f: int):
        proj = self.project
        # луковая кожа: соседние рисунки текущего слоя
        if self.state.onion and cur_layer is not None and cur_layer.visible and cur_layer.type == "drawing":
            lt = self._layer_t(cur_layer, f)
            keys = cur_layer.sorted_keys()
            cur_key = cur_layer.key_at_or_before(f)
            idx = keys.index(cur_key) if cur_key in keys else -1
            for n in range(1, self.state.onion_prev + 1):
                if idx - n >= 0 and not cur_layer.keys[keys[idx - n]].is_empty():
                    p.setOpacity(0.35 / n)
                    p.drawImage(origin, self._cached(cur_layer.keys[keys[idx - n]], region, ONION_PREV, lt))
            for n in range(1, self.state.onion_next + 1):
                j = idx + n if idx >= 0 else n - 1
                if 0 <= j < len(keys) and keys[j] > f and not cur_layer.keys[keys[j]].is_empty():
                    p.setOpacity(0.35 / n)
                    p.drawImage(origin, self._cached(cur_layer.keys[keys[j]], region, ONION_NEXT, lt))
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
            lt = self._layer_t(layer, f)
            op = layer.opacity * (layer.transform.value("opacity", f) if lt is not None else 1.0)
            p.setOpacity(op)
            if extra is not None and extra.erase:
                # ластик должен стирать уже нарисованное — рисуем слой заново вместе с ним
                p.drawImage(origin, self._render(drawing, region, extra, lt=lt))
            else:
                if has:
                    p.drawImage(origin, self._cached(drawing, region, lt=lt))
                if extra is not None:
                    p.save()
                    p.setTransform(self.transform())
                    p.setClipRect(self.paper_rect())
                    if lt is not None:
                        p.setTransform(lt, True)
                    p.setRenderHint(QPainter.Antialiasing)
                    draw_stroke(p, extra)
                    p.restore()
        p.setOpacity(1.0)

    def _paint_overlay(self, p: QPainter):
        p.setRenderHint(QPainter.Antialiasing)
        t = self._view_t()
        # «верёвочка» стабилизатора
        if self._live is not None and self._stab is not None and self._target is not None:
            a, b = t.map(self._stab), t.map(self._target)
            p.setPen(QPen(QColor(theme.ACCENT), 1, Qt.DashLine))
            p.drawLine(a, b)
            p.setBrush(QColor(theme.ACCENT))
            p.drawEllipse(a, 2.5, 2.5)
        # точки кривой SAI
        if self._sai:
            p.setPen(QPen(QColor(theme.ACCENT), 1, Qt.DashLine))
            p.setBrush(Qt.NoBrush)
            pts = [t.map(q) for q in self._sai]
            for a, b in zip(pts, pts[1:]):
                p.drawLine(a, b)
            p.setPen(QPen(QColor(theme.ACCENT), 1.5))
            p.setBrush(QColor("#ffffff"))
            for q in pts:
                p.drawRect(QRectF(q.x() - 3.5, q.y() - 3.5, 7, 7))
        if self.state.tool == "transform":
            self._paint_transform_box(p)
        # опорные точки кривой
        if self._curve_bend is not None and self._shape_start is not None:
            p.setPen(QPen(QColor(theme.ACCENT), 1))
            p.setBrush(QColor(theme.BG_DEEP))
            for pt in (self._shape_start, self._shape_end, self._curve_bend):
                p.drawEllipse(t.map(pt), 4, 4)
        # контур кисти
        info = TOOLS_BY_KEY.get(self._active_tool())
        if self._mouse is None or info is None or not info.sized or self._space or self._pan_last:
            return
        st = self.state.tool_settings(self._active_tool())
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
        self._sai = None
        if self.state.tool == "transform" and self.project.selection is None:
            layer = self.project.draw_layer()
            if layer is not None:
                self.project.select(("layer", layer.id))
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
        """Нажим для мыши — по скорости движения (быстрее — тоньше)."""
        st = self.state.tool_settings(self._active_tool())
        if not st or st.speed <= 0 or self._mouse is None:
            return 1.0
        now = time.perf_counter()
        dt = max(1e-3, now - self._last_t)
        self._last_t = now
        v = math.hypot(pos_widget.x() - self._mouse.x(), pos_widget.y() - self._mouse.y()) / dt  # px/с
        target = 1.0 - (st.speed / 100) * min(1.0, v / 2500)
        self._speed_p += (target - self._speed_p) * 0.35
        return max(0.05, self._speed_p)

    def _active_tool(self) -> str:
        """Инструмент текущего мазка (перо, перевёрнутое ластиком, временно рисует ластиком)."""
        return self._stroke_tool or self.state.tool

    def _cancel_shape(self):
        self._shape_start = self._shape_end = self._curve_bend = None
        self.update()

    # ---------- общий ввод для мыши и пера ----------
    def _to_local(self, pos: QPointF) -> QPointF:
        """Точка курсора в координатах текущего слоя (с учётом его сдвига, поворота, деформации)."""
        scene = self.to_scene(pos)
        layer = self.project.draw_layer()
        lt = self._layer_t(layer, self.project.current_frame) if layer is not None else None
        if lt is None:
            return scene
        inv, ok = lt.inverted()
        return inv.map(scene) if ok else scene

    def _view_t(self) -> QTransform:
        """Из координат текущего слоя — в экран."""
        layer = self.project.draw_layer()
        lt = self._layer_t(layer, self.project.current_frame) if layer is not None else None
        return lt * self.transform() if lt is not None else self.transform()

    def _begin_draw(self, pos: QPointF, pressure: float, shift: bool, tool: str):
        scene = self._to_local(pos)
        self._stroke_tool = tool
        self._mouse = pos
        self._last_t = time.perf_counter()
        self._speed_p = 1.0
        if shift:
            self._live_line = (scene, scene)
        else:
            self._live = [(scene.x(), scene.y(), pressure)]
            self._stab = QPointF(scene)
            self._target = QPointF(scene)
        self.update()

    def _move_draw(self, pos: QPointF, pressure: float, shift: bool):
        scene = self._to_local(pos)
        if self._live_line is not None:
            a = self._live_line[0]
            self._live_line = (a, _constrain_45(a, scene) if shift else scene)
        elif self._live is not None:
            self._target = scene
            self._add_live_point(scene, pressure)
        self._mouse = pos
        self.update()

    def _end_draw(self, pos: QPointF):
        st = self.state.tool_settings(self._active_tool())
        stroke = None
        if self._live_line is not None:
            stroke = self._live_stroke()
            a, b = self._live_line
            if (b - a).manhattanLength() < 0.5:
                stroke = None
            self._live_line = None
        elif self._live is not None:
            self._target = self._to_local(pos)
            # стабилизатор отстаёт — дотягиваем линию до курсора
            if self._stab is not None:
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
        self._stroke_tool = None
        self._pen = False
        if stroke is not None:
            self.project.add_stroke(stroke)
        self.update()

    def _add_live_point(self, target: QPointF, pressure: float):
        st = self.state.tool_settings(self._active_tool())
        s = (st.stabilizer / 100) if st else 0
        if not self._pen:  # мышью рука дрожит сильнее — немного помогаем
            s = min(0.95, s + prefs().get("mouse/extra_stab") / 100 * (1 - s))
        if s > 0:
            k = max(0.03, (1 - s) ** 1.6)
            self._stab = self._stab + (target - self._stab) * k
            pt = self._stab
        else:
            pt = target
        lx, ly, _ = self._live[-1]
        if math.hypot(pt.x() - lx, pt.y() - ly) >= 0.6 / self.zoom:
            self._live.append((pt.x(), pt.y(), pressure))

    # ---------- графический планшет ----------
    def tabletEvent(self, e):
        """Перо обрабатываем напрямую: точные координаты, нажим с кривой, ластик на обратном конце."""
        pos = e.position()
        eraser_end = (e.pointerType() == QPointingDevice.PointerType.Eraser
                      and prefs().get("tablet/pen_eraser"))
        tool = "eraser" if eraser_end else self.state.tool
        self.pen_info = (e.pressure(), e.xTilt(), e.yTilt(), "ластик" if eraser_end else "перо")
        self.penMoved.emit()
        kind = e.type()
        shift = bool(e.modifiers() & Qt.ShiftModifier)
        if kind == QEvent.TabletPress:
            if (e.button() == Qt.LeftButton and tool in DRAW_TOOLS and not self._space
                    and self._pan_last is None and self._live is None and self._live_line is None):
                if self._can_draw():
                    self._pen = True
                    self._begin_draw(pos, apply_curve(e.pressure()), shift, tool)
                e.accept()
                return
        elif kind == QEvent.TabletMove and self._pen:
            self._move_draw(pos, apply_curve(e.pressure()), shift)
            e.accept()
            return
        elif kind == QEvent.TabletRelease and self._pen:
            self._end_draw(pos)
            e.accept()
            return
        e.ignore()  # остальное (навигация, другие инструменты, наведение) — как мышь

    # ---------- мышь ----------
    def mousePressEvent(self, e):
        pos = e.position()
        tool = self.state.tool
        if e.button() == Qt.MiddleButton or (e.button() == Qt.LeftButton and (self._space or tool == "hand")):
            self._pan_last = pos
            self._update_cursor()
            return
        if e.button() == Qt.RightButton:
            if tool == "curve" and self._sai:
                self._finish_sai()
            elif tool == "zoom":
                self.zoom_step(-1, pos)
            elif self._shape_start is not None:
                self._cancel_shape()
            return
        if e.button() != Qt.LeftButton:
            return
        scene = self._to_local(pos)
        if tool == "zoom":
            self.zoom_step(-1 if e.modifiers() & Qt.AltModifier else 1, pos)
        elif tool == "eyedropper":
            img = self.grab().toImage()
            dpr = img.devicePixelRatio()
            self.state.set_color(img.pixelColor(int(pos.x() * dpr), int(pos.y() * dpr)))
        elif tool in DRAW_TOOLS:
            if self._can_draw():
                self._begin_draw(pos, 1.0, bool(e.modifiers() & Qt.ShiftModifier), tool)
        elif tool == "transform":
            self._tf_press(pos, e.modifiers())
        elif tool == "curve":
            if self._sai is None:
                if not self._can_draw():
                    return
                self._sai = [scene]
                self.message.emit("Щёлкайте, чтобы добавлять точки кривой. Enter или двойной щелчок — готово, "
                                  "Backspace — убрать точку, Esc — отмена")
            elif (self._sai[-1] - scene).manhattanLength() > 0.5:
                self._sai.append(scene)
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
        if self._live is not None or self._live_line is not None:
            if not self._pen:
                self._move_draw(pos, self._pressure_at(pos), bool(e.modifiers() & Qt.ShiftModifier))
            return
        if self._tf is not None:
            self._tf_move(pos, e.modifiers())
            return
        if self.state.tool == "transform":
            self._tf_hover(pos)
        local = self._to_local(pos)
        if self._sai is not None:
            self._sai_hover = local
        if self._curve_bend is not None:
            self._curve_bend = local
        elif self._shape_start is not None:
            self._shape_end = local
        self._mouse = pos
        self.update()

    def mouseReleaseEvent(self, e):
        if self._pan_last is not None and e.button() in (Qt.LeftButton, Qt.MiddleButton):
            self._pan_last = None
            self._update_cursor()
            return
        if e.button() != Qt.LeftButton:
            return
        if (self._live is not None or self._live_line is not None) and not self._pen:
            self._end_draw(e.position())
            return
        if self._tf is not None:
            self._tf_release()
            return
        st = self.state.tool_settings()
        stroke = None
        if self._shape_start is not None and self._curve_bend is None:
            if (self._shape_end - self._shape_start).manhattanLength() < 0.5:
                self._cancel_shape()
            elif st.shape == "curve":
                # первая фаза завершена: теперь движение мыши изгибает кривую
                self._curve_bend = (self._shape_start + self._shape_end) / 2
                self.message.emit("Ведите мышь, чтобы изогнуть кривую; щелчок — готово, Esc — отмена")
            else:
                stroke = self._live_stroke()
                self._cancel_shape()
        if stroke is not None:
            self.project.add_stroke(stroke)
        self.update()

    def _commit_shape(self):
        stroke = self._live_stroke()
        self._cancel_shape()
        if stroke is not None:
            self.project.add_stroke(stroke)

    def mouseDoubleClickEvent(self, e):
        if self.state.tool == "curve" and self._sai:
            self._finish_sai()
            return
        super().mouseDoubleClickEvent(e)

    def _finish_sai(self):
        pts = self._sai or []
        self._sai = None
        self._sai_hover = None
        if len(pts) >= 2:
            self._sai = pts
            stroke = self._live_stroke()
            self._sai = None
            if stroke is not None:
                self.project.add_stroke(stroke)
        self.update()

    # ---------- инструмент «Трансформация» ----------
    def _element(self):
        el = self.project.selected_element()
        if el is None:
            return None
        obj, tr, w, h, cx, cy, start = el
        local = self.project.current_frame - start
        v = tr.values(local)
        quad = element_quad(v, w, h, cx, cy)
        return obj, tr, w, h, cx, cy, local, v, quad

    def _handles(self, quad, v):
        """Ручки рамки в экранных координатах: углы c0..c3, середины краёв e0..e3, поворот rot."""
        t = self.transform()
        q = [t.map(quad.at(i)) for i in range(4)]
        hs = {f"c{i}": q[i] for i in range(4)}
        for i in range(4):
            a, b = q[i], q[(i + 1) % 4]
            hs[f"e{i}"] = (a + b) / 2
        top = hs["e0"]
        center = (q[0] + q[1] + q[2] + q[3]) / 4
        d = top - center
        ln = math.hypot(d.x(), d.y()) or 1
        hs["rot"] = top + d / ln * 26
        return hs, q, center

    def _paint_transform_box(self, p: QPainter):
        el = self._element()
        if el is None:
            return
        *_x, v, quad = el
        hs, q, _c = self._handles(quad, v)
        p.save()
        p.setPen(QPen(QColor(theme.ACCENT), 1.5))
        p.setBrush(Qt.NoBrush)
        p.drawPolygon(QPolygonF(q))
        p.drawLine(hs["e0"], hs["rot"])
        p.setBrush(QColor("#ffffff"))
        for name, pt in hs.items():
            if name == "rot":
                p.drawEllipse(pt, 6, 6)
            else:
                p.drawRect(QRectF(pt.x() - 4.5, pt.y() - 4.5, 9, 9))
        p.restore()

    def _hit_handle(self, pos: QPointF):
        el = self._element()
        if el is None:
            return None
        *_x, v, quad = el
        hs, _q, _c = self._handles(quad, v)
        for name, pt in hs.items():
            if (pt - pos).manhattanLength() <= 11:
                return name
        return None

    def _clip_under(self, pos: QPointF):
        scene = self.to_scene(pos)
        proj = self.project
        for track in proj.tracks:  # сверху вниз
            if track.kind != "video" or track.animation or not track.enabled or track.locked:
                continue
            clip = track.clip_at(proj.current_frame, proj.fps)
            if clip is None or not hasattr(clip, "transform"):
                continue
            w, h = clip_geometry(proj, clip)
            quad = element_quad(clip.transform.values(proj.current_frame - clip.start), w, h,
                                proj.width / 2, proj.height / 2)
            if quad.containsPoint(scene, Qt.OddEvenFill):
                return clip
        return None

    def _tf_press(self, pos: QPointF, mods):
        handle = self._hit_handle(pos)
        if handle is None:
            el = self._element()
            inside = el is not None and el[-1].containsPoint(self.to_scene(pos), Qt.OddEvenFill)
            if not inside:
                clip = self._clip_under(pos)
                if clip is not None:
                    self.project.select(("clip", clip.id))
                else:
                    layer = self.project.draw_layer()
                    if layer is None:
                        return
                    self.project.select(("layer", layer.id))
            handle = "move"
        el = self._element()
        if el is None:
            return
        obj, tr, w, h, cx, cy, local, v, quad = el
        if isinstance(getattr(obj, "locked", False), bool) and getattr(obj, "locked", False):
            self.message.emit("Слой заблокирован")
            return
        mode = handle
        if handle.startswith("c") and mods & Qt.ControlModifier:
            mode = "pin" + handle[1]
        elif handle.startswith("e") and mods & Qt.AltModifier:
            mode = "skew" + handle[1]
        self._tf = {"mode": mode, "press": self.to_scene(pos), "orig": tr.copy(), "obj": obj, "v0": dict(v),
                    "w": w, "h": h, "cx": cx, "cy": cy, "local": local}

    def _tf_hover(self, pos: QPointF):
        h = self._hit_handle(pos)
        if h is None:
            el = self._element()
            inside = el is not None and el[-1].containsPoint(self.to_scene(pos), Qt.OddEvenFill)
            self.setCursor(Qt.SizeAllCursor if inside else Qt.ArrowCursor)
        elif h == "rot":
            self.setCursor(Qt.CrossCursor)
        elif h.startswith("c"):
            self.setCursor(Qt.SizeFDiagCursor if h in ("c0", "c2") else Qt.SizeBDiagCursor)
        else:
            self.setCursor(Qt.SizeVerCursor if h in ("e0", "e2") else Qt.SizeHorCursor)

    def _tf_move(self, pos: QPointF, mods):
        d = self._tf
        m = self.to_scene(pos)
        m0 = d["press"]
        v0 = d["v0"]
        w, h = d["w"], d["h"]
        center = QPointF(d["cx"] + v0["x"], d["cy"] + v0["y"])
        rot0 = QTransform().translate(center.x(), center.y()).rotate(v0["rot"]) \
            .shear(math.tan(math.radians(v0["skx"])), 0)
        inv, _ok = rot0.inverted()
        ql, ql0 = inv.map(m), inv.map(m0)
        mode = d["mode"]
        new = {}
        if mode == "move":
            new = {"x": v0["x"] + m.x() - m0.x(), "y": v0["y"] + m.y() - m0.y()}
        elif mode == "rot":
            a = math.degrees(math.atan2(m.y() - center.y(), m.x() - center.x())
                             - math.atan2(m0.y() - center.y(), m0.x() - center.x()))
            r = v0["rot"] + a
            if mods & Qt.ShiftModifier:
                r = round(r / 15) * 15
            new = {"rot": r}
        elif mode.startswith("pin"):
            i = mode[3]
            new = {f"c{i}x": v0[f"c{i}x"] + m.x() - m0.x(), f"c{i}y": v0[f"c{i}y"] + m.y() - m0.y()}
        elif mode.startswith("skew"):
            i = int(mode[4])
            if i in (0, 2):
                sign = -1 if i == 0 else 1
                dx = ql.x() - ql0.x()
                new = {"skx": v0["skx"] + sign * math.degrees(math.atan2(dx, h / 2 * abs(v0["sy"]) or 1))}
        elif mode.startswith("c"):
            hx, hy = [(-1, -1), (1, -1), (1, 1), (-1, 1)][int(mode[1])]
            if mods & Qt.ShiftModifier:  # свободно
                new = {"sx": ql.x() / (hx * w / 2), "sy": ql.y() / (hy * h / 2)}
            else:  # пропорционально
                ref = QPointF(hx * w / 2 * v0["sx"], hy * h / 2 * v0["sy"])
                k = (ql.x() * ref.x() + ql.y() * ref.y()) / max(1e-6, ref.x() ** 2 + ref.y() ** 2)
                new = {"sx": v0["sx"] * k, "sy": v0["sy"] * k}
        elif mode.startswith("e"):
            i = int(mode[1])
            if i == 0:
                new = {"sy": -ql.y() / (h / 2)}
            elif i == 2:
                new = {"sy": ql.y() / (h / 2)}
            elif i == 1:
                new = {"sx": ql.x() / (w / 2)}
            else:
                new = {"sx": -ql.x() / (w / 2)}
        tr = d["orig"].copy()
        for prop, val in new.items():
            tr.set(prop, d["local"], val)
        d["obj"].transform = tr
        self.project.contentChanged.emit()

    def _tf_release(self):
        d, self._tf = self._tf, None
        obj = d["obj"]
        final = obj.transform.copy()
        obj.transform = d["orig"]
        if final.to_dict() != d["orig"].to_dict():
            self.project.edit("Трансформация", lambda: setattr(obj, "transform", final))
        self.project.contentChanged.emit()

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

    def event(self, e):
        # пока строится кривая, Enter/Esc/Backspace — её, а не горячие клавиши окна (Enter = «Воспроизвести»)
        if (e.type() == QEvent.ShortcutOverride and (self._sai is not None or self._curve_bend is not None)
                and e.key() in (Qt.Key_Return, Qt.Key_Enter, Qt.Key_Escape, Qt.Key_Backspace)):
            e.accept()
            return True
        return super().event(e)

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Space and not e.isAutoRepeat():
            self._space = True
            self._update_cursor()
            return
        if self._sai is not None:
            if e.key() == Qt.Key_Escape:
                self._sai = None
                self.update()
                return
            if e.key() in (Qt.Key_Return, Qt.Key_Enter):
                self._finish_sai()
                return
            if e.key() == Qt.Key_Backspace:
                self._sai.pop()
                if not self._sai:
                    self._sai = None
                self.update()
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
