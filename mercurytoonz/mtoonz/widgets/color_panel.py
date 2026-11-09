"""Панель цвета: квадрат насыщенность/яркость, полоса тона, образцы и палитра."""

from PySide6.QtCore import QPointF, QRectF, QSize, Qt, Signal
from PySide6.QtGui import QColor, QLinearGradient, QPainter, QPen
from PySide6.QtWidgets import (
    QGridLayout, QHBoxLayout, QLabel, QLineEdit, QToolButton, QVBoxLayout, QWidget,
)

from .. import icons, theme
from ..state import EditorState

DEFAULT_PALETTE = [
    "#1b1b1f", "#4a4d55", "#9a9ea8", "#ffffff", "#7a3b1d", "#c26a35",
    "#ff8a3d", "#ffd84a", "#f2e6c9", "#9be36b", "#2f9e5b", "#5be0c4",
    "#5cc8ff", "#2c6fd6", "#24306b", "#c58cff", "#ff6fa8", "#e8404a",
]


class SVSquare(QWidget):
    changed = Signal(float, float)  # s, v в 0..1

    def __init__(self):
        super().__init__()
        self.hue = 0.0
        self.s = 1.0
        self.v = 1.0
        self.setMinimumSize(160, 80)
        self.setCursor(Qt.CrossCursor)

    def set_hsv(self, h, s, v):
        self.hue, self.s, self.v = h, s, v
        self.update()

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        r = QRectF(self.rect()).adjusted(0.5, 0.5, -0.5, -0.5)
        g = QLinearGradient(r.topLeft(), r.topRight())
        g.setColorAt(0, QColor("#ffffff"))
        g.setColorAt(1, QColor.fromHsvF(self.hue, 1, 1))
        p.setPen(Qt.NoPen)
        p.setBrush(g)
        p.drawRoundedRect(r, 6, 6)
        g2 = QLinearGradient(r.topLeft(), r.bottomLeft())
        g2.setColorAt(0, QColor(0, 0, 0, 0))
        g2.setColorAt(1, QColor(0, 0, 0, 255))
        p.setBrush(g2)
        p.drawRoundedRect(r, 6, 6)
        pt = QPointF(r.left() + self.s * r.width(), r.top() + (1 - self.v) * r.height())
        p.setBrush(Qt.NoBrush)
        p.setPen(QPen(QColor(0, 0, 0, 160), 3))
        p.drawEllipse(pt, 6, 6)
        p.setPen(QPen(QColor("#ffffff"), 1.5))
        p.drawEllipse(pt, 6, 6)

    def _pick(self, pos):
        s = min(1, max(0, pos.x() / max(1, self.width())))
        v = 1 - min(1, max(0, pos.y() / max(1, self.height())))
        self.s, self.v = s, v
        self.update()
        self.changed.emit(s, v)

    def mousePressEvent(self, e):
        self._pick(e.position())

    def mouseMoveEvent(self, e):
        if e.buttons() & Qt.LeftButton:
            self._pick(e.position())


class HueStrip(QWidget):
    changed = Signal(float)

    def __init__(self):
        super().__init__()
        self.hue = 0.0
        self.setFixedHeight(14)
        self.setCursor(Qt.PointingHandCursor)

    def set_hue(self, h):
        self.hue = h
        self.update()

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        r = QRectF(self.rect()).adjusted(0, 2, 0, -2)
        g = QLinearGradient(r.topLeft(), r.topRight())
        for i in range(7):
            g.setColorAt(i / 6, QColor.fromHsvF((i / 6) % 1.0, 1, 1))
        p.setPen(Qt.NoPen)
        p.setBrush(g)
        p.drawRoundedRect(r, 5, 5)
        x = self.hue * self.width()
        x = min(max(x, 6), self.width() - 6)
        p.setBrush(QColor.fromHsvF(self.hue, 1, 1))
        p.setPen(QPen(QColor("#ffffff"), 2))
        p.drawEllipse(QPointF(x, self.height() / 2), 6, 6)

    def _pick(self, pos):
        h = min(0.999, max(0, pos.x() / max(1, self.width())))
        self.hue = h
        self.update()
        self.changed.emit(h)

    def mousePressEvent(self, e):
        self._pick(e.position())

    def mouseMoveEvent(self, e):
        if e.buttons() & Qt.LeftButton:
            self._pick(e.position())


