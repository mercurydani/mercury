"""Окно справки: о программе, что нового, конфиденциальность, контакты, горячие клавиши."""

from __future__ import annotations

import platform

from PySide6 import __version__ as PYSIDE_VERSION
from PySide6.QtCore import QSize, qVersion
from PySide6.QtWidgets import (
    QDialog, QHBoxLayout, QLabel, QListWidget, QListWidgetItem, QPushButton, QStackedWidget,
    QTextBrowser, QVBoxLayout, QWidget,
)

from .. import (
    brand,
    APP_NAME, APP_RELEASE_DATE, APP_VERSION, DEVELOPER_EMAIL, DEVELOPER_NAME, ISSUES_URL, PROJECT_URL, STUDIO_URL,
    icons,
    theme,
)
from ..versions import CHANGELOG

CSS = f"""
<style>
h2 {{ font-size: 20px; margin: 0 0 6px 0; }}
h3 {{ font-size: 15px; margin: 18px 0 4px 0; }}
p, li {{ line-height: 145%; }}
.muted {{ color: {theme.TEXT_MUTED}; }}
.badge {{ color: #ffffff; background: {theme.ACCENT}; }}
a {{ color: {theme.ACCENT}; }}
td {{ padding: 2px 10px 2px 0; }}
</style>
"""


def about_html() -> str:
    return CSS + f"""
<h2>{APP_NAME}</h2>
<p class=muted>Версия {APP_VERSION} · выпуск от {APP_RELEASE_DATE}</p>
<p>Программа для 2D-анимации и монтажа: покадровое рисование, анимация по ключевым кадрам,
звуковые дорожки и запись голоса.</p>
<p>Сделано в <a href="{STUDIO_URL}">Mercury Studio</a> · Белград.</p>
<h3>Сведения о сборке</h3>
<table>
<tr><td class=muted>Версия программы</td><td>{APP_VERSION}</td></tr>
<tr><td class=muted>Формат проекта</td><td>.mtoonz, версия 3</td></tr>
<tr><td class=muted>Python</td><td>{platform.python_version()}</td></tr>
<tr><td class=muted>Qt / PySide6</td><td>{qVersion()} / {PYSIDE_VERSION}</td></tr>
<tr><td class=muted>Система</td><td>{platform.system()} {platform.release()} ({platform.machine()})</td></tr>
</table>
<h3>Сторонние компоненты</h3>
<p>Интерфейс построен на <a href="https://www.qt.io/qt-for-python">Qt for Python (PySide6)</a>,
лицензия LGPL v3. Работа со звуком использует Qt Multimedia, экспорт — FFmpeg из пакета imageio-ffmpeg
(LGPL/GPL, в зависимости от сборки).</p>
"""


def changelog_html() -> str:
    parts = [CSS, "<h2>Что нового</h2>"]
    for ver, date, title, items in CHANGELOG:
        current = " &nbsp;<span class=badge>&nbsp;текущая&nbsp;</span>" if ver == APP_VERSION else ""
        parts.append(f"<h3>{ver} — {title}{current}</h3><p class=muted>{date}</p><ul>")
        parts += [f"<li>{item}</li>" for item in items]
        parts.append("</ul>")
    return "".join(parts)


def privacy_html() -> str:
    return CSS + f"""
<h2>Политика конфиденциальности</h2>
<p class=muted>Действует с версии 0.3.0 · {APP_RELEASE_DATE}</p>

<h3>Коротко</h3>
<p>{APP_NAME} работает целиком на вашем компьютере. Программа не собирает, не отправляет
и не продаёт ваши данные. Учётная запись не нужна.</p>

<h3>Какие данные обрабатываются</h3>
<ul>
<li><b>Ваши проекты.</b> Рисунки, звук и настройки сцены хранятся в файлах <i>.mtoonz</i>
в папке, которую вы выбрали (по умолчанию «Документы/MercuryToonz»). Они никуда не передаются.</li>
<li><b>Настройки программы.</b> Папка проектов и список недавних файлов хранятся в настройках
вашей учётной записи операционной системы.</li>
<li><b>Микрофон.</b> Программа обращается к микрофону только во время записи в окне «Запись звука»
— после нажатия кнопки «Записать». Запись сохраняется во временный файл на вашем компьютере,
а после сохранения проекта — внутри файла проекта.</li>
<li><b>Экспорт.</b> Видео, GIF, картинки и звук создаются на вашем компьютере с помощью встроенного
FFmpeg и сохраняются туда, куда вы укажете.</li>
<li><b>Временные файлы.</b> Звук открытых проектов распаковывается во временную папку системы.</li>
</ul>

<h3>Чего программа не делает</h3>
<ul>
<li>не отправляет статистику использования, отчёты об ошибках и телеметрию;</li>
<li>не обращается к интернету (ссылки в справке открываются в вашем браузере только по щелчку);</li>
<li>не показывает рекламу и не использует трекеры.</li>
</ul>

<h3>Ваши права</h3>
<p>Все данные находятся у вас: чтобы удалить их, удалите файлы проектов и папку программы.
Если в будущих версиях появятся сетевые функции (например, обновления), они будут описаны здесь
и включаться только с вашего согласия.</p>

<h3>Вопросы</h3>
<p>Пишите разработчику — контакты в разделе «Связаться с разработчиком».</p>
"""


