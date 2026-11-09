"""Обучение: пошаговый тур по программе поверх главного окна.

Остальной интерфейс затемняется, нужная часть подсвечивается, рядом — облачко с пояснением.
Запускается при первом запуске и из меню «Справка → Обучение».
"""

from __future__ import annotations

from dataclasses import dataclass

from PySide6.QtCore import QEvent, QPoint, QRect, QRectF, Qt, Signal
from PySide6.QtGui import QColor, QPainter, QPainterPath, QPen
from PySide6.QtWidgets import QFrame, QHBoxLayout, QLabel, QPushButton, QVBoxLayout, QWidget

from .. import brand, theme


@dataclass
class Step:
    title: str
    text: str
    target: object = None      # функция, возвращающая виджет для подсветки (или None — по центру)
    before: object = None      # что сделать перед шагом (например, открыть вкладку)


def default_steps(w) -> list[Step]:
    """Шаги тура для главного окна w."""
    def action_button(key):
        return lambda: w.topbar.widgetForAction(w.actions[key])

    def show_tab(index):
        return lambda: w.left_tabs.setCurrentIndex(index)

    return [
        Step("Добро пожаловать в MercuryToonz!",
             "Здесь можно рисовать мультфильмы кадр за кадром, оживлять картинки и видео по ключевым кадрам "
             "и монтировать ролики со звуком и мемами. За минуту покажем главное."),
        Step("Инструменты",
             "Кисть <b>B</b>, карандаш <b>P</b>, ластик <b>E</b>, <b>кривая C</b> — как в Paint Tool SAI: "
             "щёлкайте точки, линия плавно пройдёт через них. <b>Трансформация Q</b> — двигать, вращать "
             "и деформировать что угодно.", lambda: w.toolbox),
        Step("Кисти и удобство",
             "16 кистей: тушь, перо, маркер, карандаши, акварель, аэрограф… <b>Стабилизатор</b> убирает дрожание "
             "руки — рисовать комфортно даже мышкой. Планшеты с нажимом тоже поддерживаются.",
             lambda: w.left_tabs, show_tab(0)),
        Step("Холст",
             "Рисуйте прямо здесь. <b>Пробел</b> + перетаскивание — двигать холст, <b>Ctrl + колесо</b> — "
             "масштаб, <b>Shift</b> при рисовании — прямая линия.", lambda: w.canvas),
        Step("Цвет",
             "Выбирайте цвет в квадрате и на радуге, вводите HEX или берите из палитры. <b>X</b> — поменять "
             "основной и дополнительный цвет.", lambda: w.color_panel),
        Step("Слои",
             "Каждая часть рисунка — на своём слое: персонаж, фон, тень. Глаз — скрыть, замок — защитить, "
             "порядок меняется перетаскиванием.", lambda: w.layers_panel),
        Step("Таймлайн и дорожки",
             "«Анимация» — ваш рисунок: <b>F6</b> — новый кадр-копия, <b>F7</b> — пустой кадр, <b>O</b> — луковая "
             "кожа. Ниже — видеодорожки для клипов и мемов и звуковые дорожки. Клипы двигаются мышью, "
             "края тянутся для обрезки, <b>Ctrl+K</b> — разрезать.", lambda: w.timeline),
        Step("Мемы, видео, картинки",
             "Кнопка «Импорт» (<b>Ctrl+I</b>) или просто <b>перетащите файлы</b> в окно: видео (звук ляжет "
             "на отдельную дорожку), картинки, GIF, музыку.", action_button("import_media")),
        Step("Ключевые кадры элемента",
             "Выберите клип или слой — здесь его свойства. Нажмите <b>◆</b>, чтобы анимировать: меняйте положение, "
             "масштаб, поворот, наклон, прозрачность на разных кадрах — программа достроит движение. "
             "<b>Движение</b> задаёт скорость: плавно, разгон, пружина, отскок… Внизу — <b>библиотека</b> "
             "готовых появлений и анимаций.", lambda: w.left_tabs, show_tab(1)),
        Step("Просмотр и экспорт",
             "<b>Enter</b> — воспроизвести. Готовый ролик — <b>Ctrl+E</b>: MP4, MOV, AVI, GIF, PNG или MP3.",
             action_button("export")),
        Step("Вот и всё!",
             "Подсказки по клавишам — <b>F1</b>, а это обучение всегда можно открыть снова: "
             "<b>Справка → Обучение</b>. Приятного творчества!"),
    ]


