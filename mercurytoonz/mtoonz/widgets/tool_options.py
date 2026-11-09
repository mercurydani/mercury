"""Панель настроек активного инструмента: библиотека кистей и параметры."""

from functools import lru_cache

from PySide6.QtCore import QSize, Qt
from PySide6.QtGui import QColor, QIcon, QImage, QPainter, QPixmap
from PySide6.QtWidgets import (
    QCheckBox, QComboBox, QGridLayout, QHBoxLayout, QLabel, QListWidget, QListWidgetItem,
    QSlider, QSpinBox, QVBoxLayout, QWidget,
)

from .. import icons, theme
from ..brushes import ERASER_PRESETS, PRESETS, draw_brush_stroke, preview_points
from ..state import BRUSH_TOOLS, TOOLS_BY_KEY, EditorState

TOOL_HINTS = {
    "brush": "Shift — прямая линия. Стабилизатор убирает дрожание мыши, нажим от скорости делает линию живой.",
    "pencil": "Shift — прямая линия.",
    "eraser": "Shift — стереть по прямой.",
    "shapes": "Shift — ровный квадрат / круг / угол 45°. «Кривая»: протяните линию, затем изогните мышью и щёлкните.",
    "select": "Выделение области кадра. Скоро.",
    "transform": "Выберите клип или слой щелчком. Внутри рамки — двигать, углы — масштаб (Shift — свободно), "
                 "края — растянуть, кружок сверху — поворот (Shift — шаг 15°). Ctrl+угол — деформация, "
                 "Alt+край — наклон. Если свойство анимировано, изменение ставит ключевой кадр.",
    "curve": "Как в Paint Tool SAI: щёлкайте — линия плавно пройдёт через все точки. Enter, двойной щелчок "
             "или правая кнопка — готово; Backspace — убрать точку; Esc — отмена. Рисует выбранной кистью.",
    "fill": "Заливка замкнутых областей. Скоро.",
    "eyedropper": "Щёлкните по холсту, чтобы взять цвет.",
    "hand": "Перетаскивайте холст. В любом инструменте — зажатый пробел или средняя кнопка мыши.",
    "zoom": "Щелчок — приблизить, Alt+щелчок или ПКМ — отдалить. Колесо — плавный масштаб.",
}

PREVIEW = QSize(110, 34)


@lru_cache(maxsize=64)
def brush_preview(key: str) -> QIcon:
    preset = next(p for p in PRESETS + ERASER_PRESETS if p.key == key)
    dpr = 2
    img = QImage(PREVIEW.width() * dpr, PREVIEW.height() * dpr, QImage.Format_ARGB32_Premultiplied)
    img.setDevicePixelRatio(dpr)
    img.fill(Qt.transparent)
    p = QPainter(img)
    p.setRenderHint(QPainter.Antialiasing)
    size = min(preset.size, 16) if preset.params.kind != "pixel" else 3
    p.setOpacity(preset.opacity)
    draw_brush_stroke(p, preview_points(PREVIEW.width(), PREVIEW.height()), QColor(theme.TEXT),
                      size, preset.params, preset.pressure or preset.speed > 0, False)
    p.end()
    return QIcon(QPixmap.fromImage(img))


