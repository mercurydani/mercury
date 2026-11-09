"""Панель «Элемент»: свойства выбранного клипа или слоя, ключевые кадры, скорость, библиотека анимаций."""

from __future__ import annotations

from PySide6.QtCore import QSize, Qt
from PySide6.QtWidgets import (
    QCheckBox, QComboBox, QDoubleSpinBox, QGridLayout, QHBoxLayout, QLabel, QListWidget, QListWidgetItem,
    QPushButton, QSpinBox, QToolButton, QVBoxLayout, QWidget,
)

from .. import icons, theme
from ..animation import (
    CORNERS, DEFAULTS, EASING_KEYS, EASINGS, GROUPS, PRESETS, PRESETS_BY_KEY, apply_preset,
)
from ..model import Project, VisualClip

KIND_TITLE = {"video": "Видео", "image": "Картинка", "gif": "GIF"}
PRESET_GROUPS = [("in", "ПОЯВЛЕНИЕ"), ("out", "ИСЧЕЗНОВЕНИЕ"), ("anim", "АНИМАЦИЯ")]

# (свойство, подпись, минимум, максимум, множитель для показа, суффикс)
FIELDS = {
    "x": ("X", -20000, 20000, 1, " px"), "y": ("Y", -20000, 20000, 1, " px"),
    "sx": ("Ш", -2000, 2000, 100, " %"), "sy": ("В", -2000, 2000, 100, " %"),
    "rot": ("", -36000, 36000, 1, "°"), "skx": ("", -80, 80, 1, "°"),
    "opacity": ("", 0, 100, 100, " %"),
}


def _section(title: str) -> QLabel:
    lab = QLabel(title)
    lab.setObjectName("sectionTitle")
    return lab


