"""Звук: запись с микрофона, разбор WAV (волна), воспроизведение вместе с анимацией."""

from __future__ import annotations

import array
import math
import os
import sys
import tempfile
import time
import uuid
import wave

from PySide6.QtCore import QEventLoop, QTimer, QUrl, Qt, Signal
from PySide6.QtGui import QColor, QPainter
from PySide6.QtWidgets import (
    QCheckBox, QComboBox, QDialog, QHBoxLayout, QLabel, QPushButton, QVBoxLayout, QWidget,
)

from . import icons, theme

PEAKS_PER_SECOND = 100


def media_dir() -> str:
    d = os.path.join(tempfile.gettempdir(), "mercurytoonz-media")
    os.makedirs(d, exist_ok=True)
    return d


def new_media_path(ext: str = ".wav") -> tuple[str, str]:
    mid = uuid.uuid4().hex[:12]
    return mid, os.path.join(media_dir(), mid + ext)


# ------------------------------------------------------------------ WAV
def write_wav(path: str, pcm: bytes, rate: int, channels: int, sample_width: int = 2):
    with wave.open(path, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(sample_width)
        w.setframerate(rate)
        w.writeframes(pcm)


def analyze_wav(path: str) -> tuple[float, list[float]]:
    """Длительность в секундах и пики громкости (0..1), PEAKS_PER_SECOND значений в секунду."""
    with wave.open(path, "rb") as w:
        rate, ch, sw, n = w.getframerate(), w.getnchannels(), w.getsampwidth(), w.getnframes()
        raw = w.readframes(n)
    duration = n / rate if rate else 0.0
    if sw == 2:
        samples = array.array("h")
        samples.frombytes(raw[: len(raw) // 2 * 2])
        if sys.byteorder == "big":
            samples.byteswap()
        scale = 32768.0
    elif sw == 1:
        samples = array.array("h", (b - 128 for b in raw))
        scale = 128.0
    elif sw == 4:
        samples = array.array("i")
        samples.frombytes(raw[: len(raw) // 4 * 4])
        if sys.byteorder == "big":
            samples.byteswap()
        scale = 2147483648.0
    else:
        return duration, []
    per = max(1, int(rate / PEAKS_PER_SECOND)) * ch
    peaks = []
    for i in range(0, len(samples), per):
        chunk = samples[i:i + per]
        if chunk:
            peaks.append(min(1.0, max(abs(max(chunk)), abs(min(chunk))) / scale))
    return duration, peaks


def decode_to_wav(src: str, dst: str, timeout_s: float = 120) -> None:
    """Любой звуковой файл (MP3, OGG, M4A…) → WAV через QAudioDecoder."""
    from PySide6.QtMultimedia import QAudioDecoder, QAudioFormat
    dec = QAudioDecoder()
    fmt = QAudioFormat()
    fmt.setSampleRate(48000)
    fmt.setChannelCount(2)
    fmt.setSampleFormat(QAudioFormat.Int16)
    dec.setAudioFormat(fmt)
    dec.setSource(QUrl.fromLocalFile(src))
    chunks: list[bytes] = []
    out_fmt = {"rate": 48000, "ch": 2}
    errors: list[str] = []
    loop = QEventLoop()

    def on_ready():
        buf = dec.read()
        f = buf.format()
        out_fmt["rate"], out_fmt["ch"] = f.sampleRate(), f.channelCount()
        chunks.append(bytes(buf.constData()))

    dec.bufferReady.connect(on_ready)
    dec.finished.connect(loop.quit)
    dec.error.connect(lambda _e: (errors.append(dec.errorString()), loop.quit()))
    QTimer.singleShot(int(timeout_s * 1000), loop.quit)
    dec.start()
    loop.exec()
    dec.stop()
    if errors or not chunks:
        raise OSError(errors[0] if errors else "Не удалось прочитать звук")
    write_wav(dst, b"".join(chunks), out_fmt["rate"], out_fmt["ch"])


# ------------------------------------------------------------------ воспроизведение
class AudioPlayback:
    """Проигрывает звуковые слои синхронно с анимацией."""

    def __init__(self, project):
        self.project = project
        self.players: dict[str, tuple] = {}  # id слоя -> (QMediaPlayer, QAudioOutput)
        self._last_frame = -1

    def _player(self, clip):
        from PySide6.QtMultimedia import QAudioOutput, QMediaPlayer
        item = self.players.get(clip.id)
        path = self.project.media.get(clip.media_id)
        if item is None and path:
            player, out = QMediaPlayer(), QAudioOutput()
            player.setAudioOutput(out)
            player.setSource(QUrl.fromLocalFile(path))
            item = (player, out)
            self.players[clip.id] = item
        return item

    def start(self, frame: int):
        self._last_frame = frame - 1
        self.sync(frame, force=True)

    def sync(self, frame: int, force: bool = False):
        """Вызывается на каждом кадре воспроизведения."""
        jumped = force or frame != self._last_frame + 1
        self._last_frame = frame
        fps = max(1, self.project.fps)
        audible = {c.id for _t, c in self.project.audio_clips()}
        for track in self.project.tracks:
            if track.kind != "audio":
                continue
            for clip in track.clips:
                item = self._player(clip)
                if item is None:
                    continue
                player, out = item
                local = (frame - clip.start) / fps                 # секунды от начала клипа
                out.setVolume(clip.gain_at(local) if clip.id in audible else 0.0)
                inside = clip.start <= frame < clip.end_frame(fps)
                playing = player.playbackState() == player.PlaybackState.PlayingState
                if abs(player.playbackRate() - clip.speed) > 1e-3:
                    player.setPlaybackRate(clip.speed)
                if inside and (jumped or not playing):
                    player.setPosition(int((clip.offset + local * clip.speed) * 1000))
                    player.play()
                elif not inside and playing:
                    player.pause()

    def stop(self):
        for player, _out in self.players.values():
            player.stop()
        self._last_frame = -1

    def reset(self):
        self.stop()
        self.players.clear()


# ------------------------------------------------------------------ запись
class LevelMeter(QWidget):
    def __init__(self):
        super().__init__()
        self.level = 0.0
        self.peak = 0.0
        self.setFixedHeight(14)

    def set_level(self, v: float):
        self.level = v
        self.peak = max(v, self.peak * 0.97)
        self.update()

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        p.setPen(Qt.NoPen)
        p.setBrush(QColor(theme.BG_RAISED))
        p.drawRoundedRect(self.rect(), 4, 4)
        w = self.width() * min(1.0, self.level)
        color = "#3fbf7f" if self.level < 0.7 else ("#ffd84a" if self.level < 0.95 else "#e8404a")
        p.setBrush(QColor(color))
        p.drawRoundedRect(0, 0, int(w), self.height(), 4, 4)
        p.setBrush(QColor(theme.TEXT))
        p.drawRect(int(self.width() * min(1.0, self.peak)) - 1, 0, 2, self.height())


class RecordDialog(QDialog):
    """Запись голоса с микрофона. По желанию анимация проигрывается во время записи (озвучка)."""

    recordingStarted = Signal()
    recordingStopped = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        from PySide6.QtMultimedia import QMediaDevices
        self.setWindowTitle("Запись звука")
        self.setMinimumWidth(440)
        self.result_path: str | None = None
        self.result_id: str | None = None
        self._source = None
        self._io = None
        self._pcm = bytearray()
        self._fmt = None
        self._t0 = 0.0

        lay = QVBoxLayout(self)
        lay.setContentsMargins(22, 20, 22, 18)
        lay.setSpacing(12)
        title = QLabel("Запись с микрофона")
        title.setStyleSheet("font-size:18px; font-weight:600;")
        lay.addWidget(title)

        row = QHBoxLayout()
        row.addWidget(QLabel("Микрофон"))
        self.device = QComboBox()
        self.devices = QMediaDevices.audioInputs()
        default = QMediaDevices.defaultAudioInput()
        for d in self.devices:
            self.device.addItem(d.description())
            if d.id() == default.id():
                self.device.setCurrentIndex(self.device.count() - 1)
        row.addWidget(self.device, 1)
        lay.addLayout(row)

        self.meter = LevelMeter()
        lay.addWidget(self.meter)
        self.time = QLabel("00:00.0")
        self.time.setAlignment(Qt.AlignCenter)
        self.time.setStyleSheet("font-family: monospace; font-size: 28px;")
        lay.addWidget(self.time)

        self.play_anim = QCheckBox("Проигрывать анимацию во время записи (для озвучки)")
        self.play_anim.setChecked(True)
        lay.addWidget(self.play_anim)
        self.note = QLabel("Звук добавится отдельной дорожкой с текущего кадра.")
        self.note.setStyleSheet(f"color:{theme.TEXT_MUTED};")
        self.note.setWordWrap(True)
        lay.addWidget(self.note)

        buttons = QHBoxLayout()
        self.rec = QPushButton("  Записать")
        self.rec.setIcon(icons.icon("record", "#ffffff"))
        self.rec.setMinimumHeight(36)
        self.rec.setStyleSheet("QPushButton { background:#d93a43; border-color:#d93a43; color:white; "
                               "font-weight:600; } QPushButton:hover { background:#e8505a; }"
                               f"QPushButton:disabled {{ background:{theme.BG_RAISED}; border-color:{theme.BORDER}; "
                               f"color:{theme.TEXT_MUTED}; }}")
        self.add = QPushButton("Добавить на таймлайн")
        self.add.setEnabled(False)
        self.add.setMinimumHeight(36)
        cancel = QPushButton("Отмена")
        cancel.setMinimumHeight(36)
        buttons.addWidget(self.rec)
        buttons.addStretch()
        buttons.addWidget(cancel)
        buttons.addWidget(self.add)
        lay.addLayout(buttons)

        if not self.devices:
            self.rec.setEnabled(False)
            self.device.addItem("Микрофон не найден")
            self.device.setEnabled(False)
            self.note.setText("Микрофон не найден. Подключите его и откройте это окно заново.")

        self.timer = QTimer(self)
        self.timer.setInterval(50)
        self.timer.timeout.connect(self._tick)
        self.rec.clicked.connect(self.toggle)
        self.add.clicked.connect(self.accept)
        cancel.clicked.connect(self.reject)

    def toggle(self):
        if self._source is None:
            self.start()
        else:
            self.stop()

    def start(self):
        from PySide6.QtMultimedia import QAudioFormat, QAudioSource
        device = self.devices[self.device.currentIndex()]
        fmt = QAudioFormat()
        fmt.setSampleRate(48000)
        fmt.setChannelCount(1)
        fmt.setSampleFormat(QAudioFormat.Int16)
        if not device.isFormatSupported(fmt):
            fmt = device.preferredFormat()
            fmt.setSampleFormat(QAudioFormat.Int16)
        self._fmt = fmt
        self._pcm = bytearray()
        self._source = QAudioSource(device, fmt, self)
        self._io = self._source.start()
        if self._io is None:
            self._source = None
            self.note.setText("Не удалось включить микрофон.")
            return
        self._io.readyRead.connect(self._read)
        self._t0 = time.monotonic()
        self.timer.start()
        self.rec.setText("  Стоп")
        self.rec.setIcon(icons.icon("stop", "#ffffff"))
        self.add.setEnabled(False)
        self.device.setEnabled(False)
        if self.play_anim.isChecked():
            self.recordingStarted.emit()

    def _read(self):
        data = bytes(self._io.readAll())
        if not data:
            return
        self._pcm += data
        samples = array.array("h")
        samples.frombytes(data[: len(data) // 2 * 2])
        if samples:
            peak = max(abs(max(samples)), abs(min(samples))) / 32768.0
            self.meter.set_level(math.sqrt(peak))

    def _tick(self):
        t = time.monotonic() - self._t0
        self.time.setText(f"{int(t // 60):02d}:{t % 60:04.1f}")
        if self._io is not None:
            self._read()

    def stop(self):
        if self._source is None:
            return
        self._read()
        self._source.stop()
        self._source = None
        self._io = None
        self.timer.stop()
        self.recordingStopped.emit()
        self.rec.setText("  Записать заново")
        self.rec.setIcon(icons.icon("record", "#ffffff"))
        self.device.setEnabled(True)
        self.meter.set_level(0)
        if self._pcm:
            mid, path = new_media_path()
            write_wav(path, bytes(self._pcm), self._fmt.sampleRate(), self._fmt.channelCount())
            self.result_id, self.result_path = mid, path
            self.add.setEnabled(True)
            secs = len(self._pcm) / (self._fmt.sampleRate() * self._fmt.channelCount() * 2)
            self.note.setText(f"Записано {secs:.1f} с. Нажмите «Добавить на таймлайн».")

    def reject(self):
        self.stop()
        super().reject()

    def closeEvent(self, e):
        self.stop()
        super().closeEvent(e)
