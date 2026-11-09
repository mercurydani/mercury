"""Самопроверка собранной программы: MercuryToonz --self-test отчёт.txt

Проверяет то, что чаще всего ломается при упаковке в .exe: Qt-плагины, FFmpeg, звук,
отрисовку, сохранение проекта, импорт видео и экспорт. Пишет отчёт в файл (у оконной
программы на Windows нет консоли) и возвращает код 0, если всё в порядке.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import traceback


def run_selftest(report_path: str | None) -> int:
    lines: list[str] = []
    ok = True

    def log(msg):
        lines.append(msg)

    def check(name, fn):
        nonlocal ok
        try:
            extra = fn()
            log(f"[OK]   {name}" + (f" — {extra}" if extra else ""))
        except Exception as e:  # noqa: BLE001 — нужен полный отчёт о любой поломке
            ok = False
            log(f"[FAIL] {name}: {e}")
            log(traceback.format_exc())

    from PySide6.QtGui import QColor
    from PySide6.QtWidgets import QApplication

    from . import APP_VERSION, export, fileformat, theme
    from .model import Project, Stroke
    from .prefs import prefs
    from .render import render_frame

    app = QApplication.instance() or QApplication(sys.argv[:1])
    app.setPalette(theme.palette())
    app.setStyleSheet(theme.STYLESHEET)
    log(f"MercuryToonz {APP_VERSION}, Python {sys.version.split()[0]}, frozen={getattr(sys, 'frozen', False)}")
    tmp = tempfile.mkdtemp(prefix="mtoonz-selftest-")
    state = {}

    def ffmpeg():
        path = export.find_ffmpeg()
        if not path:
            raise RuntimeError("FFmpeg не найден")
        out = subprocess.run([path, "-version"], capture_output=True, text=True,
                             creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0)).stdout.splitlines()[0]
        state["ffmpeg"] = path
        return out

    def window():
        from .app import MainWindow
        prefs().set("general/tutorial_done", True)
        w = MainWindow()
        w.resize(1280, 800)
        w.show()
        app.processEvents()
        if w.grab().isNull():
            raise RuntimeError("окно не отрисовалось")
        state["w"] = w
        return f"{w.width()}×{w.height()}"

    def drawing():
        p = state["w"].project
        p.reset(name="Самопроверка", width=640, height=360, fps=25, frame_count=25)
        p.add_stroke(Stroke(((100, 100, 1), (500, 260, 1)), QColor("#2f62f0"), 20))
        img = render_frame(p, 0)
        c = img.pixelColor(300, 180)
        if c.blue() < 150:
            raise RuntimeError(f"мазок не нарисовался: {c.name()}")
        return "мазок виден"

    def multimedia():
        from PySide6 import QtMultimedia as mm  # проверяем, что модуль и его плагины упакованы
        mm.QMediaPlayer()
        n_in, n_out = len(mm.QMediaDevices.audioInputs()), len(mm.QMediaDevices.audioOutputs())
        return f"микрофонов: {n_in}, выходов звука: {n_out}"

    def import_video():
        video = os.path.join(tmp, "тест.mp4")
        subprocess.run([state["ffmpeg"], "-y", "-loglevel", "error", "-f", "lavfi", "-i",
                        "color=c=red:s=320x240:r=25:d=1", "-f", "lavfi", "-i", "sine=frequency=440:duration=1",
                        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", video], check=True,
                       creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        w = state["w"]
        if w.import_files([video], frame=0) != 1:
            raise RuntimeError("видео не импортировалось")
        img = render_frame(w.project, 5)
        c = img.pixelColor(500, 40)  # в стороне от проверочного мазка
        if c.red() < 200 or c.green() > 80:
            raise RuntimeError(f"кадр видео не показан: {c.name()}")
        n_audio = sum(len(t.clips) for t in w.project.tracks if t.kind == "audio")
        return f"кадр виден, звуковых клипов: {n_audio}"

    def save_load():
        p = state["w"].project
        path = os.path.join(tmp, "проект.mtoonz")
        fileformat.save_project(p, path)
        q = Project()
        fileformat.load_project(path, q)
        if len(q.layers[0].keys[0].strokes) != 1:
            raise RuntimeError("рисунок не сохранился")
        return f"{os.path.getsize(path)} байт"

    def export_mp4():
        p = state["w"].project
        out = os.path.join(tmp, "результат.mp4")
        export.export(p, export.ExportSettings("mp4", out, 0, 24, 320, 180, 25))
        return f"{os.path.getsize(out)} байт"

    def startup_sound():
        from . import brand
        return os.path.basename(brand.startup_sound_path())

    for name, fn in (("FFmpeg", ffmpeg), ("Главное окно", window), ("Рисование", drawing),
                     ("Qt Multimedia", multimedia), ("Импорт видео", import_video),
                     ("Сохранение проекта", save_load), ("Экспорт MP4", export_mp4),
                     ("Звук запуска", startup_sound)):
        if name in ("Рисование", "Импорт видео", "Сохранение проекта", "Экспорт MP4") and "w" not in state:
            log(f"[SKIP] {name}: нет главного окна")
            ok = False
            continue
        if name == "Импорт видео" and "ffmpeg" not in state:
            log(f"[SKIP] {name}: нет FFmpeg")
            continue
        check(name, fn)
    log("ИТОГ: " + ("всё работает" if ok else "есть ошибки"))
    text = "\n".join(lines) + "\n"
    if report_path:
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(text)
    if sys.stdout is not None:
        try:
            sys.stdout.write(text)
        except (OSError, UnicodeError):
            pass
    w = state.get("w")
    if w is not None:
        w.project.undo_stack.setClean()
        w.project._extra_dirty = False
        w._reset_media()
    return 0 if ok else 1
