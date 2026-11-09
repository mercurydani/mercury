"""Модель проекта: слои, ключевые кадры, рисунки, история правок.

Кадры нумеруются с 0. На слое хранятся только ключевые кадры (`Layer.keys`);
рисунок ключевого кадра «держится» на всех следующих кадрах до следующего ключа
или до конца сцены — так же, как экспозиция в классической анимации.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field, replace

from PySide6.QtCore import QObject, Signal
from PySide6.QtGui import QColor, QUndoCommand, QUndoStack

from .animation import Key, Transform
from .brushes import BrushParams


@dataclass(frozen=True)
class Stroke:
    """Один мазок. После создания не меняется, поэтому его можно разделять между копиями."""

    points: tuple  # ((x, y, pressure), ...) в координатах сцены
    color: QColor
    width: float
    opacity: float = 1.0
    erase: bool = False
    use_pressure: bool = False
    brush: BrushParams = BrushParams()


@dataclass
class Drawing:
    strokes: list = field(default_factory=list)

    def is_empty(self) -> bool:
        return not self.strokes

    def copy(self) -> "Drawing":
        return Drawing(list(self.strokes))


LAYER_TAGS = ["#6f8fff", "#ff8a3d", "#9be36b", "#ffd84a", "#c58cff", "#ff6fa8", "#5be0c4"]


class Layer:
    """Рисованный слой (type="drawing"). Другие виды слоёв наследуются от него."""

    _counter = 0
    type = "drawing"

    def __init__(self, name: str, layer_id: str | None = None):
        self.id = layer_id or uuid.uuid4().hex[:12]
        self.name = name
        self.visible = True
        self.locked = False
        self.opacity = 1.0
        self.tag = LAYER_TAGS[Layer._counter % len(LAYER_TAGS)]
        Layer._counter += 1
        self.keys: dict[int, Drawing] = {}
        self.transform = Transform()   # слой как «элемент»: движение, поворот, деформация по ключам

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

    # состояние для истории правок
    def get_state(self):
        return (self.name, {k: d.copy() for k, d in self.keys.items()}, self.transform.copy())

    def set_state(self, state):
        self.name, keys, tr = state
        self.keys = {k: d.copy() for k, d in keys.items()}
        self.transform = tr.copy()


@dataclass
class AudioClip:
    """Звуковой клип на звуковой дорожке."""

    media_id: str
    name: str
    start: int = 0             # первый кадр
    duration: float = 0.0      # секунды
    volume: float = 1.0
    peaks: list = field(default_factory=list, repr=False, compare=False)  # волна, 100 значений в секунду
    id: str = field(default_factory=lambda: uuid.uuid4().hex[:12])

    def end_frame(self, fps: int) -> int:
        return self.start + max(1, round(self.duration * fps))

    def copy(self) -> "AudioClip":
        return replace(self)


@dataclass
class VisualClip:
    """Клип на видеодорожке: видео, картинка или GIF. Может двигаться и деформироваться по ключам."""

    media_id: str
    kind: str                  # video / image / gif
    name: str
    start: int = 0             # первый кадр на таймлайне
    length: int = 48           # длительность в кадрах
    offset: float = 0.0        # с какой секунды исходника начинается клип
    speed: float = 1.0         # скорость воспроизведения (1 = обычная)
    src_w: int = 1920
    src_h: int = 1080
    source_duration: float = 0.0
    transform: Transform = field(default_factory=Transform)
    id: str = field(default_factory=lambda: uuid.uuid4().hex[:12])

    def end_frame(self, fps: int = 0) -> int:
        return self.start + max(1, self.length)

    def copy(self) -> "VisualClip":
        return replace(self, transform=self.transform.copy())

    def source_time(self, frame: int, fps: int) -> float:
        return self.offset + (frame - self.start) / max(1, fps) * self.speed

    def max_length(self, fps: int) -> int | None:
        """Сколько кадров можно показать до конца исходника (у картинок — без ограничения)."""
        if self.kind != "video" or self.source_duration <= 0:
            return None
        return max(1, int((self.source_duration - self.offset) * fps / max(0.01, self.speed)))


class Track:
    """Дорожка таймлайна: видео ("video") или звук ("audio").

    Первая видеодорожка с animation=True показывает нарисованную анимацию (все рисованные слои).
    В остальные видеодорожки на следующих шагах будут попадать видео, картинки и GIF.
    """

    def __init__(self, kind: str, name: str, track_id: str | None = None, animation: bool = False):
        self.id = track_id or uuid.uuid4().hex[:12]
        self.kind = kind
        self.name = name
        self.animation = animation
        self.enabled = True   # видимость видео / звук включён
        self.locked = False
        self.clips: list = []   # AudioClip на звуковых дорожках, VisualClip на видеодорожках
        self.raw_clips: list = []   # клипы незнакомого типа из более новых версий — храним как есть

    def get_state(self):
        return (self.name, [c.copy() for c in self.clips])

    def set_state(self, state):
        self.name, clips = state
        self.clips = [c.copy() for c in clips]

    def clip_at(self, frame: int, fps: int):
        for c in self.clips:
            if c.start <= frame < c.end_frame(fps):
                return c
        return None

    def is_free(self, start: int, end: int, fps: int, ignore=None) -> bool:
        return all(c is ignore or c.end_frame(fps) <= start or c.start >= end for c in self.clips)


def default_tracks() -> list[Track]:
    return [Track("video", "Анимация", animation=True), Track("audio", "Звук 1")]


class Project(QObject):
    contentChanged = Signal()      # изменились рисунки — перерисовать холст
    structureChanged = Signal()    # слои / ключи / длина сцены
    frameChanged = Signal(int)
    layerChanged = Signal(int)
    sceneChanged = Signal()        # размер листа
    selectionChanged = Signal()    # выбран другой элемент (клип или слой)
    dirtyChanged = Signal(bool)
    fileChanged = Signal()         # имя проекта или путь к файлу

    def __init__(self):
        super().__init__()
        self.name = "Без названия"
        self.file_path: str | None = None
        self.width = 1920
        self.height = 1080
        self.fps = 24
        self.frame_count = 48
        self.background = QColor("#ffffff")
        self.layers: list[Layer] = []  # рисованные слои, индекс 0 — верхний
        self.tracks: list[Track] = []  # дорожки таймлайна сверху вниз
        self.current_track = 0
        self.media: dict[str, str] = {}  # id медиафайла -> путь к файлу на диске
        self.media_info: dict = {}       # id медиафайла -> media.MediaInfo (для видео)
        self.selection: tuple | None = None  # выбранный элемент: ("clip", id) или ("layer", id)
        self.current_frame = 0
        self.current_layer = 0
        self._extra_dirty = False      # изменения вне истории (видимость слоя и т.п.)
        self.undo_stack = QUndoStack(self)
        self.undo_stack.cleanChanged.connect(self._on_clean_changed)
        self.reset()

    # ---------- состояние ----------
    def reset(self, name: str = "Без названия", width: int = 1920, height: int = 1080,
              fps: int = 24, frame_count: int = 48):
        Layer._counter = 0
        self.name = name
        self.file_path = None
        self.width, self.height, self.fps, self.frame_count = width, height, fps, frame_count
        self.layers = [Layer("Слой 1")]
        self.layers[0].keys[0] = Drawing()
        self.tracks = default_tracks()
        self.media = {}
        self.media_info = {}
        self._after_load()

    def _after_load(self):
        """Сбрасывает историю и оповещает интерфейс после создания или загрузки проекта."""
        self.current_frame = 0
        self.current_layer = 0
        self.current_track = 0
        self.selection = None
        self.undo_stack.clear()
        self.undo_stack.setClean()
        self._extra_dirty = False
        self.sceneChanged.emit()
        self.structureChanged.emit()
        self.contentChanged.emit()
        self.frameChanged.emit(0)
        self.layerChanged.emit(0)
        self.fileChanged.emit()
        self.dirtyChanged.emit(False)

    def _on_clean_changed(self, _clean):
        try:
            self.dirtyChanged.emit(self.is_dirty())
        except RuntimeError:  # стек уже уничтожается вместе с проектом
            pass

    def is_dirty(self) -> bool:
        return self._extra_dirty or not self.undo_stack.isClean()

    def mark_dirty(self):
        if not self._extra_dirty:
            self._extra_dirty = True
            self.dirtyChanged.emit(True)

    def mark_saved(self, path: str):
        self.file_path = path
        self._extra_dirty = False
        self.undo_stack.setClean()
        self.fileChanged.emit()
        self.dirtyChanged.emit(False)

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
            "layers": [(l, l.get_state()) for l in self.layers],
            "tracks": [(t, t.get_state()) for t in self.tracks],
            "frame_count": self.frame_count,
            "scene": (self.width, self.height, self.fps, QColor(self.background)),
            "current_layer": self.current_layer,
        }

    def _restore(self, snap):
        self.layers = []
        for layer, state in snap["layers"]:
            layer.set_state(state)
            self.layers.append(layer)
        self.tracks = []
        for track, state in snap["tracks"]:
            track.set_state(state)
            self.tracks.append(track)
        self.current_track = min(self.current_track, len(self.tracks) - 1)
        self.frame_count = snap["frame_count"]
        scene = (self.width, self.height)
        self.width, self.height, self.fps, self.background = snap["scene"]
        if scene != (self.width, self.height):
            self.sceneChanged.emit()
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

    def draw_layer(self) -> Layer | None:
        """Текущий слой, если на нём можно рисовать и ставить ключевые кадры."""
        layer = self.layer()
        return layer if layer is not None and layer.type == "drawing" and not hasattr(layer, "raw") else None

    # ---------- рисование ----------
    def add_stroke(self, stroke: Stroke):
        layer = self.draw_layer()
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
        layer = self.draw_layer()
        if layer is None:
            return
        k = layer.key_at_or_before(self.current_frame)
        if k is None or layer.keys[k].is_empty():
            return
        self.edit("Очистить кадр", lambda: layer.keys[k].strokes.clear())

    # ---------- кадры ----------
    def insert_keyframe(self, blank: bool = False):
        layer = self.draw_layer()
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
        layer = self.draw_layer()
        if layer is None or self.current_frame not in layer.keys:
            return
        self.edit("Удалить ключевой кадр", lambda: layer.keys.pop(self.current_frame))

    def insert_frame(self):
        """Вставляет кадр на текущем слое: всё, что правее, сдвигается на 1."""
        layer = self.draw_layer()
        if layer is None:
            return
        f = self.current_frame

        def do():
            layer.keys = {(k + 1 if k > f else k): d for k, d in layer.keys.items()}
            self.frame_count += 1

        self.edit("Вставить кадр", do)

    def remove_frame(self):
        layer = self.draw_layer()
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
        src = self.draw_layer()
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

    def move_layer_to(self, src: int, dst: int):
        """Перетаскивание слоя в панели «Слои»."""
        n = len(self.layers)
        if not (0 <= src < n) or not (0 <= dst < n) or src == dst:
            return

        def do():
            layer = self.layers.pop(src)
            self.layers.insert(dst, layer)
            self.current_layer = dst

        self.edit("Переместить слой", do)

    def rename_layer(self, index: int, name: str):
        layer = self.layers[index]
        if name and name != layer.name:
            self.edit("Переименовать слой", lambda: setattr(layer, "name", name))

    # ---------- дорожки ----------
    def track(self) -> Track | None:
        if 0 <= self.current_track < len(self.tracks):
            return self.tracks[self.current_track]
        return None

    def set_track(self, index: int):
        index = max(0, min(index, len(self.tracks) - 1))
        if index != self.current_track:
            self.current_track = index
            self.structureChanged.emit()

    def add_track(self, kind: str):
        n = sum(1 for t in self.tracks if t.kind == kind) + 1
        if kind == "video":
            n = sum(1 for t in self.tracks if t.kind == "video" and not t.animation) + 1

        def do():
            track = Track(kind, f"Видео {n}" if kind == "video" else f"Звук {n}")
            if kind == "video":
                idx = self._new_video_index()
            else:
                idx = len(self.tracks)
            self.tracks.insert(idx, track)
            self.current_track = idx

        self.edit("Новая видеодорожка" if kind == "video" else "Новая звуковая дорожка", do)

    def delete_track(self):
        track = self.track()
        if track is None or track.animation:
            return

        def do():
            self.tracks.remove(track)
            self.current_track = min(self.current_track, len(self.tracks) - 1)

        self.edit("Удалить дорожку", do)

    def rename_track(self, index: int, name: str):
        track = self.tracks[index]
        if name and name != track.name:
            self.edit("Переименовать дорожку", lambda: setattr(track, "name", name))

    def _audio_track_for(self, start: int, end: int) -> Track:
        """Текущая звуковая дорожка, если на ней свободно, иначе первая свободная, иначе новая."""
        cur = self.track()
        order = ([cur] if cur is not None and cur.kind == "audio" else []) + \
                [t for t in self.tracks if t.kind == "audio" and t is not cur]
        for t in order:
            if not t.locked and t.is_free(start, end, self.fps):
                return t
        n = sum(1 for t in self.tracks if t.kind == "audio") + 1
        t = Track("audio", f"Звук {n}")
        self.tracks.append(t)
        return t

    # ---------- звук ----------
    def add_audio_clip(self, name: str, media_id: str, path: str, start: int, duration: float, peaks) -> AudioClip:
        self.media[media_id] = path
        clip = AudioClip(media_id, name, start, duration, 1.0, peaks)

        def do():
            track = self._audio_track_for(start, clip.end_frame(self.fps))
            track.clips.append(clip)
            self.current_track = self.tracks.index(track)
            end = clip.end_frame(self.fps)
            if end > self.frame_count:
                self.frame_count = end

        self.edit("Добавить звук", do)
        return clip

    def find_clip(self, clip_id: str) -> tuple[Track, AudioClip] | None:
        for t in self.tracks:
            for c in t.clips:
                if c.id == clip_id:
                    return t, c
        return None

    def move_clip(self, clip_id: str, start: int, to_track: Track | None = None) -> bool:
        found = self.find_clip(clip_id)
        if found is None:
            return False
        src, clip = found
        dst = to_track or src
        start = max(0, start)
        if dst.kind != src.kind or dst.animation or dst.locked:
            return False
        if start == clip.start and dst is src:
            return False
        if not dst.is_free(start, start + clip.end_frame(self.fps) - clip.start, self.fps, ignore=clip):
            return False

        def do():
            f = self.find_clip(clip_id)
            t, c = f
            c.start = start
            if dst is not t:
                t.clips.remove(c)
                dst.clips.append(c)
                self.current_track = self.tracks.index(dst)

        self.edit("Сдвинуть звук", do)
        return True

    def delete_clip(self, clip_id: str):
        found = self.find_clip(clip_id)
        if found is None:
            return

        def do():
            t, c = self.find_clip(clip_id)
            t.clips.remove(c)

        self.edit("Удалить звук", do)

    def audio_clips(self):
        """Все слышимые клипы: (дорожка, клип)."""
        return [(t, c) for t in self.tracks if t.kind == "audio" and t.enabled for c in t.clips]

    def animation_enabled(self) -> bool:
        return any(t.enabled for t in self.tracks if t.animation) or not any(t.animation for t in self.tracks)

    # ---------- элементы: клипы на видеодорожках и слои с трансформацией ----------
    def _new_video_index(self) -> int:
        """Новая видеодорожка встаёт сразу под «Анимацией» — над остальными клипами:
        верхняя дорожка в списке рисуется поверх (как V2 над V1 в монтажных программах)."""
        anim = next((i for i, t in enumerate(self.tracks) if t.animation), -1)
        return anim + 1

    def _video_track_for(self, start: int, end: int) -> Track:
        cur = self.track()
        order = ([cur] if cur is not None and cur.kind == "video" and not cur.animation else []) + \
                [t for t in self.tracks if t.kind == "video" and not t.animation and t is not cur]
        for t in order:
            if not t.locked and t.is_free(start, end, self.fps):
                return t
        n = sum(1 for t in self.tracks if t.kind == "video" and not t.animation) + 1
        t = Track("video", f"Видео {n}")
        self.tracks.insert(self._new_video_index(), t)
        return t

    def add_visual_clip(self, clip: VisualClip, path: str, info=None) -> VisualClip:
        self.media[clip.media_id] = path
        if info is not None:
            self.media_info[clip.media_id] = info

        def do():
            track = self._video_track_for(clip.start, clip.end_frame())
            track.clips.append(clip)
            self.current_track = self.tracks.index(track)
            if clip.end_frame() > self.frame_count:
                self.frame_count = clip.end_frame()

        self.edit("Добавить " + {"video": "видео", "gif": "GIF", "image": "картинку"}.get(clip.kind, "клип"), do)
        self.select(("clip", clip.id))
        return clip

    def trim_clip(self, clip_id: str, start: int, length: int, offset: float | None = None) -> bool:
        found = self.find_clip(clip_id)
        if found is None:
            return False
        track, clip = found
        start, length = max(0, start), max(1, length)
        if not track.is_free(start, start + length, self.fps, ignore=clip):
            return False

        def do():
            _t, c = self.find_clip(clip_id)
            if isinstance(c, VisualClip):
                c.transform.shift_keys(c.start - start)  # ключи привязаны к началу клипа
                if offset is not None:
                    c.offset = max(0.0, offset)
                c.length = length
            c.start = start
            if c.end_frame(self.fps) > self.frame_count:
                self.frame_count = c.end_frame(self.fps)

        self.edit("Обрезать клип", do)
        return True

    def split_clip(self, clip_id: str | None = None, frame: int | None = None) -> bool:
        """Разрезает клип на кадре: получается два клипа подряд (ключи переносятся во вторую часть)."""
        frame = self.current_frame if frame is None else frame
        if clip_id is None:
            sel = self.selection
            clip_id = sel[1] if sel and sel[0] == "clip" else None
        if clip_id is None:
            t = self.track()
            c = t.clip_at(frame, self.fps) if t is not None and not t.animation else None
            clip_id = c.id if c is not None and isinstance(c, VisualClip) else None
        found = self.find_clip(clip_id) if clip_id else None
        if found is None or not isinstance(found[1], VisualClip):
            return False
        _track, clip = found
        cut = frame - clip.start
        if not (0 < cut < clip.length):
            return False

        def do():
            t, c = self.find_clip(clip_id)
            second = c.copy()
            second.id = uuid.uuid4().hex[:12]
            second.start = frame
            second.length = c.length - cut
            if c.kind == "video":
                second.offset = c.offset + cut / self.fps * c.speed
            # значения свойств в момент разреза сохраняются в обеих частях
            vals = c.transform.values(cut)
            second.transform.shift_keys(-cut)
            for p, ks in second.transform.keys.items():
                ks[:] = [k for k in ks if k.frame >= 0]
                if not ks or ks[0].frame > 0:
                    ks.insert(0, Key(0, vals[p], "smooth"))
            for p, ks in c.transform.keys.items():
                tail = [k for k in ks if k.frame >= cut]
                ks[:] = [k for k in ks if k.frame < cut]
                if tail:
                    ks.append(Key(cut, vals[p], "smooth"))
            c.length = cut
            t.clips.append(second)

        self.edit("Разрезать клип", do)
        return True

    def select(self, sel: tuple | None):
        if sel != self.selection:
            self.selection = sel
            self.selectionChanged.emit()

    def selected_element(self):
        """(объект, Transform, ширина, высота, центр x, центр y, начало) выбранного элемента или None."""
        if not self.selection:
            return None
        kind, oid = self.selection
        if kind == "clip":
            found = self.find_clip(oid)
            if found is None or not isinstance(found[1], VisualClip):
                return None
            c = found[1]
            fit = min(self.width / max(1, c.src_w), self.height / max(1, c.src_h))
            return c, c.transform, c.src_w * fit, c.src_h * fit, self.width / 2, self.height / 2, c.start
        for layer in self.layers:
            if layer.id == oid:
                return layer, layer.transform, self.width, self.height, self.width / 2, self.height / 2, 0
        return None

    def edit_element(self, text: str, fn):
        """Правка трансформации выбранного элемента: fn(transform, локальный кадр)."""
        el = self.selected_element()
        if el is None:
            return
        obj, _tr, *_rest, start = el
        local = self.current_frame - start

        def do():
            fn(obj.transform, local)

        self.edit(text, do)
        self.contentChanged.emit()

    def visual_clips_at(self, frame: int):
        """Видимые клипы на кадре снизу вверх: [(дорожка, клип)]."""
        out = []
        for t in reversed(self.tracks):
            if t.kind == "video" and not t.animation and t.enabled:
                c = t.clip_at(frame, self.fps)
                if c is not None and isinstance(c, VisualClip):
                    out.append((t, c))
        return out

    def set_scene(self, width: int, height: int, fps: int, frame_count: int):
        if (width, height, fps, frame_count) == (self.width, self.height, self.fps, self.frame_count):
            return
        size_changed = (width, height) != (self.width, self.height)

        def do():
            self.width, self.height, self.fps = width, height, fps
            self.frame_count = max(1, frame_count)

        self.edit("Настройки сцены", do)
        if size_changed:
            self.sceneChanged.emit()

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