class TutorialOverlay(QWidget):
    finished = Signal()

    def __init__(self, window, steps: list[Step] | None = None):
        super().__init__(window)
        self.window_ = window
        self.steps = steps or default_steps(window)
        self.index = 0
        self.setAttribute(Qt.WA_StyledBackground, False)
        self.setFocusPolicy(Qt.StrongFocus)

        self.bubble = QFrame(self)
        self.bubble.setObjectName("bubble")
        self.bubble.setStyleSheet(
            f"#bubble {{ background:{theme.BG_RAISED}; border:1px solid {theme.MERCURY_BLUE}; border-radius:12px; }}"
            f"#bubble QLabel {{ background:transparent; }}")
        self.bubble.setFixedWidth(360)
        bl = QVBoxLayout(self.bubble)
        bl.setContentsMargins(18, 16, 18, 14)
        bl.setSpacing(8)
        top = QHBoxLayout()
        logo = QLabel()
        logo.setPixmap(brand.logo_pixmap(26))
        top.addWidget(logo)
        self.title = QLabel()
        self.title.setWordWrap(True)
        self.title.setStyleSheet("font-size:16px; font-weight:700;")
        top.addWidget(self.title, 1)
        bl.addLayout(top)
        self.text = QLabel()
        self.text.setWordWrap(True)
        self.text.setTextFormat(Qt.RichText)
        self.text.setStyleSheet(f"color:{theme.TEXT}; line-height:140%;")
        bl.addWidget(self.text)
        row = QHBoxLayout()
        self.counter = QLabel()
        self.counter.setStyleSheet(f"color:{theme.TEXT_MUTED};")
        row.addWidget(self.counter)
        row.addStretch()
        self.skip = QPushButton("Пропустить")
        self.skip.setFlat(True)
        self.skip.setStyleSheet(f"color:{theme.TEXT_MUTED}; border:none; padding:4px 8px;")
        self.back = QPushButton("Назад")
        self.next = QPushButton("Далее")
        self.next.setStyleSheet(f"QPushButton {{ background:{theme.ACCENT}; color:#ffffff; "
                                f"border-color:{theme.ACCENT}; font-weight:600; padding:5px 16px; }}")
        for b in (self.skip, self.back, self.next):
            row.addWidget(b)
        bl.addLayout(row)

        self.skip.clicked.connect(self.close_tour)
        self.back.clicked.connect(lambda: self.go(self.index - 1))
        self.next.clicked.connect(lambda: self.go(self.index + 1))
        window.installEventFilter(self)

    # ---------- жизненный цикл ----------
    def start(self):
        self.setGeometry(self.window_.rect())
        self.show()
        self.raise_()
        self.setFocus()
        self.go(0)

    def close_tour(self):
        self.window_.removeEventFilter(self)
        self.hide()
        self.deleteLater()
        self.finished.emit()

    def eventFilter(self, obj, ev):
        if obj is self.window_ and ev.type() == QEvent.Resize:
            self.setGeometry(self.window_.rect())
            self._place()
        return False

    def go(self, i: int):
        if i >= len(self.steps):
            self.close_tour()
            return
        self.index = max(0, i)
        step = self.steps[self.index]
        if step.before:
            step.before()
        self.title.setText(step.title)
        self.text.setText(step.text)
        self.counter.setText(f"{self.index + 1} / {len(self.steps)}")
        self.back.setVisible(self.index > 0)
        last = self.index == len(self.steps) - 1
        self.next.setText("Начать работу" if last else "Далее")
        self.skip.setVisible(not last)
        self.bubble.adjustSize()
        self._place()
        self.update()

    def target_rect(self) -> QRect | None:
        step = self.steps[self.index]
        widget = step.target() if step.target else None
        if widget is None or not widget.isVisible():
            return None
        top_left = widget.mapTo(self.window_, QPoint(0, 0))
        return QRect(top_left, widget.size()).adjusted(-6, -6, 6, 6)

    def _place(self):
        r = self.target_rect()
        bw, bh = self.bubble.width(), self.bubble.sizeHint().height()
        W, H = self.width(), self.height()
        if r is None:
            x, y = (W - bw) // 2, (H - bh) // 2
        else:
            gap = 16
            candidates = [
                (r.right() + gap, r.top()),                  # справа
                (r.left() - gap - bw, r.top()),              # слева
                (r.left(), r.bottom() + gap),                # снизу
                (r.left(), r.top() - gap - bh),              # сверху
            ]
            x, y = candidates[0]
            for cx, cy in candidates:
                if 0 <= cx and cx + bw <= W and 0 <= cy and cy + bh <= H:
                    x, y = cx, cy
                    break
            else:  # подсвечена большая область — облачко внутри неё
                x, y = r.center().x() - bw // 2, r.center().y() - bh // 2
        x = max(12, min(x, W - bw - 12))
        y = max(12, min(y, H - bh - 12))
        self.bubble.move(x, y)

    # ---------- отрисовка и ввод ----------
    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        dim = QPainterPath()
        dim.addRect(QRectF(self.rect()))
        r = self.target_rect()
        if r is not None:
            hole = QPainterPath()
            hole.addRoundedRect(QRectF(r), 10, 10)
            dim = dim.subtracted(hole)
        p.fillPath(dim, QColor(5, 6, 9, 175))
        if r is not None:
            p.setPen(QPen(QColor(theme.MERCURY_BLUE_LIGHT), 2))
            p.setBrush(Qt.NoBrush)
            p.drawRoundedRect(QRectF(r), 10, 10)
        p.end()

    def mousePressEvent(self, e):
        e.accept()  # клики мимо облачка не проходят в программу

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close_tour()
        elif e.key() in (Qt.Key_Right, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space):
            self.go(self.index + 1)
        elif e.key() == Qt.Key_Left:
            self.go(self.index - 1)
        e.accept()
