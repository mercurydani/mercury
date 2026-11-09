"""Окно экспорта: выбор формата, диапазона, размера, качества, звука и прозрачности."""

from __future__ import annotations

import os
import time

from PySide6.QtCore import QRectF, QStandardPaths, Qt, QUrl
from PySide6.QtGui import QColor, QDesktopServices, QFont, QPainter, QPen
from PySide6.QtWidgets import (
    QApplication, QButtonGroup, QCheckBox, QComboBox, QDialog, QFileDialog, QFormLayout, QHBoxLayout, QLabel,
    QLineEdit, QMessageBox, QProgressDialog, QPushButton, QRadioButton, QSpinBox, QVBoxLayout,
)

from .. import APP_NAME, export, fileformat, theme
from ..export import FORMATS, FORMATS_BY_KEY, ExportCancelled, ExportError, ExportSettings
from ..model import Project
from .project_browser import settings

SCALES = [(1.0, "100%"), (0.75, "75%"), (0.5, "50%"), (0.25, "25%")]


class FormatCard(QPushButton):
    def __init__(self, fmt):
        super().__init__()
        self.fmt = fmt
        self.setCheckable(True)
        self.setFixedSize(92, 64)
        self.setCursor(Qt.PointingHandCursor)
        self.setToolTip(fmt.description)

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        r = QRectF(self.rect()).adjusted(1, 1, -1, -1)
        on, hover = self.isChecked(), self.underMouse()
        p.setPen(QPen(QColor(theme.ACCENT if on else (theme.TEXT_MUTED if hover else theme.BORDER)), 2 if on else 1))
        p.setBrush(QColor(theme.BG_RAISED if (on or hover) else theme.BG_PANEL))
        p.drawRoundedRect(r, 8, 8)
        f = QFont(self.font())
        f.setPixelSize(17)
        f.setBold(True)
        p.setFont(f)
        p.setPen(QColor(theme.ACCENT if on else theme.TEXT))
        p.drawText(QRectF(r.left(), r.top() + 8, r.width(), 24), Qt.AlignCenter, self.fmt.title)
        f.setPixelSize(10)
        f.setBold(False)
        p.setFont(f)
        p.setPen(QColor(theme.TEXT_MUTED))
        kind = "звук" if not self.fmt.video else ("картинки" if self.fmt.key == "png" else
                                                   ("анимация" if self.fmt.key == "gif" else "видео"))
        p.drawText(QRectF(r.left(), r.top() + 34, r.width(), 18), Qt.AlignCenter, kind)