class _SliderRow:
    """Ползунок + числовое поле."""

    def __init__(self, grid: QGridLayout, row: int, title: str, lo: int, hi: int, suffix: str = "",
                 tip: str = ""):
        self.label = QLabel(title)
        self.label.setToolTip(tip)
        self.slider = QSlider(Qt.Horizontal)
        self.slider.setRange(lo, hi)
        self.slider.setToolTip(tip)
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

        # библиотека кистей
        self.brush_title = QLabel("КИСТИ")
        self.brush_title.setObjectName("sectionTitle")
        root.addWidget(self.brush_title)
        self.brushes = QListWidget()
        self.brushes.setIconSize(PREVIEW)
        self.brushes.setSpacing(1)
        self.brushes.setStyleSheet(
            f"QListWidget {{ background:{theme.BG_DEEP}; border:1px solid {theme.BORDER}; border-radius:6px; "
            f"outline:none; padding:2px; }}"
            f"QListWidget::item {{ padding:2px 4px; border-radius:4px; }}"
            f"QListWidget::item:hover {{ background:{theme.BG_HOVER}; }}"
            f"QListWidget::item:selected {{ background:{theme.ACCENT_DIM}; color:{theme.TEXT}; }}"
        )
        self.brushes.setMinimumHeight(170)
        root.addWidget(self.brushes, 1)

        grid = QGridLayout()
        grid.setHorizontalSpacing(10)
        grid.setVerticalSpacing(7)
        grid.setColumnStretch(1, 1)
        self.size = _SliderRow(grid, 0, "Размер", 1, 300, " px")
        self.opacity = _SliderRow(grid, 1, "Непрозрачн.", 1, 100, " %")
        self.stab = _SliderRow(grid, 2, "Стабилизатор", 0, 100, " %",
                               "Кисть плавно «тянется» за курсором — линия не дрожит даже мышкой")
        self.smooth = _SliderRow(grid, 3, "Сглаживание", 0, 100, " %",
                                 "Дополнительное выравнивание линии после отпускания кнопки")
        self.speed = _SliderRow(grid, 4, "Нажим мыши", 0, 100, " %",
                                "Быстрое движение мыши — тоньше линия, медленное — толще (имитация пера)")
        self.taper = _SliderRow(grid, 5, "Сужение", 0, 100, " %",
                                "Сужение линии в начале и в конце. 50% — как задумано в кисти")
        self.shape_label = QLabel("Фигура")
        self.shape = QComboBox()
        for title, key in (("Линия", "line"), ("Кривая", "curve"), ("Прямоугольник", "rect"), ("Эллипс", "ellipse")):
            self.shape.addItem(title, key)
        grid.addWidget(self.shape_label, 6, 0)
        grid.addWidget(self.shape, 6, 1, 1, 2)
        root.addLayout(grid)

        self.pressure = QCheckBox("Учитывать нажим пера и мыши")
        root.addWidget(self.pressure)

        self.hint = QLabel()
        self.hint.setWordWrap(True)
        self.hint.setStyleSheet(f"color:{theme.TEXT_MUTED}; font-size:12px;")
        root.addWidget(self.hint)
        self.stretch = QWidget()
        root.addWidget(self.stretch, 1)

        self.size.spin.valueChanged.connect(lambda v: self._set("size", float(v)))
        self.opacity.spin.valueChanged.connect(lambda v: self._set("opacity", v / 100))
        self.stab.spin.valueChanged.connect(lambda v: self._set("stabilizer", v))
        self.smooth.spin.valueChanged.connect(lambda v: self._set("smoothing", v))
        self.speed.spin.valueChanged.connect(lambda v: self._set("speed", v))
        self.taper.spin.valueChanged.connect(lambda v: self._set("taper", v))
        self.pressure.toggled.connect(lambda v: self._set("pressure", v))
        self.shape.currentIndexChanged.connect(lambda _: self._set("shape", self.shape.currentData()))
        self.brushes.currentItemChanged.connect(self._on_brush)

        state.toolChanged.connect(lambda _: self.refresh())
        state.settingsChanged.connect(self._sync_values)
        self._list_for = None
        self.refresh()

    def _set(self, attr: str, value):
        st = self.state.tool_settings()
        if st is not None and getattr(st, attr) != value:
            setattr(st, attr, value)
            self.state.settingsChanged.emit()

    def _on_brush(self, item, _prev=None):
        if item is not None:
            self.state.set_preset(item.data(Qt.UserRole))

    def _fill_brushes(self):
        tool = self.state.tool
        presets = ERASER_PRESETS if tool == "eraser" else PRESETS
        if self._list_for == ("eraser" if tool == "eraser" else "brush"):
            return
        self._list_for = "eraser" if tool == "eraser" else "brush"
        self.brushes.blockSignals(True)
        self.brushes.clear()
        group = None
        for preset in presets:
            if preset.group != group and tool != "eraser":
                group = preset.group
                header = QListWidgetItem(group.upper())
                header.setFlags(Qt.NoItemFlags)
                header.setForeground(QColor(theme.TEXT_MUTED))
                f = header.font()
                f.setPixelSize(10)
                f.setBold(True)
                header.setFont(f)
                self.brushes.addItem(header)
            it = QListWidgetItem(brush_preview(preset.key), preset.name)
            it.setData(Qt.UserRole, preset.key)
            self.brushes.addItem(it)
        self.brushes.blockSignals(False)

    def refresh(self):
        tool = self.state.tool
        info = TOOLS_BY_KEY[tool]
        self.icon.setPixmap(icons.pixmap(info.icon, theme.ACCENT, 20))
        self.title.setText(info.title)
        self.shortcut.setText(info.shortcut)
        st = self.state.tool_settings()
        has = st is not None
        has_brush = tool in BRUSH_TOOLS
        if has_brush:
            self._fill_brushes()
        self.brush_title.setVisible(has_brush)
        self.brushes.setVisible(has_brush)
        self.stretch.setVisible(not has_brush)
        self.size.set_visible(has)
        self.opacity.set_visible(has and tool != "eraser")
        for row in (self.stab, self.smooth, self.speed, self.taper):
            row.set_visible(has_brush)
        self.pressure.setVisible(has_brush)
        is_shape = tool == "shapes"
        self.shape_label.setVisible(is_shape)
        self.shape.setVisible(is_shape)
        self.hint.setText(TOOL_HINTS.get(tool, ""))
        self.hint.setVisible(tool in TOOL_HINTS)
        self._sync_values()

    def _sync_values(self):
        st = self.state.tool_settings()
        if st is None:
            return
        self.size.set_value(int(st.size))
        self.opacity.set_value(int(round(st.opacity * 100)))
        self.stab.set_value(st.stabilizer)
        self.smooth.set_value(st.smoothing)
        self.speed.set_value(st.speed)
        self.taper.set_value(st.taper)
        for w, v in ((self.pressure, st.pressure),):
            w.blockSignals(True)
            w.setChecked(v)
            w.blockSignals(False)
        self.shape.blockSignals(True)
        self.shape.setCurrentIndex(max(0, self.shape.findData(st.shape)))
        self.shape.blockSignals(False)
        if self.brushes.isVisible() or self.state.tool in BRUSH_TOOLS:
            self.brushes.blockSignals(True)
            for i in range(self.brushes.count()):
                it = self.brushes.item(i)
                if it.data(Qt.UserRole) == st.brush:
                    self.brushes.setCurrentItem(it)
                    break
            self.brushes.blockSignals(False)
