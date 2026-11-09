"""Экспорт: MP4, MOV, AVI, GIF, последовательность PNG, MP3.

Кадры рисуются через render.render_frame и передаются в FFmpeg по трубе (raw RGBA).
Звук всех включённых звуковых дорожек сводится фильтрами FFmpeg (atrim/adelay/amix).
FFmpeg берётся из пакета imageio-ffmpeg (ставится вместе с программой) или из системы.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from dataclasses import dataclass

from PySide6.QtGui import QImage

from .model import Project
from .render import render_frame


@dataclass(frozen=True)
class Format:
    key: str
    title: str
    ext: str
    description: str
    video: bool = True        # есть изображение
    audio: bool = True        # может содержать звук
    alpha: bool = False       # умеет прозрачный фон
    quality: bool = True      # есть выбор качества


FORMATS = [
    Format("mp4", "MP4", ".mp4", "Видео H.264 — для YouTube, соцсетей и телефонов"),
    Format("mov", "MOV", ".mov", "QuickTime; с прозрачным фоном — ProRes 4444 для монтажа", alpha=True),
    Format("avi", "AVI", ".avi", "Видео MPEG-4 (Xvid) для старых программ и плееров"),
    Format("gif", "GIF", ".gif", "Анимированная картинка без звука — для мемов и стикеров",
           audio=False, alpha=True),
    Format("png", "PNG", "", "Последовательность картинок, по файлу на кадр", audio=False, alpha=True,
           quality=False),
    Format("mp3", "MP3", ".mp3", "Только звук — все включённые звуковые дорожки", video=False),
]
FORMATS_BY_KEY = {f.key: f for f in FORMATS}

QUALITY = {  # высокое, среднее, низкое
    "crf": (18, 23, 28),
    "qv": (2, 4, 7),
    "mp3": ("256k", "192k", "128k"),
    "aac": ("256k", "192k", "128k"),
    "dither": ("sierra2_4a", "bayer:bayer_scale=4", "bayer:bayer_scale=2"),
}


class ExportError(Exception):
    pass


class ExportCancelled(Exception):
    pass


def find_ffmpeg() -> str | None:
    try:
        import imageio_ffmpeg
        path = imageio_ffmpeg.get_ffmpeg_exe()
        if path and os.path.exists(path):
            return path
    except Exception:  # пакет не установлен или нет бинарника для этой системы
        pass
    return shutil.which("ffmpeg")


@dataclass
class ExportSettings:
    fmt: str
    path: str                 # файл, а для PNG — папка
    first: int = 0            # первый кадр (с 0)
    last: int = 0             # последний кадр включительно
    width: int = 1920
    height: int = 1080
    fps: int = 24
    quality: int = 0          # 0 — высокое, 1 — среднее, 2 — низкое
    transparent: bool = False
    with_audio: bool = True
    loop: bool = True         # GIF

    @property
    def frames(self) -> int:
        return self.last - self.first + 1

    @property
    def duration(self) -> float:
        return self.frames / self.fps


def output_size(project: Project, scale: float, even: bool) -> tuple[int, int]:
    w = max(2, round(project.width * scale))
    h = max(2, round(project.height * scale))
    if even:  # H.264 / MPEG-4 с yuv420p требуют чётных размеров
        w -= w % 2
        h -= h % 2
    return w, h


def needs_even(fmt: str, transparent: bool) -> bool:
    return fmt in ("mp4", "avi") or (fmt == "mov" and not transparent)


def audio_inputs(project: Project, s: ExportSettings):
    """Клипы, которые попадают в диапазон экспорта: (путь, задержка мс, обрезка начала с, громкость)."""
    out = []
    fps = project.fps
    for _track, clip in project.audio_clips():
        path = project.media.get(clip.media_id)
        if not path or not os.path.exists(path):
            continue
        if clip.end_frame(fps) <= s.first or clip.start > s.last:
            continue
        offset = (clip.start - s.first) / fps
        out.append((path, max(0.0, offset) * 1000, max(0.0, -offset), clip.volume))
    return out


def _audio_filter(inputs, first_index: int) -> str:
    parts, labels = [], []
    for i, (_path, delay_ms, trim, vol) in enumerate(inputs):
        idx = first_index + i
        parts.append(f"[{idx}:a]atrim=start={trim:.4f},asetpts=PTS-STARTPTS,volume={vol:.3f},"
                     f"adelay=delays={int(round(delay_ms))}:all=1[a{i}]")
        labels.append(f"[a{i}]")
    if len(labels) == 1:
        parts.append(f"{labels[0]}anull[aout]")
    else:
        parts.append(f"{''.join(labels)}amix=inputs={len(labels)}:normalize=0:duration=longest[aout]")
    return ";".join(parts)


def build_command(ffmpeg: str, project: Project, s: ExportSettings) -> list[str]:
    q = s.quality
    cmd = [ffmpeg, "-y", "-hide_banner", "-loglevel", "error"]
    fmt = s.fmt
    ainputs = audio_inputs(project, s) if (FORMATS_BY_KEY[fmt].audio and (s.with_audio or fmt == "mp3")) else []

    if fmt == "mp3":
        if not ainputs:
            raise ExportError("В выбранном диапазоне нет звука. Добавьте звук на звуковую дорожку "
                              "или включите выключенные дорожки.")
        for path, *_ in ainputs:
            cmd += ["-i", path]
        cmd += ["-filter_complex", _audio_filter(ainputs, 0), "-map", "[aout]",
                "-t", f"{s.duration:.4f}", "-c:a", "libmp3lame", "-b:a", QUALITY["mp3"][q], s.path]
        return cmd

    cmd += ["-f", "rawvideo", "-pix_fmt", "rgba", "-s", f"{s.width}x{s.height}", "-r", str(s.fps), "-i", "-"]
    for path, *_ in ainputs:
        cmd += ["-i", path]
    filters = []
    maps = []
    if fmt == "gif":
        reserve = 1 if s.transparent else 0
        filters.append(f"[0:v]split[v1][v2];[v1]palettegen=reserve_transparent={reserve}:stats_mode=diff[pal];"
                       f"[v2][pal]paletteuse=dither={QUALITY['dither'][q]}"
                       f"{':alpha_threshold=128' if s.transparent else ''}[vout]")
        maps += ["-map", "[vout]"]
    else:
        maps += ["-map", "0:v"]
    if ainputs:
        filters.append(_audio_filter(ainputs, 1))
        maps += ["-map", "[aout]"]
    if filters:
        cmd += ["-filter_complex", ";".join(filters)]
    cmd += maps

    if fmt == "mp4":
        cmd += ["-c:v", "libx264", "-preset", "medium", "-crf", str(QUALITY["crf"][q]), "-pix_fmt", "yuv420p",
                "-movflags", "+faststart"]
        if ainputs:
            cmd += ["-c:a", "aac", "-b:a", QUALITY["aac"][q]]
    elif fmt == "mov":
        if s.transparent:
            cmd += ["-c:v", "prores_ks", "-profile:v", "4444", "-pix_fmt", "yuva444p10le",
                    "-qscale:v", str((4, 9, 14)[q])]
            if ainputs:
                cmd += ["-c:a", "pcm_s16le"]
        else:
            cmd += ["-c:v", "libx264", "-preset", "medium", "-crf", str(QUALITY["crf"][q]), "-pix_fmt", "yuv420p"]
            if ainputs:
                cmd += ["-c:a", "aac", "-b:a", QUALITY["aac"][q]]
    elif fmt == "avi":
        cmd += ["-c:v", "mpeg4", "-vtag", "xvid", "-q:v", str(QUALITY["qv"][q]), "-pix_fmt", "yuv420p"]
        if ainputs:
            cmd += ["-c:a", "libmp3lame", "-b:a", QUALITY["mp3"][q]]
    elif fmt == "gif":
        cmd += ["-loop", "0" if s.loop else "-1"]
    if ainputs:
        cmd += ["-t", f"{s.duration:.4f}"]
    cmd.append(s.path)
    return cmd


def _frame_bytes(project: Project, frame: int, s: ExportSettings) -> bytes:
    img = render_frame(project, frame, background=not s.transparent, size=(s.width, s.height))
    img = img.convertToFormat(QImage.Format_RGBA8888)
    return img.constBits().tobytes()[: s.width * s.height * 4]


def export(project: Project, s: ExportSettings, progress=None) -> str:
    """Экспортирует проект. progress(done, total) -> bool; False — отмена.
    Возвращает путь к результату."""
    total = s.frames if FORMATS_BY_KEY[s.fmt].video else 1

    def tick(done):
        if progress is not None and progress(done, total) is False:
            raise ExportCancelled()

    if s.fmt == "png":
        os.makedirs(s.path, exist_ok=True)
        base = os.path.basename(os.path.normpath(s.path))
        digits = max(4, len(str(s.last + 1)))
        for i, f in enumerate(range(s.first, s.last + 1)):
            tick(i)
            img = render_frame(project, f, background=not s.transparent, size=(s.width, s.height))
            img.save(os.path.join(s.path, f"{base}_{f + 1:0{digits}d}.png"), "PNG")
        tick(total)
        return s.path

    ffmpeg = find_ffmpeg()
    if not ffmpeg:
        raise ExportError("Не найден FFmpeg. Установите пакет: pip install imageio-ffmpeg")
    cmd = build_command(ffmpeg, project, s)
    folder = os.path.dirname(os.path.abspath(s.path))
    os.makedirs(folder, exist_ok=True)
    with tempfile.TemporaryFile() as log:
        return _run_ffmpeg(project, s, cmd, log, total, tick)


def _run_ffmpeg(project: Project, s: ExportSettings, cmd, log, total, tick) -> str:
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE if FORMATS_BY_KEY[s.fmt].video else subprocess.DEVNULL,
                            stdout=subprocess.DEVNULL, stderr=log, creationflags=flags)
    try:
        if FORMATS_BY_KEY[s.fmt].video:
            for i, f in enumerate(range(s.first, s.last + 1)):
                tick(i)
                try:
                    proc.stdin.write(_frame_bytes(project, f, s))
                except (BrokenPipeError, OSError):
                    break  # FFmpeg завершился с ошибкой — причину прочитаем ниже
            try:
                proc.stdin.close()
            except OSError:
                pass
        else:
            tick(0)
        while True:
            try:
                proc.wait(timeout=0.1)
                break
            except subprocess.TimeoutExpired:
                tick(total - 1 if total > 1 else 0)
    except ExportCancelled:
        proc.kill()
        proc.wait()
        if proc.stdin is not None:
            try:
                proc.stdin.close()
            except OSError:
                pass
        if os.path.exists(s.path):
            os.remove(s.path)
        raise
    if proc.returncode != 0:
        log.seek(0)
        msg = log.read().decode("utf-8", "replace").strip().splitlines()
        if os.path.exists(s.path):
            os.remove(s.path)
        raise ExportError("FFmpeg не смог записать файл:\n" + "\n".join(msg[-6:]))
    tick(total)
    return s.path
