"""Состояние редактора: активный инструмент, цвета, настройки кистей, луковая кожа."""

from dataclasses import dataclass

from PySide6.QtCore import QObject, Signal
from PySide6.QtGui import QColor

from .brushes import ERASER_BY_KEY, PRESETS_BY_KEY


@dataclass
class ToolSettings:
    size: float = 6.0
    opacity: float = 1.0
    smoothing: int = 30       # сглаживание после отпускания, 0..100
    stabilizer: int = 20      # «ленивая кисть» во время рисования, 0..100
    speed: int = 0            # утончение линии от скорости мыши, 0..100
    taper: int = 50           # сужение концов: 50 — как задумано в кисти
    pressure: bool = True
    shape: str = "line"       # для инструмента «Фигуры»: line / curve / rect / ellipse
    brush: str = ""           # ключ кисти из brushes.PRESETS / ERASER_PRESETS

    def apply_preset(self, preset):
        self.brush = preset.key
        self.size = float(preset.size)
        self.opacity = preset.opacity
        self.stabilizer = preset.stabilizer
        self.smoothing = preset.smoothing
        self.speed = preset.speed
        self.pressure = preset.pressure
        self.taper = 50


@dataclass(frozen=True)
class ToolInfo:
    key: str
    title: str
    icon: str
    shortcut: str
    draws: bool = False   # оставляет мазки
    sized: bool = False   # есть размер


TOOLS = [
    ToolInfo("select", "Выделение", "select", "V"),
    ToolInfo("transform", "Трансформация", "transform", "Q"),
    ToolInfo("brush", "Кисть", "brush", "B", draws=True, sized=True),
    ToolInfo("pencil", "Карандаш", "pencil", "P", draws=True, sized=True),
    ToolInfo("eraser", "Ластик", "eraser", "E", draws=True, sized=True),
    ToolInfo("fill", "Заливка", "fill", "G"),
    ToolInfo("shapes", "Фигуры", "shapes", "U", draws=True, sized=True),
    ToolInfo("eyedropper", "Пипетка", "eyedropper", "I"),
    ToolInfo("hand", "Рука", "hand", "H"),
    ToolInfo("zoom", "Масштаб", "zoom", "Z"),
]
TOOLS_BY_KEY = {t.key: t for t in TOOLS}

# Разделители в панели инструментов ставятся перед этими инструментами
TOOL_GROUP_STARTS = {"brush", "fill", "eyedropper"}


class EditorState(QObject):
    toolChanged = Signal(str)
    colorChanged = Signal()
    settingsChanged = Signal()
    onionChanged = Signal()

    def __init__(self):
        super().__init__()
        self.tool = "brush"
        self.color = QColor("#1b1b1f")
        self.secondary = QColor("#ffffff")
        self.settings = {
            "brush": ToolSettings(),
            "pencil": ToolSettings(),
            "eraser": ToolSettings(),
            "shapes": ToolSettings(size=4, smoothing=0, stabilizer=0, pressure=False),
        }
        self.settings["brush"].apply_preset(PRESETS_BY_KEY["ink"])
        self.settings["pencil"].apply_preset(PRESETS_BY_KEY["pencil_hb"])
        self.settings["eraser"].apply_preset(ERASER_BY_KEY["eraser_hard"])
        self.onion = True
        self.onion_prev = 2
        self.onion_next = 1
        self.loop = True

    def tool_settings(self, tool: str | None = None) -> ToolSettings | None:
        return self.settings.get(tool or self.tool)

    def preset(self, tool: str | None = None):
        """Выбранная кисть инструмента (или None для инструментов без кистей)."""
        tool = tool or self.tool
        st = self.settings.get(tool)
        if st is None or tool == "shapes":
            return None
        table = ERASER_BY_KEY if tool == "eraser" else PRESETS_BY_KEY
        return table.get(st.brush)

    def set_preset(self, key: str):
        st = self.tool_settings()
        table = ERASER_BY_KEY if self.tool == "eraser" else PRESETS_BY_KEY
        if st is not None and key in table:
            st.apply_preset(table[key])
            self.settingsChanged.emit()

    def set_tool(self, tool: str):
        if tool != self.tool:
            self.tool = tool
            self.toolChanged.emit(tool)

    def set_color(self, color: QColor):
        if color.isValid() and color != self.color:
            self.color = QColor(color)
            self.colorChanged.emit()

    def swap_colors(self):
        self.color, self.secondary = self.secondary, self.color
        self.colorChanged.emit()

    def set_onion(self, on: bool):
        if on != self.onion:
            self.onion = on
            self.onionChanged.emit()