def contacts_html() -> str:
    rows = [f"<tr><td class=muted>Разработчик</td><td>{DEVELOPER_NAME}</td></tr>"]
    if DEVELOPER_EMAIL:
        rows.append(f"<tr><td class=muted>Почта</td><td><a href='mailto:{DEVELOPER_EMAIL}'>{DEVELOPER_EMAIL}</a></td></tr>")
    rows.append(f"<tr><td class=muted>Студия</td><td><a href='{STUDIO_URL}'>{STUDIO_URL.split('//')[1]}</a></td></tr>")
    rows.append(f"<tr><td class=muted>Код программы</td><td><a href='{PROJECT_URL}'>{PROJECT_URL}</a></td></tr>")
    rows.append(f"<tr><td class=muted>Ошибки и идеи</td><td><a href='{ISSUES_URL}'>{ISSUES_URL}</a></td></tr>")
    return CSS + f"""
<h2>Связаться с разработчиком</h2>
<p>Нашли ошибку, есть идея или вопрос? Напишите нам — мы читаем всё.</p>
<table>{''.join(rows)}</table>
<h3>Чтобы мы быстрее помогли</h3>
<ul>
<li>укажите версию программы: <b>{APP_VERSION}</b> и систему: <b>{platform.system()} {platform.release()}</b>;</li>
<li>опишите шаги, после которых появилась ошибка;</li>
<li>по возможности приложите снимок экрана или файл проекта.</li>
</ul>
"""


SECTIONS = [
    ("about", "О программе", "info", about_html),
    ("changelog", "Что нового", "history", changelog_html),
    ("shortcuts", "Горячие клавиши", "keyboard", None),
    ("privacy", "Конфиденциальность", "shield", privacy_html),
    ("contacts", "Связаться с разработчиком", "mail", contacts_html),
]


class HelpDialog(QDialog):
    def __init__(self, shortcuts_html: str, section: str = "about", parent=None):
        super().__init__(parent)
        self.setWindowTitle(f"Справка — {APP_NAME}")
        self.resize(860, 600)
        root = QHBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        side = QVBoxLayout()
        side.setContentsMargins(14, 18, 10, 14)
        head = QHBoxLayout()
        logo = QLabel()
        logo.setPixmap(brand.logo_pixmap(30))
        head.addWidget(logo)
        head.addWidget(QLabel(f"<b>Mercury</b><b style='color:{theme.ACCENT}'>Toonz</b>"
                               f"<br><span style='color:{theme.TEXT_MUTED}'>версия {APP_VERSION}</span>"))
        head.addStretch()
        side.addLayout(head)
        side.addSpacing(10)
        self.nav = QListWidget()
        self.nav.setFixedWidth(230)
        self.nav.setIconSize(QSize(18, 18))
        self.nav.setStyleSheet(
            "QListWidget { background: transparent; border: none; outline: none; }"
            "QListWidget::item { padding: 8px 6px; border-radius: 6px; }"
            f"QListWidget::item:hover {{ background: {theme.BG_HOVER}; }}"
            f"QListWidget::item:selected {{ background: {theme.ACCENT}; color: #ffffff; }}"
        )
        side.addWidget(self.nav, 1)
        close = QPushButton("Закрыть")
        close.clicked.connect(self.accept)
        side.addWidget(close)
        side_w = QWidget()  # контейнер с фоном панели
        side_w.setObjectName("panel")
        side_w.setStyleSheet(f"#panel {{ background:{theme.BG_PANEL}; border-right:1px solid {theme.BORDER}; }}")
        side_w.setLayout(side)
        root.addWidget(side_w)

        self.pages = QStackedWidget()
        self.keys = []
        for key, title, icon, fn in SECTIONS:
            item = QListWidgetItem(icons.icon(icon), title)
            self.nav.addItem(item)
            view = QTextBrowser()
            view.setOpenExternalLinks(True)
            view.setStyleSheet(f"QTextBrowser {{ background:{theme.BG_DEEP}; border:none; padding:18px 26px; }}")
            view.setHtml(fn() if fn else CSS + "<h2>Горячие клавиши</h2>" + shortcuts_html)
            self.pages.addWidget(view)
            self.keys.append(key)
        root.addWidget(self.pages, 1)
        self.nav.currentRowChanged.connect(self.pages.setCurrentIndex)
        self.nav.setCurrentRow(self.keys.index(section) if section in self.keys else 0)
