"""Формат проекта MercuryToonz (*.mtoonz).

Файл — это ZIP-архив:

    meta.json        краткие сведения для списка проектов (имя, даты, размер сцены, число кадров)
    project.json     полная сцена: настройки, слои, ключевые кадры, мазки
    thumbnail.png    обложка проекта
    media/           (зарезервировано) импортированные видео и звук

Корневые поля project.json: format="mercurytoonz", version — версия формата.
Неизвестные типы слоёв при загрузке не теряются: они сохраняются как есть
и записываются обратно, чтобы старая версия программы не портила новые файлы.
"""

from __future__ import annotations

import json
import os
import shutil
import tempfile
import zipfile
from dataclasses import dataclass
from datetime import datetime, timezone

from PySide6.QtCore import QBuffer, QByteArray, QIODevice
from PySide6.QtGui import QColor, QImage

from . import APP_VERSION, audio
from .brushes import BrushParams
from .animation import Transform
from .model import AudioClip, Drawing, Layer, Project, Stroke, Track, VisualClip

EXTENSION = ".mtoonz"
FORMAT_ID = "mercurytoonz"
FORMAT_VERSION = 3  # 2: дорожки отдельно от слоёв; 3: видео/картинки/GIF и ключи трансформаций


class ProjectFileError(Exception):
    pass


# ---------------------------------------------------------------- сериализация
def _color(c: QColor) -> str:
    return c.name(QColor.HexArgb) if c.alpha() < 255 else c.name()


def _stroke_to_dict(s: Stroke) -> dict:
    flat = []
    for x, y, pr in s.points:
        flat += [round(x, 2), round(y, 2), round(pr, 3)]
    d = {"pts": flat, "color": _color(s.color), "width": round(s.width, 3)}
    if s.opacity != 1.0:
        d["opacity"] = round(s.opacity, 3)
    if s.erase:
        d["erase"] = True
    if s.use_pressure:
        d["pressure"] = True
    brush = s.brush.to_dict()
    if brush:
        d["brush"] = brush
    return d


def _stroke_from_dict(d: dict) -> Stroke:
    flat = d.get("pts", [])
    pts = tuple((flat[i], flat[i + 1], flat[i + 2]) for i in range(0, len(flat) - 2, 3))
    return Stroke(pts, QColor(d.get("color", "#000000")), float(d.get("width", 4)),
                  float(d.get("opacity", 1.0)), bool(d.get("erase", False)), bool(d.get("pressure", False)),
                  BrushParams.from_dict(d.get("brush")))


def _layer_to_dict(layer: Layer) -> dict:
    raw = getattr(layer, "raw", None)
    if raw is not None:  # слой незнакомого типа — возвращаем без изменений
        return raw
    return {
        "id": layer.id,
        "type": layer.type,
        "name": layer.name,
        "visible": layer.visible,
        "locked": layer.locked,
        "opacity": layer.opacity,
        "tag": layer.tag,
        "keys": {str(k): {"strokes": [_stroke_to_dict(s) for s in d.strokes]}
                 for k, d in sorted(layer.keys.items())},
        **({"transform": layer.transform.to_dict()} if layer.transform.to_dict() else {}),
    }


def _clip_to_dict(c) -> dict:
    if isinstance(c, VisualClip):
        d = {"id": c.id, "type": c.kind, "media": c.media_id, "name": c.name, "start": c.start,
             "length": c.length, "offset": round(c.offset, 4), "speed": c.speed, "src_w": c.src_w,
             "src_h": c.src_h, "source_duration": round(c.source_duration, 4)}
        tr = c.transform.to_dict()
        if tr:
            d["transform"] = tr
        return d
    return {"id": c.id, "type": "audio", "media": c.media_id, "name": c.name, "start": c.start,
            "duration": round(c.duration, 4), "volume": c.volume}


def _clip_from_dict(d: dict, media: dict) -> AudioClip:
    c = AudioClip(d["media"], d.get("name", "Звук"), int(d.get("start", 0)), float(d.get("duration", 0)),
                  float(d.get("volume", 1.0)))
    if d.get("id"):
        c.id = d["id"]
    try:
        c.duration, c.peaks = audio.analyze_wav(media[c.media_id])
    except Exception:  # файл не читается — оставим длительность из проекта
        pass
    return c


def _track_to_dict(t: Track) -> dict:
    d = {"id": t.id, "type": t.kind, "name": t.name, "enabled": t.enabled, "locked": t.locked,
         "clips": [_clip_to_dict(c) for c in t.clips] + t.raw_clips}
    if t.animation:
        d["animation"] = True
    return d


