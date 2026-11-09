"""Окно «Настройки»: общие, графический планшет (кривая нажима, проверка пера), мышь."""

from __future__ import annotations

from PySide6.QtCore import QEvent, QPointF, QRectF, Qt, Signal
from PySide6.QtGui import QColor, QFont, QPainter, QPainterPath, QPen, QPointingDevice
from PySide6.QtWidgets import (
    QCheckBox, QDialog, QHBoxLayout, QLabel, QPushButton, QSlider, QTabWidget, QVBoxLayout, QWidget,
)

from .. import theme
from ..prefs import apply_curve, prefs

CURVES = [(0.45, "Очень мягкая"), (0.65, "Мягкая"), (1.0, "Линейная"), (1.5, "Жёсткая"), (2.2, "Очень жёсткая")]


class CurvePreview(QWidget):
    """График «нажим пера → толщина линии»; точка — текущий нажим."""

    def __init__(self):
        super().__init__()
        self.curve = 1.0
        self.floor = 0.0
        self.current: float | None = None
        self.setFixedSize(150, 150)

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        r = QRectF(self.rect()).adjusted(12, 8, -8, -16)
        p.fillRect(self.rect(), QColor(theme.BG_DEEP))
        p.setPen(QPen(QColor(theme.BORDER), 1))
        for i in range(5):
            x = r.left() + r.width() * i / 4
            y = r.top() + r.height() * i / 4
            p.drawLine(QPointF(x, r.top()), QPointF(x, r.bottom()))
            p.drawLine(QPointF(r.left(), y), QPointF(r.right(), y))
        path = QPainterPath()
        for i in range(101):
            x = i / 100
            y = apply_curve(x, self.curve, self.floor) if x > 0 else 0
            pt = QPointF(r.left() + x * r.width(), r.bottom() - y * r.height())
            path.moveTo(pt) if i == 0 else path.lineTo(pt)
        p.setPen(QPen(QColor(theme.ACCENT), 2.5))
        p.drawPath(path)
        if self.current is not None:
            y = apply_curve(self.current, self.curve, self.floor)
            pt = QPointF(r.left() + self.current * r.width(), r.bottom() - y * r.height())
            p.setPen(Qt.NoPen)
            p.setBrush(QColor("#ffffff"))
            p.drawEllipse(pt, 5, 5)
        f = QFont(self.font())
        f.setPixelSize(10)
        p.setFont(f)
        p.setPen(QColor(theme.TEXT_MUTED))
        p.drawText(QRectF(r.left(), r.bottom() + 2, r.width(), 14), Qt.AlignCenter, "нажим пера →")


class PenTestPad(QWidget):
    """Площадка, где можно порисовать пером и увидеть нажим и наклон."""

    info = Signal(str, float)

    def __init__(self):
        super().__init__()
        self.setMinimumHeight(170)
        self.setCursor(Qt.CrossCursor)
        self.points: list = []
        self.strokes: list = []
        self.curve = 1.0
        self.floor = 0.0

    def _add(self, pos, pressure):
        self.points.append((pos.x(), pos.y(), apply_curve(pressure, self.curve, self.floor)))
        self.update()

    def tabletEvent(self, e):
        kind = e.type()
        dev = "ластик" if e.pointerType() == QPointingDevice.PointerType.Eraser else "перо"
        self.info.emit(f"Нажим {e.pressure():.2f} · наклон {e.xTilt():+.0f}° / {e.yTilt():+.0f}° · {dev}",
                       e.pressure())
        if kind == QEvent.TabletPress:
            self.points = []
            self._add(e.position(), e.pressure())
        elif kind == QEvent.TabletMove and e.pressure() > 0 and self.points is not None:
            self._add(e.position(), e.pressure())
        elif kind == QEvent.TabletRelease:
            if self.points:
                self.strokes.append(self.points)
            self.points = []
        e.accept()

    def mousePressEvent(self, e):
        self.points = [(e.position().x(), e.position().y(), 0.6)]
        self.info.emit("Это мышь — нажима у неё нет. Попробуйте пером планшета.", -1)

    def mouseMoveEvent(self, e):
        if e.buttons() & Qt.LeftButton:
            self.points.append((e.position().x(), e.position().y(), 0.6))
            self.update()

    def mouseReleaseEvent(self, e):
        if self.points:
            self.strokes.append(self.points)
        self.points = []

    def clear(self):
        self.strokes, self.points = [], []
        self.update()

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        p.fillRect(self.rect(), QColor("#ffffff"))
        if not self.strokes and not self.points:
            p.setPen(QColor("#9aa0aa"))
            p.drawText(self.rect(), Qt.AlignCenter, "Порисуйте здесь пером — линия покажет, как работает нажим")
        for pts in self.strokes + [self.points]:
            for a, b in zip(pts, pts[1:]):
                w = 1 + 14 * (a[2] + b[2]) / 2
                p.setPen(QPen(QColor("#1b1b1f"), w, Qt.SolidLine, Qt.RoundCap))
                p.drawLine(QPointF(a[0], a[1]), QPointF(b[0], b[1]))
        p.setPen(QPen(QColor(theme.BORDER), 1))
        p.setBrush(Qt.NoBrush)
        p.drawRect(QRectF(self.rect()).adjusted(0.5, 0.5, -0.5, -0.5))


