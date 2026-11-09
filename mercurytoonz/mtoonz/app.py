"""Главное окно MercuryToonz."""

from __future__ import annotations

from PySide6.QtCore import QSize, Qt, QTimer
from PySide6.QtGui import QAction, QActionGroup, QKeySequence
from PySide6.QtWidgets import (
    QApplication, QDialog, QDialogButtonBox, QDockWidget, QFileDialog, QFormLayout, QInputDialog, QLabel,
    QMainWindow, QMenu, QMessageBox, QScrollArea, QSizePolicy, QSpinBox, QSplitter, QToolBar,
    QVBoxLayout, QWidget,
)

import os
import shutil

from . import APP_NAME, APP_VERSION, audio, fileformat, icons, theme
from .audio import RecordDialog
from .widgets.help_dialog import HelpDialog
from .model import Project
from .render import first_drawn_frame, render_frame
from .state import TOOL_GROUP_STARTS, TOOLS, EditorState
from .widgets.canvas import Canvas
from .widgets.color_panel import ColorPanel
from .widgets.export_dialog import ExportDialog
from .widgets.layers_panel import LayersPanel
from .widgets import project_browser as pb
from .widgets.timeline import Timeline
from .widgets.tool_options import ToolOptions

SHORTCUTS_HELP = """
<h3>Инструменты</h3>
<table cellspacing=4>
<tr><td><b>V</b></td><td>Выделение</td><td width=24></td><td><b>Q</b></td><td>Трансформация</td></tr>
<tr><td><b>B</b></td><td>Кисть</td><td></td><td><b>P</b></td><td>Карандаш</td></tr>
<tr><td><b>E</b></td><td>Ластик</td><td></td><td><b>G</b></td><td>Заливка</td></tr>
<tr><td><b>U</b></td><td>Фигуры: линия, кривая, прямоугольник, эллипс</td><td></td><td><b>I</b></td><td>Пипетка</td></tr>
<tr><td><b>Shift</b> + рисование</td><td>Прямая линия</td><td></td><td><b>Esc</b></td><td>Отменить кривую</td></tr>
<tr><td><b>H</b> / Пробел</td><td>Рука</td><td></td><td><b>Z</b></td><td>Масштаб</td></tr>
<tr><td><b>[ ]</b></td><td>Размер кисти</td><td></td><td><b>X</b></td><td>Поменять цвета</td></tr>
</table>
<h3>Кадры и воспроизведение</h3>
<table cellspacing=4>
<tr><td><b>F6</b></td><td>Ключевой кадр (копия)</td><td width=24></td><td><b>F7</b></td><td>Пустой ключевой кадр</td></tr>
<tr><td><b>F5</b></td><td>Вставить кадр</td><td></td><td><b>Shift+F5</b></td><td>Удалить кадр</td></tr>
<tr><td><b>, .</b></td><td>Предыдущий / следующий кадр</td><td></td><td><b>Home End</b></td><td>Первый / последний</td></tr>
<tr><td><b>Enter</b></td><td>Воспроизвести / пауза</td><td></td><td><b>O</b></td><td>Луковая кожа</td></tr>
</table>
<h3>Проекты</h3>
<table cellspacing=4>
<tr><td><b>Ctrl+Shift+O</b></td><td>Проекты</td><td width=24></td><td><b>Ctrl+N</b></td><td>Новый проект</td></tr>
<tr><td><b>Ctrl+S</b></td><td>Сохранить</td><td></td><td><b>Ctrl+Shift+S</b></td><td>Сохранить как</td></tr>
<tr><td><b>Ctrl+E</b></td><td>Экспорт</td><td></td><td></td><td></td></tr>
</table>
<h3>Звук</h3>
<table cellspacing=4>
<tr><td><b>Ctrl+R</b></td><td>Записать с микрофона</td><td width=24></td><td><b>Ctrl+I</b></td><td>Импорт звука</td></tr>
</table>
<h3>Вид</h3>
<table cellspacing=4>
<tr><td><b>Ctrl+колесо</b></td><td>Масштаб холста</td><td width=24></td><td><b>Ctrl+0</b></td><td>Вписать в окно</td></tr>
<tr><td><b>Ctrl+1</b></td><td>Масштаб 100%</td><td></td><td><b>Ctrl+колесо</b> на таймлайне</td><td>Ширина кадров</td></tr>
</table>
"""