def _track_from_dict(d: dict, media: dict) -> Track | None:
    kind = d.get("type")
    if kind not in ("video", "audio"):
        return None
    t = Track(kind, d.get("name", "Дорожка"), d.get("id"), bool(d.get("animation", False)))
    t.enabled = bool(d.get("enabled", True))
    t.locked = bool(d.get("locked", False))
    for cd in d.get("clips", []):
        if cd.get("type") == "audio" and kind == "audio" and cd.get("media") in media:
            t.clips.append(_clip_from_dict(cd, media))
        elif cd.get("type") in ("video", "image", "gif") and kind == "video" and cd.get("media") in media:
            c = VisualClip(cd["media"], cd["type"], cd.get("name", "Клип"), int(cd.get("start", 0)),
                           max(1, int(cd.get("length", 1))), float(cd.get("offset", 0)), float(cd.get("speed", 1)),
                           int(cd.get("src_w", 1920)), int(cd.get("src_h", 1080)),
                           float(cd.get("source_duration", 0)), Transform.from_dict(cd.get("transform")))
            if cd.get("id"):
                c.id = cd["id"]
            t.clips.append(c)
        else:
            t.raw_clips.append(cd)
    return t


def _layer_from_dict(d: dict, media: dict) -> Layer:
    layer = Layer(d.get("name", "Слой"), d.get("id"))
    layer.visible = bool(d.get("visible", True))
    layer.locked = bool(d.get("locked", False))
    layer.opacity = float(d.get("opacity", 1.0))
    layer.tag = d.get("tag", layer.tag)
    if d.get("type", "drawing") != "drawing":
        # пока не умеем показывать — храним как есть, слой скрыт и заблокирован
        layer.raw = d
        layer.name = f"{layer.name} (не поддерживается)"
        layer.locked = True
        return layer
    layer.transform = Transform.from_dict(d.get("transform"))
    for k, kd in d.get("keys", {}).items():
        layer.keys[int(k)] = Drawing([_stroke_from_dict(s) for s in kd.get("strokes", [])])
    return layer


def project_to_dict(project: Project) -> dict:
    return {
        "format": FORMAT_ID,
        "version": FORMAT_VERSION,
        "app_version": APP_VERSION,
        "name": project.name,
        "scene": {
            "width": project.width,
            "height": project.height,
            "fps": project.fps,
            "frames": project.frame_count,
            "background": _color(project.background),
        },
        "layers": [_layer_to_dict(l) for l in project.layers],
        "tracks": [_track_to_dict(t) for t in project.tracks],
        "media": [_media_meta(project, mid, path) for mid, path in sorted(project.media.items())],
    }


def _media_entry(mid: str, path: str) -> str:
    return f"media/{mid}{os.path.splitext(path)[1].lower()}"


def _media_meta(project: Project, mid: str, path: str) -> dict:
    d = {"id": mid, "file": _media_entry(mid, path)}
    info = project.media_info.get(mid)
    if info is not None:
        d["info"] = {"kind": info.kind, "width": info.width, "height": info.height,
                     "duration": round(info.duration, 4), "fps": info.fps, "has_audio": info.has_audio}
    return d


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


# ---------------------------------------------------------------- запись / чтение
def _png_bytes(img: QImage) -> bytes:
    ba = QByteArray()
    buf = QBuffer(ba)
    buf.open(QIODevice.WriteOnly)
    img.save(buf, "PNG")
    return bytes(ba)


def save_project(project: Project, path: str, thumbnail: QImage | None = None, created: str | None = None):
    """Атомарная запись: сначала во временный файл рядом, потом замена."""
    data = project_to_dict(project)
    if created is None:
        try:
            created = read_meta(path).created if os.path.exists(path) else None
        except ProjectFileError:
            created = None
    meta = {
        "format": FORMAT_ID,
        "version": FORMAT_VERSION,
        "name": project.name,
        "created": created or _now(),
        "modified": _now(),
        "width": project.width,
        "height": project.height,
        "fps": project.fps,
        "frames": project.frame_count,
        "layers": len(project.layers),
    }
    folder = os.path.dirname(os.path.abspath(path))
    os.makedirs(folder, exist_ok=True)
    fd, tmp = tempfile.mkstemp(suffix=".tmp", prefix=".mtoonz-", dir=folder)
    os.close(fd)
    try:
        with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
            z.writestr("meta.json", json.dumps(meta, ensure_ascii=False, indent=1))
            z.writestr("project.json", json.dumps(data, ensure_ascii=False, separators=(",", ":")))
            if thumbnail is not None:
                z.writestr("thumbnail.png", _png_bytes(thumbnail))
            for mid, mpath in sorted(project.media.items()):
                if os.path.exists(mpath):
                    z.write(mpath, _media_entry(mid, mpath), compress_type=zipfile.ZIP_STORED)
        os.replace(tmp, path)
    except Exception:
        if os.path.exists(tmp):
            os.remove(tmp)
        raise