class ExportDialog(QDialog):
    def __init__(self, project: Project, fmt: str = "mp4", parent=None):
        super().__init__(parent)
        self.project = project
        self.setWindowTitle("Экспорт")
        self.setMinimumWidth(640)
        self.result_path: str | None = None

        lay = QVBoxLayout(self)
        lay.setContentsMargins(24, 20, 24, 18)
        lay.setSpacing(14)
        title = QLabel("Экспорт")
        title.setStyleSheet("font-size:20px; font-weight:600;")
        lay.addWidget(title)

        cards = QHBoxLayout()
        cards.setSpacing(8)
        self.cards: dict[str, FormatCard] = {}
        group = QButtonGroup(self)
        for f in FORMATS:
            c = FormatCard(f)
            group.addButton(c)
            c.clicked.connect(lambda _=False, k=f.key: self.set_format(k))
            self.cards[f.key] = c
            cards.addWidget(c)
        cards.addStretch()
        lay.addLayout(cards)
        self.desc = QLabel()
        self.desc.setStyleSheet(f"color:{theme.TEXT_MUTED};")
        lay.addWidget(self.desc)

        form = QFormLayout()
        form.setSpacing(10)
        form.setLabelAlignment(Qt.AlignRight)

        path_row = QHBoxLayout()
        self.path = QLineEdit()
        browse = QPushButton("Обзор…")
        browse.clicked.connect(self._browse)
        path_row.addWidget(self.path, 1)
        path_row.addWidget(browse)
        self.path_label = QLabel("Файл")
        form.addRow(self.path_label, path_row)

        range_row = QHBoxLayout()
        self.all_frames = QRadioButton("Вся сцена")
        self.some_frames = QRadioButton("Кадры")
        self.all_frames.setChecked(True)
        self.first = QSpinBox()
        self.last = QSpinBox()
        for sb in (self.first, self.last):
            sb.setRange(1, project.frame_count)
            sb.setFixedWidth(70)
        self.first.setValue(1)
        self.last.setValue(project.frame_count)
        range_row.addWidget(self.all_frames)
        range_row.addSpacing(12)
        range_row.addWidget(self.some_frames)
        range_row.addWidget(self.first)
        range_row.addWidget(QLabel("—"))
        range_row.addWidget(self.last)
        range_row.addStretch()
        self.range_label = QLabel("Диапазон")
        form.addRow(self.range_label, range_row)

        size_row = QHBoxLayout()
        self.scale = QComboBox()
        for v, label in SCALES:
            self.scale.addItem(label, v)
        self.size_info = QLabel()
        self.size_info.setStyleSheet(f"color:{theme.TEXT_MUTED};")
        size_row.addWidget(self.scale)
        size_row.addWidget(self.size_info)
        size_row.addStretch()
        self.size_label = QLabel("Размер")
        form.addRow(self.size_label, size_row)

        self.fps = QSpinBox()
        self.fps.setRange(1, 60)
        self.fps.setValue(project.fps)
        self.fps.setSuffix(" кадров/с")
        self.fps.setFixedWidth(130)
        self.fps_label = QLabel("Частота")
        form.addRow(self.fps_label, self.fps)

        self.quality = QComboBox()
        self.quality.addItems(["Высокое", "Среднее", "Низкое (меньше файл)"])
        self.quality_label = QLabel("Качество")
        form.addRow(self.quality_label, self.quality)

        opts = QVBoxLayout()
        opts.setSpacing(6)
        self.with_audio = QCheckBox("Со звуком (все включённые звуковые дорожки)")
        self.with_audio.setChecked(True)
        self.transparent = QCheckBox("Прозрачный фон")
        self.loop = QCheckBox("Повторять бесконечно")
        self.loop.setChecked(True)
        self.open_after = QCheckBox("Открыть папку после экспорта")
        self.open_after.setChecked(True)
        for w in (self.with_audio, self.transparent, self.loop, self.open_after):
            opts.addWidget(w)
        form.addRow("Параметры", opts)
        lay.addLayout(form)

        self.summary = QLabel()
        self.summary.setStyleSheet(f"background:{theme.BG_PANEL}; border:1px solid {theme.BORDER}; "
                                   f"border-radius:6px; padding:8px 10px;")
        self.summary.setWordWrap(True)
        lay.addWidget(self.summary)

        buttons = QHBoxLayout()
        buttons.addStretch()
        cancel = QPushButton("Отмена")
        cancel.clicked.connect(self.reject)
        self.go = QPushButton("Экспортировать")
        self.go.setDefault(True)
        self.go.setMinimumWidth(150)
        self.go.setStyleSheet(f"QPushButton {{ background:{theme.ACCENT}; color:#ffffff; border-color:{theme.ACCENT}; "
                              "font-weight:600; }")
        self.go.clicked.connect(self.run)
        buttons.addWidget(cancel)
        buttons.addWidget(self.go)
        lay.addLayout(buttons)

        for w in (self.first, self.last, self.fps):
            w.valueChanged.connect(self._update)
        for w in (self.scale, self.quality):
            w.currentIndexChanged.connect(self._update)
        for w in (self.all_frames, self.some_frames, self.with_audio, self.transparent, self.loop):
            w.toggled.connect(self._update)
        self.first.valueChanged.connect(lambda: self.some_frames.setChecked(True))
        self.last.valueChanged.connect(lambda: self.some_frames.setChecked(True))
        self.fmt = None
        self.set_format(fmt if fmt in FORMATS_BY_KEY else "mp4")

    # ---------- путь ----------
    def _default_dir(self) -> str:
        saved = settings().value("export/folder", "")
        if saved and os.path.isdir(saved):
            return saved
        if self.project.file_path:
            return os.path.dirname(self.project.file_path)
        return QStandardPaths.writableLocation(QStandardPaths.MoviesLocation) or os.path.expanduser("~")

    def _default_path(self, fmt) -> str:
        base = fileformat.safe_file_name(self.project.name)
        cur = self.path.text().strip()
        folder = os.path.dirname(os.path.normpath(cur)) if cur else self._default_dir()
        return os.path.join(folder, base + (" (кадры)" if fmt.key == "png" else fmt.ext))

    def _browse(self):
        fmt = self.fmt
        if fmt.key == "png":
            folder = QFileDialog.getExistingDirectory(self, "Папка для кадров", os.path.dirname(self.path.text()))
            if folder:
                self.path.setText(os.path.join(folder, fileformat.safe_file_name(self.project.name) + " (кадры)"))
        else:
            path, _ = QFileDialog.getSaveFileName(self, "Экспорт", self.path.text(), f"{fmt.title} (*{fmt.ext})")
            if path:
                if not path.lower().endswith(fmt.ext):
                    path += fmt.ext
                self.path.setText(path)

    # ---------- состояние ----------
    def set_format(self, key: str):
        fmt = FORMATS_BY_KEY[key]
        self.path.setText(self._default_path(fmt))
        self.fmt = fmt
        self.cards[key].setChecked(True)
        self.desc.setText(fmt.description)
        self.path_label.setText("Папка" if key == "png" else "Файл")
        for w in (self.size_label, self.scale, self.size_info, self.fps_label, self.fps):
            w.setVisible(fmt.video)
        self.quality_label.setVisible(fmt.quality)
        self.quality.setVisible(fmt.quality)
        self.with_audio.setVisible(fmt.video and fmt.audio)
        self.transparent.setVisible(fmt.alpha)
        self.transparent.setText("Прозрачный фон (ProRes 4444)" if key == "mov" else "Прозрачный фон")
        self.loop.setVisible(key == "gif")
        if key == "gif" and self.fps.value() > 30:
            self.fps.setValue(30)
        self._update()

    def settings(self) -> ExportSettings:
        fmt = self.fmt
        transparent = fmt.alpha and self.transparent.isChecked()
        w, h = export.output_size(self.project, self.scale.currentData(), export.needs_even(fmt.key, transparent))
        if self.all_frames.isChecked():
            first, last = 0, self.project.frame_count - 1
        else:
            first, last = sorted((self.first.value() - 1, self.last.value() - 1))
        return ExportSettings(
            fmt=fmt.key, path=self.path.text().strip(), first=first, last=last, width=w, height=h,
            fps=self.fps.value() if fmt.video else self.project.fps, quality=self.quality.currentIndex(),
            transparent=transparent, with_audio=self.with_audio.isChecked(), loop=self.loop.isChecked())

    def _update(self):
        if self.fmt is None:
            return
        s = self.settings()
        self.size_info.setText(f"{s.width} × {s.height} px")
        n_audio = len(export.audio_inputs(self.project, s))
        parts = [f"<b>{self.fmt.title}</b>"]
        if self.fmt.video:
            parts.append(f"{s.width}×{s.height}")
            parts.append(f"{s.frames} кадр." if self.fmt.key != "png" else f"{s.frames} файлов PNG")
        secs = s.frames / (s.fps if self.fmt.video else self.project.fps)
        parts.append(f"{secs:.1f} с")
        if self.fmt.audio and (self.fmt.key == "mp3" or s.with_audio):
            parts.append(f"звуковых клипов: {n_audio}" if n_audio else "без звука")
        if s.transparent:
            parts.append("прозрачный фон")
        self.summary.setText("  ·  ".join(parts))
        self.go.setEnabled(bool(s.path) and (self.fmt.key != "mp3" or n_audio > 0))
        if self.fmt.key == "mp3" and not n_audio:
            self.summary.setText(self.summary.text() + "<br><span style='color:#e8a040'>В выбранных кадрах нет "
                                 "звука — сначала запишите или импортируйте звук.</span>")

    # ---------- запуск ----------
    def run(self):
        s = self.settings()
        if not s.path:
            return
        if self.fmt.key != "png" and os.path.exists(s.path):
            r = QMessageBox.question(self, APP_NAME, f"Файл «{os.path.basename(s.path)}» уже есть. Заменить?")
            if r != QMessageBox.Yes:
                return
        total = s.frames if self.fmt.video else 1
        progress = QProgressDialog("Подготовка…", "Отмена", 0, total, self)
        progress.setWindowTitle("Экспорт")
        progress.setWindowModality(Qt.WindowModal)
        progress.setMinimumDuration(0)
        progress.setMinimumWidth(380)
        t0 = time.monotonic()

        def on_progress(done, all_):
            progress.setMaximum(all_)
            progress.setValue(min(done, all_))
            if self.fmt.video and done < all_:
                left = ""
                if done > 2:
                    el = time.monotonic() - t0
                    left = f" · осталось ~{max(0, el / done * (all_ - done)):.0f} с"
                progress.setLabelText(f"Кадр {done + 1} из {all_}{left}")
            else:
                progress.setLabelText("Сжатие и запись файла…")
            QApplication.processEvents()
            return not progress.wasCanceled()

        self.go.setEnabled(False)
        try:
            path = export.export(self.project, s, on_progress)
        except ExportCancelled:
            progress.close()
            self.go.setEnabled(True)
            return
        except (ExportError, OSError) as e:
            progress.close()
            self.go.setEnabled(True)
            QMessageBox.warning(self, APP_NAME, f"Экспорт не удался.\n\n{e}")
            return
        progress.close()
        settings().setValue("export/folder", os.path.dirname(os.path.normpath(path)))
        self.result_path = path
        if self.open_after.isChecked():
            target = path if os.path.isdir(path) else os.path.dirname(path)
            QDesktopServices.openUrl(QUrl.fromLocalFile(target))
        self.accept()
