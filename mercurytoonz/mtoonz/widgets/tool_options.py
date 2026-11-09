"""Панель настроек активного инструмента."""

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QCheckBox, QComboBox, QGridLayout, QHBoxLayout, QLabel, QSlider, QSpinBox,
    QVBoxLayout, QWidget,
)

from .. import icons, theme
from ..state import TOOLS_BY_KEY, EditorState

TOOL_HINTS = {
    "select": "Выделение области кадра. Скоро.",
    "transform": "Перемещение, поворот и масштаб. Скоро.",
    "fill": "Заливка замкнутых областей. Скоро.",
    "eyedropper": "Щёлкните по холсту, чтобы взять цвет.",
    "hand": "Перетаскивайте холст. В любом инструменте — зажатый пробел или средняя кнопка мыши.",
    "zoom": "Щелчок — приблизить, Alt+щелчок или ПКМ — отдалить. Колесо — плавный масштаб.",
}


class _SliderRow:
    """Ползунок + числовое поле."""

    def __init__(self, grid: QGridLayout, row: int, title: str, lo: int, hi: int, suffix: str = ""):
        self.label = QLabel(title)
        self.slider = QSlider(Qt.Horizontal)
        self.slider.setRange(lo, hi)
        self.spin = QSpinBox()
        self.spin.setRange(lo, hi)
        self.spin.setSuffix(suffix)
        self.spin.setFixedWidth(64)
        self.spin.setAlignment(Qt.AlignRight)
        self.slider.valueChanged.connect(self.spin.setValue)
        self.spin.valueChanged.connect(self.slider.setValue)
        grid.addWidget(self.label, row, 0)
        grid.addWidget(self.slider, row, 1)
        grid.addWidget(self.spin, row, 2)

    def set_visible(self, v: bool):
        for w in (self.label, self.slider, self.spin):
            w.setVisible(v)

    def set_value(self, v: int):
        self.slider.blockSignals(True)
        self.spin.blockSignals(True)
        self.slider.setValue(v)
        self.spin.setValue(v)
        self.slider.blockSignals(False)
        self.spin.blockSignals(False)


class ToolOptions(QWidget):
    def __init__(self, state: EditorState, parent=None):
        super().__init__(parent)
        self.setObjectName("panel")
        self.state = state

        root = QVBoxLayout(self)
        root.setContentsMargins(12, 10, 12, 12)
        root.setSpacing(10)

        head = QHBoxLayout()
        self.icon = QLabel()
        self.title = QLabel()
        self.title.setStyleSheet("font-size: 15px; font-weight: 600;")
        self.shortcut = QLabel()
        self.shortcut.setStyleSheet(
            f"color:{theme.TEXT_MUTED}; border:1px solid {theme.BORDER}; border-radius:4px; padding:1px 6px;"
        )
        head.addWidget(self.icon)
        head.addWidget(self.title)
        head.addStretch()
        head.addWidget(self.shortcut)
        root.addLayout(head)

        grid = QGridLayout()
        grid.setHorizontalSpacing(10)
        grid.setVerticalSpacing(8)
        grid.setColumnStretch(1, 1)
        self.size = _SliderRow(grid, 0, "Размер", 1, 300, " px")
        self.opacity = _SliderRow(grid, 1, "Непрозрачн.", 1, 100, " %")
        self.smooth = _SliderRow(grid, 2, "Сглаживание", 0, 100, " %")
        self.shape_label = QLabel("Фигура")
        self.shape = QComboBox()
        self.shape.addItem("Линия", "line")
        self.shape.addItem("Прямоугольник", "rect")
        self.shape.addItem("Эллипс", "ellipse")
        grid.addWidget(self.shape_label, 3, 0)
        grid.addWidget(self.shape, 3, 1, 1, 2)
        root.addLayout(grid)

        self.pressure = QCheckBox("Учитывать нажим пера")
        root.addWidget(self.pressure)

        self.hint = QLabel()
        self.hint.setWordWrap(True)
        self.hint.setStyleSheet(f"color:{theme.TEXT_MUTED};")
        root.addWidget(self.hint)
        root.addStretch()

        self.size.spin.valueChanged.connect(lambda v: self._set("size", float(v)))
        self.opacity.spin.valueChanged.connect(lambda v: self._set("opacity", v / 100))
        self.smooth.spin.valueChanged.connect(lambda v: self._set("smoothing", v))
        self.pressure.toggled.connect(lambda v: self._set("pressure", v))
        self.shape.currentIndexChanged.connect(lambda _: self._set("shape", self.shape.currentData()))

        state.toolChanged.connect(lambda _: self.refresh())
        self.refresh()

    def _set(self, attr: str, value):
        st = self.state.tool_settings()
        if st is not None:
            setattr(st, attr, value)
            self.state.settingsChanged.emit()

    def refresh(self):
        info = TOOLS_BY_KEY[self.state.tool]
        self.icon.setPixmap(icons.pixmap(info.icon, theme.ACCENT, 20))
        self.title.setText(info.title)
        self.shortcut.setText(info.shortcut)
        st = self.state.tool_settings()
        has = st is not None
        self.size.set_visible(has)
        self.opacity.set_visible(has and self.state.tool != "eraser")
        self.smooth.set_visible(has and self.state.tool != "shapes")
        self.pressure.setVisible(has and self.state.tool != "shapes")
        is_shape = self.state.tool == "shapes"
        self.shape_label.setVisible(is_shape)
        self.shape.setVisible(is_shape)
        self.hint.setText(TOOL_HINTS.get(self.state.tool, ""))
        self.hint.setVisible(self.state.tool in TOOL_HINTS)
        if has:
            self.size.set_value(int(st.size))
            self.opacity.set_value(int(round(st.opacity * 100)))
            self.smooth.set_value(st.smoothing)
            self.pressure.blockSignals(True)
            self.pressure.setChecked(st.pressure)
            self.pressure.blockSignals(False)
            self.shape.blockSignals(True)
            self.shape.setCurrentIndex(max(0, self.shape.findData(st.shape)))
            self.shape.blockSignals(False)