def _open_zip(path: str) -> zipfile.ZipFile:
    try:
        return zipfile.ZipFile(path)
    except (OSError, zipfile.BadZipFile) as e:
        raise ProjectFileError(f"Не удалось открыть файл проекта: {e}") from e


def load_project(path: str, project: Project):
    """Загружает файл в существующий объект Project (интерфейс уже к нему подключён)."""
    with _open_zip(path) as z:
        try:
            data = json.loads(z.read("project.json"))
        except (KeyError, ValueError) as e:
            raise ProjectFileError("Файл повреждён: нет описания сцены") from e
        if data.get("format") != FORMAT_ID:
            raise ProjectFileError("Это не проект MercuryToonz")
        if int(data.get("version", 0)) > FORMAT_VERSION:
            raise ProjectFileError("Проект создан в более новой версии MercuryToonz. Обновите программу.")
        # медиафайлы распаковываем во временную папку проекта
        work = tempfile.mkdtemp(prefix="mtoonz-media-")
        media = {}
        media_info = {}
        names = set(z.namelist())
        for entry in data.get("media", []):
            name = entry.get("file", "")
            mid = str(entry.get("id", ""))
            if name.startswith("media/") and name in names and ".." not in name and mid:
                target = os.path.join(work, os.path.basename(name))
                with z.open(name) as src, open(target, "wb") as dst:
                    shutil.copyfileobj(src, dst)
                media[mid] = target
                if isinstance(entry.get("info"), dict):
                    from .media import MediaInfo
                    i = entry["info"]
                    media_info[mid] = MediaInfo(i.get("kind", "video"), int(i.get("width", 0)),
                                                int(i.get("height", 0)), float(i.get("duration", 0)),
                                                float(i.get("fps", 0)), bool(i.get("has_audio", False)))
    scene = data.get("scene", {})
    Layer._counter = 0
    layers, tracks = [], []
    for d in data.get("tracks", []):
        t = _track_from_dict(d, media)
        if t is not None:
            tracks.append(t)
    if not any(t.animation for t in tracks):
        tracks.insert(0, Track("video", "Анимация", animation=True))
    old_audio = []
    for d in data.get("layers", []):
        if d.get("type") == "audio":  # версия 1: звук был слоем — переносим на звуковую дорожку
            if d.get("media") in media:
                old_audio.append(_clip_from_dict(d, media))
            continue
        layers.append(_layer_from_dict(d, media))
    for i, clip in enumerate(old_audio):
        t = Track("audio", f"Звук {i + 1}")
        t.clips.append(clip)
        tracks.append(t)
    if not any(t.kind == "audio" for t in tracks):
        tracks.append(Track("audio", "Звук 1"))
    if not layers:
        layers = [Layer("Слой 1")]
        layers[0].keys[0] = Drawing()
    project.name = data.get("name") or os.path.splitext(os.path.basename(path))[0]
    project.width = int(scene.get("width", 1920))
    project.height = int(scene.get("height", 1080))
    project.fps = int(scene.get("fps", 24))
    project.frame_count = max(1, int(scene.get("frames", 48)))
    project.background = QColor(scene.get("background", "#ffffff"))
    project.layers = layers
    project.tracks = tracks
    project.media = media
    project.media_info = media_info
    project.file_path = path
    project._after_load()


# ---------------------------------------------------------------- библиотека проектов
@dataclass
class ProjectInfo:
    path: str
    name: str
    created: str
    modified: str
    width: int
    height: int
    fps: int
    frames: int
    layers: int
    thumbnail: QImage | None = None

    @property
    def modified_dt(self) -> datetime:
        try:
            return datetime.fromisoformat(self.modified).astimezone()
        except ValueError:
            return datetime.fromtimestamp(os.path.getmtime(self.path)).astimezone()


