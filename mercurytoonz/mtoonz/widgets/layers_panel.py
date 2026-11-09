"""Панель «Слои»: рисованные слои с миниатюрами, видимостью, блокировкой и прозрачностью.

Слой выбирается щелчком, переименовывается двойным щелчком, порядок меняется перетаскиванием.
"""

from __future__ import annotations

from PySide6.QtCore import QPointF, QRectF, QSize, Qt
from PySide6.QtGui import QColor, QFont, QPainter, QPen
from PySide6.QtWidgets import (
    QHBoxLayout, QInputDialog, QLabel, QMenu, QScrollArea, QSlider, QSpinBox, QToolButton,
    QVBoxLayout, QWidget,
)

from .. import icons, theme
from ..model import Project
from ..render import render_thumb

ROW_H = 44
THUMB_W, THUMB_H = 52, 32


class LayerList(QWidget):
    def __init__(self, project: Project):
        super().__init__()
        self.project = project
        self._thumbs: dict = {}
        self._press_row = -1
        self._drop_row = -1
        self.setMouseTracking(True)
        for sig in (project.structureChanged, project.contentChanged):
            sig.connect(self._changed)
        project.frameChanged.connect(lambda _: self.update())
        project.layerChanged.connect(lambda _: self.update())

    def _changed(self):
        self.setMinimumHeight(len(self.project.layers) * ROW_H + 2)
        self.update()

    def sizeHint(self):
        return QSize(260, len(self.project.layers) * ROW_H + 2)

    def _thumb(self, layer):
        d = layer.drawing_at(self.project.current_frame)
        key = (layer.id, id(d), len(d.strokes) if d else 0, self.project.width, self.project.height)
        img = self._thumbs.get(key)
        if img is None:
            if len(self._thumbs) > 200:
                self._thumbs.clear()
            img = render_thumb(self.project, d, THUMB_W, THUMB_H)
            self._thumbs[key] = img
        return img

    def paintEvent(self, _):
        p = QPainter(self)
        p.fillRect(self.rect(), QColor(theme.BG_PANEL))
        proj = self.project
        f = proj.current_frame
        for r, layer in enumerate(proj.layers):
            y = r * ROW_H
            cur = r == proj.current_layer
            p.fillRect(QRectF(0, y, self.width(), ROW_H), QColor("#2a2f38" if cur else theme.BG_PANEL))
            if cur:
                p.fillRect(QRectF(0, y, 3, ROW_H), QColor(theme.ACCENT))
            cy = y + ROW_H / 2
            p.drawPixmap(QPointF(10, cy - 8), icons.pixmap("eye" if layer.visible else "eye-off",
                                                          theme.TEXT if layer.visible else theme.TEXT_MUTED, 16))
            p.drawPixmap(QPointF(32, cy - 8), icons.pixmap("lock" if layer.locked else "unlock",
                                                          theme.ACCENT if layer.locked else theme.TEXT_MUTED, 16))
            # миниатюра на «бумаге»
            tr = QRectF(56, cy - THUMB_H / 2, THUMB_W, THUMB_H)
            p.fillRect(tr, proj.background)
            p.drawImage(tr, self._thumb(layer))
            p.setPen(QPen(QColor(theme.ACCENT) if cur else QColor(theme.BORDER), 1))
            p.setBrush(Qt.NoBrush)
            p.drawRect(tr.adjusted(-0.5, -0.5, 0.5, 0.5))
            # имя и подпись
            font = QFont(self.font())
            font.setBold(cur)
            p.setFont(font)
            p.setPen(QColor(theme.TEXT if layer.visible else theme.TEXT_MUTED))
            text_x = tr.right() + 10
            avail = self.width() - text_x - 10
            p.drawText(QRectF(text_x, y + 5, avail, 18), Qt.AlignLeft | Qt.AlignVCenter,
                       p.fontMetrics().elidedText(layer.name, Qt.ElideRight, int(avail)))
            font.setBold(False)
            font.setPixelSize(11)
            p.setFont(font)
            p.setPen(QColor(theme.TEXT_MUTED))
            if hasattr(layer, "raw"):
                sub = "не поддерживается"
            else:
                sub = f"{len(layer.keys)} ключ. кадров"
                if f in layer.keys:
                    sub = "● ключ на этом кадре · " + sub
                if layer.opacity < 1:
                    sub += f" · {round(layer.opacity * 100)}%"
            p.drawText(QRectF(text_x, y + 22, avail, 16), Qt.AlignLeft | Qt.AlignVCenter,
                       p.fontMetrics().elidedText(sub, Qt.ElideRight, int(avail)))
            # цветная метка слоя
            p.setRenderHint(QPainter.Antialiasing)
            p.setPen(Qt.NoPen)
            p.setBrush(QColor(layer.tag))
            p.drawEllipse(QPointF(self.width() - 12, cy), 3.5, 3.5)
            p.setRenderHint(QPainter.Antialiasing, False)
            p.setPen(QColor(theme.BORDER))
            p.drawLine(QPointF(0, y + ROW_H - 0.5), QPointF(self.width(), y + ROW_H - 0.5))
        if self._drop_row >= 0 and self._drop_row != self._press_row:
            y = self._drop_row * ROW_H + (ROW_H if self._drop_row > self._press_row else 0)
            p.fillRect(QRectF(0, y - 1.5, self.width(), 3), QColor(theme.ACCENT))
        p.end()

    def _row(self, y) -> int:
        return int(y // ROW_H)

    def mousePressEvent(self, e):
        r = self._row(e.position().y())
        proj = self.project
        if not (0 <= r < len(proj.layers)):
            return
        layer = proj.layers[r]
        x = e.position().x()
        if e.button() == Qt.LeftButton and 6 <= x <= 28:
            layer.visible = not layer.visible
            proj.mark_dirty()
            proj.contentChanged.emit()
            return
        if e.button() == Qt.LeftButton and 28 < x <= 50:
            layer.locked = not layer.locked
            proj.mark_dirty()
            self.update()
            return
        proj.set_layer(r)
        if e.button() == Qt.LeftButton:
            self._press_row = r
        elif e.button() == Qt.RightButton:
            win = self.window()
            menu = QMenu(self)
            for k in ("layer_add", "layer_duplicate", "layer_rename", None, "layer_up", "layer_down", None,
                      "layer_delete"):
                if k is None:
                    menu.addSeparator()
                elif hasattr(win, "actions") and k in win.actions:
                    menu.addAction(win.actions[k])
            menu.exec(e.globalPosition().toPoint())

    def mouseMoveEvent(self, e):
        if self._press_row >= 0 and e.buttons() & Qt.LeftButton:
            r = max(0, min(len(self.project.layers) - 1, self._row(e.position().y())))
            if r != self._drop_row:
                self._drop_row = r
                self.setCursor(Qt.ClosedHandCursor)
                self.update()

    def mouseReleaseEvent(self, e):
        src, dst = self._press_row, self._drop_row
        self._press_row = self._drop_row = -1
        self.unsetCursor()
        if src >= 0 and dst >= 0 and src != dst:
            self.project.move_layer_to(src, dst)
        self.update()

    def mouseDoubleClickEvent(self, e):
        r = self._row(e.position().y())
        if 0 <= r < len(self.project.layers) and e.position().x() > 50:
            name, ok = QInputDialog.getText(self, "Переименовать слой", "Имя слоя:",
                                            text=self.project.layers[r].name)
            if ok:
                self.project.rename_layer(r, name.strip())


class LayersPanel(QWidget):
    def __init__(self, project: Project, actions: dict, parent=None):
        super().__init__(parent)
        self.project = project
        self.setObjectName("panel")
        self.setAttribute(Qt.WA_StyledBackground)
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        bar = QHBoxLayout()
        bar.setContentsMargins(8, 4, 8, 4)
        bar.setSpacing(2)
        for k in ("layer_add", "layer_duplicate", "layer_up", "layer_down", "layer_delete"):
            b = QToolButton()
            b.setDefaultAction(actions[k])
            b.setIconSize(QSize(16, 16))
            b.setAutoRaise(True)
            bar.addWidget(b)
            if k == "layer_duplicate":
                bar.addSpacing(6)
        bar.addStretch()
        root.addLayout(bar)

        self.list = LayerList(project)
        scroll = QScrollArea()
        scroll.setWidget(self.list)
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll.setStyleSheet(f"QScrollArea, QScrollArea > QWidget > QWidget {{ background:{theme.BG_PANEL}; }}"
                             f"QScrollArea {{ border-top:1px solid {theme.BORDER}; }}")
        root.addWidget(scroll, 1)

        op = QHBoxLayout()
        op.setContentsMargins(10, 6, 10, 8)
        op.addWidget(QLabel("Непрозрачность"))
        self.opacity = QSlider(Qt.Horizontal)
        self.opacity.setRange(0, 100)
        op.addWidget(self.opacity, 1)
        self.opacity_spin = QSpinBox()
        self.opacity_spin.setRange(0, 100)
        self.opacity_spin.setSuffix(" %")
        self.opacity_spin.setFixedWidth(60)
        self.opacity_spin.setAlignment(Qt.AlignRight)
        op.addWidget(self.opacity_spin)
        root.addLayout(op)

        self.opacity.valueChanged.connect(self.opacity_spin.setValue)
        self.opacity_spin.valueChanged.connect(self.opacity.setValue)
        self.opacity_spin.valueChanged.connect(self._set_opacity)
        project.layerChanged.connect(lambda _: self._sync())
        project.structureChanged.connect(self._sync)
        self._sync()

    def _sync(self):
        layer = self.project.layer()
        v = round((layer.opacity if layer else 1.0) * 100)
        for w in (self.opacity, self.opacity_spin):
            w.blockSignals(True)
            w.setValue(v)
            w.blockSignals(False)
        self.list._changed()

    def _set_opacity(self, v):
        layer = self.project.layer()
        if layer is not None and round(layer.opacity * 100) != v:
            layer.opacity = v / 100
            self.project.mark_dirty()
            self.project.contentChanged.emit()