class Inspector(QWidget):
    def __init__(self, project: Project, parent=None):
        super().__init__(parent)
        self.project = project
        self.setObjectName("panel")
        self.setAttribute(Qt.WA_StyledBackground)
        self._updating = False
        root = QVBoxLayout(self)
        root.setContentsMargins(12, 10, 12, 12)
        root.setSpacing(9)

        head = QHBoxLayout()
        self.icon = QLabel()
        self.title = QLabel()
        self.title.setStyleSheet("font-size:15px; font-weight:600;")
        self.title.setWordWrap(True)
        head.addWidget(self.icon)
        head.addWidget(self.title, 1)
        root.addLayout(head)
        self.subtitle = QLabel()
        self.subtitle.setWordWrap(True)
        self.subtitle.setStyleSheet(f"color:{theme.TEXT_MUTED}; font-size:12px;")
        root.addWidget(self.subtitle)

        self.empty = QWidget()
        el = QVBoxLayout(self.empty)
        el.setContentsMargins(0, 6, 0, 0)
        hint = QLabel("Выберите клип на видеодорожке или рисованный слой — и двигайте, вращайте, "
                      "деформируйте его по ключевым кадрам.\n\nИнструмент «Трансформация» (Q) — рамка с ручками "
                      "прямо на холсте.")
        hint.setWordWrap(True)
        hint.setStyleSheet(f"color:{theme.TEXT_MUTED};")
        el.addWidget(hint)
        self.make_layer = QPushButton("Сделать текущий слой элементом")
        self.make_layer.clicked.connect(self._select_layer)
        el.addWidget(self.make_layer)
        root.addWidget(self.empty)

        self.body = QWidget()
        bl = QVBoxLayout(self.body)
        bl.setContentsMargins(0, 0, 0, 0)
        bl.setSpacing(9)

        # --- клип: скорость и длина ---
        self.clip_box = QWidget()
        cg = QGridLayout(self.clip_box)
        cg.setContentsMargins(0, 0, 0, 0)
        cg.setHorizontalSpacing(8)
        cg.addWidget(_section("КЛИП"), 0, 0, 1, 3)
        cg.addWidget(QLabel("Скорость"), 1, 0)
        self.speed = QSpinBox()
        self.speed.setRange(10, 1000)
        self.speed.setSuffix(" %")
        self.speed.setKeyboardTracking(False)
        cg.addWidget(self.speed, 1, 1)
        self.speed_hint = QLabel()
        self.speed_hint.setStyleSheet(f"color:{theme.TEXT_MUTED}; font-size:11px;")
        cg.addWidget(self.speed_hint, 1, 2)
        cg.addWidget(QLabel("Длина"), 2, 0)
        self.length = QSpinBox()
        self.length.setRange(1, 999999)
        self.length.setSuffix(" кадр.")
        self.length.setKeyboardTracking(False)
        cg.addWidget(self.length, 2, 1)
        self.fit_len = QPushButton("По исходнику")
        self.fit_len.setToolTip("Длина клипа — до конца исходного видео с учётом скорости")
        cg.addWidget(self.fit_len, 2, 2)
        cg.setColumnStretch(1, 1)
        bl.addWidget(self.clip_box)

        # --- свойства ---
        bl.addWidget(_section("СВОЙСТВА · ◆ — анимировать по ключам"))
        grid = QGridLayout()
        grid.setHorizontalSpacing(6)
        grid.setVerticalSpacing(6)
        self.spins: dict[str, QDoubleSpinBox] = {}
        self.anim_btns: dict[str, QToolButton] = {}
        row = 0
        for gkey, gtitle, props in GROUPS:
            btn = QToolButton()
            btn.setCheckable(True)
            btn.setIcon(icons.icon("diamond-empty", theme.TEXT_MUTED, "#ffffff"))
            btn.setIconSize(QSize(14, 14))
            btn.setToolTip(f"Анимировать «{gtitle}»: включить ключевые кадры")
            btn.toggled.connect(lambda on, g=gkey: self._toggle_anim(g, on))
            self.anim_btns[gkey] = btn
            grid.addWidget(btn, row, 0)
            grid.addWidget(QLabel(gtitle), row, 1)
            if gkey == "corners":
                reset = QPushButton("Сбросить углы")
                reset.setToolTip("Деформация — инструментом «Трансформация»: тяните угол рамки с зажатым Ctrl")
                reset.clicked.connect(self._reset_corners)
                grid.addWidget(reset, row, 2, 1, 2)
            else:
                for i, prop in enumerate(props):
                    label, lo, hi, mul, suffix = FIELDS[prop]
                    sb = QDoubleSpinBox()
                    sb.setRange(lo, hi)
                    sb.setDecimals(0 if mul == 1 and prop in ("x", "y") else 1 if mul == 1 else 0)
                    sb.setSuffix(suffix)
                    if label:
                        sb.setPrefix(label + " ")
                    sb.setKeyboardTracking(False)
                    sb.setMinimumWidth(78)
                    sb.valueChanged.connect(lambda val, p=prop, m=mul: self._set_value(p, val / m))
                    self.spins[prop] = sb
                    grid.addWidget(sb, row, 2 + i, 1, 2 if len(props) == 1 else 1)
            row += 1
        grid.setColumnStretch(2, 1)
        grid.setColumnStretch(3, 1)
        bl.addLayout(grid)
        self.keep_ratio = QCheckBox("Масштаб пропорционально")
        self.keep_ratio.setChecked(True)
        bl.addWidget(self.keep_ratio)

        # --- ключ на текущем кадре ---
        keyrow = QHBoxLayout()
        self.prev_key = QToolButton()
        self.prev_key.setIcon(icons.icon("prev"))
        self.prev_key.setToolTip("К предыдущему ключу элемента")
        self.key_btn = QPushButton()
        self.next_key = QToolButton()
        self.next_key.setIcon(icons.icon("next"))
        self.next_key.setToolTip("К следующему ключу элемента")
        keyrow.addWidget(self.prev_key)
        keyrow.addWidget(self.key_btn, 1)
        keyrow.addWidget(self.next_key)
        bl.addLayout(keyrow)
        er = QHBoxLayout()
        er.addWidget(QLabel("Движение"))
        self.easing = QComboBox()
        for k in EASING_KEYS:
            self.easing.addItem(EASINGS[k][0], k)
        self.easing.setToolTip("Как элемент движется от этого ключа к следующему: скорость и характер")
        er.addWidget(self.easing, 1)
        bl.addLayout(er)
        self.reset_all = QPushButton("Сбросить всё")
        self.reset_all.setToolTip("Вернуть элемент на место: без сдвига, поворота, масштаба и ключей")
        bl.addWidget(self.reset_all)

        # --- библиотека ---
        bl.addWidget(_section("БИБЛИОТЕКА · двойной щелчок — применить"))
        self.library = QListWidget()
        self.library.setMinimumHeight(220)
        self.library.setStyleSheet(
            f"QListWidget {{ background:{theme.BG_DEEP}; border:1px solid {theme.BORDER}; border-radius:6px; "
            f"outline:none; padding:2px; }} QListWidget::item {{ padding:4px 6px; border-radius:4px; }}"
            f"QListWidget::item:hover {{ background:{theme.BG_HOVER}; }}"
            f"QListWidget::item:selected {{ background:{theme.ACCENT_DIM}; color:{theme.TEXT}; }}")
        for kind, title in PRESET_GROUPS:
            header = QListWidgetItem(title)
            header.setFlags(Qt.NoItemFlags)
            f = header.font()
            f.setPixelSize(10)
            f.setBold(True)
            header.setFont(f)
            header.setForeground(Qt.gray)
            self.library.addItem(header)
            for pr in PRESETS:
                if pr.kind == kind:
                    it = QListWidgetItem(("↗ " if kind == "in" else "↘ " if kind == "out" else "✦ ") + pr.title)
                    it.setData(Qt.UserRole, pr.key)
                    self.library.addItem(it)
        bl.addWidget(self.library, 1)
        self.apply_btn = QPushButton("Применить")
        bl.addWidget(self.apply_btn)
        lib_hint = QLabel("Появление ставится в начало клипа, исчезновение — в конец, анимация — на текущий кадр.")
        lib_hint.setWordWrap(True)
        lib_hint.setStyleSheet(f"color:{theme.TEXT_MUTED}; font-size:11px;")
        bl.addWidget(lib_hint)
        root.addWidget(self.body, 1)

        self.speed.valueChanged.connect(self._set_speed)
        self.length.valueChanged.connect(self._set_length)
        self.fit_len.clicked.connect(self._fit_length)
        self.key_btn.clicked.connect(self._toggle_key)
        self.prev_key.clicked.connect(lambda: self._jump(-1))
        self.next_key.clicked.connect(lambda: self._jump(1))
        self.easing.currentIndexChanged.connect(self._set_easing)
        self.reset_all.clicked.connect(self._reset)
        self.library.itemDoubleClicked.connect(lambda _it: self.apply_preset())
        self.apply_btn.clicked.connect(self.apply_preset)
        for sig in (project.selectionChanged, project.contentChanged, project.structureChanged):
            sig.connect(self.refresh)
        project.frameChanged.connect(lambda _: self.refresh())
        self.refresh()

    # ---------- данные ----------
    def _el(self):
        return self.project.selected_element()

    def _local(self):
        el = self._el()
        return None if el is None else self.project.current_frame - el[-1]

    def refresh(self):
        el = self._el()
        self.empty.setVisible(el is None)
        self.body.setVisible(el is not None)
        if el is None:
            self.icon.clear()
            self.title.setText("Элемент не выбран")
            self.subtitle.setText("")
            self.make_layer.setEnabled(self.project.draw_layer() is not None)
            return
        obj, tr, *_rest, start = el
        local = self.project.current_frame - start
        is_clip = isinstance(obj, VisualClip)
        self.icon.setPixmap(icons.pixmap("film" if is_clip else "layers", theme.ACCENT, 20))
        self.title.setText(obj.name)
        if is_clip:
            secs = obj.length / max(1, self.project.fps)
            self.subtitle.setText(f"{KIND_TITLE.get(obj.kind, 'Клип')} · {obj.src_w}×{obj.src_h} · {secs:.1f} с")
        else:
            self.subtitle.setText("Рисованный слой как элемент")
        self._updating = True
        try:
            self.clip_box.setVisible(is_clip)
            if is_clip:
                self.speed.setValue(round(obj.speed * 100))
                self.speed.setEnabled(obj.kind != "image")
                self.speed_hint.setText("" if obj.kind == "image" else "быстрее / медленнее")
                self.length.setValue(obj.length)
                self.fit_len.setEnabled(obj.kind == "video")
            v = tr.values(local)
            for prop, sb in self.spins.items():
                sb.setValue(v[prop] * FIELDS[prop][3])
            for gkey, _t, props in GROUPS:
                anim = any(tr.animated(p) for p in props)
                btn = self.anim_btns[gkey]
                btn.setChecked(anim)
                btn.setIcon(icons.icon("diamond" if anim else "diamond-empty",
                                       theme.ACCENT if anim else theme.TEXT_MUTED, "#ffffff"))
            has_key = local in tr.key_frames()
            animated_any = bool(tr.keys)
            self.key_btn.setEnabled(animated_any)
            self.key_btn.setText("◆ Удалить ключ на этом кадре" if has_key else "◇ Поставить ключ на этом кадре")
            self.prev_key.setEnabled(any(k < local for k in tr.key_frames()))
            self.next_key.setEnabled(any(k > local for k in tr.key_frames()))
            e = tr.easing_at(list(tr.keys), local)
            self.easing.setEnabled(e is not None)
            if e is not None:
                self.easing.setCurrentIndex(EASING_KEYS.index(e))
        finally:
            self._updating = False

    # ---------- правки ----------
    def _select_layer(self):
        layer = self.project.draw_layer()
        if layer is not None:
            self.project.select(("layer", layer.id))

    def _set_value(self, prop, value):
        if self._updating:
            return
        props = [prop]
        if prop in ("sx", "sy") and self.keep_ratio.isChecked():
            el = self._el()
            if el is not None:
                v = el[1].values(self._local())
                old = v[prop] or 1e-6
                other = "sy" if prop == "sx" else "sx"
                ratio = value / old
                props = [(prop, value), (other, v[other] * ratio)]
        pairs = props if isinstance(props[0], tuple) else [(prop, value)]

        def fn(tr, local):
            for p, val in pairs:
                tr.set(p, local, val)

        self.project.edit_element("Свойство элемента", fn)

    def _toggle_anim(self, gkey, on):
        if self._updating:
            return
        props = next(p for g, _t, p in GROUPS if g == gkey)
        self.project.edit_element("Анимация свойства" if on else "Без анимации",
                                  lambda tr, local: tr.set_animated(props, local, on))

    def _toggle_key(self):
        el = self._el()
        if el is None:
            return
        tr, local = el[1], self._local()
        animated = [p for p in DEFAULTS if tr.animated(p)]
        if local in tr.key_frames():
            self.project.edit_element("Удалить ключ", lambda t, f: t.remove_key(animated, f))
        else:
            def fn(t, f):
                vals = t.values(f)
                for p in animated:
                    t.set(p, f, vals[p])
            self.project.edit_element("Ключ элемента", fn)

    def _jump(self, d):
        el = self._el()
        if el is None:
            return
        tr, start = el[1], el[-1]
        local = self._local()
        keys = tr.key_frames()
        cand = [k for k in keys if (k > local if d > 0 else k < local)]
        if cand:
            self.project.set_frame(start + (cand[0] if d > 0 else cand[-1]))

    def _set_easing(self, _i):
        if self._updating:
            return
        name = self.easing.currentData()
        self.project.edit_element("Характер движения", lambda tr, f: tr.set_easing(list(tr.keys), f, name))

    def _reset_corners(self):
        def fn(tr, local):
            for p in CORNERS:
                tr.keys.pop(p, None)
                tr.static.pop(p, None)
        self.project.edit_element("Сбросить деформацию", fn)

    def _reset(self):
        def fn(tr, local):
            tr.keys.clear()
            tr.static.clear()
        self.project.edit_element("Сбросить элемент", fn)

    def _clip(self):
        el = self._el()
        return el[0] if el is not None and isinstance(el[0], VisualClip) else None

    def _set_speed(self, v):
        clip = self._clip()
        if self._updating or clip is None:
            return
        cid = clip.id

        def do():
            c = self.project.find_clip(cid)[1]
            c.speed = v / 100
        self.project.edit("Скорость клипа", do)

    def _set_length(self, v):
        clip = self._clip()
        if self._updating or clip is None or v == clip.length:
            return
        if not self.project.trim_clip(clip.id, clip.start, v):
            self.window().statusBar().showMessage("Клип упирается в соседний на дорожке", 3000)
            self.refresh()

    def _fit_length(self):
        clip = self._clip()
        if clip is None:
            return
        n = clip.max_length(self.project.fps)
        if n:
            self.length.setValue(n)

    def apply_preset(self):
        it = self.library.currentItem()
        el = self._el()
        if it is None or it.data(Qt.UserRole) is None or el is None:
            return
        preset = PRESETS_BY_KEY[it.data(Qt.UserRole)]
        obj, tr, w, h, *_c, start = el
        fps = self.project.fps
        n = max(2, round(preset.frames * fps / 24))
        local = self.project.current_frame - start
        if isinstance(obj, VisualClip):
            at = 0 if preset.kind == "in" else max(0, obj.length - 1 - n) if preset.kind == "out" else local
        else:
            at = local
        base = tr.values(at if preset.kind != "out" else max(0, at - 1))
        self.project.edit_element(f"Анимация «{preset.title}»",
                                  lambda t, f: apply_preset(t, preset, at, fps, w, h, base))
        self.project.set_frame(start + at)
