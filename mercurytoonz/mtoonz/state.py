"""Состояние редактора: активный инструмент, цвета, настройки кистей, луковая кожа."""

from dataclasses import dataclass

from PySide6.QtCore import QObject, Signal
from PySide6.QtGui import QColor


@dataclass
class ToolSettings:
    size: float = 6.0
    opacity: float = 1.0
    smoothing: int = 30       # 0..100
    pressure: bool = True
    shape: str = "line"       # для инструмента «Фигуры»: line / rect / ellipse


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
            "brush": ToolSettings(size=8, smoothing=40),
            "pencil": ToolSettings(size=2, smoothing=10),
            "eraser": ToolSettings(size=24, smoothing=10, pressure=False),
            "shapes": ToolSettings(size=4, smoothing=0, pressure=False),
        }
        self.onion = True
        self.onion_prev = 2
        self.onion_next = 1
        self.loop = True

    def tool_settings(self, tool: str | None = None) -> ToolSettings | None:
        return self.settings.get(tool or self.tool)

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
