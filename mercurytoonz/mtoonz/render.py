"""Отрисовка мазков и целых кадров. Используется холстом, превью проектов и (дальше) экспортом."""

from __future__ import annotations

from PySide6.QtCore import QRectF, Qt
from PySide6.QtGui import QColor, QImage, QPainter, QTransform

from .animation import element_transform
from .brushes import draw_brush_stroke
from .model import Drawing, Project, Stroke


def draw_stroke(p: QPainter, s: Stroke):
    p.setCompositionMode(QPainter.CompositionMode_DestinationOut if s.erase
                         else QPainter.CompositionMode_SourceOver)
    p.setOpacity(s.opacity)
    draw_brush_stroke(p, s.points, s.color, s.width, s.brush, s.use_pressure, s.erase)
    p.setOpacity(1.0)
    p.setCompositionMode(QPainter.CompositionMode_SourceOver)


def draw_drawing(p: QPainter, drawing: Drawing | None):
    if drawing:
        for s in drawing.strokes:
            draw_stroke(p, s)


def layer_transform(project: Project, layer, frame: int) -> QTransform | None:
    """Трансформация слоя-элемента в кадре (None — слой не сдвинут)."""
    tr = layer.transform
    if tr.is_identity():
        return None
    v = tr.values(frame)
    return element_transform(v, project.width, project.height, project.width / 2, project.height / 2)


def clip_geometry(project: Project, clip):
    fit = min(project.width / max(1, clip.src_w), project.height / max(1, clip.src_h))
    return clip.src_w * fit, clip.src_h * fit


def clip_transform(project: Project, clip, frame: int) -> QTransform | None:
    w, h = clip_geometry(project, clip)
    v = clip.transform.values(frame - clip.start)
    return element_transform(v, w, h, project.width / 2, project.height / 2)


def draw_clip(p: QPainter, project: Project, pool, clip, frame: int, media_w: int = 0) -> bool:
    """Рисует клип (видео, картинку, GIF) в координатах сцены. Возвращает False, если кадра нет."""
    src = pool.get(project, clip.media_id, clip.kind) if pool is not None else None
    if src is None:
        return False
    img = src.frame(clip.source_time(frame, project.fps), media_w)
    if img is None:
        return False
    t = clip_transform(project, clip, frame)
    if t is None:
        return False
    w, h = clip_geometry(project, clip)
    op = clip.transform.value("opacity", frame - clip.start)
    if op <= 0.001:
        return True
    p.save()
    p.setTransform(t, True)
    p.setOpacity(p.opacity() * max(0.0, min(1.0, op)))
    p.setRenderHint(QPainter.SmoothPixmapTransform)
    cl, ct, cr, cb = clip.crop
    if cl or ct or cr or cb:  # кадрирование: края скрыты, сама картинка остаётся на месте
        iw, ih = img.width(), img.height()
        fw, fh = max(0.0, 1 - cl - cr), max(0.0, 1 - ct - cb)
        if fw > 0 and fh > 0:
            p.drawImage(QRectF(cl * w, ct * h, fw * w, fh * h), img, QRectF(cl * iw, ct * ih, fw * iw, fh * ih))
    else:
        p.drawImage(QRectF(0, 0, w, h), img)
    p.restore()
    return True


def render_frame(project: Project, frame: int, max_width: int | None = None,
                 background: bool = True, size: tuple[int, int] | None = None, pool=None,
                 media_w: int = 0) -> QImage:
    """Кадр сцены целиком: клипы видеодорожек и рисованные слои, в порядке дорожек.
    max_width — уменьшить для превью; size — точный размер результата (для экспорта);
    pool — открытые медиафайлы (media.MediaPool); media_w — ширина декодирования видео (0 — исходная)."""
    if size is not None:
        w, h = size
        sx, sy = w / project.width, h / project.height
    else:
        scale = 1.0
        if max_width and project.width > max_width:
            scale = max_width / project.width
        w, h = max(1, round(project.width * scale)), max(1, round(project.height * scale))
        sx = sy = scale
    out = QImage(w, h, QImage.Format_ARGB32_Premultiplied)
    out.fill(project.background if background else QColor(0, 0, 0, 0))
    own_pool = None
    if pool is None and any(t.kind == "video" and not t.animation and t.clips for t in project.tracks):
        from .media import MediaPool
        pool = own_pool = MediaPool()
    p = QPainter(out)
    p.setRenderHint(QPainter.Antialiasing)
    p.scale(sx, sy)
    p.setClipRect(QRectF(0, 0, project.width, project.height))
    for track in reversed(project.tracks):  # нижние дорожки рисуются первыми
        if track.kind != "video" or not track.enabled:
            continue
        if track.animation:
            _draw_layers(p, project, frame, w, h, sx, sy)
        else:
            c = track.clip_at(frame, project.fps)
            if c is not None and hasattr(c, "transform"):
                draw_clip(p, project, pool, c, frame, media_w)
    p.end()
    if own_pool is not None:
        own_pool.close()
    return out


def _draw_layers(p: QPainter, project: Project, frame: int, w: int, h: int, sx: float, sy: float):
    for layer in reversed(project.layers):
        if not layer.visible:
            continue
        drawing = layer.drawing_at(frame)
        if drawing is None or drawing.is_empty():
            continue
        lt = layer_transform(project, layer, frame)
        op = layer.opacity * (layer.transform.value("opacity", frame) if lt is not None else 1.0)
        buf = QImage(w, h, QImage.Format_ARGB32_Premultiplied)
        buf.fill(Qt.transparent)
        bp = QPainter(buf)
        bp.setRenderHint(QPainter.Antialiasing)
        bp.scale(sx, sy)
        bp.setClipRect(QRectF(0, 0, project.width, project.height))
        if lt is not None:
            bp.setTransform(lt, True)
        draw_drawing(bp, drawing)
        bp.end()
        p.save()
        p.resetTransform()
        p.setOpacity(op)
        p.drawImage(0, 0, buf)
        p.restore()


def first_drawn_frame(project: Project) -> int:
    """Первый кадр, где что-то нарисовано (для обложки проекта)."""
    best = None
    for layer in project.layers:
        for k, d in layer.keys.items():
            if not d.is_empty() and (best is None or k < best):
                best = k
    return best or 0


def render_thumb(project: Project, drawing: Drawing | None, w: int, h: int, dpr: float = 2.0) -> QImage:
    """Миниатюра рисунка для панели слоёв (на прозрачном фоне)."""
    img = QImage(int(w * dpr), int(h * dpr), QImage.Format_ARGB32_Premultiplied)
    img.setDevicePixelRatio(dpr)
    img.fill(Qt.transparent)
    if drawing is None or drawing.is_empty():
        return img
    s = min(w / project.width, h / project.height)
    p = QPainter(img)
    p.setRenderHint(QPainter.Antialiasing)
    p.translate((w - project.width * s) / 2, (h - project.height * s) / 2)
    p.scale(s, s)
    p.setClipRect(QRectF(0, 0, project.width, project.height))
    draw_drawing(p, drawing)
    p.end()
    return img
