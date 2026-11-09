"""Таймлайн: слои слева, сетка кадров справа, линейка и бегунок воспроизведения."""

from __future__ import annotations

from PySide6.QtCore import QPointF, QRectF, QSize, Qt, Signal
from PySide6.QtGui import QColor, QFont, QPainter, QPen, QPolygonF
from PySide6.QtWidgets import (
    QFrame, QHBoxLayout, QInputDialog, QLabel, QMenu, QScrollBar, QSlider, QSpinBox,
    QToolButton, QVBoxLayout, QWidget,
)

from .. import icons, theme
from ..model import Project
from ..state import EditorState

LAYER_W = 230
HEADER_H = 26
ROW_H = 30

C_ROW = QColor("#1f2228")
C_ROW_ALT = QColor("#22252c")
C_ROW_CUR = QColor("#2a2f38")
C_GRID = QColor("#2b2f37")
C_GRID_5 = QColor("#363b45")
C_OUTSIDE = QColor("#17191d")
C_SPAN = QColor("#3a404b")
C_SPAN_CUR = QColor("#4a5160")
C_SPAN_EMPTY = QColor("#2b3038")


class TimelineCanvas(QWidget):
    scrolled = Signal()

    def __init__(self, project: Project, state: EditorState, context_actions: list):
        super().__init__()
        self.project = project
        self.state = state
        self.context_actions = context_actions
        self.cell_w = 18
        self.hoff = 0
        self.voff = 0
        self._scrubbing = False
        self._drag_layer = None   # перетаскиваемый звуковой клип
        self._drag_from = 0
        self._drag_delta = 0
        self.setMouseTracking(True)
        self.setMinimumHeight(HEADER_H + ROW_H * 2)
        self.setFocusPolicy(Qt.ClickFocus)
        for sig in (project.structureChanged, project.contentChanged):
            sig.connect(self.update)
        project.frameChanged.connect(lambda _: self.update())
        project.layerChanged.connect(lambda _: self.update())

    # ---------- геометрия ----------
    def grid_width(self) -> int:
        return max(0, self.width() - LAYER_W)

    def content_width(self) -> int:
        # показываем немного «пустых» кадров за концом сцены
        return (self.project.frame_count + 40) * self.cell_w

    def content_height(self) -> int:
        return len(self.project.layers) * ROW_H

    def frame_at(self, x: float) -> int:
        return int((x - LAYER_W + self.hoff) // self.cell_w)

    def row_at(self, y: float) -> int:
        return int((y - HEADER_H + self.voff) // ROW_H)

    def frame_x(self, f: int) -> float:
        return LAYER_W + f * self.cell_w - self.hoff

    def row_y(self, r: int) -> float:
        return HEADER_H + r * ROW_H - self.voff

    def ensure_frame_visible(self, f: int):
        x = f * self.cell_w
        gw = self.grid_width()
        if x < self.hoff:
            self.hoff = x
        elif x + self.cell_w > self.hoff + gw:
            self.hoff = x + self.cell_w - gw + self.cell_w * 4
        else:
            return
        self.scrolled.emit()
        self.update()

    # ---------- отрисовка ----------
    def paintEvent(self, _):
        p = QPainter(self)
        p.fillRect(self.rect(), QColor(theme.BG_PANEL))
        proj = self.project
        cw = self.cell_w
        first = max(0, self.hoff // cw)
        last = (self.hoff + self.grid_width()) // cw + 1

        # --- сетка кадров ---
        p.save()
        p.setClipRect(LAYER_W, HEADER_H, self.grid_width(), self.height() - HEADER_H)
        for r, layer in enumerate(proj.layers):
            y = self.row_y(r)
            if y > self.height() or y + ROW_H < HEADER_H:
                continue
            cur = r == proj.current_layer
            base = C_ROW_CUR if cur else (C_ROW_ALT if r % 2 else C_ROW)
            p.fillRect(QRectF(LAYER_W, y, self.grid_width(), ROW_H), base)
            out_x = self.frame_x(proj.frame_count)
            if out_x < self.width():
                p.fillRect(QRectF(out_x, y, self.width() - out_x, ROW_H), C_OUTSIDE)
            for f in range(first, last + 1):
                x = self.frame_x(f)
                p.setPen(C_GRID_5 if (f + 1) % 5 == 0 else C_GRID)
                p.drawLine(QPointF(x + cw - 0.5, y), QPointF(x + cw - 0.5, y + ROW_H))
            p.setPen(C_GRID)
            p.drawLine(QPointF(LAYER_W, y + ROW_H - 0.5), QPointF(self.width(), y + ROW_H - 0.5))
            self._paint_layer_cells(p, layer, y, first, last, cur)

        # текущий кадр
        cx = self.frame_x(proj.current_frame)
        p.fillRect(QRectF(cx, HEADER_H, cw, self.height()), QColor(255, 90, 79, 28))
        p.restore()

        # --- линейка ---
        self._paint_ruler(p, first, last)

        # --- бегунок ---
        px = cx + cw / 2
        if px >= LAYER_W:
            p.setPen(QPen(QColor(theme.PLAYHEAD), 1.5))
            p.drawLine(QPointF(px, HEADER_H), QPointF(px, self.height()))

        # --- колонка слоёв ---
        self._paint_layers(p)
        p.end()

    def _paint_audio_clip(self, p: QPainter, layer, y, cur):
        fps = max(1, self.project.fps)
        start = layer.start + (self._drag_delta if self._drag_layer is layer else 0)
        end = start + max(1, round(layer.duration * fps))
        x0, x1 = self.frame_x(start), self.frame_x(end)
        if x1 < LAYER_W or x0 > self.width():
            return
        rect = QRectF(x0 + 1, y + 3, x1 - x0 - 2, ROW_H - 6)
        p.setRenderHint(QPainter.Antialiasing)
        base = QColor("#2a6b4d" if cur else "#24563f")
        if not layer.visible:
            base = QColor("#3a3f47")
        p.setPen(QPen(QColor("#3fbf7f"), 1) if cur else Qt.NoPen)
        p.setBrush(base)
        p.drawRoundedRect(rect, 4, 4)
        # волна
        if layer.peaks:
            from ..audio import PEAKS_PER_SECOND
            mid = rect.center().y()
            half = rect.height() / 2 - 3
            vis0 = max(rect.left(), LAYER_W)
            vis1 = min(rect.right(), self.width())
            px_per_sec = self.cell_w * fps
            wave = QColor("#9be3bf" if layer.visible else "#6b7280")
            p.setPen(QPen(wave, 1))
            xi = int(vis0)
            while xi < vis1:
                t0 = (xi - rect.left()) / px_per_sec
                i0 = int(t0 * PEAKS_PER_SECOND)
                i1 = max(i0 + 1, int((t0 + 1 / px_per_sec) * PEAKS_PER_SECOND))
                chunk = layer.peaks[i0:i1]
                if chunk:
                    h = max(0.5, max(chunk) * half)
                    p.drawLine(QPointF(xi + 0.5, mid - h), QPointF(xi + 0.5, mid + h))
                xi += 1
        p.setPen(QColor("#e6fff2"))
        f = QFont(self.font())
        f.setPixelSize(11)
        p.setFont(f)
        label = QRectF(max(rect.left(), LAYER_W) + 6, rect.top(), rect.width(), 14)
        p.drawText(label, Qt.AlignLeft | Qt.AlignVCenter, layer.name)
        p.setRenderHint(QPainter.Antialiasing, False)

    def _paint_layer_cells(self, p: QPainter, layer, y, first, last, cur):
        if layer.type == "audio":
            self._paint_audio_clip(p, layer, y, cur)
            return
        proj = self.project
        cw = self.cell_w
        keys = layer.sorted_keys()
        p.setRenderHint(QPainter.Antialiasing)
        for i, k in enumerate(keys):
            end = keys[i + 1] if i + 1 < len(keys) else proj.frame_count
            end = max(end, k + 1)
            if end <= first or k > last:
                continue
            drawing = layer.keys[k]
            empty = drawing.is_empty()
            x0, x1 = self.frame_x(k), self.frame_x(end)
            span = QRectF(x0 + 1, y + 4, x1 - x0 - 2, ROW_H - 8)
            if empty:
                p.setPen(QPen(C_SPAN_CUR if cur else C_SPAN, 1))
                p.setBrush(C_SPAN_EMPTY)
            else:
                p.setPen(Qt.NoPen)
                p.setBrush(C_SPAN_CUR if cur else C_SPAN)
            p.drawRoundedRect(span, 3, 3)
            # цветная метка слоя по нижнему краю непустого рисунка
            if not empty:
                p.fillRect(QRectF(span.left() + 2, span.bottom() - 2, span.width() - 4, 2), QColor(layer.tag))
            # маркер ключа
            c = QPointF(x0 + cw / 2, y + ROW_H / 2)
            r = min(4.5, cw / 2 - 2)
            if empty:
                p.setBrush(Qt.NoBrush)
                p.setPen(QPen(QColor(theme.TEXT), 1.4))
            else:
                p.setPen(Qt.NoPen)
                p.setBrush(QColor(theme.TEXT))
            p.drawEllipse(c, r, r)
            # конец экспозиции
            if end - k > 1:
                ex = self.frame_x(end - 1)
                p.setPen(Qt.NoPen)
                p.setBrush(QColor(theme.TEXT_MUTED))
                p.drawRect(QRectF(ex + cw / 2 - 2.5, y + ROW_H / 2 - 3.5, 5, 7))
        p.setRenderHint(QPainter.Antialiasing, False)

    def _paint_ruler(self, p: QPainter, first, last):
        proj = self.project
        cw = self.cell_w
        p.fillRect(QRectF(LAYER_W, 0, self.grid_width(), HEADER_H), QColor(theme.BG_PANEL))
        p.save()
        p.setClipRect(LAYER_W, 0, self.grid_width(), HEADER_H)
        f = QFont(self.font())
        f.setPointSizeF(8.5)
        p.setFont(f)
        step = 5 if cw >= 12 else 10
        for fr in range(first, last + 1):
            x = self.frame_x(fr)
            n = fr + 1
            outside = fr >= proj.frame_count
            if n % step == 0 or n == 1:
                p.setPen(QColor(theme.TEXT_MUTED if not outside else "#4a4f58"))
                p.drawText(QRectF(x - 20, 2, cw + 40, HEADER_H - 8), Qt.AlignHCenter | Qt.AlignTop, str(n))
                p.drawLine(QPointF(x + cw / 2, HEADER_H - 6), QPointF(x + cw / 2, HEADER_H))
            else:
                p.setPen(QColor("#3c414b"))
                p.drawLine(QPointF(x + cw / 2, HEADER_H - 3), QPointF(x + cw / 2, HEADER_H))
        # бейдж текущего кадра
        cx = self.frame_x(proj.current_frame) + cw / 2
        label = str(proj.current_frame + 1)
        w = max(22, p.fontMetrics().horizontalAdvance(label) + 10)
        badge = QRectF(cx - w / 2, 3, w, 16)
        p.setRenderHint(QPainter.Antialiasing)
        p.setPen(Qt.NoPen)
        p.setBrush(QColor(theme.PLAYHEAD))
        p.drawRoundedRect(badge, 4, 4)
        p.drawPolygon(QPolygonF([QPointF(cx - 4, 19), QPointF(cx + 4, 19), QPointF(cx, HEADER_H - 1)]))
        p.setPen(QColor("#ffffff"))
        f.setBold(True)
        p.setFont(f)
        p.drawText(badge, Qt.AlignCenter, label)
        p.restore()
        p.setPen(QColor(theme.BORDER))
        p.drawLine(QPointF(LAYER_W, HEADER_H - 0.5), QPointF(self.width(), HEADER_H - 0.5))

    def _paint_layers(self, p: QPainter):
        proj = self.project
        p.fillRect(QRectF(0, 0, LAYER_W, self.height()), QColor(theme.BG_PANEL))
        p.save()
        p.setClipRect(0, HEADER_H, LAYER_W, self.height() - HEADER_H)
        for r, layer in enumerate(proj.layers):
            y = self.row_y(r)
            if y > self.height() or y + ROW_H < HEADER_H:
                continue
            cur = r == proj.current_layer
            row = QRectF(0, y, LAYER_W, ROW_H)
            p.fillRect(row, C_ROW_CUR if cur else C_ROW)
            if cur:
                p.fillRect(QRectF(0, y, 3, ROW_H), QColor(theme.ACCENT))
            # видимость и блокировка
            audio = layer.type == "audio"
            eye = icons.pixmap(("speaker" if audio else "eye") if layer.visible else
                               ("speaker-off" if audio else "eye-off"),
                               theme.TEXT if layer.visible else theme.TEXT_MUTED, 16)
            p.drawPixmap(QPointF(10, y + (ROW_H - 16) / 2), eye)
            lock = icons.pixmap("lock" if layer.locked else "unlock",
                                theme.ACCENT if layer.locked else theme.TEXT_MUTED, 16)
            p.drawPixmap(QPointF(34, y + (ROW_H - 16) / 2), lock)
            # цветная метка
            p.setRenderHint(QPainter.Antialiasing)
            p.setPen(Qt.NoPen)
            p.setBrush(QColor(layer.tag))
            p.drawRoundedRect(QRectF(60, y + ROW_H / 2 - 5, 10, 10), 3, 3)
            p.setRenderHint(QPainter.Antialiasing, False)
            # имя
            p.setPen(QColor(theme.TEXT if layer.visible else theme.TEXT_MUTED))
            f = QFont(self.font())
            f.setBold(cur)
            p.setFont(f)
            name = p.fontMetrics().elidedText(layer.name, Qt.ElideRight, LAYER_W - 90)
            p.drawText(QRectF(78, y, LAYER_W - 86, ROW_H), Qt.AlignVCenter | Qt.AlignLeft, name)
            p.setPen(C_GRID)
            p.drawLine(QPointF(0, y + ROW_H - 0.5), QPointF(LAYER_W, y + ROW_H - 0.5))
        p.restore()
        # шапка колонки слоёв
        p.fillRect(QRectF(0, 0, LAYER_W, HEADER_H), QColor(theme.BG_PANEL))
        p.drawPixmap(QPointF(10, 5), icons.pixmap("eye", theme.TEXT_MUTED, 16))
        p.drawPixmap(QPointF(34, 5), icons.pixmap("lock", theme.TEXT_MUTED, 16))
        p.setPen(QColor(theme.TEXT_MUTED))
        f = QFont(self.font())
        f.setPointSizeF(8.5)
        f.setBold(True)
        p.setFont(f)
        p.drawText(QRectF(60, 0, 150, HEADER_H), Qt.AlignVCenter, "СЛОИ")
        p.setPen(QColor(theme.BORDER))
        p.drawLine(QPointF(0, HEADER_H - 0.5), QPointF(LAYER_W, HEADER_H - 0.5))
        p.drawLine(QPointF(LAYER_W - 0.5, 0), QPointF(LAYER_W - 0.5, self.height()))

    # ---------- ввод ----------
    def mousePressEvent(self, e):
        pos = e.position()
        x, y = pos.x(), pos.y()
        proj = self.project
        if x < LAYER_W:
            if y < HEADER_H:
                return
            r = self.row_at(y)
            if not (0 <= r < len(proj.layers)):
                return
            layer = proj.layers[r]
            if e.button() == Qt.LeftButton and 6 <= x <= 30:
                layer.visible = not layer.visible
                proj.mark_dirty()
                proj.contentChanged.emit()
            elif e.button() == Qt.LeftButton and 30 < x <= 54:
                layer.locked = not layer.locked
                proj.mark_dirty()
                self.update()
            else:
                proj.set_layer(r)
            return
        f = self.frame_at(x)
        if y < HEADER_H:
            if e.button() == Qt.LeftButton:
                self._scrubbing = True
                proj.set_frame(f)
            return
        r = self.row_at(y)
        if 0 <= r < len(proj.layers):
            proj.set_layer(r)
            layer = proj.layers[r]
            if (layer.type == "audio" and e.button() == Qt.LeftButton and not layer.locked
                    and layer.start <= f < layer.end_frame(proj.fps)):
                # тянем звуковой клип по времени
                self._drag_layer = layer
                self._drag_from = f
                self._drag_delta = 0
                self.setCursor(Qt.ClosedHandCursor)
                return
        proj.set_frame(f)
        if e.button() == Qt.LeftButton:
            self._scrubbing = True
        elif e.button() == Qt.RightButton:
            menu = QMenu(self)
            for a in self.context_actions:
                if a is None:
                    menu.addSeparator()
                else:
                    menu.addAction(a)
            menu.exec(e.globalPosition().toPoint())

    def mouseMoveEvent(self, e):
        if self._drag_layer is not None:
            d = self.frame_at(e.position().x()) - self._drag_from
            self._drag_delta = max(-self._drag_layer.start, d)
            self.update()
            return
        if self._scrubbing:
            self.project.set_frame(self.frame_at(e.position().x()))
            self.ensure_frame_visible(self.project.current_frame)

    def mouseReleaseEvent(self, e):
        self._scrubbing = False
        if self._drag_layer is not None:
            layer, delta = self._drag_layer, self._drag_delta
            self._drag_layer = None
            self._drag_delta = 0
            self.unsetCursor()
            if delta:
                self.project.move_audio(layer, layer.start + delta)
            else:
                self.project.set_frame(self._drag_from)
            self.update()

    def mouseDoubleClickEvent(self, e):
        pos = e.position()
        if pos.x() > 60 and pos.x() < LAYER_W and pos.y() > HEADER_H:
            r = self.row_at(pos.y())
            if 0 <= r < len(self.project.layers):
                name, ok = QInputDialog.getText(self, "Переименовать слой", "Имя слоя:",
                                                text=self.project.layers[r].name)
                if ok:
                    self.project.rename_layer(r, name.strip())

    def wheelEvent(self, e):
        d = e.angleDelta()
        if e.modifiers() & Qt.ControlModifier:
            self.set_cell_width(self.cell_w + (2 if d.y() > 0 else -2))
        elif e.modifiers() & Qt.ShiftModifier or abs(d.x()) > abs(d.y()):
            self.hoff = max(0, self.hoff - (d.x() or d.y()) // 2)
        else:
            maxv = max(0, self.content_height() - (self.height() - HEADER_H))
            self.voff = max(0, min(maxv, self.voff - d.y() // 4))
        self.scrolled.emit()
        self.update()
        e.accept()

    def resizeEvent(self, e):
        super().resizeEvent(e)
        self.scrolled.emit()

    def set_cell_width(self, w: int):
        self.cell_w = max(10, min(48, w))
        self.scrolled.emit()
        self.update()


class Timeline(QWidget):
    """Таймлайн с панелью управления воспроизведением."""

    def __init__(self, project: Project, state: EditorState, actions: dict, parent=None):
        super().__init__(parent)
        self.setObjectName("panel")
        self.project = project
        self.state = state

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        bar = QFrame()
        bar.setStyleSheet(f"QFrame {{ background:{theme.BG_PANEL}; border-bottom:1px solid {theme.BORDER}; }}"
                          "QLabel, QToolButton { border:none; }")
        bl = QHBoxLayout(bar)
        bl.setContentsMargins(8, 4, 8, 4)
        bl.setSpacing(2)

        def btn(key):
            b = QToolButton()
            b.setDefaultAction(actions[key])
            b.setIconSize(QSize(18, 18))
            b.setAutoRaise(True)
            bl.addWidget(b)
            return b

        def sep():
            line = QFrame()
            line.setFixedSize(1, 18)
            line.setStyleSheet(f"background:{theme.BORDER};")
            bl.addSpacing(6)
            bl.addWidget(line)
            bl.addSpacing(6)

        for k in ("layer_add", "layer_duplicate", "layer_delete"):
            btn(k)
        sep()
        for k in ("key", "key_blank", "frame_insert", "frame_remove"):
            btn(k)
        sep()
        for k in ("first", "prev", "play", "next", "last", "loop"):
            btn(k)
        sep()
        btn("onion")
        sep()
        btn("record_audio")
        btn("import_audio")
        bl.addStretch()

        self.counter = QLabel()
        self.counter.setObjectName("frameCounter")
        bl.addWidget(self.counter)
        sep()
        bl.addWidget(QLabel("FPS"))
        self.fps = QSpinBox()
        self.fps.setRange(1, 60)
        self.fps.setValue(project.fps)
        self.fps.setFixedWidth(48)
        self.fps.setAlignment(Qt.AlignCenter)
        bl.addWidget(self.fps)
        bl.addSpacing(10)
        bl.addWidget(QLabel("Кадров"))
        self.length = QSpinBox()
        self.length.setRange(1, 9999)
        self.length.setFixedWidth(58)
        self.length.setAlignment(Qt.AlignCenter)
        bl.addWidget(self.length)
        sep()
        zoom_icon = QLabel()
        zoom_icon.setPixmap(icons.pixmap("zoom", theme.TEXT_MUTED, 16))
        bl.addWidget(zoom_icon)
        self.zoom = QSlider(Qt.Horizontal)
        self.zoom.setRange(10, 48)
        self.zoom.setFixedWidth(90)
        bl.addWidget(self.zoom)
        root.addWidget(bar)

        body = QHBoxLayout()
        body.setContentsMargins(0, 0, 0, 0)
        body.setSpacing(0)
        ctx = [actions[k] if k else None for k in
               ("key", "key_blank", "key_remove", None, "frame_insert", "frame_remove", None, "clear")]
        self.canvas = TimelineCanvas(project, state, ctx)
        self.vbar = QScrollBar(Qt.Vertical)
        body.addWidget(self.canvas, 1)
        body.addWidget(self.vbar)
        root.addLayout(body, 1)
        self.hbar = QScrollBar(Qt.Horizontal)
        root.addWidget(self.hbar)

        self.zoom.setValue(self.canvas.cell_w)
        self.zoom.valueChanged.connect(self.canvas.set_cell_width)
        self.hbar.valueChanged.connect(self._on_hbar)
        self.vbar.valueChanged.connect(self._on_vbar)
        self.canvas.scrolled.connect(self._sync_bars)
        self.fps.valueChanged.connect(self._on_fps)
        self.length.editingFinished.connect(lambda: project.set_frame_count(self.length.value()))
        project.frameChanged.connect(self._on_frame)
        project.structureChanged.connect(self._on_structure)
        self._on_structure()

    def _on_fps(self, v):
        if v != self.project.fps:
            self.project.fps = v
            self.project.mark_dirty()

    def _on_hbar(self, v):
        self.canvas.hoff = v
        self.canvas.update()

    def _on_vbar(self, v):
        self.canvas.voff = v
        self.canvas.update()

    def _sync_bars(self):
        c = self.canvas
        self.hbar.blockSignals(True)
        self.hbar.setRange(0, max(0, c.content_width() - c.grid_width()))
        self.hbar.setPageStep(max(1, c.grid_width()))
        self.hbar.setSingleStep(c.cell_w)
        self.hbar.setValue(c.hoff)
        self.hbar.blockSignals(False)
        vis = max(0, c.height() - HEADER_H)
        self.vbar.blockSignals(True)
        self.vbar.setRange(0, max(0, c.content_height() - vis))
        self.vbar.setPageStep(max(1, vis))
        self.vbar.setSingleStep(ROW_H)
        self.vbar.setValue(c.voff)
        self.vbar.blockSignals(False)
        self.vbar.setVisible(c.content_height() > vis)
        if self.zoom.value() != c.cell_w:
            self.zoom.blockSignals(True)
            self.zoom.setValue(c.cell_w)
            self.zoom.blockSignals(False)

    def _on_frame(self, f):
        self.counter.setText(f"{f + 1:>3} / {self.project.frame_count}")
        self.canvas.ensure_frame_visible(f)

    def _on_structure(self):
        for sb, v in ((self.length, self.project.frame_count), (self.fps, self.project.fps)):
            sb.blockSignals(True)
            sb.setValue(v)
            sb.blockSignals(False)
        self._on_frame(self.project.current_frame)
        self._sync_bars()

    def resizeEvent(self, e):
        super().resizeEvent(e)
        self._sync_bars()