def _slider_row(title, lo, hi, value, fmt):
    row = QHBoxLayout()
    label = QLabel(title)
    label.setMinimumWidth(170)
    slider = QSlider(Qt.Horizontal)
    slider.setRange(lo, hi)
    slider.setValue(value)
    val = QLabel(fmt(value))
    val.setMinimumWidth(110)
    slider.valueChanged.connect(lambda v: val.setText(fmt(v)))
    row.addWidget(label)
    row.addWidget(slider, 1)
    row.addWidget(val)
    return row, slider


class PreferencesDialog(QDialog):
    showSplash = Signal()

    def __init__(self, parent=None, tab: str = "general"):
        super().__init__(parent)
        self.setWindowTitle("Настройки")
        self.resize(640, 560)
        pr = prefs()
        root = QVBoxLayout(self)
        root.setContentsMargins(18, 16, 18, 14)
        tabs = QTabWidget()
        root.addWidget(tabs, 1)

        # --- общие ---
        general = QWidget()
        gl = QVBoxLayout(general)
        gl.setSpacing(10)
        self.splash = QCheckBox("Показывать заставку при запуске")
        self.splash.setChecked(pr.get("general/splash"))
        self.sound = QCheckBox("Звук при запуске")
        self.sound.setChecked(pr.get("general/startup_sound"))
        gl.addWidget(self.splash)
        gl.addWidget(self.sound)
        show = QPushButton("Показать заставку сейчас")
        show.clicked.connect(self.showSplash.emit)
        row = QHBoxLayout()
        row.addWidget(show)
        row.addStretch()
        gl.addLayout(row)
        gl.addStretch()
        tabs.addTab(general, "Общие")

        # --- планшет ---
        tablet = QWidget()
        tl = QVBoxLayout(tablet)
        tl.setSpacing(10)
        intro = QLabel("Поддерживаются графические планшеты и перьевые экраны (Wacom, Huion, XP-Pen, Gaomon, "
                       "Surface Pen, iPad через Sidecar и другие) — через драйвер планшета или Windows Ink. "
                       "Нажим меняет толщину линии, обратный конец пера работает как ластик.")
        intro.setWordWrap(True)
        intro.setStyleSheet(f"color:{theme.TEXT_MUTED};")
        tl.addWidget(intro)
        top = QHBoxLayout()
        left = QVBoxLayout()
        curve_val = min(range(len(CURVES)), key=lambda i: abs(CURVES[i][0] - pr.get("tablet/curve")))
        row, self.curve = _slider_row("Кривая нажима", 0, len(CURVES) - 1, curve_val, lambda v: CURVES[v][1])
        left.addLayout(row)
        row, self.floor = _slider_row("Порог нажима", 0, 30, int(pr.get("tablet/min_pressure") * 100),
                                      lambda v: "нет" if v == 0 else f"{v}%")
        left.addLayout(row)
        hint = QLabel("Мягкая кривая — толстая линия даже при лёгком касании. Жёсткая — нужно сильнее давить. "
                      "Порог отсекает случайные касания.")
        hint.setWordWrap(True)
        hint.setStyleSheet(f"color:{theme.TEXT_MUTED}; font-size:12px;")
        left.addWidget(hint)
        self.pen_eraser = QCheckBox("Обратный конец пера — ластик")
        self.pen_eraser.setChecked(pr.get("tablet/pen_eraser"))
        left.addWidget(self.pen_eraser)
        left.addStretch()
        top.addLayout(left, 1)
        self.preview = CurvePreview()
        top.addWidget(self.preview)
        tl.addLayout(top)
        self.pad = PenTestPad()
        tl.addWidget(self.pad, 1)
        pad_row = QHBoxLayout()
        self.pen_label = QLabel("Перо ещё не обнаружено — коснитесь площадки.")
        self.pen_label.setStyleSheet(f"color:{theme.TEXT_MUTED};")
        clear = QPushButton("Очистить")
        clear.clicked.connect(self.pad.clear)
        pad_row.addWidget(self.pen_label, 1)
        pad_row.addWidget(clear)
        tl.addLayout(pad_row)
        tabs.addTab(tablet, "Планшет")

        # --- мышь ---
        mouse = QWidget()
        ml = QVBoxLayout(mouse)
        ml.setSpacing(10)
        txt = QLabel(
            "<b>Рисовать мышью можно комфортно.</b> Что помогает:<ul>"
            "<li><b>Стабилизатор</b> кисти — линия плавно тянется за курсором и не дрожит;</li>"
            "<li><b>Нажим мыши</b> — быстрое движение даёт тонкую линию, медленное — толстую;</li>"
            "<li><b>Сужение</b> — аккуратные «хвостики» на концах линий, как у пера;</li>"
            "<li><b>Shift</b> — ровная прямая, <b>Фигуры → Кривая</b> — плавная дуга;</li>"
            "<li>рисуйте крупнее и уменьшайте: приблизьте холст (Ctrl+колесо) для мелких деталей.</li></ul>"
            "Для штриховки и живописи с переменным нажимом всё же удобнее планшет.")
        txt.setWordWrap(True)
        ml.addWidget(txt)
        row, self.mouse_stab = _slider_row("Доп. стабилизация мыши", 0, 50, pr.get("mouse/extra_stab"),
                                           lambda v: "выкл." if v == 0 else f"+{v}%")
        ml.addLayout(row)
        mh = QLabel("Добавляется к стабилизатору кисти только при рисовании мышью; перо планшета не замедляет.")
        mh.setWordWrap(True)
        mh.setStyleSheet(f"color:{theme.TEXT_MUTED}; font-size:12px;")
        ml.addWidget(mh)
        ml.addStretch()
        tabs.addTab(mouse, "Мышь")

        buttons = QHBoxLayout()
        reset = QPushButton("Сбросить всё")
        reset.clicked.connect(self._reset)
        buttons.addWidget(reset)
        buttons.addStretch()
        close = QPushButton("Готово")
        close.setDefault(True)
        close.clicked.connect(self.accept)
        buttons.addWidget(close)
        root.addLayout(buttons)

        for w, key in ((self.splash, "general/splash"), (self.sound, "general/startup_sound"),
                       (self.pen_eraser, "tablet/pen_eraser")):
            w.toggled.connect(lambda v, k=key: pr.set(k, v))
        self.curve.valueChanged.connect(self._on_curve)
        self.floor.valueChanged.connect(self._on_curve)
        self.mouse_stab.valueChanged.connect(lambda v: pr.set("mouse/extra_stab", v))
        self.pad.info.connect(self._on_pen)
        self._on_curve()
        tabs.setCurrentIndex({"general": 0, "tablet": 1, "mouse": 2}.get(tab, 0))

    def _on_curve(self):
        c = CURVES[self.curve.value()][0]
        f = self.floor.value() / 100
        prefs().set("tablet/curve", c)
        prefs().set("tablet/min_pressure", f)
        for w in (self.preview, self.pad):
            w.curve, w.floor = c, f
        self.preview.update()

    def _on_pen(self, text, pressure):
        self.pen_label.setText(text)
        self.preview.current = pressure if pressure >= 0 else None
        self.preview.update()

    def _reset(self):
        prefs().reset()
        pr = prefs()
        self.splash.setChecked(pr.get("general/splash"))
        self.sound.setChecked(pr.get("general/startup_sound"))
        self.pen_eraser.setChecked(pr.get("tablet/pen_eraser"))
        self.curve.setValue(min(range(len(CURVES)), key=lambda i: abs(CURVES[i][0] - pr.get("tablet/curve"))))
        self.floor.setValue(int(pr.get("tablet/min_pressure") * 100))
        self.mouse_stab.setValue(pr.get("mouse/extra_stab"))