class SceneSettingsDialog(QDialog):
    def __init__(self, project: Project, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Настройки сцены")
        form = QFormLayout(self)
        form.setContentsMargins(18, 18, 18, 18)
        form.setSpacing(10)
        self.w = QSpinBox()
        self.w.setRange(16, 8192)
        self.w.setValue(project.width)
        self.w.setSuffix(" px")
        self.h = QSpinBox()
        self.h.setRange(16, 8192)
        self.h.setValue(project.height)
        self.h.setSuffix(" px")
        self.fps = QSpinBox()
        self.fps.setRange(1, 60)
        self.fps.setValue(project.fps)
        self.frames = QSpinBox()
        self.frames.setRange(1, 9999)
        self.frames.setValue(project.frame_count)
        for sb in (self.w, self.h, self.fps, self.frames):
            sb.setMinimumWidth(110)
        form.addRow("Ширина", self.w)
        form.addRow("Высота", self.h)
        form.addRow("Кадров в секунду", self.fps)
        form.addRow("Длина (кадров)", self.frames)
        buttons = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        buttons.button(QDialogButtonBox.Ok).setDefault(True)
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        form.addRow(buttons)


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.project = Project()
        self.state = EditorState()
        self.resize(1480, 920)
        self.setWindowIcon(icons.icon("logo", theme.ACCENT))
        self.setDockNestingEnabled(True)
        self.setCorner(Qt.BottomRightCorner, Qt.RightDockWidgetArea)  # слои — на всю высоту
        self.setCorner(Qt.BottomLeftCorner, Qt.BottomDockWidgetArea)

        self.playback = audio.AudioPlayback(self.project)
        self.project.fileChanged.connect(self.playback.reset)
        self.play_timer = QTimer(self)
        self.play_timer.timeout.connect(self._tick)

        self.canvas = Canvas(self.project, self.state)
        self.setCentralWidget(self.canvas)

        self.actions: dict[str, QAction] = {}
        self._create_actions()
        self._create_toolbox()
        self._create_topbar()
        self._create_docks()
        self._create_menus()
        self._create_statusbar()

        self.project.dirtyChanged.connect(lambda _: self._update_title())
        self.project.fileChanged.connect(self._update_title)
        self.project.fileChanged.connect(self._rebuild_recent)
        self.project.frameChanged.connect(lambda _: self._update_status())
        self.project.layerChanged.connect(lambda _: self._update_status())
        self.project.structureChanged.connect(self._update_status)
        self.state.toolChanged.connect(self._on_tool_changed)
        self.canvas.message.connect(lambda m: self.statusBar().showMessage(m, 3000))
        self.canvas.zoomChanged.connect(lambda z: self.zoom_label.setText(f"{z * 100:.0f}%"))
        self.canvas.cursorMoved.connect(lambda x, y: self.pos_label.setText(f"X {x:5.0f}   Y {y:5.0f}"))
        self._update_title()
        self._update_status()

    # ------------------------------------------------------------------ actions
    def _act(self, key, text, icon=None, shortcut=None, slot=None, checkable=False, tip=None):
        a = QAction(text, self)
        if icon:
            a.setIcon(icons.icon(icon))
        if shortcut:
            seqs = shortcut if isinstance(shortcut, (list, tuple)) else [shortcut]
            a.setShortcuts([QKeySequence(s) for s in seqs])
        a.setCheckable(checkable)
        if slot:
            a.triggered.connect(slot)
        sc = a.shortcut().toString(QKeySequence.NativeText)
        a.setToolTip(f"{tip or text}  ({sc})" if sc else (tip or text))
        a.setStatusTip(tip or text)
        self.addAction(a)  # чтобы горячие клавиши работали без меню
        self.actions[key] = a
        return a

    def _soon(self, what):
        return lambda: self.statusBar().showMessage(f"«{what}» появится на следующих шагах", 3000)

    def _create_actions(self):
        p = self.project
        A = self._act
        # файл
        A("new", "Новый проект", "new", QKeySequence.New, self.new_project)
        A("projects", "Проекты…", "layers", "Ctrl+Shift+O", self.show_projects,
          tip="Проекты — список, создание, удаление")
        A("open", "Открыть файл…", "open", QKeySequence.Open, self.open_dialog)
        A("save", "Сохранить", "save", QKeySequence.Save, self.save)
        A("save_as", "Сохранить как…", None, QKeySequence.SaveAs, self.save_as)
        A("rename_project", "Переименовать проект…", None, None, self.rename_project)
        A("export", "Экспорт…", "export", "Ctrl+E", lambda: self.export_dialog(),
          tip="Экспорт в MP4, MOV, AVI, GIF, PNG или MP3")
        for key, title in (("mp4", "Видео MP4…"), ("mov", "Видео MOV…"), ("avi", "Видео AVI…"),
                           ("gif", "Анимированный GIF…"), ("png", "Последовательность PNG…"),
                           ("mp3", "Только звук MP3…")):
            A(f"export_{key}", title, None, None, lambda _=False, k=key: self.export_dialog(k))
        A("quit", "Выход", None, QKeySequence.Quit, self.close)
        # правка
        undo = p.undo_stack.createUndoAction(self, "Отменить")
        undo.setIcon(icons.icon("undo"))
        undo.setShortcut(QKeySequence.Undo)
        redo = p.undo_stack.createRedoAction(self, "Повторить")
        redo.setIcon(icons.icon("redo"))
        redo.setShortcuts([QKeySequence.Redo, QKeySequence("Ctrl+Y")])
        for k, a in (("undo", undo), ("redo", redo)):
            self.addAction(a)
            self.actions[k] = a
        A("cut", "Вырезать", None, QKeySequence.Cut, self._soon("Вырезать"))
        A("copy", "Копировать", None, QKeySequence.Copy, self._soon("Копировать"))
        A("paste", "Вставить", None, QKeySequence.Paste, self._soon("Вставить"))
        A("clear", "Очистить кадр", "trash", "Delete", p.clear_drawing)
        A("swap_colors", "Поменять цвета", "swap", "X", self.state.swap_colors)
        A("size_up", "Увеличить кисть", None, "]", lambda: self._brush_size(1.25))
        A("size_down", "Уменьшить кисть", None, "[", lambda: self._brush_size(0.8))
        # вид
        A("zoom_in", "Приблизить", None, [QKeySequence.ZoomIn, "Ctrl+="], lambda: self.canvas.zoom_step(1))
        A("zoom_out", "Отдалить", None, QKeySequence.ZoomOut, lambda: self.canvas.zoom_step(-1))
        A("zoom_fit", "Вписать в окно", "fit", "Ctrl+0", self.canvas.fit_to_view)
        A("zoom_100", "Масштаб 100%", None, "Ctrl+1", lambda: self.canvas.set_zoom(1.0))
        onion = A("onion", "Луковая кожа", "onion", "O", self.state.set_onion, checkable=True,
                  tip="Луковая кожа — показать соседние рисунки")
        onion.setChecked(self.state.onion)
        # кадры
        A("key", "Ключевой кадр", "keyframe", "F6", lambda: p.insert_keyframe(False),
          tip="Ключевой кадр — копия текущего рисунка")
        A("key_blank", "Пустой ключевой кадр", "keyframe-empty", "F7", lambda: p.insert_keyframe(True))
        A("key_remove", "Удалить ключевой кадр", None, "Shift+F6", p.remove_keyframe)
        A("frame_insert", "Вставить кадр", "frame-add", "F5", p.insert_frame,
          tip="Вставить кадр — продлить экспозицию")
        A("frame_remove", "Удалить кадр", "frame-remove", "Shift+F5", p.remove_frame)
        A("first", "Первый кадр", "first", "Home", lambda: p.set_frame(0))
        A("prev", "Предыдущий кадр", "prev", [",", "Left"], lambda: self._step(-1))
        A("next", "Следующий кадр", "next", [".", "Right"], lambda: self._step(1))
        A("last", "Последний кадр", "last", "End", lambda: p.set_frame(p.frame_count - 1))
        A("prev_key", "Предыдущий ключ", None, "Shift+,", lambda: self._step_key(-1))
        A("next_key", "Следующий ключ", None, "Shift+.", lambda: self._step_key(1))
        # слои
        A("layer_add", "Новый слой", "layer-add", "Ctrl+Shift+N", p.add_layer)
        A("layer_duplicate", "Дублировать слой", "duplicate", "Ctrl+Shift+D", p.duplicate_layer)
        A("layer_delete", "Удалить слой", "trash", None, p.delete_layer)
        A("layer_rename", "Переименовать слой…", None, "F2", self.rename_layer)
        A("layer_up", "Слой выше", "up", "Ctrl+Shift+Up", lambda: p.move_layer(-1))
        A("layer_down", "Слой ниже", "down", "Ctrl+Shift+Down", lambda: p.move_layer(1))
        # дорожки
        A("track_add_video", "Новая видеодорожка", "film", None, lambda: p.add_track("video"),
          tip="Новая видеодорожка — для видео, картинок и GIF")
        A("track_add_audio", "Новая звуковая дорожка", "audio-track", None, lambda: p.add_track("audio"))
        A("track_delete", "Удалить дорожку", "trash", None, self.delete_track)
        # анимация
        A("play", "Воспроизвести", "play", ["Return", "Enter"], self.toggle_play,
          tip="Воспроизвести / пауза")
        loop = A("loop", "Зациклить", "loop", None, lambda v: setattr(self.state, "loop", v), checkable=True)
        loop.setChecked(self.state.loop)
        A("tween", "Создать промежуточные кадры", "tween", None, self._soon("Промежуточные кадры (tween)"))
        A("scene", "Настройки сцены…", "settings", "Ctrl+Alt+S", self.scene_settings)
        # справка
        A("record_audio", "Записать звук с микрофона…", "mic", "Ctrl+R", self.record_audio,
          tip="Записать голос с микрофона")
        A("import_audio", "Импорт звука…", "music", "Ctrl+I", self.import_audio,
          tip="Добавить звуковой файл (WAV, MP3, OGG, M4A…)")
        # справка
        A("shortcuts", "Горячие клавиши", "keyboard", "F1", lambda: self.show_help("shortcuts"))
        A("changelog", "Что нового", "history", None, lambda: self.show_help("changelog"))
        A("privacy", "Политика конфиденциальности", "shield", None, lambda: self.show_help("privacy"))
        A("contacts", "Связаться с разработчиком", "mail", None, lambda: self.show_help("contacts"))
        A("about", f"О программе {APP_NAME}", "info", None, lambda: self.show_help("about"))

        # инструменты
        self.tool_group = QActionGroup(self)
        self.tool_group.setExclusive(True)
        for t in TOOLS:
            a = A(f"tool_{t.key}", t.title, t.icon, t.shortcut,
                  (lambda checked=False, k=t.key: self.state.set_tool(k)), checkable=True)
            a.setActionGroup(self.tool_group)
            a.setIcon(icons.icon(t.icon))
        self.actions[f"tool_{self.state.tool}"].setChecked(True)

    def _brush_size(self, factor):
        st = self.state.tool_settings()
        if st:
            new = st.size * factor
            new = max(new, st.size + 1) if factor > 1 else min(new, st.size - 1)
            st.size = float(max(1, min(300, round(new))))
            self.state.toolChanged.emit(self.state.tool)  # обновить панель
            self.state.settingsChanged.emit()

    # ------------------------------------------------------------------ UI parts
    def _create_toolbox(self):
        tb = QToolBar("Инструменты")
        tb.setObjectName("toolbox")
        tb.setOrientation(Qt.Vertical)
        tb.setMovable(False)
        tb.setIconSize(QSize(22, 22))
        for t in TOOLS:
            if t.key in TOOL_GROUP_STARTS:
                tb.addSeparator()
            tb.addAction(self.actions[f"tool_{t.key}"])
        self.addToolBar(Qt.LeftToolBarArea, tb)
        self.toolbox = tb

    def _create_topbar(self):
        tb = QToolBar("Основная панель")
        tb.setObjectName("topbar")
        tb.setMovable(False)
        tb.setIconSize(QSize(18, 18))
        logo = QLabel()
        logo.setPixmap(icons.pixmap("logo", theme.ACCENT, 22))
        logo.setContentsMargins(6, 0, 4, 0)
        tb.addWidget(logo)
        name = QLabel(f"<b>Mercury</b><span style='color:{theme.ACCENT}'><b>Toonz</b></span>")
        name.setContentsMargins(0, 0, 12, 0)
        tb.addWidget(name)
        for k in ("projects", "new", "save"):
            tb.addAction(self.actions[k])
        tb.addSeparator()
        for k in ("undo", "redo"):
            tb.addAction(self.actions[k])
        tb.addSeparator()
        tb.addAction(self.actions["export"])
        tb.addSeparator()
        tb.addAction(self.actions["record_audio"])
        tb.addAction(self.actions["import_audio"])
        spacer = QWidget()
        spacer.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
        tb.addWidget(spacer)
        tb.addAction(self.actions["onion"])
        tb.addAction(self.actions["zoom_fit"])
        tb.addAction(self.actions["scene"])
        self.addToolBar(Qt.TopToolBarArea, tb)
        self.topbar = tb

    def _dock(self, title, widget, area, name):
        d = QDockWidget(title, self)
        d.setObjectName(name)
        d.setWidget(widget)
        d.setFeatures(QDockWidget.DockWidgetMovable | QDockWidget.DockWidgetFloatable |
                      QDockWidget.DockWidgetClosable)
        self.addDockWidget(area, d)
        return d

    def _create_docks(self):
        self.tool_options = ToolOptions(self.state)
        self.color_panel = ColorPanel(self.state)
        self.timeline = Timeline(self.project, self.state, self.actions)
        self.layers_panel = LayersPanel(self.project, self.actions)
        tool_scroll = QScrollArea()
        tool_scroll.setWidget(self.tool_options)
        tool_scroll.setWidgetResizable(True)
        tool_scroll.setFrameShape(QScrollArea.NoFrame)
        tool_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        tool_scroll.setStyleSheet(f"QScrollArea, QScrollArea > QWidget > QWidget {{ background:{theme.BG_PANEL}; }}")
        self.tool_options.setAttribute(Qt.WA_StyledBackground)
        self.color_panel.setAttribute(Qt.WA_StyledBackground)

        def section(title, body):
            box = QWidget()
            box.setObjectName("panel")
            lay = QVBoxLayout(box)
            lay.setContentsMargins(0, 0, 0, 0)
            lay.setSpacing(0)
            head = QLabel(title)
            head.setStyleSheet(f"background:{theme.BG_PANEL}; color:{theme.TEXT_MUTED}; font-weight:600; "
                               f"padding:6px 10px; border-bottom:1px solid {theme.BORDER};")
            lay.addWidget(head)
            lay.addWidget(body, 1)
            return box

        # слева — настройки инструмента рядом с панелью инструментов
        self.dock_tool = self._dock("Инструмент", tool_scroll, Qt.LeftDockWidgetArea, "dockTool")
        # справа — цвет и под ним слои; граница перетаскивается
        self.props_split = QSplitter(Qt.Vertical)
        self.props_split.setHandleWidth(5)
        self.props_split.setChildrenCollapsible(False)
        self.props_split.addWidget(section("Цвет", self.color_panel))
        self.props_split.addWidget(section("Слои", self.layers_panel))
        self.props_split.setStretchFactor(0, 0)
        self.props_split.setStretchFactor(1, 1)
        self.props_split.setSizes([320, 400])
        self.dock_props = self._dock("Цвет и слои", self.props_split, Qt.RightDockWidgetArea, "dockProps")
        self.dock_props.setTitleBarWidget(QWidget())  # заголовки у секций свои
        self.dock_timeline = self._dock("Таймлайн", self.timeline, Qt.BottomDockWidgetArea, "dockTimeline")
        self.resizeDocks([self.dock_tool, self.dock_props], [270, 290], Qt.Horizontal)
        self.resizeDocks([self.dock_timeline], [240], Qt.Vertical)

    def _create_menus(self):
        mb = self.menuBar()
        a = self.actions

        def menu(title, items):
            m = mb.addMenu(title)
            for it in items:
                if it is None:
                    m.addSeparator()
                elif isinstance(it, tuple):
                    sub = m.addMenu(it[0])
                    for k in it[1]:
                        if k is None:
                            sub.addSeparator()
                        else:
                            sub.addAction(a[k])
                elif isinstance(it, QAction):
                    m.addAction(it)
                else:
                    m.addAction(a[it])
            return m

        file_menu = menu("Файл", ["projects", None, "new", "open", None, "save", "save_as", "rename_project", None,
                      "export", ("Экспорт в формат", ["export_mp4", "export_mov", "export_avi", None, "export_gif",
                                                  "export_png", None, "export_mp3"]), None, "quit"])
        self.recent_menu = QMenu("Недавние", self)
        file_menu.insertMenu(a["save"], self.recent_menu)
        file_menu.insertSeparator(a["save"])
        self._rebuild_recent()
        menu("Правка", ["undo", "redo", None, "cut", "copy", "paste", "clear", None,
                        "swap_colors", "size_up", "size_down"])
        menu("Вид", ["zoom_in", "zoom_out", "zoom_fit", "zoom_100", None, "onion", None,
                     self.dock_tool.toggleViewAction(), self.dock_props.toggleViewAction(),
                     self.dock_timeline.toggleViewAction()])
        tools = mb.addMenu("Инструменты")
        for t in TOOLS:
            tools.addAction(a[f"tool_{t.key}"])
        menu("Кадр", ["key", "key_blank", "key_remove", None, "frame_insert", "frame_remove", None,
                      "first", "prev", "next", "last", None, "prev_key", "next_key"])
        menu("Слой", ["layer_add", "layer_duplicate", "layer_delete", "layer_rename", None,
                      "layer_up", "layer_down"])
        menu("Дорожка", ["track_add_video", "track_add_audio", "track_delete", None,
                         "record_audio", "import_audio"])
        menu("Анимация", ["play", "loop", None, "tween", None, "scene"])
        menu("Справка", ["shortcuts", "changelog", None, "privacy", "contacts", None, "about"])

    def _create_statusbar(self):
        sb = self.statusBar()
        self.tool_label = QLabel()
        self.frame_label = QLabel()
        self.pos_label = QLabel("X     0   Y     0")
        self.pos_label.setMinimumWidth(130)
        self.zoom_label = QLabel(f"{self.canvas.zoom * 100:.0f}%")
        self.zoom_label.setMinimumWidth(50)
        self.size_label = QLabel()
        for w in (self.tool_label, self.frame_label, self.size_label, self.pos_label, self.zoom_label):
            sb.addPermanentWidget(w)

    # ------------------------------------------------------------------ behaviour
    def _on_tool_changed(self, tool):
        a = self.actions.get(f"tool_{tool}")
        if a and not a.isChecked():
            a.setChecked(True)
        self._update_status()

    def _update_status(self):
        p = self.project
        layer = p.layer()
        self.frame_label.setText(f"Кадр {p.current_frame + 1}/{p.frame_count}   ·   {layer.name if layer else '—'}")
        self.tool_label.setText(next(t.title for t in TOOLS if t.key == self.state.tool))
        self.size_label.setText(f"{p.width}×{p.height} · {p.fps} fps")

    def _update_title(self):
        dirty = " •" if self.project.is_dirty() else ""
        self.setWindowTitle(f"{self.project.name}{dirty} — {APP_NAME}")

    def _step(self, d):
        p = self.project
        f = p.current_frame + d
        if f >= p.frame_count:
            f = 0 if self.state.loop else p.frame_count - 1
        elif f < 0:
            f = p.frame_count - 1 if self.state.loop else 0
        p.set_frame(f)

    def _step_key(self, d):
        layer = self.project.layer()
        if layer is None:
            return
        f = self.project.current_frame
        keys = layer.sorted_keys()
        cand = [k for k in keys if (k > f if d > 0 else k < f)]
        if cand:
            self.project.set_frame(cand[0] if d > 0 else cand[-1])

    def toggle_play(self):
        a = self.actions["play"]
        if self.play_timer.isActive():
            self.play_timer.stop()
            self.playback.stop()
            a.setIcon(icons.icon("play"))
            a.setText("Воспроизвести")
        else:
            self.play_timer.start(max(1, round(1000 / self.project.fps)))
            self.playback.start(self.project.current_frame)
            a.setIcon(icons.icon("pause"))
            a.setText("Пауза")

    def _tick(self):
        p = self.project
        self.play_timer.setInterval(max(1, round(1000 / p.fps)))
        if p.current_frame + 1 >= p.frame_count and not self.state.loop:
            self.toggle_play()
            return
        self._step(1)
        self.playback.sync(p.current_frame)

    # ------------------------------------------------------------------ файлы
    def maybe_save(self) -> bool:
        """Спрашивает про несохранённые изменения. False — пользователь передумал."""
        if not self.project.is_dirty():
            return True
        box = QMessageBox(self)
        box.setIcon(QMessageBox.Question)
        box.setWindowTitle(APP_NAME)
        box.setText(f"Сохранить изменения в проекте «{self.project.name}»?")
        save = box.addButton("Сохранить", QMessageBox.AcceptRole)
        discard = box.addButton("Не сохранять", QMessageBox.DestructiveRole)
        box.addButton("Отмена", QMessageBox.RejectRole)
        box.setDefaultButton(save)
        box.exec()
        if box.clickedButton() is save:
            return self.save()
        return box.clickedButton() is discard

    def _stop_playback(self):
        if self.play_timer.isActive():
            self.toggle_play()

    def show_projects(self, startup: bool = False):
        self._stop_playback()
        dlg = pb.ProjectBrowser(self, current_path=self.project.file_path, startup=startup)
        if dlg.exec() != QDialog.Accepted or dlg.result_action is None:
            return
        kind, value = dlg.result_action
        if kind == "open":
            self.open_path(value)
        elif kind == "new":
            self.create_project(value)

    def new_project(self):
        self._stop_playback()
        dlg = pb.NewProjectDialog(fileformat.unique_name(pb.projects_folder(), "Мультфильм"), self)
        if dlg.exec() == QDialog.Accepted:
            self.create_project(dlg.values())

    def create_project(self, values: dict):
        if not self.maybe_save():
            return
        self.project.reset(**values)
        path = fileformat.unique_path(pb.projects_folder(), values["name"])
        self._write(path)
        self.canvas.fit_to_view()

    def open_dialog(self):
        path, _ = QFileDialog.getOpenFileName(self, "Открыть проект", pb.projects_folder(),
                                              f"Проекты MercuryToonz (*{fileformat.EXTENSION})")
        if path:
            self.open_path(path)

    def open_path(self, path: str) -> bool:
        if self.project.file_path and os.path.abspath(path) == os.path.abspath(self.project.file_path):
            return True  # уже открыт
        if not self.maybe_save():
            return False
        self._stop_playback()
        try:
            fileformat.load_project(path, self.project)
        except (fileformat.ProjectFileError, OSError, ValueError) as e:
            QMessageBox.warning(self, APP_NAME, f"Не удалось открыть «{os.path.basename(path)}».\n\n{e}")
            return False
        pb.remember_recent(path)
        self._rebuild_recent()
        self.canvas.fit_to_view()
        self.statusBar().showMessage(f"Открыт проект «{self.project.name}»", 3000)
        return True

    def _write(self, path: str) -> bool:
        p = self.project
        thumb = render_frame(p, first_drawn_frame(p), max_width=480)
        try:
            fileformat.save_project(p, path, thumb)
        except OSError as e:
            QMessageBox.warning(self, APP_NAME, f"Не удалось сохранить проект.\n\n{e}")
            return False
        p.mark_saved(path)
        pb.remember_recent(path)
        self.statusBar().showMessage(f"Сохранено: {path}", 3000)
        return True

    def save(self) -> bool:
        if not self.project.file_path:
            return self.save_as()
        return self._write(self.project.file_path)

    def save_as(self) -> bool:
        start = self.project.file_path or fileformat.unique_path(pb.projects_folder(), self.project.name)
        path, _ = QFileDialog.getSaveFileName(self, "Сохранить проект как", start,
                                              f"Проекты MercuryToonz (*{fileformat.EXTENSION})")
        if not path:
            return False
        if not path.endswith(fileformat.EXTENSION):
            path += fileformat.EXTENSION
        name = os.path.splitext(os.path.basename(path))[0]
        if self.project.file_path is None or name != os.path.splitext(os.path.basename(self.project.file_path))[0]:
            self.project.name = name
        return self._write(path)

    def rename_project(self):
        p = self.project
        name, ok = QInputDialog.getText(self, "Переименовать проект", "Название:", text=p.name)
        name = name.strip()
        if not ok or not name or name == p.name:
            return
        p.name = name
        if p.file_path:
            old = p.file_path
            new = fileformat.unique_path(os.path.dirname(old), name, exclude=old)
            if self._write(new) and os.path.abspath(new) != os.path.abspath(old):
                try:
                    os.remove(old)
                except OSError:
                    pass
        else:
            p.mark_dirty()
            p.fileChanged.emit()

    def _rebuild_recent(self):
        if not hasattr(self, "recent_menu"):
            return
        self.recent_menu.clear()
        files = pb.recent_files()
        for path in files:
            act = self.recent_menu.addAction(os.path.splitext(os.path.basename(path))[0])
            act.setToolTip(path)
            act.triggered.connect(lambda _=False, pth=path: self.open_path(pth))
        self.recent_menu.setEnabled(bool(files))

    def rename_layer(self):
        from PySide6.QtWidgets import QInputDialog
        layer = self.project.layer()
        if layer is None:
            return
        name, ok = QInputDialog.getText(self, "Переименовать слой", "Имя слоя:", text=layer.name)
        if ok:
            self.project.rename_layer(self.project.current_layer, name.strip())

    def scene_settings(self):
        dlg = SceneSettingsDialog(self.project, self)
        if dlg.exec() == QDialog.Accepted:
            self.project.set_scene(dlg.w.value(), dlg.h.value(), dlg.fps.value(), dlg.frames.value())

    def export_dialog(self, fmt: str = ""):
        self._stop_playback()
        last = pb.settings().value("export/format", "mp4")
        dlg = ExportDialog(self.project, fmt or last, self)
        if dlg.exec() == QDialog.Accepted and dlg.result_path:
            pb.settings().setValue("export/format", dlg.fmt.key)
            self.statusBar().showMessage(f"Готово: {dlg.result_path}", 6000)

    def delete_track(self):
        t = self.project.track()
        if t is None:
            return
        if t.animation:
            self.statusBar().showMessage("Дорожку «Анимация» удалить нельзя — на ней ваш рисунок", 3000)
            return
        if t.clips:
            r = QMessageBox.question(self, APP_NAME, f"Удалить дорожку «{t.name}» вместе с клипами ({len(t.clips)})?")
            if r != QMessageBox.Yes:
                return
        self.project.delete_track()

    def show_help(self, section: str = "about"):
        HelpDialog(SHORTCUTS_HELP, section, self).exec()

    # ------------------------------------------------------------------ звук
    def record_audio(self):
        self._stop_playback()
        start = self.project.current_frame
        dlg = RecordDialog(self)
        dlg.recordingStarted.connect(lambda: (self.project.set_frame(start), self.toggle_play()))
        dlg.recordingStopped.connect(self._stop_playback)
        ok = dlg.exec() == QDialog.Accepted
        self._stop_playback()
        self.project.set_frame(start)
        if ok and dlg.result_path:
            n = sum(len(t.clips) for t in self.project.tracks if t.kind == "audio") + 1
            self._add_audio(f"Запись {n}", dlg.result_id, dlg.result_path, start)

    def import_audio(self):
        self._stop_playback()
        path, _ = QFileDialog.getOpenFileName(
            self, "Импорт звука", os.path.expanduser("~"),
            "Звук (*.wav *.mp3 *.ogg *.oga *.m4a *.aac *.flac *.opus *.wma);;Все файлы (*)")
        if not path:
            return
        mid, dst = audio.new_media_path()
        QApplication.setOverrideCursor(Qt.WaitCursor)
        try:
            if path.lower().endswith(".wav"):
                try:
                    audio.analyze_wav(path)
                    shutil.copyfile(path, dst)
                except Exception:  # WAV в необычном кодеке — перекодируем
                    audio.decode_to_wav(path, dst)
            else:
                audio.decode_to_wav(path, dst)
        except OSError as e:
            QApplication.restoreOverrideCursor()
            QMessageBox.warning(self, APP_NAME, f"Не удалось открыть звук «{os.path.basename(path)}».\n\n{e}")
            return
        QApplication.restoreOverrideCursor()
        self._add_audio(os.path.splitext(os.path.basename(path))[0], mid, dst, self.project.current_frame)

    def _add_audio(self, name: str, media_id: str, path: str, start: int):
        try:
            duration, peaks = audio.analyze_wav(path)
        except Exception as e:  # noqa: BLE001
            QMessageBox.warning(self, APP_NAME, f"Не удалось прочитать звук.\n\n{e}")
            return
        if duration <= 0:
            self.statusBar().showMessage("Пустая запись — ничего не добавлено", 3000)
            return
        self.project.add_audio_clip(name, media_id, path, start, duration, peaks)
        self.statusBar().showMessage(f"Добавлен звук «{name}», {duration:.1f} с", 3000)

    def closeEvent(self, e):
        self._stop_playback()
        if self.maybe_save():
            e.accept()
        else:
            e.ignore()


def run(argv) -> int:
    app = QApplication(argv)
    app.setApplicationName(APP_NAME)
    app.setApplicationVersion(APP_VERSION)
    app.setStyle("Fusion")
    app.setStyleSheet(theme.STYLESHEET)
    w = MainWindow()
    w.show()
    files = [a for a in argv[1:] if a.endswith(fileformat.EXTENSION) and os.path.exists(a)]
    if files:
        w.open_path(os.path.abspath(files[0]))
    else:
        # окно проектов поверх главного окна сразу после запуска
        QTimer.singleShot(0, lambda: w.show_projects(startup=True))
    return app.exec()
