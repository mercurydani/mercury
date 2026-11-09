"""Медиафайлы для монтажа: видео, картинки, GIF.

Видео читается через FFmpeg: процесс-«читатель» выдаёт кадры подряд с нужной частотой и размером.
Если нужен кадр не по порядку (перемотка), читатель перезапускается с нужного места (-ss).
Последние кадры кэшируются, поэтому перемотка туда-сюда и повторное воспроизведение быстрые.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import threading
from collections import OrderedDict
from dataclasses import dataclass

from PySide6.QtCore import QSize, Qt
from PySide6.QtGui import QImage, QImageReader

from . import audio
from .export import find_ffmpeg

VIDEO_EXT = {".mp4", ".mov", ".avi", ".mkv", ".webm", ".m4v", ".wmv", ".flv", ".mpg", ".mpeg", ".3gp", ".ts"}
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".bmp", ".webp", ".tif", ".tiff"}
GIF_EXT = {".gif"}
AUDIO_EXT = {".wav", ".mp3", ".ogg", ".oga", ".m4a", ".aac", ".flac", ".opus", ".wma"}

_FLAGS = getattr(subprocess, "CREATE_NO_WINDOW", 0)


def kind_of(path: str) -> str | None:
    ext = os.path.splitext(path)[1].lower()
    if ext in VIDEO_EXT:
        return "video"
    if ext in GIF_EXT:
        return "gif"
    if ext in IMAGE_EXT:
        return "image"
    if ext in AUDIO_EXT:
        return "audio"
    return None


@dataclass
class MediaInfo:
    kind: str           # video / image / gif
    width: int
    height: int
    duration: float     # секунды (картинка — 0)
    fps: float = 0.0
    has_audio: bool = False


def probe_video(path: str) -> MediaInfo:
    ffmpeg = find_ffmpeg()
    if not ffmpeg:
        raise OSError("Не найден FFmpeg. Установите пакет: pip install imageio-ffmpeg")
    r = subprocess.run([ffmpeg, "-hide_banner", "-i", path], capture_output=True, text=True,
                       errors="replace", creationflags=_FLAGS)
    err = r.stderr
    m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", err)
    duration = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3)) if m else 0.0
    v = re.search(r"Stream #.*?Video: .*?(\d{2,5})x(\d{2,5})", err)
    if not v:
        raise OSError("В файле нет видео или формат не поддерживается")
    w, h = int(v.group(1)), int(v.group(2))
    # повёрнутое видео с телефона
    rot = re.search(r"rotate\s*:\s*(-?\d+)|rotation of (-?[\d.]+)", err)
    if rot and abs(int(float(rot.group(1) or rot.group(2)))) % 180 == 90:
        w, h = h, w
    f = re.search(r"([\d.]+) fps", err)
    return MediaInfo("video", w, h, duration, float(f.group(1)) if f else 25.0,
                     has_audio=bool(re.search(r"Stream #.*?Audio:", err)))


def probe(path: str) -> MediaInfo:
    kind = kind_of(path)
    if kind == "video":
        return probe_video(path)
    reader = QImageReader(path)
    size = reader.size()
    if not size.isValid():
        img = QImage(path)
        if img.isNull():
            raise OSError(f"Не удалось открыть картинку: {reader.errorString()}")
        size = img.size()
    if kind == "gif":
        frames = GifSource(path)
        return MediaInfo("gif", size.width(), size.height(), frames.duration)
    return MediaInfo("image", size.width(), size.height(), 0.0)


def extract_audio(path: str, dst: str):
    """Звуковая дорожка видео → WAV (стерео 48 кГц)."""
    ffmpeg = find_ffmpeg()
    r = subprocess.run([ffmpeg, "-y", "-hide_banner", "-loglevel", "error", "-i", path, "-vn", "-ac", "2",
                        "-ar", "48000", "-c:a", "pcm_s16le", dst], capture_output=True, text=True,
                       errors="replace", creationflags=_FLAGS)
    if r.returncode != 0 or not os.path.exists(dst):
        raise OSError(r.stderr.strip().splitlines()[-1] if r.stderr.strip() else "Не удалось извлечь звук")


def copy_to_media(path: str) -> tuple[str, str]:
    """Копирует файл в папку медиа проекта. Возвращает (id, новый путь)."""
    mid, dst = audio.new_media_path(os.path.splitext(path)[1].lower())
    shutil.copyfile(path, dst)
    return mid, dst


# ------------------------------------------------------------------ источники кадров
class ImageSource:
    def __init__(self, path: str):
        self.image = QImage(path).convertToFormat(QImage.Format_ARGB32_Premultiplied)

    def frame(self, t: float, max_w: int = 0) -> QImage | None:
        return None if self.image.isNull() else self.image


class GifSource:
    def __init__(self, path: str):
        reader = QImageReader(path)
        self.frames: list[tuple[float, QImage]] = []  # (время начала, кадр)
        t = 0.0
        while True:
            img = reader.read()
            if img.isNull():
                break
            delay = reader.nextImageDelay() / 1000 or 0.1
            self.frames.append((t, img.convertToFormat(QImage.Format_ARGB32_Premultiplied)))
            t += max(0.02, delay)
            if len(self.frames) > 2000:
                break
        self.duration = t

    def frame(self, t: float, max_w: int = 0) -> QImage | None:
        if not self.frames:
            return None
        if self.duration > 0:
            t %= self.duration  # GIF зациклен
        img = self.frames[0][1]
        for start, im in self.frames:
            if start > t:
                break
            img = im
        return img


class _Reader:
    """Процесс FFmpeg, выдающий кадры подряд с частотой fps и размером w×h."""

    def __init__(self, path: str, t: float, fps: float, w: int, h: int):
        self.fps, self.w, self.h = fps, w, h
        self.next_index = round(t * fps)
        self.proc = subprocess.Popen(
            [find_ffmpeg(), "-hide_banner", "-loglevel", "error", "-ss", f"{max(0.0, t):.4f}", "-i", path,
             "-an", "-vf", f"fps={fps},scale={w}:{h}:flags=bilinear", "-f", "rawvideo", "-pix_fmt", "rgba", "-"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL, creationflags=_FLAGS,
            bufsize=w * h * 4)

    def read(self) -> QImage | None:
        size = self.w * self.h * 4
        data = self.proc.stdout.read(size)
        if not data or len(data) < size:
            return None
        self.next_index += 1
        img = QImage(data, self.w, self.h, self.w * 4, QImage.Format_RGBA8888)
        return img.convertToFormat(QImage.Format_ARGB32_Premultiplied)  # копия — данные больше не нужны

    def close(self):
        try:
            self.proc.kill()
            self.proc.wait(timeout=2)
        except Exception:  # процесс уже завершился
            pass
        if self.proc.stdout is not None:
            self.proc.stdout.close()


class VideoSource:
    def __init__(self, path: str, info: MediaInfo, fps: float):
        self.path, self.info = path, info
        self.fps = max(1.0, fps)
        self.readers: dict[int, _Reader] = {}           # ширина -> читатель
        self.cache: OrderedDict = OrderedDict()         # (ширина, индекс кадра) -> QImage
        self.lock = threading.Lock()

    def _size(self, max_w: int) -> tuple[int, int]:
        w, h = self.info.width, self.info.height
        if max_w and w > max_w:
            h = round(h * max_w / w)
            w = max_w
        return max(2, w - w % 2), max(2, h - h % 2)

    def frame(self, t: float, max_w: int = 0) -> QImage | None:
        t = max(0.0, min(t, max(0.0, self.info.duration - 0.5 / self.fps)))
        w, h = self._size(max_w)
        idx = round(t * self.fps)
        key = (w, idx)
        with self.lock:
            img = self.cache.get(key)
            if img is not None:
                self.cache.move_to_end(key)
                return img
            r = self.readers.get(w)
            if r is None or not (r.next_index <= idx <= r.next_index + int(self.fps)):
                if r is not None:
                    r.close()
                r = _Reader(self.path, idx / self.fps, self.fps, w, h)
                self.readers[w] = r
            img = None
            while r.next_index <= idx:
                i = r.next_index
                frame = r.read()
                if frame is None:
                    break
                img = frame
                self.cache[(w, i)] = frame
            limit = max(24, int(48 * 1920 * 1080 / max(1, w * h)))
            while len(self.cache) > limit:
                self.cache.popitem(last=False)
            if img is None:  # конец файла — последний известный кадр
                older = [k for k in self.cache if k[0] == w]
                return self.cache[older[-1]] if older else None
            return img

    def close(self):
        for r in self.readers.values():
            r.close()
        self.readers.clear()
        self.cache.clear()


class MediaPool:
    """Открытые источники кадров проекта (по id медиафайла)."""

    def __init__(self):
        self.sources: dict[str, object] = {}

    def get(self, project, media_id: str, kind: str):
        src = self.sources.get(media_id)
        if src is None:
            path = project.media.get(media_id)
            if not path or not os.path.exists(path):
                return None
            try:
                if kind == "video":
                    info = project.media_info.get(media_id) or probe_video(path)
                    src = VideoSource(path, info, project.fps)
                elif kind == "gif":
                    src = GifSource(path)
                else:
                    src = ImageSource(path)
            except OSError:
                return None
            self.sources[media_id] = src
        elif isinstance(src, VideoSource) and abs(src.fps - project.fps) > 1e-6:
            src.close()
            src.fps = project.fps
        return src

    def close(self):
        for s in self.sources.values():
            if isinstance(s, VideoSource):
                s.close()
        self.sources.clear()


def thumbnail(image: QImage | None, size: QSize) -> QImage | None:
    if image is None or image.isNull():
        return None
    return image.scaled(size, Qt.KeepAspectRatio, Qt.SmoothTransformation)
