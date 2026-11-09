"""Окно «Проекты»: список проектов в рабочей папке, создание, открытие, удаление."""

from __future__ import annotations

import os
from datetime import datetime

from PySide6.QtCore import QRectF, QSettings, QSize, QStandardPaths, Qt, QUrl
from PySide6.QtGui import QColor, QDesktopServices, QFont, QPainter, QPainterPath, QPen
from PySide6.QtWidgets import (
    QAbstractItemView, QButtonGroup, QComboBox, QGridLayout, QDialog, QDialogButtonBox, QFileDialog, QFormLayout,
    QHBoxLayout, QInputDialog, QLabel, QLineEdit, QListWidget, QListWidgetItem, QMenu,
    QMessageBox, QPushButton, QSpinBox, QStackedWidget, QStyle, QStyledItemDelegate,
    QVBoxLayout, QWidget,
)

from .. import APP_NAME, brand, fileformat, icons, theme

# Пропорции кадра: (ключ, подпись, где используется, ширина, высота, [разрешения])
ASPECTS = [
    ("16:9", "16:9", "YouTube, ТВ", 16, 9,
     [(3840, 2160, "4K"), (2560, 1440, "2K"), (1920, 1080, "Full HD"), (1280, 720, "HD"), (854, 480, "480p")]),
    ("9:16", "9:16", "Shorts, Reels, TikTok", 9, 16,
     [(2160, 3840, "4K"), (1080, 1920, "Full HD"), (720, 1280, "HD")]),
    ("1:1", "1:1", "Квадрат, аватарки", 1, 1,
     [(2160, 2160, "4K"), (1080, 1080, "Full HD"), (720, 720, "HD")]),
    ("4:5", "4:5", "Лента Instagram", 4, 5,
     [(2160, 2700, "4K"), (1080, 1350, "Full HD")]),
    ("4:3", "4:3", "Классический ТВ", 4, 3,
     [(2880, 2160, "4K"), (1440, 1080, "Full HD"), (1024, 768, "XGA"), (640, 480, "VGA")]),
    ("21:9", "21:9", "Кино, широкий", 21, 9,
     [(3440, 1440, "UWQHD"), (2560, 1080, "UW Full HD")]),
    ("custom", "Свой", "Любой размер", 3, 2, []),
]
DEFAULT_ASPECT = "16:9"
DEFAULT_SIZE = (1920, 1080)
FPS_CHOICES = [8, 12, 15, 24, 25, 30, 48, 50, 60]

CARD_W, CARD_H = 232, 206
THUMB_H = 130
ROLE_INFO = Qt.UserRole + 1


def settings() -> QSettings:
    return QSettings("Mercury", "MercuryToonz")


def projects_folder() -> str:
    default = os.path.join(
        QStandardPaths.writableLocation(QStandardPaths.DocumentsLocation) or os.path.expanduser("~"),
        "MercuryToonz",
    )
    folder = settings().value("projects/folder", default)
    os.makedirs(folder, exist_ok=True)
    return folder


def set_projects_folder(folder: str):
    settings().setValue("projects/folder", folder)


def remember_recent(path: str):
    s = settings()
    recent = [p for p in (s.value("projects/recent", []) or []) if p != path]
    s.setValue("projects/recent", [path] + recent[:9])


def recent_files() -> list[str]:
    return [p for p in (settings().value("projects/recent", []) or []) if os.path.exists(p)]


def human_time(dt: datetime) -> str:
    delta = datetime.now().astimezone() - dt
    sec = int(delta.total_seconds())
    if sec < 60:
        return "только что"
    if sec < 3600:
        return f"{sec // 60} мин назад"
    if sec < 86400:
        return f"{sec // 3600} ч назад"
    if sec < 86400 * 7:
        return f"{sec // 86400} дн назад"
    return dt.strftime("%d.%m.%Y")


