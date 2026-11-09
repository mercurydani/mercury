"""Модель проекта: слои, ключевые кадры, рисунки, история правок.

Кадры нумеруются с 0. На слое хранятся только ключевые кадры (`Layer.keys`);
рисунок ключевого кадра «держится» на всех следующих кадрах до следующего ключа
или до конца сцены — так же, как экспозиция в классической анимации.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from PySide6.QtCore import QObject, Signal
from PySide6.QtGui import QColor, QUndoCommand, QUndoStack


@dataclass(frozen=True)
class Stroke:
    """Один мазок. После создания не меняется, поэтому его можно разделять между копиями."""

    points: tuple  # ((x, y, pressure), ...) в координатах сцены
    color: QColor
    width: float
    opacity: float = 1.0
    erase: bool = False
    use_pressure: bool = False


@dataclass
class Drawing:
    strokes: list = field(default_factory=list)

    def is_empty(self) -> bool:
        return not self.strokes

    def copy(self) -> "Drawing":
        return Drawing(list(self.strokes))


LAYER_TAGS = ["#ff8a3d", "#5cc8ff", "#9be36b", "#ffd84a", "#c58cff", "#ff6fa8", "#5be0c4"]


class Layer:
    _counter = 0

    def __init__(self, name: str):
        self.name = name
        self.visible = True
        self.locked = False
        self.opacity = 1.0
        self.tag = LAYER_TAGS[Layer._counter % len(LAYER_TAGS)]
        Layer._counter += 1
        self.keys: dict[int, Drawing] = {}

    def key_at_or_before(self, frame: int) -> int | None:
        best = None
        for k in self.keys:
            if k <= frame and (best is None or k > best):
                best = k
        return best

    def next_key_after(self, frame: int) -> int | None:
        best = None
        for k in self.keys:
            if k > frame and (best is None or k < best):
                best = k
        return best

    def drawing_at(self, frame: int) -> Drawing | None:
        k = self.key_at_or_before(frame)
        return None if k is None else self.keys[k]

    def sorted_keys(self) -> list[int]:
        return sorted(self.keys)


class Project(QObject):
    contentChanged = Signal()      # изменились рисунки — перерисовать холст
    structureChanged = Signal()    # слои / ключи / длина сцены
    frameChanged = Signal(int)
    layerChanged = Signal(int)

    def __init__(self):
        super().__init__()
        self.width = 1920
        self.height = 1080
        self.fps = 24
        self.frame_count = 48
        self.layers: list[Layer] = []  # индекс 0 — верхний слой
        self.current_frame = 0
        self.current_layer = 0
        self.undo_stack = QUndoStack(self)
        self.reset()

    # ---------- состояние ----------
    def reset(self):
        Layer._counter = 0
        self.layers = [Layer("Слой 1")]
        self.layers[0].keys[0] = Drawing()
        self.current_frame = 0
        self.current_layer = 0
        self.undo_stack.clear()
        self.structureChanged.emit()
        self.frameChanged.emit(0)
        self.layerChanged.emit(0)

    def layer(self) -> Layer | None:
        if 0 <= self.current_layer < len(self.layers):
            return self.layers[self.current_layer]
        return None

    def set_frame(self, frame: int):
        frame = max(0, min(frame, self.frame_count - 1))
        if frame != self.current_frame:
            self.current_frame = frame
            self.frameChanged.emit(frame)

    def set_layer(self, index: int):
        index = max(0, min(index, len(self.layers) - 1))
        if index != self.current_layer:
            self.current_layer = index
            self.layerChanged.emit(index)

    # ---------- история ----------
    def _snapshot(self):
        return {
            "layers": [(l, l.name, {k: d.copy() for k, d in l.keys.items()}) for l in self.layers],
            "frame_count": self.frame_count,
            "current_layer": self.current_layer,
        }

    def _restore(self, snap):
        self.layers = []
        for layer, name, keys in snap["layers"]:
            layer.name = name
            layer.keys = {k: d.copy() for k, d in keys.items()}
            self.layers.append(layer)
        self.frame_count = snap["frame_count"]
        self.current_layer = min(snap["current_layer"], len(self.layers) - 1)
        self.current_frame = min(self.current_frame, self.frame_count - 1)
        self.structureChanged.emit()
        self.contentChanged.emit()
        self.layerChanged.emit(self.current_layer)
        self.frameChanged.emit(self.current_frame)

    def edit(self, text: str, fn):
        """Выполняет fn() и кладёт результат в историю как одну правку."""
        before = self._snapshot()
        fn()
        after = self._snapshot()
        self.undo_stack.push(_SnapshotCommand(self, text, before, after))

    # ---------- рисование ----------
    def add_stroke(self, stroke: Stroke):
        layer = self.layer()
        if layer is None:
            return

        def do():
            k = layer.key_at_or_before(self.current_frame)
            if k is None:
                layer.keys[self.current_frame] = Drawing()
                k = self.current_frame
            layer.keys[k].strokes.append(stroke)

        self.edit("Ластик" if stroke.erase else "Мазок", do)

    def clear_drawing(self):
        layer = self.layer()
        if layer is None:
            return
        k = layer.key_at_or_before(self.current_frame)
        if k is None or layer.keys[k].is_empty():
            return
        self.edit("Очистить кадр", lambda: layer.keys[k].strokes.clear())

    # ---------- кадры ----------
    def insert_keyframe(self, blank: bool = False):
        layer = self.layer()
        if layer is None:
            return
        f = self.current_frame
        if f in layer.keys:
            # ключ уже стоит — ставим новый на следующем кадре, как во Flash
            f += 1

        def do():
            src = layer.drawing_at(f)
            layer.keys[f] = Drawing() if (blank or src is None) else src.copy()
            if f >= self.frame_count:
                self.frame_count = f + 1

        self.edit("Пустой ключевой кадр" if blank else "Ключевой кадр", do)
        self.set_frame(f)

    def remove_keyframe(self):
        layer = self.layer()
        if layer is None or self.current_frame not in layer.keys:
            return
        self.edit("Удалить ключевой кадр", lambda: layer.keys.pop(self.current_frame))

    def insert_frame(self):
        """Вставляет кадр на текущем слое: всё, что правее, сдвигается на 1."""
        layer = self.layer()
        if layer is None:
            return
        f = self.current_frame

        def do():
            layer.keys = {(k + 1 if k > f else k): d for k, d in layer.keys.items()}
            self.frame_count += 1

        self.edit("Вставить кадр", do)

    def remove_frame(self):
        layer = self.layer()
        if layer is None:
            return
        f = self.current_frame

        def do():
            keys = {}
            for k, d in layer.keys.items():
                if k < f:
                    keys[k] = d
                elif k == f:
                    # ключ остаётся, если его не «наезжает» следующий
                    if (f + 1) not in layer.keys:
                        keys[k] = d
                else:
                    keys[k - 1] = d
            layer.keys = keys

        self.edit("Удалить кадр", do)

    # ---------- слои ----------
    def add_layer(self):
        def do():
            layer = Layer(f"Слой {len(self.layers) + 1}")
            layer.keys[0] = Drawing()
            self.layers.insert(self.current_layer, layer)

        self.edit("Новый слой", do)

    def duplicate_layer(self):
        src = self.layer()
        if src is None:
            return

        def do():
            layer = Layer(src.name + " копия")
            layer.keys = {k: d.copy() for k, d in src.keys.items()}
            self.layers.insert(self.current_layer, layer)

        self.edit("Дублировать слой", do)

    def delete_layer(self):
        if len(self.layers) <= 1:
            return

        def do():
            self.layers.pop(self.current_layer)
            self.current_layer = min(self.current_layer, len(self.layers) - 1)

        self.edit("Удалить слой", do)

    def move_layer(self, delta: int):
        i, j = self.current_layer, self.current_layer + delta
        if not (0 <= j < len(self.layers)):
            return

        def do():
            self.layers[i], self.layers[j] = self.layers[j], self.layers[i]
            self.current_layer = j

        self.edit("Переместить слой", do)

    def rename_layer(self, index: int, name: str):
        layer = self.layers[index]
        if name and name != layer.name:
            self.edit("Переименовать слой", lambda: setattr(layer, "name", name))

    def set_frame_count(self, n: int):
        n = max(1, n)
        if n != self.frame_count:
            self.edit("Длина сцены", lambda: setattr(self, "frame_count", n))


class _SnapshotCommand(QUndoCommand):
    def __init__(self, project: Project, text: str, before, after):
        super().__init__(text)
        self.project = project
        self.before = before
        self.after = after
        self._first = True

    def redo(self):
        if self._first:  # состояние уже применено в Project.edit
            self._first = False
            self.project.structureChanged.emit()
            self.project.contentChanged.emit()
            return
        self.project._restore(self.after)

    def undo(self):
        self.project._restore(self.before)