def read_meta(path: str, with_thumbnail: bool = False) -> ProjectInfo:
    with _open_zip(path) as z:
        try:
            meta = json.loads(z.read("meta.json"))
        except (KeyError, ValueError) as e:
            raise ProjectFileError("Нет meta.json") from e
        thumb = None
        if with_thumbnail and "thumbnail.png" in z.namelist():
            thumb = QImage.fromData(z.read("thumbnail.png"), "PNG")
    mtime = datetime.fromtimestamp(os.path.getmtime(path), timezone.utc).isoformat(timespec="seconds")
    return ProjectInfo(
        path=path,
        name=meta.get("name") or os.path.splitext(os.path.basename(path))[0],
        created=meta.get("created", mtime),
        modified=meta.get("modified", mtime),
        width=int(meta.get("width", 0)),
        height=int(meta.get("height", 0)),
        fps=int(meta.get("fps", 24)),
        frames=int(meta.get("frames", 0)),
        layers=int(meta.get("layers", 0)),
        thumbnail=thumb,
    )


def list_projects(folder: str) -> list[ProjectInfo]:
    out = []
    if not os.path.isdir(folder):
        return out
    for name in os.listdir(folder):
        if name.endswith(EXTENSION) and not name.startswith("."):
            try:
                out.append(read_meta(os.path.join(folder, name), with_thumbnail=True))
            except ProjectFileError:
                continue
    out.sort(key=lambda i: i.modified_dt, reverse=True)
    return out


def safe_file_name(name: str) -> str:
    bad = '<>:"/\\|?*\0'
    cleaned = "".join("_" if ch in bad or ord(ch) < 32 else ch for ch in name).strip(" .")
    return cleaned or "Проект"


def unique_path(folder: str, name: str, exclude: str | None = None) -> str:
    base = safe_file_name(name)
    path = os.path.join(folder, base + EXTENSION)
    n = 2
    while os.path.exists(path) and os.path.abspath(path) != os.path.abspath(exclude or ""):
        path = os.path.join(folder, f"{base} ({n}){EXTENSION}")
        n += 1
    return path


def unique_name(folder: str, base: str) -> str:
    names = {i.name for i in list_projects(folder)}
    if base not in names and not os.path.exists(os.path.join(folder, safe_file_name(base) + EXTENSION)):
        return base
    n = 2
    while f"{base} {n}" in names or os.path.exists(os.path.join(folder, safe_file_name(f"{base} {n}") + EXTENSION)):
        n += 1
    return f"{base} {n}"


def _rewrite_name(src: str, dst: str, name: str, keep_created: bool):
    """Копирует архив src в dst, меняя имя проекта внутри."""
    folder = os.path.dirname(os.path.abspath(dst))
    fd, tmp = tempfile.mkstemp(suffix=".tmp", prefix=".mtoonz-", dir=folder)
    os.close(fd)
    try:
        with _open_zip(src) as zin, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
            for item in zin.infolist():
                raw = zin.read(item.filename)
                if item.filename in ("meta.json", "project.json"):
                    d = json.loads(raw)
                    d["name"] = name
                    if item.filename == "meta.json":
                        d["modified"] = _now()
                        if not keep_created:
                            d["created"] = _now()
                    raw = json.dumps(d, ensure_ascii=False).encode()
                zout.writestr(item, raw)
        os.replace(tmp, dst)
    except Exception:
        if os.path.exists(tmp):
            os.remove(tmp)
        raise


def rename_project(path: str, new_name: str) -> str:
    folder = os.path.dirname(path)
    dst = unique_path(folder, new_name, exclude=path)
    _rewrite_name(path, dst, new_name, keep_created=True)
    if os.path.abspath(dst) != os.path.abspath(path):
        os.remove(path)
    return dst


def duplicate_project(path: str) -> str:
    info = read_meta(path)
    folder = os.path.dirname(path)
    name = unique_name(folder, f"{info.name} копия")
    dst = unique_path(folder, name)
    _rewrite_name(path, dst, name, keep_created=False)
    return dst


def delete_project(path: str) -> bool:
    """Сначала пробуем отправить в корзину; если её нет — удаляем окончательно.
    Возвращает True, если файл ушёл в корзину."""
    from PySide6.QtCore import QFile
    if QFile.moveToTrash(path):
        return True
    os.remove(path)
    return False


def copy_into(folder: str, path: str) -> str:
    """Импорт чужого файла .mtoonz в папку проектов."""
    info = read_meta(path)
    dst = unique_path(folder, info.name)
    shutil.copy2(path, dst)
    return dst