# ------------------------------------------------------------------ новый проект
class AspectCard(QPushButton):
    """Кнопка-карточка с прямоугольником в пропорциях кадра."""

    def __init__(self, key, title, subtitle, rw, rh):
        super().__init__()
        self.key, self.title, self.subtitle, self.rw, self.rh = key, title, subtitle, rw, rh
        self.setCheckable(True)
        self.setFixedSize(122, 112)
        self.setCursor(Qt.PointingHandCursor)
        self.setToolTip(f"{title} — {subtitle}")

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        r = QRectF(self.rect()).adjusted(1, 1, -1, -1)
        on, hover = self.isChecked(), self.underMouse()
        p.setPen(QPen(QColor(theme.ACCENT if on else (theme.TEXT_MUTED if hover else theme.BORDER)), 2 if on else 1))
        p.setBrush(QColor(theme.BG_RAISED if (on or hover) else theme.BG_PANEL))
        p.drawRoundedRect(r, 8, 8)
        box = 46
        k = box / max(self.rw, self.rh)
        w, h = self.rw * k, self.rh * k
        frame = QRectF(r.center().x() - w / 2, 12 + (box - h) / 2, w, h)
        p.setBrush(QColor(theme.ACCENT if on else "#3a404b"))
        p.setPen(Qt.NoPen)
        if self.key == "custom":
            p.setBrush(Qt.NoBrush)
            p.setPen(QPen(QColor(theme.ACCENT if on else theme.TEXT_MUTED), 1.5, Qt.DashLine))
        p.drawRoundedRect(frame, 3, 3)
        f = QFont(self.font())
        f.setPixelSize(14)
        f.setBold(True)
        p.setFont(f)
        p.setPen(QColor(theme.TEXT))
        p.drawText(QRectF(r.left(), 64, r.width(), 20), Qt.AlignCenter, self.title)
        f.setPixelSize(11)
        f.setBold(False)
        p.setFont(f)
        p.setPen(QColor(theme.TEXT_MUTED))
        p.drawText(QRectF(r.left() + 4, 84, r.width() - 8, 18), Qt.AlignCenter,
                   p.fontMetrics().elidedText(self.subtitle, Qt.ElideRight, int(r.width() - 8)))