class ColorSwatches(QWidget):
    """Основной и дополнительный цвет внахлёст, как в графических редакторах."""

    swapRequested = Signal()

    def __init__(self, state: EditorState):
        super().__init__()
        self.state = state
        self.setFixedSize(54, 54)
        self.setToolTip("Основной / дополнительный цвет. Щелчок по заднему — поменять местами (X)")

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        back = QRectF(20, 20, 32, 32)
        front = QRectF(2, 2, 32, 32)
        for rect, c in ((back, self.state.secondary), (front, self.state.color)):
            p.setPen(QPen(QColor(theme.BORDER), 1))
            p.setBrush(c)
            p.drawRoundedRect(rect, 5, 5)
        p.setPen(QPen(QColor(theme.BG_PANEL), 2))
        p.setBrush(Qt.NoBrush)
        p.drawRoundedRect(front.adjusted(-1, -1, 1, 1), 6, 6)

    def mousePressEvent(self, e):
        if QRectF(20, 20, 32, 32).contains(e.position()) and not QRectF(2, 2, 32, 32).contains(e.position()):
            self.swapRequested.emit()


class PaletteSwatch(QToolButton):
    def __init__(self, color: str):
        super().__init__()
        self.color = QColor(color)
        self.setFixedSize(22, 22)
        self.setToolTip(color.upper())
        self.setCursor(Qt.PointingHandCursor)
        self.setStyleSheet(
            f"QToolButton {{ background:{color}; border:1px solid {theme.BORDER}; border-radius:4px; padding:0; }}"
            f"QToolButton:hover {{ border:2px solid {theme.TEXT}; }}"
        )


class ColorPanel(QWidget):
    def __init__(self, state: EditorState, parent=None):
        super().__init__(parent)
        self.setObjectName("panel")
        self.state = state
        self._hue = 0.0

        root = QVBoxLayout(self)
        root.setContentsMargins(12, 8, 12, 10)
        root.setSpacing(8)

        self.sv = SVSquare()
        self.hue = HueStrip()
        root.addWidget(self.sv, 1)
        root.addWidget(self.hue)

        row = QHBoxLayout()
        self.swatches = ColorSwatches(state)
        row.addWidget(self.swatches)
        col = QVBoxLayout()
        col.setSpacing(4)
        hexrow = QHBoxLayout()
        hexrow.addWidget(QLabel("HEX"))
        self.hex = QLineEdit()
        self.hex.setMaxLength(7)
        self.hex.setFixedWidth(84)
        hexrow.addWidget(self.hex)
        hexrow.addStretch()
        col.addLayout(hexrow)
        swap = QToolButton()
        swap.setIcon(icons.icon("swap"))
        swap.setIconSize(QSize(16, 16))
        swap.setToolTip("Поменять цвета местами (X)")
        swap.clicked.connect(state.swap_colors)
        btnrow = QHBoxLayout()
        btnrow.addWidget(swap)
        self.add_btn = QToolButton()
        self.add_btn.setIcon(icons.icon("plus"))
        self.add_btn.setIconSize(QSize(16, 16))
        self.add_btn.setToolTip("Добавить текущий цвет в палитру")
        btnrow.addWidget(self.add_btn)
        btnrow.addStretch()
        col.addLayout(btnrow)
        row.addLayout(col)
        root.addLayout(row)

        title = QLabel("ПАЛИТРА")
        title.setObjectName("sectionTitle")
        root.addWidget(title)
        self.grid = QGridLayout()
        self.grid.setSpacing(4)
        root.addLayout(self.grid)
        self._palette: list[str] = []
        for c in DEFAULT_PALETTE:
            self._add_swatch(c)

        self.sv.changed.connect(self._from_sv)
        self.hue.changed.connect(self._from_hue)
        self.hex.editingFinished.connect(self._from_hex)
        self.swatches.swapRequested.connect(state.swap_colors)
        self.add_btn.clicked.connect(lambda: self._add_swatch(state.color.name()))
        state.colorChanged.connect(self._sync)
        self._sync()

    def _add_swatch(self, color: str):
        if color in self._palette:
            return
        self._palette.append(color)
        sw = PaletteSwatch(color)
        sw.clicked.connect(lambda: self.state.set_color(sw.color))
        n = len(self._palette) - 1
        self.grid.addWidget(sw, n // 9, n % 9)

    def _sync(self):
        c = self.state.color
        h, s, v, _ = c.getHsvF()
        if h >= 0:  # у серых тон не определён — оставляем прежний
            self._hue = h
        self.sv.set_hsv(self._hue, s, v)
        self.hue.set_hue(self._hue)
        self.hex.setText(c.name().upper())
        self.swatches.update()

    def _from_sv(self, s, v):
        self.state.set_color(QColor.fromHsvF(self._hue, s, v))

    def _from_hue(self, h):
        self._hue = h
        self.sv.set_hsv(h, self.sv.s, self.sv.v)
        self.state.set_color(QColor.fromHsvF(h, self.sv.s, self.sv.v))

    def _from_hex(self):
        text = self.hex.text().strip()
        if not text.startswith("#"):
            text = "#" + text
        c = QColor(text)
        if c.isValid():
            self.state.set_color(c)
        else:
            self.hex.setText(self.state.color.name().upper())