class NewProjectDialog(QDialog):
    """Новый проект: сначала пропорции кадра, затем разрешение, частота и длина."""

    def __init__(self, default_name: str, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Новый проект")
        lay = QVBoxLayout(self)
        lay.setContentsMargins(24, 20, 24, 18)
        lay.setSpacing(14)
        title = QLabel("Новый проект")
        title.setStyleSheet("font-size: 20px; font-weight: 600;")
        lay.addWidget(title)

        name_row = QHBoxLayout()
        name_row.addWidget(QLabel("Название"))
        self.name = QLineEdit(default_name)
        self.name.selectAll()
        name_row.addWidget(self.name, 1)
        lay.addLayout(name_row)

        sec = QLabel("ПРОПОРЦИИ КАДРА")
        sec.setObjectName("sectionTitle")
        lay.addWidget(sec)
        cards = QGridLayout()
        cards.setSpacing(8)
        self.cards: dict[str, AspectCard] = {}
        group = QButtonGroup(self)
        group.setExclusive(True)
        for i, (key, t, sub, rw, rh, _res) in enumerate(ASPECTS):
            c = AspectCard(key, t, sub, rw, rh)
            group.addButton(c)
            c.clicked.connect(lambda _=False, k=key: self._select_aspect(k))
            self.cards[key] = c
            cards.addWidget(c, i // 4, i % 4)
        lay.addLayout(cards)

        form = QFormLayout()
        form.setSpacing(10)
        form.setLabelAlignment(Qt.AlignRight)
        self.quality = QComboBox()
        form.addRow("Разрешение", self.quality)
        size_row = QHBoxLayout()
        self.w = QSpinBox()
        self.w.setRange(16, 8192)
        self.w.setSuffix(" px")
        self.h = QSpinBox()
        self.h.setRange(16, 8192)
        self.h.setSuffix(" px")
        self.swap = QPushButton("⇄")
        self.swap.setToolTip("Поменять ширину и высоту местами")
        self.swap.setFixedWidth(36)
        size_row.addWidget(self.w)
        size_row.addWidget(QLabel("×"))
        size_row.addWidget(self.h)
        size_row.addWidget(self.swap)
        size_row.addStretch()
        form.addRow("Размер кадра", size_row)
        self.fps = QComboBox()
        for f in FPS_CHOICES:
            self.fps.addItem(f"{f} кадров/с", f)
        self.fps.setCurrentIndex(FPS_CHOICES.index(24))
        form.addRow("Частота", self.fps)
        dur_row = QHBoxLayout()
        self.frames = QSpinBox()
        self.frames.setRange(1, 99999)
        self.frames.setValue(48)
        self.seconds = QLabel()
        self.seconds.setStyleSheet(f"color:{theme.TEXT_MUTED};")
        dur_row.addWidget(self.frames)
        dur_row.addWidget(self.seconds)
        dur_row.addStretch()
        form.addRow("Длина (кадров)", dur_row)
        lay.addLayout(form)

        buttons = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        buttons.button(QDialogButtonBox.Ok).setText("Создать")
        buttons.button(QDialogButtonBox.Ok).setDefault(True)
        buttons.button(QDialogButtonBox.Cancel).setText("Отмена")
        buttons.accepted.connect(self._accept)
        buttons.rejected.connect(self.reject)
        lay.addWidget(buttons)

        self.quality.currentIndexChanged.connect(self._on_quality)
        self.w.valueChanged.connect(self._on_size_edit)
        self.h.valueChanged.connect(self._on_size_edit)
        self.swap.clicked.connect(self._swap)
        self.fps.currentIndexChanged.connect(self._on_duration)
        self.frames.valueChanged.connect(self._on_duration)
        self._aspect = None
        self._select_aspect(DEFAULT_ASPECT)
        self._set_size(*DEFAULT_SIZE)
        self._on_duration()

    def _aspect_info(self, key):
        return next(a for a in ASPECTS if a[0] == key)

    def _select_aspect(self, key):
        self._aspect = key
        self.cards[key].setChecked(True)
        res = self._aspect_info(key)[5]
        self.quality.blockSignals(True)
        self.quality.clear()
        for w, h, label in res:
            self.quality.addItem(f"{label}  ·  {w}×{h}", (w, h))
        self.quality.addItem("Свой размер", None)
        # по умолчанию — Full HD, если есть, иначе первое
        idx = next((i for i, (_w, _h, lbl) in enumerate(res) if lbl == "Full HD"), 0)
        self.quality.setCurrentIndex(idx if res else self.quality.count() - 1)
        self.quality.blockSignals(False)
        custom = key == "custom"
        self.quality.setEnabled(not custom)
        if not custom:
            self._on_quality()

    def _set_size(self, w, h):
        for sb, v in ((self.w, w), (self.h, h)):
            sb.blockSignals(True)
            sb.setValue(v)
            sb.blockSignals(False)

    def _on_quality(self):
        data = self.quality.currentData()
        if data:
            self._set_size(*data)

    def _on_size_edit(self):
        # подбираем подходящие пропорции и разрешение под введённый размер
        w, h = self.w.value(), self.h.value()
        for key, _t, _s, rw, rh, res in ASPECTS:
            for i, (rw2, rh2, _l) in enumerate(res):
                if (rw2, rh2) == (w, h):
                    if self._aspect != key:
                        self._select_aspect(key)
                    self.quality.blockSignals(True)
                    self.quality.setCurrentIndex(i)
                    self.quality.blockSignals(False)
                    return
        for key, _t, _s, rw, rh, res in ASPECTS:
            if res and abs(w / h - rw / rh) < 0.01:
                if self._aspect != key:
                    self._select_aspect(key)
                    self._set_size(w, h)
                break
        else:
            self.cards["custom"].setChecked(True)
            self._aspect = "custom"
        self.quality.blockSignals(True)
        self.quality.setCurrentIndex(self.quality.count() - 1)
        self.quality.blockSignals(False)

    def _swap(self):
        self._set_size(self.h.value(), self.w.value())
        self._on_size_edit()

    def _on_duration(self):
        self.seconds.setText(f"≈ {self.frames.value() / self.fps.currentData():.1f} с")

    def _accept(self):
        if not self.name.text().strip():
            self.name.setFocus()
            return
        self.accept()

    def values(self) -> dict:
        return {
            "name": self.name.text().strip(),
            "width": self.w.value(),
            "height": self.h.value(),
            "fps": self.fps.currentData(),
            "frame_count": self.frames.value(),
        }


# ------------------------------------------------------------------ карточки
class CardDelegate(QStyledItemDelegate):
    def sizeHint(self, option, index):
        return QSize(CARD_W, CARD_H)

    def paint(self, p: QPainter, option, index):
        info: fileformat.ProjectInfo = index.data(ROLE_INFO)
        r = QRectF(option.rect).adjusted(6, 6, -6, -6)
        selected = bool(option.state & QStyle.State_Selected)
        hover = bool(option.state & QStyle.State_MouseOver)
        p.save()
        p.setRenderHint(QPainter.Antialiasing)
        p.setPen(QPen(QColor(theme.ACCENT if selected else (theme.TEXT_MUTED if hover else theme.BORDER)),
                      2 if selected else 1))
        p.setBrush(QColor(theme.BG_RAISED if (hover or selected) else theme.BG_PANEL))
        p.drawRoundedRect(r, 10, 10)

        thumb_r = QRectF(r.left() + 8, r.top() + 8, r.width() - 16, THUMB_H)
        clip = QPainterPath()
        clip.addRoundedRect(thumb_r, 6, 6)
        p.setClipPath(clip)
        p.fillRect(thumb_r, QColor(theme.BG_DEEP))
        if info.thumbnail is not None and not info.thumbnail.isNull():
            img = info.thumbnail
            s = min(thumb_r.width() / img.width(), thumb_r.height() / img.height())
            w, h = img.width() * s, img.height() * s
            p.drawImage(QRectF(thumb_r.center().x() - w / 2, thumb_r.center().y() - h / 2, w, h), img)
        else:
            p.setOpacity(0.5)
            p.drawPixmap(int(thumb_r.center().x() - 24), int(thumb_r.center().y() - 24), brand.logo_pixmap(48))
            p.setOpacity(1.0)
        p.setClipping(False)

        f = QFont(option.font)
        f.setPixelSize(14)
        f.setBold(True)
        p.setFont(f)
        p.setPen(QColor(theme.TEXT))
        text_r = QRectF(r.left() + 12, thumb_r.bottom() + 8, r.width() - 24, 20)
        p.drawText(text_r, Qt.AlignLeft | Qt.AlignVCenter,
                   p.fontMetrics().elidedText(info.name, Qt.ElideRight, int(text_r.width())))
        f.setBold(False)
        f.setPixelSize(12)
        p.setFont(f)
        p.setPen(QColor(theme.TEXT_MUTED))
        secs = info.frames / max(1, info.fps)
        line = f"{human_time(info.modified_dt)} · {info.width}×{info.height} · {secs:.1f} с"
        p.drawText(QRectF(text_r.left(), text_r.bottom() + 2, text_r.width(), 18),
                   Qt.AlignLeft | Qt.AlignVCenter,
                   p.fontMetrics().elidedText(line, Qt.ElideRight, int(text_r.width())))
        p.restore()


# ------------------------------------------------------------------ окно проектов
class ProjectBrowser(QDialog):
    """Возвращает выбор через self.result_action: ("open", path) или ("new", values)."""

    def __init__(self, parent=None, current_path: str | None = None, startup: bool = False):
        super().__init__(parent)
        self.setWindowTitle(f"Проекты — {APP_NAME}")
        self.resize(1080, 700)
        self.result_action: tuple | None = None
        self.current_path = current_path
        self._infos: list[fileformat.ProjectInfo] = []

        root = QHBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # --- боковая панель ---
        side = QWidget()
        side.setObjectName("panel")
        side.setFixedWidth(250)
        side.setStyleSheet(f"#panel {{ background:{theme.BG_PANEL}; border-right:1px solid {theme.BORDER}; }}")
        sl = QVBoxLayout(side)
        sl.setContentsMargins(18, 20, 18, 18)
        sl.setSpacing(8)
        head = QHBoxLayout()
        logo = QLabel()
        logo.setPixmap(brand.logo_pixmap(36))
        head.addWidget(logo)
        head.addWidget(QLabel(f"<span style='font-size:18px'><b>Mercury</b>"
                               f"<b style='color:{theme.ACCENT}'>Toonz</b></span>"))
        head.addStretch()
        sl.addLayout(head)
        sl.addSpacing(18)

        self.btn_new = QPushButton("  Новый проект")
        self.btn_new.setIcon(icons.icon("plus", "#ffffff"))
        self.btn_new.setDefault(True)
        self.btn_new.setMinimumHeight(38)
        sl.addWidget(self.btn_new)
        self.btn_open_file = QPushButton("  Открыть файл…")
        self.btn_open_file.setIcon(icons.icon("open"))
        self.btn_open_file.setMinimumHeight(34)
        sl.addWidget(self.btn_open_file)
        self.btn_import = QPushButton("  Добавить в библиотеку…")
        self.btn_import.setIcon(icons.icon("layer-add"))
        self.btn_import.setMinimumHeight(34)
        self.btn_import.setToolTip("Скопировать файл .mtoonz в папку проектов")
        sl.addWidget(self.btn_import)
        sl.addStretch()

        folder_title = QLabel("ПАПКА ПРОЕКТОВ")
        folder_title.setObjectName("sectionTitle")
        sl.addWidget(folder_title)
        self.folder_label = QLabel()
        self.folder_label.setWordWrap(True)
        self.folder_label.setStyleSheet(f"color:{theme.TEXT_MUTED}; font-size:12px;")
        sl.addWidget(self.folder_label)
        frow = QHBoxLayout()
        self.btn_folder = QPushButton("Изменить…")
        self.btn_show_folder = QPushButton("Показать")
        frow.addWidget(self.btn_folder)
        frow.addWidget(self.btn_show_folder)
        sl.addLayout(frow)
        if startup:
            sl.addSpacing(8)
            self.btn_skip = QPushButton("Пустой проект без сохранения")
            self.btn_skip.setFlat(True)
            self.btn_skip.setStyleSheet(f"color:{theme.TEXT_MUTED}; border:none; text-align:left; padding:4px 0;")
            self.btn_skip.clicked.connect(self.reject)
            sl.addWidget(self.btn_skip)
        root.addWidget(side)

        # --- основная часть ---
        main = QWidget()
        main.setStyleSheet(f"background:{theme.BG_DEEP};")
        ml = QVBoxLayout(main)
        ml.setContentsMargins(24, 20, 24, 16)
        ml.setSpacing(14)
        head = QHBoxLayout()
        h = QLabel("Проекты")
        h.setStyleSheet("font-size: 22px; font-weight: 600;")
        head.addWidget(h)
        self.count_label = QLabel()
        self.count_label.setStyleSheet(f"color:{theme.TEXT_MUTED}; padding-top:6px;")
        head.addWidget(self.count_label)
        head.addStretch()
        self.search = QLineEdit()
        self.search.setPlaceholderText("Поиск…")
        self.search.setClearButtonEnabled(True)
        self.search.setFixedWidth(220)
        head.addWidget(self.search)
        self.sort = QComboBox()
        self.sort.addItem("Сначала новые", "modified")
        self.sort.addItem("По имени", "name")
        self.sort.addItem("Сначала старые", "oldest")
        head.addWidget(self.sort)
        ml.addLayout(head)

        self.stack = QStackedWidget()
        self.list = QListWidget()
        self.list.setViewMode(QListWidget.IconMode)
        self.list.setResizeMode(QListWidget.Adjust)
        self.list.setMovement(QListWidget.Static)
        self.list.setUniformItemSizes(True)
        self.list.setGridSize(QSize(CARD_W, CARD_H))
        self.list.setSpacing(0)
        self.list.setMouseTracking(True)
        self.list.setSelectionMode(QAbstractItemView.SingleSelection)
        self.list.setItemDelegate(CardDelegate(self.list))
        self.list.setContextMenuPolicy(Qt.CustomContextMenu)
        self.list.setStyleSheet("QListWidget { background: transparent; border: none; outline: none; }")
        self.stack.addWidget(self.list)

        empty = QWidget()
        el = QVBoxLayout(empty)
        el.addStretch()
        ei = QLabel()
        ei.setPixmap(brand.logo_pixmap(96, True))
        ei.setAlignment(Qt.AlignCenter)
        el.addWidget(ei)
        self.empty_title = QLabel("Здесь пока пусто")
        self.empty_title.setAlignment(Qt.AlignCenter)
        self.empty_title.setStyleSheet("font-size:17px; font-weight:600;")
        el.addWidget(self.empty_title)
        self.empty_text = QLabel("Создайте первый проект — он появится в этом списке.")
        self.empty_text.setAlignment(Qt.AlignCenter)
        self.empty_text.setStyleSheet(f"color:{theme.TEXT_MUTED};")
        el.addWidget(self.empty_text)
        el.addStretch()
        self.stack.addWidget(empty)
        ml.addWidget(self.stack, 1)

        bottom = QHBoxLayout()
        self.btn_delete = QPushButton("  Удалить")
        self.btn_delete.setIcon(icons.icon("trash"))
        self.btn_rename = QPushButton("Переименовать")
        self.btn_dup = QPushButton("  Дублировать")
        self.btn_dup.setIcon(icons.icon("duplicate"))
        for b in (self.btn_delete, self.btn_rename, self.btn_dup):
            bottom.addWidget(b)
        bottom.addStretch()
        self.btn_open = QPushButton("Открыть")
        self.btn_open.setMinimumWidth(120)
        self.btn_open.setStyleSheet(f"QPushButton {{ background:{theme.ACCENT}; color:#ffffff; "
                                    f"border-color:{theme.ACCENT}; font-weight:600; }}"
                                    "QPushButton:disabled { background:#1f2a4d; color:#6b7698; }")
        bottom.addWidget(self.btn_open)
        ml.addLayout(bottom)
        root.addWidget(main, 1)

        # --- сигналы ---
        self.btn_new.clicked.connect(self.new_project)
        self.btn_open_file.clicked.connect(self.open_file)
        self.btn_import.clicked.connect(self.import_file)
        self.btn_folder.clicked.connect(self.change_folder)
        self.btn_show_folder.clicked.connect(
            lambda: QDesktopServices.openUrl(QUrl.fromLocalFile(projects_folder())))
        self.btn_open.clicked.connect(self.open_selected)
        self.btn_delete.clicked.connect(self.delete_selected)
        self.btn_rename.clicked.connect(self.rename_selected)
        self.btn_dup.clicked.connect(self.duplicate_selected)
        self.list.itemDoubleClicked.connect(lambda _: self.open_selected())
        self.list.itemSelectionChanged.connect(self._update_buttons)
        self.list.customContextMenuRequested.connect(self._context_menu)
        self.search.textChanged.connect(lambda _: self._fill())
        self.sort.currentIndexChanged.connect(lambda _: self._fill())
        self.refresh()

    # ---------- данные ----------
    def refresh(self, select: str | None = None):
        folder = projects_folder()
        self.folder_label.setText(folder)
        self._infos = fileformat.list_projects(folder)
        self._fill(select)

    def _fill(self, select: str | None = None):
        q = self.search.text().strip().lower()
        infos = [i for i in self._infos if q in i.name.lower()]
        mode = self.sort.currentData()
        if mode == "name":
            infos.sort(key=lambda i: i.name.lower())
        elif mode == "oldest":
            infos.sort(key=lambda i: i.modified_dt)
        self.list.clear()
        for info in infos:
            it = QListWidgetItem()
            it.setData(ROLE_INFO, info)
            it.setToolTip(info.path)
            it.setSizeHint(QSize(CARD_W, CARD_H))
            self.list.addItem(it)
            if select and os.path.abspath(info.path) == os.path.abspath(select):
                it.setSelected(True)
                self.list.setCurrentItem(it)
        total = len(self._infos)
        self.count_label.setText(f"{total}" if total else "")
        if infos:
            self.stack.setCurrentIndex(0)
        else:
            self.stack.setCurrentIndex(1)
            if q:
                self.empty_title.setText("Ничего не найдено")
                self.empty_text.setText(f"Нет проектов с «{self.search.text()}» в названии.")
            else:
                self.empty_title.setText("Здесь пока пусто")
                self.empty_text.setText("Создайте первый проект — он появится в этом списке.")
        self._update_buttons()

    def _selected(self) -> fileformat.ProjectInfo | None:
        items = self.list.selectedItems()
        return items[0].data(ROLE_INFO) if items else None

    def _update_buttons(self):
        has = self._selected() is not None
        for b in (self.btn_open, self.btn_delete, self.btn_rename, self.btn_dup):
            b.setEnabled(has)

    def _is_current(self, info) -> bool:
        return bool(self.current_path) and os.path.abspath(info.path) == os.path.abspath(self.current_path)

    # ---------- действия ----------
    def new_project(self):
        dlg = NewProjectDialog(fileformat.unique_name(projects_folder(), "Мультфильм"), self)
        if dlg.exec() == QDialog.Accepted:
            self.result_action = ("new", dlg.values())
            self.accept()

    def open_selected(self):
        info = self._selected()
        if info:
            self.result_action = ("open", info.path)
            self.accept()

    def open_file(self):
        path, _ = QFileDialog.getOpenFileName(self, "Открыть проект", projects_folder(),
                                              f"Проекты MercuryToonz (*{fileformat.EXTENSION})")
        if path:
            self.result_action = ("open", path)
            self.accept()

    def import_file(self):
        path, _ = QFileDialog.getOpenFileName(self, "Добавить проект в библиотеку", os.path.expanduser("~"),
                                              f"Проекты MercuryToonz (*{fileformat.EXTENSION})")
        if not path:
            return
        try:
            dst = fileformat.copy_into(projects_folder(), path)
        except (fileformat.ProjectFileError, OSError) as e:
            QMessageBox.warning(self, APP_NAME, str(e))
            return
        self.refresh(select=dst)

    def change_folder(self):
        folder = QFileDialog.getExistingDirectory(self, "Папка проектов", projects_folder())
        if folder:
            set_projects_folder(folder)
            self.refresh()

    def delete_selected(self):
        info = self._selected()
        if not info:
            return
        if self._is_current(info):
            QMessageBox.information(self, APP_NAME, "Этот проект сейчас открыт. Сначала откройте или создайте другой.")
            return
        box = QMessageBox(self)
        box.setIcon(QMessageBox.Warning)
        box.setWindowTitle("Удалить проект")
        box.setText(f"Удалить проект «{info.name}»?")
        box.setInformativeText("Файл будет перемещён в корзину. Если корзины нет — удалён без возможности восстановления.")
        delete = box.addButton("Удалить", QMessageBox.DestructiveRole)
        box.addButton("Отмена", QMessageBox.RejectRole)
        box.exec()
        if box.clickedButton() is not delete:
            return
        try:
            fileformat.delete_project(info.path)
        except OSError as e:
            QMessageBox.warning(self, APP_NAME, f"Не удалось удалить: {e}")
        self.refresh()

    def rename_selected(self):
        info = self._selected()
        if not info:
            return
        if self._is_current(info):
            QMessageBox.information(self, APP_NAME,
                                    "Этот проект сейчас открыт. Переименуйте его в главном окне: Файл → Переименовать.")
            return
        name, ok = QInputDialog.getText(self, "Переименовать проект", "Новое название:", text=info.name)
        name = name.strip()
        if ok and name and name != info.name:
            try:
                dst = fileformat.rename_project(info.path, name)
            except (fileformat.ProjectFileError, OSError) as e:
                QMessageBox.warning(self, APP_NAME, str(e))
                return
            self.refresh(select=dst)

    def duplicate_selected(self):
        info = self._selected()
        if not info:
            return
        try:
            dst = fileformat.duplicate_project(info.path)
        except (fileformat.ProjectFileError, OSError) as e:
            QMessageBox.warning(self, APP_NAME, str(e))
            return
        self.refresh(select=dst)

    def _context_menu(self, pos):
        item = self.list.itemAt(pos)
        if item is None:
            return
        self.list.setCurrentItem(item)
        info = item.data(ROLE_INFO)
        m = QMenu(self)
        m.addAction("Открыть", self.open_selected)
        m.addAction("Переименовать…", self.rename_selected)
        m.addAction("Дублировать", self.duplicate_selected)
        m.addAction("Показать в папке",
                    lambda: QDesktopServices.openUrl(QUrl.fromLocalFile(os.path.dirname(info.path))))
        m.addSeparator()
        m.addAction("Удалить…", self.delete_selected)
        m.exec(self.list.mapToGlobal(pos))

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Delete and self.list.hasFocus():
            self.delete_selected()
            return
        if e.key() in (Qt.Key_Return, Qt.Key_Enter) and self._selected():
            self.open_selected()
            return
        super().keyPressEvent(e)
